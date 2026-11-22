import Foundation

/// Serial ownership survives a UI generation change until cancellation unwinds.
/// A duplicate or stale completion can never release a newer operation.
public struct VaultOperationGate: Sendable {
    public private(set) var owner: UUID?
    public init() {}
    public mutating func begin() -> UUID? {
        guard owner == nil else { return nil }
        let token = UUID(); owner = token; return token
    }
    @discardableResult public mutating func end(_ token: UUID) -> Bool {
        guard owner == token else { return false }
        owner = nil; return true
    }
}
