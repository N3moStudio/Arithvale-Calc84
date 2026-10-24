#if os(iOS)
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import CalcCore

struct AlbumLibraryView: View {
    @Environment(\.dynamicTypeSize) private var textSize
    let items: [VaultItem]
    let engine: VaultEngine
    let open: (String) -> Void
    private var names: [String] { Set(items.compactMap(\.album).filter { !$0.isEmpty }).sorted() }
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: textSize.isAccessibilitySize ? 1 : 2), alignment: .leading, spacing: 18) {
                album("All items", values: items, filter: "All")
                album("Favorites", values: items.filter { $0.favorite == true }, filter: "Favorites")
                ForEach(names, id: \.self) { name in
                    album(name, values: items.filter { $0.album == name }, filter: "album:" + name)
                }
            }.padding(.horizontal, 15)
            HStack {
                Button { open("Files") } label: { Label("Files", systemImage: "doc").frame(maxWidth: .infinity, minHeight: 48) }
                Button { open("Recently Deleted") } label: { Label("Recently Deleted", systemImage: "trash").frame(maxWidth: .infinity, minHeight: 48) }
            }.font(.subheadline).padding(15)
            Color.clear.frame(height: 90)
        }
    }
    private func album(_ name: String, values: [VaultItem], filter: String) -> some View {
        Button { open(filter) } label: {
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geometry in
                    let side = (geometry.size.width - 1) / 2
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)], spacing: 1) {
                        ForEach(0..<4) { index in
                            Group {
                                if values.indices.contains(index) { LibraryThumbnail(item: values[index], engine: engine) }
                                else { Color(uiColor: .secondarySystemBackground).overlay { if index == 0 { Image(systemName: "photo").foregroundStyle(.tertiary) } } }
                            }.frame(width: side, height: (geometry.size.height - 1) / 2).clipped()
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
