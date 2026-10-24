#if os(iOS)
import SwiftUI
import CalcCore

struct CloudPolicySection: View {
    let provider: CloudProvider
    @EnvironmentObject private var vault: VaultModel
    private var policy: CloudBackupPolicy { vault.cloudPreferences[provider] }
    var body: some View {
        Section {
            Picker("Upload mode", selection: Binding(get: { policy.mode }, set: { mode in
                var next = policy; next.mode = mode
                Task { _ = await vault.saveCloudPolicy(next, provider: provider) }
            })) {
                Text("Manual selection").tag(CloudBackupPolicy.Mode.manual)
                Text("Automatic · all eligible").tag(CloudBackupPolicy.Mode.automatic)
            }
            if policy.mode == .manual {
                NavigationLink("Choose Items · \(policy.selected.subtracting(policy.blocked).count)") {
                    CloudSelectionView(provider: provider, blocking: false)
                }
            }
            NavigationLink("Never Upload · \(policy.blocked.count)") {
                CloudSelectionView(provider: provider, blocking: true)
            }
            Text("\(policy.itemIDs(in: vault.items).count) eligible items").foregroundStyle(.secondary)
        } header: { Text("What goes to " + provider.title) } footer: {
            Text("Manual: choose items, then tap Back Up. Automatic: back up all eligible items after changes while open and unlocked. Never Upload overrides either mode. Blocks apply to these library items, not separate copies imported later. Recently Deleted is excluded. Older cloud backups are not erased. Files backups still contain the full library.")
        }.disabled(vault.busy)
    }
}

struct CloudSelectionView: View {
    let provider: CloudProvider
    let blocking: Bool
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var selection: Set<UUID> = []
    @State private var loaded = false
    private var choices: [VaultItem] {
        vault.items.filter { $0.visible && $0.deletedAt == nil
            && (blocking || !vault.cloudPreferences[provider].blocked.contains($0.id)) }
    }
    var body: some View {
        VStack(spacing: 12) {
            Text(blocking ? "Checked items will never be included in future \(provider.title) uploads unless you unblock them." : "Check the items to include in \(provider.title) backups. New imports stay unselected.")
                .font(.subheadline).foregroundStyle(.secondary).padding(.horizontal)
            HStack {
                Text("\(selection.count) selected").font(.headline)
                Spacer()
                Menu("Selection") {
                    Button("Select All") { selection.formUnion(choices.map(\.id)) }
                    Button("Clear Visible Selection") { selection.subtract(choices.map(\.id)) }
                }.frame(minHeight: 44)
            }.padding(.horizontal)
            if choices.isEmpty {
                ContentUnavailableView("No eligible items", systemImage: "photo.on.rectangle",
                    description: Text("Import items first. Items blocked for this provider are hidden from manual selection."))
            } else {
                MemoryGrid(sections: LibraryPresentation.sections(choices, source: .captured, newestFirst: true, component: .month),
                    engine: vault.engine, columns: textSize.isAccessibilitySize ? 2 : 4, style: .contactSheet, grouping: "Months",
                    selection: selection, selecting: true, busy: vault.busy, setSelection: { selection = $0 },
                    identity: provider.rawValue + String(blocking), open: { item in
                        if !selection.insert(item.id).inserted { selection.remove(item.id) }
                    }, action: { _, _ in })
            }
            Text("Tap or drag across items. Changes take effect when you tap Save.").font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
        }
        .navigationTitle(blocking ? "Never Upload" : "Choose Items").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    var policy = vault.cloudPreferences[provider]
                    if blocking { policy.blocked = selection; policy.selected.subtract(selection) }
                    else { policy.selected = selection.subtracting(policy.blocked) }
                    Task { if await vault.saveCloudPolicy(policy, provider: provider) { dismiss() } }
                }.disabled(vault.busy || !loaded)
            }
        }
        .disabled(vault.busy)
        .onAppear {
            guard !loaded else { return }
            let policy = vault.cloudPreferences[provider]
            selection = blocking ? policy.blocked : policy.selected.subtracting(policy.blocked)
            loaded = true
        }
    }
}

/// Apply the gallery's existing drag selection to one or both provider policies.
struct CloudBatchSelectionView: View {
    let ids: Set<UUID>
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    @State private var status = ""
    var body: some View {
        NavigationStack {
            List {
                Section { Text("\(ids.count) selected items").font(.headline) }
                ForEach(CloudProvider.allCases) { provider in
                    Section(provider.title) {
                        Button("Add to Manual Selection") { apply(provider, action: 0) }
                        Button("Remove from Manual Selection") { apply(provider, action: 1) }
                        Button("Never Upload These Items", role: .destructive) { apply(provider, action: 2) }
                        Button("Unblock These Items") { apply(provider, action: 3) }
                    }
                }
                if !status.isEmpty { Section { Text(status) } }
                Section { Text("Adding to manual selection does not change the provider’s upload mode or remove blocks. Unblocking makes items eligible immediately in automatic mode. Older cloud backups remain. Manage mode and upload in Settings → Backup & Recovery → MEGA & Blomp.") }
            }
            .disabled(vault.busy)
            .navigationTitle("Cloud Choices").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(vault.busy) } }
        }.interactiveDismissDisabled(vault.busy)
    }
    private func apply(_ provider: CloudProvider, action: Int) {
        var policy = vault.cloudPreferences[provider]
        switch action {
        case 0: policy.selected.formUnion(ids.subtracting(policy.blocked))
        case 1: policy.selected.subtract(ids)
        case 2: policy.blocked.formUnion(ids); policy.selected.subtract(ids)
        default: policy.blocked.subtract(ids)
        }
        Task { if await vault.saveCloudPolicy(policy, provider: provider) { status = provider.title + " choices saved." } }
    }
}
#endif
