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
    }
}

private struct AccessView: View {
    @EnvironmentObject private var vault: VaultModel
    let close: () -> Void
    @State private var recovery = VaultCode.generateRecovery()
    @State private var password = ""
    @State private var code = ""
    @State private var confirmation = ""
    @State private var recoveryConfirmation = ""
    @State private var saved = false
    @State private var restoring = false
    @State private var backup: URL?
    @State private var picker = false
    private var creating: Bool { !vault.exists && !restoring }
    private var canContinue: Bool {
        !vault.busy && VaultCode.valid(code) && code == confirmation
        && (creating ? (saved && recoveryConfirmation.uppercased() == String(VaultCode.normalizeRecovery(recovery).suffix(8))) : !password.isEmpty)
        && (!restoring || backup != nil)
    }
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "lock.square.stack").font(.system(size: 40, weight: .medium))
                        .foregroundStyle(CalcTheme.accent).accessibilityHidden(true)
                    Text(creating ? "A space of your own." : "Bring your library back.").font(.largeTitle.bold())
                    Text(creating ? "Your calculator code opens this phone. Your recovery key brings your files back on another."
                         : "Use your recovery key, or the password from Calc 84 version 0.1. Your existing files won’t be replaced.")
                        .foregroundStyle(.secondary)
                }.padding(.vertical, 12)
            }
            if !vault.exists {
                Section {
                    Toggle("Restore an Existing Backup", isOn: $restoring)
                        .disabled(vault.busy)
                    NavigationLink {
                        CloudBackupView(restoring: true)
                    } label: { Label("Restore from Cloud", systemImage: "icloud.and.arrow.down") }.disabled(vault.busy)
                }
            }
            if restoring {
                Section("Encrypted Backup") {
                    Button(backup == nil ? "Choose Backup" : "Choose a Different Backup", systemImage: "folder") { picker = true }
                    if let backup { Text(backup.lastPathComponent).font(.footnote).foregroundStyle(.secondary) }
                }
            }
            Section(creating ? "Save Your Recovery Key" : "Recovery Secret") {
                if creating {
                    Text(recovery).font(.body.monospaced()).textSelection(.enabled)
                    Text("Store this separately from your backup. We cannot reset it. Don’t keep your only copy inside this app.")
                        .foregroundStyle(.secondary)
                    Toggle("I Saved My Key Somewhere Safe", isOn: $saved)
                    TextField("Confirm the last 8 characters", text: $recoveryConfirmation)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .accessibilityLabel("Last eight recovery key characters")
                } else {
                    SecureField("Recovery key or original password", text: $password)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
            }
            Section {
                SecureField("New calculator code", text: $code).keyboardType(.numberPad)
                SecureField("Repeat calculator code", text: $confirmation).keyboardType(.numberPad)
            } header: { Text("Calculator Code") } footer: {
                Text("Choose 6–12 digits. Type them in the calculator and press =. The starter code 160160 cannot protect an imported library.")
            }
            Section {
                Button {
                    vault.open(password: creating ? recovery : password, code: code, creating: creating, backup: restoring ? backup : nil)
                } label: {
                    HStack {
                        Text(creating ? "Create Library" : restoring ? "Restore Library" : "Recover Access")
                        Spacer()
                        if vault.busy { ProgressView() } else { Image(systemName: "arrow.right") }
                    }.frame(minHeight: 44)
                }.disabled(!canContinue)
            }
        }
        .navigationTitle(creating ? "Welcome" : "Recovery").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Calculator", action: close) } }
        .fileImporter(isPresented: $picker, allowedContentTypes: [.data]) {
            do { backup = try $0.get() } catch { vault.message = error.localizedDescription }
        }
        .onDisappear { password = ""; code = ""; confirmation = ""; recovery = ""; recoveryConfirmation = "" }
        .alert("Couldn’t Complete", isPresented: Binding(get: { vault.message != nil }, set: { if !$0 { vault.message = nil } })) {
            Button("Close", role: .cancel) { vault.message = nil }
        } message: { Text(vault.message ?? "") }
    }
}
#endif

