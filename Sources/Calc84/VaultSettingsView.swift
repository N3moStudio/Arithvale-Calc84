#if os(iOS)
import SwiftUI
import CalcCore

struct VaultSettingsView: View {
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.arithenTheme) private var theme
    @AppStorage(ArithenPalette.surfaceKey) private var surface = ThemeSurface.theme.rawValue
    var body: some View {
        ThemedList {
            Section {
                NavigationLink { BackupSettingsView() } label: { settingsRow("Backups", detail: "Save, add or check a copy", symbol: "externaldrive") }
                NavigationLink { CloudBackupView() } label: { settingsRow("Cloud Copies", detail: "Choose what leaves this device", symbol: "icloud") }
                NavigationLink { PrivacyAccessView() } label: { settingsRow("Privacy & Access", detail: "Code and photo indexing", symbol: "lock") }
                NavigationLink { AppearanceSettingsView() } label: { settingsRow("Appearance", detail: theme.title + " · " + (ThemeSurface(rawValue: surface) ?? .theme).title, symbol: "paintpalette") }
            }
            Section {
                NavigationLink { AboutView() } label: { settingsRow("About", detail: AppBrand.name + " " + AppBrand.version, symbol: "info.circle") }
                Button("Lock & Return to Calculator", systemImage: "lock.fill") { vault.lock(); dismiss() }
            }
        }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert("Couldn’t Complete", isPresented: Binding(get: { vault.message != nil }, set: { if !$0 { vault.message = nil } })) {
                Button("Close", role: .cancel) { vault.message = nil }
            } message: { Text(vault.message ?? "") }
    }
    private func settingsRow(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(.tint)
                .frame(width: 38, height: 38).background(ArithenPalette.color(.accent).opacity(0.10), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.footnote).foregroundStyle(ArithenPalette.color(.muted))
            }
        }.padding(.vertical, 5)
    }
}

