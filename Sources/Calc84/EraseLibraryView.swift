#if os(iOS)
import SwiftUI

struct EraseLibraryView: View {
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmation = ""
    @State private var confirming = false
    var body: some View {
        ThemedForm {
            Section {
                Text("Permanently erase this library’s photos, videos and albums. They cannot be recovered here. External backups and originals are not deleted.")
                Text("Then create an empty vault with a new recovery key and calculator code.")
            }
            Section("Type ERASE to continue") {
                TextField("ERASE", text: $confirmation)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                Button("Erase and Start Over", role: .destructive) { confirming = true }
                    .disabled(confirmation != "ERASE" || vault.busy)
                if vault.busy { ProgressView("Erasing…") }
            }
        }.navigationTitle("Erase Library").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Permanently erase this library?", isPresented: $confirming, titleVisibility: .visible) {
                Button("Erase Library Permanently", role: .destructive) {
                    Task { if await vault.eraseLockedLibrary(confirmation: confirmation) { dismiss() } }
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text("All photos in this installation will be lost. This cannot be undone.") }
            .onDisappear { confirmation = ""; confirming = false }
    }
}
#endif
