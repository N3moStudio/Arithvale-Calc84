#if os(iOS)
import Foundation
import CalcCore
import SwiftUI
import UniformTypeIdentifiers

/// Keep the picker's temporary permission alive until its sheet has finished
/// dismissing. Only then start validation and show any result/error.
final class BackupSelection: @unchecked Sendable {
    let url: URL
    let displayName: String
    private let access: Bool
    private let owned: Bool
    init(_ url: URL, owned: Bool = false, displayName: String? = nil) {
        self.url = url; self.owned = owned; self.displayName = displayName ?? url.lastPathComponent
        access = url.startAccessingSecurityScopedResource()
    }
    deinit {
        if access { url.stopAccessingSecurityScopedResource() }
        if owned { try? FileManager.default.removeItem(at: url) }
    }
    static func backupFile(_ source: URL, displayName: String? = nil) throws -> BackupSelection {
        let scope = BackupSelection(source)
        defer { withExtendedLifetime(scope) {} }
        let copy = try TemporaryFiles.fresh(extension: "c84backup")
        var succeeded = false
        defer { if !succeeded { try? FileManager.default.removeItem(at: copy) } }
        var coordinationError: NSError?
        var result: Result<Void, Error>?
        NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { url in
            result = Result {
                try Task.checkCancellation()
                try BackupFileProbe.validate(url)
                let bytes = Int64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
                try StoragePreflight.require(bytes: bytes * 2)
                try BackupCopy.copy(url, to: copy)
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: copy.path)
                try Task.checkCancellation()
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw VaultError.invalidBackup }
        try result.get(); succeeded = true
        return BackupSelection(copy, owned: true, displayName: displayName ?? source.lastPathComponent)
    }
}

