import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// Access only through the serial VaultEngine actor.
public final class VaultRepository {
    public let root: URL
    private let fm = FileManager.default
    private var key: SymmetricKey?
    private var header: VaultHeader?
    private var manifest: VaultManifest?
    public var exists: Bool { fm.fileExists(atPath: root.path) }
    public var isUnlocked: Bool { key != nil }
    public var items: [VaultItem] { manifest?.items ?? [] }
    public init(root: URL) { self.root = root }

    public func create(password: String) throws {
        guard !exists else { throw VaultError.exists }
        guard password.count >= 14, password.utf8.count <= 1024 else { throw VaultError.invalidPassword }
        var header = VaultHeader(version: 2, id: UUID(), salt: VaultCrypto.random(32), rounds: VaultCrypto.rounds)
        let key = SymmetricKey(data: VaultCrypto.random(32))
        let wrapping = try VaultCrypto.derive(password: VaultCode.normalizeRecovery(password), salt: header.salt, rounds: header.rounds)
        header.wrappedKey = try VaultCrypto.seal(key.withUnsafeBytes { Data($0) }, key: wrapping,
            context: Self.context(header, "key"))
        let next = VaultManifest()
        let stage = try stagingDirectory()
        defer { try? fm.removeItem(at: stage) }
        try Self.write(JSONEncoder().encode(header), to: stage.appendingPathComponent("header.json"))
        try Self.write(VaultCrypto.seal(JSONEncoder().encode(next), key: key,
            context: Self.context(header, "manifest")), to: stage.appendingPathComponent("index.enc"))
        try fm.moveItem(at: stage, to: root)
        self.header = header; self.key = key; manifest = next
    }

    public func unlock(password: String) throws {
        lock()
        let candidate = try readHeader()
        try finishUnlock(candidate, key: Self.recoveryKey(password, header: candidate))
    }
    public func unlock(credential: VaultCredential) throws {
        lock()
        let candidate = try readHeader()
        guard credential.id == candidate.id, credential.key.count == 32 else { throw VaultError.locked }
        try finishUnlock(candidate, key: SymmetricKey(data: credential.key))
    }
    public func credential() throws -> VaultCredential {
        guard let key, let header else { throw VaultError.locked }
        return VaultCredential(id: header.id, key: key.withUnsafeBytes { Data($0) })
    }
    public func identifier() throws -> UUID { try readHeader().id }
    private func readHeader() throws -> VaultHeader {
        let h = try JSONDecoder().decode(VaultHeader.self, from: Self.read(root.appendingPathComponent("header.json"), limit: 4096))
        try h.validate(); return h
    }
    private func finishUnlock(_ candidate: VaultHeader, key: SymmetricKey) throws {
        let encrypted = try Self.read(root.appendingPathComponent("index.enc"), limit: VaultLimits.manifestBytes)
        let decoded = try Self.decodeManifest(encrypted, header: candidate, key: key)
        self.key = key; header = candidate; manifest = decoded
        let unfinished = decoded.items.filter { $0.pendingImport == true }
        do { if !unfinished.isEmpty {
            var cleaned = decoded; cleaned.items.removeAll { $0.pendingImport == true }
            try persist(cleaned, key: key, header: candidate); manifest = cleaned
            for item in unfinished { try? fm.removeItem(at: assetURL(item.id)) }
        } } catch { lock(); throw error }
    }
    private static func recoveryKey(_ password: String, header: VaultHeader) throws -> SymmetricKey {
        let derived = try VaultCrypto.derive(password: header.version == 2 ? VaultCode.normalizeRecovery(password) : password,
            salt: header.salt, rounds: header.rounds)
        guard header.version == 2, let wrapped = header.wrappedKey else { return derived }
        let bytes = try VaultCrypto.open(wrapped, key: derived, context: context(header, "key"))
        guard bytes.count == 32 else { throw VaultError.invalidBackup }
        return SymmetricKey(data: bytes)
    }
    public func lock() { key = nil; header = nil; manifest = nil }

