import XCTest
@testable import CalcCore

final class BackupImportTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    private func library(_ name: String, password: String = "a sufficiently long recovery password") throws -> VaultRepository {
        let value = VaultRepository(root: directory.appendingPathComponent(name))
        try value.create(password: password); return value
    }
    private func preview(_ source: VaultRepository, password: String = "a sufficiently long recovery password") throws -> VaultRepository {
        let backup = directory.appendingPathComponent(UUID().uuidString + ".c84backup")
        try source.exportBackup(to: backup)
        let preview = VaultRepository(root: directory.appendingPathComponent(UUID().uuidString))
        try preview.restore(from: backup, password: password)
        return preview
    }
    func testSelectedItemsReencryptUnderCurrentKeyAndKeepDates() throws {
        let source = try library("old"), destination = try library("new", password: "a different recovery password")
        let existing = try destination.add(data: Data("keep".utf8), name: "existing", contentType: "public.data")
        let date = Date(timeIntervalSince1970: 1_650_000_000)
        let chosen = try source.add(data: Data("new photo".utf8), name: "photo.jpg", contentType: "public.jpeg", details: .init(captured: date))
        try source.update(id: chosen.id, favorite: true, album: "Travel")
        _ = try source.add(data: Data("leave behind".utf8), name: "other.jpg", contentType: "public.jpeg")
        let originalKey = try destination.credential(), originalHeader = try Data(contentsOf: destination.root.appendingPathComponent("header.json"))
        let result = try destination.importBackup(preview(source), selected: [chosen.id])
        XCTAssertEqual(result.added, 1); XCTAssertEqual(result.skipped, 0)
        let imported = try XCTUnwrap(result.items.first { $0.name == "photo.jpg" })
        XCTAssertNotEqual(imported.id, chosen.id)
        XCTAssertEqual(imported.captured, date); XCTAssertEqual(imported.added, chosen.added)
        XCTAssertEqual(imported.favorite, true); XCTAssertEqual(imported.album, "Travel")
        XCTAssertEqual(try destination.contents(of: imported.id), Data("new photo".utf8))
        XCTAssertEqual(try destination.contents(of: existing.id), Data("keep".utf8))
        XCTAssertEqual(try destination.credential().key, originalKey.key)
        XCTAssertEqual(try Data(contentsOf: destination.root.appendingPathComponent("header.json")), originalHeader)
        let export = directory.appendingPathComponent("merged.c84backup"); try destination.exportBackup(to: export)
        let roundtrip = VaultRepository(root: directory.appendingPathComponent("roundtrip"))
        XCTAssertThrowsError(try roundtrip.restore(from: export, password: "a sufficiently long recovery password"))
        try roundtrip.restore(from: export, password: "a different recovery password")
        XCTAssertEqual(roundtrip.items.count, 2)
    }
    func testDuplicateContentAcrossDifferentIDsAndRepeatedImportsIsSkipped() throws {
        let source = try library("old"), destination = try library("new")
        let data = Data(repeating: 42, count: 1_100_000)
        let old = try source.add(data: data, name: "old.jpg", contentType: "public.jpeg")
        let current = try destination.add(data: data, name: "renamed.jpg", contentType: "public.jpeg")
        let checked = try preview(source)
        for _ in 0..<2 {
            let result = try destination.importBackup(checked, selected: [old.id])
            XCTAssertEqual(result.added, 0); XCTAssertEqual(result.skipped, 1)
            XCTAssertEqual(result.items.map(\.id), [current.id])
        }
    }
    func testLivePhotoCompanionAndThumbnailRemainAssociated() throws {
        let source = try library("old"), destination = try library("new")
        let primary = try source.add(data: Data("still".utf8), name: "live.jpg", contentType: "public.jpeg", pending: true)
        let motion = try source.add(data: Data("motion".utf8), name: "motion.mov", contentType: "public.movie", pending: true)
        let thumb = try source.add(data: Data("thumbnail".utf8), name: "thumb.jpg", contentType: "public.jpeg", pending: true)
        try source.associate(primary: primary.id, companion: motion.id, thumbnail: thumb.id)
        _ = try destination.add(data: Data("still".utf8), name: "ordinary.jpg", contentType: "public.jpeg")
        let result = try destination.importBackup(preview(source), selected: [primary.id])
        XCTAssertEqual(result.added, 1)
        let imported = try XCTUnwrap(result.items.first { $0.companionID != nil })
        XCTAssertEqual(result.items.filter(\.visible).count, 2)
        XCTAssertEqual(try destination.contents(of: XCTUnwrap(imported.companionID)), Data("motion".utf8))
        XCTAssertEqual(try destination.contents(of: XCTUnwrap(imported.thumbnailID)), Data("thumbnail".utf8))
        try destination.verifyImportedCopies([imported.id])
    }
    func testCorruptionAfterPreviewRollsBackEntireAddition() throws {
        let source = try library("old"), destination = try library("new")
        _ = try destination.add(data: Data("keep".utf8), name: "keep", contentType: "public.data")
        let a = try source.add(data: Data("a".utf8), name: "a", contentType: "public.data")
        let b = try source.add(data: Data("b".utf8), name: "b", contentType: "public.data")
        let checked = try preview(source)
        let before = try Data(contentsOf: destination.root.appendingPathComponent("index.enc"))
        let files = try FileManager.default.contentsOfDirectory(atPath: destination.root.path).sorted()
        try Data("damaged".utf8).write(to: checked.root.appendingPathComponent(a.id.uuidString + ".enc"))
        XCTAssertThrowsError(try destination.importBackup(checked, selected: [a.id, b.id]))
        XCTAssertEqual(try Data(contentsOf: destination.root.appendingPathComponent("index.enc")), before)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.root.path).sorted(), files)
        XCTAssertEqual(destination.items.count, 1)
    }
    func testManualChoicesNeverOptInAndSourceBlocksWinWithAutomaticDestination() throws {
        let source = try library("old"), destination = try library("new")
        let photo = try source.add(data: Data("photo".utf8), name: "p", contentType: "public.jpeg")
        try source.setCloudPolicy(.init(mode: .automatic, blocked: [photo.id]), provider: .mega)
        try source.setCloudPolicy(.init(selected: [photo.id]), provider: .blomp)
        try destination.setCloudPolicy(.init(mode: .automatic), provider: .mega)
        let result = try destination.importBackup(preview(source), selected: [photo.id])
        let imported = try XCTUnwrap(result.items.first)
        let policies = try destination.cloudPreferences()
        XCTAssertTrue(policies.mega.blocked.contains(imported.id))
        XCTAssertFalse(policies.mega.includes(imported)); XCTAssertFalse(policies.blomp.includes(imported))
        XCTAssertEqual(policies.blomp.mode, .manual)
    }
    func testCancelledMergeAndInvalidSelectionLeaveDestinationUntouched() async throws {
        let source = try library("old"), destination = try library("new")
        let photo = try source.add(data: Data(repeating: 9, count: 2_100_000), name: "p", contentType: "public.jpeg")
        let checked = try preview(source), before = try Data(contentsOf: destination.root.appendingPathComponent("index.enc"))
        XCTAssertThrowsError(try destination.importBackup(checked, selected: [UUID()]))
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try destination.importBackup(checked, selected: [photo.id])
        }
        do { _ = try await task.value; XCTFail("Cancelled task must fail") } catch is CancellationError {} catch { XCTFail("\(error)") }
        XCTAssertEqual(try Data(contentsOf: destination.root.appendingPathComponent("index.enc")), before)
        XCTAssertTrue(destination.items.isEmpty)
    }
    func testAllSixDesignsRemainAvailableWithClearGlassDefault() {
        XCTAssertEqual(GalleryStyle.initial, .clearGlass)
        XCTAssertEqual(Set(GalleryStyle.allCases.map(\.rawValue)).count, 6)
        XCTAssertEqual(GalleryStyle.contactSheet.columns, 4)
        XCTAssertEqual(GalleryStyle.clearGlass.aspectRatio, 0.85)
        XCTAssertEqual(GalleryStyle.nightroom.columns, 2)
    }
}
