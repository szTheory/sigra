import Security
import CryptoKit
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
        XCTAssertEqual(try store.saveInitial(second).present, true)
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

    func testMediaRequiresExactLengthAndSHAThenRestoresBeforeStrictLeaseExpiry() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = NativeLessonStore(rootURL: root)
        let image = Data("verified-image".utf8)
        let audio = Data("verified-audio".utf8)
        let expiresAt = Date(timeIntervalSince1970: 1_800_000_000)
        let lease = NativeLessonLease(partition: "partition-one", expiresAt: expiresAt)
        let manifests = [
            NativeMediaManifest(kind: .image, version: "image-v1", byteCount: image.count, sha256: sha256(image)),
            NativeMediaManifest(kind: .audio, version: "audio-v1", byteCount: audio.count, sha256: sha256(audio))
        ]

        try store.activate(lease: lease, manifests: manifests, bodies: [.image: image, .audio: audio])
        XCTAssertTrue(store.isAvailableOffline(partition: lease.partition, asOf: expiresAt.addingTimeInterval(-0.000001)))
        XCTAssertFalse(store.isAvailableOffline(partition: lease.partition, asOf: expiresAt))
        XCTAssertTrue(NativeLessonStore(rootURL: root).recover(partition: lease.partition, asOf: expiresAt.addingTimeInterval(-1)))
        XCTAssertTrue(try store.offlineMediaURL(kind: .audio, partition: lease.partition, asOf: expiresAt.addingTimeInterval(-1)).isFileURL)

        let readyFiles = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertTrue(readyFiles.contains("activation.json"), "activation is the marker-last durable write")
    }

    func testShortAndCorruptMediaNeverActivate() throws {
        for mutation in ["short", "corrupt"] {
            let root = temporaryRoot()
            defer { try? FileManager.default.removeItem(at: root) }
            let expected = Data("verified-audio".utf8)
            let supplied = mutation == "short" ? expected.dropLast() : Data("verified-Audio".utf8)
            let lease = NativeLessonLease(partition: "partition-integrity", expiresAt: Date(timeIntervalSinceNow: 60))
            let manifest = NativeMediaManifest(
                kind: .audio,
                version: "audio-v1",
                byteCount: expected.count,
                sha256: sha256(expected)
            )
            XCTAssertThrowsError(try NativeLessonStore(rootURL: root).activate(
                lease: lease,
                manifests: [manifest],
                bodies: [.audio: Data(supplied)]
            ))
            XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("activation.json").path))
        }
    }

    func testPartitionSwitchLogoutAndRevocationClearBeforeLocalUse() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let body = Data("lesson".utf8)
        let manifest = NativeMediaManifest(kind: .image, version: "v1", byteCount: body.count, sha256: sha256(body))
        let lease = NativeLessonLease(partition: "partition-first", expiresAt: Date(timeIntervalSinceNow: 60))
        let store = NativeLessonStore(rootURL: root)

        try store.activate(lease: lease, manifests: [manifest], bodies: [.image: body])
        try store.switchPartition(to: "partition-second")
        XCTAssertFalse(store.isAvailableOffline(partition: lease.partition, asOf: Date()))

        try store.activate(lease: lease, manifests: [manifest], bodies: [.image: body])
        try store.clearForLogout()
        XCTAssertFalse(store.isAvailableOffline(partition: lease.partition, asOf: Date()))

        try store.activate(lease: lease, manifests: [manifest], bodies: [.image: body])
        try store.clearForRevocation()
        XCTAssertFalse(store.isAvailableOffline(partition: lease.partition, asOf: Date()))
    }

    func testReplayJournalIsCredentialFreeAndHostTerminalOutcomesPersistExactlyOnce() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let body = Data("lesson".utf8)
        let manifest = NativeMediaManifest(kind: .image, version: "v1", byteCount: body.count, sha256: sha256(body))
        let lease = NativeLessonLease(partition: "partition-replay", expiresAt: Date(timeIntervalSinceNow: 60))
        let store = NativeLessonStore(rootURL: root)
        try store.activate(lease: lease, manifests: [manifest], bodies: [.image: body])

        for terminal in NativeReplayTerminal.allCases {
            let suffix = terminal.rawValue
            let entry = NativeReplayEntry(
                journalEntryID: "journal-\(suffix)",
                clientMutationID: "mutation-\(suffix)",
                idempotencyKey: "idempotency-\(suffix)",
                baseCheckpoint: "market-morning-v1",
                action: "answer",
                answer: "apples"
            )
            try store.enqueue(entry, partition: lease.partition, asOf: Date())
            XCTAssertEqual(try store.reconcile(entry: entry, hostTerminal: terminal), terminal)
            XCTAssertEqual(try store.reconcile(entry: entry, hostTerminal: terminal), terminal)
        }

        XCTAssertEqual(store.terminalCount, 3)
        let journal = try String(contentsOf: store.journalURL, encoding: .utf8)
        XCTAssertFalse(journal.range(of: "access|refresh|credential|account|user", options: .regularExpression) != nil)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("sigra-native-contract-\(UUID().uuidString)", isDirectory: true)
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
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
