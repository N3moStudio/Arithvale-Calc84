import XCTest
@testable import CalcCore

/// Public synthetic fixtures let Python exercise the real Swift writer without
/// sharing the app's decoder or touching any user's photos or recovery key.
final class ArithenRecoveryFixtureTests: XCTestCase {
    func testRedundantBackupRoundTripAndWriteIndependentFixturesWhenRequested() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let secret = "C24144AF-B3E94438-97C89127-E373D053-9F19F720-E47CA588-7C38BF10-14C2AF32"
        let source = VaultRepository(root: folder.appendingPathComponent("source"))
        try source.create(password: secret)
        let captured = Date(timeIntervalSince1970: 1_680_000_000.125)
        let photo = try source.add(data: Data("portable original bytes".utf8), name: "../../AUX.jpg",
                                   contentType: "public.jpeg",
                                   details: MediaDetails(captured: captured, latitude: -33.75, longitude: -118.25))
        try source.organize(ids: [photo.id], albums: ["Travel", "Receipts"], tags: ["ticket", "été"], mode: .add)
        let video = try source.add(data: Data(repeating: 0xA7, count: VaultLimits.chunkBytes + 7),
                                   name: "video.mov", contentType: "public.movie",
                                   details: MediaDetails(captured: captured, duration: 2.5, latitude: 34.05, longitude: -118.25))
        let empty = try source.add(data: Data(), name: "empty.bin", contentType: "public.data")
        let archive = folder.appendingPathComponent("v3.c84backup")
        try source.exportBackup(to: archive)
        let bytes = try Data(contentsOf: archive)
        XCTAssertEqual(bytes.prefix(8), Data("ARITHB03".utf8))
        XCTAssertEqual(bytes.suffix(8), Data("ARITHEND".utf8))
        let restored = VaultRepository(root: folder.appendingPathComponent("restored"))
        try restored.restore(from: archive, password: secret)
        XCTAssertEqual(restored.items.count, 3)
        for original in [photo, video, empty] {
            XCTAssertEqual(try restored.contents(of: original.id), try source.contents(of: original.id))
            let recovered = try XCTUnwrap(restored.items.first { $0.id == original.id })
            XCTAssertEqual(recovered.captured, original.captured)
            XCTAssertEqual(recovered.latitude, original.latitude)
            XCTAssertEqual(recovered.longitude, original.longitude)
        }
        guard let path = ProcessInfo.processInfo.environment["C84_FIXTURE_DIR"] else { return }
        let destination = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: archive, to: destination.appendingPathComponent("v3.c84backup"))
        try source.update(id: photo.id, favorite: true)
        // A second independently authenticated catalog enables disagreement tests.
        try source.exportBackup(to: destination.appendingPathComponent("v3-other.c84backup"))
    }
}
