#if os(iOS)
import SwiftUI
import CalcCore
import PhotosUI
#if canImport(_PhotosUI_SwiftUI)
import _PhotosUI_SwiftUI
#endif
import UniformTypeIdentifiers

struct LibraryView: View {
    let close: () -> Void
    @State private var navigation = LibraryTabNavigation()
    var body: some View {
        TabView(selection: Binding(get: { navigation.selected }, set: { navigation.select($0) })) {
            ForEach(LibraryTab.allCases, id: \.self) { tab in
                LibraryPane(pageTab: tab, navigation: $navigation, close: close)
                    // Visibility preferences must originate inside each tab, not
                    // above TabView, or iOS can show an empty second glass bar.
                    .toolbar(.hidden, for: .tabBar)
                    .tag(tab)
            }
        }.toolbar(.hidden, for: .tabBar)
    }
}

private struct LibraryPane: View {
    let pageTab: LibraryTab
    @Binding var navigation: LibraryTabNavigation
    @EnvironmentObject private var vault: VaultModel
    @EnvironmentObject private var cloud: CloudBackupModel
    @EnvironmentObject private var shared: SharedBackupModel
    @EnvironmentObject private var sharedFiles: SharedFilesModel
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var navigationMotion
    @StateObject private var content = LibraryContentStore()
    @Environment(\.arithenTheme) private var theme
    @AppStorage("libraryDateSource") private var dateSource = LibraryDateSource.captured.rawValue
    @AppStorage("libraryNewestFirst") private var newestFirst = true
    let close: () -> Void
    @State private var photos: [PhotosPickerItem] = []
    @State private var files = false
    @State private var cloudChoices = false
    @State private var settings = false
    @State private var backupCenter = false
    @AppStorage("libraryGlassTint") private var tintValue = GlassTint.plum.rawValue
    private var glassTint: GlassTint { .clear }

