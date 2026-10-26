import Foundation

/// Owned by the setup screen's identity, including its child navigation.
/// Explicit cancellation/lock destroys the screen; navigating back preserves the key.
public struct SetupSession: Sendable {
    public private(set) var recovery = VaultCode.generateRecovery()
    public var confirmation = ""
    public var saved = false
    public init() {}
    public var canCreate: Bool {
        let key = VaultCode.normalizeRecovery(recovery)
        return VaultCode.validRecovery(key) && saved && confirmation.uppercased() == String(key.suffix(8))
    }
    public mutating func clear() { recovery = ""; confirmation = ""; saved = false }
}
