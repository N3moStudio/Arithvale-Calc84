#if os(iOS)
import SwiftUI
import Security
import Combine
import CalcCore
import UniformTypeIdentifiers

private enum InboxAccessError: Error { case missingKey }

private actor SharedFilesStorage {
    private let inbox = SharedFileInbox(root: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ArithenIncomingFiles"))
    private func key() throws -> Data {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: (Bundle.main.bundleIdentifier ?? "studio.n3mo.calc84") + ".incoming-files.v1",
            kSecAttrAccount as String: "inbox", kSecAttrSynchronizable as String: false]
        var read = query; read[kSecReturnData as String] = true; read[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(read as CFDictionary, &value)
        if status == errSecSuccess, let data = value as? Data { return data }
        guard status == errSecItemNotFound else { throw CocoaError(.fileReadNoPermission) }
        // A missing device key must not silently replace the key for pending files.
        if !(try inbox.receivedIDs()).isEmpty { throw InboxAccessError.missingKey }
        let data = SharedFileInbox.newKey()
        var create = query; create[kSecValueData as String] = data
        create[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(create as CFDictionary, nil) == errSecSuccess else { throw CocoaError(.fileWriteNoPermission) }
        return data
    }
    struct Scan: Sendable {
        let entries: [SharedFileInbox.Entry]
        let unreadableIDs: [UUID]
        let missingKey: Bool
    }
    func scan() throws -> Scan {
        do {
            let result = try inbox.scan(key: key())
            return Scan(entries: result.entries, unreadableIDs: result.unreadableIDs, missingKey: false)
        } catch InboxAccessError.missingKey {
            return Scan(entries: [], unreadableIDs: try inbox.receivedIDs(), missingKey: true)
        }
    }
    func receive(_ access: BackupSelection) throws {
        defer { withExtendedLifetime(access) {} }
        let data = try key()
        var failure: NSError?, result: Result<Void, Error>?
        NSFileCoordinator().coordinate(readingItemAt: access.url, options: [], error: &failure) { source in
            result = Result {
                for url in try ImportFileList.expand([source]) {
                    let bytes = Int64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
                    guard bytes >= 0, bytes <= VaultLimits.fileBytes else { throw VaultError.limit }
                    try StoragePreflight.require(bytes: bytes * 2)
                    _ = try inbox.receive(url, key: data)
                }
            }
        }
        if let failure { throw failure }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        try result.get()
    }
    struct Prepared: Sendable { let mapping: [URL: UUID]; let unreadableIDs: [UUID] }
    func prepare(_ entries: [SharedFileInbox.Entry], at root: URL) throws -> Prepared {
        let data = try key(); var result: [URL: UUID] = [:]
        try StoragePreflight.require(bytes: entries.reduce(Int64(0)) { $0 + Int64($1.bytes) } * 3)
        var unreadable: [UUID] = []
        for entry in entries {
            try Task.checkCancellation()
            let directory = root.appendingPathComponent(entry.id.uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete])
            let url = directory.appendingPathComponent(entry.name)
            do {
                try inbox.materialize(entry, key: data, to: url)
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
                result[url] = entry.id
            } catch {
                try Task.checkCancellation()
                // Authentication damage is isolated; permissions/space/I/O failures
                // remain retryable and must never be labelled safe to discard.
                if case VaultError.invalidBackup = error {
                    unreadable.append(entry.id); try? FileManager.default.removeItem(at: directory)
                } else if case VaultError.wrongPasswordOrDamaged = error {
                    unreadable.append(entry.id); try? FileManager.default.removeItem(at: directory)
                } else { throw error }
            }
        }
        return Prepared(mapping: result, unreadableIDs: unreadable)
    }
    func discard(_ ids: [UUID]) throws { for id in ids { try inbox.discard(id) } }
}

@MainActor
final class SharedFilesModel: ObservableObject {
    @Published private(set) var entries: [SharedFileInbox.Entry] = []
    @Published private(set) var unreadableIDs: [UUID] = []
    @Published private(set) var missingKey = false
    @Published private var receiving = 0
    @Published private var importing = false
    var working: Bool { receiving > 0 || importing }
    @Published private(set) var error: String?
    @Published private(set) var importedCount: Int?
    var hasPending: Bool { !entries.isEmpty || !unreadableIDs.isEmpty || working || error != nil }
    private let storage = SharedFilesStorage()
    private var payloadUnreadableIDs = Set<UUID>()
    private var receipt: Task<Void, Never>?
    private var preparation: Task<Void, Never>?
    private var privacy: AnyCancellable?
    init() { receipt = Task { await reload() } }
    private func reload() async {
        do {
            let result = try await storage.scan()
            payloadUnreadableIDs.formIntersection(Set(result.entries.map(\.id)).union(result.unreadableIDs))
            unreadableIDs = Array(Set(result.unreadableIDs).union(payloadUnreadableIDs))
            entries = result.entries.filter { !unreadableIDs.contains($0.id) }
            missingKey = result.missingKey
        } catch { entries = []; self.error = error.localizedDescription }
    }
    func receive(_ url: URL) {
        guard url.isFileURL else { error = "Share the downloaded file itself, not a link."; return }
        receive(BackupSelection(url))
    }
    func receive(_ access: BackupSelection) {
        let previous = receipt
        importedCount = nil
        receiving += 1
        receipt = Task {
            await previous?.value
            error = nil
            defer { receiving -= 1 }
            do { try await storage.receive(access) } catch { self.error = error.localizedDescription }
            await reload()
        }
    }
    func importPending(vault: VaultModel) {
        guard vault.unlocked, !vault.busy, !working, !entries.isEmpty else { return }
        let operationToken = vault.beginOperation()
        importing = true; error = nil; importedCount = nil
        // Reserve the operation before decrypting the inbox, so indexing and
        // other imports cannot overlap this preparation window.
        vault.textSearch.pause()
        let batch = entries, generation = vault.generation
        let root = TemporaryFiles.directory.appendingPathComponent("shared-" + UUID().uuidString)
        privacy = vault.$unlocked.dropFirst().filter { !$0 }.sink { [weak self] _ in self?.preparation?.cancel() }
        preparation = Task {
            defer { preparation = nil }
            do {
                let prepared = try await storage.prepare(batch, at: root)
                let mapping = prepared.mapping
                payloadUnreadableIDs.formUnion(prepared.unreadableIDs)
                unreadableIDs = Array(Set(unreadableIDs).union(prepared.unreadableIDs))
                guard !Task.isCancelled, vault.unlocked, generation == vault.generation else {
                    try? FileManager.default.removeItem(at: root); importing = false; vault.endOperation(operationToken); privacy = nil; return
                }
                vault.endOperation(operationToken)
                guard !mapping.isEmpty else {
                    try? FileManager.default.removeItem(at: root)
                    importing = false; privacy = nil
                    await reload()
                    error = "No readable files were found. Share the originals again or remove the unreadable received copies."
                    return
                }
                vault.importFiles(Array(mapping.keys), receivedCopies: true) { [self] imported in
                    Task { @MainActor in
                        defer { try? FileManager.default.removeItem(at: root); self.importing = false; self.privacy = nil }
                        do { try await self.storage.discard(imported.compactMap { mapping[$0] }) }
                        catch { self.error = error.localizedDescription }
                        await self.reload()
                        self.importedCount = imported.count
                        if imported.count < batch.count { self.error = "Some files weren’t imported. Their received copies are ready to retry." }
                    }
                }
            } catch {
                try? FileManager.default.removeItem(at: root); importing = false; vault.endOperation(operationToken); privacy = nil; if !Task.isCancelled { self.error = error.localizedDescription }
            }
        }
    }
    func discard(unreadableOnly: Bool = false) {
        guard !working else { return }
        importing = true; let ids = unreadableOnly ? unreadableIDs : entries.map(\.id) + unreadableIDs
        Task {
            defer { importing = false }
            do { try await storage.discard(ids); unreadableIDs.removeAll { ids.contains($0) }; payloadUnreadableIDs.subtract(ids); error = nil; await reload() } catch { self.error = error.localizedDescription }
        }
    }
}

struct SharedFilesImportView: View {
    @EnvironmentObject private var shared: SharedFilesModel
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    @State private var removing = false
    @State private var removingUnreadable = false
    @State private var choosing = false
    @State private var backup: BackupSelection?
    @State private var showingBackup = false
    @State private var pickerError: String?
    @State private var inspection: Task<Void, Never>?
    var body: some View {
        ThemedForm {
            Section("Files") {
                Button("Import", systemImage: "doc.on.doc") { pickerError = nil; choosing = true }
                    .disabled(inspection != nil || shared.working || vault.busy)
                DisclosureGroup("Or share from Files") {
                    SharedImportInstructions().foregroundStyle(ArithenPalette.color(.muted))
                }
            }
            Section {
                if !shared.entries.isEmpty { Label("\(shared.entries.count.formatted()) \(shared.entries.count == 1 ? "file received" : "files received")", systemImage: "doc.on.doc") }
                if let count = shared.importedCount, count > 0 { Label("\(count.formatted()) \(count == 1 ? "file imported" : "files imported")", systemImage: "checkmark.circle") }
                ForEach(shared.entries, id: \.id) { entry in Text(entry.name) }
                Button("Add to Library") { shared.importPending(vault: vault) }
                    .accessibilityIdentifier("files.apply").buttonStyle(ImportButtonStyle()).disabled(shared.entries.isEmpty || inspection != nil || shared.working || vault.busy)
            }
            if inspection != nil { Section { ProgressView("Reading selected files…") } }
            if shared.working {
                Section {
                    OperationProgressView(title: vault.importing ? "Importing Files" : "Preparing Files",
                        detail: vault.importing ? vault.status : "Your received copies stay available until import completes.",
                        progress: vault.importing && vault.progress > 0 ? vault.progress : nil)
                    if vault.importing { Button("Cancel Import") { vault.cancelImport() }.frame(minHeight: 44) }
                }
            }
            if let error = pickerError ?? shared.error {
                Section { Label(error, systemImage: "exclamationmark.circle").font(.subheadline).fixedSize(horizontal: false, vertical: true) }
            }
            if !shared.unreadableIDs.isEmpty {
                Section("Unreadable Received Copies") {
                    Text(shared.missingKey ? "This device no longer has the key for these received copies. Share the originals again after removing them." : "Some received copies could not be opened. Your readable files can still be imported.")
                    Button("Remove Unreadable Copies", role: .destructive) { removingUnreadable = true }
                        .disabled(shared.working || vault.busy)
                }
            }
            if !shared.entries.isEmpty {
                Section { Button("Remove Received Copies", role: .destructive) { removing = true }.disabled(shared.working || vault.busy) }
            }
        }.navigationTitle("Import from Files").navigationBarTitleDisplayMode(.inline)
            .fileImporter(isPresented: $choosing, allowedContentTypes: BackupImportTypes.files,
                          allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): inspect(urls)
                case .failure(let error): pickerError = error.localizedDescription
                }
            } onCancellation: { pickerError = nil }
            .fileDialogBrowserOptions(.displayFileExtensions)
            .navigationDestination(isPresented: $showingBackup) {
                BackupImportView(preparedSelection: backup)
            }
            .onDisappear { inspection?.cancel() }
            .onChange(of: showingBackup) { _, shown in if !shown { backup = nil } }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .confirmationDialog("Remove unreadable received copies?", isPresented: $removingUnreadable, titleVisibility: .visible) {
                Button("Remove Unreadable Copies", role: .destructive) { shared.discard(unreadableOnly: true) }
            } message: { Text("Only the received copies in Arithen will be removed. Your library and originals in Files stay unchanged.") }
            .confirmationDialog("Remove received copies?", isPresented: $removing, titleVisibility: .visible) {
                Button("Remove Copies", role: .destructive) { shared.discard() }
            } message: { Text("The originals in Files stay where they are.") }
    }
    private func inspect(_ urls: [URL]) {
        guard !urls.isEmpty, inspection == nil, vault.unlocked else { return }
        let selections = urls.map { BackupSelection($0) }
        let generation = vault.generation
        inspection = Task {
            defer { inspection = nil }
            do {
                let classifier = Task.detached(priority: .userInitiated) {
                    try selections.filter { selection in
                        try Task.checkCancellation()
                        if BackupFileProbe.extensions.contains(selection.url.pathExtension.lowercased()) { return true }
                        var failure: NSError?
                        var isBackup = false
                        NSFileCoordinator().coordinate(readingItemAt: selection.url, options: [], error: &failure) { url in
                            isBackup = (try? BackupFileProbe.validate(url)) != nil
                        }
                        if let failure { throw failure }
                        return isBackup
                    }
                }
                let archives = try await withTaskCancellationHandler { try await classifier.value } onCancel: { classifier.cancel() }
                try Task.checkCancellation()
                guard vault.unlocked, vault.generation == generation else { return }
                if let archive = archives.first {
                    guard selections.count == 1 else {
                        pickerError = "Choose one encrypted backup at a time, separately from other files."
                        return
                    }
                    let staging = Task.detached(priority: .userInitiated) {
                        try BackupSelection.backupFile(archive)
                    }
                    let staged = try await withTaskCancellationHandler { try await staging.value } onCancel: { staging.cancel() }
                    try Task.checkCancellation()
                    guard vault.unlocked, vault.generation == generation else { return }
                    backup = staged; showingBackup = true
                } else {
                    for selection in selections { shared.receive(selection) }
                }
            } catch { if !Task.isCancelled { pickerError = error.localizedDescription } }
        }
    }
}

struct ImportButtonStyle: ButtonStyle {
    @Environment(\.arithenTheme) private var theme
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(enabled ? ArithenPalette.color(.onAccent, theme: theme) : ArithenPalette.color(.muted, theme: theme))
            .background(enabled ? ArithenPalette.color(.accent, theme: theme) : ArithenPalette.color(.muted, theme: theme).opacity(0.12), in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
#endif
