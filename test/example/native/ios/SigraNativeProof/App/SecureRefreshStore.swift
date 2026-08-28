import Foundation
import Security

enum StorageReadResult: String, Codable, CaseIterable {
    case readOK = "read_ok"
    case notFound = "not_found"
    case decryptFailed = "decrypt_failed"
    case keyUnavailable = "key_unavailable"
}

struct StoragePosture: Codable, Equatable {
    var present: Bool
    var rotated: Bool
    var recoveredAfterRelaunch: Bool
    var deletedAfterLogout: Bool
    var deletedAfterRevocation: Bool
    var readResult: StorageReadResult
    let accessPersisted = false

    static let empty = StoragePosture(
        present: false,
        rotated: false,
        recoveredAfterRelaunch: false,
        deletedAfterLogout: false,
        deletedAfterRevocation: false,
        readResult: .notFound
    )

    enum CodingKeys: String, CodingKey {
        case present
        case rotated
        case recoveredAfterRelaunch = "recovered_after_relaunch"
        case deletedAfterLogout = "deleted_after_logout"
        case deletedAfterRevocation = "deleted_after_revocation"
        case readResult = "read_result"
        case accessPersisted = "access_persisted"
    }
}

protocol SecureStorageBackend: AnyObject {
    func read(service: String, account: String) -> (OSStatus, Data?)
    func write(_ material: Data, service: String, account: String) -> OSStatus
    func delete(service: String, account: String) -> OSStatus
}

final class SystemKeychainBackend: SecureStorageBackend {
    func read(service: String, account: String) -> (OSStatus, Data?) {
        var item: CFTypeRef?
        let query = baseQuery(service: service, account: account).merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, replacement in replacement }
        let result = SecItemCopyMatching(query as CFDictionary, &item)
        return (result, item as? Data)
    }

    func write(_ material: Data, service: String, account: String) -> OSStatus {
        let query = baseQuery(service: service, account: account)
        let update: [String: Any] = [kSecValueData as String: material]
        let updated = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        guard updated == errSecItemNotFound else { return updated }

        let addition = query.merging([
            kSecValueData as String: material,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        ]) { _, replacement in replacement }
        return SecItemAdd(addition as CFDictionary, nil)
    }

    func delete(service: String, account: String) -> OSStatus {
        SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
    }

    private func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
    }
}

enum SecureRefreshStoreError: Error, Equatable {
    case writeFailed(OSStatus)
    case deleteFailed(OSStatus)
    case unreadable(StorageReadResult)
}

final class SecureRefreshStore {
    let accessibilityClass = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as String

    private let backend: SecureStorageBackend
    private let service: String
    private let account: String
    private(set) var posture: StoragePosture = .empty

    init(
        backend: SecureStorageBackend = SystemKeychainBackend(),
        service: String = "com.sigra.example.native-proof.refresh",
        account: String = "active"
    ) {
        self.backend = backend
        self.service = service
        self.account = account
    }

    @discardableResult
    func saveInitial(_ material: Data) throws -> StoragePosture {
        guard !material.isEmpty else { throw SecureRefreshStoreError.writeFailed(errSecParam) }
        let result = backend.write(material, service: service, account: account)
        guard result == errSecSuccess else { throw SecureRefreshStoreError.writeFailed(result) }
        posture.present = true
        posture.readResult = .readOK
        return posture
    }

    @discardableResult
    func rotate(to replacement: Data) throws -> StoragePosture {
        let (result, current) = readMaterial()
        guard result == .readOK, let current else { throw SecureRefreshStoreError.unreadable(result) }
        guard !replacement.isEmpty else { throw SecureRefreshStoreError.writeFailed(errSecParam) }
        let changed = !constantTimeEqual(current, replacement)
        let write = backend.write(replacement, service: service, account: account)
        guard write == errSecSuccess else { throw SecureRefreshStoreError.writeFailed(write) }
        posture.present = true
        posture.rotated = changed
        posture.readResult = .readOK
        return posture
    }

    @discardableResult
    func recoverAfterRelaunch() -> StoragePosture {
        let (result, material) = readMaterial()
        posture.present = result == .readOK && material != nil
        posture.recoveredAfterRelaunch = posture.present
        posture.readResult = result
        return posture
    }

    @discardableResult
    func deleteAfterLogout() -> StoragePosture {
        delete(marking: \StoragePosture.deletedAfterLogout)
    }

    @discardableResult
    func deleteAfterRevocation() -> StoragePosture {
        delete(marking: \StoragePosture.deletedAfterRevocation)
    }

    @discardableResult
    func readPosture() -> StoragePosture {
        let (result, material) = readMaterial()
        posture.present = result == .readOK && material != nil
        posture.readResult = result
        return posture
    }

    func currentMaterial() throws -> Data {
        let (result, material) = readMaterial()
        guard result == .readOK, let material else { throw SecureRefreshStoreError.unreadable(result) }
        return material
    }

    private func readMaterial() -> (StorageReadResult, Data?) {
        let (result, material) = backend.read(service: service, account: account)
        switch result {
        case errSecSuccess where material != nil:
            return (.readOK, material)
        case errSecItemNotFound:
            return (.notFound, nil)
        case errSecDecode:
            return (.decryptFailed, nil)
        case errSecInteractionNotAllowed, errSecNotAvailable, errSecAuthFailed:
            return (.keyUnavailable, nil)
        default:
            return (.keyUnavailable, nil)
        }
    }

    private func delete(marking flag: WritableKeyPath<StoragePosture, Bool>) -> StoragePosture {
        let result = backend.delete(service: service, account: account)
        guard result == errSecSuccess || result == errSecItemNotFound else {
            posture.readResult = .keyUnavailable
            return posture
        }
        posture.present = false
        posture.readResult = .notFound
        posture[keyPath: flag] = true
        return posture
    }

    private func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).reduce(UInt8(0)) { partial, pair in partial | (pair.0 ^ pair.1) } == 0
    }
}
