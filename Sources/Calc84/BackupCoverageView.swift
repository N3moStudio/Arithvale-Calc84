#if os(iOS)
import SwiftUI
import CalcCore

struct BackupCoverageView: View {
    @EnvironmentObject private var vault: VaultModel
    @EnvironmentObject private var cloud: CloudBackupModel
    @AppStorage("lastEncryptedExport") private var lastExport = 0.0
    @AppStorage("libraryNeedsBackup") private var needsBackup = true
    @AppStorage("lastBackupDigest") private var digest = ""
    @AppStorage("lastBackupLibraryID") private var savedLibrary = ""
    @AppStorage("lastBackupFilename") private var filename = ""
    @AppStorage(RecoveryEvidenceStore.key) private var evidence = Data()
    @State private var libraryID: UUID?
    private var records: [RecoveryCheck] { (try? JSONDecoder().decode([RecoveryCheck].self, from: evidence)) ?? [] }
    private var active: [VaultItem] { vault.items.filter { $0.visible && $0.deletedAt == nil } }
    var body: some View {
        Section("Your backup copies") {
            VStack(alignment: .leading, spacing: 8) {
                Label("Files", systemImage: "folder").font(.headline)
                if lastExport > 0, savedLibrary == libraryID?.uuidString {
                    Text(needsBackup ? "Library changes need a new backup" : "Current library saved; file copy checked")
                    Text(filename).font(.caption).textSelection(.enabled)
                    Text("Saved \(Date(timeIntervalSince1970: lastExport).formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                    recovery(source: "Files", snapshotID: digest)
                } else {
                    Text("Create a backup of this library to start tracking it here.").foregroundStyle(.secondary)
                }
                Text("Files contains all library items, including Recently Deleted. Check Files itself for iCloud upload completion.").font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 6)
            ForEach(CloudProvider.allCases) { provider in
                providerRow(provider)
            }
        }.task {
            cloud.refresh()
            libraryID = try? await vault.engine.identifier()
        }
    }
    private func providerRow(_ provider: CloudProvider) -> some View {
        let policy = vault.cloudPreferences[provider]
        let eligible = policy.itemIDs(in: vault.items)
        let receipt = cloud.receipts[provider]
        let sameLibrary = libraryID != nil && receipt?.vaultID == libraryID
        let pending = BackupCoverage.pending(eligible: eligible, saved: receipt?.itemIDs ?? [], changed: receipt?.needsBackup ?? true, sameLibrary: sameLibrary)
        let blocked = active.filter { policy.blocked.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(provider.title, systemImage: "icloud").font(.headline)
                Spacer()
                Text(policy.mode == .automatic ? "Automatic" : "Manual").font(.caption).foregroundStyle(.secondary)
            }
            if !cloud.connected.contains(provider) { Text("Not connected").foregroundStyle(.secondary) }
            else if cloud.running && cloud.activeProvider == provider {
                if let progress = cloud.progress { ProgressView(value: progress) } else { ProgressView() }
                Text(cloud.phase).font(.footnote)
            } else if eligible.isEmpty { Text("No items chosen for this provider").foregroundStyle(.secondary) }
            else { Text(pending == 0 ? "\(eligible.count) chosen items in a current backup" : "\(pending) chosen items need a current backup") }
            Text("\(blocked) Never Upload · \(max(0, active.count - eligible.count - blocked)) not selected").font(.caption).foregroundStyle(.secondary)
            if sameLibrary, let saved = receipt?.saved {
                Text("Last completed \(saved.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                recovery(source: provider.title, snapshotID: receipt?.snapshotID?.uuidString)
            }
            HStack {
                NavigationLink("Manage \(provider.title)") { CloudBackupView() }
                Spacer()
                if cloud.connected.contains(provider), !eligible.isEmpty {
                    Button("Back Up Now") { cloud.backup(vault: vault, only: provider) }.buttonStyle(.borderless).disabled(vault.busy)
                }
            }.font(.subheadline).frame(minHeight: 44)
        }.padding(.vertical, 6)
    }
    @ViewBuilder private func recovery(source: String, snapshotID: String?) -> some View {
        if let record = records.last(where: { $0.matches(source: source, snapshotID: snapshotID) }) {
            Label("This backup passed recovery · \(record.items) items · \(record.checked.formatted(date: .abbreviated, time: .omitted))", systemImage: "checkmark.shield")
                .font(.caption)
        } else {
            Label("Recovery not yet tested for this exact backup", systemImage: "questionmark.circle")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
#endif
