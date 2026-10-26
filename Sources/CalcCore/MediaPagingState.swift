import Foundation

/// Requested navigation is separate from the page that has actually settled.
/// A cancelled swipe cannot switch playback or overwrite a newer button request.
public struct MediaPagingState: Equatable {
    public let count: Int
    public private(set) var visible: Int
    public private(set) var requested: Int
    public private(set) var revision: UInt64 = 0

    public init(count: Int, initial: Int) {
        self.count = max(0, count)
        let index = max(0, min(initial, max(0, count - 1)))
        visible = index; requested = index
    }
    public mutating func request(_ index: Int) {
        guard count > 0 else { return }
        let next = max(0, min(index, count - 1))
        guard next != requested else { return }
        requested = next; revision &+= 1
    }
    public mutating func settled(at index: Int, startedAt ticket: UInt64) {
        guard (0..<count).contains(index) else { return }
        visible = index
        if revision == ticket { requested = index }
    }
}

public enum LibraryViewportAnchor {
    /// Restore an item's pixel offset, clamping to the new scrollable bounds.
    public static func offset(itemTop: Double, relativeTop: Double, minimum: Double, maximum: Double) -> Double {
        guard itemTop.isFinite, relativeTop.isFinite, minimum.isFinite, maximum.isFinite else { return 0 }
        return min(max(minimum, maximum), max(minimum, itemTop - relativeTop))
    }
}