    @discardableResult
    public func add(data: Data, name: String, contentType: String, details: MediaDetails = .init(), pending: Bool = false) throws -> VaultItem {
        guard let key, let header, var next = manifest else { throw VaultError.locked }
        guard data.count <= VaultLimits.memoryBytes, next.items.count < VaultLimits.itemCount,
              next.items.reduce(0, { $0 + $1.byteCount }) + data.count < VaultLimits.backupBytes - 32 * 1024 * 1024 else { throw VaultError.limit }
        var item = VaultItem(id: UUID(), name: String(name.prefix(180)), contentType: String(contentType.prefix(120)), byteCount: data.count, added: Date())
        item.captured = details.captured; item.duration = details.duration
        item.latitude = details.latitude; item.longitude = details.longitude; item.storageVersion = 2; item.pendingImport = pending
        let path = assetURL(item.id)
        do {
            try VaultStream.encrypt(data, to: path, key: key, context: Self.context(header, item.id.uuidString))
            let checked = try VaultStream.read(path, size: data.count, key: key, context: Self.context(header, item.id.uuidString))
            guard checked == data else { throw VaultError.wrongPasswordOrDamaged }
            next.items.insert(item, at: 0)
            try persist(next, key: key, header: header); manifest = next
        } catch { try? fm.removeItem(at: path); throw error }
        return item
    }

