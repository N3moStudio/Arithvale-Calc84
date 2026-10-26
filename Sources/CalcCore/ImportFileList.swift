import Foundation

/// Enumerates regular files only. Never follows links or removes a source directory.
public enum ImportFileList {
    public static func expand(_ selections: [URL], limit: Int = VaultLimits.itemCount) throws -> [URL] {
        var result: [URL] = [], seen = Set<URL>()
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .isPackageKey]
        func append(_ file: URL) throws {
            let values = try file.resourceValues(forKeys: keys)
            guard values.isSymbolicLink != true, values.isRegularFile == true else { return }
            if seen.insert(file.standardizedFileURL).inserted {
                guard result.count < limit else { throw VaultError.limit }
                result.append(file)
            }
        }
        for selection in selections {
            try Task.checkCancellation()
            let values = try selection.resourceValues(forKeys: keys)
            guard values.isSymbolicLink != true else { continue }
            if values.isDirectory == true {
                guard values.isPackage != true else { continue }
                var enumerationError: Error?
                guard let enumerator = FileManager.default.enumerator(at: selection,
                    includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles, .skipsPackageDescendants],
                    errorHandler: { _, error in enumerationError = error; return false }) else { throw VaultError.missing }
                for case let file as URL in enumerator {
                    try Task.checkCancellation()
                    try append(file)
                }
                if let enumerationError { throw enumerationError }
            } else { try append(selection) }
        }
        return result.sorted { $0.path < $1.path }
    }
}
