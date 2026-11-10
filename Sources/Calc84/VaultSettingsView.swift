#if os(iOS)
import SwiftUI
import CalcCore

struct VaultSettingsView: View {
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ThemedList {
            Section { AppearanceSettingsCard() }
            Section("Library") {
                NavigationLink { BackupSettingsView() } label: { SettingsRow("Backups", symbol: "externaldrive") }
                NavigationLink { CloudBackupView() } label: { SettingsRow("Cloud Copies", symbol: "icloud") }
                NavigationLink { LibraryStorageView() } label: { SettingsRow("Storage", symbol: "internaldrive") }
                NavigationLink { PrivacyAccessView() } label: { SettingsRow("Privacy & Access", symbol: "lock") }
            }
            Section("Help") {
                NavigationLink { AboutView() } label: { SettingsRow("About", symbol: "info.circle", value: AppBrand.version) }
            }
            Section {
                Button("Lock & Return to Calculator", systemImage: "lock.fill") { vault.lock(); dismiss() }
            }
        }.contentMargins(.top, 16, for: .scrollContent)
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert("Couldn’t Complete", isPresented: Binding(get: { vault.message != nil }, set: { if !$0 { vault.message = nil } })) {
                Button("Close", role: .cancel) { vault.message = nil }
            } message: { Text(vault.message ?? "") }
    }
}

struct PrivacyAccessView: View {
    @EnvironmentObject private var vault: VaultModel
    var body: some View {
        ThemedList {
            Section {
                NavigationLink { ChangeCodeView() } label: { SettingsRow("Change Calculator Code", symbol: "lock.rotation") }
                NavigationLink { PrivateSearchSettings(search: vault.textSearch) } label: { SettingsRow("Photo Indexing", symbol: "text.viewfinder") }
            }
            Section("Private storage") {
                Text("Your library stays encrypted in private app storage. Save an external backup before removing the app or its data container.")
                Text("Exported originals are ordinary photos and videos. They may contain location information.")
            }

        }.navigationTitle("Privacy & Access").navigationBarTitleDisplayMode(.inline)
    }
}
struct RecoveryKeyHelpView: View {
    var body: some View {
        ThemedList {
            Section("Keep your key") {
                Text("Use the recovery key saved during this library’s setup. Starting a new library from a backup in version 0.7.0 or later gives it a new key. Earlier restored libraries keep their original key. Updates do not change existing keys.")
                Text("The app does not keep a viewable copy of your recovery key. The old key for a source backup cannot open a newer library created with a different key.")
                Text("Your calculator code opens this installation. It cannot decrypt a backup by itself.")
            }
            Section { Text("Adding items from a different backup keeps this library’s key. The source key only opens the backup you are adding.") }
        }.navigationTitle("Recovery Key").navigationBarTitleDisplayMode(.inline)
    }
}

private enum BackupSheet: Identifiable {
    case save(PreparedBackup)
    var id: String { switch self { case .save(let request): return request.id.uuidString } }
}

struct BackupSettingsView: View {
    @EnvironmentObject private var vault: VaultModel
    @AppStorage("backupFolderName") private var folderName = "Not connected"
    @AppStorage("privateBackupReminders") private var reminders = true
    // This screen owns exports; the visible Connected Folder page owns its folder picker.
    @State private var sheet: BackupSheet?
    @State private var activeExport: PreparedBackup?
    @State private var picked: BackupSelection?
    @State private var preparation: Task<Void, Never>?
    var body: some View {
        ThemedList {
            Section {
                Button {
                    preparation = Task {
                        if let request = await vault.prepareBackupForFiles() {
                            activeExport = request; sheet = .save(request)
                        }
                    }
                } label: { SettingsRow("Create Backup", symbol: "square.and.arrow.down") }
                .disabled(vault.busy)
                NavigationLink { BackupImportView() } label: { SettingsRow("Import Backup", symbol: "externaldrive.badge.plus") }
                    .disabled(vault.busy)
                NavigationLink { RecoveryTestView() } label: { SettingsRow("Check a Backup", symbol: "checkmark.shield") }
                    .disabled(vault.busy)
            } footer: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose a location outside \(AppBrand.name) / LiveContainer. No folder connection is required for this save.")
                    StorageEstimateView(bytes: vault.items.reduce(Int64(0)) { $0 + Int64($1.byteCount) }, copies: 2)
                }
            }
            BackupActivitySection()
            Section("Save & status") {
                NavigationLink {
                    ConnectedBackupFolderSettings()
                } label: { SettingsRow("Connected Folder", symbol: "folder", detail: folderName) }
                NavigationLink { BackupStatusSettingsView() } label: { SettingsRow("Backup Status", symbol: "checkmark.shield") }
            }
            Section("Options") {
                NavigationLink { BackupRemindersSettingsView() } label: {
                    SettingsRow("Backup Reminders", symbol: "bell", value: reminders ? "On" : "Off")
                }
            }
            Section {
                NavigationLink { BackupHelpSettingsView() } label: { SettingsRow("Backup Help", symbol: "questionmark.circle") }
            }
        }
        .navigationTitle("Backups").navigationBarTitleDisplayMode(.inline)
        .onDisappear { if activeExport == nil { preparation?.cancel() } }
        .sheet(item: $sheet, onDismiss: {
            if let activeExport { vault.finishBackupExport(activeExport, destination: picked?.url) }
            activeExport = nil; picked = nil
        }) { request in
            switch request {
            case .save(let backup):
                BackupDocumentPicker(purpose: .save(backup.url)) { url in
                    guard sheet != nil else { return }
                    picked = url.map { BackupSelection($0) }
                    sheet = nil
                }
            }
        }
    }
}
#endif
