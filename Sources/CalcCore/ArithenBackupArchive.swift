import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Portable archive: authenticated duplicate catalogs bracket independently
/// hashed ciphertext resources. Existing resource AEAD remains unchanged.
public enum ArithenBackupArchive {
    public static let magic = Data("ARITHB03".utf8)
    public static let footerMagic = Data("ARITHEND".utf8)
    // A 4 MiB encrypted index is Base64 encoded inside an encrypted catalog,
    // itself Base64 encoded in the envelope. 12 MiB bounds both encoding layers.
    public static let envelopeLimit = 12 * 1024 * 1024
    private static let headerLimit = 4096

    public struct Record: Codable, Equatable, Sendable {
        public let id: UUID
        public let bytes: Int
        public let sha256: String
        public init(id: UUID, bytes: Int, sha256: String) { self.id = id; self.bytes = bytes; self.sha256 = sha256 }
    }
    public struct Prepared: Sendable {
        public let envelope: Data
        public let records: [Record]
        /// Cloud transport may reconstruct this from an existing encrypted plan.
        /// The writer checks structure and bytes; only read authenticates its catalog.
        public init(envelope: Data, records: [Record]) { self.envelope = envelope; self.records = records }
    }
    public struct Opened: Sendable {
        public let header: Data
        public let index: Data
        public let records: [Record]
        public let key: SymmetricKey
        public let bodyStart: UInt64
        public let metadataRecovered: Bool
        public let snapshotID: UUID
        fileprivate let archiveSize: UInt64
    }
    private struct Envelope: Codable {
        let version: Int
        let snapshotID: UUID
        let vaultHeader: Data
        let sealedCatalog: Data
    }
    private struct Catalog: Codable {
        let index: Data
        let records: [Record]
        let headerSHA256: String
    }
    private struct Candidate {
        let raw: Data
        let envelope: Envelope
        let catalog: Catalog
        let key: SymmetricKey
        var bodyStart: UInt64 { UInt64(16 + raw.count) }
        var bodyEnd: UInt64 { bodyStart + catalog.records.reduce(UInt64(0)) { $0 + UInt64($1.bytes) } }
        var expectedSize: UInt64 { bodyEnd + UInt64(raw.count + 16) }
    }

    public static func prepare(header: Data, index: Data, resources: [UUID: URL], orderedIDs: [UUID], key: SymmetricKey) throws -> Prepared {
        try Task.checkCancellation()
        guard !header.isEmpty, header.count <= headerLimit, index.count >= 28, index.count <= VaultLimits.manifestBytes,
              orderedIDs.count <= VaultLimits.itemCount, Set(orderedIDs).count == orderedIDs.count,
              Set(orderedIDs) == Set(resources.keys) else { throw VaultError.invalidBackup }
        var records: [Record] = []
        var resourceBytes: UInt64 = 0
        for id in orderedIDs {
            try Task.checkCancellation()
            guard let url = resources[id] else { throw VaultError.missing }
            let bytes = try fileSize(url)
            guard bytes >= 28, bytes <= UInt64(VaultStream.encryptedSize(VaultLimits.fileBytes)) else { throw VaultError.limit }
            resourceBytes += bytes
            guard resourceBytes <= UInt64(VaultLimits.backupBytes) else { throw VaultError.limit }
            records.append(.init(id: id, bytes: Int(bytes), sha256: try digestFile(url, count: Int(bytes))))
        }
        return try prepare(header: header, index: index, records: records, key: key)
    }

    /// Reuse resource digests already verified by a cloud plan. The writer still
    /// verifies actual bytes before completing an archive; read authenticates this
    /// catalog before trusting any length, identity or digest.
    public static func prepare(header: Data, index: Data, records: [Record], key: SymmetricKey) throws -> Prepared {
        try Task.checkCancellation()
        guard !header.isEmpty, header.count <= headerLimit, index.count >= 28,
              index.count <= VaultLimits.manifestBytes else { throw VaultError.invalidBackup }
        try validate(records)
        let snapshotID = UUID()
        let catalog = Catalog(index: index, records: records, headerSHA256: digest(header))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let encoded = try encoder.encode(catalog)
        guard encoded.count + 28 <= envelopeLimit else { throw VaultError.limit }
        let sealed = try VaultCrypto.seal(encoded, key: catalogKey(key, snapshotID), context: context(snapshotID))
        let envelope = try encoder.encode(Envelope(version: 3, snapshotID: snapshotID, vaultHeader: header, sealedCatalog: sealed))
        try validateSize(envelope.count, records: records)
        return Prepared(envelope: envelope, records: records)
    }

