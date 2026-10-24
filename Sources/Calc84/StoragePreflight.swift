#if os(iOS)
import Foundation

enum StoragePreflight {
    static func require(bytes: Int64) throws {
        // Application Support may not exist on an empty installation. The app's
        // home already exists on the same volume, including in LiveContainer.
        let root = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let values = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let available = values.volumeAvailableCapacityForImportantUsage else { return }
        let needed = max(0, bytes) + 64 * 1024 * 1024
        guard available >= needed else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError,
                userInfo: [NSLocalizedDescriptionKey: "Free up at least " + ByteCountFormatter.string(fromByteCount: needed - available, countStyle: .file) + " on this phone, then try again. Your existing files are unchanged."])
        }
    }
}
#endif
