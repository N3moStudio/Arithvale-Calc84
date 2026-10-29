#if os(iOS)
import SwiftUI
import CalcCore

/// Immutable scope ownership shared by the import task and its review, across I/O tasks.
final class ImportAccess: @unchecked Sendable {
    private let granted: [URL]
    private let parent: ImportAccess?
    init(_ urls: [URL], parent: ImportAccess? = nil) {
        self.parent = parent
        granted = urls.filter { $0.startAccessingSecurityScopedResource() }
    }
    deinit { for url in granted { url.stopAccessingSecurityScopedResource() } }
}

struct ImportedFileOriginal: Sendable {
    let vaultID: UUID
    let url: URL
    let digest: Data
}
struct FileImportReview: Identifiable, Sendable {
    let id = UUID()
    let imported: Int
    let requested: Int
    let originals: [ImportedFileOriginal]
    let access: ImportAccess
    let detail: String?
}
struct FileTrashResult: Sendable {
    var removed: Set<UUID> = []
    var errors: [String] = []
}

enum OriginalFiles {
    /// Import an exact coordinated snapshot, rather than a source that another app can edit.
    static func snapshot(_ source: URL, to destination: URL) throws -> Data {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var result: Result<Data, Error>?
        coordinator.coordinate(readingItemAt: source, options: [], error: &coordinationError) { url in
            result = Result {
                try Task.checkCancellation()
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else { throw VaultError.missing }
                try FileManager.default.copyItem(at: url, to: destination)
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: destination.path)
                try Task.checkCancellation()
                return try BackupCopy.digest(destination)
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw VaultError.missing }
        return try result.get()
    }
    static func trash(_ original: ImportedFileOriginal) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var operationError: Error?
        coordinator.coordinate(writingItemAt: original.url, options: .forDeleting, error: &coordinationError) { url in
            do {
                try Task.checkCancellation()
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true,
                      try BackupCopy.digest(url) == original.digest else { throw VaultError.changed }
                try Task.checkCancellation()
                // No permanent-delete fallback. Unsupported providers leave the file alone.
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch { operationError = error }
        }
        if let coordinationError { throw coordinationError }
        if let operationError { throw operationError }
    }
}

struct FileImportReviewView: View {
    let review: FileImportReview
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirming = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("\(review.imported) files imported", systemImage: "checkmark.shield").font(.headline)
                    Text("Encrypted copies were saved and checked. Keep the originals, or allow \(AppBrand.name) to move the successfully imported files to Trash.")
                    if review.imported < review.requested {
                        Text("\(review.requested - review.imported) were not imported. Those originals will stay.")
                    }
                    if let detail = review.detail { Text(detail).font(.footnote).foregroundStyle(.secondary) }
                }
                Section("Originals eligible for Trash · \(review.originals.count)") {
                    ForEach(review.originals, id: \.vaultID) { original in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(original.url.lastPathComponent)
                            Text(original.url.deletingLastPathComponent().lastPathComponent).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    if vault.failedImportCount > 0 {
                        Button("Retry Unimported Items") { vault.retryImports() }
                    }
                    Button("Keep Originals") { dismiss() }
                    if !review.originals.isEmpty {
                        Button("Move \(review.originals.count) Originals to Trash", role: .destructive) { confirming = true }
                    }
                } footer: {
                    Text("Files are checked again before moving. Changed files and providers without Trash support are kept. Folders are never deleted. Check Files → Recently Deleted or your provider’s Trash; retention is controlled by that provider. Cloud providers may sync the removal to your other devices. Save and test a backup first if the vault will be your only copy.")
                }
                if vault.busy { Section { ProgressView("Checking originals…") } }
            }.disabled(vault.busy)
            .navigationTitle("Import Complete").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(vault.busy) } }
            .confirmationDialog("Allow \(AppBrand.name) to move \(review.originals.count) original files to Trash?", isPresented: $confirming, titleVisibility: .visible) {
                Button("Move \(review.originals.count) Files to Trash", role: .destructive) { vault.trashImportedFiles(review) }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Only the listed, successfully imported files are eligible. Your encrypted copies remain in Arithen.") }
        }.interactiveDismissDisabled(vault.busy)
    }
}
#endif
