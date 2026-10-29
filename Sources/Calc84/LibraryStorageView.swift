#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers
import CalcCore

struct LibraryStorageView: View {
    @EnvironmentObject private var vault: VaultModel
    @State private var report: LibraryStorageReport?
    @State private var groups: [DuplicateGroup] = []
    @State private var scanned = false
    @State private var scanning = false
    @State private var scan: Task<Void, Never>?
    @State private var error: String?
    @State private var available: Int64?
    private var active: [VaultItem] { vault.items.filter { $0.visible && $0.deletedAt == nil } }
    private var largest: [VaultItem] { active.sorted { bytes($0) > bytes($1) } }
    private func bytes(_ item: VaultItem) -> Int64 { report?.bytes(for: item) ?? Int64(item.byteCount) }
    private func size(_ value: Int64) -> String { ByteCountFormatter.string(fromByteCount: value, countStyle: .file) }
    var body: some View {
        List {
            Section("On this phone") {
                if let report {
                    LabeledContent("Encrypted library", value: size(report.encryptedBytes))
                    storageRow("Photos", items: active.filter { UTType($0.contentType)?.conforms(to: .image) == true })
                    storageRow("Videos", items: active.filter { UTType($0.contentType)?.conforms(to: .movie) == true })
                    storageRow("Files", items: active.filter { UTType($0.contentType)?.conforms(to: .image) != true && UTType($0.contentType)?.conforms(to: .movie) != true })
                    storageRow("Recently Deleted", items: vault.items.filter { $0.visible && $0.deletedAt != nil })
                    LabeledContent("Private search index", value: size(report.searchBytes))
                } else if error == nil { ProgressView("Measuring library…") }
                if let available { LabeledContent("Phone space available", value: size(available)) }
            }
            Section {
                NavigationLink("Largest Items · \(active.count)") {
                    StorageItemsView(title: "Largest Items", items: largest, bytes: report?.resourceBytes ?? [:])
                }
                NavigationLink("Recently Deleted") {
                    StorageItemsView(title: "Recently Deleted", items: vault.items.filter { $0.visible && $0.deletedAt != nil }, bytes: report?.resourceBytes ?? [:], deleted: true)
                }
            } footer: { Text("Sizes include encrypted originals, Live Photo motion and previews. Recently Deleted still uses space until you explicitly remove those copies permanently.") }
            Section {
                if scanning {
                    ProgressView("Comparing original files…")
                    Button("Cancel Scan") { scan?.cancel() }
                } else {
                    Button(scanned ? "Scan Again for Exact Duplicates" : "Find Exact Duplicates", systemImage: "square.on.square") { findDuplicates() }.disabled(vault.busy)
                }
                if scanned {
                    if groups.isEmpty { Text("No exact duplicates found.").foregroundStyle(.secondary) }
                    ForEach(Array(groups.enumerated()), id: \.element.id) { number, group in
                        NavigationLink("Group \(number + 1) · \(group.ids.count) copies") {
                            StorageItemsView(title: "Duplicate Copies", items: active.filter { group.ids.contains($0.id) }, bytes: report?.resourceBytes ?? [:])
                        }
                    }
                }
            } header: { Text("Review duplicates") } footer: { Text("Checks authenticated originals, including Live Photo motion. Similar-looking photos are not treated as duplicates. Nothing is selected or deleted automatically.") }
            Section("Before your next backup") {
                StorageEstimateView(bytes: vault.items.reduce(Int64(0)) { $0 + Int64($1.byteCount) }, copies: 2)
                NavigationLink("Open Backup Center") { BackupSettingsView() }
            }
            if let error { Section { Text(error).foregroundStyle(.secondary); Button("Retry Measurement") { Task { await refresh() } } } }
        }.navigationTitle("Storage").navigationBarTitleDisplayMode(.inline)
            .task { await refresh() }
            .onChange(of: vault.items) { _, _ in scanned = false; groups = []; Task { await refresh() } }
            .onDisappear { scan?.cancel() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in scan?.cancel() }
    }
    private func storageRow(_ title: String, items: [VaultItem]) -> some View {
        LabeledContent(title, value: size(items.reduce(0) { $0 + bytes($1) }))
    }
    private func refresh() async {
        let generation = vault.generation
        do {
            let value = try await vault.engine.storageReport()
            guard vault.unlocked, vault.generation == generation, !Task.isCancelled else { return }
            report = value; available = try StoragePreflight.available(); error = nil
        } catch { if vault.unlocked, vault.generation == generation { self.error = error.localizedDescription } }
    }
    private func findDuplicates() {
        guard vault.unlocked, !vault.busy, !scanning else { return }
        vault.textSearch.pause(); scanning = true; vault.busy = true; scanned = false
        let generation = vault.generation
        scan = Task {
            defer { scanning = false; vault.busy = false; scan = nil }
            do {
                let result = try await vault.engine.duplicates()
                try Task.checkCancellation()
                guard vault.unlocked, vault.generation == generation else { return }
                groups = result; scanned = true
            } catch { if !Task.isCancelled, vault.unlocked, vault.generation == generation { self.error = error.localizedDescription } }
        }
    }
}

