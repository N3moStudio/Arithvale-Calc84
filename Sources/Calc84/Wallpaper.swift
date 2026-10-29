#if os(iOS)
import SwiftUI
import AVFoundation
import PhotosUI
import CoreTransferable
import UniformTypeIdentifiers
import CalcCore
#if canImport(_PhotosUI_SwiftUI)
import _PhotosUI_SwiftUI
#endif

enum WallpaperError: LocalizedError {
    case invalid, tooLarge
    var errorDescription: String? {
        switch self {
        case .invalid: "This video couldn’t be prepared. Try a downloaded video from Photos."
        case .tooLarge: "Choose a video smaller than 256 MB. You can trim a copy in Photos first."
        }
    }
}

struct WallpaperTransfer: Transferable, Sendable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { incoming in
            let bytes = try incoming.file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
            guard bytes > 0, bytes <= WallpaperPolicy.maximumSourceBytes else { throw WallpaperError.tooLarge }
            let copy = try PickedMedia.receive(incoming)
            return WallpaperTransfer(url: copy.url)
        }
    }
}

enum WallpaperFiles {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CalculatorWallpapers", isDirectory: true)
    }
    static func url(_ value: String) -> URL? {
        guard let id = WallpaperPolicy.videoID(value) else { return nil }
        return directory.appendingPathComponent(id.uuidString).appendingPathExtension("mov")
    }
    static func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        var folder = directory
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
    }
    static func source(_ value: String) -> URL? { url(value)?.deletingPathExtension().appendingPathExtension("source.mov") }
    static func remove(_ value: String) {
        for url in [url(value), source(value)].compactMap({ $0 }) { try? FileManager.default.removeItem(at: url) }
    }
}

/// Converts a bounded local source once, not during each animation frame.
enum WallpaperVideo {
    static func prepare(_ source: URL, edit: WallpaperEdit = .init()) async throws -> URL {
        let asset = AVURLAsset(url: source)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let chosen = edit.normalized(sourceDuration: duration.seconds),
              let sourceTrack = tracks.first
        else { throw WallpaperError.invalid }
        // Keep only video, so a decorative background has no audio track to route.
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw WallpaperError.invalid }
        let range = CMTimeRange(start: CMTime(seconds: chosen.start, preferredTimescale: 600), duration: CMTime(seconds: chosen.duration, preferredTimescale: 600))
        try track.insertTimeRange(range, of: sourceTrack, at: .zero)
        track.preferredTransform = try await sourceTrack.load(.preferredTransform)
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPreset1280x720)
        else { throw WallpaperError.invalid }
        let result = try TemporaryFiles.fresh(extension: "mov")
        var keep = false
        defer { if !keep { try? FileManager.default.removeItem(at: result) } }
        export.timeRange = CMTimeRange(start: .zero, duration: range.duration)
        export.shouldOptimizeForNetworkUse = false
        try Task.checkCancellation()
        try await export.export(to: result, as: .mov)
        try Task.checkCancellation()
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: result.path)
        keep = true
        return result
    }
    static func poster(_ url: URL, seconds: Double = 0) async throws -> UIImage {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw WallpaperError.invalid }
        let chosen = min(max(0, seconds.isFinite ? seconds : 0), max(0, duration - 0.01))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 900, height: 900)
        generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
        let frame = try await generator.image(at: CMTime(seconds: chosen, preferredTimescale: 600))
        return UIImage(cgImage: frame.image)
    }
}

