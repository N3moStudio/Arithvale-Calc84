#if os(iOS)
import SwiftUI

struct ArithenArtwork: View {
    private static let image: UIImage? = {
        guard let url = Bundle.module.url(forResource: "ArithenIcon", withExtension: "png", subdirectory: "Resources") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }()
    var body: some View {
        if let image = Self.image {
            Image(uiImage: image).resizable().scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
struct ArithenIdentity: View {
    @Environment(\.dynamicTypeSize) private var size
    var body: some View {
        let layout = size.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 18))
        layout {
            ArithenArtwork().frame(width: 70, height: 70).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(AppBrand.name).font(.title2.bold())
                Text(AppBrand.version).font(.subheadline).foregroundStyle(.secondary)
            }.fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 16).accessibilityElement(children: .combine)
    }
}
#endif

