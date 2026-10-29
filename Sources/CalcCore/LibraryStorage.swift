import Foundation

public struct DuplicateGroup: Identifiable, Equatable, Sendable {
    public let ids: [UUID]
    public var id: UUID { ids[0] }
    public init(ids: [UUID]) { self.ids = ids }
}

public struct LibraryStorageReport: Sendable {
    public let encryptedBytes: Int64
    public let searchBytes: Int64
    public let resourceBytes: [UUID: Int64]
    public init(encryptedBytes: Int64, searchBytes: Int64, resourceBytes: [UUID: Int64]) {
        self.encryptedBytes = encryptedBytes; self.searchBytes = searchBytes; self.resourceBytes = resourceBytes
    }
    public func bytes(for item: VaultItem) -> Int64 {
        Set([item.id, item.companionID, item.thumbnailID].compactMap { $0 }).reduce(0) { $0 + (resourceBytes[$1] ?? 0) }
    }
}

public enum StorageBudget {
    public static let reserve: Int64 = 64 * 1024 * 1024
    public static func required(sourceBytes: Int64, copies: Int64) -> Int64 {
        let (total, overflow) = max(0, sourceBytes).multipliedReportingOverflow(by: max(0, copies))
        let (result, reserveOverflow) = total.addingReportingOverflow(reserve)
        return overflow || reserveOverflow ? Int64.max : result
    }
}
