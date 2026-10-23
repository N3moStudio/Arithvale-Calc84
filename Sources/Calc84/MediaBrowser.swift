#if os(iOS)
import SwiftUI
import UIKit
import AVKit
import UniformTypeIdentifiers
import CalcCore
#if canImport(_AVKit_SwiftUI)
import _AVKit_SwiftUI
#endif

struct MediaBrowser: View {
    let items: [VaultItem]
    let initial: UUID
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var previews = MediaPreviewStore()
    @State private var position: Int
    @State private var sheet: MediaSheet?
    private enum MediaSheet: Identifiable {
        case details(VaultItem), export(VaultItem)
        var id: String { switch self { case .details(let item): return "details-" + item.id.uuidString; case .export(let item): return "export-" + item.id.uuidString } }
    }
    init(items: [VaultItem], initial: UUID) {
        self.items = items; self.initial = initial
        _position = State(initialValue: items.firstIndex(where: { $0.id == initial }) ?? 0)
    }
    private var current: VaultItem? {
        guard items.indices.contains(position) else { return nil }
        return vault.items.first(where: { $0.id == items[position].id })
    }
    var body: some View {
        NavigationStack {
            if let current {
                MediaPager(items: items, position: $position, previews: previews, reduceMotion: reduceMotion) {
                    sheet = .details(current)
                }
                .background(Color.black)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                    ToolbarItem(placement: .principal) { Text("\(position + 1) of \(items.count)").font(.subheadline).foregroundStyle(.secondary) }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Share or Save", systemImage: "square.and.arrow.up") { sheet = .export(current) }
                    }
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Previous", systemImage: "chevron.left") { position -= 1 }.disabled(position == 0)
                        Spacer()
                        Button(current.favorite == true ? "Unfavorite" : "Favorite", systemImage: current.favorite == true ? "heart.fill" : "heart") {
                            vault.update(current, favorite: current.favorite != true)
                        }.disabled(vault.busy)
                        Spacer()
                        Button("Details", systemImage: "info.circle") { sheet = .details(current) }
                            .accessibilityHint("You can also swipe up on an unzoomed photo or video.")
                        Spacer()
                        Button("Next", systemImage: "chevron.right") { position += 1 }.disabled(position + 1 >= items.count)
                    }
                }
            }
        }
        .tint(CalcTheme.accent)
        .onAppear { previews.focus(position, items: items, vault: vault) }
        .onChange(of: position) { _, index in previews.focus(index, items: items, vault: vault) }
        .onChange(of: vault.unlocked) { _, unlocked in if !unlocked { previews.clear(); dismiss() } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in previews.trimToCurrent() }
        .onDisappear { previews.clear() }
        .sheet(item: $sheet) { request in
            switch request {
            case .export(let item): ExportMediaView(items: [item]).environmentObject(vault)
            case .details(let item): MediaDetailsView(item: item).environmentObject(vault)
            }
        }
    }
}

/// Native interactive paging keeps the outgoing page visible throughout a swipe.
private struct MediaPager: UIViewControllerRepresentable {
    let items: [VaultItem]
    @Binding var position: Int
    @ObservedObject var previews: MediaPreviewStore
    let reduceMotion: Bool
    let details: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIPageViewController {
        let page = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        page.dataSource = context.coordinator; page.delegate = context.coordinator
        page.view.backgroundColor = .black
        if let initial = context.coordinator.controller(position) { page.setViewControllers([initial], direction: .forward, animated: false) }
        return page
    }
    func updateUIViewController(_ page: UIPageViewController, context: Context) {
        let coordinator = context.coordinator; coordinator.parent = self
        page.view.subviews.compactMap { $0 as? UIScrollView }.forEach { $0.isScrollEnabled = previews.zoomedID != previews.activeID || previews.zoomedID == nil }
        coordinator.reconcile(page)
    }
    static func dismantleUIViewController(_ page: UIPageViewController, coordinator: Coordinator) {
        page.dataSource = nil; page.delegate = nil; coordinator.controllers.removeAll()
    }
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: MediaPager
        var controllers: [Int: MediaPageHost] = [:]
        var transitioning = false
        init(_ parent: MediaPager) { self.parent = parent }
        func reconcile(_ page: UIPageViewController) {
            guard !transitioning,
                  let old = (page.viewControllers?.first as? MediaPageHost)?.index, old != parent.position,
                  let target = controller(parent.position) else { return }
            transitioning = true
            page.setViewControllers([target], direction: parent.position > old ? .forward : .reverse, animated: !parent.reduceMotion) { [weak self, weak page] _ in
                guard let self, let page else { return }
                self.transitioning = false; self.trim(around: target.index)
                // Rapid Next/Previous taps may have changed the desired page mid-animation.
                self.reconcile(page)
            }
        }
        func controller(_ index: Int) -> MediaPageHost? {
            guard parent.items.indices.contains(index) else { return nil }
            if let controller = controllers[index] { return controller }
            let item = parent.items[index]
            let root = MediaPage(item: item, asset: parent.previews.asset(for: item), previews: parent.previews) { [weak self] in self?.parent.details() }
            let controller = MediaPageHost(index: index, root: root); controllers[index] = controller
            return controller
        }
        func trim(around index: Int) {
            controllers = controllers.filter { abs($0.key - index) <= 1 }
        }
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let host = viewController as? MediaPageHost else { return nil }; return controller(host.index - 1)
        }
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let host = viewController as? MediaPageHost else { return nil }; return controller(host.index + 1)
        }
        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) { transitioning = true }
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            transitioning = false
            if let host = pageViewController.viewControllers?.first as? MediaPageHost {
                if completed { parent.position = host.index }
                trim(around: host.index)
            }
        }
    }
}
private final class MediaPageHost: UIHostingController<MediaPage> {
    let index: Int
    init(index: Int, root: MediaPage) { self.index = index; super.init(rootView: root); view.backgroundColor = .black }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}