    public static func write(_ prepared: Prepared, sources: [UUID: URL], to destination: URL) throws {
        try Task.checkCancellation()
        _ = try decodeEnvelope(prepared.envelope)
        try validate(prepared.records)
        try validateSize(prepared.envelope.count, records: prepared.records)
        guard Set(sources.keys) == Set(prepared.records.map(\.id)) else { throw VaultError.invalidBackup }
        let output = try createExclusive(destination)
        var finished = false
        defer { try? output.close(); if !finished { try? FileManager.default.removeItem(at: destination) } }
        try output.write(contentsOf: magic)
        try VaultStream.number(UInt64(prepared.envelope.count), to: output)
        try output.write(contentsOf: prepared.envelope)
        for record in prepared.records {
            guard let url = sources[record.id], try fileSize(url) == UInt64(record.bytes) else { throw VaultError.invalidBackup }
            let input = try FileHandle(forReadingFrom: url)
            defer { try? input.close() }
            try copy(input, count: record.bytes, to: output, expectedDigest: record.sha256)
            guard (try input.read(upToCount: 1) ?? Data()).isEmpty else { throw VaultError.changed }
        }
        try output.write(contentsOf: prepared.envelope)
        try VaultStream.number(UInt64(prepared.envelope.count), to: output)
        try output.write(contentsOf: footerMagic)
        try output.synchronize()
        finished = true
    }

    public static func hasSignature(_ url: URL) throws -> Bool {
        let size = try fileSize(url)
        guard size >= 8, size <= UInt64(VaultLimits.backupBytes) else { return false }
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        if try VaultStream.exact(8, from: input) == magic { return true }
        try input.seek(toOffset: size - 8)
        return try VaultStream.exact(8, from: input) == footerMagic
    }

    /// Authenticate a cloud catalog before trusting its download inventory.
    /// No payload is read here; each resource still needs digest and AEAD checks.
    public static func authenticateEnvelope(_ raw: Data, unlock: (Data) throws -> SymmetricKey) throws -> Opened {
        let value = try authenticate(raw, unlock: unlock)
        return Opened(header: value.envelope.vaultHeader, index: value.catalog.index, records: value.catalog.records,
                      key: value.key, bodyStart: value.bodyStart, metadataRecovered: false,
                      snapshotID: value.envelope.snapshotID, archiveSize: value.expectedSize)
    }

    public static func read(_ url: URL, allowIncompletePayload: Bool = false, unlock: (Data) throws -> SymmetricKey) throws -> Opened {
        try Task.checkCancellation()
        let size = try fileSize(url)
        guard size >= 32, size <= UInt64(VaultLimits.backupBytes) else { throw VaultError.invalidBackup }
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        // Reuse only exact-header keys: the two catalogs normally share a header,
        // so expensive password derivation occurs once without trusting a digest.
        var keys: [Data: SymmetricKey] = [:]
        func candidate(at offset: UInt64, length: UInt64) throws -> Candidate? {
            guard length > 0, length <= UInt64(envelopeLimit), offset <= size, length <= size - offset else { return nil }
            do {
                try Task.checkCancellation()
                try input.seek(toOffset: offset)
                let raw = try VaultStream.exact(Int(length), from: input)
                return try authenticate(raw) { header in
                    if let existing = keys[header] { return existing }
                    let key = try unlock(header); keys[header] = key; return key
                }
            } catch is CancellationError { throw CancellationError() }
            catch { return nil }
        }
        var front: Candidate?
        try input.seek(toOffset: 0)
        if try VaultStream.exact(8, from: input) == magic {
            let length = try VaultStream.number(from: input)
            front = try candidate(at: 16, length: length)
        }
        var back: Candidate?
        var footerOffset: UInt64?
        try input.seek(toOffset: size - 8)
        if try VaultStream.exact(8, from: input) == footerMagic {
            try input.seek(toOffset: size - 16)
            let length = try VaultStream.number(from: input)
            if length <= size - 16 {
                let offset = size - 16 - length
                back = try candidate(at: offset, length: length)
                footerOffset = offset
            }
        }
        guard let chosen = front ?? back else { throw VaultError.wrongPasswordOrDamaged }
        if let front, let back, front.raw != back.raw { throw VaultError.invalidBackup }
        guard (allowIncompletePayload || size >= chosen.bodyEnd), size >= chosen.bodyStart, size <= chosen.expectedSize else { throw VaultError.invalidBackup }
        if let back {
            guard back.bodyEnd == footerOffset, back.expectedSize == size else { throw VaultError.invalidBackup }
        }
        return Opened(header: chosen.envelope.vaultHeader, index: chosen.catalog.index, records: chosen.catalog.records,
                      key: chosen.key, bodyStart: chosen.bodyStart, metadataRecovered: front == nil || back == nil,
                      snapshotID: chosen.envelope.snapshotID, archiveSize: size)
    }

