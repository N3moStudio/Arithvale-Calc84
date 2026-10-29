#if os(iOS)
import SwiftUI
import CalcCore

struct AlbumTagEditor: View {
    @EnvironmentObject private var vault: VaultModel
    let ids: Set<UUID>
    let close: () -> Void
    @State private var mode = OrganizationMode.add
    @State private var chosen = Set<String>()
    @State private var newAlbum = ""
    @State private var tags = ""
    private var names: [String] { Set(vault.items.filter(\.visible).flatMap(\.albumNames) + Array(vault.albumPreferences.keys)).sorted() }
    private var selected: [VaultItem] { vault.items.filter { ids.contains($0.id) } }
    private var albumsToApply: [String] { LibraryOrganization.names(chosen.sorted() + [newAlbum]) }
    private var tagsToApply: [String] { LibraryOrganization.names(tags.components(separatedBy: ","), limit: 64) }
    var body: some View {
        Form {
            Section {
                Picker("Action", selection: $mode) {
                    Text("Add").tag(OrganizationMode.add)
                    Text("Remove").tag(OrganizationMode.remove)
                }.pickerStyle(.segmented)
                Text("\(ids.count) selected. A photo can be in several albums without another copy.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Albums") {
                TextField(mode == .add ? "New album name" : "Album name", text: $newAlbum)
                ForEach(names, id: \.self) { name in
                    Toggle(isOn: Binding(get: { chosen.contains(name) }, set: { if $0 { chosen.insert(name) } else { chosen.remove(name) } })) {
                        VStack(alignment: .leading) {
                            Text(name)
                            Text("\(selected.filter { $0.albumNames.contains(name) }.count) selected items already here")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section {
                TextField("Tags, separated by commas", text: $tags).textInputAutocapitalization(.never)
                let existing = Set(selected.flatMap { $0.tags ?? [] }).sorted()
                if !existing.isEmpty { Text("Current: " + existing.joined(separator: ", ")).font(.footnote).foregroundStyle(.secondary) }
            } header: { Text("Tags") } footer: { Text("For example: travel, receipt, school. Albums and tags stay inside encrypted backups. Up to 24 albums and 32 tags per item.") }
        }.navigationTitle("Albums & Tags").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: close) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .add ? "Add" : "Remove") {
                        Task { if await vault.organize(ids: ids, albums: albumsToApply, tags: tagsToApply, mode: mode) { close() } }
                    }.disabled(vault.busy || (albumsToApply.isEmpty && tagsToApply.isEmpty))
                }
            }
            .alert("Couldn’t Organize", isPresented: Binding(get: { vault.message != nil }, set: { if !$0 { vault.message = nil } })) {
                Button("Close", role: .cancel) { vault.message = nil }
            } message: { Text(vault.message ?? "") }
    }
}

struct AlbumCustomizationView: View {
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    let name: String
    @State private var pinned: Bool
    @State private var cover: UUID?
    init(name: String, preference: AlbumPreference) {
        self.name = name; _pinned = State(initialValue: preference.pinned); _cover = State(initialValue: preference.coverID)
    }
    private var items: [VaultItem] { vault.items.filter { $0.visible && $0.deletedAt == nil && $0.albumNames.contains(name) } }
    var body: some View {
        Form {
            Section { Toggle("Pin Album", isOn: $pinned) }
            Section {
                Button { cover = nil } label: {
                    HStack { Text("Automatic Collage"); Spacer(); if cover == nil { Image(systemName: "checkmark") } }
                }
                ForEach(items) { item in
                    Button { cover = item.id } label: {
                        HStack {
                            LibraryThumbnail(item: item, engine: vault.engine).frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(item.name).foregroundStyle(.primary).lineLimit(2)
                            Spacer()
                            if cover == item.id { Image(systemName: "checkmark") }
                        }
                    }.accessibilityLabel("Use \(item.name) as album cover")
                }
            } header: { Text("Album cover") } footer: { Text("Only items in this album can be its cover. A deleted cover falls back to the collage.") }
        }.navigationTitle(name).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { if await vault.setAlbumPreference(.init(pinned: pinned, coverID: cover), name: name) { dismiss() } } }.disabled(vault.busy)
                }
            }
            .alert("Couldn’t Save Album", isPresented: Binding(get: { vault.message != nil }, set: { if !$0 { vault.message = nil } })) {
                Button("Close", role: .cancel) { vault.message = nil }
            } message: { Text(vault.message ?? "") }
    }
}
#endif
