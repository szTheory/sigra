import AVFoundation
import CryptoKit
import Foundation

enum NativeMediaKind: String, Codable, CaseIterable, Hashable {
    case image
    case audio
}

struct NativeMediaManifest: Codable, Equatable {
    let kind: NativeMediaKind
    let version: String
    let byteCount: Int
    let sha256: String
}

struct NativeLessonLease: Codable, Equatable {
    let partition: String
    let expiresAt: Date
}

enum NativeLessonStoreError: Error, Equatable {
    case invalidManifest
    case mediaIntegrityFailed
    case unavailable
    case partitionMismatch
    case leaseExpired
    case invalidReplay
    case persistenceFailed
}

enum NativeReplayTerminal: String, Codable, CaseIterable {
    case accepted
    case rejected
    case conflict
}

struct NativeReplayEntry: Codable, Equatable {
    let journalEntryID: String
    let clientMutationID: String
    let idempotencyKey: String
    let baseCheckpoint: String
    let action: String
    let answer: String

    enum CodingKeys: String, CodingKey {
        case journalEntryID = "journal_entry_id"
        case clientMutationID = "client_mutation_id"
        case idempotencyKey = "idempotency_key"
        case baseCheckpoint = "base_checkpoint"
        case action
        case answer
    }
}

final class NativeLessonStore {
    private struct Activation: Codable {
        let lease: NativeLessonLease
        let manifests: [NativeMediaManifest]
        let fileNames: [String: String]
    }

    private let rootURL: URL
    private let fileManager: FileManager
    private var activation: Activation?
    private var player: AVAudioPlayer?
    private(set) var terminalCount = 0

    private var activationURL: URL { rootURL.appendingPathComponent("activation.json") }
    var journalURL: URL {
        guard let activation else { return rootURL.appendingPathComponent("journal.json") }
        return partitionDirectory(activation.lease.partition).appendingPathComponent("journal.json")
    }

