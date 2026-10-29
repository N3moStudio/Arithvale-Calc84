import Foundation

public enum AppearanceArea: String, CaseIterable, Sendable {
    case calculator, library
    public var tintKey: String { rawValue + "GlassTint" }
    public var backgroundKey: String { rawValue + "BackgroundStyle" }
    public var videoKey: String { rawValue + "BackgroundVideo" }
    public var dimmingKey: String { rawValue + "BackgroundDimming" }
    public var editKey: String { rawValue + "BackgroundEdit.v1" }
}

public struct WallpaperEdit: Codable, Equatable, Sendable {
    public var start: Double = 0
    public var duration: Double = 30
    /// Time within the chosen loop, rather than the original video.
    public var still: Double = 0
    public var horizontal: Double = 0.5
    public var vertical: Double = 0.5
    public init() {}
    public func normalized(sourceDuration: Double) -> WallpaperEdit? {
        guard sourceDuration.isFinite, sourceDuration > 0 else { return nil }
        var result = self
        let minimum = min(0.5, sourceDuration)
        result.start = min(max(0, start.isFinite ? start : 0), max(0, sourceDuration - minimum))
        result.duration = min(sourceDuration - result.start, min(30, max(minimum, duration.isFinite ? duration : 30)))
        result.still = min(max(0, still.isFinite ? still : 0), max(0, result.duration - 0.01))
        result.horizontal = min(1, max(0, horizontal.isFinite ? horizontal : 0.5))
        result.vertical = min(1, max(0, vertical.isFinite ? vertical : 0.5))
        return result
    }
}

public struct WallpaperCrop: Equatable, Sendable {
    public let width: Double, height: Double, x: Double, y: Double
    public static func layout(sourceWidth: Double, sourceHeight: Double, width: Double, height: Double, edit: WallpaperEdit) -> WallpaperCrop {
        guard [sourceWidth, sourceHeight, width, height].allSatisfy({ $0.isFinite && $0 > 0 }) else {
            return .init(width: 0, height: 0, x: 0, y: 0)
        }
        let scale = max(width / sourceWidth, height / sourceHeight)
        let w = sourceWidth * scale, h = sourceHeight * scale
        let x = min(1, max(0, edit.horizontal.isFinite ? edit.horizontal : 0.5))
        let y = min(1, max(0, edit.vertical.isFinite ? edit.vertical : 0.5))
        return .init(width: w, height: h, x: -(w - width) * x, y: -(h - height) * y)
    }
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

