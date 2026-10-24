#if os(iOS)
import SwiftUI
import CalcCore

struct VaultSettingsView: View {
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            Section {
                NavigationLink { BackupSettingsView() } label: { settingsRow("Backups", detail: "Save, add or check a copy", symbol: "externaldrive") }
                NavigationLink { CloudBackupView() } label: { settingsRow("Cloud Copies", detail: "Choose what leaves this device", symbol: "icloud") }
                NavigationLink { PrivacyAccessView() } label: { settingsRow("Privacy & Access", detail: "Calculator code and recovery key", symbol: "lock") }
                NavigationLink { AppearanceSettingsView() } label: { settingsRow("Appearance", detail: "Layout, colors and display", symbol: "paintpalette") }
            }
            Section {
                NavigationLink { AboutView() } label: { LabeledContent(AppBrand.name, value: AppBrand.version).font(.footnote).foregroundStyle(.secondary) }
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
            Image(systemName: symbol).font(.title2).frame(width: 28).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 9)
    }
}

struct PrivacyAccessView: View {
    var body: some View {
        List {
            Section {
                NavigationLink("Change Calculator Code") { ChangeCodeView() }
                NavigationLink("Recovery Key") { RecoveryKeyHelpView() }
            }
            Section("Private storage") {
                Text("Your library stays encrypted in private app storage. Save an external backup before removing the app or its data container.")
                Text("Exported originals are ordinary photos and videos. They may contain location information.")
            }
            Section { NavigationLink("About & Privacy") { AboutView() } }
        }.navigationTitle("Privacy & Access").navigationBarTitleDisplayMode(.inline)
    }
}
struct RecoveryKeyHelpView: View {
    var body: some View {
        List {
            Section("Keep your key") {
                Text("Use the recovery key you saved when creating or restoring this library. The app does not keep a viewable copy of that key.")
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
    @AppStorage("lastRecoveryTest") private var lastTest = 0.0
    @AppStorage("lastRecoveryTestIdentity") private var lastTestIdentity = ""
    @State private var sheet: BackupSheet?
    @State private var activeExport: PreparedBackup?
    @State private var picked: BackupSelection?
    @State private var preparation: Task<Void, Never>?
    var body: some View {
        List {
            Section {
                NavigationLink { BackupImportView() } label: { Label("Add from Backup", systemImage: "externaldrive.badge.plus").frame(minHeight: 44) }
                Button {
                    preparation = Task {
                        if let request = await vault.prepareBackupForFiles() {
                            activeExport = request; sheet = .save(request)
                        }
                    }
                } label: { Label("Save a Backup", systemImage: "square.and.arrow.down").fontWeight(.semibold).frame(minHeight: 44) }
                .disabled(vault.busy)
            } footer: { Text("Choose a location outside \(AppBrand.name) / LiveContainer. No folder connection is required for this save.") }
            if vault.busy || !vault.status.isEmpty {
                Section {
                    HStack(spacing: 12) {
                        if vault.busy { ProgressView() }
                        Text(vault.status.isEmpty ? "Working…" : vault.status).font(.subheadline)
                    }
                    if let message = vault.message {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                NavigationLink("Last Saved Copy") { List {
                if lastExport > 0 {
                    LabeledContent("Saved") { Text(Date(timeIntervalSince1970: lastExport), format: .dateTime.month().day().hour().minute()) }
                    if !savedFolder.isEmpty { LabeledContent("Folder", value: savedFolder) }
                    Text(filename).font(.footnote).textSelection(.enabled)
                    if needsBackup { Label("New changes need another backup", systemImage: "exclamationmark.circle") }
                    Text("Find this filename in Files. A successful save does not confirm cloud upload.").font(.footnote).foregroundStyle(.secondary)
                } else { Text("No backup has been saved and checked yet.").foregroundStyle(.secondary) }
                }.navigationTitle("Last Saved Copy") }
            }
            Section {
                NavigationLink { RecoveryTestView() } label: { Label("Test a Backup", systemImage: "checkmark.shield") }
                    .disabled(vault.busy)
                if lastTest > 0 {
                    Text(lastTestIdentity.isEmpty ? "Older test · snapshot identity was not recorded" : lastTestIdentity).font(.caption).textSelection(.enabled)
                    LabeledContent("Last test") { Text(Date(timeIntervalSince1970: lastTest), format: .dateTime.month().day().hour().minute()) }
                }
                NavigationLink("Recovery Key") { RecoveryKeyHelpView() }
                NavigationLink("Restore after reinstalling") {
                    List {
                        Text("1. Before deleting anything, save a backup outside the app and test that exact file. Wait for your Files provider to finish uploading.")
                        Text("2. In a fresh installation, enter 160160 and hold =. Choose Restore an Existing Backup before creating a new library.")
                        Text("3. Select the .c84backup file. Enter its original recovery key, then choose a calculator code.")
                        Text("4. Check photos, videos, and dates. Reconnect your backup folder if you used one.")
                        Text("A normal update using the same app identity or LiveContainer data container should retain your library. Make a verified backup first; do not uninstall just to update.")
                        Text("The key belongs to the library. Restoring an old backup uses the old key. Creating a new library generates a different key that cannot open old backups.")
                    }.navigationTitle("Restore Your Library").navigationBarTitleDisplayMode(.inline)
                }
            } header: { Text("Check & restore") } footer: { Text("A recovery test checks the file you select, not all your backups. A screenshot of the key does not contain your photos.") }
            Section {
                NavigationLink("Connected Folder") { List {
                LabeledContent("Connected folder", value: folderName)
                Button(BackupFolder.configured ? "Reconnect or Change Folder" : "Connect Backup Folder", systemImage: "folder.badge.plus") { sheet = .folder }
                    .disabled(vault.busy)
                if BackupFolder.configured {
                    Button("Back Up to Connected Folder", systemImage: "externaldrive.badge.plus") { Task { await vault.backup() } }.disabled(vault.busy)
                    Toggle("Back up after changes", isOn: $automatic).disabled(vault.busy)
                    Button("Disconnect Folder") { BackupFolder.forget() }.disabled(vault.busy)
                }
                }.navigationTitle("Connected Folder") }
            } footer: {
                Text("Choose a writable folder, then tap Open. We check access before connecting it. If your provider or installer cannot keep folder access, use Save Backup to Files above. Automatic backups run only while the app is open; older snapshots stay until you delete them.")
            }
        }
        .navigationTitle("Backups").navigationBarTitleDisplayMode(.inline)
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
