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
    @EnvironmentObject private var vault: VaultModel
    @AppStorage("backupFolderName") private var folderName = "Not connected"
    @AppStorage("automaticFolderBackup") private var automatic = false
    private struct Request: Identifiable { let id = UUID() }
    @State private var request: Request?
    @State private var picked: BackupSelection?
    @State private var notice: String?
    var body: some View {
        ThemedList {
            Section {
                LabeledContent("Connected folder", value: folderName)
                Button { picked = nil; notice = nil; request = Request() } label: {
                    SettingsRow(BackupFolder.configured ? "Reconnect or Change Folder" : "Connect Backup Folder", symbol: "folder.badge.plus")
                }.disabled(vault.busy)
            } footer: {
                Text("Select the folder itself, then tap Open. If you are inside it, go back one level first. Only one folder can be connected.")
            }
            if let notice { Section { Text(notice).font(.subheadline) } }
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
            Section {
                DisclosureGroup("If Open does nothing") {
                    Text("In Files, go to the parent folder, tap Select if shown, select one folder, then Open.")
                    Text("In LiveContainer, use Fix File Picker and turn off Fix File Picker (legacy), then relaunch Arithen. The legacy option may copy a folder into the app instead of granting access to the original.")
                    Text("Some host/provider combinations cannot grant folder access. Create Backup can still save individual copies. A shared or copied folder cannot create a permanent connection.")
                }
            }
        }.navigationTitle("Connected Folder").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $request, onDismiss: {
                if let selection = picked {
                    picked = nil
                    vault.connectBackupFolder(selection.url)
                    withExtendedLifetime(selection) {}
                } else if notice == nil {
                    notice = "Files closed without returning a folder. Your existing connection is unchanged."
                }
            }) { presented in
                BackupDocumentPicker(purpose: .connectFolder, finished: { url in
                    guard request?.id == presented.id else { return }
                    picked = url.map { BackupSelection($0) }
                    if url == nil { notice = "No folder selected. Your existing connection is unchanged." }
                    request = nil
                }, failure: { message in
                    guard request?.id == presented.id else { return }
                    notice = message; request = nil
                })
            }
    }
}

struct BackupStatusSettingsView: View {
    var body: some View {
        ThemedList {
            BackupActivitySection()
            BackupCoverageView()
        }.navigationTitle("Backup Status").navigationBarTitleDisplayMode(.inline)
    }
}

struct BackupRemindersSettingsView: View {
    @AppStorage("privateBackupReminders") private var reminders = true
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
                Text("Receive a backup in Files, then add it through Import Backup. You can import another backup any time.")
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
