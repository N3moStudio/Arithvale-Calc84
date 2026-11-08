#if os(iOS)
import SwiftUI
import CalcCore

private struct ThemeKey: EnvironmentKey { static let defaultValue = ArithenTheme.bloom }
private struct CompactAppliedKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var arithenTheme: ArithenTheme { get { self[ThemeKey.self] } set { self[ThemeKey.self] = newValue } }
    var arithenCompactApplied: Bool { get { self[CompactAppliedKey.self] } set { self[CompactAppliedKey.self] = newValue } }
}
extension DynamicTypeSize {
    var nativeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
    }
}
enum ArithenPalette {
    static let themeKey = "arithen.theme.v1"
    static let surfaceKey = "arithen.surface.v1"
    static var theme: ArithenTheme { .init(storedValue: UserDefaults.standard.string(forKey: themeKey)) }
    static func ui(_ ink: ArithenTheme.Ink, theme: ArithenTheme = theme) -> UIColor {
        UIColor { traits in
            let hex = theme.hex(ink, dark: theme.isDark(systemDark: traits.userInterfaceStyle == .dark))
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
        }
    }
    static func color(_ ink: ArithenTheme.Ink, theme: ArithenTheme = theme) -> Color { Color(uiColor: ui(ink, theme: theme)) }
}
/// No theme-dependent identity: calculations, navigation, imports and zoom survive.
/// Presented roots inherit the marker, so compact sizing is applied exactly once.
struct AppearanceRoot: ViewModifier {
    @AppStorage(ArithenPalette.themeKey) private var storedTheme = ArithenTheme.defaultStyle.rawValue
    @Environment(\.dynamicTypeSize) private var size
    @Environment(\.arithenCompactApplied) private var compactApplied
    private var theme: ArithenTheme { .init(storedValue: storedTheme) }
    private var compact: DynamicTypeSize {
        guard !compactApplied, !size.isAccessibilitySize else { return size }
        let sizes: [DynamicTypeSize] = [.xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge]
        return sizes[CompactTypography.category(sizes.firstIndex(of: size) ?? 3, accessibility: false)]
    }
    func body(content: Content) -> some View {
        content.fontDesign(.rounded).dynamicTypeSize(compact)
            .environment(\.arithenCompactApplied, true).environment(\.arithenTheme, theme)
            .tint(ArithenPalette.color(.accent, theme: theme))
            .foregroundStyle(ArithenPalette.color(.text, theme: theme))
            .preferredColorScheme(theme.colorMode == "system" ? nil : theme.colorMode == "dark" ? .dark : .light)
    }
}
struct SettingsScreen: ViewModifier {
    @Environment(\.arithenTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @AppStorage(ArithenPalette.surfaceKey) private var surface = ThemeSurface.theme.rawValue
    func body(content: Content) -> some View {
        let glass = surface == ThemeSurface.glass.rawValue && !reduceTransparency && contrast != .increased
        return content.scrollContentBackground(.hidden).background(ArithenPalette.color(.canvas, theme: theme))
            .listStyle(.insetGrouped).listRowSpacing(0)
            .listSectionSpacing(24).environment(\.defaultMinListRowHeight, 52)
            .toolbarBackground(ArithenPalette.color(.surface, theme: theme), for: .navigationBar)
            .toolbarBackground(glass ? .automatic : .visible, for: .navigationBar)
    }
}
extension View {
    func settingsScreen() -> some View { modifier(SettingsScreen()) }
    func settingsRows() -> some View { listRowBackground(ArithenPalette.color(.surface)) }
}
/// Only app-owned lists/forms are themed; system pickers and share sheets stay native.
struct ThemedList<Content: View>: View {
    @Environment(\.arithenTheme) private var theme
    @ViewBuilder var content: () -> Content
    var body: some View { List { content().listRowBackground(ArithenPalette.color(.surface, theme: theme)).listRowSeparatorTint(ArithenPalette.color(.text, theme: theme).opacity(0.10)) }.settingsScreen() }
}
struct ThemedForm<Content: View>: View {
    @Environment(\.arithenTheme) private var theme
    @ViewBuilder var content: () -> Content
    var body: some View { Form { content().listRowBackground(ArithenPalette.color(.surface, theme: theme)).listRowSeparatorTint(ArithenPalette.color(.text, theme: theme).opacity(0.10)) }.settingsScreen() }
}

struct FloatingLibraryBar: ViewModifier {
    func body(content: Content) -> some View { content.modifier(ArithenGlass(tint: .clear, shape: Capsule(), interactive: false)) }
}
struct AppearanceSettingsView: View {
    @AppStorage(ArithenPalette.themeKey) private var theme = ArithenTheme.defaultStyle.rawValue
    @AppStorage(ArithenPalette.surfaceKey) private var surface = ThemeSurface.theme.rawValue
    @Environment(\.dynamicTypeSize) private var size
    // Existing installations retain the third choice and original reset semantics.
    private let surfaces: [ThemeSurface] = [.solid, .glass, .theme]
    var body: some View {
        ThemedList {
            Section("Theme") {
                LazyVGrid(columns: size.isAccessibilitySize ? [GridItem(.flexible())]
                          : [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    ForEach(ArithenTheme.allCases) { choice in
                        SettingsThemeTile(theme: choice, selected: ArithenTheme(storedValue: theme) == choice) {
                            theme = choice.rawValue
                        }
                    }
                }.padding(.vertical, 8)
            }
            Section {
                ForEach(surfaces, id: \.rawValue) { choice in
                    Button { surface = choice.rawValue } label: {
                        HStack {
                            Text(choice == .solid ? "Solid" : choice.title)
                                .foregroundStyle(ArithenPalette.color(.text))
                            Spacer(minLength: 8)
                            if (ThemeSurface(rawValue: surface) ?? .theme) == choice {
                                Image(systemName: "checkmark").accessibilityHidden(true)
                            }
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.accessibilityAddTraits((ThemeSurface(rawValue: surface) ?? .theme) == choice ? [.isSelected] : [])
                }
            } header: { Text("Surfaces") } footer: {
                Text("Settings stay solid for readability. Liquid Glass styles floating controls where supported. Theme default currently uses Solid.")
            }
            Section {
                Button("Reset Appearance") { theme = ArithenTheme.defaultStyle.rawValue; surface = ThemeSurface.theme.rawValue }
            }
        }.navigationTitle("Appearance").navigationBarTitleDisplayMode(.inline)
    }
}
#endif
