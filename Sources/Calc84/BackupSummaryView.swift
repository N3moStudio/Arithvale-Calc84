#if os(iOS)
import SwiftUI
import CalcCore

struct BackupSummaryView: View {
    @EnvironmentObject private var cloud: CloudBackupModel
    @AppStorage("lastEncryptedExport") private var lastExport = 0.0
    @AppStorage("libraryNeedsBackup") private var needsBackup = true
    private var destinations: [BackupDestinationStatus] {
        [.init(name: "Files", saved: lastExport > 0 ? Date(timeIntervalSince1970: lastExport) : nil, needsBackup: needsBackup)]
        + CloudProvider.allCases.map { provider in
            .init(name: provider.title + " selection", saved: cloud.receipts[provider]?.saved,
                  needsBackup: cloud.receipts[provider]?.needsBackup ?? true, connected: cloud.connected.contains(provider))
        }
    }
    var body: some View {
        Label(BackupStatus.summary(destinations), systemImage: destinations.contains(where: \.current) ? "checkmark.shield" : "externaldrive")
            .onAppear { cloud.refresh() }
    }
}
#endif