    @discardableResult
    public func add(file: URL, name: String, contentType: String, details: MediaDetails = .init(), pending: Bool = false) throws -> VaultItem {
        guard let key, let header, var next = manifest else { throw VaultError.locked }
        let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size >= 0, size <= VaultLimits.fileBytes, next.items.count < VaultLimits.itemCount,
              next.items.reduce(0, { $0 + $1.byteCount }) + size < VaultLimits.backupBytes - 32 * 1024 * 1024 else { throw VaultError.limit }
        var item = VaultItem(id: UUID(), name: String(name.prefix(180)), contentType: String(contentType.prefix(120)), byteCount: size, added: Date())
        item.captured = details.captured; item.duration = details.duration
        item.latitude = details.latitude; item.longitude = details.longitude; item.storageVersion = 2; item.pendingImport = pending
        let path = assetURL(item.id)
        do {
            try VaultStream.encrypt(file, to: path, size: size, key: key, context: Self.context(header, item.id.uuidString))
            // Read back/authenticate before publishing the index entry.
            try VaultStream.decrypt(path, to: nil, size: size, key: key, context: Self.context(header, item.id.uuidString))
            next.items.insert(item, at: 0)
            try persist(next, key: key, header: header); manifest = next
        } catch { try? fm.removeItem(at: path); throw error }
        return item
    }
    public func associate(primary: UUID, companion: UUID?, thumbnail: UUID?) throws {
        guard let key, let header, var next = manifest,
              let p = next.items.firstIndex(where: { $0.id == primary }) else { throw VaultError.locked }
        next.items[p].pendingImport = false
        if let companion, let c = next.items.firstIndex(where: { $0.id == companion }) {
            next.items[p].companionID = companion; next.items[p].companionType = next.items[c].contentType
            next.items[c].isCompanion = true
            next.items[c].pendingImport = false
        }
        if let thumbnail, let t = next.items.firstIndex(where: { $0.id == thumbnail }) {
            next.items[p].thumbnailID = thumbnail; next.items[t].isThumbnail = true
            next.items[t].pendingImport = false
        }
        try persist(next, key: key, header: header); manifest = next
    }
    public func contents(of id: UUID) throws -> Data {
        guard let item = items.first(where: { $0.id == id }) else { throw isUnlocked ? VaultError.missing : VaultError.locked }
        guard item.byteCount <= VaultLimits.memoryBytes else { throw VaultError.limit }
        guard let key, let header else { throw VaultError.locked }
        if item.storageVersion == 2 {
            return try VaultStream.read(assetURL(id), size: item.byteCount, key: key, context: Self.context(header, id.uuidString))
        }
        let data = try VaultCrypto.open(Self.read(assetURL(id), limit: VaultLimits.memoryBytes + 28), key: key, context: Self.context(header, id.uuidString))
        guard data.count == item.byteCount else { throw VaultError.wrongPasswordOrDamaged }
        return data
    }
    public func materialize(id: UUID, to url: URL) throws {
        guard let key, let header else { throw VaultError.locked }
        guard let item = items.first(where: { $0.id == id }) else { throw VaultError.missing }
        guard !fm.fileExists(atPath: url.path) else { throw VaultError.exists }
        if item.storageVersion == 2 {
            try VaultStream.decrypt(assetURL(id), to: url, size: item.byteCount, key: key, context: Self.context(header, id.uuidString))
        } else { try Self.write(contents(of: id), to: url) }
    }
    /// Re-read the committed index and authenticate every resource before allowing
    /// a caller to request deletion of a photo-library original. No plaintext export.
    public func verifyImportedCopies(_ ids: [UUID]) throws {
        guard let key, let header else { throw VaultError.locked }
        guard !ids.isEmpty else { throw VaultError.missing }
        let committed = try Self.decodeManifest(Self.read(root.appendingPathComponent("index.enc"), limit: VaultLimits.manifestBytes), header: header, key: key)
        for id in Set(ids) {
            guard let item = committed.items.first(where: { $0.id == id }), item.visible, item.deletedAt == nil else { throw VaultError.missing }
            for resourceID in [item.id, item.companionID, item.thumbnailID].compactMap({ $0 }) {
                guard let resource = committed.items.first(where: { $0.id == resourceID }), resource.pendingImport != true else { throw VaultError.missing }
                if resource.storageVersion == 2 {
                    try VaultStream.decrypt(assetURL(resourceID), to: nil, size: resource.byteCount, key: key, context: Self.context(header, resourceID.uuidString))
                } else {
                    let data = try VaultCrypto.open(Self.read(assetURL(resourceID), limit: VaultLimits.memoryBytes + 28), key: key, context: Self.context(header, resourceID.uuidString))
                    guard data.count == resource.byteCount else { throw VaultError.wrongPasswordOrDamaged }
                }
            }
        }
    }
    public func update(id: UUID, favorite: Bool? = nil, album: String? = nil, deleted: Bool? = nil) throws {
        guard let key, let header, var next = manifest, let i = next.items.firstIndex(where: { $0.id == id }) else { throw VaultError.locked }
        if let favorite { next.items[i].favorite = favorite }
        if let album { next.items[i].album = String(album.prefix(100)) }
        if let deleted { next.items[i].deletedAt = deleted ? Date() : nil }
        try persist(next, key: key, header: header); manifest = next
    }
    public func remove(id: UUID) throws {
        guard let key, let header, var next = manifest else { throw VaultError.locked }
        let target = next.items.first { $0.id == id }
        let ids = Set([id, target?.companionID, target?.thumbnailID].compactMap { $0 })
        next.items.removeAll { ids.contains($0.id) }
        try persist(next, key: key, header: header); manifest = next
        for id in ids { try? fm.removeItem(at: assetURL(id)) }
    }

    public func cloudPlan() throws -> CloudPlan {
        guard let header, let key, let manifest else { throw VaultError.locked }
        guard !manifest.items.contains(where: { $0.pendingImport == true }) else { throw VaultError.changed }
        let index = try Self.read(root.appendingPathComponent("index.enc"), limit: VaultLimits.manifestBytes)
        let committed = try Self.decodeManifest(index, header: header, key: key)
        var records: [CloudRecord] = []
        var sources: [UUID: URL] = [:]
        for item in committed.items {
            try Task.checkCancellation()
            if item.storageVersion == 2 {
                try VaultStream.decrypt(assetURL(item.id), to: nil, size: item.byteCount, key: key, context: Self.context(header, item.id.uuidString))
            } else { _ = try contents(of: item.id) }
            let url = assetURL(item.id)
            let length = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            records.append(CloudRecord(id: item.id, bytes: length, sha256: try CloudBackup.hash(url)))
            sources[item.id] = url
        }
        return CloudPlan(snapshot: CloudSnapshot(id: UUID(), vaultID: header.id, created: Date(),
            header: try JSONEncoder().encode(header), index: index, records: records), sources: sources)
    }

