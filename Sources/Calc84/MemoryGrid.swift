#if os(iOS)
import SwiftUI
import UIKit
import ImageIO
import UniformTypeIdentifiers
import CalcCore

/// Reusable native cells keep a long library scrollable without loading every image.
struct MemoryGrid: UIViewControllerRepresentable {
    let sections: [LibrarySection]
    let engine: VaultEngine
    let columns: Int
    let style: GalleryStyle
    let grouping: String
    let selection: Set<UUID>
    let selecting: Bool
    let busy: Bool
    let setSelection: (Set<UUID>) -> Void
    let identity: String
    let open: (VaultItem) -> Void
    let action: (String, VaultItem) -> Void
    var viewerVault: VaultModel? = nil
    var contentRevision: UUID? = nil
    func makeUIViewController(context: Context) -> MemoryGridController { MemoryGridController(self) }
    func updateUIViewController(_ controller: MemoryGridController, context: Context) { controller.update(self) }
    static func dismantleUIViewController(_ controller: MemoryGridController, coordinator: ()) { controller.tearDown() }
}

final class MemoryGridController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private var model: MemoryGrid
    private lazy var layout = UICollectionViewCompositionalLayout { [weak self] _, environment in
        self?.makeSection(environment)
    }
    private lazy var grid = UICollectionView(frame: .zero, collectionViewLayout: layout)
    private let images = NSCache<NSUUID, UIImage>()
    private let scrubber = MonthScrubber()
    private let month = UILabel()
    private var hideMonth: DispatchWorkItem?
    private var lastWidth: CGFloat = 0
    private var currentSection = 0
    private var restoredVisibility = true
    private var dragSelection: GridDragSelection?
    private var mediaHost: MediaViewerController?
    init(_ model: MemoryGrid) { self.model = model; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self) }
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(coverPrivateContent), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resumeVisibleContent), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(releaseCache), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        view.backgroundColor = .clear
        images.totalCostLimit = 32 * 1024 * 1024
        grid.backgroundColor = .clear
        grid.dataSource = self; grid.delegate = self
        grid.alwaysBounceVertical = true; grid.showsVerticalScrollIndicator = false
        grid.contentInsetAdjustmentBehavior = .never
        grid.register(MemoryCell.self, forCellWithReuseIdentifier: "photo")
        grid.register(MonthHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "month")
        view.addSubview(grid); view.addSubview(scrubber); view.addSubview(month)
        dragSelection = GridDragSelection(grid: grid) { [weak self] selection in
            guard let self else { return }
            self.refreshSelection(selection)
            self.model.setSelection(selection)
        }
        configureDragSelection()
        month.textColor = .white; month.backgroundColor = .darkGray
        month.font = .preferredFont(forTextStyle: .headline)
        month.adjustsFontForContentSizeCategory = true
        month.textAlignment = .center; month.layer.cornerRadius = 9; month.clipsToBounds = true
        month.isUserInteractionEnabled = false; month.isAccessibilityElement = false; month.alpha = 0
        scrubber.changed = { [weak self] fraction in
            guard let self else { return }
            let offset = LibraryScrollPosition.offset(fraction: fraction, content: Double(self.grid.contentSize.height), viewport: Double(self.grid.bounds.height))
            self.grid.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
            self.updateDate(show: true)
        }
        scrubber.ended = { [weak self] in self?.scheduleHide() }
        scrubber.step = { [weak self] delta in self?.jumpSection(delta) }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        grid.frame = view.bounds
        scrubber.frame = CGRect(x: max(0, view.bounds.width - 44), y: 0, width: 44, height: view.bounds.height)
        if lastWidth != grid.bounds.width {
            dragSelection?.cancel()
            lastWidth = grid.bounds.width
            layout.invalidateLayout()
        }
        grid.layoutIfNeeded()
        updateDate(show: false)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !restoredVisibility { restoredVisibility = true; grid.reloadData() }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        dragSelection?.cancel()
        // The native zoom needs its source thumbnail while the viewer is open.
        // Privacy/lock and teardown still purge synchronously.
        if mediaHost == nil { clearImages(); restoredVisibility = false }
    }
    @objc private func coverPrivateContent() {
        clearImages(); restoredVisibility = false
    }
    @objc private func resumeVisibleContent() {
        guard viewIfLoaded?.window != nil, model.viewerVault?.unlocked != false else { return }
        if !restoredVisibility { restoredVisibility = true; grid.reloadData() }
    }
    @objc private func releaseCache() { images.removeAllObjects() }
    func tearDown() {
        model.viewerVault?.mediaViewerPresented = false
        mediaHost?.closeForPrivacy(); mediaHost = nil
        clearImages()
        NotificationCenter.default.removeObserver(self)
    }
    func clearImages() {
        dragSelection?.cancel()
        hideMonth?.cancel(); month.alpha = 0
        grid.layer.removeAllAnimations(); grid.alpha = 1
        images.removeAllObjects()
        for cell in grid.visibleCells.compactMap({ $0 as? MemoryCell }) { cell.clear() }
    }
    func update(_ next: MemoryGrid) {
        let newContent: Bool
        if let previous = model.contentRevision, let revision = next.contentRevision { newContent = previous != revision }
        else { newContent = model.sections != next.sections }
        let newLayout = model.columns != next.columns || model.style != next.style || model.grouping != next.grouping
        let reset = model.identity != next.identity
        let selectionChanged = model.selection != next.selection || model.selecting != next.selecting
        let anchorPath = (newContent || newLayout) ? grid.indexPathsForVisibleItems.sorted().first : nil
        let anchor = anchorPath.flatMap { item(at: $0)?.id }
        let relativeTop = anchorPath.flatMap { layout.layoutAttributesForItem(at: $0)?.frame.minY }.map { $0 - grid.contentOffset.y }
        if newContent || newLayout || reset { dragSelection?.cancel() }
        model = next
        guard isViewLoaded else { return }
        let bottom: CGFloat = model.style == .clearGlass && !model.selecting ? 88 : 8
        if grid.contentInset.bottom != bottom { grid.contentInset.bottom = bottom }
        if newContent { configureDragSelection() }
        else { dragSelection?.update(selection: model.selection, enabled: model.selecting && !model.busy) }
        if newContent || newLayout || reset {
            let change = {
                self.grid.reloadData(); self.layout.invalidateLayout(); self.grid.layoutIfNeeded()
                if reset { self.grid.setContentOffset(.zero, animated: false) }
                else if let anchor, let relativeTop, let path = self.path(for: anchor),
                        let frame = self.layout.layoutAttributesForItem(at: path)?.frame {
                    let offset = LibraryViewportAnchor.offset(itemTop: Double(frame.minY), relativeTop: Double(relativeTop),
                        minimum: Double(-self.grid.adjustedContentInset.top),
                        maximum: Double(self.grid.contentSize.height - self.grid.bounds.height + self.grid.adjustedContentInset.bottom))
                    self.grid.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
                }
            }
            if newLayout && !reset && view.window != nil && mediaHost == nil && !UIAccessibility.isReduceMotionEnabled {
                UIView.transition(with: grid, duration: 0.15, options: [.transitionCrossDissolve, .allowUserInteraction, .beginFromCurrentState], animations: change)
            } else { UIView.performWithoutAnimation(change) }
        } else if selectionChanged {
            refreshSelection(model.selection)
        }
        if newContent || newLayout || reset { updateDate(show: false) }
    }
    private func path(for id: UUID) -> IndexPath? {
        for (section, group) in model.sections.enumerated() {
            if let row = group.items.firstIndex(where: { $0.id == id }) { return IndexPath(item: row, section: section) }
        }
        return nil
    }
    private func open(_ item: VaultItem) {
        guard !model.selecting, let vault = model.viewerVault else { model.open(item); return }
        guard vault.unlocked, mediaHost == nil, presentedViewController == nil, view.window != nil else { return }
        dragSelection?.cancel()
        let host = MediaViewerController(items: model.sections.flatMap(\.items), initial: item.id, vault: vault,
            sourceView: { [weak self] id, preview in self?.transitionSource(id: id, preview: preview) },
            closed: { [weak self, weak vault] id in
                guard let self else { return }
                self.mediaHost = nil
                vault?.mediaViewerPresented = false
                if vault?.unlocked == true {
                    // The iOS 17/Reduce Motion fallback also returns to the current
                    // item, although it doesn't ask for a native zoom source.
                    _ = self.transitionSource(id: id, preview: nil)
                    DispatchQueue.main.async { [weak self] in
                        guard let self, vault?.unlocked == true, self.view.window != nil else { return }
                        let cell = self.path(for: id).flatMap { self.grid.cellForItem(at: $0) }
                        UIAccessibility.post(notification: .screenChanged, argument: cell)
                    }
                } else { self.clearImages() }
            })
        mediaHost = host
        vault.mediaViewerPresented = true
        present(host, animated: !UIAccessibility.isReduceMotionEnabled)
    }
    private func transitionSource(id: UUID, preview: UIImage?) -> UIView? {
        guard model.viewerVault?.unlocked == true, let path = path(for: id) else { return nil }
        if !restoredVisibility { restoredVisibility = true; grid.reloadData() }
        if grid.cellForItem(at: path) == nil { grid.scrollToItem(at: path, at: .centeredVertically, animated: false) }
        grid.layoutIfNeeded()
        guard let cell = grid.cellForItem(at: path) as? MemoryCell, cell.itemID == id else { return nil }
        cell.prepareTransition(preview)
        return cell.transitionView
    }
    private func configureDragSelection() {
        dragSelection?.configure(sections: model.sections.map { $0.items.map(\.id) },
                                 selection: model.selection, enabled: model.selecting && !model.busy)
    }
    private func refreshSelection(_ selection: Set<UUID>) {
        for cell in grid.visibleCells.compactMap({ $0 as? MemoryCell }) {
            if let id = cell.itemID { cell.setSelection(selection.contains(id), selecting: model.selecting) }
        }
    }
    func numberOfSections(in collectionView: UICollectionView) -> Int { model.sections.count }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { model.sections[section].items.count }
    private func item(at path: IndexPath) -> VaultItem? {
        guard model.sections.indices.contains(path.section), model.sections[path.section].items.indices.contains(path.item) else { return nil }
        return model.sections[path.section].items[path.item]
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt path: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photo", for: path) as! MemoryCell
        if let item = item(at: path) {
            cell.configure(item, engine: model.engine, cache: images)
            cell.contentView.layer.cornerRadius = model.style == .nightroom ? 12 : model.style == .timeline ? 12 : 0
            cell.setSelection((dragSelection?.selection ?? model.selection).contains(item.id), selecting: model.selecting)
        }
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt path: IndexPath) {
        if let item = item(at: path) { open(item) }
    }
    private func makeSection(_ environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let style = model.style
        let inset = CGFloat(style.inset), gap = CGFloat(style.gap)
        let available = max(1, environment.container.effectiveContentSize.width - inset * 2)
        let group: NSCollectionLayoutGroup
        if style == .timeline {
            let height = available * 0.61
            let hero = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(0.61), heightDimension: .fractionalHeight(1)))
            let small = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(0.5)))
            let side = NSCollectionLayoutGroup.vertical(layoutSize: .init(widthDimension: .fractionalWidth(0.39), heightDimension: .fractionalHeight(1)), repeatingSubitem: small, count: 2)
            side.interItemSpacing = .fixed(gap)
            group = .horizontal(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(height)), subitems: [hero, side])
            group.interItemSpacing = .fixed(gap)
            // Fractional widths include the gap. Flexible side width avoids overflow.
            hero.contentInsets.trailing = gap
            group.interItemSpacing = .fixed(0)
        } else {
            let count = max(2, model.columns)
            let height = (available - CGFloat(count - 1) * gap) / CGFloat(count) / style.aspectRatio
            let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1 / CGFloat(count)), heightDimension: .fractionalHeight(1)))
            group = .horizontal(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(height)), repeatingSubitem: item, count: count)
            group.interItemSpacing = .fixed(gap)
        }
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = gap
        section.contentInsets = .init(top: 0, leading: inset, bottom: style == .timeline ? 18 : 12, trailing: inset)
        let height = UIFont.preferredFont(forTextStyle: style == .contactSheet ? .subheadline : .headline).lineHeight + 24
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(height)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        header.pinToVisibleBounds = style == .contactSheet || style == .photoLibrary
        section.boundarySupplementaryItems = [header]
        return section
    }
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at path: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "month", for: path) as! MonthHeader
        let section = model.sections[path.section]
        let format: Date.FormatStyle = model.grouping == "Years" ? .dateTime.year() : model.grouping == "Days" ? .dateTime.month(.wide).day().year() : .dateTime.month(.wide).year()
        header.configure(section.date.formatted(format), count: section.items.count, style: model.style)
        return header
    }
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? MemoryCell)?.clear()
    }
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt path: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard !model.selecting, let item = item(at: path) else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let actions: [(String, String, String)] = item.deletedAt == nil
                ? [("Open", "arrow.up.left.and.arrow.down.right", "open"),
                   (item.favorite == true ? "Remove Favorite" : "Favorite", "heart", "favorite"),
                   ("Save or Share", "square.and.arrow.up", "export"), ("Move to Album", "rectangle.stack", "album"),
                   ("Move to Recently Deleted", "trash", "delete")]
                : [("Restore", "arrow.uturn.backward", "restore")]
            return UIMenu(children: actions.map { title, symbol, key in
                UIAction(title: title, image: UIImage(systemName: symbol), attributes: key == "delete" ? .destructive : []) { _ in
                    if key == "open" { self?.open(item) } else { self?.model.action(key, item) }
                }
            })
        }
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) { updateDate(show: scrollView.isDragging || scrollView.isDecelerating || scrubber.isDragging) }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { hideMonth?.cancel(); updateDate(show: true) }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) { if !decelerate { scheduleHide() } }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { scheduleHide() }
    private func updateDate(show: Bool) {
        guard isViewLoaded else { return }
        let fraction = LibraryScrollPosition.fraction(offset: Double(grid.contentOffset.y), content: Double(grid.contentSize.height), viewport: Double(grid.bounds.height))
        scrubber.fraction = fraction
        scrubber.isHidden = model.selecting || model.sections.isEmpty || grid.contentSize.height <= grid.bounds.height
        // Derive the badge from real visible cells, including long months and short sections.
        let visible = grid.indexPathsForVisibleItems.sorted().filter { path in
            guard let rect = layout.layoutAttributesForItem(at: path)?.frame else { return false }
            return rect.maxY > grid.contentOffset.y + 1
        }
        if let first = visible.first, model.sections.indices.contains(first.section) {
            currentSection = first.section
            let text = model.sections[first.section].date.formatted(.dateTime.month(.abbreviated).year()).uppercased()
            month.text = text; scrubber.accessibilityValue = text
        }
        scrubber.layoutIfNeeded()
        let size = month.sizeThatFits(CGSize(width: 240, height: 80))
        let width = min(view.bounds.width - 60, max(120, size.width + 24))
        let height = max(42, size.height + 16)
        month.frame = CGRect(x: view.bounds.width - width - 36, y: max(4, min(view.bounds.height - height - 4, scrubber.thumbCenter - height / 2)), width: width, height: height)
        if show, !scrubber.isHidden { hideMonth?.cancel(); month.alpha = 1 }
    }
    private func scheduleHide() {
        hideMonth?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.16) { self.month.alpha = 0 }
        }
        hideMonth = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }
    private func jumpSection(_ delta: Int) {
        guard !model.sections.isEmpty else { return }
        let next = max(0, min(model.sections.count - 1, currentSection + delta))
        let path = IndexPath(item: 0, section: next)
        if let header = layout.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: path) {
            let maxY = max(0, grid.contentSize.height - grid.bounds.height)
            grid.setContentOffset(CGPoint(x: 0, y: min(maxY, header.frame.minY)), animated: false)
            updateDate(show: true); scheduleHide()
        }
    }
}