@MainActor
final class WallpaperPlayback: ObservableObject {
    @Published private(set) var player: AVQueuePlayer?
    @Published private(set) var poster: UIImage?
    private var loop: AVPlayerLooper?
    private var temporary: URL?
    private var request = UUID()
    private var allowed = false
    func clear() {
        request = UUID()
        player?.pause(); loop?.disableLooping(); loop = nil
        player?.removeAllItems(); player = nil; poster = nil
        if let temporary { try? FileManager.default.removeItem(at: temporary) }
        temporary = nil
    }
    func playback(_ allowed: Bool) {
        self.allowed = allowed
        if allowed { player?.play() } else { player?.pause() }
    }
    func loadPublic(_ id: String, edit: WallpaperEdit) async {
        clear(); let ticket = request
        guard let url = WallpaperFiles.url(id), FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let image = try await WallpaperVideo.poster(url, seconds: edit.still)
            try Task.checkCancellation()
            guard request == ticket else { return }
            install(url, image: image)
        } catch { /* A removed/missing wallpaper falls back to the static gradient. */ }
    }
    func loadPrivate(_ item: VaultItem, vault: VaultModel, edit: WallpaperEdit) async {
        clear(); let ticket = request; let generation = vault.generation
        guard vault.unlocked, item.byteCount <= WallpaperPolicy.maximumSourceBytes else { return }
        var original: URL?
        var prepared: URL?
        var retained = false
        defer {
            if let original { try? FileManager.default.removeItem(at: original) }
            if !retained, let prepared { try? FileManager.default.removeItem(at: prepared) }
        }
        do {
            let file = try TemporaryFiles.fresh(extension: UTType(item.contentType)?.preferredFilenameExtension ?? "mov")
            original = file
            try StoragePreflight.require(bytes: Int64(item.byteCount) + 80 * 1024 * 1024)
            try await vault.engine.materialize(id: item.id, to: file)
            try Task.checkCancellation()
            guard vault.unlocked, vault.generation == generation, request == ticket else { return }
            let movie = try await WallpaperVideo.prepare(file, edit: edit); prepared = movie
            let image = try await WallpaperVideo.poster(movie, seconds: edit.still)
            try Task.checkCancellation()
            guard vault.unlocked, vault.generation == generation, request == ticket else { return }
            temporary = movie; retained = true; install(movie, image: image)
        } catch { /* Library lock, cancellation or removed media restores the static background. */ }
    }
    func preview(_ source: URL, edit: WallpaperEdit) async throws {
        clear(); let ticket = request
        let movie = try await WallpaperVideo.prepare(source, edit: edit)
        var keep = false
        defer { if !keep { try? FileManager.default.removeItem(at: movie) } }
        let image = try await WallpaperVideo.poster(movie, seconds: edit.still)
        try Task.checkCancellation()
        guard request == ticket else { throw CancellationError() }
        temporary = movie; keep = true; install(movie, image: image)
    }
    private func install(_ url: URL, image: UIImage) {
        poster = image
        let item = AVPlayerItem(url: url)
        item.preferredMaximumResolution = CGSize(width: 1280, height: 720)
        let queue = AVQueuePlayer()
        queue.isMuted = true
        queue.preventsDisplaySleepDuringVideoPlayback = false
        queue.allowsExternalPlayback = false
        if #available(iOS 27.0, *) { queue.setDisconnectedFromSystemAudio(true) }
        loop = AVPlayerLooper(player: queue, templateItem: item)
        player = queue
        if allowed { queue.play() }
    }
}

final class WallpaperLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var videoLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
struct WallpaperSurface: UIViewRepresentable {
    let player: AVQueuePlayer?
    func makeUIView(context: Context) -> WallpaperLayerView {
        let view = WallpaperLayerView()
        view.videoLayer.videoGravity = .resizeAspectFill
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }
    func updateUIView(_ view: WallpaperLayerView, context: Context) { view.videoLayer.player = player }
    static func dismantleUIView(_ view: WallpaperLayerView, coordinator: ()) { view.videoLayer.player = nil }
}

