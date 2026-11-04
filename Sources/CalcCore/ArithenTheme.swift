import Foundation

/// Interface style and Home Screen artwork deliberately have separate storage.
public enum ArithenTheme: String, CaseIterable, Identifiable, Sendable {
    case glacier, afterhours, porcelain, ion, ember, bloom, blueprint, titanium
    public static let defaultStyle = ArithenTheme.bloom
    /// Retired themes map to the current default so old backups and saved choices still load.
    public static let retiredStyles: [String: ArithenTheme] = ["abyss": .bloom]
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var detail: String {
        switch self {
        case .glacier: return "Ice blue & silver"
        case .afterhours: return "Ink & violet"
        case .porcelain: return "Chalk & graphite"
        case .ion: return "Citron & graphite"
        case .ember: return "Copper & charcoal"
        case .bloom: return "Petal pink & berry"
        case .blueprint: return "Paper & cobalt"
        case .titanium: return "Platinum & ink"
        }
    }
    public var cornerRadius: Double { self == .afterhours ? 28 : self == .porcelain ? 13 : 20 }
    public init(storedValue: String?) { self = storedValue.flatMap(Self.resolve) ?? Self.defaultStyle }
    /// Returns nil only for names this version has never known.
    public static func resolve(_ raw: String) -> Self? { Self(rawValue: raw) ?? retiredStyles[raw] }

    public enum Ink: CaseIterable { case accent, onAccent, secondary, canvas, surface, text, muted }
    public func hex(_ ink: Ink, dark: Bool) -> Int {
        let light: [Int], night: [Int]
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
        let index: Int
        switch ink { case .accent: index = 0; case .onAccent: index = 1; case .secondary: index = 2
        case .canvas: index = 3; case .surface: index = 4; case .text: index = 5; case .muted: index = 6 }
        return (dark ? night : light)[index]
    }
}


public enum ThemeSurface: String, Codable, CaseIterable, Sendable {
    case theme, solid, glass
    public var title: String { switch self { case .theme: "Theme default"; case .solid: "Solid (no glass)"; case .glass: "Liquid Glass" } }
    public var usesGlass: Bool { self == .glass }
}
public extension ArithenTheme {
    var colorMode: String { switch self {
    case .afterhours, .ion, .ember, .titanium: "dark"
    case .porcelain, .bloom, .blueprint: "light"
    case .glacier: "system"
    } }
    func isDark(systemDark: Bool) -> Bool { colorMode == "dark" || (colorMode == "system" && systemDark) }
}
public enum CompactTypography {
    public static func category(_ index: Int, accessibility: Bool) -> Int {
        accessibility ? index : max(0, index - 1)
    }
}

extension ArithenTheme: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let value = Self.resolve(raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown theme"))
        }
        self = value
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer(); try container.encode(rawValue)
    }
}
