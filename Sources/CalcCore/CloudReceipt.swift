import Foundation

public struct CloudReceipt: Codable, Sendable {
    public var objects: Set<String> = []
    public var itemIDs: Set<UUID> = []
    public var saved: Date?
    public var vaultID: UUID?
    public var needsBackup = true
    public var snapshotID: UUID? = nil
    public init() {}
    public func matches(libraryID: UUID?) -> Bool {
        guard let libraryID else { return false }
        return vaultID == libraryID
    }
}
