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
    let portrait: Bool
    let grouping: String
    let selection: Set<UUID>
    let selecting: Bool
    let busy: Bool
    let setSelection: (Set<UUID>) -> Void
    let identity: String
    let open: (VaultItem) -> Void
    let action: (String, VaultItem) -> Void
    func makeUIViewController(context: Context) -> MemoryGridController { MemoryGridController(self) }
    func updateUIViewController(_ controller: MemoryGridController, context: Context) { controller.update(self) }
    static func dismantleUIViewController(_ controller: MemoryGridController, coordinator: ()) { controller.clearImages() }
}

final class MemoryGridController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private var model: MemoryGrid
    private let layout = UICollectionViewFlowLayout()
    private lazy var grid = UICollectionView(frame: .zero, collectionViewLayout: layout)
    private let images = NSCache<NSUUID, UIImage>()
    private let scrubber = MonthScrubber()
    private let month = UILabel()
    private var hideMonth: DispatchWorkItem?
    private var lastWidth: CGFloat = 0
    private var currentSection = 0
    private var restoredVisibility = true
    private var dragSelection: GridDragSelection?
    init(_ model: MemoryGrid) { self.model = model; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        images.totalCostLimit = 32 * 1024 * 1024
        grid.backgroundColor = .systemBackground
        grid.dataSource = self; grid.delegate = self
        grid.alwaysBounceVertical = true; grid.showsVerticalScrollIndicator = false
        grid.contentInsetAdjustmentBehavior = .never
        layout.minimumLineSpacing = 1; layout.minimumInteritemSpacing = 1
        layout.sectionHeadersPinToVisibleBounds = true
        grid.register(MemoryCell.self, forCellWithReuseIdentifier: "photo")
        grid.register(MonthHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "month")
        view.addSubview(grid); view.addSubview(scrubber); view.addSubview(month)
        dragSelection = GridDragSelection(grid: grid) { [weak self] selection in
            guard let self else { return }
            self.refreshSelection(selection)
            self.model.setSelection(selection)
        }
        configureDragSelection()
        month.textColor = .white; month.backgroundColor = UIColor(red: 0.84, green: 0, blue: 0.23, alpha: 1)
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
        clearImages(); restoredVisibility = false
    }
    func clearImages() {
        dragSelection?.cancel()
        hideMonth?.cancel(); month.alpha = 0
        images.removeAllObjects()
        for cell in grid.visibleCells.compactMap({ $0 as? MemoryCell }) { cell.clear() }
    }
    func update(_ next: MemoryGrid) {
        let newContent = model.sections != next.sections
        let newLayout = model.columns != next.columns || model.portrait != next.portrait || model.grouping != next.grouping
        let reset = model.identity != next.identity
        let anchor = grid.indexPathsForVisibleItems.sorted().first.flatMap { item(at: $0)?.id }
        if newContent || newLayout || reset { dragSelection?.cancel() }
        model = next
        guard isViewLoaded else { return }
        configureDragSelection()
        if newContent || newLayout || reset {
            grid.reloadData(); layout.invalidateLayout(); grid.layoutIfNeeded()
            if reset { grid.setContentOffset(.zero, animated: false) }
            else if newLayout, let anchor {
                for (section, group) in model.sections.enumerated() {
                    if let row = group.items.firstIndex(where: { $0.id == anchor }) {
                        grid.scrollToItem(at: IndexPath(item: row, section: section), at: .top, animated: false); break
                    }
                }
            }
        } else {
            refreshSelection(model.selection)
        }
        updateDate(show: false)
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
            cell.setSelection((dragSelection?.selection ?? model.selection).contains(item.id), selecting: model.selecting)
        }
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt path: IndexPath) {
        if let item = item(at: path) { model.open(item) }
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt path: IndexPath) -> CGSize {
        let count = CGFloat(max(2, min(6, model.columns)))
        let width = floor((collectionView.bounds.width - count + 1) / count)
        return CGSize(width: max(1, width), height: max(1, floor(width * (model.portrait ? 1.65 : 1))))
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        CGSize(width: collectionView.bounds.width, height: UIFont.preferredFont(forTextStyle: .headline).lineHeight + 26)
    }
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at path: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "month", for: path) as! MonthHeader
        let section = model.sections[path.section]
        let format: Date.FormatStyle = model.grouping == "Years" ? .dateTime.year() : model.grouping == "Days" ? .dateTime.month(.wide).day().year() : .dateTime.month(.wide).year()
        header.configure(section.date.formatted(format), count: section.items.count)
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
                UIAction(title: title, image: UIImage(systemName: symbol), attributes: key == "delete" ? .destructive : []) { _ in self?.model.action(key, item) }
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
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        title.font = .preferredFont(forTextStyle: .headline); title.adjustsFontForContentSizeCategory = true
        count.font = .preferredFont(forTextStyle: .subheadline); count.textColor = .secondaryLabel; count.adjustsFontForContentSizeCategory = true
        addSubview(title); addSubview(count)
        isAccessibilityElement = true; accessibilityTraits = [.header]
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(_ value: String, count: Int) { title.text = value; self.count.text = "\(count)"; accessibilityLabel = "\(value), \(count) items" }
    override func layoutSubviews() {
        super.layoutSubviews()
        count.sizeToFit()
        count.frame = CGRect(x: bounds.width - count.bounds.width - 18, y: 0, width: count.bounds.width, height: bounds.height)
        title.frame = CGRect(x: 16, y: 0, width: max(0, count.frame.minX - 28), height: bounds.height)
    }
}

private final class MemoryCell: UICollectionViewCell {
    private let photo = UIImageView(), duration = UILabel(), favorite = UIImageView(), check = UIImageView()
    private var task: Task<Void, Never>?
    private(set) var itemID: UUID?
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
        if let image = cache.object(forKey: item.id as NSUUID) { photo.image = image; return }
        photo.image = UIImage(systemName: item.duration != nil ? "film" : "doc"); photo.tintColor = .tertiaryLabel
        task = Task { [weak self] in
            guard item.thumbnailID != nil || (item.byteCount <= 8 * 1024 * 1024 && UTType(item.contentType)?.conforms(to: .image) == true),
                  let data = try? await engine.contents(id: item.thumbnailID ?? item.id), !Task.isCancelled else { return }
            let image = await Task.detached(priority: .utility) { () -> UIImage? in
                guard let source = CGImageSourceCreateWithData(data as CFData, nil), let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 420,
                    kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
                return UIImage(cgImage: bitmap)
            }.value
            guard !Task.isCancelled, let self, self.itemID == item.id, let image else { return }
            cache.setObject(image, forKey: item.id as NSUUID, cost: (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0))
            self.photo.image = image
        }
    }
    func setSelection(_ selected: Bool, selecting: Bool) {
        check.isHidden = !selecting
        check.image = UIImage(systemName: selected ? "checkmark.circle.fill" : "circle")
        check.tintColor = selected ? .systemBlue : .white
        photo.alpha = selected ? 0.7 : 1
        accessibilityTraits = selected ? [.button, .selected] : [.button]
        accessibilityHint = selecting ? (selected ? "Double-tap to deselect." : "Double-tap to select.") : "Double-tap to open."
    }
    func clear() { task?.cancel(); task = nil; photo.image = nil; itemID = nil }
    override func prepareForReuse() { super.prepareForReuse(); clear() }
}
#endif
