import Foundation

public enum AppPreferences {
    public static let remindersKey = "privateBackupReminders"
    public static let cellularKey = "cloudUseCellular"
    public static func reminders(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: remindersKey) as? Bool ?? true
    }
    public static func cellular(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: cellularKey) as? Bool ?? true
    }
    public static func register(in defaults: UserDefaults = .standard) {
        // Registration supplies missing values without overwriting an explicit opt-out.
        defaults.register(defaults: [remindersKey: true, cellularKey: true])
    }
}