private struct MediaPage: View {
    let item: VaultItem
    @ObservedObject var asset: MediaPreviewAsset
    @ObservedObject var previews: MediaPreviewStore
    let details: () -> Void
    @State private var player: AVPlayer?
    @State private var zoomed = false
    private var movie: Bool { UTType(item.contentType)?.conforms(to: .movie) == true }
    private var pdf: Bool { UTType(item.contentType)?.conforms(to: .pdf) == true }
    var body: some View {
        ZStack {
            Color.black
            if let error = asset.error { ContentUnavailableView("Couldn’t Open", systemImage: "exclamationmark.triangle", description: Text(error)) }
            else if let player { VideoPlayer(player: player) }
            else if let url = asset.url, pdf { PDFPreview(url: url) }
            else if let photo = asset.livePhoto { LivePhotoPreview(photo: photo) }
            else if let image = asset.image {
                if movie { Image(uiImage: image).resizable().scaledToFit() }
                else {
                    ZoomableImage(image: image) { value in
                        zoomed = value
                        if value { previews.zoomedID = item.id }
                        else if previews.zoomedID == item.id { previews.zoomedID = nil }
                    }
                }
            }
            else if asset.url != nil { ContentUnavailableView("File Is Stored", systemImage: "doc", description: Text("Use Share or Save to open a copy.")) }
            else { ProgressView().tint(.white) }
            if movie, asset.image != nil, asset.url == nil, asset.error == nil, previews.activeID == item.id {
                ProgressView("Opening video…").tint(.white).padding().background(.black.opacity(0.6), in: Capsule())
            }
        }
        .foregroundStyle(.white)
        .simultaneousGesture(DragGesture(minimumDistance: 35).onEnded { value in
            guard !zoomed, !pdf, previews.activeID == item.id,
                  value.translation.height < -60, abs(value.translation.height) > abs(value.translation.width) * 1.5 else { return }
            details()
        })
        .accessibilityAction(named: "Show Details") { details() }
        .onAppear { updatePlayer() }
        .onChange(of: previews.activeID) { _, _ in updatePlayer() }
        .onChange(of: asset.url) { _, _ in updatePlayer() }
        .onDisappear { stopPlayer(); if previews.zoomedID == item.id { previews.zoomedID = nil } }
    }
    private func updatePlayer() {
        guard movie, previews.activeID == item.id, let url = asset.url else { stopPlayer(); return }
        if player == nil { player = AVPlayer(url: url) }
    }
    private func stopPlayer() { player?.pause(); player?.replaceCurrentItem(with: nil); player = nil }
}

private struct MediaDetailsView: View {
    let item: VaultItem
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("File") {
                    Text(item.name).textSelection(.enabled)
                    LabeledContent("Type", value: UTType(item.contentType)?.localizedDescription ?? item.contentType)
                    LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: Int64(item.byteCount), countStyle: .file))
                    if let album = item.album, !album.isEmpty { LabeledContent("Album", value: album) }
                }
                Section("Dates") {
                    if let date = item.captured { LabeledContent("Captured") { Text(date, format: .dateTime) } }
                    else { Text("Original capture date unavailable.") }
                    LabeledContent("Imported") { Text(item.added, format: .dateTime) }
                }
                if let duration = item.duration { Section { LabeledContent("Duration", value: Duration.seconds(duration).formatted(.time(pattern: .hourMinuteSecond))) } }
                if item.companionID != nil { Section { Text("Live Photo · hold the image to play. Both original resources are retained for export.") } }
                if let latitude = item.latitude, let longitude = item.longitude {
                    Section("Stored Location") { Text("\(latitude), \(longitude)").textSelection(.enabled) }
                }
                Section { NavigationLink("Backup Status") { CloudItemStatusView(item: item).environmentObject(vault.cloud) } }
            }
            .navigationTitle("Details").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}
#endif
