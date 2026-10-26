#if os(iOS)
import SwiftUI
import CalcCore

struct AboutView: View {
    @EnvironmentObject private var vault: VaultModel
    var body: some View {
        List {
            Section { ArithenIdentity() }
            Section("Storage") {
                LabeledContent("Originals and resources", value: ByteCountFormatter.string(fromByteCount: vault.items.reduce(0) { $0 + Int64($1.byteCount) }, countStyle: .file))
                LabeledContent("Stored resources", value: "\(vault.items.count) / \(VaultLimits.itemCount)")
                Text("Thumbnails and Live Photo videos each count as a resource. Keep a checked backup and its recovery key outside this app.")
            }
            Section("Help") {
                Link("Support & source", destination: AppBrand.support)
                NavigationLink("Recovery guide") {
                    ScrollView { Text("Open with your code and hold =. On a fresh install use 160160, then choose Files or Cloud Recovery. Use the recovery key belonging to that backup. Save and test an external backup before updating or removing the app. Existing Calc 84 libraries and .c84backup files remain compatible.").padding() }.navigationTitle("Recovery Guide")
                }
                NavigationLink("Privacy") {
                    ScrollView { Text("Arithen encrypts its local library. There is no developer account or analytics. Optional backups send encrypted files to your own MEGA or Blomp account. Those services receive account and connection information under their own policies. Exported originals are ordinary files and may include location. The app does not block screenshots. Your recovery key cannot be reset by the developer.").padding() }.navigationTitle("Privacy")
                }
                NavigationLink("Third-party notices") { NoticesView() }
            }
        }.navigationTitle("About").navigationBarTitleDisplayMode(.inline)
    }
}
private struct NoticesView: View {
    private var notices: String {
        guard let root = Bundle.module.resourceURL,
              let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return "Notices are included with the source distribution." }
        return enumerator.compactMap { $0 as? URL }.filter { ["txt", "md"].contains($0.pathExtension) }
            .sorted { $0.path < $1.path }.compactMap { url in (try? String(contentsOf: url, encoding: .utf8)).map { url.lastPathComponent + "\n\n" + $0 } }.joined(separator: "\n\n")
    }
    var body: some View { ScrollView { Text(notices).font(.footnote).textSelection(.enabled).padding() }.navigationTitle("Notices") }
}
#endif
