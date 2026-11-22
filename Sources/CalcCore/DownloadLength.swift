import Foundation

/// Transfer completeness is separate from the authenticated archive/digest check.
public enum DownloadLength {
    public static func validate(actual: Int, expected: Int, maximum: Int) throws {
        guard maximum >= 0, expected >= 0, expected <= maximum,
              actual >= 0, actual == expected else { throw VaultError.invalidBackup }
    }
}
