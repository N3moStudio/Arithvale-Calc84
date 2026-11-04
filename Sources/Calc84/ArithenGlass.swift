#if os(iOS)
import SwiftUI
import CalcCore

extension GlassTint {
    var color: Color {
        switch self {
        case .plum: Color(red: 0.471, green: 0.380, blue: 0.733)
        case .clear: Color.primary
        case .blue: Color(red: 0.28, green: 0.52, blue: 0.84)
        case .mint: Color(red: 0.19, green: 0.66, blue: 0.52)
        case .rose: Color(red: 0.78, green: 0.35, blue: 0.55)
        case .amber: Color(red: 0.80, green: 0.49, blue: 0.16)
        }
    }
    var glassColor: Color? { self == .clear ? nil : color.opacity(0.32) }
}

/// Controls use native optical glass on iOS 26; older systems use readable material.
struct ArithenGlass<S: InsettableShape>: ViewModifier {
    let tint: GlassTint
    let shape: S
    var prominent = false
    var interactive = true
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @AppStorage(ArithenPalette.surfaceKey) private var surface = ThemeSurface.theme.rawValue
    @Environment(\.arithenTheme) private var theme
    func body(content: Content) -> some View {
        if surface != ThemeSurface.glass.rawValue || reduceTransparency || contrast == .increased {
            content.background(ArithenPalette.color(prominent ? .accent : .surface, theme: theme), in: shape)
                .overlay(shape.strokeBorder(ArithenPalette.color(.text, theme: theme).opacity(contrast == .increased ? 0.4 : 0.12), lineWidth: 1).allowsHitTesting(false))
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(ArithenPalette.color(.accent, theme: theme).opacity(prominent ? 0.45 : 0.08)).interactive(interactive), in: shape)
        } else {
            content.background {
                shape.fill(.regularMaterial)
                    .overlay(shape.fill(ArithenPalette.color(.accent, theme: theme).opacity(prominent ? 0.25 : 0.04)))
            }
                .overlay(shape.strokeBorder(.white.opacity(0.25), lineWidth: 0.8).allowsHitTesting(false))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        }
    }
}
struct ArithenGlassGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        if #available(iOS 26.0, *) { GlassEffectContainer(spacing: 4, content: content) }
        else { content() }
    }
}
#endif

