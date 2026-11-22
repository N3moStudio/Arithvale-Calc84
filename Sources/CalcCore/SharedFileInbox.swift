import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// Shared originals wait encrypted, independently of library setup/unlock. The app
/// keeps this inbox key in device-only Keychain storage; it is never a backup key.
public struct SharedFileInbox: Sendable {
    public struct Entry: Codable, Equatable, Identifiable, Sendable {
        public let id: UUID
        public let name: String
        public let bytes: Int
    }
    public let root: URL
    public init(root: URL) { self.root = root }
    public static func newKey() -> Data { VaultCrypto.random(32) }
    private func key(_ data: Data) throws -> SymmetricKey {
        guard data.count == 32 else { throw VaultError.invalidBackup }
        return SymmetricKey(data: data)
    }
    private func folder(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }
    public struct Scan: Sendable {
        public let entries: [Entry]
        public let unreadableIDs: [UUID]
    }
    /// Enumerate only our receipt names; no metadata or missing device key is needed
    /// to remove a received copy. Never follow a directory supplied by metadata.
    public func receivedIDs() throws -> [UUID] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        guard try root.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw VaultError.invalidBackup }
        return try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .compactMap { UUID(uuidString: $0.lastPathComponent) }.sorted { $0.uuidString < $1.uuidString }
    }
    public func scan(key data: Data) throws -> Scan {
        let key = try key(data)
        var readable: [Entry] = [], unreadable: [UUID] = []
        for id in try receivedIDs() {
            try Task.checkCancellation()
            do { readable.append(try readEntry(id, key: key)) }
            catch { unreadable.append(id) }
        }
        return Scan(entries: readable, unreadableIDs: unreadable)
    }
    // Keep strict callers fail-closed; the UI uses scan to expose isolated damage.
    public func entries(key data: Data) throws -> [Entry] {
        let result = try scan(key: data)
        guard result.unreadableIDs.isEmpty else { throw VaultError.invalidBackup }
        return result.entries
    }
    private func readEntry(_ id: UUID, key: SymmetricKey) throws -> Entry {
        let directory = folder(id)
        let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else { throw VaultError.invalidBackup }
        for name in ["metadata", "contents"] {
            let file = try directory.appendingPathComponent(name).resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard file.isRegularFile == true, file.isSymbolicLink != true else { throw VaultError.invalidBackup }
        }
        let metadata = directory.appendingPathComponent("metadata")
        let size = try metadata.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size <= 4096 else { throw VaultError.invalidBackup }
        let entry = try JSONDecoder().decode(Entry.self, from: VaultCrypto.open(Data(contentsOf: metadata), key: key, context: "incoming/\(id)/metadata"))
        guard entry.id == id, entry.bytes >= 0, entry.bytes <= VaultLimits.fileBytes,
              entry.name == URL(fileURLWithPath: entry.name).lastPathComponent,
              entry.name != ".", entry.name != "..", !entry.name.isEmpty else { throw VaultError.invalidBackup }
        return entry
    }
    public func receive(_ source: URL, key data: Data) throws -> Entry {
        // Darwin URLs cache resource values. A new share of the same URL may now
        // contain different bytes; refresh metadata without losing scoped access.
        var currentSource = source
        currentSource.removeAllCachedResourceValues()
        try BackupInbox.requireLocalFile(currentSource)
        let values = try currentSource.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true, let size = values.fileSize,
              size >= 0, size <= VaultLimits.fileBytes else { throw VaultError.limit }
        let key = try key(data), id = UUID(), fm = FileManager.default
        let entry = Entry(id: id, name: String(currentSource.lastPathComponent.prefix(255)), bytes: size)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try protect(root)
        let pending = root.appendingPathComponent("pending-" + id.uuidString)
        try fm.createDirectory(at: pending, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: pending) }
        try VaultStream.encrypt(currentSource, to: pending.appendingPathComponent("contents"), size: size, key: key, context: "incoming/\(id)")
        let metadata = try VaultCrypto.seal(JSONEncoder().encode(entry), key: key, context: "incoming/\(id)/metadata")
        try metadata.write(to: pending.appendingPathComponent("metadata"), options: .atomic)
        try Task.checkCancellation()
        try fm.moveItem(at: pending, to: folder(id))
        return entry
    }
    public func materialize(_ entry: Entry, key data: Data, to destination: URL) throws {
        let key = try key(data)
        // Reauthenticate this receipt without rescanning the whole batch for every file.
        guard try readEntry(entry.id, key: key) == entry else { throw VaultError.missing }
        try VaultStream.decrypt(folder(entry.id).appendingPathComponent("contents"), to: destination,
                                size: entry.bytes, key: key, context: "incoming/\(entry.id)")
    }
    public func discard(_ id: UUID) throws {
        guard try receivedIDs().contains(id) else { return }
        let url = folder(id)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    private func protect(_ url: URL) throws {
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        var value = url, resources = URLResourceValues(); resources.isExcludedFromBackup = true
        try value.setResourceValues(resources)
        #endif
    }
}
