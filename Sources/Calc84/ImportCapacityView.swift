#if os(iOS)
import SwiftUI
import PhotosUI
import CalcCore
#if canImport(_PhotosUI_SwiftUI)
import _PhotosUI_SwiftUI
#endif

final class ImportCapacityRequest: Identifiable {
    let id = UUID()
    let files: [URL]
    let photos: [PhotosPickerItem]
    let access: ImportAccess
    init(files: [URL] = [], photos: [PhotosPickerItem] = []) {
        self.files = files; self.photos = photos; access = ImportAccess(files)
    }
}

struct ImportCapacityView: View {
    let request: ImportCapacityRequest
    let close: () -> Void
    @EnvironmentObject private var vault: VaultModel
    @State private var total: Int64?
    @State private var available: Int64?
    @State private var count = 0
    @State private var preparing = true
    @State private var error: String?
    private var sufficient: Bool {
        guard let total, let available else { return true }
        return available >= StorageBudget.required(sourceBytes: total, copies: 3)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Review Your Import", systemImage: "square.and.arrow.down").font(.headline)
                    if preparing { ProgressView("Checking selected files…") }
                    else { Text("\(count) items selected") }
                    if let total {
                        LabeledContent("Original size", value: ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
                        StorageEstimateView(bytes: total)
                    } else if !preparing {
                        Text("Photos and some file providers don’t supply exact sizes before download. Arithen checks available space as each original becomes available.")
                        if let available { Text(ByteCountFormatter.string(fromByteCount: available, countStyle: .file) + " available on this phone") }
                    }
                } footer: { Text("Originals stay where they are. After a verified import, you can separately choose whether to move supported originals to Trash or Recently Deleted.") }
                if let error { Section { Text(error).foregroundStyle(.secondary) } }
            }.navigationTitle("Import").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: close) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") {
                            if !request.photos.isEmpty { vault.importPhotos(request.photos) }
                            else { vault.importFiles(request.files, accessParent: request.access) }
                            close()
                        }.disabled(preparing || error != nil || !sufficient || count == 0 || vault.busy)
                    }
                }
        }.task {
            do {
                available = try StoragePreflight.available()
                if !request.photos.isEmpty { count = request.photos.count }
                else {
                    let files = request.files, access = request.access
                    let worker = Task.detached(priority: .utility) { () throws -> (Int, Int64?) in
                        defer { withExtendedLifetime(access) {} }
                        let expanded = try ImportFileList.expand(files)
                        var bytes: Int64 = 0, known = true
                        for url in expanded {
                            try Task.checkCancellation()
                            if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize { bytes += Int64(size) }
                            else { known = false }
                        }
                        return (expanded.count, known ? bytes : nil)
                    }
                    let result = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                    try Task.checkCancellation(); count = result.0; total = result.1
                }
            } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
            preparing = false
        }
    }
}
#endif
