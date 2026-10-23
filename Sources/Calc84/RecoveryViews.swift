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
        Form {
            Section("Current Code") { SecureField("Current calculator code", text: $old).keyboardType(.numberPad) }
            Section("New Code") {
                SecureField("6–12 digits", text: $new).keyboardType(.numberPad)
                SecureField("Repeat new code", text: $confirmation).keyboardType(.numberPad)
            }
            Section {
                Button("Change Code") { Task { if await vault.changeCode(old: old, new: new) { dismiss() } } }
                    .disabled(vault.busy || !VaultCode.valid(new) || new != confirmation || old.isEmpty)
            } footer: { Text("160160 is for first-time setup only. Your recovery key and existing backups will not change.") }
        }.navigationTitle("Change Code")
            .onDisappear { old = ""; new = ""; confirmation = "" }
    }
}
struct RecoveryTestView: View {
    @EnvironmentObject private var vault: VaultModel
    @State private var backup: BackupSelection?
    @State private var choosingBackup = false
    @State private var secret = ""
    @State private var passed = false
    var body: some View {
        Form {
            BackupInputSection(backup: $backup, enabled: !vault.busy, working: $choosingBackup)
            Section {
                Text("This decrypts and checks the complete backup in a separate temporary library. Your current library is left in place. You need free space for another encrypted copy.")
                SecureField("Recovery key or original password", text: $secret)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Test Recovery") {
                    if let backup { Task { passed = await vault.verifyBackup(url: backup.url, recovery: secret); secret = "" } }
                }.disabled(backup == nil || secret.isEmpty || vault.busy || choosingBackup)
                if vault.busy { ProgressView("Authenticating backup…") }
                if passed { Label("Recovery test passed", systemImage: "checkmark.shield.fill") }
            }
            Section { LabeledContent(AppBrand.name, value: AppBrand.version) }
        }.navigationTitle("Test a Backup")
            .onChange(of: backup?.url) { _, _ in passed = false }
            .alert("Couldn’t Test Backup", isPresented: Binding(get: { vault.message != nil }, set: { if !$0 { vault.message = nil } })) {
                Button("Close", role: .cancel) { vault.message = nil }
            } message: { Text(vault.message ?? "") }
            .onDisappear { secret = "" }
    }
}
#endif




