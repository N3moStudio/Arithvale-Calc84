#if os(iOS)
import Foundation
import SwiftUI
import CalcCore

enum StoragePreflight {
    static func available() throws -> Int64? {
        try URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
    }
    static func require(bytes: Int64) throws {
        // Application Support may not exist on an empty installation. The app's
        // home already exists on the same volume, including in LiveContainer.
        guard let available = try available() else { return }
        let needed = StorageBudget.required(sourceBytes: bytes, copies: 1)
        guard available >= needed else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError,
                userInfo: [NSLocalizedDescriptionKey: "Free up at least " + ByteCountFormatter.string(fromByteCount: needed - available, countStyle: .file) + " on this phone, then try again. Your existing files are unchanged."])
        }
    }
}

struct StorageEstimateView: View {
    let bytes: Int64
    var copies: Int64 = 3
    @State private var available: Int64?
    private var needed: Int64 { StorageBudget.required(sourceBytes: bytes, copies: copies) }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Allow about " + ByteCountFormatter.string(fromByteCount: needed, countStyle: .file) + " free", systemImage: "internaldrive")
            if let available {
                Text(ByteCountFormatter.string(fromByteCount: available, countStyle: .file) + " available on this phone")
                if available < needed { Text("Free up space before continuing.").fontWeight(.semibold) }
            }
            Text("Includes temporary encrypted copies and working space. Space is checked again when the operation starts.")
        }.font(.footnote).foregroundStyle(.secondary)
            .task { available = try? StoragePreflight.available() }
    }
}
#endif
