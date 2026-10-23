import Foundation

/// A drag applies one operation to a contiguous range in the displayed order.
/// Reversing the drag restores the original state of items left outside the range.
public struct LibrarySelectionSweep {
    private let items: [UUID]
    private let anchor: Int
    private let baseline: Set<UUID>
    private let adding: Bool

    public init?(items: [UUID], anchor: Int, selection: Set<UUID>) {
        guard items.indices.contains(anchor) else { return nil }
        self.items = items; self.anchor = anchor; baseline = selection
        adding = !selection.contains(items[anchor])
    }
    public func selection(through index: Int) -> Set<UUID>? {
        guard items.indices.contains(index) else { return nil }
        let range = items[min(anchor, index)...max(anchor, index)]
        return adding ? baseline.union(range) : baseline.subtracting(range)
    }
    /// Points per second; only an active selection gesture uses edge scrolling.
    public static func scrollSpeed(location: Double, viewport: Double) -> Double {
        guard location.isFinite, viewport.isFinite, viewport > 0 else { return 0 }
        let edge = min(64, viewport / 4)
        if location < edge { return -600 * min(1, max(0, (edge - location) / edge)) }
        if location > viewport - edge { return 600 * min(1, max(0, (location - viewport + edge) / edge)) }
        return 0
    }
}
