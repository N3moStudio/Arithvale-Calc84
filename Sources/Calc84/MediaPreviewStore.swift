#if os(iOS)
import SwiftUI
import Photos
import ImageIO
import UniformTypeIdentifiers
import CalcCore

/// Only the current page and its immediate neighbors may retain decoded media.
@MainActor
final class MediaPreviewStore: ObservableObject {
    @Published var activeID: UUID?
    @Published var zoomedID: UUID?
    private var assets: [UUID: MediaPreviewAsset] = [:]
    private var prefetch: Task<Void, Never>?

    func image(for id: UUID) -> UIImage? { assets[id]?.thumbnailImage ?? assets[id]?.image }

    func asset(for item: VaultItem) -> MediaPreviewAsset {
        if let existing = assets[item.id] { return existing }
        let value = MediaPreviewAsset(item: item); assets[item.id] = value; return value
    }
    func focus(_ position: Int, items: [VaultItem], vault: VaultModel) {
        guard items.indices.contains(position), vault.unlocked else { clear(); return }
        prefetch?.cancel(); zoomedID = nil; activeID = items[position].id
        let indices = [position, position + 1, position - 1].filter { items.indices.contains($0) }
        let keep = Set(indices.map { items[$0].id })
        for id in Array(assets.keys) {
            if !keep.contains(id) { assets.removeValue(forKey: id)?.dispose() }
            else if id != activeID {
                if let asset = assets[id], asset.item.byteCount > 32 * 1024 * 1024 { asset.dispose() }
                else { assets[id]?.cancelLoading() }
            }
        }
        let current = asset(for: items[position])
        current.load(vault: vault, full: true)
        // Immediate lightweight placeholders; do not decrypt large neighboring videos.
        for index in indices.dropFirst() { asset(for: items[index]).load(vault: vault, full: false) }
        prefetch = Task { [weak self] in
            await current.operation?.value
            do { try await Task.sleep(for: .milliseconds(150)); try Task.checkCancellation() }
            catch { return }
            guard let self, self.activeID == items[position].id, vault.unlocked else { return }
            for index in indices.dropFirst() {
                let item = items[index]
                // Bound speculative disk work and decoded memory. Live Photo motion and
                // large/video originals are prepared only when they become current.
                guard item.byteCount <= 16 * 1024 * 1024, item.companionID == nil,
                      UTType(item.contentType)?.conforms(to: .image) == true else { continue }
                guard !Task.isCancelled, self.activeID == items[position].id else { return }
                let asset = self.asset(for: item); asset.load(vault: vault, full: true)
                await asset.operation?.value
            }
        }
    }
    func clear() {
        prefetch?.cancel(); prefetch = nil; activeID = nil; zoomedID = nil
        for asset in assets.values { asset.dispose() }; assets.removeAll()
    }
    func trimToCurrent() {
        prefetch?.cancel(); prefetch = nil
        for (id, asset) in assets where id != activeID { asset.dispose() }
    }
}

@MainActor
final class MediaPreviewAsset: ObservableObject {
    let item: VaultItem
    @Published private(set) var image: UIImage?
    private(set) var thumbnailImage: UIImage?
    @Published private(set) var livePhoto: PHLivePhoto?
    @Published private(set) var url: URL?
    @Published private(set) var error: String?
    @Published private(set) var motionError: String?
    private(set) var operation: Task<Void, Never>?
    private var operationID = UUID()
    private var loadingFull = false
    private var companion: URL?
    init(item: VaultItem) { self.item = item }

    func cancelLoading() {
        operationID = UUID(); operation?.cancel(); operation = nil; loadingFull = false
    }
    func dispose() {
        cancelLoading(); image = nil; thumbnailImage = nil; livePhoto = nil; error = nil; motionError = nil
        if let url { try? FileManager.default.removeItem(at: url) }; url = nil
        if let companion { try? FileManager.default.removeItem(at: companion) }; companion = nil
    }
    func load(vault: VaultModel, full: Bool) {
        let needsMotion = item.companionID != nil && livePhoto == nil && motionError == nil
        guard full ? (url == nil || needsMotion) : image == nil else { return }
        if operation != nil && (loadingFull || !full) { return }
        cancelLoading(); error = nil; loadingFull = full
        let request = UUID(); operationID = request
        let generation = vault.generation
        operation = Task {
            defer { if operationID == request { operation = nil; loadingFull = false } }
            var created: URL?
            var retained = false
            defer { if !retained, let created { try? FileManager.default.removeItem(at: created) } }
            do {
                if image == nil, let id = item.thumbnailID {
                    if let data = try? await vault.engine.contents(id: id) {
                        try valid(vault, generation, request)
                        let thumbnail = await Task.detached(priority: .userInitiated) { UIImage(data: data)?.preparingForDisplay() }.value
                        try valid(vault, generation, request); thumbnailImage = thumbnail; image = thumbnail
                    }
                    try valid(vault, generation, request)
                }
                guard full else { return }
                let source: URL
                if let existing = url { source = existing; retained = true }
                else {
                    source = try TemporaryFiles.fresh(extension: UTType(item.contentType)?.preferredFilenameExtension ?? "bin")
                    created = source
                    try StoragePreflight.require(bytes: Int64(item.byteCount))
                    try await vault.engine.materialize(id: item.id, to: source)
                }
                try valid(vault, generation, request)
                if !retained, UTType(item.contentType)?.conforms(to: .image) == true {
                    let decoded = await Task.detached(priority: .userInitiated) {
                        guard let source = CGImageSourceCreateWithURL(source as CFURL, nil),
                              let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                                kCGImageSourceCreateThumbnailFromImageAlways: true,
                                kCGImageSourceThumbnailMaxPixelSize: 2048,
                                kCGImageSourceCreateThumbnailWithTransform: true,
                                kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return UIImage?.none }
                        return UIImage(cgImage: bitmap)
                    }.value
                    try valid(vault, generation, request); image = decoded ?? image
                }
                url = source; retained = true
                if let id = item.companionID {
                    let pair = try TemporaryFiles.fresh(extension: "mov")
                    var keepPair = false
                    defer { if !keepPair { try? FileManager.default.removeItem(at: pair) } }
                    do {
                        try await vault.engine.materialize(id: id, to: pair)
                        try valid(vault, generation, request)
                        let photo = try await LivePhotoLoader.load([source, pair])
                        try valid(vault, generation, request)
                        companion = pair; livePhoto = photo; keepPair = true
                    } catch {
                        if !Task.isCancelled, operationID == request {
                            motionError = "Motion preview unavailable. Both originals remain available for export."
                        }
                    }
                }
            } catch {
                if !Task.isCancelled, operationID == request, generation == vault.generation { self.error = error.localizedDescription }
            }
        }
    }
    private func valid(_ vault: VaultModel, _ generation: UUID, _ request: UUID) throws {
        try Task.checkCancellation()
        guard vault.unlocked, generation == vault.generation, operationID == request else { throw CancellationError() }
    }
}
#endif
