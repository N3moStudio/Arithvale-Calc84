import Foundation

/// The persisted device-code throttle is unchanged; ordinary calculator attempts
/// remain silent and only explicit access settings explain an active delay.
public enum DeviceAccessBackoff {
    public static func delay(failures: Int) -> TimeInterval? {
        guard failures >= 5 else { return nil }
        return min(300, 30 * pow(2, Double(min(failures - 5, 4))))
    }
}