    /// Copy ciphertext into an owned staging file. A failed digest or cancellation
    /// removes that file; no other archive resource is affected. The repository
    /// must additionally authenticate each resource's existing AEAD before import.
    public static func copyResource(from source: URL, opened: Opened, record: Record, to destination: URL) throws {
        try Task.checkCancellation()
        guard try fileSize(source) == opened.archiveSize,
              let index = opened.records.firstIndex(of: record) else { throw VaultError.invalidBackup }
        let offset = opened.bodyStart + opened.records.prefix(index).reduce(UInt64(0)) { $0 + UInt64($1.bytes) }
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        try input.seek(toOffset: offset)
        let output = try createExclusive(destination)
        var finished = false
        defer { try? output.close(); if !finished { try? FileManager.default.removeItem(at: destination) } }
        try copy(input, count: record.bytes, to: output, expectedDigest: record.sha256)
        try output.synchronize(); finished = true
    }

    private static func authenticate(_ raw: Data, unlock: (Data) throws -> SymmetricKey) throws -> Candidate {
        try Task.checkCancellation()
        let envelope = try decodeEnvelope(raw)
        let key = try unlock(envelope.vaultHeader)
        let plain = try VaultCrypto.open(envelope.sealedCatalog, key: catalogKey(key, envelope.snapshotID), context: context(envelope.snapshotID))
        guard plain.count <= envelopeLimit else { throw VaultError.invalidBackup }
        let catalog = try JSONDecoder().decode(Catalog.self, from: plain)
        guard catalog.index.count >= 28, catalog.index.count <= VaultLimits.manifestBytes,
              catalog.headerSHA256 == digest(envelope.vaultHeader) else { throw VaultError.invalidBackup }
        try validate(catalog.records)
        try validateSize(raw.count, records: catalog.records)
        return Candidate(raw: raw, envelope: envelope, catalog: catalog, key: key)
    }
    private static func decodeEnvelope(_ raw: Data) throws -> Envelope {
        guard !raw.isEmpty, raw.count <= envelopeLimit else { throw VaultError.invalidBackup }
        let value = try JSONDecoder().decode(Envelope.self, from: raw)
        guard value.version == 3, !value.vaultHeader.isEmpty, value.vaultHeader.count <= headerLimit,
              value.sealedCatalog.count >= 28, value.sealedCatalog.count <= envelopeLimit else { throw VaultError.invalidBackup }
        return value
    }
    private static func validate(_ records: [Record]) throws {
        guard records.count <= VaultLimits.itemCount, Set(records.map(\.id)).count == records.count,
              records.allSatisfy({ $0.bytes >= 28 && $0.bytes <= VaultStream.encryptedSize(VaultLimits.fileBytes)
                  && $0.sha256.utf8.count == 64 && $0.sha256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) }) else { throw VaultError.invalidBackup }
        guard records.reduce(UInt64(0), { $0 + UInt64($1.bytes) }) <= UInt64(VaultLimits.backupBytes) else { throw VaultError.limit }
    }
    private static func validateSize(_ envelopeBytes: Int, records: [Record]) throws {
        guard envelopeBytes > 0, envelopeBytes <= envelopeLimit else { throw VaultError.limit }
        let total = UInt64(32 + envelopeBytes * 2) + records.reduce(UInt64(0)) { $0 + UInt64($1.bytes) }
        guard total <= UInt64(VaultLimits.backupBytes) else { throw VaultError.limit }
    }
    private static func context(_ id: UUID) -> String { "Arithen/backup/v3/" + id.uuidString }
    private static func catalogKey(_ key: SymmetricKey, _ id: UUID) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: key, salt: Data(id.uuidString.utf8),
                              info: Data("Arithen/backup/v3/catalog".utf8), outputByteCount: 32)
    }
    private static func digest(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
    private static func digestFile(_ url: URL, count: Int) throws -> String {
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        var hash = SHA256(), remaining = count
        while remaining > 0 {
            try Task.checkCancellation()
            let data = try VaultStream.exact(min(VaultLimits.chunkBytes, remaining), from: input)
            hash.update(data: data); remaining -= data.count
        }
        guard (try input.read(upToCount: 1) ?? Data()).isEmpty else { throw VaultError.changed }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    private static func copy(_ input: FileHandle, count: Int, to output: FileHandle, expectedDigest: String) throws {
        var hash = SHA256(), remaining = count
        while remaining > 0 {
            try Task.checkCancellation()
            let data = try VaultStream.exact(min(VaultLimits.chunkBytes, remaining), from: input)
            hash.update(data: data); try output.write(contentsOf: data); remaining -= data.count
        }
        guard hash.finalize().map({ String(format: "%02x", $0) }).joined() == expectedDigest else { throw VaultError.wrongPasswordOrDamaged }
    }
    private static func fileSize(_ url: URL) throws -> UInt64 {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true, let size = values.fileSize, size >= 0 else { throw VaultError.invalidBackup }
        return UInt64(size)
    }
    private static func createExclusive(_ url: URL) throws -> FileHandle {
        // O_EXCL also rejects dangling symlinks; never truncate a user's existing file.
        let descriptor = url.path.withCString { open($0, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, mode_t(0o600)) }
        guard descriptor >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        #if os(iOS)
        do { try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path) }
        catch { try? handle.close(); try? FileManager.default.removeItem(at: url); throw error }
        #endif
        return handle
    }
}
