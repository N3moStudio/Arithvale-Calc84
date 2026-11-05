import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// Only receipts written by this installation authorize cleanup. Never infer ownership
/// from an extension, filename pattern, or the contents of the user's folder.
public struct AutomaticFolderBackups: Sendable {
    public static let interval: TimeInterval = 24 * 60 * 60
    public static let retainedCount = 7

    public enum Operation: Sendable, Equatable { case read, write, delete }
    public typealias Coordinate = (URL, Operation, (URL) throws -> Void) throws -> Void
    public struct Saved: Sendable {
        public let url: URL
        public let digest: Data
        public let removed: Int
        public let cleanupDeferred: Bool
    }
    struct Receipt: Codable, Equatable {
        let id: UUID
        let digest: Data
        var saved: Date
        var filename: String { "Automatic-\(id.uuidString).c84backup" }
    }
    struct Journal: Codable {
        var version = 1
        let library: UUID
        let folder: String
        var receipts: [Receipt] = []
    }

    public let folder: URL
    public let journalURL: URL
    public let library: UUID
    public init(folder: URL, historyDirectory: URL, library: UUID) {
        self.folder = folder.standardizedFileURL.resolvingSymlinksInPath()
        self.library = library
        let identity = self.folder.absoluteString + "|" + library.uuidString
        let name = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
        journalURL = historyDirectory.appendingPathComponent(name + ".json")
    }

    public func delay(at now: Date = Date()) throws -> TimeInterval {
        guard let last = try load().receipts.last?.saved else { return 0 }
        // A clock change must not turn one unlock into a burst of exports.
        return min(Self.interval, max(0, last.addingTimeInterval(Self.interval).timeIntervalSince(now)))
    }

    public func save(_ source: URL, at now: Date? = nil,
                     coordinate: Coordinate = { url, _, action in try action(url) }) throws -> Saved {
        var journal = try load()
        try Task.checkCancellation()
        var receipt = Receipt(id: UUID(), digest: try BackupCopy.digest(source), saved: now ?? Date())
        let destination = folder.appendingPathComponent(receipt.filename)
        try coordinate(destination, .write) { try BackupCopy.copy(source, to: $0, expected: receipt.digest) }
        receipt.saved = now ?? Date()
        // Persist the new verified copy before considering any older file for deletion.
        // A failed journal write leaves the new copy unowned and all older copies safe.
        journal.receipts.append(receipt)
        try persist(journal)
        var removed = 0
        do {
            let obsolete = Array(journal.receipts.dropLast(Self.retainedCount))
            guard !obsolete.isEmpty else { return Saved(url: destination, digest: receipt.digest, removed: 0, cleanupDeferred: false) }
            let retained = Array(journal.receipts.suffix(Self.retainedCount))
            // All seven rollback copies, including the replacement, must still read back
            // correctly. An unavailable cloud placeholder is a reason to keep extra files.
            for kept in retained { try verify(kept, coordinate: coordinate) }
            // Preflight every deletion before deleting anything; also check again inside
            // the provider's coordinated delete to protect a file changed in the meantime.
            for old in obsolete { try verify(old, allowMissing: true, coordinate: coordinate) }
            for old in obsolete {
                try Task.checkCancellation()
                let url = folder.appendingPathComponent(old.filename)
                do {
                    try coordinate(url, .delete) { target in
                        try self.requireRegularFile(target, receipt: old)
                        try BackupCopy.verify(target, expected: old.digest)
                        try Task.checkCancellation()
                        try FileManager.default.removeItem(at: target)
                        removed += 1
                    }
                } catch where Self.isMissing(error) {
                    // Recover safely if a previous run stopped after deletion but before
                    // updating its journal, or the user already removed this old copy.
                }
                journal.receipts.removeAll { $0.id == old.id }
                try persist(journal)
            }
            return Saved(url: destination, digest: receipt.digest, removed: removed, cleanupDeferred: false)
        } catch {
            // Saving succeeded. Cleanup failure must never invalidate or remove that copy.
            return Saved(url: destination, digest: receipt.digest, removed: removed, cleanupDeferred: true)
        }
    }

    private func verify(_ receipt: Receipt, allowMissing: Bool = false, coordinate: Coordinate) throws {
        try Task.checkCancellation()
        do {
            try coordinate(folder.appendingPathComponent(receipt.filename), .read) { target in
                try self.requireRegularFile(target, receipt: receipt)
                try BackupCopy.verify(target, expected: receipt.digest)
            }
        } catch where allowMissing && Self.isMissing(error) { }
    }
    private func requireRegularFile(_ url: URL, receipt: Receipt) throws {
        let expected = folder.appendingPathComponent(receipt.filename).standardizedFileURL
        guard url.standardizedFileURL == expected,
              url.resolvingSymlinksInPath().standardizedFileURL == expected else { throw VaultError.invalidBackup }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw VaultError.invalidBackup }
    }
    private func load() throws -> Journal {
        let data: Data
        do { data = try Data(contentsOf: journalURL) }
        catch where Self.isMissing(error) { return Journal(library: library, folder: folder.absoluteString) }
        let journal = try JSONDecoder().decode(Journal.self, from: data)
        guard journal.version == 1, journal.library == library, journal.folder == folder.absoluteString,
              journal.receipts.count <= 10_000,
              Set(journal.receipts.map(\.id)).count == journal.receipts.count,
              journal.receipts.allSatisfy({ $0.digest.count == 32 && $0.saved.timeIntervalSince1970.isFinite })
        else { throw VaultError.invalidBackup }
        return journal
    }
    private func persist(_ journal: Journal) throws {
        try FileManager.default.createDirectory(at: journalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(journal).write(to: journalURL, options: .atomic)
    }
    private static func isMissing(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code)
    }
}
