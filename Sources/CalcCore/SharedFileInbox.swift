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
    public func entries(key data: Data) throws -> [Entry] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        let key = try key(data)
        return try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).compactMap { url in
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            return try readEntry(id, key: key)
        }.sorted { $0.id.uuidString < $1.id.uuidString }
    }
    private func readEntry(_ id: UUID, key: SymmetricKey) throws -> Entry {
        let metadata = folder(id).appendingPathComponent("metadata")
        let size = try metadata.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size <= 4096 else { throw VaultError.invalidBackup }
        let entry = try JSONDecoder().decode(Entry.self, from: VaultCrypto.open(Data(contentsOf: metadata), key: key, context: "incoming/\(id)/metadata"))
        guard entry.id == id, entry.bytes >= 0, entry.bytes <= VaultLimits.fileBytes,
              entry.name == URL(fileURLWithPath: entry.name).lastPathComponent,
              entry.name != ".", entry.name != "..", !entry.name.isEmpty else { throw VaultError.invalidBackup }
        return entry
    }
    public func receive(_ source: URL, key data: Data) throws -> Entry {
        try BackupInbox.requireLocalFile(source)
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true, let size = values.fileSize,
              size >= 0, size <= VaultLimits.fileBytes else { throw VaultError.limit }
        let key = try key(data), id = UUID(), fm = FileManager.default
        let entry = Entry(id: id, name: String(source.lastPathComponent.prefix(255)), bytes: size)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try protect(root)
        let pending = root.appendingPathComponent("pending-" + id.uuidString)
        try fm.createDirectory(at: pending, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: pending) }
        try VaultStream.encrypt(source, to: pending.appendingPathComponent("contents"), size: size, key: key, context: "incoming/\(id)")
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
