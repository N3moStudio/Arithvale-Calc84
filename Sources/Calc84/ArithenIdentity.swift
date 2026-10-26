#if os(iOS)
import SwiftUI

struct ArithenIdentity: View {
    private static let image: UIImage? = {
        guard let url = Bundle.module.url(forResource: "ArithenIcon", withExtension: "png", subdirectory: "Resources") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }()
    var body: some View {
        HStack(spacing: 14) {
            if let image = Self.image {
                Image(uiImage: image).resizable().frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 13)).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(AppBrand.name).font(.title2.bold())
                Text(AppBrand.version).font(.footnote).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 8)
    }
}
#endif

