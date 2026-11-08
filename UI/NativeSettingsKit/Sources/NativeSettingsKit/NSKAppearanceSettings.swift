import SwiftUI

/// Opt-in appearance screen. Bind directly to the host's existing model/adapters.
/// Defaults, persistence, migrations and feature access remain owned by the host.
public struct NSKAppearanceSettings: View {
    @Binding private var theme: NSKTheme
    @Binding private var surface: NSKSurface
    @Environment(\.dynamicTypeSize) private var size
    private let title: String
    public init(theme: Binding<NSKTheme>, surface: Binding<NSKSurface>, title: String = "Appearance") {
        _theme = theme; _surface = surface; self.title = title
    }
    public var body: some View {
        NSKList {
            NSKSection("Theme") {
                LazyVGrid(columns: size.isAccessibilitySize
                          ? [GridItem(.flexible())]
                          : [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    ForEach(NSKTheme.allCases) { choice in
                        NSKThemeTile(theme: choice, selected: choice == theme) { theme = choice }
                    }
                }.padding(.vertical, 8)
            }
            NSKSection("Surface") {
                ForEach(NSKSurface.allCases) { choice in
                    Button { surface = choice } label: {
                        HStack {
                            Text(choice.title).foregroundStyle(.primary)
                            Spacer(minLength: 8)
                            if surface == choice { Image(systemName: "checkmark").accessibilityHidden(true) }
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(surface == choice ? [.isSelected] : [])
                }
            }
        }.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

private struct NSKThemeTile: View {
    let theme: NSKTheme
    let selected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let dark = (theme.preferredColorScheme ?? scheme) == .dark
        let colors = theme.palette(dark: dark)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Circle().fill(colors.accent).frame(width: 18, height: 18)
                    Circle().fill(colors.muted).frame(width: 18, height: 18)
                    Spacer(minLength: 4)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(colors.accent)
                }.accessibilityHidden(true)
                Text(theme.title).font(.subheadline.weight(.semibold))
                    .foregroundStyle(colors.text).fixedSize(horizontal: false, vertical: true)
            }.padding(12).frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                .background(colors.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(colors.accent.opacity(selected ? 1 : 0.25), lineWidth: selected ? 2 : 1))
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).accessibilityLabel(Text(theme.title))
            .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
