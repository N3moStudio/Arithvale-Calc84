#if os(iOS)
import SwiftUI
import CalcCore

struct BackupActivitySection: View {
    @EnvironmentObject private var vault: VaultModel
    var body: some View {
        if vault.busy || !vault.status.isEmpty || vault.message != nil {
            Section {
                HStack(spacing: 12) {
                    if vault.busy { ProgressView() }
                    Text(vault.status.isEmpty ? (vault.busy ? "Working…" : "Backup status") : vault.status)
                        .font(.subheadline)
                }
                if let message = vault.message {
                    Text(message).font(.subheadline).foregroundStyle(ArithenPalette.color(.muted))
                }
            }
        }
    }
}

struct ConnectedBackupFolderSettings: View {
    let connect: () -> Void
    @EnvironmentObject private var vault: VaultModel
    @AppStorage("backupFolderName") private var folderName = "Not connected"
    @AppStorage("automaticFolderBackup") private var automatic = false
    var body: some View {
        ThemedList {
            Section {
                LabeledContent("Connected folder", value: folderName)
                Button(action: connect) {
                    SettingsRow(BackupFolder.configured ? "Reconnect or Change Folder" : "Connect Backup Folder", symbol: "folder.badge.plus")
                }.disabled(vault.busy)
            } footer: {
                Text("Choose a writable folder, then tap Open. If your provider or installer cannot keep folder access, use Create Backup. A checked Files copy does not confirm cloud upload.")
            }
            if BackupFolder.configured {
                Section {
                    Button("Back Up to Connected Folder", systemImage: "externaldrive.badge.plus") { Task { await vault.backup() } }
                        .disabled(vault.busy)
                    Toggle("Automatic Daily Backup", isOn: $automatic).disabled(vault.busy)
                        .onChange(of: automatic) { _, _ in vault.scheduleAutomaticBackup() }
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("When there are changes, save at most once per 24 hours while the library is open. Back Up to Connected Folder still works anytime.")
                        Text("Keep the latest 7 automatic copies. Cleanup requires a verified replacement and rechecked retained copies. Manual saves and existing older backups stay protected.")
                    }
                }
            }
            BackupActivitySection()
            if BackupFolder.configured {
                Section { Button("Disconnect Folder") { BackupFolder.forget() }.disabled(vault.busy) }
            }
        }.navigationTitle("Connected Folder").navigationBarTitleDisplayMode(.inline)
    }
}

struct BackupStatusSettingsView: View {
    @AppStorage("lastRecoveryTest") private var lastTest = 0.0
    @AppStorage("lastRecoveryTestIdentity") private var lastTestIdentity = ""
    var body: some View {
        ThemedList {
            BackupActivitySection()
            BackupCoverageView()
            Section {
                NavigationLink { LastSavedBackupSettingsView() } label: { SettingsRow("Last Saved Copy", symbol: "doc.badge.clock") }
            }
            Section {
                if lastTest > 0 {
                    Text(lastTestIdentity.isEmpty ? "Older test · snapshot identity was not recorded" : lastTestIdentity)
                        .font(.subheadline).textSelection(.enabled)
                    LabeledContent("Last test") { Text(Date(timeIntervalSince1970: lastTest), format: .dateTime.month().day().hour().minute()) }
                } else { Text("Test a backup to record a recovery check.").foregroundStyle(ArithenPalette.color(.muted)) }
            } header: { Text("Recovery checks") } footer: {
                Text("A recovery test checks the file you select, not all your backups. A screenshot of the key does not contain your photos.")
            }
        }.navigationTitle("Backup Status").navigationBarTitleDisplayMode(.inline)
    }
}

private struct LastSavedBackupSettingsView: View {
    @AppStorage("lastEncryptedExport") private var lastExport = 0.0
    @AppStorage("lastBackupFilename") private var filename = ""
    @AppStorage("lastBackupFolder") private var savedFolder = ""
    @AppStorage("libraryNeedsBackup") private var needsBackup = true
    var body: some View {
        ThemedList {
            Section {
                if lastExport > 0 {
                    LabeledContent("Saved") { Text(Date(timeIntervalSince1970: lastExport), format: .dateTime.month().day().hour().minute()) }
                    if !savedFolder.isEmpty { LabeledContent("Folder", value: savedFolder) }
                    Text(filename).font(.subheadline).textSelection(.enabled)
                    if needsBackup { Label("New changes need another backup", systemImage: "exclamationmark.circle") }
                } else { Text("No backup has been saved and checked yet.").foregroundStyle(ArithenPalette.color(.muted)) }
            } footer: {
                if lastExport > 0 { Text("Find this filename in Files. A successful save does not confirm cloud upload.") }
            }
        }.navigationTitle("Last Saved Copy").navigationBarTitleDisplayMode(.inline)
    }
}

struct BackupRemindersSettingsView: View {
    @AppStorage("privateBackupReminders") private var reminders = false
    var body: some View {
        ThemedForm {
            Section {
                Toggle("Private Backup Reminders", isOn: $reminders)
            } footer: {
                Text("Show a reminder inside the unlocked library when changes need a Files backup and the last saved copy is at least a week old, or no copy has been saved. Snooze it until tomorrow. No Lock Screen notifications.")
            }
        }.navigationTitle("Backup Reminders").navigationBarTitleDisplayMode(.inline)
    }
}

struct BackupHelpSettingsView: View {
    var body: some View {
        ThemedList {
            Section {
                NavigationLink { SharedBackupGuide() } label: { SettingsRow("How to Import from Files", symbol: "square.and.arrow.down") }
            } header: { Text("Import") } footer: {
                Text("Files → Share → LiveContainer → Arithen. Unlock the library, then tap Backup received or Import Backup in Backup Center. You can add another backup any time.")
            }
            Section("Recovery") {
                NavigationLink { RecoveryKeyHelpView() } label: { SettingsRow("Recovery Key", symbol: "key") }
                NavigationLink { RestoreLibraryHelpView() } label: { SettingsRow("Restore after reinstalling", symbol: "arrow.counterclockwise") }
            }
        }.navigationTitle("Backup Help").navigationBarTitleDisplayMode(.inline)
    }
}

private struct RestoreLibraryHelpView: View {
    var body: some View {
        ThemedList {
            Section("Restore your library") {
                Text("1. Before deleting anything, save a backup outside the app and test that exact file. Wait for your Files provider to finish uploading.")
                Text("2. In a fresh installation, enter 160160 and hold =. Choose Start from Existing Backups, or share a backup from Files to this app.")
                Text("3. Select the .c84backup file, enter its old recovery key, and tap Add Backup to Setup. Save and confirm the new recovery key, choose a calculator code, then create the library.")
                Text("4. Check photos, videos, and dates. Reconnect your backup folder if you used one.")
            }
            Section("Updates and keys") {
                Text("A normal update using the same app identity or LiveContainer data container should retain your library. Make a verified backup first; do not uninstall just to update.")
                Text("Every new library gets a new key, even when it starts from the same photos in an old backup. Old archives keep their original keys. Adding more backups later keeps the current library’s key.")
            }
        }.navigationTitle("Restore Your Library").navigationBarTitleDisplayMode(.inline)
    }
}
#endif
