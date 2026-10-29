#if os(iOS)
import SwiftUI
import CalcCore
import PhotosUI
#if canImport(_PhotosUI_SwiftUI)
import _PhotosUI_SwiftUI
#endif
import UniformTypeIdentifiers
import ImageIO

struct PrivateSpaceView: View {
    @EnvironmentObject private var vault: VaultModel
    let close: () -> Void
    var body: some View {
        NavigationStack {
            Group {
                if vault.unlocked { LibraryView(close: close) }
                else { AccessView(close: close) }
            }
        }.tint(CalcTheme.accent)
            .onChange(of: vault.unlocked) { old, new in if old && !new { close() } }
    }
}

private struct AccessView: View {
    @EnvironmentObject private var vault: VaultModel
    let close: () -> Void
    @State private var setup = SetupSession()
    @State private var password = ""
    @State private var code = ""
    @State private var confirmation = ""
    @State private var restoring = false
    @State private var backups: [QueuedSetupBackup] = []
    @StateObject private var backupInput = BackupInputModel()
    private var creating: Bool { !vault.exists }
    private var canContinue: Bool {
        !vault.busy && !backupInput.working && VaultCode.valid(code) && code == confirmation
        && (creating ? setup.canCreate : !password.isEmpty)
        && (!creating || !restoring || (!backups.isEmpty && backupInput.backup == nil && password.isEmpty))
    }
    private func clearSecrets() {
        setup.clear(); password = ""; code = ""; confirmation = ""; backups = []
    }
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "lock.square.stack").font(.system(size: 40, weight: .medium))
                        .foregroundStyle(CalcTheme.accent).accessibilityHidden(true)
                    Text(creating ? "A space of your own." : "Recover access.").font(.largeTitle.bold())
                    Text(creating ? "Your calculator code opens this phone. Your recovery key brings your files back on another."
                         : "Use your recovery key, or the password from the original version 0.1. Your existing files won’t be replaced.")
                        .foregroundStyle(.secondary)
                }.padding(.vertical, 12)
            }
            if !vault.exists {
                Section {
                    Toggle("Start from Existing Backups", isOn: $restoring)
                        .disabled(vault.busy)
                    NavigationLink {
                        CloudBackupView(restoring: true, setup: $setup)
                    } label: { Label("Restore from Cloud", systemImage: "icloud.and.arrow.down") }
                        .disabled(vault.busy || !backups.isEmpty || backupInput.backup != nil || backupInput.working)
                    if !backups.isEmpty {
                        Text("Remove the queued backups to switch to cloud setup.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            if !vault.exists {
                SharedBackupSection(input: backupInput) { restoring = true }
            }
            if creating && restoring {
                BackupInputSection(input: backupInput, enabled: !vault.busy)
                if let backup = backupInput.backup {
                    Section {
                        SecureField("Source recovery key or original password", text: $password)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button("Add Backup to Setup") {
                            backups.append(.init(backup: backup, recovery: password))
                            password = ""; backupInput.clearSelection()
                        }.disabled(password.isEmpty || vault.busy || backups.count >= 32)
                    } header: { Text("This backup’s old key") } footer: {
                        Text("This key only reads this source. Your new key below protects the new library. Every source is checked before setup completes.")
                    }
                }
                if !backups.isEmpty {
                    Section("Backups to Add") {
                        ForEach(backups) { entry in
                            HStack {
                                Text(entry.backup.displayName).lineLimit(2)
                                Spacer()
                                Button("Remove", role: .destructive) { backups.removeAll { $0.id == entry.id } }
                                    .buttonStyle(.borderless).disabled(vault.busy)
                            }
                        }
                        StorageEstimateView(bytes: backups.reduce(Int64(0)) { $0 + Int64((try? $1.backup.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }, copies: 2)
                        Text("You can choose another backup above, with its own old key, or finish setup now. In LiveContainer, finish setup before leaving to share another backup; then use + → From a Backup. All additions use the new library’s key.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            if creating {
                NewRecoveryKeySection(setup: $setup).disabled(vault.busy)
            } else {
                Section("Current Recovery Key") {
                    SecureField("Recovery key or original password", text: $password)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
            }
            Section {
                SecureField("New calculator code", text: $code).keyboardType(.numberPad)
                SecureField("Repeat calculator code", text: $confirmation).keyboardType(.numberPad)
            } header: { Text("Calculator Code") } footer: {
                if !code.isEmpty && !VaultCode.valid(code) { Text("Use 6–12 digits, different from 160160.") }
                else if !confirmation.isEmpty && code != confirmation { Text("The codes don’t match yet.") }
                Text("Choose 6–12 digits. Type them in the calculator and hold =. The starter code 160160 cannot protect an imported library.")
            }
            Section {
                Button {
                    vault.open(password: creating ? setup.recovery : password, code: code, creating: creating, backups: creating && restoring ? backups : [])
                } label: {
                    HStack {
                        Text(creating ? (restoring ? "Create Library from Backups" : "Create Library") : "Recover Access")
                        Spacer()
                        if vault.busy { ProgressView() } else { Image(systemName: "arrow.right") }
                    }.frame(minHeight: 44)
                }.disabled(!canContinue)
                if vault.busy && !vault.status.isEmpty { Text(vault.status).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .backupPicker(backupInput)
        .safeAreaInset(edge: .bottom) { Text(AppBrand.name + " " + AppBrand.version).font(.caption).foregroundStyle(.secondary).padding(6).frame(maxWidth: .infinity).background(.bar) }
        .navigationTitle(creating ? "Welcome" : "Recovery").navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(vault.busy)
        .toolbar { ToolbarItem(placement: .cancellationAction) {
            Button(vault.busy ? "Cancel Setup" : "Calculator") { vault.lock(); clearSecrets(); close() }
        } }
        .onChange(of: vault.unlocked) { _, unlocked in if unlocked { clearSecrets() } }
        .onChange(of: vault.generation) { _, _ in clearSecrets() }
        .onChange(of: restoring) { _, value in
            if !value { backups = []; password = ""; backupInput.clearSelection() }
        }
        .alert("Couldn’t Complete", isPresented: Binding(get: { vault.message != nil }, set: { if !$0 { vault.message = nil } })) {
            Button("Close", role: .cancel) { vault.message = nil }
        } message: { Text(vault.message ?? "") }
    }
}
#endif

