#if os(iOS)
import UIKit
import CalcCore

/// One-finger horizontal intent selects; vertical intent stays with native scrolling.
@MainActor
final class GridDragSelection: NSObject, UIGestureRecognizerDelegate {
    private weak var grid: UICollectionView?
    private let changed: (Set<UUID>) -> Void
    private lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(drag(_:)))
    private var sections: [[UUID]] = []
    private var items: [UUID] = []
    private var indices: [IndexPath: Int] = [:]
    private var start: IndexPath?
    private var sweep: LibrarySelectionSweep?
    private var endpoint: Int?
    private var location = CGPoint.zero
    private var displayLink: CADisplayLink?
    private(set) var selection = Set<UUID>()

    init(grid: UICollectionView, changed: @escaping (Set<UUID>) -> Void) {
        self.grid = grid; self.changed = changed
        super.init()
        pan.minimumNumberOfTouches = 1; pan.maximumNumberOfTouches = 1
        pan.delegate = self; pan.cancelsTouchesInView = true; pan.isEnabled = false
        grid.addGestureRecognizer(pan)
        grid.panGestureRecognizer.require(toFail: pan)
    }
    func configure(sections: [[UUID]], selection: Set<UUID>, enabled: Bool) {
        if self.sections != sections || !enabled || (sweep != nil && self.selection != selection) { cancel() }
        if self.sections != sections {
            self.sections = sections; items = []; indices = [:]
            for (section, ids) in sections.enumerated() {
                for (row, id) in ids.enumerated() {
                    indices[IndexPath(item: row, section: section)] = items.count
                    items.append(id)
                }
            }
        }
        update(selection: selection, enabled: enabled)
    }
    func update(selection: Set<UUID>, enabled: Bool) {
        if !enabled || (sweep != nil && self.selection != selection) { cancel() }
        self.selection = selection
        if pan.isEnabled != enabled { pan.isEnabled = enabled }
    }
    func cancel() {
        finish()
        // Reset an in-progress recognizer when the data, layout or presentation changes.
        let enabled = pan.isEnabled
        pan.isEnabled = false; pan.isEnabled = enabled
    }
    private func finish() {
        displayLink?.invalidate(); displayLink = nil
        sweep = nil; endpoint = nil; start = nil
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === pan, let grid else { return false }
        // Headers and empty space remain scroll targets, even over pinned cells.
        var target = touch.view
        while let view = target, view !== grid {
            if let cell = view as? UICollectionViewCell {
                start = grid.indexPath(for: cell)
                return start != nil
            }
            target = view.superview
        }
        return false
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === pan, start != nil, let grid else { return false }
        let movement = pan.translation(in: grid)
        return abs(movement.x) > abs(movement.y)
    }
    @objc private func drag(_ recognizer: UIPanGestureRecognizer) {
        guard let grid else { finish(); return }
        // The superview's coordinates stay fixed while the grid's bounds scroll.
        location = recognizer.location(in: grid.superview)
        switch recognizer.state {
        case .began:
            guard let start, let index = indices[start],
                  let sweep = LibrarySelectionSweep(items: items, anchor: index, selection: selection) else { return }
            self.sweep = sweep
            apply(index)
            updateEndpoint()
            let target = SelectionScrollTarget { [weak self] link in self?.scroll(link) }
            let link = CADisplayLink(target: target, selector: #selector(SelectionScrollTarget.tick(_:)))
            displayLink = link; link.add(to: .main, forMode: .common)
        case .changed: updateEndpoint()
        case .ended: updateEndpoint(); finish()
        case .cancelled, .failed: finish()
        default: break
        }
    }
    private func apply(_ index: Int) {
        guard index != endpoint, let result = sweep?.selection(through: index) else { return }
        endpoint = index
        guard result != selection else { return }
        selection = result; changed(result)
    }
    private func updateEndpoint() {
        guard sweep != nil, let grid else { return }
        var point = grid.convert(location, from: grid.superview)
        point.x = max(grid.bounds.minX + 1, min(grid.bounds.maxX - 1, point.x))
        point.y = max(grid.bounds.minY + 1, min(grid.bounds.maxY - 1, point.y))
        if let path = grid.indexPathForItem(at: point), let index = indices[path] { apply(index); return }
        // Cross the thin gutters, date headers and incomplete final rows without gaps.
        let cells = grid.collectionViewLayout.layoutAttributesForElements(in: grid.bounds)?.filter {
            $0.representedElementCategory == .cell
        } ?? []
        func distance(_ rect: CGRect) -> CGFloat {
            let x = max(0, max(rect.minX - point.x, point.x - rect.maxX))
            let y = max(0, max(rect.minY - point.y, point.y - rect.maxY))
            return x * x + y * y
        }
        if let nearest = cells.min(by: { distance($0.frame) < distance($1.frame) }),
           let index = indices[nearest.indexPath] { apply(index) }
    }
    private func scroll(_ link: CADisplayLink) {
        guard sweep != nil, let grid, grid.window != nil else { finish(); return }
        let point = grid.convert(location, from: grid.superview)
        let speed = LibrarySelectionSweep.scrollSpeed(location: Double(point.y - grid.bounds.minY), viewport: Double(grid.bounds.height))
        guard speed != 0 else { return }
        let minimum = -grid.adjustedContentInset.top
        let maximum = max(minimum, grid.contentSize.height - grid.bounds.height + grid.adjustedContentInset.bottom)
        let seconds = min(1.0 / 30, max(0, link.targetTimestamp - link.timestamp))
        let offset = max(minimum, min(maximum, grid.contentOffset.y + CGFloat(speed * seconds)))
        guard offset != grid.contentOffset.y else { return }
        grid.setContentOffset(CGPoint(x: grid.contentOffset.x, y: offset), animated: false)
        grid.layoutIfNeeded(); updateEndpoint()
    }
}

/// CADisplayLink retains its target; the callback captures the selection controller weakly.
@MainActor
private final class SelectionScrollTarget: NSObject {
    let action: (CADisplayLink) -> Void
    init(_ action: @escaping (CADisplayLink) -> Void) { self.action = action }
    @objc func tick(_ link: CADisplayLink) { action(link) }
}
#endif