private final class MonthScrubber: UIView {
    var changed: ((Double) -> Void)?
    var ended: (() -> Void)?
    var step: ((Int) -> Void)?
    var fraction: Double = 0 { didSet { setNeedsLayout() } }
    private(set) var isDragging = false
    private let thumb = UIView()
    private let grip = UILabel()
    private var grabOffset: CGFloat = 0
    var thumbCenter: CGFloat { thumb.frame.midY }
    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true; accessibilityLabel = "Scroll by month"; accessibilityTraits = [.adjustable]
        accessibilityHint = "Swipe up or down to jump between date sections."
        thumb.backgroundColor = .secondaryLabel; thumb.layer.cornerRadius = 8
        thumb.isUserInteractionEnabled = false
        grip.text = "⋮"; grip.textColor = .systemBackground; grip.textAlignment = .center; grip.font = .boldSystemFont(ofSize: 18)
        thumb.addSubview(grip); addSubview(thumb)
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(drag(_:))))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        thumb.frame = CGRect(x: 25, y: 8 + CGFloat(fraction) * max(0, bounds.height - 64), width: 14, height: 48)
        grip.frame = thumb.bounds
    }
    // The rail is visually narrow, but its draggable thumb has a 44-point hit target.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        isDragging || CGRect(x: 0, y: thumb.frame.minY - 4, width: bounds.width, height: 56).contains(point)
    }
    @objc private func drag(_ gesture: UIPanGestureRecognizer) {
        let y = gesture.location(in: self).y
        if gesture.state == .began { isDragging = true; grabOffset = y - thumb.frame.midY }
        if gesture.state == .began || gesture.state == .changed {
            let denominator = max(1, bounds.height - 64)
            changed?(Double(max(0, min(1, (y - grabOffset - 32) / denominator))))
        }
        if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed { isDragging = false; ended?() }
    }
    override func accessibilityIncrement() { step?(1) }
    override func accessibilityDecrement() { step?(-1) }
}

