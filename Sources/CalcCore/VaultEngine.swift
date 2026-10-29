import Foundation

public actor VaultEngine {
    private let repository: VaultRepository
    public init(root: URL) { repository = VaultRepository(root: root) }
    public func exists() -> Bool { repository.exists }
    public func identifier() throws -> UUID { try repository.identifier() }
    public func credential() throws -> VaultCredential { try repository.credential() }
    public func unlock(credential: VaultCredential) throws -> [VaultItem] {
        try repository.unlock(credential: credential); return repository.items
    }
    public func create(password: String) throws -> [VaultItem] {
        try repository.create(password: password)
        return repository.items
    }
    public func unlock(password: String) throws -> [VaultItem] {
        try repository.unlock(password: password)
        return repository.items
    }
    public func lock() { repository.lock() }
    public func add(data: Data, name: String, contentType: String) throws -> [VaultItem] {
        try repository.add(data: data, name: name, contentType: contentType)
        return repository.items
    }
    public func add(file: URL, name: String, contentType: String, details: MediaDetails = .init(),
                    companion: URL? = nil, companionType: String? = nil, thumbnail: Data? = nil) throws -> [VaultItem] {
        var created: [UUID] = []
        do {
            let primary = try repository.add(file: file, name: name, contentType: contentType, details: details, pending: true)
            created.append(primary.id)
            var companionID: UUID?
            var thumbnailID: UUID?
            if let companion {
                let part = try repository.add(file: companion, name: "Live Photo video.mov", contentType: companionType ?? "com.apple.quicktime-movie", details: details, pending: true)
                companionID = part.id; created.append(part.id)
            }
            if let thumbnail {
                let part = try repository.add(data: thumbnail, name: "thumbnail.jpg", contentType: "public.jpeg", pending: true)
                thumbnailID = part.id; created.append(part.id)
            }
            try repository.associate(primary: primary.id, companion: companionID, thumbnail: thumbnailID)
            return repository.items
        } catch {
            for id in created.reversed() { try? repository.remove(id: id) }
            throw error
        }
    }
    public func contents(id: UUID) throws -> Data { try repository.contents(of: id) }
    public func albumPreferences() throws -> [String: AlbumPreference] { try repository.albumPreferences() }
    public func organize(ids: Set<UUID>, albums: [String], tags: [String], mode: OrganizationMode) throws -> [VaultItem] {
        try repository.organize(ids: ids, albums: albums, tags: tags, mode: mode); return repository.items
    }
    public func setAlbumPreference(_ value: AlbumPreference, name: String) throws -> [String: AlbumPreference] {
        try repository.setAlbumPreference(value, name: name); return try repository.albumPreferences()
    }
    public func searchIndex() throws -> PrivateSearchIndex { try repository.searchIndex() }
    public func saveSearchIndex(_ value: PrivateSearchIndex) throws { try repository.saveSearchIndex(value) }
    public func storageReport() throws -> LibraryStorageReport { try repository.storageReport() }
    public func duplicates() throws -> [DuplicateGroup] { try repository.duplicates() }
    public func materialize(id: UUID, to: URL) throws { try repository.materialize(id: id, to: to) }
    public func verifyImportedCopies(_ ids: [UUID]) throws { try repository.verifyImportedCopies(ids) }
    public func update(id: UUID, favorite: Bool? = nil, album: String? = nil, deleted: Bool? = nil) throws -> [VaultItem] {
        try repository.update(id: id, favorite: favorite, album: album, deleted: deleted)
        return repository.items
    }
    public func remove(id: UUID) throws -> [VaultItem] {
        try repository.remove(id: id)
        return repository.items
    }
    public func export(to: URL) throws { try repository.exportBackup(to: to) }
    public func cloudPreferences() throws -> CloudPreferences { try repository.cloudPreferences() }
    public func setCloudPolicy(_ policy: CloudBackupPolicy, provider: CloudProvider) throws {
        try repository.setCloudPolicy(policy, provider: provider)
    }
    public func cloudPlan(provider: CloudProvider) throws -> CloudPlan { try repository.cloudPlan(provider: provider) }
    public func restore(from: URL, password: String) throws -> [VaultItem] {
        try repository.restore(from: from, password: password)
        return repository.items
    }
    public func initializeFromBackups(_ sources: [SetupBackupSource], recovery: String,
                                      progress: @Sendable (Int, Int) -> Void = { _, _ in }) throws -> [VaultItem] {
        try repository.initializeFromBackups(sources, recovery: recovery, progress: progress)
        return repository.items
    }
    public func importBackup(from root: URL, credential: VaultCredential, selected: Set<UUID>) throws -> BackupImportResult {
        let source = VaultRepository(root: root)
        defer { source.lock() }
        try source.unlock(credential: credential)
        return try repository.importBackup(source, selected: selected)
    }
    public func verifyBackup(from: URL, password: String) throws -> Int {
        let temporary = repository.root.deletingLastPathComponent().appendingPathComponent("verify-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let verifier = VaultRepository(root: temporary)
        try verifier.restore(from: from, password: password)
        return verifier.items.filter(\.visible).count
    }
}
