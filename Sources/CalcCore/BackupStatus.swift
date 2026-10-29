import Foundation

public struct BackupDestinationStatus: Sendable {
    public let name: String
    public let saved: Date?
    public let needsBackup: Bool
    public let connected: Bool
    public init(name: String, saved: Date?, needsBackup: Bool, connected: Bool = true) {
        self.name = name; self.saved = saved; self.needsBackup = needsBackup; self.connected = connected
    }
    public var current: Bool { connected && saved != nil && !needsBackup }
}
public enum BackupStatus {
    public static func summary(_ destinations: [BackupDestinationStatus]) -> String {
        let current = destinations.filter(\.current).sorted { $0.saved! > $1.saved! }
        if let latest = current.first { return latest.name + " backup checked" }
        return destinations.contains { $0.connected && $0.saved != nil } ? "Back up changes" : "Back up"
    }
}

public struct RecoveryCheck: Codable, Equatable, Sendable {
    public let source: String
    public let snapshotID: String
    public let checked: Date
    public let items: Int
    public init(source: String, snapshotID: String, checked: Date = Date(), items: Int) {
        self.source = source; self.snapshotID = snapshotID; self.checked = checked; self.items = items
    }
    public func matches(source: String, snapshotID: String?) -> Bool {
        guard let snapshotID, !snapshotID.isEmpty else { return false }
        return self.source == source && self.snapshotID == snapshotID
    }
}

public enum BackupCoverage {
    public static func pending(eligible: Set<UUID>, saved: Set<UUID>, changed: Bool, sameLibrary: Bool) -> Int {
        guard sameLibrary, !changed else { return eligible.count }
        return eligible.subtracting(saved).count
    }
}
