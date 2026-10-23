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
    let items: [VaultItem]
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    @State private var working = false
    @State private var result = ""
    @State private var error: String?
    @State private var export: MediaExport?
    @State private var operation: Task<Void, Never>?
    private var allMedia: Bool { items.allSatisfy { UTType($0.contentType)?.conforms(to: .image) == true || UTType($0.contentType)?.conforms(to: .movie) == true } }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("\(items.count) selected", systemImage: "square.and.arrow.up").font(.headline)
                    Text("These actions create ordinary, unencrypted copies. Original files can include GPS location and other metadata.")
                    Text("Saving to Photos preserves the stored capture date. Photos can still list it under Recently Added.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Button("Save to Photos", systemImage: "photo.badge.arrow.down") { start(mode: "photos") }.disabled(!allMedia)
                    Button("Save Originals to Files", systemImage: "folder") { start(mode: "files") }
                    Button("Share / AirDrop Originals", systemImage: "square.and.arrow.up") { start(mode: "share") }
                    Button("Share Photo Copies without Metadata", systemImage: "location.slash") { start(mode: "privatePhotos") }
                        .disabled(!items.allSatisfy { UTType($0.contentType)?.conforms(to: .image) == true })
                    Text("Photo copies are new JPEGs up to 4096 pixels, with location and original metadata omitted. Live Photos become stills. Visible details in the picture remain. Originals stay unchanged.").font(.footnote).foregroundStyle(.secondary)
                }.disabled(working || vault.busy)
                if working { Section { ProgressView("Preparing originals…") } }
                if !result.isEmpty { Section { Label(result, systemImage: "checkmark.circle") } }
                if items.contains(where: { $0.companionID != nil }) {
                    Section {
                        Text("Save to Photos recreates a Live Photo. Files and Share export both its image and video; the receiving app decides whether to pair them.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }.navigationTitle("Save or Share").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(working ? "Cancel" : "Done") { operation?.cancel(); dismiss() } } }
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
        }.onDisappear { operation?.cancel() }
    }
    private func start(mode: String) {
        working = true; result = ""; let ticket = vault.generation
        operation = Task {
            var directory: URL?
            var handedOff = false
            var saved = 0
            defer {
                working = false
                if !handedOff, let directory { try? FileManager.default.removeItem(at: directory) }
            }
            do {
                let folder = TemporaryFiles.directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
                directory = folder
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                    attributes: [.protectionKey: FileProtectionType.complete])
                var urls: [URL] = []
                for (index, item) in items.enumerated() {
                    try Task.checkCancellation()
                    guard vault.unlocked, ticket == vault.generation else { throw VaultError.locked }
                    let base = (item.name as NSString).lastPathComponent
                    let safe = base.isEmpty || base == "." || base == ".." ? "Original.bin" : base
                    let main = folder.appendingPathComponent("\(index + 1)-\(safe)")
                    try await vault.engine.materialize(id: item.id, to: main)
                    if let captured = item.captured { try? FileManager.default.setAttributes([.creationDate: captured, .modificationDate: captured], ofItemAtPath: main.path) }
                    if mode == "privatePhotos" {
                        let copy = folder.appendingPathComponent("Photo-\(index + 1).jpg")
                        try await Task.detached(priority: .utility) { try PrivatePhotoCopy.make(from: main, to: copy) }.value
                        try? FileManager.default.removeItem(at: main)
                        urls.append(copy)
                        continue
                    }
                    var companion: URL?
                    if let id = item.companionID {
                        let url = folder.appendingPathComponent("\(index + 1)-LivePhoto.mov")
                        try await vault.engine.materialize(id: id, to: url); companion = url
                    }
                    try Task.checkCancellation()
                    guard vault.unlocked, ticket == vault.generation else { throw VaultError.locked }
                    if mode == "photos" {
                        try await MediaBridge.saveToPhotos(item: item, main: main, companion: companion)
                        saved += 1
                        try? FileManager.default.removeItem(at: main)
                        if let companion { try? FileManager.default.removeItem(at: companion) }
                    } else { urls.append(main); if let companion { urls.append(companion) } }
                }
                try Task.checkCancellation()
                guard vault.unlocked, ticket == vault.generation else { throw VaultError.locked }
                if mode == "photos" { result = "Saved \(saved) to Photos with their stored dates." }
                else { export = MediaExport(urls: urls, share: mode == "share" || mode == "privatePhotos", folder: folder); handedOff = true }
            } catch {
                if !Task.isCancelled, ticket == vault.generation { self.error = (saved > 0 ? "Saved \(saved) items. " : "") + error.localizedDescription }
            }
        }
    }
}

struct ActivitySheet: UIViewControllerRepresentable {
    let urls: [URL]
    let folder: URL
    let finished: (Bool) -> Void
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        controller.excludedActivityTypes = [.saveToCameraRoll] // Use our date-preserving Photos path.
        controller.completionWithItemsHandler = { _, completed, _, _ in
            try? FileManager.default.removeItem(at: folder)
            finished(completed)
        }
        return controller
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
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