    @State private var regularFilter = "All"
    private var filter: String {
        get { pageTab == .albums ? navigation.albumPath.last ?? "All" : regularFilter }
        nonmutating set { regularFilter = newValue }
    }
    @State private var search = ""
    private var searching: Bool { pageTab == .search }
    private var isActive: Bool { navigation.selected == pageTab }
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
    private var style: GalleryStyle { .clearGlass }
    private var showingAlbums: Bool { pageTab == .albums }
    private var albums: [String] { content.albums }
    private var visible: [VaultItem] { content.visible }
    private var sections: [LibrarySection] { content.sections }
    private var query: LibraryQuery {
        LibraryQuery(filter: filter, search: search, dateSource: LibraryDateSource(rawValue: dateSource) ?? .captured, newestFirst: newestFirst)
    }
    private var navigationSelection: String { showingAlbums ? "Albums" : searching ? "Search" : "Library" }
    private var selectedItems: [VaultItem] { visible.filter { selection.contains($0.id) } }
    var body: some View {
        NavigationStack(path: showingAlbums ? $navigation.albumPath : .constant([])) {
            screen(albumDetail: false)
                .navigationTitle(pageTab.rawValue)
                .toolbar(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
                .navigationDestination(for: String.self) { route in
                    screen(albumDetail: true)
                        .navigationTitle(selecting ? "\(selection.count.formatted()) Selected" : albumTitle(route))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar(.visible, for: .navigationBar)
                        .toolbar(.hidden, for: .tabBar)
                        .toolbar {
                            ToolbarItemGroup(placement: .topBarTrailing) {
                                if selecting { Button("Cancel") { selection = []; selecting = false } }
                                else {
                                    Button("Lock", systemImage: "lock.fill") { vault.lock(); close() }
                                    Button("Settings", systemImage: "gearshape") { settings = true }
                                }
                            }
                        }
                }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if selecting { actionBar }
                else { navigationBar.padding(5) }
            }.modifier(FloatingLibraryBar()).padding(.horizontal, textSize.isAccessibilitySize ? 14 : 30).padding(.vertical, 8)
        }
        .background(ArithenPalette.color(.canvas, theme: theme).ignoresSafeArea())
        .sheet(isPresented: $settings) { NavigationStack { VaultSettingsView().environmentObject(vault) } }
        .sheet(isPresented: $backupCenter) { NavigationStack { BackupSettingsView()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { backupCenter = false } } }
        } }
        .sheet(isPresented: $adding, onDismiss: routeAdd) { addSheet }
        .sheet(isPresented: $addingBackup) { NavigationStack { BackupImportView() } }
        .sheet(isPresented: $showingExports) { ExportMediaView(items: exportItems).environmentObject(vault) }
        .sheet(isPresented: $albumSheet) { albumEditor }
        .sheet(isPresented: $cloudChoices) { CloudBatchSelectionView(ids: selection).environmentObject(vault) }
        .sheet(isPresented: $files) { NavigationStack { SharedFilesImportView() } }
        .sheet(item: Binding(get: { isActive ? vault.fileImportReview : nil }, set: { if isActive { vault.fileImportReview = $0 } })) {
            FileImportReviewView(review: $0).environmentObject(vault)
        }
        .accessibilityHidden(vault.photoImportReview != nil)
        .allowsHitTesting(vault.photoImportReview == nil)
        .overlay {
            if isActive, let review = vault.photoImportReview {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { }
                    ScrollView { PhotoImportReviewView(review: review) { vault.photoImportReview = nil }
                        .frame(maxWidth: .infinity).padding(24) }
                        .scrollBounceBehavior(.basedOnSize).defaultScrollAnchor(.center)
                }
            }
        }
        .photosPicker(isPresented: $photoPicker, selection: $photos, maxSelectionCount: 50, matching: .any(of: [.images, .videos]), preferredItemEncoding: .current, photoLibrary: .shared())
        .onChange(of: photos) { _, value in if !value.isEmpty { vault.importPhotos(value); photos = [] } }
        .onChange(of: selection) { _, value in if value.isEmpty { selecting = false } }
        .onChange(of: search) { _, _ in selection = [] }
        .onChange(of: navigation.albumPath) { _, _ in if showingAlbums { selection = []; selecting = false } }
        .onReceive(vault.$items) { items in
            guard isActive else { return }
            vault.textSearch.prune(items: items)
            content.update(items: items, query: query)
            selection.formIntersection(Set(content.visible.map(\.id)))
        }
        .task(id: query) {
            guard isActive else { return }
            let value = query
            if !value.search.isEmpty { do { try await Task.sleep(nanoseconds: 150_000_000) } catch { return } }
            guard !Task.isCancelled else { return }
            content.update(items: vault.items, query: value)
        }
        .onReceive(vault.textSearch.$index) { index in
            guard isActive else { return }
            content.update(items: vault.items, query: query, recognizedText: index.enabled ? index.entries : [:])
        }
        .task(id: isActive) {
            guard isActive else { return }
            let index = vault.textSearch.index
            content.update(items: vault.items, query: query, recognizedText: index.enabled ? index.entries : [:])
            selection.formIntersection(Set(content.visible.map(\.id)))
            await vault.refreshLibraryExtras()
        }
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
        .alert("Couldn’t Complete", isPresented: Binding(get: { isActive && !settings && vault.photoImportReview == nil && vault.fileImportReview == nil && vault.message != nil }, set: { if !$0 && isActive { vault.message = nil } })) {
            Button("Close", role: .cancel) { vault.message = nil }
        } message: { Text(vault.message ?? "") }
    }
    private func albumTitle(_ route: String) -> String {
        route.hasPrefix("album:") ? String(route.dropFirst(6)) : route == "All" ? "All Items" : route
    }
    private func screen(albumDetail: Bool) -> some View {
        VStack(spacing: 0) {
            if !albumDetail { header }
            BackupReminderView { backupCenter = true }
            if shared.entry != nil || shared.working || shared.error != nil { receivedBackup }
            if sharedFiles.hasPending { receivedFiles }
            if searching {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(ArithenPalette.color(.muted))
                    TextField("Search names, albums, tags or text", text: $search).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Clear", systemImage: "xmark.circle.fill") { search = "" }.labelStyle(.iconOnly).frame(width: 44, height: 44)
                }.padding(.leading, 14).background(ArithenPalette.color(.surface), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16).padding(.bottom, 8)
            }
            if !showingAlbums || albumDetail { filters }
            if vault.busy {
                HStack(spacing: 10) {
                    OperationProgressView(title: vault.importing ? "Importing into Your Library" : cloud.running ? "Backing Up" : "Working",
                        detail: cloud.running ? cloud.phase : vault.status,
                        progress: vault.importing && vault.progress > 0 ? vault.progress : nil)
                    Spacer(minLength: 0)
                    if vault.importing { Button("Cancel") { vault.cancelImport() }.frame(minHeight: 44) }
                    if vault.cloud.running { Button("Pause") { vault.cloud.pause() }.frame(minHeight: 44) }
                }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(ArithenPalette.color(.surface))
            }
            if vault.failedImportCount > 0 && !vault.busy {
                Button("Retry \(vault.failedImportCount) Unimported Items") { vault.retryImports() }.frame(minHeight: 44)
            }
            if showingAlbums && !albumDetail {
                AlbumLibraryView(items: content.albumItems, engine: vault.engine) { value in
                    navigation.openAlbum(value); selection = []
                }
            } else {
                MemoryGrid(sections: sections, engine: vault.engine, columns: textSize.isAccessibilitySize ? 2 : 4,
                    style: style == .albumsFirst ? .photoLibrary : style, grouping: "Snaps", selection: selection, selecting: selecting,
                    busy: vault.busy, setSelection: { selection = $0; selecting = !$0.isEmpty },
                    identity: filter + "|" + search + "|" + dateSource + "|" + String(newestFirst), open: open, action: itemAction,
                    viewerVault: vault, contentRevision: content.revision, beginSelection: { item in selection = [item.id]; selecting = true }, theme: theme)
                    .opacity(visible.isEmpty ? 0 : 1)
                    .overlay {
                        // Keep the presentation owner alive if unfavoriting the
                        // current photo empties this query while its viewer is open.
                        if visible.isEmpty {
                            ContentUnavailableView(search.isEmpty ? (filter == "Recently Deleted" ? "Nothing Deleted" : "Your memories go here") : "No matches",
                                systemImage: filter == "Recently Deleted" ? "trash" : "photo.on.rectangle",
                                description: Text(search.isEmpty ? (filter == "Recently Deleted" ? "Deleted items stay here until you remove them permanently." : "Tap + to add photos, videos, files or a backup.") : "Try a shorter word or a tag. Photo Indexing in Privacy & Access finds words inside photos."))
                        }
                    }
            }
        }
        .background(ArithenPalette.color(.canvas, theme: theme))
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button("Lock & Return to Calculator", systemImage: "lock.fill") { vault.lock(); close() }
                    .labelStyle(.iconOnly).frame(width: 44, height: 44)
                if !textSize.isAccessibilitySize { headerTitle }
                Spacer(minLength: 0)
                if selecting {
                    Button("Cancel") { selection = []; selecting = false }
                        .font(.body.weight(.semibold)).fixedSize(horizontal: true, vertical: false).frame(minHeight: 44)
                } else {
                    Button("Add to Library", systemImage: "plus") { adding = true }
                        .labelStyle(.iconOnly).frame(width: 44, height: 44).disabled(vault.busy)
                    Button("Settings", systemImage: "gearshape") { settings = true }
                        .labelStyle(.iconOnly).frame(width: 44, height: 44)
                }
            }
            // Give large text its own row instead of shrinking it beside the controls.
            if textSize.isAccessibilitySize { headerTitle.padding(.horizontal, 2) }
        }.padding(.horizontal, 12).padding(.vertical, 8)
    }
    private var headerTitle: some View {
        Text(selecting ? "\(selection.count.formatted()) \(selection.count == 1 ? "Snap Selected" : "Snaps Selected")" : showingAlbums ? "Albums" : searching ? "Search" : "Library")
            .font(.title2.bold()).monospacedDigit()
            .lineLimit(textSize.isAccessibilitySize ? nil : 1)
            .minimumScaleFactor(textSize.isAccessibilitySize ? 1 : 0.75)
            .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
    }
    private var receivedFiles: some View {
        Button { files = true } label: {
            HStack(spacing: 12) {
                if sharedFiles.working { ProgressView().frame(width: 28) }
                else { Image(systemName: sharedFiles.error == nil ? "doc.on.doc" : "exclamationmark.circle").font(.title2).frame(width: 28) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(sharedFiles.working ? "Preparing files…" : sharedFiles.error != nil ? "Files need attention" : "\(sharedFiles.entries.count.formatted()) \(sharedFiles.entries.count == 1 ? "file received" : "files received")")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(ArithenPalette.color(.text))
                    Text(sharedFiles.working ? "Your received copies are being processed" : sharedFiles.error != nil ? "Review the import" : "Ready to import into your library")
                        .font(.caption).foregroundStyle(ArithenPalette.color(.muted))
                }.multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            }.frame(minHeight: 44).padding(14)
                .background(ArithenPalette.color(.surface), in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain).padding(.horizontal, 14).padding(.bottom, 8)
    }
    private var receivedBackup: some View {
        HStack(spacing: 6) {
            Button { addingBackup = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.badge.arrow.up").font(.title2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(shared.working ? "Receiving backup…" : shared.error != nil ? "Review received backup" : "Backup received")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(ArithenPalette.color(.text))
                        Text("Import into your library").font(.caption).foregroundStyle(ArithenPalette.color(.muted))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }.frame(minHeight: 44)
            }.disabled(shared.working || vault.busy)
            Button("Remove Received Copy", systemImage: "xmark") { removeReceived = true }
                .labelStyle(.iconOnly).frame(width: 44, height: 44).foregroundStyle(ArithenPalette.color(.muted))
                .disabled(shared.working || vault.busy)
        }.padding(.leading, 14).padding(.vertical, 7)
            .background(ArithenPalette.color(.surface), in: RoundedRectangle(cornerRadius: style == .contactSheet ? 9 : 14))
            .padding(.horizontal, 14).padding(.bottom, 8)
    }
    private var filters: some View {
        Group {
            if showingAlbums { snapCount }
            else if textSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 0) {
                    snapCount
                    ScrollView(.horizontal) { filterButtons.fixedSize(horizontal: true, vertical: false) }
                        .scrollIndicators(.hidden)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { snapCount; Spacer(minLength: 0); filterButtons }
                    VStack(alignment: .leading, spacing: 0) { snapCount; filterButtons }
                }
            }
        }.padding(.horizontal, 14).padding(.vertical, 4)
            .overlay(alignment: .bottom) { Rectangle().fill(ArithenPalette.color(.text).opacity(0.12)).frame(height: 0.5) }
    }
    private var snapCount: some View {
        Group {
            if showingAlbums { countLabel.frame(maxWidth: .infinity, alignment: .leading) }
            else { Button { filter = "All"; selection = [] } label: { countLabel }.buttonStyle(.plain) }
        }.frame(minHeight: 44)
            .contextMenu {
                Picker("Sort by", selection: $dateSource) {
                    ForEach(LibraryDateSource.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                Toggle("Newest First", isOn: $newestFirst)
            }
    }
    private var countLabel: some View {
        Text("\(visible.count.formatted()) \(visible.count == 1 ? "Snap" : "Snaps")").font(.subheadline.weight(.semibold)).monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
    }
    private var filterButtons: some View {
        HStack(spacing: 12) {
            ForEach(["Photos", "Videos", "Favorites"], id: \.self) { value in
                Button { filter = filter == value ? "All" : value; selection = [] } label: {
                    Text(value == "Favorites" ? "Favs" : value).font(.subheadline.weight(filter == value ? .bold : .medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(ArithenPalette.color(filter == value ? .accent : .muted))
                        .frame(minHeight: 44)
                        .overlay(alignment: .bottom) { if filter == value { Capsule().fill(.tint).frame(height: 2) } }
                }.accessibilityAddTraits(filter == value ? .isSelected : [])
            }
        }
    }
    private var navigationBar: some View {
        HStack(spacing: 4) {
            navButton("Library", symbol: "photo.on.rectangle", active: pageTab == .library) { navigation.select(.library) }
            navButton("Albums", symbol: "rectangle.stack", active: showingAlbums) { navigation.select(.albums) }
            navButton("Search", symbol: "magnifyingglass", active: searching) { navigation.select(.search) }
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
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(ArithenPalette.color(active ? .accent : .muted, theme: theme))
                .background {
                    if active && style == .clearGlass {
                        Capsule().fill(ArithenPalette.color(.accent, theme: theme).opacity(0.1))
                            .matchedGeometryEffect(id: "library-navigation-selection", in: navigationMotion)
                    }
                }
        }.accessibilityAddTraits(active ? .isSelected : [])
    }
    private var addSheet: some View {
        NavigationStack {
            ThemedList {
                Button { pendingAdd = "photos"; adding = false } label: {
                    Label("Photos & Videos", systemImage: "photo.on.rectangle").frame(minHeight: 44)
                }
                Button { pendingAdd = "files"; adding = false } label: { Label("Import from Files", systemImage: "folder").frame(minHeight: 44) }
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
        case "backup": addingBackup = true
        default: break
        }
        pendingAdd = nil
    }
    private var actionBar: some View {
        HStack(spacing: 4) {
            if filter == "Recently Deleted" {
                Button("Restore", systemImage: "arrow.uturn.backward") { Task { await vault.updateMany(selectedItems, deleted: false); selection = [] } }
                    .frame(maxWidth: .infinity, minHeight: 48)
            } else {
                Button { exportItems = selectedItems; showingExports = true } label: {
                    VStack(spacing: 4) { Image(systemName: "square.and.arrow.up"); Text("Share").font(.caption) }
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                Button { albumSheet = true } label: {
                    VStack(spacing: 4) { Image(systemName: "rectangle.stack.badge.plus"); Text("Add to Album").font(.caption) }
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            }
            Button(role: .destructive) { deletion = true } label: {
                VStack(spacing: 4) { Image(systemName: "trash"); Text("Delete").font(.caption) }
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
        }.multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            .padding(6).disabled(vault.busy || selection.isEmpty)
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
