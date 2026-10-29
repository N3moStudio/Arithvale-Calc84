#if os(iOS)
import SwiftUI
import CalcCore

struct BackupReminderView: View {
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.scenePhase) private var scene
    @AppStorage("privateBackupReminders") private var enabled = false
    @AppStorage("libraryNeedsBackup") private var changed = true
    @AppStorage("lastEncryptedExport") private var saved = 0.0
    @AppStorage("backupReminderSnoozedUntil") private var snoozed = 0.0
    @State private var now = Date()
    let open: () -> Void
    private var due: Bool {
        LibraryEfficiency.needsReminder(enabled: enabled, unlocked: vault.unlocked,
            hasItems: vault.items.contains { $0.visible && $0.deletedAt == nil }, changed: changed,
            now: now, lastBackup: saved > 0 ? Date(timeIntervalSince1970: saved) : nil,
            snoozedUntil: snoozed > 0 ? Date(timeIntervalSince1970: snoozed) : nil)
    }
    var body: some View {
        Group {
            if due && !vault.busy {
                HStack {
                    Button(action: open) {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Time for a backup").font(.subheadline.weight(.semibold))
                                Text("Library changes need a new Files backup.").font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "externaldrive.badge.exclamationmark") }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.buttonStyle(.plain)
                    Button("Remind Me Tomorrow", systemImage: "xmark") {
                        snoozed = Date().addingTimeInterval(24 * 60 * 60).timeIntervalSince1970
                    }.labelStyle(.iconOnly).frame(width: 44, height: 44)
                }.padding(10).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 14).padding(.bottom, 8)
            }
        }.onAppear { now = Date() }
            .onChange(of: scene) { _, phase in if phase == .active { now = Date() } }
            .onChange(of: changed) { _, _ in now = Date() }
    }
}
#endif
