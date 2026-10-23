import Foundation

public enum LibraryLayout: String, CaseIterable, Sendable {
    case timeline, photos
    public var title: String { self == .timeline ? "Vault Timeline" : "Photos Layout" }
}
public enum LibraryDateSource: String, CaseIterable, Sendable {
    case captured, imported
    public var title: String { self == .captured ? "Date Captured" : "Date Imported" }
}
public struct LibrarySection: Identifiable, Equatable {
    public let id: String
    public let date: Date
    public let items: [VaultItem]
}

/// The same clamped mapping drives the visible scroll handle and drag-to-date control.
public enum LibraryScrollPosition {
    public static func fraction(offset: Double, content: Double, viewport: Double) -> Double {
        guard offset.isFinite, content.isFinite, viewport.isFinite, content > viewport else { return 0 }
        return min(1, max(0, offset / (content - viewport)))
    }
    public static func offset(fraction: Double, content: Double, viewport: Double) -> Double {
        guard fraction.isFinite, content.isFinite, viewport.isFinite else { return 0 }
        return min(1, max(0, fraction)) * max(0, content - viewport)
    }
}
public enum LibraryPresentation {
    public static func sections(_ items: [VaultItem], source: LibraryDateSource, newestFirst: Bool,
                                component: Calendar.Component = .month, calendar: Calendar = .current) -> [LibrarySection] {
        func date(_ item: VaultItem) -> Date { source == .captured ? item.chronologicalDate : item.added }
        let sorted = items.sorted {
            let a = date($0), b = date($1)
            if a == b { return $0.id.uuidString < $1.id.uuidString }
            return newestFirst ? a > b : a < b
        }
        var groups: [(Date, [VaultItem])] = []
        for item in sorted {
            let start = calendar.dateInterval(of: component, for: date(item))?.start ?? calendar.startOfDay(for: date(item))
            if groups.last?.0 == start { groups[groups.count - 1].1.append(item) }
            else { groups.append((start, [item])) }
        }
        return groups.map { LibrarySection(id: String($0.0.timeIntervalSince1970), date: $0.0, items: $0.1) }
    }
}
