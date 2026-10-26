#if os(iOS)
import SwiftUI
import CalcCore

struct NewRecoveryKeySection: View {
    @Binding var setup: SetupSession
    var body: some View {
        Section("Save Your New Recovery Key") {
            Text(setup.recovery).font(.body.monospaced()).textSelection(.enabled)
                .accessibilityIdentifier("setup.newRecoveryKey")
            Text("Use this new key for every backup you make from this library. A source backup’s old key only opens the old backup. Save this separately; it cannot be shown again after setup.")
                .font(.footnote).foregroundStyle(.secondary)
            Toggle("I Saved My New Key Somewhere Safe", isOn: $setup.saved)
                .accessibilityIdentifier("setup.savedRecoveryKey")
            TextField("Confirm the last 8 characters", text: $setup.confirmation)
                .textInputAutocapitalization(.characters).autocorrectionDisabled()
                .accessibilityLabel("Last eight characters of the new recovery key")
                .accessibilityIdentifier("setup.confirmRecoveryKey")
        }
    }
}

/// Own the encrypted temporary copy until setup finishes. Keys stay in memory.
struct QueuedSetupBackup: Identifiable {
    let id = UUID()
    let backup: BackupSelection
    let recovery: String
    var source: SetupBackupSource { .init(url: backup.url, recovery: recovery) }
}
#endif
