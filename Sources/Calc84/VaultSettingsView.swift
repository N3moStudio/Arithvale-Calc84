#if os(iOS)
import SwiftUI
import CalcCore

struct VaultSettingsView: View {
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("libraryLayout") private var layout = LibraryLayout.timeline.rawValue
    @AppStorage("libraryDateSource") private var dateSource = LibraryDateSource.captured.rawValue
    @AppStorage("libraryNewestFirst") private var newestFirst = true
    @AppStorage("memoryGridColumns") private var columns = 4
    @AppStorage("lastEncryptedExport") private var lastExport = 0.0
    @AppStorage("libraryNeedsBackup") private var needsBackup = true
    var body: some View {
        List {
            Section {
                NavigationLink { BackupSettingsView() } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("Backup & Recovery", systemImage: "externaldrive")
                        BackupSummaryView().environmentObject(vault.cloud).font(.footnote).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                }
            }
            Section { NavigationLink("About " + AppBrand.name) { AboutView() } }
            Section("Your gallery") {
                Picker("View", selection: $layout) {
                    Text("Memories grid").tag(LibraryLayout.timeline.rawValue)
                    Text("Photos grid").tag(LibraryLayout.photos.rawValue)
                }
                Text(layout == LibraryLayout.timeline.rawValue ? "Tall tiles, month headings, and a date handle for quick scrolling." : "Square tiles with year, month, or day grouping.")
                    .font(.footnote).foregroundStyle(.secondary)
                Picker("Columns", selection: $columns) { Text("2 · Large").tag(2); Text("3").tag(3); Text("4 · Compact").tag(4) }
                Picker("Dates", selection: $dateSource) {
                    ForEach(LibraryDateSource.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                Toggle("Newest first", isOn: $newestFirst)
            }
            Section("Access") {
                NavigationLink("Change calculator code") { ChangeCodeView() }
                Text("Changing this code does not change your recovery key.").font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                NavigationLink("Privacy & storage") {
                    List {
                        Section("Private library") {
                            Text("Your library is encrypted in private app storage. No \(AppBrand.name) account or analytics. Optional cloud backups use your own Blomp or MEGA account.")
                            Text("Deleting the app or its data container can delete that copy. Keep an external backup and its recovery key.")
                        }
                        Section("Copies you save") {
                            Text("Encrypted backups can be found, copied, or deleted in Files. Their contents are not ordinary playable photos or videos.")
                            Text("Shared or exported originals are unencrypted and can include location metadata. Recipients can keep them.")
                        }
                        Section("Before relying on it") {
                            Text("Test a backup and restore it using disposable samples first. Keep originals until phone tests pass. There is no screenshot-blocking or undetectability guarantee.")
                        }
                    }.navigationTitle("Privacy & Storage").navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .alert("Couldn’t Complete", isPresented: Binding(get: { vault.message != nil }, set: { if !$0 { vault.message = nil } })) {
            Button("Close", role: .cancel) { vault.message = nil }
        } message: { Text(vault.message ?? "") }
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
                NavigationLink { CloudBackupView() } label: { Label("MEGA & Blomp", systemImage: "icloud") }
                Text("Files backup").font(.title3.bold())
                Text("Save an encrypted backup to Files. Keep its recovery key separately—you need both after reinstalling.").foregroundStyle(.secondary)
                Button {
                    preparation = Task {
                        if let request = await vault.prepareBackupForFiles() {
                            activeExport = request; sheet = .save(request)
                        }
                    }
                } label: { Label("Save Backup to Files", systemImage: "square.and.arrow.down").fontWeight(.semibold).frame(minHeight: 44) }
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
            Section("Last checked copy") {
                if lastExport > 0 {
                    LabeledContent("Saved") { Text(Date(timeIntervalSince1970: lastExport), format: .dateTime.month().day().hour().minute()) }
                    if !savedFolder.isEmpty { LabeledContent("Folder", value: savedFolder) }
                    Text(filename).font(.footnote).textSelection(.enabled)
                    if needsBackup { Label("New changes need another backup", systemImage: "exclamationmark.circle") }
                    Text("Find this filename in Files. A successful save does not confirm cloud upload.").font(.footnote).foregroundStyle(.secondary)
                } else { Text("No backup has been saved and checked yet.").foregroundStyle(.secondary) }
            }
            Section {
                NavigationLink { RecoveryTestView() } label: { Label("Test a Backup", systemImage: "checkmark.shield") }
                    .disabled(vault.busy)
                if lastTest > 0 {
                    Text(lastTestIdentity.isEmpty ? "Older test · snapshot identity was not recorded" : lastTestIdentity).font(.caption).textSelection(.enabled)
                    LabeledContent("Last test") { Text(Date(timeIntervalSince1970: lastTest), format: .dateTime.month().day().hour().minute()) }
                }
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
                LabeledContent("Connected folder", value: folderName)
                Button(BackupFolder.configured ? "Reconnect or Change Folder" : "Connect Backup Folder", systemImage: "folder.badge.plus") { sheet = .folder }
                    .disabled(vault.busy)
                if BackupFolder.configured {
                    Button("Back Up to Connected Folder", systemImage: "externaldrive.badge.plus") { Task { await vault.backup() } }.disabled(vault.busy)
                    Toggle("Back up after changes", isOn: $automatic).disabled(vault.busy)
                    Button("Disconnect Folder") { BackupFolder.forget() }.disabled(vault.busy)
                }
            } header: { Text("Optional · reuse a folder") } footer: {
                Text("Choose a writable folder, then tap Open. We check access before connecting it. If your provider or installer cannot keep folder access, use Save Backup to Files above. Automatic backups run only while the app is open; older snapshots stay until you delete them.")
            }
        }
        .navigationTitle("Backup & Recovery").navigationBarTitleDisplayMode(.inline)
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
                    picked = url.map(BackupSelection.init)
                    sheet = nil
                }
            case .save(let backup):
                BackupDocumentPicker(purpose: .save(backup.url)) { url in
                    guard sheet != nil else { return }
                    picked = url.map(BackupSelection.init)
                    sheet = nil
                }
            }
        }
    }
}
#endif
