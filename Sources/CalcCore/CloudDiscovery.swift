import Foundation

public struct CloudListingPage: Sendable {
    public let paths: [String]
    public let next: String?
    public init(paths: [String], next: String?) { self.paths = paths; self.next = next }
}

/// No encrypted index or media inventory is retained for a picker row.
public struct CloudSnapshotSummary: Identifiable, Sendable {
    public let id: UUID
    public let vaultID: UUID
    public let created: Date
    public let path: String
    public let bytes: Int64
    public init(_ snapshot: CloudSnapshot) {
        id = snapshot.id; vaultID = snapshot.vaultID; created = snapshot.created
        path = snapshot.path; bytes = snapshot.records.reduce(0) { $0 + Int64($1.bytes) }
    }
}

public enum CloudDiscovery {
    public static let pageSize = 40
    public static func load(path: String, store: any CloudStore, scratch: URL) async throws -> CloudSnapshot {
        // Never follow arbitrary paths advertised by an account listing.
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 5, parts[0] == "c84", parts[1] == "v1", parts[3] == "snapshots",
              UUID(uuidString: String(parts[2])) != nil, path.hasSuffix(".c84cloud"),
              UUID(uuidString: String(parts[4].dropLast(9))) != nil else { throw VaultError.invalidBackup }
        let file = scratch.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        guard let size = try await store.size(path: path) else { throw CloudError.missing }
        guard size > 0, size <= 8 * 1024 * 1024 else { throw VaultError.limit }
        try await store.download(path: path, to: file, maximum: 8 * 1024 * 1024)
        try Task.checkCancellation()
        let snapshot = try CloudSnapshot.decode(Data(contentsOf: file))
        guard snapshot.path == path else { throw VaultError.invalidBackup }
        return snapshot
    }
    public static func isDamagedCatalog(_ error: Error) -> Bool {
        if error is DecodingError { return true }
        if let error = error as? VaultError {
            switch error { case .invalidBackup, .limit: return true; default: return false }
        }
        if let error = error as? CloudError, case .missing = error { return true }
        return false // Authentication, transport, disk errors and cancellation must reach Retry.
    }
    public static func scan(_ page: CloudListingPage, store: any CloudStore, scratch: URL,
                            found: @Sendable (CloudSnapshotSummary) async -> Void,
                            skipped: @Sendable () async -> Void) async throws {
        guard page.paths.count <= pageSize else { throw CloudError.service }
        for path in page.paths {
            try Task.checkCancellation()
            do { await found(CloudSnapshotSummary(try await load(path: path, store: store, scratch: scratch))) }
            catch {
                try Task.checkCancellation()
                guard isDamagedCatalog(error) else { throw error }
                await skipped()
            }
        }
    }
}
