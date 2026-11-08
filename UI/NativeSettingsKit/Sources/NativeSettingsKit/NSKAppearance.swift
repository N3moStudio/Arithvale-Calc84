import SwiftUI

private struct NSKThemeKey: EnvironmentKey { static let defaultValue = NSKTheme.bloom }
private struct NSKSurfaceKey: EnvironmentKey { static let defaultValue = NSKSurface.solid }
private struct NSKTypographyAppliedKey: EnvironmentKey { static let defaultValue = false }

public extension EnvironmentValues {
    var nskTheme: NSKTheme {
        get { self[NSKThemeKey.self] }
        set { self[NSKThemeKey.self] = newValue }
    }
    var nskSurface: NSKSurface {
        get { self[NSKSurfaceKey.self] }
        set { self[NSKSurfaceKey.self] = newValue }
    }
}

private extension EnvironmentValues {
    var nskTypographyApplied: Bool {
        get { self[NSKTypographyAppliedKey.self] }
        set { self[NSKTypographyAppliedKey.self] = newValue }
    }
}

enum NSKTypography {
    static func compact(_ size: DynamicTypeSize) -> DynamicTypeSize {
        guard !size.isAccessibilitySize else { return size }
        let sizes: [DynamicTypeSize] = [.xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge]
        guard let index = sizes.firstIndex(of: size) else { return size }
        return sizes[max(0, index - 1)]
    }
}

private struct NSKAppearanceModifier: ViewModifier {
    let theme: NSKTheme
    let surface: NSKSurface
    @Environment(\.dynamicTypeSize) private var systemSize
    @Environment(\.colorScheme) private var inheritedScheme
    @Environment(\.nskTypographyApplied) private var typographyApplied
    func body(content: Content) -> some View {
        // Environment changes preserve navigation, gestures and host-owned drafts.
        // Never use .id(theme) or recreate a NavigationStack on appearance changes.
        content
            .environment(\.nskTheme, theme).environment(\.nskSurface, surface)
            .fontDesign(.rounded)
            .dynamicTypeSize(typographyApplied ? systemSize : NSKTypography.compact(systemSize))
            .environment(\.nskTypographyApplied, true)
            // Scope this styling to the receiving subtree; do not override the host window.
            .environment(\.colorScheme, theme.preferredColorScheme ?? inheritedScheme)
    }
}

public extension View {
    /// Install once at the settings NavigationStack/presentation root. No state is persisted.
    func nativeSettingsAppearance(theme: NSKTheme = .bloom, surface: NSKSurface = .solid) -> some View {
        modifier(NSKAppearanceModifier(theme: theme, surface: surface))
    }
    /// Only for a floating custom control, never every row or content card.
    func nativeSettingsFloatingSurface() -> some View {
        background { NSKFloatingBackground() }
    }
}

private struct NSKFloatingBackground: View {
    @Environment(\.nskTheme) private var theme
    @Environment(\.nskSurface) private var surface
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
        let colors = theme.palette(dark: scheme == .dark)
        if !surface.allowsTransparency(reduceTransparency: reduceTransparency, increasedContrast: contrast == .increased) {
            shape.fill(colors.surface)
        } else {
            // The conditional affects ONLY decoration; controls keep their identity/state.
            #if compiler(>=6.2)
            if #available(iOS 26.0, *) {
                shape.fill(.clear).glassEffect(.regular, in: shape)
            } else {
                shape.fill(.regularMaterial)
            }
            #else
            shape.fill(.regularMaterial)
            #endif
        }
    }
}