    /// Authenticate the small catalog before trusting its download inventory.
    public static func validateCloudRecovery(_ snapshot: CloudSnapshot, password: String) throws -> Int {
        try snapshot.validate()
        let header = try JSONDecoder().decode(VaultHeader.self, from: snapshot.header)
        let key = try recoveryKey(password, header: header)
        let manifest = try decodeManifest(snapshot.index, header: header, key: key)
        let records = Dictionary(uniqueKeysWithValues: snapshot.records.map { ($0.id, $0) })
        guard records.count == manifest.items.count, manifest.items.allSatisfy({ item in
            records[item.id]?.bytes == (item.storageVersion == 2 ? VaultStream.encryptedSize(item.byteCount) : item.byteCount + 28)
        }) else { throw VaultError.invalidBackup }
        return manifest.items.filter(\.visible).count
    }

    public func exportBackup(to url: URL) throws {
        guard let header, let key, manifest != nil else { throw VaultError.locked }
        let handle = try VaultStream.newFile(url)
        var completed = false
        defer { try? handle.close(); if !completed { try? fm.removeItem(at: url) } }
        try handle.write(contentsOf: Data("C84B0002".utf8))
        try VaultStream.block(JSONEncoder().encode(header), to: handle)
        try VaultStream.block(Self.read(root.appendingPathComponent("index.enc"), limit: VaultLimits.manifestBytes), to: handle)
        try VaultStream.number(UInt64(items.count), to: handle)
        for item in items {
            if item.storageVersion == 2 {
                try VaultStream.decrypt(assetURL(item.id), to: nil, size: item.byteCount, key: key, context: Self.context(header, item.id.uuidString))
            } else { _ = try contents(of: item.id) }
            let input = try FileHandle(forReadingFrom: assetURL(item.id))
            defer { try? input.close() }
            let length = try input.seekToEnd(); try input.seek(toOffset: 0)
            try handle.write(contentsOf: Data(item.id.uuidString.utf8))
            try VaultStream.number(length, to: handle)
            try VaultStream.copy(input, to: handle, count: Int(length))
        }
        try handle.synchronize(); completed = true
    }

