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
    public let catalogSHA256: String?
    public let checked: Date
    public let items: Int
    public init(source: String, snapshotID: String, catalogSHA256: String? = nil, checked: Date = Date(), items: Int) {
        self.source = source; self.snapshotID = snapshotID; self.catalogSHA256 = catalogSHA256
        self.checked = checked; self.items = items
    }
    public func matchesFiles(digest: String) -> Bool {
        !digest.isEmpty && source == "Files" && snapshotID == digest
    }
    public func matchesCloud(provider: CloudProvider, receipt: CloudReceipt) -> Bool {
        guard let snapshotID = receipt.snapshotID, let catalogSHA256 = receipt.catalogSHA256, !catalogSHA256.isEmpty else { return false }
        return source == provider.title && self.snapshotID == snapshotID.uuidString && self.catalogSHA256 == catalogSHA256
    }
}

public enum BackupCoverage {
    public static func pending(eligible: Set<UUID>, saved: Set<UUID>, changed: Bool, sameLibrary: Bool) -> Int {
        guard sameLibrary, !changed else { return eligible.count }
        return eligible.subtracting(saved).count
    }
}