enum BackupFolder {
    static var configured: Bool { UserDefaults.standard.data(forKey: "backupFolderBookmark") != nil }
    static var name: String { UserDefaults.standard.string(forKey: "backupFolderName") ?? "Not connected" }
    static func filename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "Library-\(formatter.string(from: Date()))-\(UUID().uuidString).c84backup"
    }
    /// Keep the old bookmark until a real coordinated write/read/delete succeeds.
    static func remember(_ url: URL) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        try requireExternalLocation(url)
        guard try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            throw MediaBridge.failure("Select a folder, then tap Open. To save just one backup, use Save Backup to Files instead.")
        }
        let probe = url.appendingPathComponent(".calc84-write-check-\(UUID().uuidString)")
        try coordinatedWrite(probe) { target in
            let bytes = Data(UUID().uuidString.utf8)
            try bytes.write(to: target, options: .withoutOverwriting)
            defer { try? FileManager.default.removeItem(at: target) }
            guard try Data(contentsOf: target) == bytes else { throw VaultError.invalidBackup }
            try FileManager.default.removeItem(at: target)
        }
        let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        // Validate the saved grant too, before replacing the last working folder.
        var stale = false
        let resolved = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        guard !stale else { throw MediaBridge.failure("The folder permission expired. Choose the folder again.") }
        let resolvedAccess = resolved.startAccessingSecurityScopedResource()
        defer { if resolvedAccess { resolved.stopAccessingSecurityScopedResource() } }
        try requireExternalLocation(resolved)
        guard try resolved.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            throw MediaBridge.failure("The provider did not return a folder permission. Choose another location.")
        }
        let restoredProbe = resolved.appendingPathComponent(".calc84-bookmark-check-\(UUID().uuidString)")
        try coordinatedWrite(restoredProbe) { target in
            let bytes = Data(UUID().uuidString.utf8)
            try bytes.write(to: target, options: .withoutOverwriting)
            defer { try? FileManager.default.removeItem(at: target) }
            guard try Data(contentsOf: target) == bytes else { throw VaultError.invalidBackup }
            try FileManager.default.removeItem(at: target)
        }
        UserDefaults.standard.set(bookmark, forKey: "backupFolderBookmark")
        UserDefaults.standard.set(url.lastPathComponent, forKey: "backupFolderName")
    }
    private static func requireExternalLocation(_ url: URL) throws {
        let root = URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath().standardizedFileURL.path
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard path != root, !path.hasPrefix(root + "/") else {
            throw MediaBridge.failure("Choose a folder outside this app or its LiveContainer data. Copies inside the app can disappear when it is deleted.")
        }
    }
    static func resolve() throws -> URL {
        guard let data = UserDefaults.standard.data(forKey: "backupFolderBookmark") else {
            throw MediaBridge.failure("Connect a folder first, or use Save Backup to Files without connecting one.")
        }
        var stale = false
        let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        if stale { try remember(url) }
        return url
    }
    static func forget() {
        UserDefaults.standard.removeObject(forKey: "backupFolderBookmark")
        UserDefaults.standard.removeObject(forKey: "backupFolderName")
        UserDefaults.standard.set(false, forKey: "automaticFolderBackup")
    }
    struct SaveResult: Sendable {
        let url: URL
        let digest: Data
        let cleanupDeferred: Bool
    }
    private static func managedBackups(folder: URL, library: UUID) throws -> AutomaticFolderBackups {
        var history = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AutomaticBackupHistory", isDirectory: true)
        try FileManager.default.createDirectory(at: history, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try history.setResourceValues(values)
        return AutomaticFolderBackups(folder: folder, historyDirectory: history, library: library)
    }
    static func automaticDelay(library: UUID) throws -> TimeInterval {
        let folder = try resolve()
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        return try managedBackups(folder: folder, library: library).delay()
    }
    static func save(_ source: URL, library: UUID, automatic: Bool) throws -> SaveResult {
        let folder = try resolve()
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        try requireExternalLocation(folder)
        if automatic {
            let saved = try managedBackups(folder: folder, library: library).save(source, coordinate: coordinate)
            return SaveResult(url: saved.url, digest: saved.digest, cleanupDeferred: saved.cleanupDeferred)
        }
        // Explicit saves remain outside the automatic retention journal.
        let destination = folder.appendingPathComponent(filename())
        try coordinatedWrite(destination) { try BackupCopy.copy(source, to: $0) }
        return SaveResult(url: destination, digest: try BackupCopy.digest(source), cleanupDeferred: false)
    }
    static func verifyExport(_ destination: URL, expected: Data) throws {
        try requireExternalLocation(destination)
        var coordinationError: NSError?
        var result: Result<Void, Error>?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: destination, options: [], error: &coordinationError) { url in
            result = Result { try BackupCopy.verify(url, expected: expected) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw MediaBridge.failure("The provider did not allow the saved copy to be read. Use Test a Backup to check it.") }
        try result.get()
    }
    private static func coordinatedWrite(_ destination: URL, body: (URL) throws -> Void) throws {
        var coordinationError: NSError?
        var result: Result<Void, Error>?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: destination, options: [], error: &coordinationError) { url in
            result = Result { try body(url) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw MediaBridge.failure("The Files provider did not complete the request. Try Save Backup to Files or another location.") }
        try result.get()
    }
    private static func coordinate(_ url: URL, operation: AutomaticFolderBackups.Operation,
                                   body: (URL) throws -> Void) throws {
        var coordinationError: NSError?
        var result: Result<Void, Error>?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        switch operation {
        case .read:
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { target in
                result = Result { try body(target) }
            }
        case .write, .delete:
            coordinator.coordinate(writingItemAt: url, options: operation == .delete ? .forDeleting : [], error: &coordinationError) { target in
                result = Result { try body(target) }
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw MediaBridge.failure("The Files provider did not finish checking the backup. Older copies were kept.") }
        try result.get()
    }
}

/// Cancel and interactive dismissal never count as a successful save.
struct BackupDocumentPicker: UIViewControllerRepresentable {
    enum Purpose { case folder, connectFolder, openBackup, save(URL) }
    let purpose: Purpose
    let finished: (URL?) -> Void
    var failure: ((String) -> Void)? = nil
    init(purpose: Purpose, failure: ((String) -> Void)? = nil, finished: @escaping (URL?) -> Void) {
        self.purpose = purpose; self.failure = failure; self.finished = finished
    }
    func makeCoordinator() -> Coordinator { Coordinator(finished, failure: failure) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker: UIDocumentPickerViewController
        switch purpose {
        case .folder, .connectFolder:
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
            picker.title = "Choose Folder, Then Tap Open"
            // Do not force Files to reopen a stale provider URL.
        case .openBackup:
            // LiveContainer may not register the guest app's exported UTI. The archive
            // reader still authenticates the content; the picker must not hide the file.
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
            picker.title = "Import Backup File"
        case .save(let url):
            picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        }
        picker.allowsMultipleSelection = false
        // Selecting the folder itself also works when a host expands the type filter.
        if case .connectFolder = purpose { picker.allowsMultipleSelection = true }
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    static func dismantleUIViewController(_ controller: UIDocumentPickerViewController, coordinator: Coordinator) {
        // SwiftUI can dismantle an obsolete controller while replacing its presentation.
        // Teardown is cleanup, not a user cancellation; never mutate sheet state here.
        controller.delegate = nil
        coordinator.invalidate()
    }
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private var finished: ((URL?) -> Void)?
        private var completed = false
        private let failure: ((String) -> Void)?
        init(_ finished: @escaping (URL?) -> Void, failure: ((String) -> Void)?) {
            self.finished = finished; self.failure = failure
        }
        func finish(_ url: URL?) {
            guard !completed else { return }
            completed = true
            let callback = finished; finished = nil
            callback?(url)
        }
        func invalidate() { completed = true; finished = nil }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard urls.count == 1 else {
                guard !completed else { return }
                if let failure { completed = true; finished = nil; failure("Select one folder, then tap Open.") }
                else { finish(nil) }
                return
            }
            finish(urls.first)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finish(nil) }
    }
}
#endif