    /// All authentication completes in staging, then one rename commits. Existing libraries are never replaced.
    public func restore(from backup: URL, password: String) throws {
        guard !exists else { throw VaultError.exists }
        let size = try backup.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size <= VaultLimits.backupBytes else { throw VaultError.limit }
        let input = try FileHandle(forReadingFrom: backup)
        defer { try? input.close() }
        let magic = try VaultStream.exact(8, from: input)
        guard [Data("C84B0001".utf8), Data("C84B0002".utf8)].contains(magic) else { throw VaultError.invalidBackup }
        let headerData = try VaultStream.block(from: input, limit: 4096)
        let candidate = try JSONDecoder().decode(VaultHeader.self, from: headerData); try candidate.validate()
        let candidateKey = try Self.recoveryKey(password, header: candidate)
        let indexData = try VaultStream.block(from: input, limit: VaultLimits.manifestBytes)
        let index = try Self.decodeManifest(indexData, header: candidate, key: candidateKey)
        let count = try VaultStream.number(from: input)
        guard count == UInt64(index.items.count) else { throw VaultError.invalidBackup }
        let lookup = Dictionary(uniqueKeysWithValues: index.items.map { ($0.id, $0) })
        var seen = Set<UUID>()
        let stage = try stagingDirectory()
        defer { try? fm.removeItem(at: stage) }
        try Self.write(headerData, to: stage.appendingPathComponent("header.json"))
        try Self.write(indexData, to: stage.appendingPathComponent("index.enc"))
        for _ in 0..<count {
            let idData = try VaultStream.exact(36, from: input)
            guard let text = String(data: idData, encoding: .utf8), let id = UUID(uuidString: text),
                  let item = lookup[id], seen.insert(id).inserted else { throw VaultError.invalidBackup }
            let length = try VaultStream.number(from: input)
            let expected = item.storageVersion == 2 ? VaultStream.encryptedSize(item.byteCount) : item.byteCount + 28
            guard length == UInt64(expected) else { throw VaultError.invalidBackup }
            let destination = stage.appendingPathComponent(id.uuidString + ".enc")
            let output = try VaultStream.newFile(destination)
            do { try VaultStream.copy(input, to: output, count: Int(length)); try output.close() }
            catch { try? output.close(); throw error }
            if item.storageVersion == 2 {
                try VaultStream.decrypt(destination, to: nil, size: item.byteCount, key: candidateKey, context: Self.context(candidate, id.uuidString))
            } else {
                let plain = try VaultCrypto.open(Self.read(destination, limit: VaultLimits.memoryBytes + 28), key: candidateKey, context: Self.context(candidate, id.uuidString))
                guard plain.count == item.byteCount else { throw VaultError.invalidBackup }
            }
        }
        guard (try input.read(upToCount: 1) ?? Data()).isEmpty else { throw VaultError.invalidBackup }
        try fm.moveItem(at: stage, to: root)
        key = candidateKey; header = candidate; manifest = index
    }
    private func assetURL(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString + ".enc") }
    private static func context(_ header: VaultHeader, _ item: String) -> String { "Calc84/v\(header.version)/\(header.id.uuidString)/\(item)" }
    private func persist(_ next: VaultManifest, key: SymmetricKey, header: VaultHeader) throws {
        let encoded = try JSONEncoder().encode(next)
        guard encoded.count + 28 <= VaultLimits.manifestBytes else { throw VaultError.limit }
        try Self.write(VaultCrypto.seal(encoded, key: key, context: Self.context(header, "manifest")), to: root.appendingPathComponent("index.enc"))
    }
    private static func decodeManifest(_ encrypted: Data, header: VaultHeader, key: SymmetricKey) throws -> VaultManifest {
        let data = try VaultCrypto.open(encrypted, key: key, context: context(header, "manifest"))
        let result = try JSONDecoder().decode(VaultManifest.self, from: data)
        let ids = Set(result.items.map(\.id))
        guard [1, 2].contains(result.version), result.items.count <= VaultLimits.itemCount, ids.count == result.items.count,
              result.items.allSatisfy({ item in
                  item.byteCount >= 0 && item.byteCount <= (item.storageVersion == 2 ? VaultLimits.fileBytes : VaultLimits.memoryBytes)
                  && item.name.count <= 180 && item.contentType.count <= 120 && (item.album?.count ?? 0) <= 100
                  && (item.storageVersion == nil || item.storageVersion == 2)
                  && (item.companionID == nil || (ids.contains(item.companionID!) && item.companionID != item.id))
                  && (item.thumbnailID == nil || (ids.contains(item.thumbnailID!) && item.thumbnailID != item.id))
                  && (item.captured?.timeIntervalSince1970.isFinite ?? true)
                  && (item.duration.map { $0.isFinite && $0 >= 0 } ?? true)
              }) else { throw VaultError.invalidBackup }
        guard result.items.reduce(0, { $0 + $1.byteCount }) < VaultLimits.backupBytes else { throw VaultError.limit }
        return result
    }
    private func stagingDirectory() throws -> URL {
        let parent = root.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        let directory = parent.appendingPathComponent("stage-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }
    static func write(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
    static func read(_ url: URL, limit: Int) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size <= limit else { throw VaultError.limit }
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        let data = try VaultStream.exact(size, from: input)
        guard (try input.read(upToCount: 1) ?? Data()).isEmpty else { throw VaultError.limit }
        return data
    }
}
