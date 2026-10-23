import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// Bounded-memory verification shared by folder backups and the system Save picker.
public enum BackupCopy {
    public static func digest(_ url: URL) throws -> Data {
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        var hash = SHA256()
        while let bytes = try input.read(upToCount: 1024 * 1024), !bytes.isEmpty { hash.update(data: bytes) }
        return Data(hash.finalize())
    }

    public static func verify(_ url: URL, expected: Data) throws {
        guard try digest(url) == expected else { throw VaultError.invalidBackup }
    }

    /// Never replaces an earlier snapshot. Removes only a copy created by this operation.
    public static func copy(_ source: URL, to destination: URL) throws {
        let expected = try digest(source)
        try FileManager.default.copyItem(at: source, to: destination)
        do { try verify(destination, expected: expected) }
        catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
}
