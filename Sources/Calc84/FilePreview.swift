#if os(iOS)
import SwiftUI
import UIKit
import Photos
import PhotosUI
import PDFKit
import AVKit
#if canImport(_AVKit_SwiftUI)
import _AVKit_SwiftUI
#endif
import UniformTypeIdentifiers
import CalcCore

struct MediaExport: Identifiable {
    let id = UUID()
    let urls: [URL]
    let share: Bool
    let folder: URL
}
struct ExportMediaView: View {
    private enum Mode { case photos, files, share, privatePhotos }
    let items: [VaultItem]
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    @State private var activeMode: Mode?
    @State private var stopping = false
    @State private var savedPhotos = 0
    @State private var prepared = 0
    @State private var result = ""
    @State private var error: String?
    @State private var export: MediaExport?
    @State private var operation: Task<Void, Never>?
    private var allMedia: Bool { items.allSatisfy { UTType($0.contentType)?.conforms(to: .image) == true || UTType($0.contentType)?.conforms(to: .movie) == true } }
    private var allImages: Bool { items.allSatisfy { UTType($0.contentType)?.conforms(to: .image) == true } }
    var body: some View {
        NavigationStack {
            ThemedForm {
                Section {
                    Label("\(items.count) selected", systemImage: "square.and.arrow.up").font(.headline)
                    Text("These actions create ordinary, unencrypted copies. Original files can include GPS location and other metadata.")
                    Text("Saving to Photos preserves the stored capture date. Photos can still list it under Recently Added.")
                        .font(.footnote).foregroundStyle(ArithenPalette.color(.muted))
                }
                Section {
                    Button(savedPhotos > 0 && savedPhotos < items.count ? "Save Remaining to Photos" : "Save to Photos", systemImage: "photo.badge.arrow.down") { start(mode: .photos) }
                        .disabled(!allMedia || savedPhotos == items.count)
                    Button("Save Originals to Files", systemImage: "folder") { start(mode: .files) }
                    Button("Share / AirDrop Originals", systemImage: "square.and.arrow.up") { start(mode: .share) }
                    if allImages {
                        Button("Share Photo Copies without Metadata", systemImage: "location.slash") { start(mode: .privatePhotos) }
                        Text("Photo copies are new JPEGs up to 4096 pixels, with location and original metadata omitted. Live Photos become stills. Visible details in the picture remain. Originals stay unchanged.").font(.footnote).foregroundStyle(ArithenPalette.color(.muted))
                    }
                }.disabled(activeMode != nil || vault.busy)
                if let activeMode {
                    Section {
                        let count = activeMode == .photos ? savedPhotos : prepared
                        ProgressView(value: Double(count), total: Double(max(1, items.count))) {
                            Text(activeMode == .photos ? "Saved \(count) of \(items.count) to Photos" : "Prepared \(count) of \(items.count)")
                        }
                    }
                }
                if !result.isEmpty { Section { Label(result, systemImage: "checkmark.circle") } }
                if items.contains(where: { $0.companionID != nil }) {
                    Section {
                        Text("Save to Photos recreates a Live Photo. Files and Share export both its image and video; the receiving app decides whether to pair them.")
                            .font(.footnote).foregroundStyle(ArithenPalette.color(.muted))
                    }
                }
            }.navigationTitle("Save or Share").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(activeMode == nil ? "Done" : stopping ? "Stopping…" : "Cancel") {
                            if activeMode == nil { dismiss() }
                            else { stopping = true; operation?.cancel() }
                        }.disabled(stopping)
                    }
                }
                .sheet(item: $export, onDismiss: { export = nil }) { request in
                    if request.share {
                        ActivitySheet(urls: request.urls, folder: request.folder) { completed in
                            result = completed ? "Handed to the selected destination." : ""; export = nil
                        }
                    } else {
                        DocumentsExportSheet(urls: request.urls, folder: request.folder) { completed in
                            result = completed ? "Copies saved outside the vault." : ""; export = nil
                        }
                    }
                }
                .alert("Couldn’t Complete", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button("Close", role: .cancel) { error = nil }
                } message: { Text(error ?? "") }
        }.interactiveDismissDisabled(activeMode != nil)
            .onDisappear { operation?.cancel() }
    }
    private func start(mode: Mode) {
        guard activeMode == nil, !items.isEmpty else { return }
        activeMode = mode; prepared = 0; result = ""; let ticket = vault.generation
        operation = Task {
            var directory: URL?
            var handedOff = false
            defer {
                activeMode = nil; stopping = false; operation = nil
                if !handedOff, let directory { try? FileManager.default.removeItem(at: directory) }
            }
            do {
                let folder = TemporaryFiles.directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
                directory = folder
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                    attributes: [.protectionKey: FileProtectionType.complete])
                var urls: [URL] = []
                let first = mode == .photos ? savedPhotos : 0
                for index in first..<items.count {
                    let item = items[index]
                    try Task.checkCancellation()
                    guard vault.unlocked, ticket == vault.generation else { throw VaultError.locked }
                    let base = (item.name as NSString).lastPathComponent
                    let safe = base.isEmpty || base == "." || base == ".." ? "Original.bin" : base
                    let main = folder.appendingPathComponent("\(index + 1)-\(safe)")
                    try await vault.engine.materialize(id: item.id, to: main)
                    if let captured = item.captured { try? FileManager.default.setAttributes([.creationDate: captured, .modificationDate: captured], ofItemAtPath: main.path) }
                    if mode == .privatePhotos {
                        let copy = folder.appendingPathComponent("Photo-\(index + 1).jpg")
                        try await Task.detached(priority: .utility) { try PrivatePhotoCopy.make(from: main, to: copy) }.value
                        try? FileManager.default.removeItem(at: main)
                        urls.append(copy)
                        prepared += 1
                        continue
                    }
                    var companion: URL?
                    if let id = item.companionID {
                        let url = folder.appendingPathComponent("\(index + 1)-LivePhoto.mov")
                        try await vault.engine.materialize(id: id, to: url); companion = url
                    }
                    try Task.checkCancellation()
                    guard vault.unlocked, ticket == vault.generation else { throw VaultError.locked }
                    if mode == .photos {
                        try await MediaBridge.saveToPhotos(item: item, main: main, companion: companion)
                        savedPhotos += 1
                        try? FileManager.default.removeItem(at: main)
                        if let companion { try? FileManager.default.removeItem(at: companion) }
                    } else {
                        urls.append(main)
                        if let companion { urls.append(companion) }
                        prepared += 1
                    }
                }
                try Task.checkCancellation()
                guard vault.unlocked, ticket == vault.generation else { throw VaultError.locked }
                if mode == .photos { result = "Saved \(savedPhotos) to Photos with their stored dates." }
                else { export = MediaExport(urls: urls, share: mode == .share || mode == .privatePhotos, folder: folder); handedOff = true }
            } catch {
                guard ticket == vault.generation, vault.unlocked else { return }
                if Task.isCancelled {
                    result = mode == .photos ? "Saved \(savedPhotos) of \(items.count) to Photos." : "Export canceled."
                } else {
                    self.error = (mode == .photos ? "Saved \(savedPhotos) of \(items.count) to Photos. " : "") + error.localizedDescription
                }
            }
        }
    }
}

