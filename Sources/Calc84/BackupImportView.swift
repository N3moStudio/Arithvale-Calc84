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
    @Published private(set) var canRecover = false
    @Published private(set) var recoveryReport: BackupRecoveryReport?
    @Published private(set) var recoveredMetadata = false
    @Published private(set) var partialRecovery = false
    private var stagedCredential: VaultCredential?
    private var generation = UUID()
    private var operation: Task<Void, Never>?
    var readyToImport: Bool { !working && credential != nil }
    init() {
        root = TemporaryFiles.directory.appendingPathComponent("review-" + UUID().uuidString, isDirectory: true)
        engine = VaultEngine(root: root)
    }
    func prepare(_ backup: BackupSelection, key: String, recoverIntact: Bool = false) {
        guard !working, credential == nil, recoveryReport == nil else { return }
        let ticket = UUID(); generation = ticket
        working = true; error = nil; canRecover = false; recoveredMetadata = false
        partialRecovery = recoverIntact; phase = "Preparing backup…"
        operation = Task {
            defer { if ticket == generation { working = false; operation = nil }; withExtendedLifetime(backup) {} }
            do {
                let bytes = Int64(try backup.url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
                try StoragePreflight.require(bytes: bytes * 3)
                phase = recoverIntact ? "Authenticating recoverable files…" : "Checking the recovery key and authenticating every file…"
                let restored: [VaultItem]
                let report: BackupRecoveryReport?
                if recoverIntact {
                    let recovered = try await engine.restoreRecoverable(from: backup.url, password: key)
                    restored = recovered.items; report = recovered
                    recoveredMetadata = recovered.metadataRecovered
                } else {
                    restored = try await engine.restore(from: backup.url, password: key)
                    report = nil
                    recoveredMetadata = await engine.restorationRecoveredMetadata()
                }
                try Task.checkCancellation()
                let access = try await engine.credential()
                try Task.checkCancellation()
                guard ticket == generation else { return }
                items = restored.filter { $0.visible && $0.deletedAt == nil }
                if let report {
                    // A forensic scan never starts import by itself. Hold its
                    // credential privately until the user accepts these counts.
                    stagedCredential = access; recoveryReport = report
                } else { credential = access }
            } catch {
                await engine.lock()
                try? FileManager.default.removeItem(at: root)
                guard ticket == generation, !Task.isCancelled else { return }
                self.error = error.localizedDescription
                canRecover = (try? ArithenBackupArchive.hasSignature(backup.url)) == true
            }
        }
    }
    func confirmRecovery() {
        guard !working, recoveryReport != nil, !items.isEmpty, let stagedCredential else { return }
        self.stagedCredential = nil; recoveryReport = nil
        credential = stagedCredential
    }
    func clear() {
        generation = UUID(); let ticket = generation
        operation?.cancel(); items = []; credential = nil; stagedCredential = nil
        recoveryReport = nil; canRecover = false; error = nil; working = true
        let pending = operation, engine = engine, root = root
        operation = Task {
            await pending?.value
            await engine.lock()
            try? FileManager.default.removeItem(at: root)
            if ticket == generation { working = false; operation = nil }
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
    @State private var result: BackupImportResult?
    @State private var usedReceipt: URL?
    @State private var removeReceived = false
    @State private var importError: String?
    @State private var resultNotice: String?
    var body: some View {
        Group {
            if let result {
                ContentUnavailableView {
                    Label("Added to Your Library", systemImage: "checkmark.circle")
                } description: {
                    Text("\(result.added) items added · \(result.skipped) exact duplicates skipped\nYour current recovery key stays the same.")
                    if let resultNotice { Text(resultNotice) }
                } actions: { Button("View Library") { dismiss() }.buttonStyle(.borderedProminent) }
            } else {
                ThemedForm {
                    Section("Backup File") {
                        Button("Choose Backup File", systemImage: "doc") {
                            usedReceipt = nil; key = ""; input.choose(.file)
                        }.disabled(input.working || review.working || review.recoveryReport != nil || vault.busy)
                        if let backup = input.backup {
                            Label(backup.displayName, systemImage: "doc.badge.checkmark").font(.subheadline)
                        }
                        DisclosureGroup("Or share from Files") {
                            SharedImportInstructions().foregroundStyle(ArithenPalette.color(.muted))
                            if let entry = shared.entry {
                                Button("Use Received Backup") { receiveBackup() }
                                    .disabled(input.working || review.working || review.recoveryReport != nil || vault.busy)
                                Text(entry.displayName).font(.caption)
                            }
                        }
                    }
                    Section {
                        SecureField("Backup recovery key", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .disabled(input.working || review.working || review.recoveryReport != nil || vault.busy)
                        Button("Import") {
                            if let backup = input.backup { review.prepare(backup, key: key); key = "" }
                        }.buttonStyle(ImportButtonStyle())
                            .disabled(input.backup == nil || key.isEmpty || shared.working || input.working || review.working || review.recoveryReport != nil || vault.busy)
                        if review.canRecover {
                            Button("Recover Intact Files") {
                                if let backup = input.backup { review.prepare(backup, key: key, recoverIntact: true); key = "" }
                            }.disabled(input.backup == nil || key.isEmpty || input.working || review.working || vault.busy)
                            Text("Re-enter this backup’s key to check for intact files. You’ll review what can be recovered before anything is added.")
                                .font(.footnote).fixedSize(horizontal: false, vertical: true)
                        }
                    } header: { Text("Recovery Key") } footer: {
                        Text("Use this backup’s key. Your current library keeps its own key.")
                    }
                    if let report = review.recoveryReport, !review.working {
                        Section("Recovery Results") {
                            Text("\(review.items.count.formatted()) intact active items can be added.")
                            Text("\(report.skippedItemCount.formatted()) items unavailable · \(report.damagedResourceCount.formatted()) resources failed verification")
                                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                            Text("This recovers verified intact files, not necessarily the complete library. The source backup stays unchanged.")
                                .font(.footnote).fixedSize(horizontal: false, vertical: true)
                            Button("Import Intact Items") { review.confirmRecovery() }
                                .disabled(review.items.isEmpty || vault.busy)
                            Button("Cancel Recovery", role: .cancel) { review.clear() }
                        }
                    }
                    if shared.working || input.working || review.working || vault.importing {
                        Section {
                            OperationProgressView(title: vault.importing ? "Importing Backup" : review.working ? "Checking Backup" : "Receiving Backup",
                                detail: vault.importing ? vault.status : review.working ? review.phase : "Preparing the selected copy…",
                                progress: vault.importing && vault.progress > 0 ? vault.progress : nil)
                        }
                    }
                    if let error = shared.error ?? input.error ?? review.error {
                        Section { Label(error, systemImage: "exclamationmark.circle").font(.subheadline).fixedSize(horizontal: false, vertical: true) }
                    }
                    if let notice = input.notice {
                        Section { Text(notice).font(.subheadline).fixedSize(horizontal: false, vertical: true) }
                    }
                    if shared.entry != nil {
                        Section { Button("Remove Received Copy", role: .destructive) { removeReceived = true }
                            .disabled(input.working || review.working || review.recoveryReport != nil || vault.busy) }
                    }
                }
            }
        }
        .navigationTitle("Add from Backup")
        .backupPicker(input)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) {
            Button(vault.importing ? "Cancel Import" : review.working ? "Cancel Check" : "Close") {
                if vault.importing { vault.cancelImport() } else { dismiss() }
            }
        } }
        .interactiveDismissDisabled(vault.importing)
        .task {
            if input.backup == nil, let entry = shared.entry {
                usedReceipt = entry.url; input.prepare(entry.url, displayName: entry.displayName)
            }
        }
        .onChange(of: input.backup?.url) { _, _ in key = ""; review.clear() }
        .onChange(of: shared.entry?.url) { _, _ in receiveBackup() }
        .onChange(of: review.readyToImport) { _, ready in if ready { importPreparedBackup() } }
        .onChange(of: vault.unlocked) { _, unlocked in if !unlocked { review.clear(); key = ""; dismiss() } }
        .onDisappear { key = ""; if vault.importing { vault.cancelImport() }; review.clear() }
        .confirmationDialog("Remove received copy?", isPresented: $removeReceived, titleVisibility: .visible) {
            Button("Remove Received Copy", role: .destructive) { input.clearSelection(); usedReceipt = nil; shared.discard() }
        } message: { Text("The original in Files is unchanged. You can share another backup after removing this received copy.") }
        .alert("Couldn’t Add Backup", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("Close", role: .cancel) { importError = nil }
        } message: { Text(importError ?? "") }
    }
    private func importPreparedBackup() {
        guard !vault.busy, review.readyToImport, let credential = review.credential else { return }
        let ids = Set(review.items.map(\.id))
        guard !ids.isEmpty else { importError = "This backup has no active items to import."; review.clear(); return }
        let partial = review.partialRecovery, spareMetadata = review.recoveredMetadata
        vault.addFromBackup(root: review.root, credential: credential, selected: ids) { value in
            switch value {
            case .success(let added):
                result = added
                if partial {
                    resultNotice = "Only the intact files you approved were recovered. Keep the original backup for any further recovery and create a fresh backup of this library."
                } else if spareMetadata {
                    resultNotice = "The backup’s spare catalog was used successfully. Create a fresh backup of this library."
                }
                // Keep a damaged received backup available for another recovery
                // attempt. A partial recovery must not silently discard it.
                if !partial, shared.entry?.url == usedReceipt { shared.discard() }
                review.clear()
            case .failure(let error): importError = error.localizedDescription; review.clear()
            }
        }
    }
    private func receiveBackup() {
        guard input.request == nil, !input.working, !review.working, review.recoveryReport == nil, !vault.busy, let entry = shared.entry else { return }
        usedReceipt = entry.url; input.prepare(entry.url, displayName: entry.displayName)
    }
}
#endif
