import Foundation

/// File selection is based on archive bytes, not a host app's UTI registration.
/// Full authentication still happens in VaultRepository.restore/verifyBackup.
public enum BackupFileProbe {
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
