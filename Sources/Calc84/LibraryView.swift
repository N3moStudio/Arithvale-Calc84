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
    @EnvironmentObject private var cloud: CloudBackupModel
    @EnvironmentObject private var shared: SharedBackupModel
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var navigationMotion
    @StateObject private var content = LibraryContentStore()
    @AppStorage("galleryStyle") private var layout = GalleryStyle.initial.rawValue
    @AppStorage("appAppearance") private var appearance = AppAppearance.system.rawValue
    @AppStorage("libraryDateSource") private var dateSource = LibraryDateSource.captured.rawValue
    @AppStorage("libraryNewestFirst") private var newestFirst = true
    let close: () -> Void
    @State private var photos: [PhotosPickerItem] = []
    @State private var files = false
    @State private var folders = false
    @State private var importCapacity: ImportCapacityRequest?
    @State private var cloudChoices = false
    @State private var settings = false
    @AppStorage("libraryGlassTint") private var tintValue = GlassTint.plum.rawValue
    private var glassTint: GlassTint { GlassTint(rawValue: tintValue) ?? .plum }
    private var backgroundVisible: Bool { !settings && !adding && !addingBackup && !showingExports && !albumSheet && !cloudChoices && !photoPicker && !files && !folders && !deletion && !removeReceived && !vault.mediaViewerPresented && !vault.libraryToolPresented && importCapacity == nil && !vault.busy && vault.photoImportReview == nil && vault.fileImportReview == nil }
    @State private var filter = "All"
    @State private var search = ""
    @State private var searching = false
    @State private var tab = "Library"
    @State private var adding = false
    @State private var pendingAdd: String?
    @State private var photoPicker = false
    @State private var addingBackup = false
    @State private var removeReceived = false
    @State private var selecting = false
    @State private var selection = Set<UUID>()
    @State private var deletion = false
    @State private var albumSheet = false
    @State private var exportItems: [VaultItem] = []
    @State private var showingExports = false
    private var style: GalleryStyle { GalleryStyle(rawValue: layout) ?? .initial }
    private var showingAlbums: Bool { tab == "Albums" || (style == .albumsFirst && tab == "Library" && filter == "All") }
    private var albums: [String] { content.albums }
    private var visible: [VaultItem] { content.visible }
    private var sections: [LibrarySection] { content.sections }
    private var query: LibraryQuery {
        LibraryQuery(filter: filter, search: search, dateSource: LibraryDateSource(rawValue: dateSource) ?? .captured, newestFirst: newestFirst)
    }
    private var navigationSelection: String { showingAlbums ? "Albums" : searching ? "Search" : "Library" }
    private var selectedItems: [VaultItem] { visible.filter { selection.contains($0.id) } }
    var body: some View {
        VStack(spacing: 0) {
            header
            if shared.entry != nil || shared.working || shared.error != nil { receivedBackup }
            if searching {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search names, albums, tags or text", text: $search).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Clear", systemImage: "xmark.circle.fill") { search = "" }.labelStyle(.iconOnly).frame(width: 44, height: 44)
                }.padding(.leading, 14).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16).padding(.bottom, 8)
            }
            if !showingAlbums { filters }
            if vault.busy {
                HStack(spacing: 10) {
                    OperationProgressView(title: vault.importing ? "Importing into Your Library" : cloud.running ? "Backing Up" : "Working",
                        detail: cloud.running ? cloud.phase : vault.status,
                        progress: vault.importing && vault.progress > 0 ? vault.progress : nil)
                    Spacer(minLength: 0)
                    if vault.importing { Button("Cancel") { vault.cancelImport() }.frame(minHeight: 44) }
                    if vault.cloud.running { Button("Pause") { vault.cloud.pause() }.frame(minHeight: 44) }
                }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Color(uiColor: .secondarySystemBackground))
            }
            if vault.failedImportCount > 0 && !vault.busy {
                Button("Retry \(vault.failedImportCount) Unimported Items") { vault.retryImports() }.frame(minHeight: 44)
            }
            if showingAlbums {
                AlbumLibraryView(items: content.albumItems, engine: vault.engine) { value in
                    tab = "Library"; filter = value; selection = []
                    // All Items in Albums First opens the actual photo grid.
                    if style == .albumsFirst && value == "All" { filter = "All Items" }
                }
            } else {
                MemoryGrid(sections: sections, engine: vault.engine, columns: textSize.isAccessibilitySize ? 2 : style.columns,
                    style: style == .albumsFirst ? .photoLibrary : style, grouping: "Months", selection: selection, selecting: selecting,
                    busy: vault.busy, setSelection: { selection = $0 },
                    identity: filter + "|" + search + "|" + dateSource + "|" + String(newestFirst), open: open, action: itemAction,
                    viewerVault: vault, contentRevision: content.revision)
                    .opacity(visible.isEmpty ? 0 : 1)
                    .overlay {
                        // Keep the presentation owner alive if unfavoriting the
                        // current photo empties this query while its viewer is open.
                        if visible.isEmpty {
                            ContentUnavailableView(search.isEmpty ? (filter == "Recently Deleted" ? "Nothing Deleted" : "Your memories go here") : "No matches",
                                systemImage: filter == "Recently Deleted" ? "trash" : "photo.on.rectangle",
                                description: Text(search.isEmpty ? (filter == "Recently Deleted" ? "Deleted items stay here until you remove them permanently." : "Tap + to add photos, videos, files or a backup.") : "Try a shorter word or a tag. Turn on Private Text Search in Settings to find words inside photos."))
                        }
                    }
            }
            if selecting { actionBar.modifier(FloatingLibraryBar()).padding(.horizontal, 8).padding(.bottom, 4) }
            else if style != .clearGlass { navigationBar.padding(6).modifier(FloatingLibraryBar()).padding(.horizontal, 12).padding(.bottom, 6) }
        }
        .overlay(alignment: .bottom) {
            if style == .clearGlass && !selecting {
                navigationBar.padding(6).modifier(FloatingLibraryBar()).padding(.horizontal, 20).padding(.bottom, 8)
            }
        }
        .background { ArithenWallpaper(area: .library, visible: backgroundVisible) }
        .preferredColorScheme(style == .nightroom ? .dark : (AppAppearance(rawValue: appearance) ?? .system).scheme)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $settings) { NavigationStack { VaultSettingsView().environmentObject(vault) } }
        .sheet(isPresented: $adding, onDismiss: routeAdd) { addSheet }
        .sheet(isPresented: $addingBackup) { NavigationStack { BackupImportView() } }
        .sheet(isPresented: $showingExports) { ExportMediaView(items: exportItems).environmentObject(vault) }
        .sheet(isPresented: $albumSheet) { albumEditor }
        .sheet(isPresented: $cloudChoices) { CloudBatchSelectionView(ids: selection).environmentObject(vault) }
        .sheet(item: $importCapacity) { request in ImportCapacityView(request: request) { importCapacity = nil } }
        .sheet(item: $vault.fileImportReview) { FileImportReviewView(review: $0).environmentObject(vault) }
        .sheet(item: $vault.photoImportReview) { PhotoImportReviewView(review: $0).environmentObject(vault) }
        .photosPicker(isPresented: $photoPicker, selection: $photos, maxSelectionCount: 50, matching: .any(of: [.images, .videos]), preferredItemEncoding: .current, photoLibrary: .shared())
        .fileImporter(isPresented: $files, allowedContentTypes: [.item], allowsMultipleSelection: true) {
            do { importCapacity = ImportCapacityRequest(files: try $0.get()) } catch { vault.message = error.localizedDescription }
        }
        .fileImporter(isPresented: $folders, allowedContentTypes: [.folder], allowsMultipleSelection: false) {
            do { importCapacity = ImportCapacityRequest(files: try $0.get()) } catch { vault.message = error.localizedDescription }
        }
        .onChange(of: photos) { _, value in if !value.isEmpty { importCapacity = ImportCapacityRequest(photos: value); photos = [] } }
        .onChange(of: search) { _, _ in selection = [] }
        .onChange(of: layout) { _, _ in selecting = false; selection = [] }
        .onReceive(vault.$items) { items in
            vault.textSearch.prune(items: items)
            content.update(items: items, query: query)
            selection.formIntersection(Set(content.visible.map(\.id)))
        }
        .task(id: query) {
            let value = query
            if !value.search.isEmpty { do { try await Task.sleep(nanoseconds: 150_000_000) } catch { return } }
            guard !Task.isCancelled else { return }
            content.update(items: vault.items, query: value)
        }
        .onReceive(vault.textSearch.$index) { index in
            content.update(items: vault.items, query: query, recognizedText: index.enabled ? index.entries : [:])
        }
        .task { await vault.refreshLibraryExtras() }
        .confirmationDialog(filter == "Recently Deleted" ? "Permanently Delete Selected Items?" : "Move to Recently Deleted?",
            isPresented: $deletion, titleVisibility: .visible) {
            Button(filter == "Recently Deleted" ? "Delete Permanently" : "Move to Recently Deleted", role: .destructive) {
                let chosen = selectedItems
                Task { await vault.updateMany(chosen, deleted: true, permanently: filter == "Recently Deleted"); selection = []; selecting = false }
            }
        } message: { Text(filter == "Recently Deleted" ? "This removes these local copies. Older backups and exported originals keep theirs." : "Restore them from Albums → Recently Deleted. Nothing is automatically erased.") }
        .onChange(of: vault.unlocked) { _, unlocked in if !unlocked { photos = []; selection = []; search = "" } }
        .confirmationDialog("Remove the received copy?", isPresented: $removeReceived, titleVisibility: .visible) {
            Button("Remove Received Copy", role: .destructive) { shared.discard() }
        } message: { Text("The original backup in Files stays where it is. You can share another backup afterward.") }
        .alert("Couldn’t Complete", isPresented: Binding(get: { !settings && vault.photoImportReview == nil && vault.fileImportReview == nil && vault.message != nil }, set: { if !$0 { vault.message = nil } })) {
            Button("Close", role: .cancel) { vault.message = nil }
        } message: { Text(vault.message ?? "") }
    }
    private var header: some View {
        ArithenGlassGroup {
        HStack(spacing: 6) {
            Text(selecting ? "\(selection.count) selected" : showingAlbums ? "Albums" : searching ? "Search" : style == .timeline ? "Your days" : "Library")
                .font(style == .contactSheet ? .title2.bold() : .largeTitle.bold())
                .lineLimit(1).minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button(selecting ? "Done" : "Select") {
                if showingAlbums { tab = "Library"; filter = "All Items" }
                selecting.toggle(); selection = []
            }.font(.subheadline.weight(.semibold)).frame(minWidth: 56, minHeight: 44)
                .modifier(ArithenGlass(tint: glassTint, shape: Capsule())).disabled(vault.busy)
            Button("Add to Library", systemImage: "plus") { adding = true }
                .labelStyle(.iconOnly).font(.title3).frame(width: 44, height: 44)
                .modifier(ArithenGlass(tint: glassTint, shape: Circle(), prominent: true)).disabled(vault.busy)
            Button("Settings", systemImage: "gearshape") { settings = true }
                .labelStyle(.iconOnly).font(.title3).frame(width: 44, height: 44)
                .modifier(ArithenGlass(tint: glassTint, shape: Circle()))
        }
        }.padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 12)
    }
    private var receivedBackup: some View {
        HStack(spacing: 6) {
            Button { addingBackup = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.badge.arrow.up").font(.title2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(shared.working ? "Receiving backup…" : shared.error != nil ? "Review received backup" : "Backup received")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        Text("Review & add to your library").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }.frame(minHeight: 44)
            }.disabled(shared.working || vault.busy)
            Button("Remove Received Copy", systemImage: "xmark") { removeReceived = true }
                .labelStyle(.iconOnly).frame(width: 44, height: 44).foregroundStyle(.secondary)
                .disabled(shared.working || vault.busy)
        }.padding(.leading, 14).padding(.vertical, 7)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: style == .contactSheet ? 9 : 14))
            .padding(.horizontal, 14).padding(.bottom, 8)
    }
    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ArithenGlassGroup {
            HStack(spacing: 8) {
                ForEach(["All", "Photos", "Videos", "Favorites"], id: \.self) { value in
                    let active = filter == value || (value == "All" && filter == "All Items")
                    Button { filter = style == .albumsFirst && value == "All" ? "All Items" : value; selection = [] } label: {
                        Text(value).font(.subheadline.weight(active ? .semibold : .regular))
                            .foregroundStyle(active ? Color.primary : Color.secondary)
                            .padding(.horizontal, 15).frame(minHeight: 44)
                            .modifier(ArithenGlass(tint: glassTint, shape: Capsule(), prominent: active))
                    }.accessibilityAddTraits(active ? .isSelected : [])
                }
            }.padding(.horizontal, 14)
            }
        }.padding(.bottom, 8)
    }
    private var navigationBar: some View {
        HStack(spacing: 4) {
            navButton("Library", symbol: "photo.on.rectangle", active: tab == "Library" && !showingAlbums) {
                tab = "Library"; filter = style == .albumsFirst ? "All Items" : "All"; searching = false; search = ""
            }
            navButton("Albums", symbol: "rectangle.stack", active: showingAlbums) {
                tab = "Albums"; searching = false; search = ""
            }
            navButton("Search", symbol: "magnifyingglass", active: searching) {
                tab = "Search"; searching = true; filter = "All Items"
            }
            if style == .contactSheet {
                navButton("Add", symbol: "plus", active: false) { adding = true }
            }
        }.animation(reduceMotion ? nil : .spring(duration: 0.22, bounce: 0.08), value: navigationSelection)
    }
    private func navButton(_ title: String, symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 21, weight: active ? .semibold : .regular))
                Text(title).font(.caption2.weight(active ? .semibold : .regular))
            }.frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(active ? Color.primary : Color.secondary)
                .background {
                    if active && style == .clearGlass {
                        Capsule().fill(Color.primary.opacity(0.09))
                            .matchedGeometryEffect(id: "library-navigation-selection", in: navigationMotion)
                    }
                }
        }.accessibilityAddTraits(active ? .isSelected : [])
    }
    private var addSheet: some View {
        NavigationStack {
            List {
                Button { pendingAdd = "photos"; adding = false } label: {
                    Label("Photos & Videos", systemImage: "photo.on.rectangle").frame(minHeight: 44)
                }
                Button { pendingAdd = "files"; adding = false } label: { Label("Files", systemImage: "doc").frame(minHeight: 44) }
                Button { pendingAdd = "folder"; adding = false } label: { Label("A Folder", systemImage: "folder").frame(minHeight: 44) }
                Button { pendingAdd = "backup"; adding = false } label: { Label("From a Backup", systemImage: "externaldrive.badge.plus").frame(minHeight: 44) }
            }.navigationTitle("Add to Library").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { adding = false } } }
        }.presentationDetents([.medium, .large])
    }
    private func routeAdd() {
        guard vault.unlocked else { pendingAdd = nil; return }
        switch pendingAdd {
        case "photos": photoPicker = true
        case "files": files = true
        case "folder": folders = true
        case "backup": addingBackup = true
        default: break
        }
        pendingAdd = nil
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
                    Button("Cloud Choices", systemImage: "icloud") { cloudChoices = true }.labelStyle(.iconOnly).frame(width: 44, height: 44).disabled(selection.isEmpty)
                    Button("Album", systemImage: "rectangle.stack.badge.plus") { albumSheet = true }.labelStyle(.iconOnly).frame(width: 44, height: 44).disabled(selection.isEmpty)
                }
                Spacer(minLength: 0)
                Button("Delete", systemImage: "trash") { deletion = true }.labelStyle(.iconOnly).frame(width: 44, height: 44).disabled(selection.isEmpty)
            }
        }.font(.subheadline).padding(.horizontal, 20).padding(.vertical, 6).disabled(vault.busy)
    }
    private func open(_ item: VaultItem) {
        if selecting { if !selection.insert(item.id).inserted { selection.remove(item.id) } }
    }
    private func itemAction(_ action: String, _ item: VaultItem) {
        switch action {
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
            AlbumTagEditor(ids: selection) { albumSheet = false; selection = [] }
        }
    }
}
#endif
