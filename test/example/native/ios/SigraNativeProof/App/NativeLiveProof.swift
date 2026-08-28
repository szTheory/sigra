import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI
import UIKit

#if NATIVE_PROOF
private struct LiveBootstrap: Decodable {
    struct Media: Decodable {
        let kind: String
        let version: String
        let byteSize: Int
        let sha256: String

        enum CodingKeys: String, CodingKey {
            case kind, version, sha256
            case byteSize = "byte_size"
        }
    }

    let partition: String
    let expiresAt: String
    let media: [Media]

    enum CodingKeys: String, CodingKey {
        case partition, media
        case expiresAt = "expires_at"
    }
}

private struct ReplayResponse: Decodable {
    let status: String
}

private enum LiveProofPhase: String {
    case fresh
    case awaitingRelaunch
    case awaitingFinalLogin
    case complete
}

@MainActor
final class NativeLiveProofCoordinator: ObservableObject {
    @Published private(set) var status = NativeProofStatus.unavailable
    @Published private(set) var phase: String = LiveProofPhase.fresh.rawValue
    @Published private(set) var failureRule = ""

    private let environment: [String: String]
    private let defaults = UserDefaults.standard
    private let phaseKey = "sigra.native-proof.live.phase"
    private let partitionKey = "sigra.native-proof.live.partition"
    private let expiresKey = "sigra.native-proof.live.expires"
    private var auth: HostedAuthSession?

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
        phase = defaults.string(forKey: phaseKey) ?? LiveProofPhase.fresh.rawValue
        restorePosture()
    }

    var isLive: Bool { environment["SIGRA_NATIVE_PROOF_MODE"] == "live_physical_iphone" }

    func startFirstJourney(anchor: ASPresentationAnchor) async {
        guard phase == LiveProofPhase.fresh.rawValue else { return }
        do {
            try cleanupLocalFiles()
            _ = SecureRefreshStore().deleteAfterLogout()
            let session = try makeSession()
            auth = session
            let initial = try await session.startHostedLogin(from: anchor)
            status.storagePresent = initial.present
            let rotated = try await session.rotateRefresh()
            status.storageRotated = rotated.rotated
            try await proveHostedReturn(session)
            let bootstrap = try await fetchBootstrap(session)
            let store = try makeStore()
            let lease = try lease(from: bootstrap)
            let media = try await fetchMedia(session, bootstrap: bootstrap)
            let manifests = try manifests(from: bootstrap)
            try store.activate(lease: lease, manifests: manifests, bodies: media)
            status.imageVerified = try verifiedLocalMedia(.image, store: store, lease: lease)
            status.audioVerified = try verifiedLocalMedia(.audio, store: store, lease: lease)
            status.strictLeaseEdge = store.isAvailableOffline(
                partition: lease.partition,
                asOf: lease.expiresAt.addingTimeInterval(-0.000001)
            ) && !store.isAvailableOffline(partition: lease.partition, asOf: lease.expiresAt)
            status.offlineUse = try await proveControlledTransportFailure(store: store, lease: lease)
            try await proveReplayOutcomes(session, store: try makeStore(), lease: lease)
            defaults.set(lease.partition, forKey: partitionKey)
            defaults.set(bootstrap.expiresAt, forKey: expiresKey)
            persistPosture()
            setPhase(.awaitingRelaunch)
        } catch {
            fail("NP-IOS-LIVE-FIRST-JOURNEY")
        }
    }

    func resumeAfterRelaunch() async {
        guard phase == LiveProofPhase.awaitingRelaunch.rawValue else { return }
        do {
            let partition = try requiredDefault(partitionKey)
            let expires = try parseDate(try requiredDefault(expiresKey))
            let lease = NativeLessonLease(partition: partition, expiresAt: expires)
            let store = try makeStore()
            status.killRelaunch = store.recover(partition: partition, asOf: Date())
            let session = try makeSession()
            auth = session
            let posture = try await session.recoverAndRotateRefresh()
            status.storageRecoveredAfterRelaunch = posture.recoveredAfterRelaunch
            status.storageRotated = status.storageRotated && posture.rotated

            let foreign = "foreign-" + UUID().uuidString.lowercased()
            let (_, denied) = try await session.authorizedRequest(
                path: "/api/native-proof/lesson/bootstrap?account_partition=\(foreign)"
            )
            let (_, allowed) = try await session.authorizedRequest(path: "/api/native-proof/lesson/bootstrap")
            status.accountSwitch = denied.statusCode == 403 && allowed.statusCode == 200 &&
                store.isAvailableOffline(partition: lease.partition, asOf: Date())

            let (_, logout) = try await session.authorizedRequest(
                path: "/api/native-proof/logout",
                method: "POST",
                jsonBody: [:]
            )
            guard logout.statusCode == 200 else { throw HostedAuthError.invalidResponse }
            let revoked = try await session.rotateRefresh()
            status.serverRevocation = revoked.deletedAfterRevocation && revoked.readResult == .notFound
            status.storageDeletedAfterRevocation = revoked.deletedAfterRevocation
            try store.clearForRevocation()
            persistPosture()
            setPhase(.awaitingFinalLogin)
        } catch {
            fail("NP-IOS-LIVE-RELAUNCH")
        }
    }

    func finishWithLocalLogout(anchor: ASPresentationAnchor) async {
        guard phase == LiveProofPhase.awaitingFinalLogin.rawValue else { return }
        do {
            let session = try makeSession()
            auth = session
            let initial = try await session.startHostedLogin(from: anchor)
            guard initial.present else { throw HostedAuthError.invalidResponse }
            let deleted = session.logout()
            status.storageDeletedAfterLogout = deleted.deletedAfterLogout
            status.storageReadResult = deleted.readResult.rawValue
            status.cleanup = status.storageDeletedAfterLogout && status.storageDeletedAfterRevocation
            try cleanupLocalFiles()
            defaults.removeObject(forKey: partitionKey)
            defaults.removeObject(forKey: expiresKey)
            persistPosture()
            setPhase(.complete)
        } catch {
            fail("NP-IOS-LIVE-FINAL-LOGIN")
        }
    }

    private func proveHostedReturn(_ session: HostedAuthSession) async throws {
        let body = [
            "platform": "ios",
            "transport": "custom_scheme",
            "link_verification": "not_applicable",
            "callback_binding": "matched",
            "replay": "not_seen",
            "native_assertion_ref": "physical-iphone-live"
        ]
        let (data, response) = try await session.authorizedRequest(
            path: "/api/native-proof/return", method: "POST", jsonBody: body
        )
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        status.hostedReturn = response.statusCode == 200 && object?["status"] as? String == "allow"
        guard status.hostedReturn else { throw HostedAuthError.invalidResponse }
    }

    private func fetchBootstrap(_ session: HostedAuthSession) async throws -> LiveBootstrap {
        let (data, response) = try await session.authorizedRequest(path: "/api/native-proof/lesson/bootstrap")
        guard response.statusCode == 200 else { throw HostedAuthError.invalidResponse }
        return try JSONDecoder().decode(LiveBootstrap.self, from: data)
    }

    private func fetchMedia(_ session: HostedAuthSession, bootstrap: LiveBootstrap) async throws -> [NativeMediaKind: Data] {
        var result: [NativeMediaKind: Data] = [:]
        for manifest in bootstrap.media {
            guard let kind = NativeMediaKind(rawValue: manifest.kind) else { throw HostedAuthError.invalidResponse }
            let (data, response) = try await session.authorizedRequest(
                path: "/api/native-proof/lesson/media/\(manifest.kind)/\(manifest.version)"
            )
            guard response.statusCode == 200,
                  data.count == manifest.byteSize,
                  sha256(data) == manifest.sha256.lowercased() else {
                throw HostedAuthError.invalidResponse
            }
            result[kind] = data
        }
        return result
    }

    private func proveReplayOutcomes(
        _ session: HostedAuthSession,
        store: NativeLessonStore,
        lease: NativeLessonLease
    ) async throws {
        guard store.recover(partition: lease.partition, asOf: Date()) else { throw NativeLessonStoreError.unavailable }
        let cases: [(NativeReplayTerminal, String, String)] = [
            (.accepted, "market-morning-v1", "apples"),
            (.rejected, "market-morning-v1", ""),
            (.conflict, "obsolete-checkpoint", "apples")
        ]
        for (terminal, checkpoint, answer) in cases {
            let suffix = terminal.rawValue + "-" + UUID().uuidString.lowercased()
            let entry = NativeReplayEntry(
                journalEntryID: "journal-" + suffix,
                clientMutationID: "mutation-" + suffix,
                idempotencyKey: "idempotency-" + suffix,
                baseCheckpoint: checkpoint,
                action: terminal == .rejected ? "skip" : "answer",
                answer: answer
            )
            try store.enqueue(entry, partition: lease.partition, asOf: Date())
            let body = [
                "client_mutation_id": entry.clientMutationID,
                "idempotency_key": entry.idempotencyKey,
                "base_checkpoint": entry.baseCheckpoint,
                "action": entry.action,
                "answer": entry.answer
            ]
            let (data, response) = try await session.authorizedRequest(
                path: "/api/native-proof/lesson/replay", method: "POST", jsonBody: body
            )
            guard response.statusCode == 200 else { throw HostedAuthError.invalidResponse }
            let host = try JSONDecoder().decode(ReplayResponse.self, from: data)
            guard host.status == terminal.rawValue,
                  try store.reconcile(entry: entry, hostTerminal: terminal) == terminal,
                  try store.reconcile(entry: entry, hostTerminal: terminal) == terminal else {
                throw NativeLessonStoreError.invalidReplay
            }
            switch terminal {
            case .accepted: status.replayAccepted = true
            case .rejected: status.replayRejected = true
            case .conflict: status.replayConflict = true
            }
        }
    }

    private func proveControlledTransportFailure(
        store: NativeLessonStore,
        lease: NativeLessonLease
    ) async throws -> Bool {
        guard let raw = environment["SIGRA_NATIVE_PROOF_FAILURE_URL"],
              let url = URL(string: raw + "/health") else { throw HostedAuthError.invalidConfiguration }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        do {
            _ = try await URLSession.shared.data(for: request)
            return false
        } catch {
            let image = try store.offlineMediaURL(kind: .image, partition: lease.partition, asOf: Date())
            let audio = try store.offlineMediaURL(kind: .audio, partition: lease.partition, asOf: Date())
            let imageAvailable = try Data(contentsOf: image).count > 0
            let audioAvailable = try Data(contentsOf: audio).count > 0
            return imageAvailable && audioAvailable
        }
    }

    private func manifests(from bootstrap: LiveBootstrap) throws -> [NativeMediaManifest] {
        try bootstrap.media.map { value in
            guard let kind = NativeMediaKind(rawValue: value.kind) else { throw HostedAuthError.invalidResponse }
            return NativeMediaManifest(kind: kind, version: value.version, byteCount: value.byteSize, sha256: value.sha256)
        }
    }

    private func lease(from bootstrap: LiveBootstrap) throws -> NativeLessonLease {
        NativeLessonLease(partition: bootstrap.partition, expiresAt: try parseDate(bootstrap.expiresAt))
    }

    private func parseDate(_ value: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: value) else { throw HostedAuthError.invalidResponse }
        return date
    }

    private func makeSession() throws -> HostedAuthSession {
        guard let raw = environment["SIGRA_NATIVE_PROOF_BASE_URL"],
              let url = URL(string: raw),
              url.host != nil else { throw HostedAuthError.invalidConfiguration }
        return HostedAuthSession(configuration: HostedAuthConfiguration(baseURL: url, profileID: "ios-native-proof"))
    }

    private func makeStore() throws -> NativeLessonStore { try NativeLessonStore() }

    private func verifiedLocalMedia(
        _ kind: NativeMediaKind,
        store: NativeLessonStore,
        lease: NativeLessonLease
    ) throws -> Bool {
        let url = try store.offlineMediaURL(kind: kind, partition: lease.partition, asOf: Date())
        return (try Data(contentsOf: url)).count > 0
    }

    private func cleanupLocalFiles() throws {
        let store = try makeStore()
        try store.clearForLogout()
    }

    private func requiredDefault(_ key: String) throws -> String {
        guard let value = defaults.string(forKey: key), !value.isEmpty else { throw HostedAuthError.invalidResponse }
        return value
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func setPhase(_ value: LiveProofPhase) {
        phase = value.rawValue
        defaults.set(value.rawValue, forKey: phaseKey)
    }

    private func persistPosture() {
        guard let data = try? JSONEncoder().encode(status) else { return }
        defaults.set(data, forKey: "sigra.native-proof.live.posture")
    }

    private func restorePosture() {
        guard let data = defaults.data(forKey: "sigra.native-proof.live.posture"),
              let restored = try? JSONDecoder().decode(NativeProofStatus.self, from: data) else { return }
        status = restored
    }

    private func fail(_ rule: String) { failureRule = rule }
}
#endif
