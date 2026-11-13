#if os(iOS)
import SwiftUI
import CalcCore
import UniformTypeIdentifiers

struct ChangeCodeView: View {
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    @State private var old = ""
    @State private var new = ""
    @State private var confirmation = ""
    var body: some View {
        ThemedForm {
            Section { Label("Change Calculator Code", systemImage: "lock.rotation").font(.title3.bold()) }.listRowBackground(Color.clear)
            Section("Current Code") { SecureField("Current calculator code", text: $old).keyboardType(.numberPad) }
            Section("New Code") {
                SecureField("6–12 digits", text: $new).keyboardType(.numberPad)
                SecureField("Repeat new code", text: $confirmation).keyboardType(.numberPad)
            }
            Section {
                Button("Save New Code") { Task { if await vault.changeCode(old: old, new: new) { dismiss() } } }
                    .buttonStyle(ImportButtonStyle())
                    .disabled(vault.busy || !VaultCode.valid(new) || new != confirmation || old.isEmpty)
            } footer: { Text("Your photos and backups stay unchanged.") }
        }.navigationTitle("Change Code")
            .onDisappear { old = ""; new = ""; confirmation = "" }
    }
}
struct RecoveryTestView: View {
    @EnvironmentObject private var vault: VaultModel
    @StateObject private var backupInput = BackupInputModel()
    @State private var secret = ""
    @State private var passed = false
    var body: some View {
        ThemedForm {
            SharedBackupSection(input: backupInput)
            BackupInputSection(input: backupInput, enabled: !vault.busy)
            Section {
                Text("Check that this file and recovery key can restore your photos without changing your library. Extra temporary space is required.")
                SecureField("Recovery key or original password", text: $secret)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Check Backup") {
                    if let backup = backupInput.backup { Task { passed = await vault.verifyBackup(url: backup.url, recovery: secret); secret = "" } }
                }.disabled(backupInput.backup == nil || secret.isEmpty || vault.busy || backupInput.working)
                if vault.busy { ProgressView("Authenticating backup…") }
                if passed { Label("Recovery test passed", systemImage: "checkmark.shield.fill") }
            }
            Section { LabeledContent(AppBrand.name, value: AppBrand.version) }
        }.backupPicker(backupInput).navigationTitle("Check a Backup")
            .onChange(of: backupInput.backup?.url) { _, _ in passed = false }
            .alert("Couldn’t Test Backup", isPresented: Binding(get: { vault.message != nil }, set: { if !$0 { vault.message = nil } })) {
                Button("Close", role: .cancel) { vault.message = nil }
            } message: { Text(vault.message ?? "") }
            .onDisappear { secret = "" }
    }
}
#endif