    init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
    }

    convenience init(fileManager: FileManager = .default) throws {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        self.init(rootURL: support.appendingPathComponent("SigraNativeProof", isDirectory: true), fileManager: fileManager)
    }

    func activate(
        lease: NativeLessonLease,
        manifests: [NativeMediaManifest],
        bodies: [NativeMediaKind: Data]
    ) throws {
        guard validIdentifier(lease.partition), !manifests.isEmpty,
              Set(manifests.map(\NativeMediaManifest.kind)).count == manifests.count,
              Set(manifests.map(\NativeMediaManifest.kind)) == Set(bodies.keys) else {
            throw NativeLessonStoreError.invalidManifest
        }
        let directory = partitionDirectory(lease.partition)
        let staging = rootURL.appendingPathComponent(".staging-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
            var files: [String: String] = [:]
            for manifest in manifests {
                guard validManifest(manifest), let body = bodies[manifest.kind],
                      body.count == manifest.byteCount,
                      digest(body) == manifest.sha256.lowercased() else {
                    throw NativeLessonStoreError.mediaIntegrityFailed
                }
                let name = mediaFileName(partition: lease.partition, manifest: manifest)
                try body.write(to: staging.appendingPathComponent(name), options: [.atomic, .completeFileProtection])
                files[manifest.kind.rawValue] = name
            }

            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            for name in files.values.sorted() {
                let destination = directory.appendingPathComponent(name)
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.moveItem(at: staging.appendingPathComponent(name), to: destination)
            }
            let retainedNames = Set(files.values)
            for stale in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            where stale.pathExtension == "media" && !retainedNames.contains(stale.lastPathComponent) {
                try fileManager.removeItem(at: stale)
            }
            let promoted = Activation(lease: lease, manifests: manifests, fileNames: files)
            let marker = try JSONEncoder().encode(promoted)
            try marker.write(to: activationURL, options: [.atomic, .completeFileProtection])
            activation = promoted
            terminalCount = loadTerminals().count
            try? fileManager.removeItem(at: staging)
        } catch let error as NativeLessonStoreError {
            try? fileManager.removeItem(at: staging)
            throw error
        } catch {
            try? fileManager.removeItem(at: staging)
            throw NativeLessonStoreError.persistenceFailed
        }
    }

    func recover(partition: String, asOf: Date) -> Bool {
        guard let data = try? Data(contentsOf: activationURL),
              let stored = try? JSONDecoder().decode(Activation.self, from: data),
              stored.lease.partition == partition,
              leaseValid(stored.lease, asOf: asOf),
              verifyStoredMedia(stored) else {
            activation = nil
            terminalCount = 0
            return false
        }
        activation = stored
        terminalCount = loadTerminals().count
        return true
    }

    func isAvailableOffline(partition: String, asOf: Date) -> Bool {
        guard let active = activation ?? loadActivation(),
              active.lease.partition == partition,
              leaseValid(active.lease, asOf: asOf),
              verifyStoredMedia(active) else {
            activation = nil
            return false
        }
        activation = active
        return true
    }

    func offlineMediaURL(kind: NativeMediaKind, partition: String, asOf: Date) throws -> URL {
        guard isAvailableOffline(partition: partition, asOf: asOf),
              let active = activation,
              let name = active.fileNames[kind.rawValue] else {
            throw NativeLessonStoreError.unavailable
        }
        return partitionDirectory(partition).appendingPathComponent(name)
    }

    @MainActor
    func playOfflineAudio(partition: String, asOf: Date) throws {
        let url = try offlineMediaURL(kind: .audio, partition: partition, asOf: asOf)
        let audio = try AVAudioPlayer(contentsOf: url)
        audio.prepareToPlay()
        guard audio.play() else { throw NativeLessonStoreError.unavailable }
        player = audio
    }

    func switchPartition(to partition: String) throws {
        guard validIdentifier(partition) else { throw NativeLessonStoreError.partitionMismatch }
        guard let active = activation ?? loadActivation() else { return }
        if active.lease.partition != partition { try clear(active) }
    }

    func clearForLogout() throws {
        if let active = activation ?? loadActivation() { try clear(active) }
        else { try removeActivationMarker() }
    }

    func clearForRevocation() throws {
        if let active = activation ?? loadActivation() { try clear(active) }
        else { try removeActivationMarker() }
    }

    func enqueue(_ entry: NativeReplayEntry, partition: String, asOf: Date) throws {
        guard isAvailableOffline(partition: partition, asOf: asOf) else {
            throw NativeLessonStoreError.unavailable
        }
        guard validEntry(entry) else { throw NativeLessonStoreError.invalidReplay }
        var entries = loadJournal()
        if let existing = entries.first(where: { $0.idempotencyKey == entry.idempotencyKey }) {
            guard existing == entry else { throw NativeLessonStoreError.invalidReplay }
            return
        }
        entries.append(entry)
        try persist(entries, at: journalURL)
    }

    func reconcile(entry: NativeReplayEntry, hostTerminal: NativeReplayTerminal) throws -> NativeReplayTerminal {
        guard loadJournal().contains(entry) else { throw NativeLessonStoreError.invalidReplay }
        var terminals = loadTerminals()
        if let existing = terminals[entry.idempotencyKey] { return existing }
        terminals[entry.idempotencyKey] = hostTerminal
        try persist(terminals, at: terminalURL)
        terminalCount = terminals.count
        return hostTerminal
    }

    private var terminalURL: URL {
        guard let activation else { return rootURL.appendingPathComponent("terminal.json") }
        return partitionDirectory(activation.lease.partition).appendingPathComponent("terminal.json")
    }

    private func loadActivation() -> Activation? {
        guard let data = try? Data(contentsOf: activationURL) else { return nil }
        return try? JSONDecoder().decode(Activation.self, from: data)
    }

    private func loadJournal() -> [NativeReplayEntry] {
        guard let data = try? Data(contentsOf: journalURL) else { return [] }
        return (try? JSONDecoder().decode([NativeReplayEntry].self, from: data)) ?? []
    }

    private func loadTerminals() -> [String: NativeReplayTerminal] {
        guard let data = try? Data(contentsOf: terminalURL) else { return [:] }
        return (try? JSONDecoder().decode([String: NativeReplayTerminal].self, from: data)) ?? [:]
    }

    private func persist<T: Encodable>(_ value: T, at url: URL) throws {
        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            throw NativeLessonStoreError.persistenceFailed
        }
    }

    private func verifyStoredMedia(_ stored: Activation) -> Bool {
        let directory = partitionDirectory(stored.lease.partition)
        return stored.manifests.allSatisfy { manifest in
            guard let name = stored.fileNames[manifest.kind.rawValue],
                  let body = try? Data(contentsOf: directory.appendingPathComponent(name), options: .mappedIfSafe) else {
                return false
            }
            return body.count == manifest.byteCount && digest(body) == manifest.sha256.lowercased()
        }
    }

    private func clear(_ active: Activation) throws {
        activation = nil
        player?.stop()
        player = nil
        terminalCount = 0
        do {
            try removeActivationMarker()
            let directory = partitionDirectory(active.lease.partition)
            if fileManager.fileExists(atPath: directory.path) { try fileManager.removeItem(at: directory) }
        } catch {
            throw NativeLessonStoreError.persistenceFailed
        }
    }

    private func removeActivationMarker() throws {
        if fileManager.fileExists(atPath: activationURL.path) { try fileManager.removeItem(at: activationURL) }
    }

    private func leaseValid(_ lease: NativeLessonLease, asOf: Date) -> Bool {
        asOf.compare(lease.expiresAt) == .orderedAscending
    }

    private func validManifest(_ manifest: NativeMediaManifest) -> Bool {
        validIdentifier(manifest.version) && (1...10_485_760).contains(manifest.byteCount) &&
            manifest.sha256.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil
    }

    private func validEntry(_ entry: NativeReplayEntry) -> Bool {
        [entry.journalEntryID, entry.clientMutationID, entry.idempotencyKey, entry.baseCheckpoint, entry.action]
            .allSatisfy(validIdentifier) && entry.answer.utf8.count <= 120
    }

    private func validIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128
    }

    private func partitionDirectory(_ partition: String) -> URL {
        rootURL.appendingPathComponent("partition-\(digest(Data(partition.utf8)))", isDirectory: true)
    }

    private func mediaFileName(partition: String, manifest: NativeMediaManifest) -> String {
        "partition-\(digest(Data(partition.utf8)).prefix(16))-\(manifest.kind.rawValue)-\(digest(Data(manifest.version.utf8)).prefix(16)).media"
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
