import Foundation

/// Only ciphertext, opaque identifiers, lengths and hashes leave the vault.
/// Each immutable catalog is published LAST, after every referenced object is checked.
public struct CloudRecord: Codable, Equatable, Sendable {
    public let id: UUID
    public let bytes: Int
    public let sha256: String
    public var filename: String { id.uuidString + "-" + sha256 + ".enc" }
}

public struct CloudSnapshot: Codable, Sendable {
    public var version = 1
    public let id: UUID
    public let vaultID: UUID
    public let created: Date
    public let header: Data
    public let index: Data
    public let records: [CloudRecord]
    public var prefix: String { "c84/v1/" + vaultID.uuidString + "/" }
    public var path: String { prefix + "snapshots/" + id.uuidString + ".c84cloud" }
    public func objectPath(_ record: CloudRecord) -> String { prefix + "objects/" + record.filename }
    public func validate() throws {
        guard version == 1, created.timeIntervalSince1970.isFinite,
              header.count <= 4096, index.count <= VaultLimits.manifestBytes,
              records.count <= VaultLimits.itemCount,
              Set(records.map(\.id)).count == records.count,
              records.allSatisfy({ $0.bytes >= 28 && $0.bytes <= VaultStream.encryptedSize(VaultLimits.fileBytes)
                  && $0.sha256.count == 64 && $0.sha256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) }),
              records.reduce(Int64(0), { $0 + Int64($1.bytes) }) <= Int64(VaultLimits.backupBytes) else { throw VaultError.invalidBackup }
        let decoded = try JSONDecoder().decode(VaultHeader.self, from: header)
        try decoded.validate()
        guard decoded.id == vaultID else { throw VaultError.invalidBackup }
    }
    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= 8 * 1024 * 1024 else { throw VaultError.limit }
        let snapshot = try JSONDecoder().decode(Self.self, from: data)
        try snapshot.validate(); return snapshot
    }
}

public struct CloudPlan: Sendable {
    public let snapshot: CloudSnapshot
    public let sources: [UUID: URL]
    public let itemIDs: Set<UUID>
}

public enum CloudBackup {
    public static func hash(_ url: URL) throws -> String { try BackupCopy.digest(url).map { String(format: "%02x", $0) }.joined() }
    /// Convert a downloaded set to the existing, independently recoverable archive.
    /// The repository's restore then authenticates all bytes with the recovery key.
    public static func assemble(_ snapshot: CloudSnapshot, objects: [UUID: URL], to destination: URL) throws {
        try snapshot.validate()
        let output = try VaultStream.newFile(destination)
        var finished = false
        defer { try? output.close(); if !finished { try? FileManager.default.removeItem(at: destination) } }
        try output.write(contentsOf: Data("C84B0002".utf8))
        try VaultStream.block(snapshot.header, to: output)
        try VaultStream.block(snapshot.index, to: output)
        try VaultStream.number(UInt64(snapshot.records.count), to: output)
        for record in snapshot.records {
            try Task.checkCancellation()
            guard let url = objects[record.id], try url.resourceValues(forKeys: [.fileSizeKey]).fileSize == record.bytes,
                  try hash(url) == record.sha256 else { throw VaultError.invalidBackup }
            try output.write(contentsOf: Data(record.id.uuidString.utf8))
            try VaultStream.number(UInt64(record.bytes), to: output)
            let input = try FileHandle(forReadingFrom: url)
            defer { try? input.close() }
            try VaultStream.copy(input, to: output, count: record.bytes)
        }
        try output.synchronize(); finished = true
    }
}

public enum CloudError: Error, LocalizedError {
    case unsafeEndpoint, authentication, permission, quota, retry, service, missing, configuration
    public var errorDescription: String? {
        switch self {
        case .unsafeEndpoint: return "The service returned an unsupported or insecure connection. No files or login tokens were sent to it."
        case .authentication: return "Sign in again. Check your email, password, and verification code."
        case .permission: return "This account did not allow access to its backup folder. Check your account, then reconnect."
        case .quota: return "The account is out of storage or transfer allowance. Free up space or wait for the service to reset its allowance."
        case .retry: return "The service is busy. Try again later; completed files will be reused."
        case .service: return "The service did not complete the request. Your local library and previous backups are unchanged."
        case .missing: return "A backup file is missing. Choose another saved backup."
        case .configuration: return "Finish connecting this service first."
        }
    }
}

