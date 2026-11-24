import Foundation

public struct CloudReceipt: Codable, Sendable {
    public var objects: Set<String> = []
    public var itemIDs: Set<UUID> = []
    public var saved: Date?
    public var vaultID: UUID?
    public var needsBackup = true
    public var snapshotID: UUID? = nil
    public var catalogSHA256: String? = nil
    public var revision: Data? = nil
    public init() {}
    public func matches(libraryID: UUID?) -> Bool {
        guard let libraryID else { return false }
        return vaultID == libraryID
    }
    func covers(revision: Data, libraryID: UUID) -> Bool {
        matches(libraryID: libraryID) && saved != nil && snapshotID != nil && self.revision == revision
    }
}
