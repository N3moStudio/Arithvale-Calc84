#if os(iOS)
import SwiftUI
import CalcCore

struct BackupReminderView: View {
    @Environment(\.arithenTheme) private var theme
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.scenePhase) private var scene
    @Environment(\.dynamicTypeSize) private var textSize
    @AppStorage("privateBackupReminders") private var enabled = true
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
                HStack(alignment: .top, spacing: 6) {
                    Button(action: open) {
                        HStack(alignment: .top, spacing: 8) {
                            if !textSize.isAccessibilitySize {
                                Image(systemName: "externaldrive.badge.exclamationmark")
                                    .font(.system(size: 18)).padding(.top, 3)
                            }
                            // Accessibility text gets the available width instead
                            // of competing with a scaled Label icon and close glyph.
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Time for a backup").font(.subheadline.weight(.semibold))
                                Text("Save changes to Files.").font(.caption)
                                    .foregroundStyle(ArithenPalette.color(.muted, theme: theme))
                            }.multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.buttonStyle(.plain).accessibilityIdentifier("backup.reminder.open")
                    Button("Remind Me Tomorrow", systemImage: "xmark") {
                        snoozed = Date().addingTimeInterval(24 * 60 * 60).timeIntervalSince1970
                    }.labelStyle(.iconOnly).font(.system(size: 17, weight: .medium))
                        .frame(width: 44, height: 44)
                        .accessibilityShowsLargeContentViewer { Label("Remind Me Tomorrow", systemImage: "xmark") }
                }.padding(10).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 14).padding(.bottom, 8)
            }
        }.onAppear { now = Date() }
            .onChange(of: scene) { _, phase in if phase == .active { now = Date() } }
            .onChange(of: changed) { _, _ in now = Date() }
    }
}
#endif
