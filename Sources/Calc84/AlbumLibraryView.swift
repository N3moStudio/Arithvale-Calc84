#if os(iOS)
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import CalcCore

struct AlbumLibraryView: View {
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dynamicTypeSize) private var textSize
    let items: [VaultItem]
    let engine: VaultEngine
    let open: (String) -> Void
    private struct EditingAlbum: Identifiable { let name: String; var id: String { name } }
    @State private var editing: EditingAlbum?
    private var names: [String] {
        Set(items.flatMap(\.albumNames) + Array(vault.albumPreferences.keys)).sorted {
            let a = vault.albumPreferences[$0]?.pinned == true, b = vault.albumPreferences[$1]?.pinned == true
            return a == b ? $0.localizedStandardCompare($1) == .orderedAscending : a
        }
    }
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: textSize.isAccessibilitySize ? 1 : 2), alignment: .leading, spacing: 18) {
                album("All items", values: items, filter: "All")
                album("Favorites", values: items.filter { $0.favorite == true }, filter: "Favorites")
                ForEach(names, id: \.self) { name in
                    VStack(alignment: .leading, spacing: 2) {
                        album(name, values: items.filter { $0.albumNames.contains(name) }, filter: "album:" + name)
                            .contextMenu { Button("Customize Album", systemImage: "slider.horizontal.3") { editing = .init(name: name) } }
                        Button { editing = .init(name: name) } label: {
                            HStack {
                                if vault.albumPreferences[name]?.pinned == true { Label("Pinned", systemImage: "pin.fill") }
                                Spacer()
                                Image(systemName: "ellipsis")
                            }.font(.caption).frame(minHeight: 44).contentShape(Rectangle())
                        }.accessibilityLabel("Customize \(name)")
                    }
                }
            }.padding(.horizontal, 15)
            HStack {
                Button { open("Files") } label: { Label("Files", systemImage: "doc").frame(maxWidth: .infinity, minHeight: 48) }
                Button { open("Recently Deleted") } label: { Label("Recently Deleted", systemImage: "trash").frame(maxWidth: .infinity, minHeight: 48) }
            }.font(.subheadline).padding(15)
            Color.clear.frame(height: 90)
        }
        .sheet(item: $editing) { album in NavigationStack {
            AlbumCustomizationView(name: album.name, preference: vault.albumPreferences[album.name] ?? .init())
        } }
        .onChange(of: editing?.id) { _, value in vault.libraryToolPresented = value != nil }
        .onDisappear { vault.libraryToolPresented = false }
    }
    private func album(_ name: String, values: [VaultItem], filter: String) -> some View {
        Button { open(filter) } label: {
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geometry in
                    if filter.hasPrefix("album:"), let id = vault.albumPreferences[name]?.coverID, let item = values.first(where: { $0.id == id }) {
                        LibraryThumbnail(item: item, engine: engine)
                    } else {
                    let side = (geometry.size.width - 1) / 2
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)], spacing: 1) {
                        ForEach(0..<4) { index in
                            Group {
                                if values.indices.contains(index) { LibraryThumbnail(item: values[index], engine: engine) }
                                else { Color(uiColor: .secondarySystemBackground).overlay { if index == 0 { Image(systemName: "photo").foregroundStyle(.tertiary) } } }
                            }.frame(width: side, height: (geometry.size.height - 1) / 2).clipped()
                        }
                    }
                    }
                }.aspectRatio(1.18, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 13))
                Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(2)
                Text("\(values.count) items").font(.caption).foregroundStyle(.secondary)
            }
        }.buttonStyle(.plain).accessibilityElement(children: .ignore).accessibilityLabel("\(name), \(values.count) items")
    }
}

/// Small thumbnails only; originals are decoded by the full-screen viewer.
struct LibraryThumbnail: View {
    let item: VaultItem
    let engine: VaultEngine
    @State private var image: UIImage?
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(uiColor: .secondarySystemBackground)
                if let image { Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped() }
                else { Image(systemName: "photo").foregroundStyle(.tertiary) }
            }
        }.task(id: item.id) {
            guard item.thumbnailID != nil || (item.byteCount <= 8 * 1024 * 1024 && UTType(item.contentType)?.conforms(to: .image) == true),
                  let data = try? await engine.contents(id: item.thumbnailID ?? item.id), !Task.isCancelled else { return }
            let decoded = await Task.detached(priority: .utility) { () -> UIImage? in
                guard let source = CGImageSourceCreateWithData(data as CFData, nil), let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 300, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
                return UIImage(cgImage: bitmap)
            }.value
            if !Task.isCancelled { image = decoded }
        }.onDisappear { image = nil }.accessibilityHidden(true)
    }
}
#endif
