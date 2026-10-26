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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var previews: MediaPreviewStore
    let close: () -> Void
    let didShow: (UUID) -> Void
    @State private var navigation: MediaPagingState
    @State private var sheet: MediaSheet?
    @AppStorage("libraryGlassTint") private var tintValue = GlassTint.plum.rawValue
    private var glassTint: GlassTint { GlassTint(rawValue: tintValue) ?? .plum }
    private enum MediaSheet: Identifiable {
        case details(VaultItem), export(VaultItem)
        var id: String { switch self { case .details(let item): return "details-" + item.id.uuidString; case .export(let item): return "export-" + item.id.uuidString } }
    }
    init(items: [VaultItem], initial: UUID, previews: MediaPreviewStore,
         close: @escaping () -> Void, didShow: @escaping (UUID) -> Void) {
        self.items = items; self.initial = initial
        self.previews = previews; self.close = close; self.didShow = didShow
        _navigation = State(initialValue: MediaPagingState(count: items.count, initial: items.firstIndex(where: { $0.id == initial }) ?? 0))
    }
    private var position: Int { navigation.visible }
    private var current: VaultItem? {
        guard items.indices.contains(position) else { return nil }
        return vault.items.first(where: { $0.id == items[position].id })
    }
    var body: some View {
        NavigationStack {
            if let current {
                VStack(spacing: 0) {
                    MediaPager(items: items, navigation: $navigation, previews: previews, reduceMotion: reduceMotion)
                    Button { sheet = .details(current) } label: {
                        VStack(spacing: 4) {
                            Capsule().fill(.secondary).frame(width: 30, height: 4)
                            Text("Details").font(.caption)
                        }.frame(width: 104).frame(minHeight: 44)
                            .modifier(ArithenGlass(tint: glassTint, shape: Capsule()))
                    }
                    .padding(.vertical, 4)
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityHint("Opens file information. You can also swipe up on this handle.")
                    .simultaneousGesture(DragGesture(minimumDistance: 12).onEnded { value in
                        guard value.translation.height < -20,
                              abs(value.translation.height) > abs(value.translation.width) * 1.5 else { return }
                        sheet = .details(current)
                    })
                }
                .background(Color.black)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done", action: close) }
                    ToolbarItem(placement: .principal) { Text("\(position + 1) of \(items.count)").font(.subheadline).foregroundStyle(.secondary) }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Share or Save", systemImage: "square.and.arrow.up") { sheet = .export(current) }
                    }
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Previous", systemImage: "chevron.left") { navigation.request(navigation.requested - 1) }.disabled(navigation.requested == 0)
                        Spacer()
                        Button(current.favorite == true ? "Unfavorite" : "Favorite", systemImage: current.favorite == true ? "heart.fill" : "heart") {
                            vault.update(current, favorite: current.favorite != true)
                        }.disabled(vault.busy)
                        Spacer()
                        Button("Details", systemImage: "info.circle") { sheet = .details(current) }
                            .accessibilityHint("You can also swipe up on the Details handle below the image.")
                        Spacer()
                        Button("Next", systemImage: "chevron.right") { navigation.request(navigation.requested + 1) }.disabled(navigation.requested + 1 >= items.count)
                    }
                }
            }
        }
        .tint(glassTint == .clear ? .primary : glassTint.color)
        .onAppear { focus(position) }
        .onChange(of: position) { _, index in focus(index) }
        .onChange(of: vault.unlocked) { _, unlocked in if !unlocked { sheet = nil; previews.clear() } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in previews.trimToCurrent() }
        .sheet(item: $sheet) { request in
            switch request {
            case .export(let item): ExportMediaView(items: [item]).environmentObject(vault)
            case .details(let item): MediaDetailsView(item: item).environmentObject(vault)
            }
        }
    }
    private func focus(_ index: Int) {
        guard vault.unlocked, items.indices.contains(index) else { return }
        didShow(items[index].id)
        // Reappearing after a sheet/cancelled presentation isn't a page change.
        // Preserve the current image's zoom and prepared resources.
        if previews.activeID != items[index].id { previews.focus(index, items: items, vault: vault) }
    }
}

/// Native interactive paging keeps the outgoing page visible throughout a swipe.
private struct MediaPager: UIViewControllerRepresentable {
    let items: [VaultItem]
    @Binding var navigation: MediaPagingState
    @ObservedObject var previews: MediaPreviewStore
    let reduceMotion: Bool
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIPageViewController {
        let page = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        page.dataSource = context.coordinator; page.delegate = context.coordinator
        page.view.backgroundColor = .black
        if let initial = context.coordinator.controller(navigation.visible) { page.setViewControllers([initial], direction: .forward, animated: false) }
        return page
    }
    func updateUIViewController(_ page: UIPageViewController, context: Context) {
        let coordinator = context.coordinator; coordinator.parent = self
        page.view.subviews.compactMap { $0 as? UIScrollView }.forEach { $0.isScrollEnabled = previews.zoomedID != previews.activeID || previews.zoomedID == nil }
        coordinator.reconcile(page)
    }
    static func dismantleUIViewController(_ page: UIPageViewController, coordinator: Coordinator) {
        coordinator.alive = false
        page.dataSource = nil; page.delegate = nil; coordinator.controllers.removeAll()
    }
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: MediaPager
        var controllers: [Int: MediaPageHost] = [:]
        var transitioning = false
        var alive = true
        var interactionRevision: UInt64 = 0
        var operation: UInt64 = 0
        init(_ parent: MediaPager) { self.parent = parent }
        func reconcile(_ page: UIPageViewController) {
            guard alive, !transitioning,
                  let old = (page.viewControllers?.first as? MediaPageHost)?.index, old != parent.navigation.requested,
                  let target = controller(parent.navigation.requested) else { return }
            transitioning = true
            let ticket = parent.navigation.revision
            operation &+= 1
            let attempt = operation
            page.setViewControllers([target], direction: target.index > old ? .forward : .reverse, animated: !parent.reduceMotion) { [weak self, weak page] _ in
                // Nonanimated completions can run inside updateUIViewController.
                DispatchQueue.main.async {
                    guard let self, self.alive, self.operation == attempt, let page,
                          let shown = page.viewControllers?.first as? MediaPageHost else { return }
                    self.parent.navigation.settled(at: shown.index, startedAt: ticket)
                    self.transitioning = false; self.trim(around: shown.index)
                    self.reconcile(page)
                }
            }
        }
        func controller(_ index: Int) -> MediaPageHost? {
            guard parent.items.indices.contains(index) else { return nil }
            if let controller = controllers[index] { return controller }
            let item = parent.items[index]
            let root = MediaPage(item: item, asset: parent.previews.asset(for: item), previews: parent.previews)
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
        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            operation &+= 1; transitioning = true; interactionRevision = parent.navigation.revision
        }
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard alive else { return }
            transitioning = false
            if let host = pageViewController.viewControllers?.first as? MediaPageHost {
                parent.navigation.settled(at: host.index, startedAt: interactionRevision)
                trim(around: host.index)
            }
            reconcile(pageViewController)
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
        .onAppear { updatePlayer() }
        .onChange(of: previews.activeID) { _, _ in updatePlayer() }
        .onChange(of: asset.url) { _, _ in updatePlayer() }
        .onDisappear {
            // Pause covered content, but keep playback position during a cancelled
            // transition. Committed page changes/owner cleanup release the player.
            player?.pause()
            if previews.activeID != item.id {
                stopPlayer()
                if previews.zoomedID == item.id { previews.zoomedID = nil }
            }
        }
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
