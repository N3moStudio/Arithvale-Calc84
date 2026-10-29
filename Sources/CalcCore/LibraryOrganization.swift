import Foundation

public struct AlbumPreference: Codable, Equatable, Sendable {
    public var pinned: Bool
    public var coverID: UUID?
    public init(pinned: Bool = false, coverID: UUID? = nil) { self.pinned = pinned; self.coverID = coverID }
}

public enum OrganizationMode: String, CaseIterable, Sendable { case add, remove }

public enum LibraryOrganization {
    public static func names(_ values: [String], limit: Int = 100) -> [String] {
        var seen = Set<String>()
        return values.map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit)) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
    public static func applying(_ values: [String], to existing: [String], mode: OrganizationMode, limit: Int) -> [String] {
        let clean = names(values, limit: limit)
        return mode == .add ? names(existing + clean, limit: limit) : existing.filter { !clean.contains($0) }
    }
    public static func matches(_ item: VaultItem, query: String, recognizedText: String = "") -> Bool {
        matches(document: searchDocument(item, recognizedText: recognizedText), terms: searchTerms(query))
    }
    public static func searchDocument(_ item: VaultItem, recognizedText: String = "") -> String {
        ([item.name] + item.albumNames + (item.tags ?? []) + [recognizedText]).joined(separator: "\n")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
    public static func searchTerms(_ query: String) -> [String] {
        query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace).map(String.init)
    }
    public static func matches(document: String, terms: [String]) -> Bool {
        terms.allSatisfy { document.contains($0) }
    }
    static func validate(_ manifest: VaultManifest) throws {
        guard manifest.items.allSatisfy({ item in
            item.albumNames.count <= 24 && item.albumNames.allSatisfy { !$0.isEmpty && $0.count <= 100 }
                && (item.tags ?? []).count <= 32 && (item.tags ?? []).allSatisfy { !$0.isEmpty && $0.count <= 64 }
        }), (manifest.albumPreferences ?? [:]).count <= 500,
        (manifest.albumPreferences ?? [:]).allSatisfy({ name, value in
            !name.isEmpty && name.count <= 100 && (value.coverID == nil || manifest.items.contains {
                $0.id == value.coverID && $0.visible && $0.albumNames.contains(name)
            })
        }) else { throw VaultError.invalidBackup }
    }
}

/// A rebuildable, local-only index. It is encrypted separately from the portable manifest.
public struct PrivateSearchIndex: Codable, Equatable, Sendable {
    public var enabled = false
    public var entries: [UUID: String] = [:]
    public init() {}
    public static let textBytes = 4096
    public static let fileBytes = 24 * 1024 * 1024
    public static func bounded(_ text: String) -> String {
        var result = String(text.prefix(textBytes))
        while result.utf8.count > textBytes { result.removeLast() }
        return result
    }
    public mutating func prune(items: [VaultItem]) {
        let active = Set(items.filter { $0.visible && $0.deletedAt == nil }.map(\.id))
        entries = entries.filter { active.contains($0.key) }
    }
    public func validate() throws {
        guard entries.count <= VaultLimits.itemCount, entries.values.allSatisfy({ $0.utf8.count <= Self.textBytes }),
              enabled || entries.isEmpty else { throw VaultError.invalidBackup }
    }
}
