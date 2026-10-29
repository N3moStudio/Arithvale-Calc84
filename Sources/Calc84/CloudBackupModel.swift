#if os(iOS)
import SwiftUI
import CalcCore

struct CloudReceipt: Codable {
    var objects: Set<String> = []
    var itemIDs: Set<UUID> = []
    var saved: Date?
    var vaultID: UUID?
    var needsBackup = true
    var snapshotID: UUID? = nil
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
    @Published var snapshots: [CloudSnapshotSummary] = []
    @Published var nextPage: String?
    @Published var skippedCatalogs = 0
    private var listingProvider: CloudProvider?
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
            self.phase = "\(provider.title) connected. Choose items or enable automatic backup."
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
    func backup(vault: VaultModel, only: CloudProvider? = nil, verifyAll: Bool = false, automaticOnly: Bool = false) {
        guard vault.unlocked else { return }
        let providers = CloudProvider.allCases.filter {
            connected.contains($0) && (only == nil || only == $0)
                && (!automaticOnly || vault.cloudPreferences[$0].mode == .automatic)
        }
        guard !providers.isEmpty else { if !automaticOnly { error = "Connect a service first." }; return }
        start(vault) {
            self.phase = "Checking your encrypted library…"
            let scratch = try Self.scratch()
            defer { try? FileManager.default.removeItem(at: scratch) }
            var failures: [String] = []
            var completed = 0
            var empty: [String] = []
            for provider in providers {
                try Task.checkCancellation(); self.activeProvider = provider
                do {
                    // Re-read the committed policy for each provider; never reuse another plan.
                    let preferences = try await vault.engine.cloudPreferences()
                    if automaticOnly && preferences[provider].mode != .automatic { continue }
                    let plan = try await vault.engine.cloudPlan(provider: provider)
                    try Task.checkCancellation()
                    guard !plan.itemIDs.isEmpty else { empty.append(provider.title); continue }
                    try StoragePreflight.require(bytes: Int64(plan.snapshot.records.map(\.bytes).max() ?? 0) + 8 * 1024 * 1024)
                    let store = try await self.store(provider)
                    let previous = self.receipts[provider] ?? .init()
                    try await CloudTransfer.upload(plan, store: store, scratch: scratch,
                        previouslyVerified: verifyAll ? [] : previous.objects,
                        verified: { name in await self.recordObject(name, provider: provider) },
                        progress: { value in await self.showProgress(value, provider: provider) })
                    try Task.checkCancellation()
                    var receipt = self.receipts[provider] ?? .init()
                    receipt.objects = Set(plan.snapshot.records.map(\.filename))
                    receipt.itemIDs = plan.itemIDs
                    receipt.vaultID = plan.snapshot.vaultID; receipt.saved = Date(); receipt.needsBackup = false
                    receipt.snapshotID = plan.snapshot.id
                    self.receipts[provider] = receipt; self.persist(provider); completed += 1
                } catch {
                    if Task.isCancelled { throw CancellationError() }
                    failures.append(provider.title + ": " + Self.message(error)); self.stores[provider] = nil
                }
            }
            self.error = failures.isEmpty ? nil : failures.joined(separator: "\n\n")
            self.phase = failures.isEmpty ? (completed > 0 ? "Selected items backed up" : "No items eligible for backup") : "Some backups need attention"
            if !empty.isEmpty { self.phase += ". Choose items for " + empty.joined(separator: ", ") + "." }
        }
    }
    private func recordObject(_ name: String, provider: CloudProvider) {
        guard !Task.isCancelled else { return }
        var receipt = receipts[provider] ?? .init(); receipt.objects.insert(name)
        receipts[provider] = receipt; persist(provider)
    }
    private func showProgress(_ value: CloudTransferProgress, provider: CloudProvider) {
        guard !Task.isCancelled else { return }
        phase = provider.title + " · " + value.phase + " (\(value.completed)/\(value.total))"
        if value.totalBytes > 0 {
            phase += " · " + ByteCountFormatter.string(fromByteCount: value.completedBytes, countStyle: .file)
                + " of " + ByteCountFormatter.string(fromByteCount: value.totalBytes, countStyle: .file) + " checked"
        }
        progress = value.totalBytes > 0 ? Double(value.completedBytes) / Double(value.totalBytes) : Double(value.completed) / Double(max(value.total, 1))
    }
    func findBackups(_ provider: CloudProvider, vault: VaultModel, next: Bool = false) {
        guard !running, !vault.busy else { return }
        let cursor = next && listingProvider == provider ? nextPage : nil
        snapshots = []; skippedCatalogs = 0; nextPage = nil; listingProvider = provider
        start(vault) {
            self.phase = "Finding saved backups…"
            let store = try await self.store(provider)
            let page = try await store.listPage(prefix: "c84/v1/", after: cursor, limit: CloudDiscovery.pageSize)
            guard page.next == nil || page.next! > (cursor ?? "") else { throw CloudError.service }
            let scratch = try Self.scratch(); defer { try? FileManager.default.removeItem(at: scratch) }
            try await CloudDiscovery.scan(page, store: store, scratch: scratch,
                found: { value in await self.foundSnapshot(value) }, skipped: { await self.skippedSnapshot() })
            try Task.checkCancellation()
            self.nextPage = page.next
            self.phase = self.snapshots.isEmpty ? "No readable backups on this page." : "Choose a saved backup."
            if self.skippedCatalogs > 0 { self.phase += " \(self.skippedCatalogs) damaged or missing catalogs skipped." }
            if page.next != nil { self.phase += " More history is available on the next page." }
        }
    }
    private func foundSnapshot(_ value: CloudSnapshotSummary) {
        guard !Task.isCancelled else { return }
        if !snapshots.contains(where: { $0.id == value.id && $0.vaultID == value.vaultID }) { snapshots.append(value) }
        snapshots.sort { $0.created > $1.created }
    }
    private func skippedSnapshot() { if !Task.isCancelled { skippedCatalogs += 1 } }
    func restore(_ summary: CloudSnapshotSummary, provider: CloudProvider, recovery: String, code: String, vault: VaultModel, testOnly: Bool, newRecovery: String? = nil) {
        guard testOnly ? vault.unlocked : !vault.exists else { return }
        guard testOnly || (newRecovery.map(VaultCode.validRecovery) == true) else { error = VaultError.invalidRecovery.localizedDescription; return }
        start(vault) {
            self.phase = "Checking recovery key…"
            let store = try await self.store(provider)
            let scratch = try Self.scratch(); defer { try? FileManager.default.removeItem(at: scratch) }
            let snapshot = try await CloudDiscovery.load(path: summary.path, store: store, scratch: scratch)
            _ = try await Task.detached { try VaultRepository.validateCloudRecovery(snapshot, password: recovery) }.value
            try Task.checkCancellation()
            try StoragePreflight.require(bytes: snapshot.records.reduce(Int64(0)) { $0 + Int64($1.bytes) } * 3)
            let archive = scratch.appendingPathComponent("recovery.c84backup")
            try await CloudTransfer.download(snapshot, store: store, scratch: scratch, destination: archive,
                progress: { value in await self.showProgress(value, provider: provider) })
            try Task.checkCancellation(); self.phase = "Authenticating every recovered file…"
            if testOnly {
                let count = try await vault.engine.verifyBackup(from: archive, password: recovery)
                try Task.checkCancellation()
                vault.recordRecoveryTest(source: provider.title, snapshot: snapshot.id.uuidString, library: snapshot.vaultID.uuidString)
                vault.recordRecoveryEvidence(source: provider.title, snapshotID: snapshot.id.uuidString, items: count)
                self.phase = "Recovery test passed · \(count) items. Your library was not replaced."
            } else {
                guard let newRecovery else { throw VaultError.invalidRecovery }
                self.phase = "Copying into your new encrypted library…"
                try await vault.finishCloudRestore(archive, recovery: recovery, newRecovery: newRecovery, code: code)
                self.phase = "Library created. Future backups use the new recovery key you saved."
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
