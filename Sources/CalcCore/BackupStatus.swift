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
