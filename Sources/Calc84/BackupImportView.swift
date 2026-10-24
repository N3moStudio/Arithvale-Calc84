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
    private var operation: Task<Void, Never>?
    init() {
        root = TemporaryFiles.directory.appendingPathComponent("review-" + UUID().uuidString, isDirectory: true)
        engine = VaultEngine(root: root)
    }
    func prepare(_ backup: BackupSelection, key: String) {
        guard !working, credential == nil else { return }
        working = true; error = nil
        operation = Task {
            defer { working = false; withExtendedLifetime(backup) {} }
            do {
                let bytes = Int64(try backup.url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
                try StoragePreflight.require(bytes: bytes * 3)
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
            } else if review.credential != nil {
                preview
            } else {
                Form {
                    Section {
                        if let entry = shared.entry {
                            Label(entry.displayName, systemImage: "doc.badge.arrow.up").font(.subheadline)
                            Button("Use Received Backup") { usedReceipt = entry.url; input.prepare(entry.url, displayName: entry.displayName) }
                                .disabled(input.working || review.working || vault.busy)
                            Button("Remove Received Copy", role: .destructive) { removeReceived = true }
                                .disabled(input.working || review.working || vault.busy)
                        } else {
                            NavigationLink { SharedBackupGuide() } label: { Label("Receive Backup from Files", systemImage: "square.and.arrow.down") }
                            Text("In Files, share the backup to LiveContainer, choose Arithvale, then unlock your library.").font(.footnote).foregroundStyle(.secondary)
                        }
                        if shared.working { ProgressView("Receiving backup…") }
                        if let error = shared.error { Text(error).font(.footnote).foregroundStyle(.secondary) }
                    } header: { Text("Shared backup") }
                    if let backup = input.backup {
                        Section {
                            Label(backup.displayName, systemImage: "doc.badge.checkmark").font(.subheadline)
                            SecureField("This backup’s recovery key", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                            Button("Preview Contents") { review.prepare(backup, key: key); key = "" }
                                .buttonStyle(.borderedProminent).disabled(key.isEmpty || review.working || vault.busy || input.working)
                            if review.working { ProgressView("Authenticating the complete backup…") }
                            if let error = review.error { Text(error).foregroundStyle(.secondary) }
                        } footer: { Text("Choose what to add before anything changes. Your current library stays in place.") }
                    }
                    Section {
                        DisclosureGroup("Choose a File or Folder Instead") {
                            Button("Choose Backup File") { usedReceipt = nil; input.choose(.file) }
                            Button("Choose Backup Folder") { usedReceipt = nil; input.choose(.folder) }
                            ForEach(input.entries, id: \.self) { url in
                                Button(url.lastPathComponent) { input.prepare(url) }
                            }
                            if input.working { ProgressView("Preparing backup…") }
                            if let error = input.error { Text(error).font(.footnote) }
                            if let notice = input.notice { Text(notice).font(.footnote) }
                        }.disabled(review.working || input.working || vault.busy)
                        NavigationLink("Just Test This Backup") { RecoveryTestView() }.disabled(review.working || vault.busy)
                    }
                }
            }
        }
        .navigationTitle(review.credential == nil ? "Add from Backup" : "Choose What to Add")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) {
            Button(vault.importing ? "Cancel Import" : "Close") {
                if vault.importing { vault.cancelImport() } else { dismiss() }
            }
        } }
        .interactiveDismissDisabled(vault.importing)
        .backupPicker(input)
        .task {
            if input.backup == nil, let entry = shared.entry {
                usedReceipt = entry.url; input.prepare(entry.url, displayName: entry.displayName)
            }
        }
        .onChange(of: review.items) { _, values in selected = Set(values.map(\.id)) }
        .onChange(of: vault.unlocked) { _, unlocked in if !unlocked { review.clear(); key = ""; dismiss() } }
        .onDisappear { key = ""; if vault.importing { vault.cancelImport() }; review.clear() }
        .confirmationDialog("Remove received copy?", isPresented: $removeReceived, titleVisibility: .visible) {
            Button("Remove Received Copy", role: .destructive) { shared.discard() }
        } message: { Text("The original in Files is unchanged. You can share another backup after removing this received copy.") }
        .alert("Couldn’t Add Backup", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("Close", role: .cancel) { importError = nil }
        } message: { Text(importError ?? "") }
    }
    private var preview: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(selected.count) selected").font(.subheadline)
                Spacer()
                Button(selected.count == review.items.count ? "Deselect All" : "Select All") {
                    selected = selected.count == review.items.count ? [] : Set(review.items.map(\.id))
                }.frame(minHeight: 44)
            }.padding(.horizontal)
            MemoryGrid(sections: LibraryPresentation.sections(review.items, source: .captured, newestFirst: true), engine: review.engine,
                columns: 3, style: .photoLibrary, grouping: "Months", selection: selected, selecting: true, busy: vault.busy,
                setSelection: { selected = $0 }, identity: "backup-review", open: { item in
                    if !selected.insert(item.id).inserted { selected.remove(item.id) }
                }, action: { _, _ in })
            VStack(spacing: 12) {
                if vault.importing { ProgressView(vault.status) }
                Button("Add \(selected.count) Items") {
                    guard let credential = review.credential else { return }
                    vault.addFromBackup(root: review.root, credential: credential, selected: selected) { value in
                        switch value {
                        case .success(let added):
                            result = added
                            if shared.entry?.url == usedReceipt { shared.discard() }
                            review.clear()
                        case .failure(let error): importError = error.localizedDescription
                        }
                    }
                }.buttonStyle(.borderedProminent).controlSize(.large).disabled(selected.isEmpty || vault.busy)
                Text("Exact duplicates are skipped. Added items use your current library’s encryption. Cloud exclusions are kept.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding()
        }
    }
}
#endif