private final class MonthHeader: UICollectionReusableView {
    private let title = UILabel(), count = UILabel()
    private var inset: CGFloat = 16
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        title.font = .preferredFont(forTextStyle: .headline); title.adjustsFontForContentSizeCategory = true
        count.font = .preferredFont(forTextStyle: .subheadline); count.textColor = .secondaryLabel; count.adjustsFontForContentSizeCategory = true
        addSubview(title); addSubview(count)
        isAccessibilityElement = true; accessibilityTraits = [.header]
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(_ value: String, count: Int, style: GalleryStyle) {
        title.text = value; self.count.text = "\(count) items"; accessibilityLabel = "\(value), \(count) items"
        inset = style.inset > 0 ? 0 : 16
        let size: CGFloat = style == .timeline ? 21 : style == .contactSheet ? 14 : 16
        title.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: size, weight: .semibold))
        self.count.font = UIFont.preferredFont(forTextStyle: .caption1)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        count.sizeToFit()
        count.frame = CGRect(x: bounds.width - count.bounds.width - inset, y: 0, width: count.bounds.width, height: bounds.height)
        title.frame = CGRect(x: inset, y: 0, width: max(0, count.frame.minX - inset - 12), height: bounds.height)
    }
}

private final class MemoryCell: UICollectionViewCell {
    private let photo = UIImageView(), duration = UILabel(), favorite = UIImageView(), check = UIImageView()
    private var task: Task<Void, Never>?
    private var hasThumbnail = false
    private var selectionState: (selected: Bool, selecting: Bool)?
    private(set) var itemID: UUID?
    var transitionView: UIView { photo }
    func prepareTransition(_ image: UIImage?) {
        if !hasThumbnail, let image { photo.image = image }
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .secondarySystemBackground; contentView.clipsToBounds = true
        photo.contentMode = .scaleAspectFill; photo.clipsToBounds = true
        duration.font = .preferredFont(forTextStyle: .caption1); duration.adjustsFontForContentSizeCategory = true; duration.textColor = .white
        duration.layer.shadowColor = UIColor.black.cgColor; duration.layer.shadowOpacity = 1; duration.layer.shadowRadius = 3; duration.layer.shadowOffset = .zero
        favorite.image = UIImage(systemName: "heart.fill"); favorite.tintColor = .white
        favorite.layer.shadowColor = UIColor.black.cgColor; favorite.layer.shadowOpacity = 1; favorite.layer.shadowRadius = 3
        check.backgroundColor = UIColor.black.withAlphaComponent(0.35); check.layer.cornerRadius = 13
        [photo, duration, favorite, check].forEach { contentView.addSubview($0) }
        isAccessibilityElement = true; accessibilityTraits = [.button]
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews(); photo.frame = contentView.bounds
        let height = ceil(duration.font.lineHeight) + 8
        duration.frame = CGRect(x: 6, y: max(0, bounds.height - height - 6), width: max(0, bounds.width - 12), height: height)
        favorite.frame = CGRect(x: 7, y: 7, width: 17, height: 17)
        check.frame = CGRect(x: bounds.width - 32, y: 6, width: 26, height: 26)
    }
    func configure(_ item: VaultItem, engine: VaultEngine, cache: NSCache<NSUUID, UIImage>) {
        clear(); itemID = item.id
        accessibilityLabel = item.name + ", " + item.chronologicalDate.formatted(date: .abbreviated, time: .omitted)
        favorite.isHidden = item.favorite != true
        if let seconds = item.duration, seconds.isFinite, seconds >= 0, seconds < Double(Int.max) {
            duration.text = String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
        } else { duration.text = nil }
        let kind = UTType(item.contentType)?.conforms(to: .movie) == true ? "Video" : item.companionID != nil ? "Live Photo" : UTType(item.contentType)?.conforms(to: .image) == true ? "Photo" : "File"
        accessibilityLabel = [kind, item.name, item.chronologicalDate.formatted(date: .abbreviated, time: .omitted),
                              duration.text, item.favorite == true ? "Favorite" : nil].compactMap { $0 }.joined(separator: ", ")
        setNeedsLayout()
        if let image = cache.object(forKey: item.id as NSUUID) { photo.image = image; hasThumbnail = true; return }
        photo.image = UIImage(systemName: item.duration != nil ? "film" : "doc"); photo.tintColor = .tertiaryLabel
        task = Task { [weak self] in
            guard item.thumbnailID != nil || (item.byteCount <= 8 * 1024 * 1024 && UTType(item.contentType)?.conforms(to: .image) == true),
                  let data = try? await engine.contents(id: item.thumbnailID ?? item.id), !Task.isCancelled else { return }
            let worker = Task.detached(priority: .utility) { () -> UIImage? in
                guard !Task.isCancelled, let source = CGImageSourceCreateWithData(data as CFData, nil), let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 420,
                    kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
                guard !Task.isCancelled else { return nil }
                return UIImage(cgImage: bitmap)
            }
            let image = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
            guard !Task.isCancelled, let self, self.itemID == item.id, let image else { return }
            cache.setObject(image, forKey: item.id as NSUUID, cost: (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0))
            self.photo.image = image; self.hasThumbnail = true
        }
    }
    func setSelection(_ selected: Bool, selecting: Bool) {
        if let previous = selectionState, previous.selected == selected, previous.selecting == selecting { return }
        selectionState = (selected, selecting)
        check.isHidden = !selecting
        check.image = UIImage(systemName: selected ? "checkmark.circle.fill" : "circle")
        check.tintColor = selected ? .systemBlue : .white
        photo.alpha = selected ? 0.7 : 1
        accessibilityTraits = selected ? [.button, .selected] : [.button]
        accessibilityHint = selecting ? (selected ? "Double-tap to deselect." : "Double-tap to select.") : "Double-tap to open."
    }
    func clear() { task?.cancel(); task = nil; photo.image = nil; itemID = nil; hasThumbnail = false; selectionState = nil }
    override func prepareForReuse() { super.prepareForReuse(); clear() }
}
#endif