struct ActivitySheet: UIViewControllerRepresentable {
    let urls: [URL]
    let folder: URL
    let finished: (Bool) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(folder: folder, finished: finished) }
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        controller.excludedActivityTypes = [.saveToCameraRoll] // Use our date-preserving Photos path.
        controller.completionWithItemsHandler = { [coordinator = context.coordinator] _, completed, _, _ in
            coordinator.finish(completed)
        }
        return controller
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
    static func dismantleUIViewController(_ controller: UIActivityViewController, coordinator: Coordinator) {
        // A parent/lock dismissal need not invoke the activity completion handler.
        // Release only this export when its actual presentation ends, never all
        // temporary files merely because a share extension made the app inactive.
        controller.completionWithItemsHandler = nil
        DispatchQueue.main.async { coordinator.finish(false) }
    }
    final class Coordinator {
        private let folder: URL
        private var finished: ((Bool) -> Void)?
        init(folder: URL, finished: @escaping (Bool) -> Void) { self.folder = folder; self.finished = finished }
        func finish(_ completed: Bool) {
            guard let callback = finished else { return }
            finished = nil
            try? FileManager.default.removeItem(at: folder)
            callback(completed)
        }
    }
}
struct DocumentsExportSheet: UIViewControllerRepresentable {
    let urls: [URL]
    let folder: URL
    let finished: (Bool) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(folder: folder, finished: finished) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
        controller.delegate = context.coordinator; return controller
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    static func dismantleUIViewController(_ controller: UIDocumentPickerViewController, coordinator: Coordinator) {
        DispatchQueue.main.async { coordinator.finish(false) }
    }
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let folder: URL
        let finished: (Bool) -> Void
        private var completed = false
        init(folder: URL, finished: @escaping (Bool) -> Void) { self.folder = folder; self.finished = finished }
        func finish(_ saved: Bool) {
            guard !completed else { return }; completed = true
            try? FileManager.default.removeItem(at: folder); finished(saved)
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { finish(!urls.isEmpty) }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finish(false) }
    }
}
struct PDFPreview: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView { let view = PDFView(); view.autoScales = true; view.document = PDFDocument(url: url); return view }
    func updateUIView(_ view: PDFView, context: Context) {}
    static func dismantleUIView(_ view: PDFView, coordinator: ()) { view.document = nil }
}
struct ZoomableImage: UIViewRepresentable {
    let image: UIImage
    var zoomChanged: (Bool) -> Void = { _ in }
    func makeCoordinator() -> Coordinator { Coordinator(zoomChanged) }
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView(); scroll.minimumZoomScale = 1; scroll.maximumZoomScale = 5; scroll.delegate = context.coordinator
        scroll.showsHorizontalScrollIndicator = false; scroll.showsVerticalScrollIndicator = false
        scroll.panGestureRecognizer.isEnabled = false
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2; scroll.addGestureRecognizer(doubleTap)
        context.coordinator.scroll = scroll
        let view = context.coordinator.imageView; view.image = image; view.contentMode = .scaleAspectFit
        view.isAccessibilityElement = true; view.accessibilityLabel = "Imported image"; view.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(view)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor), view.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            view.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor), view.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            view.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor), view.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor)])
        return scroll
    }
    func updateUIView(_ view: UIScrollView, context: Context) {
        context.coordinator.zoomChanged = zoomChanged
        if context.coordinator.imageView.image !== image { context.coordinator.imageView.image = image }
    }
    static func dismantleUIView(_ view: UIScrollView, coordinator: Coordinator) { coordinator.imageView.image = nil }
    final class Coordinator: NSObject, UIScrollViewDelegate {
        let imageView = UIImageView()
        weak var scroll: UIScrollView?
        var zoomChanged: (Bool) -> Void
        private var wasZoomed = false
        init(_ zoomChanged: @escaping (Bool) -> Void) { self.zoomChanged = zoomChanged }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let zoomed = scrollView.zoomScale > 1.01
            scrollView.panGestureRecognizer.isEnabled = zoomed
            if wasZoomed != zoomed { wasZoomed = zoomed; zoomChanged(zoomed) }
        }
        @objc func doubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scroll else { return }
            if scroll.zoomScale > 1.01 { scroll.setZoomScale(1, animated: !UIAccessibility.isReduceMotionEnabled) }
            else {
                let point = gesture.location(in: imageView), size = scroll.bounds.size
                scroll.zoom(to: CGRect(x: point.x - size.width / 4, y: point.y - size.height / 4,
                                       width: size.width / 2, height: size.height / 2), animated: !UIAccessibility.isReduceMotionEnabled)
            }
        }
    }
}
#endif
