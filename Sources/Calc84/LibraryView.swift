#if os(iOS)
import SwiftUI
import CalcCore
import PhotosUI
#if canImport(_PhotosUI_SwiftUI)
import _PhotosUI_SwiftUI
#endif
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dynamicTypeSize) private var textSize
    @AppStorage("libraryLayout") private var layout = LibraryLayout.timeline.rawValue
    @AppStorage("libraryDateSource") private var dateSource = LibraryDateSource.captured.rawValue
    @AppStorage("libraryNewestFirst") private var newestFirst = true
    // Start the new gallery at four without rewriting the old grid preference.
    @AppStorage("memoryGridColumns") private var columns = 4
    @AppStorage("lastEncryptedExport") private var lastExport = 0.0
    @AppStorage("libraryNeedsBackup") private var needsBackup = true
    let close: () -> Void
    @State private var photos: [PhotosPickerItem] = []
    @State private var files = false
    @State private var selected: VaultItem?
    @State private var settings = false
    @State private var filter = "All"
    @State private var search = ""
    @State private var searching = false
    @State private var period = "Months"
    @State private var selecting = false
    @State private var selection = Set<UUID>()
    @State private var deletion = false
    @State private var albumSheet = false
    @State private var albumName = ""
    @State private var exportItems: [VaultItem] = []
    @State private var showingExports = false
    private var timeline: Bool { layout == LibraryLayout.timeline.rawValue }
    private var albums: [String] { Array(Set(vault.items.filter { $0.visible && $0.deletedAt == nil }.compactMap(\.album).filter { !$0.isEmpty })).sorted() }
    private var visible: [VaultItem] {
        vault.items.filter { item in
            guard item.visible, (filter == "Recently Deleted" ? item.deletedAt != nil : item.deletedAt == nil) else { return false }
            if !search.isEmpty && !item.name.localizedCaseInsensitiveContains(search) && !(item.album?.localizedCaseInsensitiveContains(search) ?? false) { return false }
            switch filter {
            case "Photos": return UTType(item.contentType)?.conforms(to: .image) == true
            case "Videos": return UTType(item.contentType)?.conforms(to: .movie) == true
            case "Favorites": return item.favorite == true
            case "All", "Recently Deleted": return true
            default: return filter.hasPrefix("album:") && item.album == String(filter.dropFirst(6))
            }
        }
    }
    private var sections: [LibrarySection] {
        LibraryPresentation.sections(visible, source: LibraryDateSource(rawValue: dateSource) ?? .captured,
            newestFirst: newestFirst, component: timeline ? .month : period == "Years" ? .year : period == "Days" ? .day : .month)
    }
    private var selectedItems: [VaultItem] { visible.filter { selection.contains($0.id) } }
    var body: some View {
        VStack(spacing: 0) {
            header
            if searching {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search names or albums", text: $search).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Clear", systemImage: "xmark.circle.fill") { search = "" }.labelStyle(.iconOnly).frame(width: 44, height: 44)
                }.padding(.leading, 14).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16).padding(.bottom, 8)
            }
            filters
            HStack(spacing: 6) {
                Text(selecting ? "\(selection.count) selected" : "\(visible.count) items").fontWeight(.semibold)
                Spacer()
                Button { settings = true } label: {
                    Label(lastExport == 0 ? "Back up" : needsBackup ? "Back up changes" : "Backup saved", systemImage: lastExport == 0 || needsBackup ? "externaldrive" : "checkmark.shield")
                        .font(.caption.weight(.semibold)).multilineTextAlignment(.trailing).frame(minHeight: 44)
                }.disabled(vault.busy)
            }.font(.subheadline).padding(.horizontal, 16)
            if !timeline {
                Picker("Browse by", selection: $period) {
                    ForEach(["Years", "Months", "Days"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.segmented).padding(.horizontal, 16).padding(.bottom, 8)
            }
            if vault.busy {
                HStack(spacing: 10) { ProgressView(); Text(vault.status.isEmpty ? "Working…" : vault.status).font(.footnote) }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Color(uiColor: .secondarySystemBackground))
            }
            if visible.isEmpty {
                Spacer()
                ContentUnavailableView(search.isEmpty ? (filter == "Recently Deleted" ? "Nothing Deleted" : "Your memories go here") : "No matches",
                    systemImage: filter == "Recently Deleted" ? "trash" : "photo.on.rectangle",
                    description: Text(search.isEmpty ? (filter == "Recently Deleted" ? "Deleted items stay here until you remove them permanently." : "Tap Import to add photos or videos. Your originals stay where they are.") : "Try another name or album."))
                Spacer()
            } else {
                MemoryGrid(sections: sections, engine: vault.engine, columns: textSize.isAccessibilitySize ? 2 : columns,
                    portrait: timeline, grouping: timeline ? "Months" : period, selection: selection, selecting: selecting,
                    identity: filter + "|" + search + "|" + dateSource + "|" + String(newestFirst), open: open, action: itemAction)
            }
            Divider()
            actionBar
        }
        .background(Color(uiColor: .systemBackground)).tint(.primary)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $settings) { NavigationStack { VaultSettingsView().environmentObject(vault) } }
        .sheet(item: $selected) { FilePreview(item: $0).environmentObject(vault) }
        .sheet(isPresented: $showingExports) { ExportMediaView(items: exportItems).environmentObject(vault) }
        .sheet(isPresented: $albumSheet) { albumEditor }
        .sheet(item: $vault.photoImportReview) { PhotoImportReviewView(review: $0).environmentObject(vault) }
        .fileImporter(isPresented: $files, allowedContentTypes: [.item], allowsMultipleSelection: true) {
            do { vault.importFiles(try $0.get()) } catch { vault.message = error.localizedDescription }
        }
        .onChange(of: photos) { _, value in if !value.isEmpty { vault.importPhotos(value); photos = [] } }
        .onChange(of: search) { _, _ in selection = [] }
        .onChange(of: vault.items) { _, _ in selection.formIntersection(Set(visible.map(\.id))) }
        .confirmationDialog(filter == "Recently Deleted" ? "Permanently Delete Selected Items?" : "Move to Recently Deleted?",
            isPresented: $deletion, titleVisibility: .visible) {
            Button(filter == "Recently Deleted" ? "Delete Permanently" : "Move to Recently Deleted", role: .destructive) {
                let chosen = selectedItems
                Task { await vault.updateMany(chosen, deleted: true, permanently: filter == "Recently Deleted"); selection = []; selecting = false }
            }
        } message: { Text(filter == "Recently Deleted" ? "This removes these local copies. Older backups and exported originals keep theirs." : "Restore them from Albums → Recently Deleted. Nothing is automatically erased.") }
        .onDisappear { selected = nil; photos = []; selection = []; search = "" }
        .alert("Couldn’t Complete", isPresented: Binding(get: { !settings && vault.photoImportReview == nil && vault.message != nil }, set: { if !$0 { vault.message = nil } })) {
            Button("Close", role: .cancel) { vault.message = nil }
        } message: { Text(vault.message ?? "") }
    }
    private var header: some View {
        HStack(spacing: 6) {
            Button("Lock and return to Calculator", systemImage: "chevron.down", action: close)
                .labelStyle(.iconOnly).font(.title2.weight(.semibold)).frame(width: 44, height: 48)
            Text("Memories").font(.title2.bold()).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Button("Search", systemImage: searching ? "xmark" : "magnifyingglass") { searching.toggle(); if !searching { search = "" } }
                .labelStyle(.iconOnly).font(.title2).frame(width: 44, height: 48)
            Button(selecting ? "Done" : "Select") { selecting.toggle(); selection = [] }
                .font(.subheadline.bold()).padding(.horizontal, 14).frame(minHeight: 44)
                .background(Color(uiColor: .secondarySystemBackground), in: Capsule()).disabled(vault.busy || visible.isEmpty)
        }.padding(.leading, 4).padding(.trailing, 12).padding(.vertical, 8)
    }
    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 22) {
                ForEach(["All", "Photos", "Videos", "Favorites"], id: \.self) { value in
                    Button { filter = value; selection = [] } label: {
                        Text(value).font(.headline).foregroundStyle(filter == value ? .primary : .secondary).frame(minHeight: 44)
                            .overlay(alignment: .bottom) { if filter == value { Capsule().frame(height: 3) } }
                    }.accessibilityAddTraits(filter == value ? .isSelected : [])
                }
                Menu {
                    ForEach(albums, id: \.self) { name in Button(name) { filter = "album:" + name; selection = [] } }
                    Divider()
                    Button("Recently Deleted", systemImage: "trash") { filter = "Recently Deleted"; selection = [] }
                } label: {
                    Text(filter.hasPrefix("album:") ? String(filter.dropFirst(6)) : filter == "Recently Deleted" ? "Recently Deleted" : "Albums")
                        .font(.headline).frame(minHeight: 44)
                        .overlay(alignment: .bottom) { if filter.hasPrefix("album:") || filter == "Recently Deleted" { Capsule().frame(height: 3) } }
                }
            }.padding(.horizontal, 16)
        }.overlay(alignment: .bottom) { Divider() }
    }
    private var actionBar: some View {
        HStack(spacing: 12) {
            if selecting {
                Menu {
                    Button("Select All") { selection = Set(visible.map(\.id)) }
                    Button("Deselect All") { selection = [] }
                } label: { Label("Selection", systemImage: "checkmark.circle").labelStyle(.iconOnly).frame(width: 44, height: 44) }
                if filter == "Recently Deleted" {
                    Button("Restore", systemImage: "arrow.uturn.backward") { Task { await vault.updateMany(selectedItems, deleted: false); selection = [] } }
                        .disabled(selection.isEmpty)
                } else {
                    Button("Save / Share", systemImage: "square.and.arrow.up") { exportItems = selectedItems; showingExports = true }.disabled(selection.isEmpty)
                    Spacer(minLength: 0)
                    Button("Album", systemImage: "rectangle.stack.badge.plus") { albumSheet = true }.labelStyle(.iconOnly).frame(width: 44, height: 44).disabled(selection.isEmpty)
                }
                Spacer(minLength: 0)
                Button("Delete", systemImage: "trash") { deletion = true }.labelStyle(.iconOnly).frame(width: 44, height: 44).disabled(selection.isEmpty)
            } else {
                PhotosPicker(selection: $photos, maxSelectionCount: 50, matching: .any(of: [.images, .videos]), preferredItemEncoding: .current, photoLibrary: .shared()) {
                    Label("Import", systemImage: "plus").fontWeight(.semibold).frame(minHeight: 44)
                }
                Spacer()
                Button("Files", systemImage: "folder") { files = true }.frame(minHeight: 44)
                Spacer()
                Button("Settings", systemImage: "gearshape") { settings = true }.frame(minHeight: 44)
            }
        }.font(.subheadline).padding(.horizontal, 20).padding(.vertical, 6).disabled(vault.busy)
    }
    private func open(_ item: VaultItem) {
        if selecting { if !selection.insert(item.id).inserted { selection.remove(item.id) } }
        else { selected = item }
    }
    private func itemAction(_ action: String, _ item: VaultItem) {
        switch action {
        case "open": selected = item
        case "favorite": vault.update(item, favorite: item.favorite != true)
        case "export": exportItems = [item]; showingExports = true
        case "album": selection = [item.id]; albumSheet = true
        case "delete": vault.update(item, deleted: true)
        case "restore": vault.update(item, deleted: false)
        default: break
        }
    }
    private var albumEditor: some View {
        NavigationStack {
            Form {
                Section("Album") {
                    TextField("Album name", text: $albumName)
                    ForEach(albums, id: \.self) { name in Button(name) { albumName = name } }
                }
                Section {
                    Button("Move Selected Items") {
                        let chosen = selectedItems; let name = albumName.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task { await vault.updateMany(chosen, album: name); albumSheet = false; albumName = ""; selection = [] }
                    }.disabled(albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vault.busy)
                    Button("Remove from Album") { Task { await vault.updateMany(selectedItems, album: ""); albumSheet = false; selection = [] } }.disabled(vault.busy)
                }
            }.navigationTitle("Move to Album")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { albumSheet = false } } }
        }
    }
}
#endif
