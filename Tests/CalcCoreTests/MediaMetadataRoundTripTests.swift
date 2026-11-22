import XCTest
@testable import CalcCore

final class MediaMetadataRoundTripTests: XCTestCase {
    func testPhotoAndVideoDatesAndCoordinatesSurviveRestoreMergeAndReexport() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let originalKey = "original metadata recovery password"
        let newKey = "new destination recovery password"
        let original = VaultRepository(root: root.appendingPathComponent("original"))
        try original.create(password: originalKey)
        let date = Date(timeIntervalSince1970: 1_628_782_000.125)
        let details = MediaDetails(captured: date, duration: 2.5, latitude: -33.75, longitude: -118.25)
        let photo = try original.add(data: Data("original photo bytes".utf8), name: "photo.jpg", contentType: "public.jpeg", details: details)
        let video = try original.add(data: Data("original video bytes".utf8), name: "video.mov", contentType: "com.apple.quicktime-movie", details: details)
        let backup = root.appendingPathComponent("original.c84backup")
        try original.exportBackup(to: backup)
        original.lock()
        let restored = VaultRepository(root: root.appendingPathComponent("restored"))
        try restored.restore(from: backup, password: originalKey)
        let destination = VaultRepository(root: root.appendingPathComponent("destination"))
        try destination.create(password: newKey)
        let imported = try destination.importBackup(restored, selected: [photo.id, video.id])
        XCTAssertEqual(imported.added, 2)
        let merged = root.appendingPathComponent("merged.c84backup")
        try destination.exportBackup(to: merged)
        let roundtrip = VaultRepository(root: root.appendingPathComponent("roundtrip"))
        try roundtrip.restore(from: merged, password: newKey)
        for source in [photo, video] {
            let reloaded = try XCTUnwrap(roundtrip.items.first { $0.name == source.name })
            XCTAssertNotEqual(reloaded.id, source.id)
            XCTAssertEqual(reloaded.captured, date)
            XCTAssertEqual(reloaded.added, source.added)
            XCTAssertEqual(reloaded.latitude, -33.75)
            XCTAssertEqual(reloaded.longitude, -118.25)
            XCTAssertEqual(reloaded.chronologicalDate, date)
            XCTAssertEqual(try roundtrip.contents(of: reloaded.id), try restored.contents(of: source.id))
        }
    }
}