struct PrivacyAccessView: View {
    @EnvironmentObject private var vault: VaultModel
    var body: some View {
        ThemedList {
            Section {
                NavigationLink("Change Calculator Code") { ChangeCodeView() }
                NavigationLink("Photo Indexing") { PrivateSearchSettings(search: vault.textSearch) }
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
            Section {
                NavigationLink("Test a Backup & Key") { RecoveryTestView() }
            } footer: { Text("Adding items from a different backup keeps this library’s key. The source key only opens the backup you are adding.") }
        }.navigationTitle("Recovery Key").navigationBarTitleDisplayMode(.inline)
    }
}

private enum BackupSheet: Identifiable {
    case folder, save(PreparedBackup)
    var id: String { switch self { case .folder: return "folder"; case .save(let request): return request.id.uuidString } }
}

struct BackupSettingsView: View {
    @EnvironmentObject private var vault: VaultModel
    @AppStorage("backupFolderName") private var folderName = "Not connected"
    @AppStorage("automaticFolderBackup") private var automatic = false
    @AppStorage("lastEncryptedExport") private var lastExport = 0.0
    @AppStorage("lastBackupFilename") private var filename = ""
    @AppStorage("lastBackupFolder") private var savedFolder = ""
    @AppStorage("libraryNeedsBackup") private var needsBackup = true
    @AppStorage("privateBackupReminders") private var reminders = false
    @AppStorage("lastRecoveryTest") private var lastTest = 0.0
    @AppStorage("lastRecoveryTestIdentity") private var lastTestIdentity = ""
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
                } label: { Label("Create Backup", systemImage: "square.and.arrow.down").fontWeight(.semibold).frame(minHeight: 44) }
                .disabled(vault.busy)
                NavigationLink { BackupImportView() } label: { Label("Import Backup", systemImage: "externaldrive.badge.plus").frame(minHeight: 44) }.disabled(vault.busy)
                NavigationLink { RecoveryTestView() } label: { Label("Test Backup", systemImage: "checkmark.shield").frame(minHeight: 44) }.disabled(vault.busy)
            } footer: { Text("Choose a location outside \(AppBrand.name) / LiveContainer. No folder connection is required for this save.") }
            Section { NavigationLink("Storage") { LibraryStorageView() } }
            BackupCoverageView()
            Section {
                Toggle("Private Backup Reminders", isOn: $reminders)
            } footer: {
                Text("Show a reminder inside the unlocked library when changes need a Files backup and the last saved copy is at least a week old, or no copy has been saved. Snooze it until tomorrow. No Lock Screen notifications.")
            }
            Section {
                NavigationLink { SharedBackupGuide() } label: { Label("How to Import from Files", systemImage: "square.and.arrow.down") }
                Text("Files → Share → LiveContainer → Arithen. Unlock the library, then tap Backup received or Import Backup above. You can add another backup any time.")
                    .font(.footnote).foregroundStyle(ArithenPalette.color(.muted))
                StorageEstimateView(bytes: vault.items.reduce(Int64(0)) { $0 + Int64($1.byteCount) }, copies: 2)
            }
            if vault.busy || !vault.status.isEmpty {
                Section {
                    HStack(spacing: 12) {
                        if vault.busy { ProgressView() }
                        Text(vault.status.isEmpty ? "Working…" : vault.status).font(.subheadline)
                    }
                    if let message = vault.message {
                        Text(message).font(.footnote).foregroundStyle(ArithenPalette.color(.muted))
                    }
                }
            }
            Section {
                NavigationLink("Last Saved Copy") { ThemedList {
                if lastExport > 0 {
                    LabeledContent("Saved") { Text(Date(timeIntervalSince1970: lastExport), format: .dateTime.month().day().hour().minute()) }
                    if !savedFolder.isEmpty { LabeledContent("Folder", value: savedFolder) }
                    Text(filename).font(.footnote).textSelection(.enabled)
                    if needsBackup { Label("New changes need another backup", systemImage: "exclamationmark.circle") }
                    Text("Find this filename in Files. A successful save does not confirm cloud upload.").font(.footnote).foregroundStyle(ArithenPalette.color(.muted))
                } else { Text("No backup has been saved and checked yet.").foregroundStyle(ArithenPalette.color(.muted)) }
                }.navigationTitle("Last Saved Copy") }
            }
            Section {
                if lastTest > 0 {
                    Text(lastTestIdentity.isEmpty ? "Older test · snapshot identity was not recorded" : lastTestIdentity).font(.caption).textSelection(.enabled)
                    LabeledContent("Last test") { Text(Date(timeIntervalSince1970: lastTest), format: .dateTime.month().day().hour().minute()) }
                }
                NavigationLink("Recovery Key") { RecoveryKeyHelpView() }
                NavigationLink("Restore after reinstalling") {
                    ThemedList {
                        Text("1. Before deleting anything, save a backup outside the app and test that exact file. Wait for your Files provider to finish uploading.")
                        Text("2. In a fresh installation, enter 160160 and hold =. Choose Start from Existing Backups, or share a backup from Files to this app.")
                        Text("3. Select the .c84backup file, enter its old recovery key, and tap Add Backup to Setup. Save and confirm the new recovery key, choose a calculator code, then create the library.")
                        Text("4. Check photos, videos, and dates. Reconnect your backup folder if you used one.")
                        Text("A normal update using the same app identity or LiveContainer data container should retain your library. Make a verified backup first; do not uninstall just to update.")
                        Text("Every new library gets a new key, even when it starts from the same photos in an old backup. Old archives keep their original keys. Adding more backups later keeps the current library’s key.")
                    }.navigationTitle("Restore Your Library").navigationBarTitleDisplayMode(.inline)
                }
            } header: { Text("Check & restore") } footer: { Text("A recovery test checks the file you select, not all your backups. A screenshot of the key does not contain your photos.") }
            Section {
                NavigationLink("Connected Folder") { ThemedList {
                LabeledContent("Connected folder", value: folderName)
                Button(BackupFolder.configured ? "Reconnect or Change Folder" : "Connect Backup Folder", systemImage: "folder.badge.plus") { sheet = .folder }
                    .disabled(vault.busy)
                if BackupFolder.configured {
                    Button("Back Up to Connected Folder", systemImage: "externaldrive.badge.plus") { Task { await vault.backup() } }.disabled(vault.busy)
                    Toggle("Automatic Daily Backup", isOn: $automatic).disabled(vault.busy)
                        .onChange(of: automatic) { _, _ in vault.scheduleAutomaticBackup() }
                    Text("When there are changes, save at most once per 24 hours while the library is open. Back Up to Connected Folder still works anytime.")
                        .font(.footnote).foregroundStyle(ArithenPalette.color(.muted))
                    Text("Keep the latest 7 automatic copies. Cleanup requires a verified replacement and rechecked retained copies. Manual saves and existing older backups stay protected.")
                        .font(.footnote).foregroundStyle(ArithenPalette.color(.muted))
                    Button("Disconnect Folder") { BackupFolder.forget() }.disabled(vault.busy)
                }
                }.navigationTitle("Connected Folder") }
            } footer: {
                Text("Choose a writable folder, then tap Open. If your provider or installer cannot keep folder access, use Create Backup. A checked Files copy does not confirm cloud upload.")
            }
        }
        .navigationTitle("Backup Center").navigationBarTitleDisplayMode(.inline)
        .onDisappear { if activeExport == nil { preparation?.cancel() } }
        .sheet(item: $sheet, onDismiss: {
            if let activeExport { vault.finishBackupExport(activeExport, destination: picked?.url) }
            else if let picked { vault.connectBackupFolder(picked.url) }
            activeExport = nil; picked = nil
        }) { request in
            switch request {
            case .folder:
                BackupDocumentPicker(purpose: .folder) { url in
                    guard sheet != nil else { return }
                    picked = url.map { BackupSelection($0) }
                    sheet = nil
                }
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
