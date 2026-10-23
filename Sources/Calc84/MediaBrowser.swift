#if os(iOS)
import SwiftUI
import CalcCore

struct MediaBrowser: View {
    let items: [VaultItem]
    let initial: UUID
    @EnvironmentObject private var vault: VaultModel
    @State private var position: Int
    init(items: [VaultItem], initial: UUID) {
        self.items = items; self.initial = initial
        _position = State(initialValue: items.firstIndex(where: { $0.id == initial }) ?? 0)
    }
    private var current: VaultItem? {
        guard items.indices.contains(position) else { return nil }
        return vault.items.first(where: { $0.id == items[position].id })
    }
    var body: some View {
        Group {
            if let current {
                FilePreview(item: current, previous: position > 0 ? { position -= 1 } : nil,
                            next: position + 1 < items.count ? { position += 1 } : nil)
                    .id(current.id)
            }
        }
    }
}
#endif
