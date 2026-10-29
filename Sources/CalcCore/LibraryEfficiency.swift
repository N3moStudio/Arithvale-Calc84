import Foundation

public enum LibraryEfficiency {
    public static func allowsOptionalWork(active: Bool, lowPower: Bool, thermallyLimited: Bool) -> Bool {
        active && !lowPower && !thermallyLimited
    }
    /// Reminders stay inside the unlocked library and never claim cloud coverage.
    public static func needsReminder(enabled: Bool, unlocked: Bool, hasItems: Bool, changed: Bool,
                                     now: Date, lastBackup: Date?, snoozedUntil: Date?) -> Bool {
        guard enabled, unlocked, hasItems, changed else { return false }
        if let snoozedUntil, now < snoozedUntil { return false }
        if let lastBackup, now.timeIntervalSince(lastBackup) < 7 * 24 * 60 * 60 { return false }
        return true
    }
}
