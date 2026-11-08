import SwiftUI

/// Native List, not a custom scrolling/reorder/navigation implementation.
public struct NSKList<Content: View>: View {
    @Environment(\.nskTheme) private var theme
    @Environment(\.nskSurface) private var surface
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        let colors = theme.palette(dark: scheme == .dark)
        let glass = surface.allowsTransparency(reduceTransparency: reduceTransparency, increasedContrast: contrast == .increased)
        List { content }
            .listStyle(.insetGrouped).listRowSpacing(0).listSectionSpacing(24)
            .environment(\.defaultMinListRowHeight, 52)
            .scrollContentBackground(.hidden).background(colors.canvas)
            .foregroundStyle(colors.text).tint(colors.accent)
            .contentMargins(.top, 16, for: .scrollContent)
            .toolbarBackground(colors.surface, for: .navigationBar)
            .toolbarBackground(glass ? .automatic : .visible, for: .navigationBar)
            .toolbarColorScheme(scheme, for: .navigationBar)
    }
}

/// One surface around related rows. The native List supplies rounding and separators.
public struct NSKSection<Content: View>: View {
    @Environment(\.nskTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    private let title: String?
    private let content: Content
    public init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }
    public var body: some View {
        Section { content } header: {
            if let title { Text(title).textCase(nil) }
        }
        .listRowBackground(theme.palette(dark: scheme == .dark).surface)
    }
}

/// Use as a native NavigationLink/Button label. No tap handler, chevron or nested button.
public struct NSKRow: View {
    @Environment(\.nskTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var size
    private let title: String
    private let symbol: String
    private let value: String?
    private let detail: String?
    public init(_ title: String, symbol: String, value: String? = nil, detail: String? = nil) {
        self.title = title; self.symbol = symbol; self.value = value; self.detail = detail
    }
    public var body: some View {
        let colors = theme.palette(dark: scheme == .dark)
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol).font(.body.weight(.medium))
                .foregroundStyle(colors.accent).frame(width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                let layout = size.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
                layout {
                    Text(title).foregroundStyle(colors.text).fixedSize(horizontal: false, vertical: true)
                    if !size.isAccessibilitySize { Spacer(minLength: 0) }
                    if let value {
                        Text(value).font(.subheadline).foregroundStyle(colors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let detail {
                    Text(detail).font(.subheadline).foregroundStyle(colors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }.frame(minHeight: 44).padding(.vertical, 4)
            .accessibilityElement(children: .combine)
    }
}

/// Intentionally larger than ordinary settings rows. Supply the HOST app's artwork.
public struct NSKIdentityLabel<Artwork: View>: View {
    @Environment(\.nskTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var size
    private let eyebrow: String
    private let title: String
    private let subtitle: String
    private let artwork: Artwork
    public init(eyebrow: String = "MAKE IT YOURS", title: String = "Your space. Your way.",
                subtitle: String, @ViewBuilder artwork: () -> Artwork) {
        self.eyebrow = eyebrow; self.title = title; self.subtitle = subtitle; self.artwork = artwork()
    }
    public var body: some View {
        let colors = theme.palette(dark: scheme == .dark)
        let layout = size.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 18))
        layout {
            artwork.frame(width: 70, height: 70).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow).font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(colors.accent)
                Text(title).font(.title2.weight(.bold)).foregroundStyle(colors.text)
                Text(subtitle).font(.subheadline).foregroundStyle(colors.muted)
            }.fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 16).accessibilityElement(children: .combine)
    }
}

/// For detail editors inside a host ScrollView. A heading + spacing, with no extra bubble.
public struct NSKEditorGroup<Content: View>: View {
    private let title: String
    private let content: Content
    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            content
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct NSKPrimaryButtonStyle: ButtonStyle {
    @Environment(\.nskTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var enabled
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        let colors = theme.palette(dark: scheme == .dark)
        configuration.label.font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(colors.onAccent)
            .background(colors.accent, in: RoundedRectangle(cornerRadius: theme.cornerRadius))
            .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
    }
}
