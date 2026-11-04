#if os(iOS)
import SwiftUI
import CalcCore

@MainActor
private final class BackupReviewModel: ObservableObject {
    let root: URL
    let engine: VaultEngine
    @Published private(set) var items: [VaultItem] = []
    @Published private(set) var credential: VaultCredential?
    @Published private(set) var working = false
    @Published private(set) var error: String?
    @Published private(set) var phase = "Preparing backup…"
    private var operation: Task<Void, Never>?
    init() {
        root = TemporaryFiles.directory.appendingPathComponent("review-" + UUID().uuidString, isDirectory: true)
        engine = VaultEngine(root: root)
    }
    func prepare(_ backup: BackupSelection, key: String) {
        guard !working, credential == nil else { return }
        working = true; error = nil; phase = "Preparing backup…"
        operation = Task {
            defer { working = false; withExtendedLifetime(backup) {} }
            do {
                let bytes = Int64(try backup.url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
                try StoragePreflight.require(bytes: bytes * 3)
                phase = "Checking the recovery key and authenticating every file…"
                let restored = try await engine.restore(from: backup.url, password: key)
                try Task.checkCancellation()
                let access = try await engine.credential()
                try Task.checkCancellation()
                items = restored.filter { $0.visible && $0.deletedAt == nil }
                credential = access
            } catch {
                await engine.lock()
                try? FileManager.default.removeItem(at: root)
                if !Task.isCancelled { self.error = error.localizedDescription }
            }
        }
    }
    func clear() {
        operation?.cancel(); items = []; credential = nil
        let pending = operation, engine = engine, root = root
        Task {
            await pending?.value
            await engine.lock()
            try? FileManager.default.removeItem(at: root)
        }
    }
}

struct BackupImportView: View {
    @EnvironmentObject private var vault: VaultModel
    @EnvironmentObject private var shared: SharedBackupModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var input = BackupInputModel()
    @StateObject private var review = BackupReviewModel()
    @State private var key = ""
    @State private var selected = Set<UUID>()
    @State private var result: BackupImportResult?
    @State private var usedReceipt: URL?
    @State private var removeReceived = false
    @State private var importError: String?
    var body: some View {
        Group {
            if let result {
                ContentUnavailableView {
                    Label("Added to Your Library", systemImage: "checkmark.circle")
                } description: {
                    Text("\(result.added) items added · \(result.skipped) exact duplicates skipped\nYour current recovery key stays the same.")
                } actions: { Button("View Library") { dismiss() }.buttonStyle(.borderedProminent) }
            } else {
                ThemedForm {
                    Section {
                        Text("In Files, share the backup to LiveContainer, choose Arithen, then unlock the library.").foregroundStyle(ArithenPalette.color(.muted))
                        if let entry = shared.entry { Label(entry.displayName, systemImage: "doc.badge.arrow.up").font(.subheadline) }
                        SecureField("Backup recovery key", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button("Import") {
                            if let backup = input.backup { review.prepare(backup, key: key); key = "" }
                        }.buttonStyle(ImportButtonStyle())
                            .disabled(input.backup == nil || key.isEmpty || shared.working || input.working || review.working || vault.busy)
                        if shared.working || input.working { ProgressView("Receiving backup…") }
                        if review.working || vault.importing {
                            OperationProgressView(title: "Importing Backup", detail: vault.importing ? vault.status : review.phase)
                        }
                        if let error = shared.error ?? input.error ?? review.error { Text(error).font(.footnote).foregroundStyle(ArithenPalette.color(.muted)) }
                    }
                    if shared.entry != nil {
                        Section { Button("Remove Received Copy", role: .destructive) { removeReceived = true }
                            .disabled(input.working || review.working || vault.busy) }
                    }
                }
            }
        }
        .navigationTitle("Add from Backup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) {
            Button(vault.importing ? "Cancel Import" : "Close") {
                if vault.importing { vault.cancelImport() } else { dismiss() }
            }
        } }
        .interactiveDismissDisabled(vault.importing)
        .task {
            if input.backup == nil, let entry = shared.entry {
                usedReceipt = entry.url; input.prepare(entry.url, displayName: entry.displayName)
            }
        }
        .onChange(of: shared.entry?.url) { _, _ in receiveBackup() }
        .onChange(of: review.working) { _, working in
            if !working, let credential = review.credential {
                let ids = Set(review.items.map(\.id))
                guard !ids.isEmpty else { importError = "This backup has no active items to import."; review.clear(); return }
                vault.addFromBackup(root: review.root, credential: credential, selected: ids) { value in
                    switch value {
                    case .success(let added):
                        result = added
                        if shared.entry?.url == usedReceipt { shared.discard() }
                        review.clear()
                    case .failure(let error): importError = error.localizedDescription; review.clear()
                    }
                }
            }
        }
        .onChange(of: vault.unlocked) { _, unlocked in if !unlocked { review.clear(); key = ""; dismiss() } }
        .onDisappear { key = ""; if vault.importing { vault.cancelImport() }; review.clear() }
        .confirmationDialog("Remove received copy?", isPresented: $removeReceived, titleVisibility: .visible) {
            Button("Remove Received Copy", role: .destructive) { input.clearSelection(); usedReceipt = nil; shared.discard() }
        } message: { Text("The original in Files is unchanged. You can share another backup after removing this received copy.") }
        .alert("Couldn’t Add Backup", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("Close", role: .cancel) { importError = nil }
        } message: { Text(importError ?? "") }
    }
    private func receiveBackup() {
        guard !input.working, !review.working, !vault.busy, let entry = shared.entry else { return }
        usedReceipt = entry.url; input.prepare(entry.url, displayName: entry.displayName)
    }
}
#endif
