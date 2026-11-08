#if os(iOS)
import SwiftUI
import CalcCore

// Presentation adapted from Native Settings Kit 0.1.0. See UI/NativeSettingsKit/PROVENANCE.md.
// Host bindings and the existing AppearanceRoot remain the only owners of settings/state.
struct SettingsRow: View {
    let title: String
    let symbol: String
    var value: String? = nil
    var detail: String? = nil
    @Environment(\.dynamicTypeSize) private var size
    @Environment(\.arithenTheme) private var theme

    init(_ title: String, symbol: String, value: String? = nil, detail: String? = nil) {
        self.title = title; self.symbol = symbol; self.value = value; self.detail = detail
    }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.body.weight(.medium))
                .foregroundStyle(ArithenPalette.color(.accent, theme: theme))
                .frame(width: 32, height: 32).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                let layout = size.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
                layout {
                    Text(title).foregroundStyle(ArithenPalette.color(.text, theme: theme))
                        .fixedSize(horizontal: false, vertical: true)
                    if !size.isAccessibilitySize { Spacer(minLength: 0) }
                    if let value {
                        Text(value).font(.subheadline).foregroundStyle(ArithenPalette.color(.muted, theme: theme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let detail {
                    Text(detail).font(.subheadline).foregroundStyle(ArithenPalette.color(.muted, theme: theme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }.frame(minHeight: 44).padding(.vertical, 4).accessibilityElement(children: .combine)
    }
}

struct AppearanceSettingsCard: View {
    @Environment(\.arithenTheme) private var theme
    @Environment(\.dynamicTypeSize) private var size
    @AppStorage(ArithenPalette.surfaceKey) private var surface = ThemeSurface.theme.rawValue
    var body: some View {
        NavigationLink { AppearanceSettingsView() } label: {
            let layout = size.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 18))
            layout {
                ArithenArtwork().frame(width: 70, height: 70).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppBrand.name.uppercased()).font(.caption.weight(.semibold)).tracking(1.2)
                        .foregroundStyle(ArithenPalette.color(.accent, theme: theme))
                    Text("Make it yours").font(.title2.bold()).foregroundStyle(ArithenPalette.color(.text, theme: theme))
                    Text(theme.title + " · " + (ThemeSurface(rawValue: surface) ?? .theme).title)
                        .font(.subheadline).foregroundStyle(ArithenPalette.color(.muted, theme: theme))
                }.fixedSize(horizontal: false, vertical: true)
            }.padding(.vertical, 16).accessibilityElement(children: .combine)
        }.accessibilityHint("Choose your theme and surfaces")
    }
}

struct SettingsThemeTile: View {
    let theme: ArithenTheme
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Circle().fill(ArithenPalette.color(.accent, theme: theme)).frame(width: 18, height: 18)
                    Circle().fill(ArithenPalette.color(.muted, theme: theme)).frame(width: 18, height: 18)
                    Spacer(minLength: 4)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(ArithenPalette.color(.accent, theme: theme))
                }.accessibilityHidden(true)
                Text(theme.title).font(.subheadline.weight(.semibold))
                    .foregroundStyle(ArithenPalette.color(.text, theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(12).frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                .background(ArithenPalette.color(.surface, theme: theme), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(ArithenPalette.color(.accent, theme: theme).opacity(selected ? 1 : 0.25), lineWidth: selected ? 2 : 1))
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).accessibilityLabel(Text(theme.title))
            .accessibilityValue(Text(theme.detail)).accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
#endif
