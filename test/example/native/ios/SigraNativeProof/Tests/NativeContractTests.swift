import Security
import XCTest
@testable import SigraNativeProof

final class NativeContractTests: XCTestCase {
    func testHostedRequestUsesExactRegisteredCallbackAndPKCES256() throws {
        let configuration = HostedAuthConfiguration(
            baseURL: try XCTUnwrap(URL(string: "https://host.invalid")),
            profileID: "ios-primary"
        )
        let attempt = try HostedAuthSession.authorizationRequest(
            configuration: configuration,
            state: "expected-state",
            verifier: String(repeating: "v", count: 43)
        )
        let components = try XCTUnwrap(URLComponents(url: attempt.startURL, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })

        XCTAssertEqual(components.path, "/users/app-login")
        XCTAssertEqual(query["profile_id"]!, "ios-primary")
        XCTAssertEqual(query["callback"]!, "sigra-native-proof://auth/callback")
        XCTAssertEqual(query["state"]!, "expected-state")
        XCTAssertEqual(query["code_challenge_method"]!, "S256")
        XCTAssertNotEqual(query["code_challenge"]!, String(repeating: "v", count: 43))
    }

    func testCallbackDeniesWrongSchemeAuthorityPathStateAndMissingCode() throws {
        let accepted = try XCTUnwrap(URL(string: "sigra-native-proof://auth/callback?code=one-time&state=expected"))
        XCTAssertNoThrow(try HostedAuthSession.validatedCode(from: accepted, expectedState: "expected"))

        for denied in [
            "other://auth/callback?code=one-time&state=expected",
            "sigra-native-proof://other/callback?code=one-time&state=expected",
            "sigra-native-proof://auth/other?code=one-time&state=expected",
            "sigra-native-proof://auth/callback?code=one-time&state=wrong",
            "sigra-native-proof://auth/callback?state=expected"
        ] {
            let callback = try XCTUnwrap(URL(string: denied))
            XCTAssertThrowsError(try HostedAuthSession.validatedCode(from: callback, expectedState: "expected"))
        }
    }

    func testKeychainPostureCoversRotationRelaunchDeletionAndExactReadCategories() throws {
        let backend = FakeSecureStorageBackend()
        let store = SecureRefreshStore(backend: backend)
        let first = Data(repeating: 0x41, count: 32)
        let second = Data(repeating: 0x42, count: 32)

        XCTAssertEqual(store.accessibilityClass, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as String)
        XCTAssertEqual(try store.saveInitial(first).readResult, .readOK)
        XCTAssertEqual(try store.rotate(to: second).rotated, true)
        XCTAssertEqual(SecureRefreshStore(backend: backend).recoverAfterRelaunch().recoveredAfterRelaunch, true)
        XCTAssertEqual(store.deleteAfterLogout().deletedAfterLogout, true)
        XCTAssertEqual(store.saveInitial(second).present, true)
        XCTAssertEqual(store.deleteAfterRevocation().deletedAfterRevocation, true)

        for (status, expected) in [
            (errSecItemNotFound, StorageReadResult.notFound),
            (errSecDecode, .decryptFailed),
            (errSecInteractionNotAllowed, .keyUnavailable)
        ] {
            backend.forcedReadStatus = status
            XCTAssertEqual(store.readPosture().readResult, expected)
        }
    }

    func testStorageStatusHasExactAllowlistAndNeverPersistsAccess() throws {
        let encoded = try JSONEncoder().encode(StoragePosture(
            present: true,
            rotated: true,
            recoveredAfterRelaunch: true,
            deletedAfterLogout: true,
            deletedAfterRevocation: true,
            readResult: .readOK
        ))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(Set(object.keys), Set([
            "present", "rotated", "recovered_after_relaunch", "deleted_after_logout",
            "deleted_after_revocation", "read_result", "access_persisted"
        ]))
        XCTAssertEqual(object["access_persisted"] as? Bool, false)
    }
}

private final class FakeSecureStorageBackend: SecureStorageBackend {
    var material: Data?
    var forcedReadStatus: OSStatus?

    func read(service: String, account: String) -> (OSStatus, Data?) {
        if let forcedReadStatus { return (forcedReadStatus, nil) }
        return material.map { (errSecSuccess, $0) } ?? (errSecItemNotFound, nil)
    }

    func write(_ material: Data, service: String, account: String) -> OSStatus {
        self.material = material
        forcedReadStatus = nil
        return errSecSuccess
    }

    func delete(service: String, account: String) -> OSStatus {
        material = nil
        forcedReadStatus = nil
        return errSecSuccess
    }
}
