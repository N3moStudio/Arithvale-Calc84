#if os(iOS)
import Foundation

enum StoragePreflight {
    static func require(bytes: Int64) throws {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
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
