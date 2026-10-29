#if os(iOS)
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CalcCore
#if canImport(_PhotosUI_SwiftUI)
import _PhotosUI_SwiftUI
#endif

struct SurfaceAppearanceSettings: View {
    let area: AppearanceArea
    @AppStorage private var tint: String
    @AppStorage private var background: String
    @AppStorage private var video: String
    @AppStorage private var dimming: Double
    @AppStorage private var editData: Data
    @State private var editor: WallpaperEditorRequest?
    @State private var picked: PhotosPickerItem?
    @State private var importing = false
    @State private var error: String?
    @State private var importTask: Task<Void, Never>?
    init(area: AppearanceArea) {
        self.area = area
        _tint = AppStorage(wrappedValue: GlassTint.plum.rawValue, area.tintKey)
        _background = AppStorage(wrappedValue: WallpaperStyle.gradient.rawValue, area.backgroundKey)
        _video = AppStorage(wrappedValue: "", area.videoKey)
        _dimming = AppStorage(wrappedValue: 0.55, area.dimmingKey)
        _editData = AppStorage(wrappedValue: Data(), area.editKey)
    }
    private var selectedTint: GlassTint { GlassTint(rawValue: tint) ?? .plum }
    var body: some View {
        Form {
            Section {
                ArithenGlassGroup {
                    HStack(spacing: 14) {
                        ForEach(["plus", "heart", "slider.horizontal.3"], id: \.self) { symbol in
                            Image(systemName: symbol).font(.title2).frame(width: 58, height: 58)
                                .modifier(ArithenGlass(tint: selectedTint, shape: Circle(), interactive: false))
                        }
                    }.frame(maxWidth: .infinity).padding(.vertical, 22)
                }.listRowBackground(
                    LinearGradient(colors: [Color(red: 0.47, green: 0.38, blue: 0.73).opacity(0.32), Color(uiColor: .secondarySystemGroupedBackground)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                Picker("Glass tint", selection: $tint) {
                    ForEach(GlassTint.allCases, id: \.rawValue) { option in
                        Label(option.title, systemImage: option == .clear ? "circle" : "circle.fill")
                            .foregroundStyle(option.color).tag(option.rawValue)
                    }
                }
            } header: { Text("Glass controls") } footer: {
                Text("Tint changes the buttons and controls in this area. iOS 26 uses Liquid Glass; older versions use a translucent material.")
            }
            Section {
                Picker("Background", selection: $background) {
                    ForEach(WallpaperStyle.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                if area == .calculator {
                    PhotosPicker(selection: $picked, matching: .videos, preferredItemEncoding: .current) {
                        Label(video.isEmpty ? "Choose Your Video" : "Replace Video", systemImage: "video.badge.plus")
                    }.disabled(importing)
                } else {
                    NavigationLink("Choose a Library Video") { LibraryWallpaperPicker() }
                }
                if importing { ProgressView("Preparing your background…") }
                if !video.isEmpty {
                    Button("Edit Loop, Crop & Still Frame", systemImage: "slider.horizontal.3") {
                        let edit = (try? JSONDecoder().decode(WallpaperEdit.self, from: editData)) ?? .init()
                        if area == .library { editor = WallpaperEditorRequest(libraryID: WallpaperPolicy.videoID(video), edit: edit) }
                        else if let original = WallpaperFiles.source(video), FileManager.default.fileExists(atPath: original.path) {
                            editor = WallpaperEditorRequest(source: original, edit: edit)
                        } else if let oldClip = WallpaperFiles.url(video) {
                            // Earlier versions retained only their prepared loop.
                            editor = WallpaperEditorRequest(source: oldClip)
                        }
                    }.disabled(importing)
                    Button("Remove Background Video", role: .destructive) {
                        let previous = video
                        video = ""; editData = Data(); background = WallpaperStyle.gradient.rawValue
                        if area == .calculator { WallpaperFiles.remove(previous) }
                    }.disabled(importing)
                }
                if background == WallpaperStyle.video.rawValue {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Background softness")
                        Slider(value: $dimming, in: 0.25...0.85).accessibilityLabel("Background softness")
                    }
                    if video.isEmpty { Text("Choose a video to use this background.").foregroundStyle(.secondary) }
                }
            } header: { Text("Your background") } footer: {
                Text(area == .calculator
                    ? "Choose something suitable for the calculator screen: it is visible before unlocking. Pick a silent loop up to 30 seconds, its crop, and a still frame. A protected source copy is kept here for later editing; your original stays in Photos."
                    : "Choose from videos already imported into your encrypted library. The original stays encrypted; a temporary playback copy is cleared when you lock or leave. Removing the background does not delete the library video.")
            }
            Section {
                Label("Stops in Low Power Mode", systemImage: "battery.25percent")
                Label("Respects Reduce Motion", systemImage: "accessibility")
                Text("Video also pauses when this screen is covered or inactive, or the phone is running hot. Your chosen still frame stays visible when movement is disabled.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle(area == .calculator ? "Calculator Appearance" : "Library Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .tint(CalcTheme.accent)
            .onChange(of: picked) { _, item in
                guard let item else { return }
                importTask?.cancel()
                importing = true
                importTask = Task {
                    defer { importing = false; picked = nil }
                    var input: URL?
                    defer {
                        if let input { try? FileManager.default.removeItem(at: input) }
                    }
                    do {
                        guard let transfer = try await item.loadTransferable(type: WallpaperTransfer.self) else { throw WallpaperError.invalid }
                        input = transfer.url
                        try Task.checkCancellation()
                        editor = WallpaperEditorRequest(source: transfer.url, ownsSource: true)
                        input = nil // The editor now owns and cleans this temporary source.
                    } catch {
                        if !Task.isCancelled { self.error = error.localizedDescription }
                    }
                }
            }
            .sheet(item: $editor) { request in WallpaperEditor(area: area, request: request) }
            .onDisappear { importTask?.cancel() }
            .alert("Couldn’t Set Background", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
    }
}

struct LibraryWallpaperPicker: View {
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("libraryBackgroundVideo") private var selected = ""
    @AppStorage("libraryBackgroundStyle") private var style = WallpaperStyle.gradient.rawValue
    @AppStorage("libraryBackgroundEdit.v1") private var editData = Data()
    @State private var editor: WallpaperEditorRequest?
    private var videos: [VaultItem] {
        vault.items.filter { $0.visible && $0.deletedAt == nil && UTType($0.contentType)?.conforms(to: .movie) == true }
    }
    var body: some View {
        List {
            Section {
                Text("Import your video using Library → + → Photos & Videos, then choose it here. Pick the section to loop, position the crop and choose a still frame. Originals stay unchanged.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if videos.isEmpty { ContentUnavailableView("No Library Videos", systemImage: "video", description: Text("Import a video into your library first.")) }
            ForEach(videos) { item in
                Button {
                    let edit = selected == item.id.uuidString ? ((try? JSONDecoder().decode(WallpaperEdit.self, from: editData)) ?? .init()) : WallpaperEdit()
                    editor = WallpaperEditorRequest(libraryID: item.id, edit: edit)
                } label: {
                    HStack(spacing: 12) {
                        LibraryThumbnail(item: item, engine: vault.engine).frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading) {
                            Text(item.name).lineLimit(2).foregroundStyle(.primary)
                            if item.byteCount > WallpaperPolicy.maximumSourceBytes { Text("Choose a copy under 256 MB").font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        if selected == item.id.uuidString { Image(systemName: "checkmark") }
                    }.frame(minHeight: 64)
                }.disabled(item.byteCount > WallpaperPolicy.maximumSourceBytes || !vault.unlocked)
            }
        }.navigationTitle("Choose a Video").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editor) { request in WallpaperEditor(area: .library, request: request) }
    }
}
#endif