private struct StorageItemsView: View {
    @EnvironmentObject private var vault: VaultModel
    let title: String
    let items: [VaultItem]
    let bytes: [UUID: Int64]
    var deleted = false
    @State private var selected = Set<UUID>()
    @State private var confirm = false
    @State private var preview: VaultItem?
    private var current: [VaultItem] {
        let ids = Set(items.map(\.id))
        return vault.items.filter { ids.contains($0.id) && $0.visible && ($0.deletedAt != nil) == deleted }
            .sorted { storedBytes($0) > storedBytes($1) }
    }
    private func storedBytes(_ item: VaultItem) -> Int64 {
        [item.id, item.companionID, item.thumbnailID].compactMap { $0 }.reduce(0) { $0 + (bytes[$1] ?? 0) }
    }
    var body: some View {
        List {
            Section {
                Text("Choose the copies you want to remove. Tap a preview to inspect it first.").font(.footnote).foregroundStyle(.secondary)
                ForEach(current) { item in
                    HStack(spacing: 12) {
                        Button { preview = item } label: {
                            LibraryThumbnail(item: item, engine: vault.engine).frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.borderless).accessibilityLabel("Preview \(item.name)")
                        Toggle(isOn: Binding(get: { selected.contains(item.id) }, set: { if $0 { selected.insert(item.id) } else { selected.remove(item.id) } })) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name).lineLimit(2)
                                Text(ByteCountFormatter.string(fromByteCount: storedBytes(item), countStyle: .file)).font(.caption).foregroundStyle(.secondary)
                                if !item.albumNames.isEmpty { Text(item.albumNames.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
            }
            if !selected.isEmpty {
                Section {
                    if deleted { Button("Restore Selected") { Task { await vault.updateMany(current.filter { selected.contains($0.id) }, deleted: false); selected = [] } } }
                    Button(deleted ? "Delete Selected Permanently" : "Move Selected to Recently Deleted", role: .destructive) { confirm = true }
                }.disabled(vault.busy)
            }
        }.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .sheet(item: $preview) { item in StorageMediaPreview(items: current, initial: item.id) }
            .confirmationDialog(deleted ? "Permanently delete \(selected.count) copies?" : "Move \(selected.count) copies to Recently Deleted?", isPresented: $confirm, titleVisibility: .visible) {
                Button(deleted ? "Delete Permanently" : "Move to Recently Deleted", role: .destructive) {
                    Task { await vault.updateMany(current.filter { selected.contains($0.id) }, deleted: true, permanently: deleted); selected = [] }
                }
            } message: { Text(deleted ? "This frees their local storage. Older backups and exported copies remain unchanged." : "You can restore these copies from Recently Deleted. Space is freed only after permanent deletion.") }
    }
}

private struct StorageMediaPreview: View {
    let items: [VaultItem]
    let initial: UUID
    @Environment(\.dismiss) private var dismiss
    @StateObject private var previews = MediaPreviewStore()
    var body: some View {
        MediaBrowser(items: items, initial: initial, previews: previews, close: { dismiss() }, didShow: { _ in })
            .onDisappear { previews.clear() }
    }
}
#endif
