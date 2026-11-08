import XCTest
import SwiftUI
@testable import NativeSettingsKit

final class AppearanceContractTests: XCTestCase {
    func testCompactTypographyPreservesAccessibilityCategories() {
        for size: DynamicTypeSize in [.accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5] {
            XCTAssertEqual(NSKTypography.compact(size), size)
        }
        XCTAssertEqual(NSKTypography.compact(.large), .medium)
        XCTAssertEqual(NSKTypography.compact(.xSmall), .xSmall)
    }

    func testLegacyValuesAdaptWithoutGuessingUnknownValues() {
        XCTAssertEqual(NSKTheme.legacyValue("abyss"), .bloom)
        XCTAssertEqual(NSKSurface.legacyValue("theme"), .solid)
        XCTAssertNil(NSKTheme.legacyValue("a-future-host-theme"))
        XCTAssertNil(NSKSurface.legacyValue("unknown"))
    }

    func testAccessibilityOverridesTransparency() {
        for choice in NSKSurface.allCases {
            XCTAssertFalse(choice.allowsTransparency(reduceTransparency: true, increasedContrast: false))
            XCTAssertFalse(choice.allowsTransparency(reduceTransparency: false, increasedContrast: true))
        }
        XCTAssertFalse(NSKSurface.solid.allowsTransparency(reduceTransparency: false, increasedContrast: false))
        XCTAssertTrue(NSKSurface.glass.allowsTransparency(reduceTransparency: false, increasedContrast: false))
    }

    func testAllSolidPaletteTextPairsMeetNormalTextContrast() {
        for theme in NSKTheme.allCases {
            for dark in [false, true] {
                let values = theme.palette(dark: dark).hex
                // primary, muted, secondary and accent text on both content backgrounds;
                // button label on accent. Disabled/decorative colors are not text claims.
                for (foreground, background) in [(5, 3), (5, 4), (6, 3), (6, 4), (2, 3), (2, 4), (0, 3), (0, 4), (1, 0)] {
                    XCTAssertGreaterThanOrEqual(contrast(values[foreground], values[background]), 4.5,
                                               "\(theme.rawValue) dark=\(dark) pair=\(foreground)/\(background)")
                }
            }
        }
    }

    private func luminance(_ value: UInt32) -> Double {
        let rgb = [16, 8, 0].map { shift -> Double in
            let channel = Double((value >> shift) & 255) / 255
            return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]
    }
    private func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let x = luminance(a), y = luminance(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
