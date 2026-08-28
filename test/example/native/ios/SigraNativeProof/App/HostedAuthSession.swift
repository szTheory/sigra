import AuthenticationServices
import CryptoKit
import Foundation
import Security

struct HostedAuthConfiguration: Equatable {
    let baseURL: URL
    let profileID: String
}

struct HostedAuthorizationAttempt: Equatable {
    let state: String
    let verifier: String
    let startURL: URL
}

struct HostedSessionMaterial: Equatable {
    let access: Data
    let refresh: Data
}

enum HostedAuthError: Error, Equatable {
    case invalidConfiguration
    case invalidCallback
    case browserCancelled
    case invalidResponse
    case serverRevoked
    case transportFailure
}

protocol HostedAuthTransport {
    func exchange(
        code: String,
        verifier: String,
        configuration: HostedAuthConfiguration
    ) async throws -> HostedSessionMaterial
    func refresh(_ material: Data, configuration: HostedAuthConfiguration) async throws -> HostedSessionMaterial
}

struct URLSessionHostedAuthTransport: HostedAuthTransport {
    private struct SessionResponse: Decodable {
        let accessToken: String
        let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func exchange(
        code: String,
        verifier: String,
        configuration: HostedAuthConfiguration
    ) async throws -> HostedSessionMaterial {
        let body: [String: String] = [
            "code": code,
            "code_verifier": verifier,
            "profile_id": configuration.profileID,
            "callback": HostedAuthSession.callbackURL.absoluteString
        ]
        return try await request(path: "/api/app-login/exchange", body: body, configuration: configuration)
    }

    func refresh(_ material: Data, configuration: HostedAuthConfiguration) async throws -> HostedSessionMaterial {
        guard let value = String(data: material, encoding: .utf8), !value.isEmpty else {
            throw HostedAuthError.invalidResponse
        }
        return try await request(
            path: "/api/app-login/refresh",
            body: ["refresh_token": value],
            configuration: configuration
        )
    }

    private func request(
        path: String,
        body: [String: String],
        configuration: HostedAuthConfiguration
    ) async throws -> HostedSessionMaterial {
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false),
              components.scheme == "https" || components.scheme == "http",
              components.host != nil else {
            throw HostedAuthError.invalidConfiguration
        }
        components.path = path
        components.query = nil
        guard let url = components.url else { throw HostedAuthError.invalidConfiguration }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw HostedAuthError.transportFailure
        }
        guard let http = response as? HTTPURLResponse else { throw HostedAuthError.invalidResponse }
        if http.statusCode == 401 { throw HostedAuthError.serverRevoked }
        guard (200..<300).contains(http.statusCode) else { throw HostedAuthError.invalidResponse }
        let decoded = try JSONDecoder().decode(SessionResponse.self, from: data)
        guard let access = decoded.accessToken.data(using: .utf8), !access.isEmpty,
              let refresh = decoded.refreshToken.data(using: .utf8), !refresh.isEmpty else {
            throw HostedAuthError.invalidResponse
        }
        return HostedSessionMaterial(access: access, refresh: refresh)
    }
}

