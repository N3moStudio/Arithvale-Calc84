#if os(iOS)
import SwiftUI
import CalcCore

/// Both recovery flows share this picker. Folder browsing avoids host UTI filters.
struct BackupChooserView: View {
    let selected: (BackupSelection) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var picker: Choice?
    @State private var folder: BackupSelection?
    @State private var entries: [URL] = []
    @State private var error: String?
    @State private var working = false
    @State private var preparation: Task<Void, Never>?
    private enum Choice: String, Identifiable { case file, folder; var id: String { rawValue } }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Choose Backup File", systemImage: "doc") { picker = .file }
                    Button("Browse a Folder Instead", systemImage: "folder") { picker = .folder }
                } footer: {
                    Text("If Files grays out your backup, choose its folder using Browse a Folder Instead, tap Open, then tap the backup below. This bypasses file-type filtering in the host app. A renamed backup can also be selected; its contents are checked.")
                }
                if let folder {
                    Section(folder.displayName) {
                        if entries.isEmpty { Text("No files found in this folder. Try another folder or download the backup in Files first.") }
                        ForEach(entries, id: \.self) { url in
                            Button(url.lastPathComponent) { prepare(url) }.frame(minHeight: 44)
                        }
                    }
                }
                if working { Section { ProgressView("Copying backup for safe access…") } }
                if let error { Section { Text(error).foregroundStyle(.secondary) } }
            }.disabled(working)
            .navigationTitle("Choose Backup").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { preparation?.cancel(); dismiss() } } }
            .sheet(item: $picker) { choice in
                BackupDocumentPicker(purpose: choice == .file ? .openBackup : .folder) { url in
                    picker = nil
                    guard let url else { return }
                    if choice == .file { prepare(url) } else { browse(url) }
                }
            }
        }
        .interactiveDismissDisabled(working)
        .onDisappear { preparation?.cancel() }
    }
    private func browse(_ url: URL) {
        let scope = BackupSelection(url); folder = scope; error = nil; entries = []; working = true
        preparation = Task {
            defer { working = false }
            do {
                let values = try await Task.detached {
                    defer { withExtendedLifetime(scope) {} }
                    let files = try FileManager.default.contentsOfDirectory(at: url,
                        includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                    guard files.count <= 10_000 else { throw VaultError.limit }
                    return try files.filter { try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory != true }
                        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                }.value
                try Task.checkCancellation(); entries = values
            } catch { if !Task.isCancelled { self.error = "Couldn’t read this folder. Download the backup in Files and try again. " + error.localizedDescription } }
        }
    }
    private func prepare(_ url: URL) {
        working = true; error = nil
        let scope = BackupSelection(url); let parentScope = folder
        preparation = Task {
            defer { working = false }
            let worker = Task.detached {
                defer { withExtendedLifetime(scope) {}; withExtendedLifetime(parentScope) {} }
                return try BackupSelection.backupFile(url)
            }
            do {
                let value = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                selected(value); dismiss()
            } catch { if !Task.isCancelled { self.error = "Couldn’t import this backup. Try Browse a Folder Instead or download the file in Files first. " + error.localizedDescription } }
        }
    }
}
#endif
