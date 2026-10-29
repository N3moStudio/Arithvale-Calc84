#if os(iOS)
import SwiftUI
import Vision
import ImageIO
import UniformTypeIdentifiers
import CalcCore

/// Vision and decoding run off the main actor; only a bounded image is decoded.
private actor TextRecognitionWorker {
    func recognize(_ url: URL) throws -> String {
        try Task.checkCancellation()
        return try autoreleasepool {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 2400,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else { throw WallpaperError.invalid }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            try VNImageRequestHandler(cgImage: image).perform([request])
            try Task.checkCancellation()
            return PrivateSearchIndex.bounded((request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n"))
        }
    }
}

@MainActor
final class LibraryTextSearch: ObservableObject {
    @Published private(set) var index = PrivateSearchIndex()
    @Published private(set) var running = false
    @Published private(set) var status = "Text search is off. Names, albums, and tags still work."
    @Published private(set) var error: String?
    private let worker = TextRecognitionWorker()
    private var task: Task<Void, Never>?
    private var request = UUID()
    func lock() {
        task?.cancel(); request = UUID(); index = .init(); running = false; error = nil
        status = "Text search is off. Names, albums, and tags still work."
    }
    func pause() { task?.cancel() }
    func prune(items: [VaultItem]) {
        var next = index; next.prune(items: items)
        if next != index { index = next }
    }
    func load(vault: VaultModel) async {
        guard !running else { return }
        let ticket = request, generation = vault.generation
        do {
            let result = try await vault.engine.searchIndex()
            guard request == ticket, vault.unlocked, vault.generation == generation else { return }
            index = result
            status = result.enabled ? "\(result.entries.count) photos checked. New photos can be indexed below." : "Text search is off. Names, albums, and tags still work."
        } catch {
            if request == ticket, vault.unlocked, vault.generation == generation {
                self.error = "The search index couldn’t be read. Turn text search off to clear it, then enable it to rebuild. Your original photos are unchanged."
            }
        }
    }
    func setEnabled(_ enabled: Bool, vault: VaultModel) {
        start(vault: vault, enabled: enabled)
    }
    func scan(vault: VaultModel) { start(vault: vault, enabled: true) }
    private func start(vault: VaultModel, enabled: Bool) {
        guard vault.unlocked, !vault.busy else { return }
        let previous = task; previous?.cancel()
        request = UUID(); let ticket = request, generation = vault.generation
        running = true; error = nil
        task = Task {
            await previous?.value
            defer { if ticket == request { running = false; task = nil } }
            do {
                try Task.checkCancellation()
                guard ticket == request, vault.unlocked, generation == vault.generation else { return }
                var next = enabled ? index : PrivateSearchIndex()
                next.enabled = enabled; next.prune(items: vault.items)
                try await vault.engine.saveSearchIndex(next)
                guard ticket == request, vault.unlocked, generation == vault.generation else { return }
                index = next
                guard enabled else { status = "Text search is off. Its saved index has been removed."; return }
                let photos = vault.items.filter { $0.visible && $0.deletedAt == nil && UTType($0.contentType)?.conforms(to: .image) == true && next.entries[$0.id] == nil }
                var failed = 0, pending = 0
                for (position, item) in photos.enumerated() {
                    try Task.checkCancellation()
                    guard ticket == request, vault.unlocked, generation == vault.generation else { return }
                    guard UIApplication.shared.applicationState == .active,
                          !ProcessInfo.processInfo.isLowPowerModeEnabled,
                          ProcessInfo.processInfo.thermalState != .serious,
                          ProcessInfo.processInfo.thermalState != .critical, !vault.busy else {
                        status = "Paused to save power or let another operation finish. Tap Index New Photos to continue."
                        break
                    }
                    status = "Reading photo \(position + 1) of \(photos.count)…"
                    let file = try TemporaryFiles.fresh(extension: UTType(item.contentType)?.preferredFilenameExtension ?? "img")
                    defer { try? FileManager.default.removeItem(at: file) }
                    do {
                        try StoragePreflight.require(bytes: Int64(item.byteCount))
                        try await vault.engine.materialize(id: item.id, to: file)
                        try Task.checkCancellation()
                        let text = try await worker.recognize(file)
                        guard ticket == request, vault.unlocked, generation == vault.generation else { return }
                        next.entries[item.id] = text; pending += 1
                        if pending >= 10 {
                            try await vault.engine.saveSearchIndex(next)
                            guard ticket == request, vault.unlocked, generation == vault.generation else { return }
                            index = next; pending = 0
                        }
                    } catch {
                        if Task.isCancelled { throw CancellationError() }
                        // Failed photos stay unindexed so a later run can retry them.
                        failed += 1
                    }
                    if position == photos.count - 1 { status = "\(next.entries.count) photos checked. \(failed == 0 ? "Ready to search." : "\(failed) couldn’t be read; you can retry.")" }
                }
                try Task.checkCancellation()
                try await vault.engine.saveSearchIndex(next)
                guard ticket == request, vault.unlocked, generation == vault.generation else { return }
                index = next
                if photos.isEmpty { status = "All eligible photos have been checked." }
            } catch {
                guard ticket == request, vault.unlocked, generation == vault.generation else { return }
                if Task.isCancelled { status = "Paused. Completed batches are saved; tap Index New Photos to continue." }
                else { self.error = error.localizedDescription; status = "Text search needs attention." }
            }
        }
    }
}

struct PrivateSearchSettings: View {
    @EnvironmentObject private var vault: VaultModel
    @ObservedObject var search: LibraryTextSearch
    var body: some View {
        Form {
            Section {
                Toggle("Search Text in Photos", isOn: Binding(get: { search.index.enabled }, set: { search.setEnabled($0, vault: vault) }))
                    .disabled(vault.busy)
                Text("Read words in photos and screenshots on this phone. The saved search index is encrypted and only available while your library is unlocked.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                if search.running {
                    ProgressView(search.status)
                    Button("Pause Indexing") { search.pause() }
                } else {
                    Text(search.status)
                    if search.index.enabled { Button("Index New Photos") { search.scan(vault: vault) }.disabled(vault.busy) }
                }
                if let error = search.error {
                    Text(error).foregroundStyle(.secondary)
                    if !search.index.enabled { Button("Clear Damaged Index") { search.setEnabled(false, vault: vault) }.disabled(vault.busy) }
                }
            } footer: {
                Text("Indexing stops when you leave the app, lock the library, enable Low Power Mode, or the phone gets hot. New imports need another indexing run. Recognition can miss text; try a shorter word. This local index is rebuilt after a restore and is never sent to MEGA or Blomp.")
            }
        }.navigationTitle("Private Text Search").navigationBarTitleDisplayMode(.inline)
            .task { await search.load(vault: vault) }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in search.pause() }
    }
}
#endif
