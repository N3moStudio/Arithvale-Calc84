#if os(iOS)
import SwiftUI
import CalcCore

/// Embedded directly in each recovery form: no intermediate chooser sheet.
struct BackupInputSection: View {
    @Binding var backup: BackupSelection?
    var enabled = true
    @Binding var working: Bool
    @State private var picker: Choice?
    @State private var pending: (Choice, BackupSelection)?
    @State private var folder: BackupSelection?
    @State private var entries: [URL] = []
    @State private var error: String?
    @State private var preparation: Task<Void, Never>?
    private enum Choice: String, Identifiable { case file, folder; var id: String { rawValue } }

    var body: some View {
        Section {
            Button("Choose Backup File", systemImage: "doc") { picker = .file }
                .accessibilityIdentifier("backup.chooseFile")
            Button("Choose Backup Folder", systemImage: "folder") { picker = .folder }
                .accessibilityIdentifier("backup.chooseFolder")
            if let backup {
                Label(backup.displayName, systemImage: "doc.badge.checkmark")
                    .font(.subheadline).textSelection(.enabled)
                Text("Backup selected. Enter its original recovery key below.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let folder {
                Text("Files in \(folder.displayName)").font(.headline)
                Text("Tap the backup filename here to select it.").font(.footnote)
                if entries.isEmpty && !working {
                    Text("No files found. Choose the folder containing your backup, or download it in Files first.")
                        .foregroundStyle(.secondary)
                }
                ForEach(entries, id: \.self) { url in
                    Button { prepare(url) } label: {
                        Label(url.lastPathComponent, systemImage: "doc")
                            .lineLimit(3).frame(minHeight: 44, alignment: .leading)
                    }.buttonStyle(.borderless)
                }
            }
            if working { ProgressView("Preparing backup…") }
            if let error { Text(error).foregroundStyle(.secondary).accessibilityIdentifier("backup.error") }
        } header: { Text("Encrypted Backup") } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("File: tap the backup itself. Folder: open the folder containing it, tap Open, then tap the filename in the list above. Opening a folder alone does not select a backup.")
                Text("If LiveContainer’s picker does not respond, enable Fix File Picker in this app’s LiveContainer settings, then relaunch it.")
            }
        }
        .disabled(working || !enabled)
        .sheet(item: $picker, onDismiss: consumeSelection) { choice in
            BackupDocumentPicker(purpose: choice == .file ? .openBackup : .folder) { url in
                // Take the temporary permission before the document controller dismisses.
                pending = url.map { (choice, BackupSelection($0)) }
                picker = nil
            }
        }
        .onDisappear { preparation?.cancel() }
    }

    private func consumeSelection() {
        guard let request = pending else { return }
        pending = nil
        if request.0 == .folder { browse(request.1) }
        else { prepare(request.1.url, scope: request.1) }
    }

    private func browse(_ scope: BackupSelection) {
        folder = scope; entries = []; error = nil; working = true
        preparation = Task {
            defer { working = false }
            let worker = Task.detached(priority: .userInitiated) {
                defer { withExtendedLifetime(scope) {} }
                var coordinationError: NSError?
                var result: Result<[URL], Error>?
                NSFileCoordinator().coordinate(readingItemAt: scope.url, options: [], error: &coordinationError) { url in
                    result = Result { try BackupFileProbe.files(in: url) }
                }
                if let coordinationError { throw coordinationError }
                guard let result else { throw CocoaError(.fileReadUnknown) }
                return try result.get()
            }
            do {
                let files = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation(); entries = files
            } catch {
                if !Task.isCancelled { self.error = "Couldn’t read this folder. " + error.localizedDescription }
            }
        }
    }

    private func prepare(_ url: URL, scope: BackupSelection? = nil) {
        working = true; error = nil
        let access = scope ?? BackupSelection(url); let parent = folder
        preparation = Task {
            defer { working = false }
            let worker = Task.detached(priority: .userInitiated) {
                defer { withExtendedLifetime(access) {}; withExtendedLifetime(parent) {} }
                return try BackupSelection.backupFile(url)
            }
            do {
                let value = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                backup = value; entries = []; folder = nil
            } catch {
                if !Task.isCancelled {
                    self.error = "Couldn’t select this backup. Use Choose Backup Folder if the file picker cannot open it. " + error.localizedDescription
                }
            }
        }
    }
}
#endif
