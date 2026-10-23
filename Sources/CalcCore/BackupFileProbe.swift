import Foundation

/// File selection is based on archive bytes, not a host app's UTI registration.
/// Full authentication still happens in VaultRepository.restore/verifyBackup.
public enum BackupFileProbe {
    /// List candidates without reading their bytes or depending on a custom UTI.
    /// A cloud placeholder is downloaded only when the user selects that file.
    public static func files(in folder: URL) throws -> [URL] {
        let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else { throw VaultError.invalidBackup }
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey]
        let candidates = try FileManager.default.contentsOfDirectory(at: folder,
            includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
        guard candidates.count <= 10_000 else { throw VaultError.limit }
        return try candidates.filter { url in
            try Task.checkCancellation()
            let resource = try url.resourceValues(forKeys: keys)
            return resource.isRegularFile == true && resource.isSymbolicLink != true
        }.sorted {
            let left = $0.pathExtension.lowercased() == "c84backup"
            let right = $1.pathExtension.lowercased() == "c84backup"
            if left != right { return left }
            return $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    public static func validate(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size >= 8, size <= VaultLimits.backupBytes else { throw VaultError.invalidBackup }
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        let magic = try input.read(upToCount: 8)
        guard magic == Data("C84B0001".utf8) || magic == Data("C84B0002".utf8) else { throw VaultError.invalidBackup }
    }
}
