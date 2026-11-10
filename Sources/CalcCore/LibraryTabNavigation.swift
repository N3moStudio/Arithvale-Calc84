import Foundation

public enum LibraryTab: String, CaseIterable, Hashable, Sendable {
    case library = "Library", albums = "Albums", search = "Search"
}

/// Tab routes outlive the visible pane. Selecting another tab never turns an album
/// (especially Recently Deleted) into the ordinary library's query.
public struct LibraryTabNavigation: Equatable, Sendable {
    public private(set) var selected: LibraryTab = .library
    public var albumPath: [String] = []
    public init() {}
    public mutating func select(_ tab: LibraryTab) {
        if selected == tab && tab == .albums { albumPath = [] }
        selected = tab
    }
    public mutating func openAlbum(_ filter: String) {
        selected = .albums
        albumPath = [filter]
    }
}
