import XCTest
@testable import CalcCore

final class AppearancePolicyTests: XCTestCase {
    func testPowerPrivacyAndAccessibilityAllGatePlayback() {
        for active in [false, true] { for visible in [false, true] {
            for motion in [false, true] { for power in [false, true] { for heat in [false, true] {
                let expected = active && visible && !motion && !power && !heat
                XCTAssertEqual(WallpaperPolicy.plays(active: active, visible: visible, reduceMotion: motion,
                    lowPower: power, thermallyLimited: heat), expected)
            } } }
        } }
    }
    func testVideoPreferencesCannotBecomePaths() {
        for value in ["../private.mov", "/tmp/movie", "file:///tmp/a.mov", "", "https://example.com/video"] {
            XCTAssertNil(WallpaperPolicy.videoID(value))
        }
        let id = UUID()
        XCTAssertEqual(WallpaperPolicy.videoID(id.uuidString), id)
        XCTAssertNotEqual(AppearanceArea.calculator.videoKey, AppearanceArea.library.videoKey)
    }
    func testVideoBoundsRejectInvalidDurations() {
        for value in [Double.nan, .infinity, -.infinity, 0, -1] { XCTAssertNil(WallpaperPolicy.clipDuration(value)) }
        XCTAssertEqual(WallpaperPolicy.clipDuration(4.5), 4.5)
        XCTAssertEqual(WallpaperPolicy.clipDuration(300), 30)
    }
    func testDimmingCannotLoseMinimumContrastScrim() {
        XCTAssertEqual(WallpaperPolicy.dimming(.nan), 0.55)
        XCTAssertEqual(WallpaperPolicy.dimming(-1), 0.25)
        XCTAssertEqual(WallpaperPolicy.dimming(3), 0.85)
    }
}

