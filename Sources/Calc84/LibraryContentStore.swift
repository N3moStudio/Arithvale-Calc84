#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers
import CalcCore

struct LibraryQuery: Equatable {
    var filter: String
    var search: String
    var dateSource: LibraryDateSource
    var newestFirst: Bool
}

/// Only item/query changes rebuild the index. A selection sweep never sorts it.
@MainActor
final class LibraryContentStore: ObservableObject {
    @Published private(set) var sections: [LibrarySection] = []
    private(set) var visible: [VaultItem] = []
    private(set) var albumItems: [VaultItem] = []
    private(set) var albums: [String] = []
    private(set) var revision = UUID()
    private var items: [VaultItem] = []
    private var query: LibraryQuery?

    func update(items: [VaultItem], query: LibraryQuery) {
        guard self.items != items || self.query != query else { return }
        self.items = items; self.query = query
        albumItems = items.filter { $0.visible && $0.deletedAt == nil }
        albums = Array(Set(albumItems.compactMap(\.album).filter { !$0.isEmpty })).sorted()
        visible = items.filter { item in
            guard item.visible, (query.filter == "Recently Deleted" ? item.deletedAt != nil : item.deletedAt == nil) else { return false }
            if !query.search.isEmpty && !item.name.localizedCaseInsensitiveContains(query.search)
                && !(item.album?.localizedCaseInsensitiveContains(query.search) ?? false) { return false }
            switch query.filter {
            case "Photos": return UTType(item.contentType)?.conforms(to: .image) == true
            case "Videos": return UTType(item.contentType)?.conforms(to: .movie) == true
            case "Files": return UTType(item.contentType)?.conforms(to: .image) != true && UTType(item.contentType)?.conforms(to: .movie) != true
            case "Favorites": return item.favorite == true
            case "All", "All Items", "Recently Deleted": return true
            default: return query.filter.hasPrefix("album:") && item.album == String(query.filter.dropFirst(6))
            }
        }
        revision = UUID()
        sections = LibraryPresentation.sections(visible, source: query.dateSource, newestFirst: query.newestFirst)
    }
}
#endif
