#if os(iOS)
import SwiftUI
import Security
import Combine
import CalcCore

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
        if FileManager.default.fileExists(atPath: inbox.root.path),
           !(try FileManager.default.contentsOfDirectory(atPath: inbox.root.path)).isEmpty { throw CocoaError(.fileReadNoPermission) }
        let data = SharedFileInbox.newKey()
        var create = query; create[kSecValueData as String] = data
        create[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(create as CFDictionary, nil) == errSecSuccess else { throw CocoaError(.fileWriteNoPermission) }
        return data
    }
    func entries() throws -> [SharedFileInbox.Entry] { try inbox.entries(key: key()) }
    func receive(_ access: BackupSelection) throws {
        defer { withExtendedLifetime(access) {} }
        let data = try key()
        var failure: NSError?, result: Result<Void, Error>?
        NSFileCoordinator().coordinate(readingItemAt: access.url, options: [], error: &failure) { source in
            result = Result {
                for url in try ImportFileList.expand([source]) {
                    let bytes = Int64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
                    try StoragePreflight.require(bytes: bytes * 2)
                    _ = try inbox.receive(url, key: data)
                }
            }
        }
        if let failure { throw failure }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        try result.get()
    }
    func prepare(_ entries: [SharedFileInbox.Entry], at root: URL) throws -> [URL: UUID] {
        let data = try key(); var result: [URL: UUID] = [:]
        try StoragePreflight.require(bytes: entries.reduce(Int64(0)) { $0 + Int64($1.bytes) } * 3)
        for entry in entries {
            let directory = root.appendingPathComponent(entry.id.uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete])
            let url = directory.appendingPathComponent(entry.name)
            try inbox.materialize(entry, key: data, to: url)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
            result[url] = entry.id
        }
        return result
    }
    func discard(_ ids: [UUID]) throws { for id in ids { try inbox.discard(id) } }
}

@MainActor
final class SharedFilesModel: ObservableObject {
    @Published private(set) var entries: [SharedFileInbox.Entry] = []
    @Published private var receiving = 0
    @Published private var importing = false
    var working: Bool { receiving > 0 || importing }
    @Published private(set) var error: String?
    @Published private(set) var importedCount: Int?
    var hasPending: Bool { !entries.isEmpty || working || error != nil }
    private let storage = SharedFilesStorage()
    private var receipt: Task<Void, Never>?
    private var preparation: Task<Void, Never>?
    private var privacy: AnyCancellable?
    init() { receipt = Task { await reload() } }
    private func reload() async {
        do { entries = try await storage.entries() } catch { self.error = error.localizedDescription }
    }
    func receive(_ url: URL) {
        guard url.isFileURL else { error = "Share the downloaded file itself, not a link."; return }
        let access = BackupSelection(url), previous = receipt
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
        importing = true; error = nil; importedCount = nil
        // Reserve the operation before decrypting the inbox, so indexing and
        // other imports cannot overlap this preparation window.
        vault.textSearch.pause(); vault.busy = true
        let batch = entries, generation = vault.generation
        let root = TemporaryFiles.directory.appendingPathComponent("shared-" + UUID().uuidString)
        privacy = vault.$unlocked.dropFirst().filter { !$0 }.sink { [weak self] _ in self?.preparation?.cancel() }
        preparation = Task {
            defer { preparation = nil }
            do {
                let mapping = try await storage.prepare(batch, at: root)
                guard !Task.isCancelled, vault.unlocked, generation == vault.generation else {
                    try? FileManager.default.removeItem(at: root); importing = false; vault.busy = false; privacy = nil; return
                }
                vault.busy = false
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
                try? FileManager.default.removeItem(at: root); importing = false; vault.busy = false; privacy = nil; if !Task.isCancelled { self.error = error.localizedDescription }
            }
        }
    }
    func discard() {
        guard !working else { return }
        importing = true; let ids = entries.map(\.id)
        Task {
            defer { importing = false }
            do { try await storage.discard(ids); error = nil; await reload() } catch { self.error = error.localizedDescription }
        }
    }
}

struct SharedFilesImportView: View {
    @EnvironmentObject private var shared: SharedFilesModel
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    @State private var removing = false
    var body: some View {
        ThemedForm {
            Section {
                SharedImportInstructions().foregroundStyle(ArithenPalette.color(.muted))
                if !shared.entries.isEmpty { Label("\(shared.entries.count.formatted()) \(shared.entries.count == 1 ? "file received" : "files received")", systemImage: "doc.on.doc") }
                if let count = shared.importedCount, count > 0 { Label("\(count.formatted()) \(count == 1 ? "file imported" : "files imported")", systemImage: "checkmark.circle") }
                if shared.working { ProgressView(vault.importing ? "Importing…" : "Receiving…") }
                Button("Import") { shared.importPending(vault: vault) }
                    .buttonStyle(ImportButtonStyle()).disabled(shared.entries.isEmpty || shared.working || vault.busy)
                if let error = shared.error { Text(error).font(.footnote).foregroundStyle(ArithenPalette.color(.muted)) }
            }
            if !shared.entries.isEmpty {
                Section { Button("Remove Received Copies", role: .destructive) { removing = true }.disabled(shared.working || vault.busy) }
            }
        }.navigationTitle("Import from Files").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .confirmationDialog("Remove received copies?", isPresented: $removing, titleVisibility: .visible) {
                Button("Remove Copies", role: .destructive) { shared.discard() }
            } message: { Text("The originals in Files stay where they are.") }
    }
}

struct ImportButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(enabled ? ArithenPalette.color(.onAccent) : ArithenPalette.color(.muted))
            .background(enabled ? ArithenPalette.color(.accent) : ArithenPalette.color(.muted).opacity(0.12), in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
#endif
