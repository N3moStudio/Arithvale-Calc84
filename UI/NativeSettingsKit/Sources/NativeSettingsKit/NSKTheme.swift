import SwiftUI

/// Palette data adapted from Elsepin Shared/ShiftAppearance.swift. See PROVENANCE.md.
/// These identifiers are presentation choices, NOT replacements for a host's storage schema.
public enum NSKTheme: String, CaseIterable, Identifiable, Sendable {
    case glacier, afterhours, porcelain, ion, ember, bloom, blueprint, titanium
    public static let defaultTheme: Self = .bloom
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var cornerRadius: CGFloat { self == .afterhours ? 28 : self == .porcelain ? 13 : 20 }

    public var preferredColorScheme: ColorScheme? {
        switch self {
        case .afterhours, .ion, .ember, .titanium: return .dark
        case .porcelain, .bloom, .blueprint: return .light
        case .glacier: return nil
        }
    }

    /// Explicit read adapter for hosts migrating the historical theme names.
    /// Unknown values remain unknown; never overwrite the original stored value on read.
    public static func legacyValue(_ raw: String) -> Self? {
        raw == "abyss" ? .bloom : Self(rawValue: raw)
    }

    public func palette(dark: Bool) -> NSKPalette {
        let light: [UInt32], night: [UInt32]
        // Order: accent, onAccent, secondary, canvas, surface, text, muted.
        switch self {
        case .glacier:
            light = [0x255BA4, 0xFFFFFF, 0x3D6594, 0xF2F6FB, 0xFFFFFF, 0x17283B, 0x53667D]
            night = [0xB5D9FF, 0x10243D, 0xACCCF0, 0x111923, 0x1B2633, 0xEFF5FC, 0xA7BACF]
        case .afterhours:
            light = [0x7142A9, 0xFFFFFF, 0x67528F, 0xF4F1FA, 0xFFFFFF, 0x252037, 0x665879]
            night = [0xD1B4FF, 0x271440, 0xBFB0E4, 0x12101B, 0x211D2F, 0xF4EFFF, 0xB8ACCB]
        case .porcelain:
            light = [0x323B3F, 0xFFFFFF, 0x526777, 0xF6F5F2, 0xFFFFFF, 0x202221, 0x60635D]
            night = [0xDBE4E9, 0x20272A, 0xB7C7D1, 0x171715, 0x242421, 0xF3F3EB, 0xB9BCB0]
        case .ion:
            light = [0x516700, 0xFFFFFF, 0x53603B, 0xF4F7EC, 0xFFFFFF, 0x202719, 0x58634C]
            night = [0xD7FF4F, 0x182000, 0xBECD98, 0x10170D, 0x20291C, 0xF4F8E9, 0xB8C4A6]
        case .ember:
            light = [0xA74416, 0xFFFFFF, 0x79523E, 0xFCF4EE, 0xFFFFFF, 0x302019, 0x735A4D]
            night = [0xFF9C68, 0x321B0E, 0xDDB49D, 0x21150F, 0x33231B, 0xFFF2E9, 0xD1B8AA]
        case .bloom:
            light = [0xA62E76, 0xFFFFFF, 0x81516C, 0xF8EFF3, 0xFFF9FC, 0x352131, 0x755C6D]
            night = [0xF4A9D7, 0x3A1330, 0xDCB6CF, 0x241820, 0x35252F, 0xFFF0F9, 0xD0B6C6]
        case .blueprint:
            light = [0x2151C7, 0xFFFFFF, 0x415C8C, 0xEDF2FF, 0xFFFFFF, 0x132747, 0x526582]
            night = [0xA8C4FF, 0x10275C, 0xB2C4E6, 0x111B30, 0x202F4A, 0xF0F5FF, 0xB6C5DF]
        case .titanium:
            light = [0x475465, 0xFFFFFF, 0x536174, 0xF1F3F6, 0xFFFFFF, 0x222830, 0x5D6877]
            night = [0xD4DCE8, 0x202731, 0xBBC8DA, 0x15171B, 0x242830, 0xF2F5FA, 0xB6C0CE]
        }
        return NSKPalette(hex: dark ? night : light)
    }
}

public struct NSKPalette {
    public let hex: [UInt32]
    public var accent: Color { color(0) }
    public var onAccent: Color { color(1) }
    public var secondary: Color { color(2) }
    public var canvas: Color { color(3) }
    public var surface: Color { color(4) }
    public var text: Color { color(5) }
    public var muted: Color { color(6) }
    private func color(_ index: Int) -> Color {
        let value = hex[index]
        return Color(.sRGB, red: Double((value >> 16) & 255) / 255,
                     green: Double((value >> 8) & 255) / 255,
                     blue: Double(value & 255) / 255, opacity: 1)
    }
}

public enum NSKSurface: String, CaseIterable, Identifiable, Sendable {
    case solid, glass
    public var id: String { rawValue }
    public var title: String { self == .solid ? "Solid" : "Liquid Glass" }
    public static func legacyValue(_ raw: String) -> Self? {
        raw == "theme" ? .solid : Self(rawValue: raw)
    }
    public func allowsTransparency(reduceTransparency: Bool, increasedContrast: Bool) -> Bool {
        self == .glass && !reduceTransparency && !increasedContrast
    }
}