struct ArithenWallpaper: View {
    let area: AppearanceArea
    var visible = true
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.scenePhase) private var scene
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var scheme
    @AppStorage private var styleValue: String
    @AppStorage private var video: String
    @AppStorage private var dimming: Double
    @AppStorage private var editData: Data
    @StateObject private var playback = WallpaperPlayback()
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var thermal = ProcessInfo.processInfo.thermalState
    init(area: AppearanceArea, visible: Bool = true) {
        self.area = area; self.visible = visible
        _styleValue = AppStorage(wrappedValue: WallpaperStyle.gradient.rawValue, area.backgroundKey)
        _video = AppStorage(wrappedValue: "", area.videoKey)
        _dimming = AppStorage(wrappedValue: 0.55, area.dimmingKey)
        _editData = AppStorage(wrappedValue: Data(), area.editKey)
    }
    private var edit: WallpaperEdit { (try? JSONDecoder().decode(WallpaperEdit.self, from: editData)) ?? .init() }
    private var privateItem: VaultItem? {
        guard area == .library, vault.unlocked, let id = WallpaperPolicy.videoID(video) else { return nil }
        return vault.items.first { $0.id == id && $0.visible && $0.deletedAt == nil && UTType($0.contentType)?.conforms(to: .movie) == true }
    }
    private var active: Bool { scene == .active && visible && (area == .calculator || vault.unlocked) }
    private var shouldPlay: Bool {
        WallpaperPolicy.plays(active: active, visible: visible, reduceMotion: reduceMotion || reduceTransparency || contrast == .increased,
            lowPower: lowPower, thermallyLimited: thermal == .serious || thermal == .critical)
    }
    private var loadIdentity: String {
        guard active, styleValue == WallpaperStyle.video.rawValue else { return "" }
        if area == .library { return privateItem.map { $0.id.uuidString + vault.generation.uuidString + editData.base64EncodedString() } ?? "" }
        return video + editData.base64EncodedString()
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(uiColor: .systemBackground)
                if styleValue != WallpaperStyle.plain.rawValue {
                    LinearGradient(colors: scheme == .dark
                        ? [Color(red: 0.14, green: 0.11, blue: 0.23), Color(red: 0.04, green: 0.035, blue: 0.07)]
                        : [Color(red: 0.95, green: 0.93, blue: 0.98), Color(red: 0.86, green: 0.81, blue: 0.95)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                if styleValue == WallpaperStyle.video.rawValue {
                    if let poster = playback.poster {
                        CroppedWallpaper(image: poster, player: shouldPlay ? playback.player : nil, edit: edit)
                    }
                    (scheme == .dark ? Color.black : Color.white).opacity(WallpaperPolicy.dimming(dimming))
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
            .task(id: loadIdentity) {
                playback.clear()
                guard !loadIdentity.isEmpty else { return }
                if area == .library, let item = privateItem { await playback.loadPrivate(item, vault: vault, edit: edit) }
                else if area == .calculator { await playback.loadPublic(video, edit: edit) }
                // Completion must not overwrite a newer power/accessibility decision.
                // install() uses the permission maintained by the observers below.
            }
            .onChange(of: shouldPlay, initial: true) { _, value in playback.playback(value) }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange).receive(on: RunLoop.main)) { _ in lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled; playback.playback(shouldPlay) }
            .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification).receive(on: RunLoop.main)) { _ in thermal = ProcessInfo.processInfo.thermalState; playback.playback(shouldPlay) }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in playback.playback(false); if area == .library { playback.clear() } }
            .onChange(of: vault.unlocked) { _, value in if area == .library && !value { playback.clear() } }
            .onDisappear { playback.clear() }
    }
}

struct CroppedWallpaper: View {
    let image: UIImage
    var player: AVQueuePlayer?
    let edit: WallpaperEdit
    var body: some View {
        GeometryReader { geometry in
            let crop = WallpaperCrop.layout(sourceWidth: image.size.width, sourceHeight: image.size.height,
                width: geometry.size.width, height: geometry.size.height, edit: edit)
            ZStack(alignment: .topLeading) {
                Color.clear
                Image(uiImage: image).resizable().frame(width: crop.width, height: crop.height).offset(x: crop.x, y: crop.y)
                if let player { WallpaperSurface(player: player).frame(width: crop.width, height: crop.height).offset(x: crop.x, y: crop.y) }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
    }
}
#endif

