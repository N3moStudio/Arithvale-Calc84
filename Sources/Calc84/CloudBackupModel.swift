#if os(iOS)
import SwiftUI
import CalcCore

struct CloudReceipt: Codable {
    var objects: Set<String> = []
    var itemIDs: Set<UUID> = []
    var saved: Date?
    var vaultID: UUID?
    var needsBackup = true
}

struct SavedCloudSnapshot: Identifiable {
    let snapshot: CloudSnapshot
    var id: UUID { snapshot.id }
}

@MainActor
final class CloudBackupModel: ObservableObject {
    @Published var connected: Set<CloudProvider> = []
    @Published var receipts: [CloudProvider: CloudReceipt] = [:]
    @Published var phase = "Connect a service to get started."
    @Published var progress: Double?
    @Published var running = false
    @Published var activeProvider: CloudProvider?
    @Published var error: String?
    @Published var snapshots: [SavedCloudSnapshot] = []
    private var operation: Task<Void, Never>?
    private var stores: [CloudProvider: any CloudStore] = [:]
    private var operationID = UUID()
    var wifiOnly: Bool { !UserDefaults.standard.bool(forKey: "cloudUseCellular") }

    func refresh() {
        for provider in CloudProvider.allCases {
            do {
                if try CloudCredentials.load(provider) != nil { connected.insert(provider) } else { connected.remove(provider) }
                if let data = UserDefaults.standard.data(forKey: "cloudReceipt." + provider.rawValue),
                   let receipt = try? JSONDecoder().decode(CloudReceipt.self, from: data) { receipts[provider] = receipt }
            } catch { self.error = "Unlock your phone to access saved cloud connections." }
        }
        if !running, error == nil {
            if connected.isEmpty { phase = "Connect a service to get started." }
            else if connected.contains(where: { receipts[$0]?.needsBackup != false }) { phase = "Changes waiting for backup" }
            else { phase = "Latest backups completed" }
        }
    }
    private func persist(_ provider: CloudProvider) {
        if let receipt = receipts[provider], let data = try? JSONEncoder().encode(receipt) {
            UserDefaults.standard.set(data, forKey: "cloudReceipt." + provider.rawValue)
        }
    }
    func changed() {
        for provider in CloudProvider.allCases {
            var receipt = receipts[provider] ?? .init(); receipt.needsBackup = true
            receipts[provider] = receipt; persist(provider)
        }
    }
    func pause() { operation?.cancel(); phase = "Pausing…" }
    func lock() {
        operation?.cancel(); stores.removeAll(); snapshots = []; error = nil
        // Receipts contain only opaque IDs. They are loaded again after unlock.
    }
    func connectionChanged() { stores.removeAll() }
    func disconnect(_ provider: CloudProvider) {
        guard !running else { return }
        do {
            try CloudCredentials.remove(provider)
            stores[provider] = nil; receipts[provider] = nil; connected.remove(provider)
            UserDefaults.standard.removeObject(forKey: "cloudReceipt." + provider.rawValue)
            phase = "Disconnected. Existing cloud backups are still there."
        } catch { self.error = error.localizedDescription }
    }
    func connect(_ provider: CloudProvider, email: String, password: String, appKey: String, code: String, vault: VaultModel) {
        start(vault) {
            self.phase = "Connecting to \(provider.title)…"
            let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let store: any CloudStore
            let login: CloudLogin
            switch provider {
            case .blomp:
                let client = BlompStore(email: email, password: password, cellular: !self.wifiOnly)
                try await client.connect(); store = client
                login = CloudLogin(email: email, secret: password)
            case .mega:
                let client = try MegaStore(appKey: appKey, cellular: !self.wifiOnly)
                let session = try await client.signIn(email: email, password: password, code: code)
                store = client; login = CloudLogin(email: email, secret: session, appKey: appKey)
            }
            try Task.checkCancellation()
            try CloudCredentials.save(login, for: provider)
            // Reconnecting may select another account. Never reuse the old receipts.
            self.receipts[provider] = .init(); self.persist(provider)
            self.stores[provider] = store; self.connected.insert(provider)
            self.phase = "\(provider.title) connected. Choose Back Up Now to save your library."
        }
    }
    private func store(_ provider: CloudProvider) async throws -> any CloudStore {
        if let store = stores[provider] { return store }
        guard let login = try CloudCredentials.load(provider) else { throw CloudError.configuration }
        let store: any CloudStore
        switch provider {
        case .blomp:
            let client = BlompStore(email: login.email, password: login.secret, cellular: !wifiOnly)
            try await client.connect(); store = client
        case .mega:
            let client = try MegaStore(appKey: login.appKey ?? "", cellular: !wifiOnly)
            try await client.resume(session: login.secret); store = client
        }
        stores[provider] = store; return store
    }
    private func start(_ vault: VaultModel, body: @escaping @MainActor () async throws -> Void) {
        guard !running, !vault.busy else { return }
        running = true; vault.busy = true; error = nil; progress = nil
        operationID = UUID(); let ticket = operationID
        operation = Task {
            defer {
                if ticket == operationID { running = false; activeProvider = nil; progress = nil; operation = nil }
                vault.busy = false
            }
            do { try await body() }
            catch {
                if Task.isCancelled {
                    stores.removeAll()
                    phase = "Paused. Completed uploads will be reused."
                }
                else {
                    self.error = Self.message(error); phase = "Backup needs attention"
                    // Expired sessions and policy changes must be checked next time.
                    stores.removeAll()
                }
            }
        }
    }
    private static func message(_ error: Error) -> String {
        if let error = error as? URLError {
            switch error.code {
            case .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid, .secureConnectionFailed:
                return "The service’s secure connection could not be verified. Nothing was sent over an insecure connection. Try again later or use another service."
            case .notConnectedToInternet, .dataNotAllowed, .networkConnectionLost:
                return "Waiting for an allowed connection. Connect to Wi-Fi, then tap Back Up Now or try the download again."
            default: return "The connection was interrupted. Try again; previous backups remain available."
            }
        }
        return error.localizedDescription
    }
    func backup(vault: VaultModel, only: CloudProvider? = nil, verifyAll: Bool = false) {
        guard vault.unlocked else { return }
        let providers = CloudProvider.allCases.filter { connected.contains($0) && (only == nil || only == $0) }
        guard !providers.isEmpty else { error = "Connect a service first."; return }
        start(vault) {
            self.phase = "Checking your encrypted library…"
            let plan = try await vault.engine.cloudPlan()
            let scratch = try Self.scratch()
            defer { try? FileManager.default.removeItem(at: scratch) }
            var failures: [String] = []
            for provider in providers {
                try Task.checkCancellation(); self.activeProvider = provider
                do {
                    let store = try await self.store(provider)
                    let previous = self.receipts[provider] ?? .init()
                    try await CloudTransfer.upload(plan, store: store, scratch: scratch,
                        previouslyVerified: verifyAll ? [] : previous.objects,
                        verified: { name in await self.recordObject(name, provider: provider) },
                        progress: { value in await self.showProgress(value, provider: provider) })
                    try Task.checkCancellation()
                    var receipt = self.receipts[provider] ?? .init()
                    receipt.itemIDs = Set(vault.items.filter(\.visible).map(\.id))
                    receipt.vaultID = plan.snapshot.vaultID; receipt.saved = Date(); receipt.needsBackup = false
                    self.receipts[provider] = receipt; self.persist(provider)
                } catch {
                    if Task.isCancelled { throw CancellationError() }
                    failures.append(provider.title + ": " + Self.message(error)); self.stores[provider] = nil
                }
            }
            self.error = failures.isEmpty ? nil : failures.joined(separator: "\n\n")
            self.phase = failures.isEmpty ? "Backup complete" : "Some backups need attention"
        }
    }
    private func recordObject(_ name: String, provider: CloudProvider) {
        var receipt = receipts[provider] ?? .init(); receipt.objects.insert(name)
        receipts[provider] = receipt; persist(provider)
    }
    private func showProgress(_ value: CloudTransferProgress, provider: CloudProvider) {
        phase = provider.title + " · " + value.phase + " (\(value.completed)/\(value.total))"
        progress = Double(value.completed) / Double(max(value.total, 1))
    }
    func findBackups(_ provider: CloudProvider, vault: VaultModel) {
        snapshots = []
        start(vault) {
            self.phase = "Finding saved backups…"
            let store = try await self.store(provider)
            let paths = try await store.list(prefix: "c84/v1/")
            guard paths.count <= 2000 else { throw VaultError.limit }
            let scratch = try Self.scratch(); defer { try? FileManager.default.removeItem(at: scratch) }
            var found: [SavedCloudSnapshot] = []
            for path in paths {
                try Task.checkCancellation()
                let file = scratch.appendingPathComponent(UUID().uuidString)
                defer { try? FileManager.default.removeItem(at: file) }
                try await store.download(path: path, to: file, maximum: 8 * 1024 * 1024)
                let snapshot = try CloudSnapshot.decode(Data(contentsOf: file))
                guard snapshot.path == path else { throw VaultError.invalidBackup }
                found.append(.init(snapshot: snapshot))
            }
            self.snapshots = found.sorted { $0.snapshot.created > $1.snapshot.created }
            self.phase = found.isEmpty ? "No completed backups found in this account." : "Choose a saved backup."
        }
    }
    func restore(_ snapshot: CloudSnapshot, provider: CloudProvider, recovery: String, code: String, vault: VaultModel, testOnly: Bool) {
        guard testOnly ? vault.unlocked : !vault.exists else { return }
        start(vault) {
            self.phase = "Checking recovery key…"
            _ = try await Task.detached { try VaultRepository.validateCloudRecovery(snapshot, password: recovery) }.value
            try Task.checkCancellation()
            let store = try await self.store(provider)
            let scratch = try Self.scratch(); defer { try? FileManager.default.removeItem(at: scratch) }
            let archive = scratch.appendingPathComponent("recovery.c84backup")
            try await CloudTransfer.download(snapshot, store: store, scratch: scratch, destination: archive,
                progress: { value in await self.showProgress(value, provider: provider) })
            try Task.checkCancellation(); self.phase = "Authenticating every recovered file…"
            if testOnly {
                let count = try await vault.engine.verifyBackup(from: archive, password: recovery)
                self.phase = "Recovery test passed · \(count) items. Your library was not replaced."
            } else {
                try await vault.finishCloudRestore(archive, recovery: recovery, code: code)
                self.phase = "Library restored. Your original recovery key still works."
            }
        }
    }
    private static func scratch() throws -> URL {
        let url = TemporaryFiles.directory.appendingPathComponent("cloud-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        return url
    }
    func itemStatus(_ item: VaultItem, provider: CloudProvider) -> String {
        guard connected.contains(provider) else { return "Not connected" }
        guard receipts[provider]?.itemIDs.contains(item.id) == true else { return "Not backed up yet" }
        return "Included in last completed backup"
    }
}
#endif