/// Remote deletion is deliberately absent. Phone deletions never remove backups.
public protocol CloudStore: Sendable {
    func refresh() async throws
    func listPage(prefix: String, after: String?, limit: Int) async throws -> CloudListingPage
    func size(path: String) async throws -> Int?
    func upload(file: URL, path: String) async throws
    func download(path: String, to: URL, maximum: Int) async throws
}
public extension CloudStore { func refresh() async throws {} }

public struct CloudTransferProgress: Sendable {
    public let completed: Int
    public let total: Int
    public let phase: String
    public var completedBytes: Int64 = 0
    public var totalBytes: Int64 = 0
}

public enum CloudTransfer {
    /// Checks existing objects too: a local receipt is not proof of remote durability.
    /// Verification costs download bandwidth, but does not trust upload acknowledgements.
    public static func upload(_ plan: CloudPlan, store: any CloudStore, scratch: URL, previouslyVerified: Set<String> = [],
                              verified: @Sendable (String) async -> Void = { _ in },
                              progress: @Sendable (CloudTransferProgress) async -> Void) async throws {
        try plan.snapshot.validate()
        try await store.refresh()
        let total = plan.snapshot.records.count + 1
        let totalBytes = plan.snapshot.records.reduce(Int64(0)) { $0 + Int64($1.bytes) }
        var completedBytes: Int64 = 0
        for (position, record) in plan.snapshot.records.enumerated() {
            try Task.checkCancellation()
            defer { completedBytes += Int64(record.bytes) }
            let path = plan.snapshot.objectPath(record)
            await progress(.init(completed: position, total: total, phase: "Checking encrypted files", completedBytes: completedBytes, totalBytes: totalBytes))
            var matches = false
            if try await store.size(path: path) == record.bytes {
                if previouslyVerified.contains(record.filename) { continue }
                let check = scratch.appendingPathComponent(UUID().uuidString)
                defer { try? FileManager.default.removeItem(at: check) }
                try await store.download(path: path, to: check, maximum: record.bytes)
                matches = try CloudBackup.hash(check) == record.sha256
            }
            if !matches {
                guard let source = plan.sources[record.id] else { throw VaultError.missing }
                await progress(.init(completed: position, total: total, phase: "Uploading encrypted files", completedBytes: completedBytes, totalBytes: totalBytes))
                try await store.upload(file: source, path: path)
                try Task.checkCancellation()
                let check = scratch.appendingPathComponent(UUID().uuidString)
                defer { try? FileManager.default.removeItem(at: check) }
                await progress(.init(completed: position, total: total, phase: "Checking downloaded copy", completedBytes: completedBytes, totalBytes: totalBytes))
                try await store.download(path: path, to: check, maximum: record.bytes)
                guard try CloudBackup.hash(check) == record.sha256 else { throw VaultError.invalidBackup }
            }
            await verified(record.filename)
        }
        try Task.checkCancellation()
        let catalog = scratch.appendingPathComponent(UUID().uuidString)
        let readBack = scratch.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: catalog); try? FileManager.default.removeItem(at: readBack) }
        let data = try JSONEncoder().encode(plan.snapshot)
        try data.write(to: catalog, options: .withoutOverwriting)
        await progress(.init(completed: total - 1, total: total, phase: "Saving recovery catalog", completedBytes: totalBytes, totalBytes: totalBytes))
        try await store.upload(file: catalog, path: plan.snapshot.path)
        try await store.download(path: plan.snapshot.path, to: readBack, maximum: 8 * 1024 * 1024)
        guard try Data(contentsOf: readBack) == data else { throw VaultError.invalidBackup }
        await progress(.init(completed: total, total: total, phase: "Backup verified", completedBytes: totalBytes, totalBytes: totalBytes))
    }
    public static func download(_ snapshot: CloudSnapshot, store: any CloudStore, scratch: URL,
                                destination: URL, progress: @Sendable (CloudTransferProgress) async -> Void) async throws {
        try snapshot.validate()
        var objects: [UUID: URL] = [:]
        defer { for url in objects.values { try? FileManager.default.removeItem(at: url) } }
        for (position, record) in snapshot.records.enumerated() {
            try Task.checkCancellation()
            await progress(.init(completed: position, total: snapshot.records.count + 1, phase: "Downloading encrypted files"))
            let url = scratch.appendingPathComponent(UUID().uuidString)
            objects[record.id] = url
            try await store.download(path: snapshot.objectPath(record), to: url, maximum: record.bytes)
        }
        await progress(.init(completed: snapshot.records.count, total: snapshot.records.count + 1, phase: "Checking recovery files"))
        try CloudBackup.assemble(snapshot, objects: objects, to: destination)
    }
}
