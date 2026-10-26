import Foundation

/// One durable, encrypted handoff. Call serially (the app owns it in an actor).
/// Receiving is not authentication; only restore/test with the key authenticates it.
public struct BackupInbox: Sendable {
    public struct Entry: Sendable, Equatable {
        public let url: URL
        public let displayName: String
    }
    public enum InboxError: LocalizedError {
        case localFileRequired, occupied
        public var errorDescription: String? {
            switch self {
            case .localFileRequired: return "Share the downloaded backup file itself, not a link or a folder."
            case .occupied: return "A shared backup is already waiting. Use it or remove its received copy before sharing another."
            }
        }
    }
    private struct Metadata: Codable { let displayName: String }
    public let root: URL
    private var received: URL { root.appendingPathComponent("received", isDirectory: true) }
    public init(root: URL) { self.root = root }

    public static func requireLocalFile(_ url: URL) throws {
        guard url.isFileURL, url.host == nil || url.host == "" || url.host == "localhost" else {
            throw InboxError.localFileRequired
        }
    }
    public func load() throws -> Entry? {
        guard FileManager.default.fileExists(atPath: root.path) else { return nil }
        try requireDirectory(root)
        // A process killed during copying leaves only an unpublished staging folder.
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
            let name = url.lastPathComponent
            if name.hasPrefix("pending-"), UUID(uuidString: String(name.dropFirst(8))) != nil {
                try FileManager.default.removeItem(at: url)
            }
        }
        guard FileManager.default.fileExists(atPath: received.path) else { return nil }
        try requireDirectory(received)
        let metadata = received.appendingPathComponent("name.json")
        let values = try metadata.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size <= 4096 else { throw VaultError.invalidBackup }
        let name = try JSONDecoder().decode(Metadata.self, from: Data(contentsOf: metadata)).displayName
        guard !name.isEmpty, name.count <= 255 else { throw VaultError.invalidBackup }
        let url = received.appendingPathComponent("archive.c84backup")
        try BackupFileProbe.validate(url)
        return Entry(url: url, displayName: name)
    }
    public func receive(_ source: URL) throws -> Entry {
        try Self.requireLocalFile(source)
        try BackupFileProbe.validate(source)
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try requireDirectory(root)
        try protect(root)
        guard !fm.fileExists(atPath: received.path) else { throw InboxError.occupied }
        let staging = root.appendingPathComponent("pending-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: staging) }
        try protect(staging)
        let archive = staging.appendingPathComponent("archive.c84backup")
        try Task.checkCancellation()
        try BackupCopy.copy(source, to: archive)
        try BackupFileProbe.validate(archive)
        try protect(archive)
        let name = String(source.lastPathComponent.prefix(255))
        let metadata = staging.appendingPathComponent("name.json")
        try JSONEncoder().encode(Metadata(displayName: name)).write(to: metadata, options: .atomic)
        try protect(metadata)
        try Task.checkCancellation()
        // Same-volume rename publishes only a complete, verified encrypted copy.
        try fm.moveItem(at: staging, to: received)
        return Entry(url: received.appendingPathComponent("archive.c84backup"), displayName: name)
    }
    public func discard() throws {
        // Only this private received copy; never the URL supplied by Files.
        if FileManager.default.fileExists(atPath: received.path) {
            try requireDirectory(root)
            try FileManager.default.removeItem(at: received)
        }
    }
    private func requireDirectory(_ url: URL) throws {
        let value = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard value.isDirectory == true, value.isSymbolicLink != true else { throw VaultError.invalidBackup }
    }
    private func protect(_ url: URL) throws {
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        var excluded = url; var values = URLResourceValues(); values.isExcludedFromBackup = true
        try excluded.setResourceValues(values)
        #endif
    }
}
