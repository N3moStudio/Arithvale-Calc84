import XCTest
@testable import CalcCore

final class ThemeAndInboxTests: XCTestCase {
    func testThemeDefaultsAndLegacyMigration() throws {
        XCTAssertEqual(ArithenTheme.allCases.map(\.rawValue), ["glacier", "afterhours", "porcelain", "ion", "ember", "bloom", "blueprint", "titanium"])
        XCTAssertEqual(ArithenTheme(storedValue: nil), .bloom)
        XCTAssertEqual(ArithenTheme(storedValue: "abyss"), .bloom)
        XCTAssertEqual(try JSONDecoder().decode(ArithenTheme.self, from: Data("\"abyss\"".utf8)), .bloom)
        XCTAssertThrowsError(try JSONDecoder().decode(ArithenTheme.self, from: Data("\"unknown\"".utf8)))
        for theme in ArithenTheme.allCases {
            XCTAssertEqual(try JSONDecoder().decode(ArithenTheme.self, from: JSONEncoder().encode(theme)), theme)
        }
    }
    func testWholeBloomPaletteAndThemeColorModes() {
        XCTAssertEqual(ArithenTheme.Ink.allCases.map { ArithenTheme.bloom.hex($0, dark: false) },
                       [0xA62E76, 0xFFFFFF, 0x81516C, 0xF8EFF3, 0xFFF9FC, 0x352131, 0x755C6D])
        for theme in [ArithenTheme.afterhours, .ion, .ember, .titanium] { XCTAssertTrue(theme.isDark(systemDark: false)) }
        for theme in [ArithenTheme.porcelain, .bloom, .blueprint] { XCTAssertFalse(theme.isDark(systemDark: true)) }
        XCTAssertTrue(ArithenTheme.glacier.isDark(systemDark: true))
        XCTAssertFalse(ArithenTheme.glacier.isDark(systemDark: false))
        XCTAssertFalse(ThemeSurface.theme.usesGlass)
        XCTAssertFalse(ThemeSurface.solid.usesGlass)
        XCTAssertTrue(ThemeSurface.glass.usesGlass)
    }
    func testCompactDoesNotShrinkAccessibilityOrBelowMinimum() {
        XCTAssertEqual(CompactTypography.category(0, accessibility: false), 0)
        XCTAssertEqual(CompactTypography.category(3, accessibility: false), 2)
        for size in 7...11 { XCTAssertEqual(CompactTypography.category(size, accessibility: true), size) }
    }
    private func fixture(_ test: (URL, SharedFileInbox, Data) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try test(root, SharedFileInbox(root: root.appendingPathComponent("inbox")), SharedFileInbox.newKey())
    }
    func testReceivedFilesAreEncryptedAndSurviveRestart() throws {
        try fixture { root, inbox, key in
            let source = root.appendingPathComponent("personal-photo.jpg")
            let bytes = Data(String(repeating: "PRIVATE PHOTO BYTES", count: 120_000).utf8)
            try bytes.write(to: source)
            let entry = try inbox.receive(source, key: key)
            let fresh = SharedFileInbox(root: inbox.root)
            XCTAssertEqual(try fresh.entries(key: key), [entry])
            let received = inbox.root.appendingPathComponent(entry.id.uuidString)
            XCTAssertNil(try Data(contentsOf: received.appendingPathComponent("contents")).range(of: Data("PRIVATE PHOTO BYTES".utf8)))
            XCTAssertNil(try Data(contentsOf: received.appendingPathComponent("metadata")).range(of: Data(source.lastPathComponent.utf8)))
            let out = root.appendingPathComponent("restored.jpg")
            try fresh.materialize(entry, key: key, to: out)
            XCTAssertEqual(try Data(contentsOf: out), bytes)
            try fresh.discard(entry.id)
            XCTAssertTrue(try fresh.entries(key: key).isEmpty)
            XCTAssertEqual(try Data(contentsOf: source), bytes)
        }
    }
    func testInboxRejectsWrongKeyAndTampering() throws {
        try fixture { root, inbox, key in
            let source = root.appendingPathComponent("test.txt"); try Data("important".utf8).write(to: source)
            let entry = try inbox.receive(source, key: key)
            XCTAssertThrowsError(try inbox.entries(key: SharedFileInbox.newKey()))
            let cipher = inbox.root.appendingPathComponent(entry.id.uuidString).appendingPathComponent("contents")
            var bytes = try Data(contentsOf: cipher); bytes[bytes.count - 1] ^= 1; try bytes.write(to: cipher)
            XCTAssertThrowsError(try inbox.materialize(entry, key: key, to: root.appendingPathComponent("out")))
            XCTAssertEqual(try inbox.entries(key: key), [entry])
            XCTAssertEqual(try Data(contentsOf: source), Data("important".utf8))
        }
    }
    func testInboxRejectsLinksAndDoesNotOverwriteSameNames() throws {
        try fixture { root, inbox, key in
            XCTAssertThrowsError(try inbox.receive(URL(string: "https://example.com/photo")!, key: key))
            XCTAssertThrowsError(try inbox.receive(root, key: key))
            let source = root.appendingPathComponent("same.txt"); try Data("first".utf8).write(to: source)
            let link = root.appendingPathComponent("link"); try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
            XCTAssertThrowsError(try inbox.receive(link, key: key))
            let first = try inbox.receive(source, key: key)
            try Data("second".utf8).write(to: source)
            let second = try inbox.receive(source, key: key)
            XCTAssertNotEqual(first.id, second.id)
            XCTAssertEqual(try inbox.entries(key: key).count, 2)
            try inbox.discard(first.id)
            XCTAssertEqual(try inbox.entries(key: key), [second])
        }
    }
    func testMaterializeAuthenticatesItsOwnReceipt() throws {
        try fixture { root, inbox, key in
            let source = root.appendingPathComponent("photo.jpg")
            let bytes = Data("verified original".utf8); try bytes.write(to: source)
            let first = try inbox.receive(source, key: key)
            let second = try inbox.receive(source, key: key)
            let firstMetadata = inbox.root.appendingPathComponent(first.id.uuidString).appendingPathComponent("metadata")
            let secondMetadata = inbox.root.appendingPathComponent(second.id.uuidString).appendingPathComponent("metadata")
            // A different receipt's authenticated metadata cannot be substituted.
            try Data(contentsOf: firstMetadata).write(to: secondMetadata)
            XCTAssertThrowsError(try inbox.materialize(second, key: key, to: root.appendingPathComponent("rejected.jpg")))
            let restored = root.appendingPathComponent("restored.jpg")
            try inbox.materialize(first, key: key, to: restored)
            XCTAssertEqual(try Data(contentsOf: restored), bytes)
        }
    }
}
