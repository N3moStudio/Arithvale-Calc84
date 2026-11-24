import Foundation

public struct CloudListingPage: Sendable {
    public let paths: [String]
    public let next: String?
    public init(paths: [String], next: String?) { self.paths = paths; self.next = next }
}

/// No encrypted index or media inventory is retained for a picker row.
public struct CloudSnapshotSummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let vaultID: UUID
    public let created: Date
    public let path: String
    public let bytes: Int64
    public let catalogSHA256: String
    init(_ snapshot: CloudSnapshot, catalogSHA256: String) {
        id = snapshot.id; vaultID = snapshot.vaultID; created = snapshot.created
        path = snapshot.path; bytes = snapshot.records.reduce(0) { $0 + Int64($1.bytes) }
        self.catalogSHA256 = catalogSHA256
    }
}

public enum CloudDiscovery {
    public static let pageSize = 40

    public enum CatalogError: LocalizedError {
        case changed
        public var errorDescription: String? { "The cloud catalog has changed. Find Backups again to review the available copies." }
    }

    public struct Catalog: Sendable {
        public let snapshot: CloudSnapshot
        public let sha256: String

        fileprivate func validate(receipt: CloudReceipt?) throws {
            guard let receipt, receipt.vaultID == snapshot.vaultID, receipt.snapshotID == snapshot.id,
                  let expected = receipt.catalogSHA256 else { return }
            guard expected == sha256 else { throw CatalogError.changed }
        }
    }

    public static func load(_ summary: CloudSnapshotSummary, store: any CloudStore, scratch: URL,
                            receipt: CloudReceipt? = nil) async throws -> Catalog {
        let catalog = try await loadCatalog(path: summary.path, store: store, scratch: scratch)
        guard catalog.sha256 == summary.catalogSHA256 else { throw CatalogError.changed }
        try catalog.validate(receipt: receipt)
        return catalog
    }

    private static func loadCatalog(path: String, store: any CloudStore, scratch: URL) async throws -> Catalog {
        // Never follow arbitrary paths advertised by an account listing.
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 5, parts[0] == "c84", parts[1] == "v1", parts[3] == "snapshots",
              UUID(uuidString: String(parts[2])) != nil, path.hasSuffix(".c84cloud"),
              UUID(uuidString: String(parts[4].dropLast(9))) != nil else { throw VaultError.invalidBackup }
        let file = scratch.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        guard let size = try await store.size(path: path) else { throw CloudError.missing }
        guard size > 0, size <= CloudSnapshot.maximumBytes else { throw VaultError.limit }
        try await store.download(path: path, to: file, maximum: CloudSnapshot.maximumBytes)
        try Task.checkCancellation()
        let data = try Data(contentsOf: file)
        let snapshot = try CloudSnapshot.decode(data)
        guard snapshot.path == path else { throw VaultError.invalidBackup }
        return Catalog(snapshot: snapshot, sha256: CloudBackup.catalogSHA256(data))
    }
    public static func isDamagedCatalog(_ error: Error) -> Bool {
        if error is DecodingError || error is CatalogError { return true }
        if let error = error as? VaultError {
            switch error { case .invalidBackup, .limit: return true; default: return false }
        }
        if let error = error as? CloudError, case .missing = error { return true }
        return false // Authentication, transport, disk errors and cancellation must reach Retry.
    }
    public static func scan(_ page: CloudListingPage, store: any CloudStore, scratch: URL,
                            receipt: CloudReceipt? = nil,
                            found: @Sendable (CloudSnapshotSummary) async -> Void,
                            skipped: @Sendable () async -> Void) async throws {
        guard page.paths.count <= pageSize else { throw CloudError.service }
        for path in page.paths {
            try Task.checkCancellation()
            do {
                let catalog = try await loadCatalog(path: path, store: store, scratch: scratch)
                try catalog.validate(receipt: receipt)
                await found(CloudSnapshotSummary(catalog.snapshot, catalogSHA256: catalog.sha256))
            } catch {
                try Task.checkCancellation()
                guard isDamagedCatalog(error) else { throw error }
                await skipped()
            }
        }
    }
}
