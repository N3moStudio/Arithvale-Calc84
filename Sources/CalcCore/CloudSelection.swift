import Foundation

public enum CloudProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case blomp, mega
    public var id: String { rawValue }
    public var title: String { self == .blomp ? "Blomp" : "MEGA" }
}

/// Stored only inside the encrypted manifest. Missing preferences are manual/empty.
public struct CloudBackupPolicy: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, Sendable { case manual, automatic }
    public var mode: Mode
    public var selected: Set<UUID>
    public var blocked: Set<UUID>
    public init(mode: Mode = .manual, selected: Set<UUID> = [], blocked: Set<UUID> = []) {
        self.mode = mode; self.selected = selected; self.blocked = blocked
    }
    public func includes(_ item: VaultItem) -> Bool {
        item.visible && item.deletedAt == nil && !blocked.contains(item.id)
            && (mode == .automatic || selected.contains(item.id))
    }
    public func itemIDs(in items: [VaultItem]) -> Set<UUID> { Set(items.filter(includes).map(\.id)) }
}

public struct CloudPreferences: Codable, Equatable, Sendable {
    public var blomp = CloudBackupPolicy()
    public var mega = CloudBackupPolicy()
    public init() {}
    public subscript(_ provider: CloudProvider) -> CloudBackupPolicy {
        get { provider == .blomp ? blomp : mega }
        set { if provider == .blomp { blomp = newValue } else { mega = newValue } }
    }
    func validate(items: [VaultItem]) throws {
        let ids = Set(items.filter(\.visible).map(\.id))
        for provider in CloudProvider.allCases {
            let policy = self[provider]
            guard policy.selected.isSubset(of: ids), policy.blocked.isSubset(of: ids) else { throw VaultError.invalidBackup }
        }
    }
    mutating func remove(_ ids: Set<UUID>) {
        for provider in CloudProvider.allCases {
            self[provider].selected.subtract(ids); self[provider].blocked.subtract(ids)
        }
    }
}
