#if os(iOS)
import SwiftUI
import CalcCore
import PhotosUI
import Photos
#if canImport(_PhotosUI_SwiftUI)
import _PhotosUI_SwiftUI
#endif
import UniformTypeIdentifiers

struct PreparedBackup: Identifiable {
    let id = UUID()
    let url: URL
    let digest: Data
    let generation: UUID
}

@MainActor
final class VaultModel: ObservableObject {
    @Published var items: [VaultItem] = []
    @Published var cloudPreferences = CloudPreferences()
    @Published var unlocked = false
    @Published var exists = false
    @Published var busy = false
    @Published var message: String?
    @Published var status = ""
    @Published var progress = 0.0
    @Published var importing = false
    @Published var failedImportCount = 0
    private var importTask: Task<Void, Never>?
    private var automaticBackupTask: Task<Void, Never>?
    private var failedPhotos: [PhotosPickerItem] = []
    private var failedFiles: [URL] = []
    @Published var photoImportReview: PhotoImportReview?
    @Published var fileImportReview: FileImportReview?
    private var failedFileAccess: ImportAccess?
    private var fileDeletionTask: Task<FileTrashResult, Never>?
    let engine: VaultEngine
    let cloud = CloudBackupModel()
    private let deviceAccess = DeviceAccess()
    private(set) var generation = UUID()
    private var lockTask: Task<Void, Never>?
    private var pendingBackup: PreparedBackup?

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        engine = VaultEngine(root: base.appendingPathComponent("Calc84Library", isDirectory: true))
        Task { exists = await engine.exists() }
    }
    /// True means show the library or first-run setup. Wrong codes leave a normal calculator.
    func enter(code: String) async -> Bool {
        guard !busy else { return false }
        busy = true; defer { busy = false }
        let ticket = generation
        await lockTask?.value
        guard ticket == generation else { return false }
        exists = await engine.exists()
        if !exists { return code == VaultCode.starter }
        do {
            let id = try await engine.identifier()
            let configured = try await deviceAccess.configured(for: id)
            guard ticket == generation else { return false }
            // Hidden recovery entry presents the locked recovery form, never decrypted
            // items. Recovering access still requires the original recovery secret.
            if !configured || code == VaultCode.starter { return code == VaultCode.starter }
            guard let credential = try await deviceAccess.unlock(code: code, id: id), ticket == generation else { return false }
            let result = try await engine.unlock(credential: credential)
            guard ticket == generation else { await engine.lock(); return false }
            let preferences = try await engine.cloudPreferences()
            guard ticket == generation else { await engine.lock(); return false }
            cloudPreferences = preferences; items = result; unlocked = true; scheduleAutomaticBackup(); return true
        } catch {
            if ticket == generation { message = error.localizedDescription }
            return false
        }
    }
    func open(password: String, code: String, creating: Bool, backup: URL?) {
        guard !busy, VaultCode.valid(code) else { message = VaultError.invalidCode.localizedDescription; return }
        busy = true; let ticket = generation
        Task {
            defer { busy = false }
            await lockTask?.value
            guard ticket == generation else { return }
            do {
                let result: [VaultItem]
                if let backup {
                    let access = backup.startAccessingSecurityScopedResource()
                    defer { if access { backup.stopAccessingSecurityScopedResource() } }
                    result = try await engine.restore(from: backup, password: password)
                } else if creating { result = try await engine.create(password: password) }
                else { result = try await engine.unlock(password: password) }
                // Creation/restore commits before enrollment. A failed Keychain save is recoverable with the saved recovery secret.
                exists = await engine.exists()
                guard ticket == generation else { await engine.lock(); return }
                try await deviceAccess.enroll(code: code, credential: engine.credential())
                guard ticket == generation else { await engine.lock(); return }
                let preferences = try await engine.cloudPreferences()
                guard ticket == generation else { await engine.lock(); return }
                cloudPreferences = preferences; items = result; unlocked = true; changed()
            } catch {
                await engine.lock()
                exists = await engine.exists()
                if ticket == generation { message = error.localizedDescription }
            }
        }
    }
    func changeCode(old: String, new: String) async -> Bool {
        guard unlocked, !busy else { return false }
        busy = true; defer { busy = false }
        let ticket = generation
        do {
            try await deviceAccess.change(old: old, new: new, id: engine.identifier())
            guard ticket == generation else { return false }
            status = "Calculator code changed. Your recovery key and backups still work."
            return true
        } catch { if ticket == generation { message = error.localizedDescription }; return false }
    }
    func lock() {
        importTask?.cancel(); automaticBackupTask?.cancel(); fileDeletionTask?.cancel()
        fileImportReview = nil; failedFileAccess = nil
        failedPhotos = []; failedFiles = []; failedImportCount = 0
        cloud.lock(); cloudPreferences = .init()
        generation = UUID(); unlocked = false; items = []; status = ""; message = nil; photoImportReview = nil
        if let pendingBackup { finishBackupExport(pendingBackup, destination: nil) }
        lockTask = Task { await engine.lock(); exists = await engine.exists() }
    }
    private func changed() { UserDefaults.standard.set(true, forKey: "libraryNeedsBackup"); cloud.changed() }
    func cancelImport() { importTask?.cancel(); status = "Cancelling import…" }
    func retryImports() {
        guard unlocked, !busy else { return }
        if !failedPhotos.isEmpty { let values = failedPhotos; importPhotos(values) }
        else if !failedFiles.isEmpty { let values = failedFiles; importFiles(values) }
    }
    private func importStopped(_ error: Error) -> Bool {
        Task.isCancelled || (error as NSError).domain == NSCocoaErrorDomain && (error as NSError).code == NSFileWriteOutOfSpaceError
    }
    func importFiles(_ selections: [URL]) {
        guard unlocked, !busy, !selections.isEmpty else { return }
        let access = ImportAccess(selections, parent: failedFileAccess)
        fileImportReview = nil; failedFileAccess = nil
        busy = true; importing = true; progress = 0; let ticket = generation
        failedFiles = []; failedPhotos = []; failedImportCount = 0
        importTask = Task {
            let urls: [URL]
            do {
                status = "Reading selected files…"
                let worker = Task.detached { try ImportFileList.expand(selections) }
                urls = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
            } catch {
                busy = false; importing = false; importTask = nil
                if ticket == generation { message = error.localizedDescription }
                return
            }
            var originals: [ImportedFileOriginal] = []
            var failures: [URL] = []
            var errors: [String] = []
            for (position, url) in urls.enumerated() {
                guard ticket == generation, !Task.isCancelled else { failures += urls.dropFirst(position); break }
                status = "Importing file \(position + 1) of \(urls.count)…"
                do {
                    let bytes = Int64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
                    guard bytes <= VaultLimits.fileBytes else { throw VaultError.limit }
                    try StoragePreflight.require(bytes: bytes * 3)
                    let snapshot = try TemporaryFiles.fresh(extension: url.pathExtension)
                    defer { try? FileManager.default.removeItem(at: snapshot) }
                    let worker = Task.detached { try OriginalFiles.snapshot(url, to: snapshot) }
                    let digest = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                    let type = UTType(filenameExtension: url.pathExtension)?.identifier ?? UTType.data.identifier
                    let details = await MediaBridge.metadata(snapshot, type: type)
                    let thumb = await MediaBridge.thumbnail(snapshot, type: type)
                    try Task.checkCancellation()
                    guard ticket == generation else { break }
                    let before = Set(items.map(\.id))
                    let result = try await engine.add(file: snapshot, name: url.lastPathComponent, contentType: type, details: details, thumbnail: thumb)
                    changed()
                    guard ticket == generation else { break }
                    if let added = result.first(where: { $0.visible && !before.contains($0.id) }) {
                        originals.append(.init(vaultID: added.id, url: url, digest: digest))
                    }
                    items = result
                } catch {
                    failures.append(url); errors.append(url.lastPathComponent + ": " + error.localizedDescription)
                    if importStopped(error) { failures += urls.dropFirst(position + 1); break }
                }
                progress = Double(position + 1) / Double(max(urls.count, 1))
            }
            busy = false; importing = false; importTask = nil
            guard ticket == generation, unlocked else { return }
            failedFiles = failures; failedImportCount = failures.count
            failedFileAccess = failures.isEmpty ? nil : access
            status = "Imported \(originals.count) of \(urls.count). Originals stay where they are."
            fileImportReview = FileImportReview(imported: originals.count, requested: urls.count, originals: originals, access: access,
                detail: urls.isEmpty ? "No regular files were found. Hidden files, links, and app packages are skipped." : errors.prefix(3).joined(separator: "\n"))
            if !originals.isEmpty { scheduleAutomaticBackup() }
        }
    }
    func trashImportedFiles(_ review: FileImportReview) {
        guard unlocked, !busy, fileImportReview?.id == review.id, !review.originals.isEmpty else { return }
        busy = true; let ticket = generation; let engine = engine
        let worker = Task.detached(priority: .userInitiated) {
            var result = FileTrashResult()
            do {
                try await engine.verifyImportedCopies(review.originals.map(\.vaultID))
                for original in review.originals {
                    try Task.checkCancellation()
                    do { try OriginalFiles.trash(original); result.removed.insert(original.vaultID) }
                    catch {
                        if Task.isCancelled { throw CancellationError() }
                        result.errors.append(original.url.lastPathComponent + ": " + error.localizedDescription)
                    }
                }
            } catch { result.errors.append(error.localizedDescription) }
            // Retain the source scopes until all coordinated operations have finished.
            withExtendedLifetime(review.access) {}
            return result
        }
        fileDeletionTask = worker
        Task {
            let result = await worker.value
            busy = false; fileDeletionTask = nil
            guard ticket == generation, unlocked else { return }
            let remaining = review.originals.filter { !result.removed.contains($0.vaultID) }
            status = "\(result.removed.count) originals moved to Trash. Vault copies remain."
            if remaining.isEmpty { fileImportReview = nil }
            else {
                fileImportReview = FileImportReview(imported: review.imported, requested: review.requested,
                    originals: remaining, access: review.access,
                    detail: status + " \(remaining.count) kept. " + result.errors.prefix(3).joined(separator: "\n"))
            }
        }
    }
    func importPhotos(_ selections: [PhotosPickerItem]) {
        guard unlocked, !busy, !selections.isEmpty else { return }
        photoImportReview = nil; failedPhotos = []; failedFiles = []; failedImportCount = 0
        busy = true; importing = true; progress = 0; let ticket = generation
        importTask = Task {
            var completed = 0
            var originals: [ImportedOriginal] = []
            var failures: [PhotosPickerItem] = []
            var errors: [String] = []
            if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
                _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            }
            for (position, selection) in selections.enumerated() {
                guard ticket == generation, !Task.isCancelled else { failures += selections.dropFirst(position); break }
                status = "Importing photo or video \(position + 1) of \(selections.count)…"
                do {
                    let media = try await MediaBridge.prepare(selection)
                    defer { media.clean() }
                    try Task.checkCancellation()
                    guard ticket == generation else { break }
                    let bytes = Int64(try media.url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
                        + Int64(try media.companion?.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
                    try StoragePreflight.require(bytes: bytes * 2)
                    let existing = Set(items.map(\.id))
                    let result = try await engine.add(file: media.url, name: media.name, contentType: media.type,
                        details: media.details, companion: media.companion,
                        companionType: media.companion == nil ? nil : "com.apple.quicktime-movie", thumbnail: media.thumbnail)
                    changed(); completed += 1
                    guard ticket == generation else { break }
                    if let source = media.original, let added = result.first(where: { $0.visible && !existing.contains($0.id) }) {
                        originals.append(ImportedOriginal(vaultID: added.id, source: source))
                    }
                    items = result
                } catch {
                    failures.append(selection); errors.append("Item \(position + 1): " + error.localizedDescription)
                    if importStopped(error) { failures += selections.dropFirst(position + 1); break }
                }
                progress = Double(position + 1) / Double(selections.count)
            }
            busy = false; importing = false; importTask = nil
            guard ticket == generation, unlocked else { return }
            failedPhotos = failures; failedImportCount = failures.count
            status = "Imported \(completed) of \(selections.count). Originals remain in Photos."
            photoImportReview = PhotoImportReview(imported: completed, requested: selections.count, originals: originals,
                importError: errors.isEmpty ? nil : errors.prefix(3).joined(separator: "\n"))
            // Show review immediately. Automatic backups wait until it is dismissed.
            if completed > 0 { scheduleAutomaticBackup() }
        }
    }
    /// Recheck the committed vault copies and exact source assets only after the
    /// user's explicit choice. PhotoKit supplies the final system confirmation.
    func deleteImportedOriginals(_ review: PhotoImportReview) async -> String? {
        guard unlocked, !busy, photoImportReview?.id == review.id, !review.originals.isEmpty else { return "Unlock the library and try again." }
        busy = true; let ticket = generation
        defer { busy = false }
        do {
            try await engine.verifyImportedCopies(review.originals.map(\.vaultID))
            guard ticket == generation, unlocked else { return nil }
            let assets = try MediaBridge.originalsForDeletion(review.originals.map(\.source))
            guard ticket == generation, unlocked else { return nil }
            try await PHPhotoLibrary.shared().performChanges { @Sendable in PHAssetChangeRequest.deleteAssets(assets as NSArray) }
            guard ticket == generation else { return nil }
            photoImportReview = nil
            status = "Imported originals deleted from Photos. Check Photos → Recently Deleted; your vault copies remain."
            return nil
        } catch {
            guard ticket == generation else { return nil }
            return "Deletion wasn’t completed. Your vault copies are unchanged. " + error.localizedDescription
        }
    }
    func update(_ item: VaultItem, favorite: Bool? = nil, album: String? = nil, deleted: Bool? = nil, permanently: Bool = false) {
        guard unlocked, !busy else { return }
        busy = true; let ticket = generation
        Task {
            do {
                let result: [VaultItem]
                if permanently { result = try await engine.remove(id: item.id) }
                else { result = try await engine.update(id: item.id, favorite: favorite, album: album, deleted: deleted) }
                changed()
                if ticket == generation {
                    items = result
                    let current = Set(result.filter(\.visible).map(\.id))
                    for provider in CloudProvider.allCases {
                        cloudPreferences[provider].selected.formIntersection(current)
                        cloudPreferences[provider].blocked.formIntersection(current)
                    }
                }
            } catch { if ticket == generation { message = error.localizedDescription } }
            busy = false
            if ticket == generation { scheduleAutomaticBackup() }
        }
    }
    func saveCloudPolicy(_ policy: CloudBackupPolicy, provider: CloudProvider) async -> Bool {
        guard unlocked, !busy else { return false }
        busy = true; let ticket = generation
        defer { busy = false }
        do {
            try await engine.setCloudPolicy(policy, provider: provider)
            guard ticket == generation, unlocked else { return false }
            cloudPreferences[provider] = policy; changed(); scheduleAutomaticBackup()
            return true
        } catch { if ticket == generation { message = error.localizedDescription }; return false }
    }
    func scheduleAutomaticBackup() {
        automaticBackupTask?.cancel()
        let ticket = generation
        automaticBackupTask = Task {
            do {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                while busy || photoImportReview != nil || fileImportReview != nil { try await Task.sleep(nanoseconds: 500_000_000) }
                try Task.checkCancellation()
                guard unlocked, ticket == generation else { return }
                if UserDefaults.standard.bool(forKey: "automaticFolderBackup"), BackupFolder.configured { await backup() }
                try Task.checkCancellation()
                if unlocked, ticket == generation {
                    cloud.refresh(); cloud.backup(vault: self, automaticOnly: true)
                }
            } catch { /* A newer change or lock supersedes this request. */ }
        }
    }
    func finishCloudRestore(_ archive: URL, recovery: String, code: String) async throws {
        guard !exists, VaultCode.valid(code) else { throw VaultError.exists }
        let ticket = generation
        let result = try await engine.restore(from: archive, password: recovery)
        exists = await engine.exists()
        guard ticket == generation, !Task.isCancelled else { await engine.lock(); throw CancellationError() }
        do { try await deviceAccess.enroll(code: code, credential: engine.credential()) }
        catch { await engine.lock(); throw error }
        guard ticket == generation, !Task.isCancelled else { await engine.lock(); throw CancellationError() }
        let preferences = try await engine.cloudPreferences()
        guard ticket == generation, !Task.isCancelled else { await engine.lock(); throw CancellationError() }
        cloudPreferences = preferences; items = result; unlocked = true; changed()
    }
    func updateMany(_ chosen: [VaultItem], album: String? = nil, deleted: Bool? = nil, permanently: Bool = false) async {
        guard unlocked, !busy else { return }
        busy = true; let ticket = generation
        do {
            for item in chosen {
                guard ticket == generation else { break }
                let result: [VaultItem]
                if permanently { result = try await engine.remove(id: item.id) }
                else { result = try await engine.update(id: item.id, album: album, deleted: deleted) }
                changed()
                if ticket == generation {
                    items = result
                    let current = Set(result.filter(\.visible).map(\.id))
                    for provider in CloudProvider.allCases {
                        cloudPreferences[provider].selected.formIntersection(current)
                        cloudPreferences[provider].blocked.formIntersection(current)
                    }
                }
            }
        } catch { if ticket == generation { message = error.localizedDescription } }
        busy = false
        if ticket == generation { scheduleAutomaticBackup() }
    }
    func backup() async {
        guard unlocked, !busy else { return }
        busy = true; progress = 0; let ticket = generation
        defer { busy = false }
        do {
            let source = try TemporaryFiles.fresh(extension: "c84backup")
            defer { try? FileManager.default.removeItem(at: source) }
            status = "Checking and preparing encrypted backup…"
            try StoragePreflight.require(bytes: items.reduce(Int64(0)) { $0 + Int64($1.byteCount) } * 2)
            try await engine.export(to: source)
            guard ticket == generation else { return }
            status = "Saving encrypted copy…"
            let destination = try await Task.detached(priority: .utility) { try BackupFolder.save(source) }.value
            guard ticket == generation else { return }
            recordBackup(destination)
            status = "Backup saved and checked. Check Files for cloud upload status."
        } catch { if ticket == generation {
            message = "Couldn’t save to the connected folder. Use Save Backup to Files, or reconnect the folder.\n\n" + error.localizedDescription
            status = "Backup not completed. Your local library is unchanged."
        } }
    }

    private func recordBackup(_ destination: URL) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastEncryptedExport")
        UserDefaults.standard.set(false, forKey: "libraryNeedsBackup")
        UserDefaults.standard.set(destination.lastPathComponent, forKey: "lastBackupFilename")
        UserDefaults.standard.set(destination.deletingLastPathComponent().lastPathComponent, forKey: "lastBackupFolder")
    }

    func connectBackupFolder(_ url: URL) {
        guard unlocked, !busy else { return }
        let access = url.startAccessingSecurityScopedResource()
        let ticket = generation
        busy = true; progress = 0; status = "Checking folder access…"
        Task {
            defer { if access { url.stopAccessingSecurityScopedResource() }; busy = false }
            do {
                try await Task.detached(priority: .utility) { try BackupFolder.remember(url) }.value
                if ticket == generation { status = "Folder connected. Tap Back Up to Connected Folder to save your library." }
            } catch { if ticket == generation {
                message = "Couldn’t connect this folder. You can still use Save Backup to Files.\n\n" + error.localizedDescription
                status = "Folder connection failed. Your files are unchanged."
            } }
        }
    }

    /// Hold the operation open until the Files picker returns. No changes may race
    /// this snapshot, and dismissing the picker must not set a false 'backed up' state.
    func prepareBackupForFiles() async -> PreparedBackup? {
        guard unlocked, !busy else { return nil }
        busy = true; progress = 0; let ticket = generation
        var source: URL?
        do {
            _ = try TemporaryFiles.fresh(extension: "c84backup")
            let url = TemporaryFiles.directory.appendingPathComponent(BackupFolder.filename())
            source = url; status = "Preparing encrypted backup…"
            try StoragePreflight.require(bytes: items.reduce(Int64(0)) { $0 + Int64($1.byteCount) } * 2)
            try await engine.export(to: url)
            try Task.checkCancellation()
            let digest = try await Task.detached(priority: .utility) { try BackupCopy.digest(url) }.value
            try Task.checkCancellation()
            guard ticket == generation, unlocked else { throw VaultError.locked }
            let request = PreparedBackup(url: url, digest: digest, generation: ticket)
            pendingBackup = request
            status = "Choose where to save, then tap Export or Save in Files."
            return request
        } catch {
            if let source { try? FileManager.default.removeItem(at: source) }
            busy = false
            if ticket == generation {
                if !Task.isCancelled { message = error.localizedDescription }
                status = Task.isCancelled ? "Backup preparation cancelled." : "Backup not completed."
            }
            return nil
        }
    }

    func finishBackupExport(_ request: PreparedBackup, destination: URL?) {
        guard pendingBackup?.id == request.id else { return }
        pendingBackup = nil
        let access = destination?.startAccessingSecurityScopedResource() ?? false
        Task {
            defer {
                if access { destination?.stopAccessingSecurityScopedResource() }
                try? FileManager.default.removeItem(at: request.url)
                busy = false
            }
            guard request.generation == generation, unlocked else { return }
            guard let destination else { status = "Save cancelled. No new backup was confirmed."; return }
            status = "Checking the saved copy…"
            do {
                try await Task.detached(priority: .utility) {
                    try BackupFolder.verifyExport(destination, expected: request.digest)
                }.value
                guard request.generation == generation else { return }
                recordBackup(destination)
                status = "Backup saved and checked. Keep its recovery key separately."
            } catch { if request.generation == generation {
                // A provider's save callback is not proof that our read-back succeeded.
                // Never discard the user's exported copy or mark the library safe here.
                status = "Files reported a save, but this copy still needs checking."
                message = "Choose Test a Backup and select \(destination.lastPathComponent). Keep this app and your originals until the test passes.\n\n" + error.localizedDescription
            } }
        }
    }
    func recordRecoveryTest(source: String, snapshot: String, library: String) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastRecoveryTest")
        UserDefaults.standard.set(source + " · " + snapshot + " · Library " + library, forKey: "lastRecoveryTestIdentity")
    }
    func verifyBackup(url: URL, recovery: String) async -> Bool {
        guard unlocked, !busy else { return false }
        busy = true; let ticket = generation
        defer { busy = false }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let count = try await engine.verifyBackup(from: url, password: recovery)
            guard ticket == generation else { return false }
            let digest = try await Task.detached(priority: .utility) { try CloudBackup.hash(url) }.value
            guard ticket == generation else { return false }
            recordRecoveryTest(source: "Files", snapshot: url.lastPathComponent + " · SHA-256 " + digest, library: "Contained in the tested archive")
            status = "Recovery test passed: \(count) items authenticated in a separate temporary library."
            return true
        } catch { if ticket == generation { message = error.localizedDescription }; return false }
    }
}
#endif
