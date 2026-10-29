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
    private var recognizedText: [UUID: String] = [:]
    private var indexedItems: [UUID: VaultItem] = [:]
    private var documents: [UUID: String] = [:]

    func update(items: [VaultItem], query: LibraryQuery, recognizedText: [UUID: String]? = nil) {
        let textChanged = recognizedText.map { $0 != self.recognizedText } ?? false
        guard self.items != items || self.query != query || textChanged else { return }
        let text = recognizedText ?? self.recognizedText
        let ids = Set(items.map(\.id))
        documents = documents.filter { ids.contains($0.key) }
        for item in items where indexedItems[item.id] != item || text[item.id] != self.recognizedText[item.id] {
            documents[item.id] = LibraryOrganization.searchDocument(item, recognizedText: text[item.id] ?? "")
        }
        indexedItems = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        self.recognizedText = text
        self.items = items; self.query = query
        albumItems = items.filter { $0.visible && $0.deletedAt == nil }
        albums = Array(Set(albumItems.flatMap(\.albumNames))).sorted()
        let terms = LibraryOrganization.searchTerms(query.search)
        visible = items.filter { item in
            guard item.visible, (query.filter == "Recently Deleted" ? item.deletedAt != nil : item.deletedAt == nil) else { return false }
            if !LibraryOrganization.matches(document: documents[item.id] ?? "", terms: terms) { return false }
            switch query.filter {
            case "Photos": return UTType(item.contentType)?.conforms(to: .image) == true
            case "Videos": return UTType(item.contentType)?.conforms(to: .movie) == true
            case "Files": return UTType(item.contentType)?.conforms(to: .image) != true && UTType(item.contentType)?.conforms(to: .movie) != true
            case "Favorites": return item.favorite == true
            case "All", "All Items", "Recently Deleted": return true
            default: return query.filter.hasPrefix("album:") && item.albumNames.contains(String(query.filter.dropFirst(6)))
            }
        }
        revision = UUID()
        sections = LibraryPresentation.sections(visible, source: query.dateSource, newestFirst: query.newestFirst)
    }
}
#endif
