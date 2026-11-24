#if os(iOS)
import SwiftUI
import CalcCore
import UniformTypeIdentifiers

enum BackupImportTypes {
    static let files: [UTType] = {
        let registered = BackupFileProbe.extensions.flatMap {
            UTType.types(tag: $0, tagClass: .filenameExtension, conformingTo: nil)
        }
        var seen = Set<String>()
        return (registered + [UTType(exportedAs: "studio.n3mo.calc84.backup"), .data, .item])
            .filter { seen.insert($0.identifier).inserted }
    }()
}

/// The form owns this state and its sheet. A recycled Section never owns a picker.
@MainActor
final class BackupInputModel: ObservableObject {
    enum Kind { case file, folder }
    struct Request: Identifiable {
        let id = UUID()
        let kind: Kind
    }
    @Published private(set) var request: Request?
    @Published var isChoosing = false
    @Published private(set) var backup: BackupSelection?
    @Published private(set) var folder: BackupSelection?
    @Published private(set) var entries: [URL] = []
    @Published private(set) var working = false
    @Published private(set) var error: String?
    @Published private(set) var notice: String?
    private var preparation: Task<Void, Never>?

    func choose(_ kind: Kind) {
        guard request == nil, !working else { return }
        error = nil; notice = nil
        request = Request(kind: kind)
        isChoosing = true
    }
    func picked(_ result: Result<[URL], Error>, for presented: Request) {
        guard request?.id == presented.id else { return }
        request = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { selectionCancelled(); return }
            let access = BackupSelection(url)
            if presented.kind == .folder { browse(access) }
            else { prepare(url, scope: access) }
        case .failure(let failure):
            error = failure.localizedDescription
        }
    }
    func selectionCancelled() {
        request = nil
        notice = "No file selected."
    }
    func cancelPreparation() { preparation?.cancel() }
    func clearSelection() {
        guard !working, request == nil else { return }
        backup = nil; folder = nil; entries = []; error = nil; notice = nil
    }

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
    func usePrepared(_ selection: BackupSelection) {
        backup = selection; entries = []; folder = nil; error = nil; notice = nil
    }
    func prepare(_ url: URL, scope: BackupSelection? = nil, displayName: String? = nil) {
        guard !working else { return }
        // A failed replacement must never leave the previous archive actionable
        // under the newly selected filename/error.
        backup = nil; working = true; error = nil; notice = nil
        let access = scope ?? BackupSelection(url); let parent = folder
        preparation = Task {
            defer { working = false }
            let worker = Task.detached(priority: .userInitiated) {
                defer { withExtendedLifetime(access) {}; withExtendedLifetime(parent) {} }
                return try BackupSelection.backupFile(access, displayName: displayName)
            }
            do {
                let value = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                usePrepared(value)
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
                    .font(.footnote).foregroundStyle(ArithenPalette.color(.muted))
                StorageEstimateView(bytes: Int64((try? backup.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0))
            }
            if let folder = input.folder {
                Text("Files in \(folder.displayName)").font(.headline)
                Text("Tap the backup filename here to select it.").font(.footnote)
                if input.entries.isEmpty && !input.working {
                    Text("No files found. Choose the folder containing your backup, or download it in Files first.")
                        .foregroundStyle(ArithenPalette.color(.muted))
                }
                ForEach(input.entries, id: \.self) { url in
                    Button { input.prepare(url) } label: {
                        Label(url.lastPathComponent, systemImage: "doc")
                            .lineLimit(3).frame(minHeight: 44, alignment: .leading)
                    }.buttonStyle(.borderless)
                }
            }
            if input.working { ProgressView("Preparing backup…") }
            if let error = input.error { Text(error).foregroundStyle(ArithenPalette.color(.muted)).accessibilityIdentifier("backup.error") }
            if let notice = input.notice { Text(notice).font(.footnote).foregroundStyle(ArithenPalette.color(.muted)).accessibilityIdentifier("backup.pickerNotice") }
        } header: { Text("Encrypted Backup") } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose a backup file or browse its folder.")
                Text("Sharing from Files is also available.")
            }
        }.disabled(input.working || !enabled)
    }
}

/// Attach once to the Form, outside conditional sections and rows.
private struct BackupPickerPresentation: ViewModifier {
    @ObservedObject var input: BackupInputModel
    func body(content: Content) -> some View {
        let request = input.request
        let types = request?.kind == .folder ? [UTType.folder] : BackupImportTypes.files
        content.fileImporter(isPresented: $input.isChoosing, allowedContentTypes: types,
                             allowsMultipleSelection: false) { result in
            if let request { input.picked(result, for: request) }
        } onCancellation: {
            if let request, input.request?.id == request.id { input.selectionCancelled() }
        }
        .fileDialogBrowserOptions(.displayFileExtensions)
        .onDisappear { input.cancelPreparation() }
    }
}
extension View {
    func backupPicker(_ input: BackupInputModel) -> some View {
        modifier(BackupPickerPresentation(input: input))
    }
}
#endif
