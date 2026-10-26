import Foundation

public enum AppearanceArea: String, CaseIterable, Sendable {
    case calculator, library
    public var tintKey: String { rawValue + "GlassTint" }
    public var backgroundKey: String { rawValue + "BackgroundStyle" }
    public var videoKey: String { rawValue + "BackgroundVideo" }
    public var dimmingKey: String { rawValue + "BackgroundDimming" }
}

public enum GlassTint: String, CaseIterable, Sendable {
    case plum, clear, blue, mint, rose, amber
    public var title: String { self == .clear ? "Neutral" : rawValue.capitalized }
}
public enum WallpaperStyle: String, CaseIterable, Sendable {
    case plain, gradient, video
    public var title: String {
        switch self { case .plain: "Plain"; case .gradient: "Purple Glow"; case .video: "My Video" }
    }
}
/// A wallpaper must never keep a decoder running behind another screen.
public enum WallpaperPolicy {
    public static let maximumSeconds: Double = 30
    public static let maximumSourceBytes = 256 * 1024 * 1024
    public static func plays(active: Bool, visible: Bool, reduceMotion: Bool, lowPower: Bool, thermallyLimited: Bool) -> Bool {
        active && visible && !reduceMotion && !lowPower && !thermallyLimited
    }
    /// Persist only an opaque identity, never an arbitrary path or private filename.
    public static func videoID(_ value: String) -> UUID? { UUID(uuidString: value) }
    public static func clipDuration(_ seconds: Double) -> Double? {
        guard seconds.isFinite, seconds > 0 else { return nil }
        return min(seconds, maximumSeconds)
    }
    public static func dimming(_ value: Double) -> Double {
        value.isFinite ? min(0.85, max(0.25, value)) : 0.55
    }
}

