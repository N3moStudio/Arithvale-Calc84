#if os(iOS)
import SwiftUI
import CalcCore

/// The form owns this state and its sheet. A recycled Section never owns a picker.
@MainActor
final class BackupInputModel: ObservableObject {
    enum Kind { case file, folder }
    struct Request: Identifiable {
        let id = UUID()
        let kind: Kind
    }
    @Published var request: Request?
    @Published private(set) var backup: BackupSelection?
    @Published private(set) var folder: BackupSelection?
    @Published private(set) var entries: [URL] = []
    @Published private(set) var working = false
    @Published private(set) var error: String?
    @Published private(set) var notice: String?
    private var pending: (Kind, BackupSelection)?
    private var receivedDelegateResult = false
    private var preparation: Task<Void, Never>?

    func choose(_ kind: Kind) {
        guard request == nil, !working else { return }
        pending = nil; receivedDelegateResult = false; error = nil; notice = nil
        request = Request(kind: kind)
    }
    func picked(_ url: URL?, for presented: Request) {
        // Ignore late callbacks from an older presentation after a retry.
        guard request?.id == presented.id else { return }
        receivedDelegateResult = true
        pending = url.map { (presented.kind, BackupSelection($0)) }
        if url == nil { notice = "Files closed without a selection. Your backup has not changed." }
        request = nil
    }
    func dismissed() {
        // Interactive dismissal is handled here, never by representable teardown.
        guard let value = pending else {
            if !receivedDelegateResult {
                notice = "Files closed before returning a selection. Use Receive Backup from Files above to share the file into this app instead."
            }
            return
        }
        pending = nil
        if value.0 == .folder { browse(value.1) }
        else { prepare(value.1.url, scope: value.1) }
    }
    func cancelPreparation() { preparation?.cancel() }

    private func browse(_ scope: BackupSelection) {
        folder = scope; entries = []; error = nil; notice = nil; working = true
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
    func prepare(_ url: URL, scope: BackupSelection? = nil, displayName: String? = nil) {
        guard !working else { return }
        working = true; error = nil; notice = nil
        let access = scope ?? BackupSelection(url); let parent = folder
        preparation = Task {
            defer { working = false }
            let worker = Task.detached(priority: .userInitiated) {
                defer { withExtendedLifetime(access) {}; withExtendedLifetime(parent) {} }
                return try BackupSelection.backupFile(url, displayName: displayName)
            }
            do {
                let value = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                backup = value; entries = []; folder = nil
            } catch {
                if !Task.isCancelled {
                    self.error = "Couldn’t prepare this backup. Your original file is unchanged. " + error.localizedDescription
                }
            }
        }
    }
}

struct BackupInputSection: View {
    @ObservedObject var input: BackupInputModel
    var enabled = true
    var body: some View {
        Section {
            Button("Choose Backup File", systemImage: "doc") { input.choose(.file) }
                .accessibilityIdentifier("backup.chooseFile")
            Button("Choose Backup Folder", systemImage: "folder") { input.choose(.folder) }
                .accessibilityIdentifier("backup.chooseFolder")
            if let backup = input.backup {
                Label(backup.displayName, systemImage: "doc.badge.checkmark")
                    .font(.subheadline).textSelection(.enabled)
                Text("Backup selected. Enter its original recovery key below.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let folder = input.folder {
                Text("Files in \(folder.displayName)").font(.headline)
                Text("Tap the backup filename here to select it.").font(.footnote)
                if input.entries.isEmpty && !input.working {
                    Text("No files found. Choose the folder containing your backup, or download it in Files first.")
                        .foregroundStyle(.secondary)
                }
                ForEach(input.entries, id: \.self) { url in
                    Button { input.prepare(url) } label: {
                        Label(url.lastPathComponent, systemImage: "doc")
                            .lineLimit(3).frame(minHeight: 44, alignment: .leading)
                    }.buttonStyle(.borderless)
                }
            }
            if input.working { ProgressView("Preparing backup…") }
            if let error = input.error { Text(error).foregroundStyle(.secondary).accessibilityIdentifier("backup.error") }
            if let notice = input.notice { Text(notice).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("backup.pickerNotice") }
        } header: { Text("Encrypted Backup") } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("File: tap the backup itself. Folder: open the folder containing it, tap Open, then tap the filename in the list above. Opening a folder alone does not select a backup.")
                Text("If the picker closes or will not select the file, use Receive Backup from Files above. That route bypasses this picker.")
            }
        }.disabled(input.working || !enabled)
    }
}

/// Attach once to the Form, outside conditional sections and rows.
private struct BackupPickerPresentation: ViewModifier {
    @ObservedObject var input: BackupInputModel
    func body(content: Content) -> some View {
        content.sheet(item: $input.request, onDismiss: input.dismissed) { request in
            BackupDocumentPicker(purpose: request.kind == .file ? .openBackup : .folder) { url in
                input.picked(url, for: request)
            }.id(request.id)
        }
        .onDisappear { input.cancelPreparation() }
    }
}
extension View {
    func backupPicker(_ input: BackupInputModel) -> some View {
        modifier(BackupPickerPresentation(input: input))
    }
}
#endif