@MainActor
final class HostedAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    nonisolated static let callbackURL = URL(string: "sigra-native-proof://auth/callback")!

    private let configuration: HostedAuthConfiguration
    private let transport: HostedAuthTransport
    private let refreshStore: SecureRefreshStore
    private var accessMaterial: Data?
    private var webSession: ASWebAuthenticationSession?
    private var presentationAnchor: ASPresentationAnchor?

    var hasMemoryOnlyAccess: Bool { accessMaterial != nil }
    var storagePosture: StoragePosture { refreshStore.posture }

    init(
        configuration: HostedAuthConfiguration,
        transport: HostedAuthTransport = URLSessionHostedAuthTransport(),
        refreshStore: SecureRefreshStore = SecureRefreshStore()
    ) {
        self.configuration = configuration
        self.transport = transport
        self.refreshStore = refreshStore
    }

    nonisolated static func authorizationRequest(
        configuration: HostedAuthConfiguration,
        state: String,
        verifier: String
    ) throws -> HostedAuthorizationAttempt {
        guard !state.isEmpty,
              (43...128).contains(verifier.utf8.count),
              verifier.unicodeScalars.allSatisfy({
                  CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
                      .contains($0)
              }),
              var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false),
              components.scheme == "https" || components.scheme == "http",
              components.host != nil,
              !configuration.profileID.isEmpty else {
            throw HostedAuthError.invalidConfiguration
        }
        components.path = "/users/app-login"
        components.queryItems = [
            URLQueryItem(name: "profile_id", value: configuration.profileID),
            URLQueryItem(name: "callback", value: callbackURL.absoluteString),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: pkceChallenge(verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        guard let startURL = components.url else { throw HostedAuthError.invalidConfiguration }
        return HostedAuthorizationAttempt(state: state, verifier: verifier, startURL: startURL)
    }

    nonisolated static func validatedCode(from callback: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              components.scheme == callbackURL.scheme,
              components.host == callbackURL.host,
              components.path == callbackURL.path,
              components.port == nil,
              components.user == nil,
              components.password == nil,
              components.fragment == nil,
              let items = components.queryItems,
              items.map(\URLQueryItem.name).sorted() == ["code", "state"],
              let code = items.first(where: { $0.name == "code" })?.value,
              !code.isEmpty,
              let state = items.first(where: { $0.name == "state" })?.value,
              constantTimeEqual(state, expectedState) else {
            throw HostedAuthError.invalidCallback
        }
        return code
    }

    func startHostedLogin(from anchor: ASPresentationAnchor) async throws -> StoragePosture {
        let attempt = try Self.authorizationRequest(
            configuration: configuration,
            state: try Self.randomURLSafe(byteCount: 32),
            verifier: try Self.randomURLSafe(byteCount: 48)
        )
        presentationAnchor = anchor
        let callback = try await browserCallback(for: attempt.startURL)
        let code = try Self.validatedCode(from: callback, expectedState: attempt.state)
        let issued = try await transport.exchange(
            code: code,
            verifier: attempt.verifier,
            configuration: configuration
        )
        accessMaterial = issued.access
        return try refreshStore.saveInitial(issued.refresh)
    }

    func rotateRefresh() async throws -> StoragePosture {
        let current = try refreshStore.currentMaterial()
        do {
            let replacement = try await transport.refresh(current, configuration: configuration)
            accessMaterial = replacement.access
            return try refreshStore.rotate(to: replacement.refresh)
        } catch HostedAuthError.serverRevoked {
            accessMaterial = nil
            return refreshStore.deleteAfterRevocation()
        }
    }

    func recoverAfterRelaunch() -> StoragePosture {
        accessMaterial = nil
        return refreshStore.recoverAfterRelaunch()
    }

    func logout() -> StoragePosture {
        accessMaterial = nil
        return refreshStore.deleteAfterLogout()
    }

    func markServerRevoked() -> StoragePosture {
        accessMaterial = nil
        return refreshStore.deleteAfterRevocation()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        presentationAnchor ?? ASPresentationAnchor()
    }

    private func browserCallback(for startURL: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: startURL,
                callbackURLScheme: Self.callbackURL.scheme
            ) { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else if error != nil {
                    continuation.resume(throwing: HostedAuthError.browserCancelled)
                } else {
                    continuation.resume(throwing: HostedAuthError.invalidCallback)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            webSession = session
            guard session.start() else {
                continuation.resume(throwing: HostedAuthError.transportFailure)
                return
            }
        }
    }

    nonisolated private static func pkceChallenge(_ verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8)))
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    nonisolated private static func randomURLSafe(byteCount: Int) throws -> String {
        var data = Data(count: byteCount)
        let result = data.withUnsafeMutableBytes { raw in
            SecRandomCopyBytes(kSecRandomDefault, byteCount, raw.baseAddress!)
        }
        guard result == errSecSuccess else { throw HostedAuthError.transportFailure }
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    nonisolated private static func constantTimeEqual(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs.utf8)
        let right = Array(rhs.utf8)
        guard left.count == right.count else { return false }
        return zip(left, right).reduce(UInt8(0)) { partial, pair in partial | (pair.0 ^ pair.1) } == 0
    }
}
