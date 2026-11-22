import XCTest
@testable import CalcCore
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

final class IndexedBackupRecoveryTests: XCTestCase {
    private var root: URL!
    private let secret = "disposable indexed recovery test password"
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    private func library(_ name: String = UUID().uuidString) throws -> VaultRepository {
        let value = VaultRepository(root: root.appendingPathComponent(name))
        try value.create(password: secret); return value
    }
    private func destination() -> VaultRepository { VaultRepository(root: root.appendingPathComponent(UUID().uuidString)) }
    private func add(_ repo: VaultRepository, name: String) throws -> VaultItem {
        try repo.add(data: Data(name.utf8), name: name, contentType: "public.jpeg")
    }
    private func export(_ repo: VaultRepository) throws -> URL {
        let url = root.appendingPathComponent(UUID().uuidString + ".arithenbackup")
        try repo.exportBackup(to: url); return url
    }
    private func opened(_ url: URL, source: VaultRepository) throws -> ArithenBackupArchive.Opened {
        let key = SymmetricKey(data: try source.credential().key)
        return try ArithenBackupArchive.read(url) { _ in key }
    }
    private func corrupt(_ url: URL, id: UUID, source: VaultRepository) throws -> URL {
        let metadata = try opened(url, source: source)
        let i = try XCTUnwrap(metadata.records.firstIndex { $0.id == id })
        let offset = Int(metadata.bodyStart) + metadata.records.prefix(i).reduce(0) { $0 + $1.bytes }
        var data = try Data(contentsOf: url); data[offset + metadata.records[i].bytes / 2] ^= 1
        let copy = root.appendingPathComponent(UUID().uuidString + ".arithenbackup")
        try data.write(to: copy); return copy
    }
    private func assertNoStages(file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix("stage-") }, file: file, line: line)
    }

    func testExportRejectsCorruptedCommittedIndexBeforePublishingBackup() throws {
        let source = try library(), item = try add(source, name: "readable original")
        let index = source.root.appendingPathComponent("index.enc")
        var damaged = try Data(contentsOf: index); damaged[damaged.count - 1] ^= 1
        try damaged.write(to: index)
        let output = root.appendingPathComponent("must-not-exist.arithenbackup")
        XCTAssertThrowsError(try source.exportBackup(to: output))
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        XCTAssertEqual(try source.contents(of: item.id), Data("readable original".utf8))
        XCTAssertEqual(try Data(contentsOf: index), damaged)
        try assertNoStages()
    }

    func testExportRejectsAuthenticatedButStaleCommittedIndex() throws {
        let source = try library()
        let index = source.root.appendingPathComponent("index.enc")
        let oldIndex = try Data(contentsOf: index)
        let item = try add(source, name: "new item")
        let currentIndex = try Data(contentsOf: index)
        try oldIndex.write(to: index)
        let output = root.appendingPathComponent("stale-must-not-exist.arithenbackup")
        XCTAssertThrowsError(try source.exportBackup(to: output)) { error in
            guard let error = error as? VaultError, error == .changed else { return XCTFail("Expected stale index rejection") }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        XCTAssertEqual(try source.contents(of: item.id), Data("new item".utf8))
        try currentIndex.write(to: index)
        try source.exportBackup(to: output)
        let restored = destination(); try restored.restore(from: output, password: secret)
        XCTAssertEqual(try restored.contents(of: item.id), Data("new item".utf8))
        try assertNoStages()
    }

    func testDefaultArchiveRestoresExactMetadataAndBytesAfterSourceRemoval() throws {
        let source = try library()
        let original = root.appendingPathComponent("photo.jpg")
        let bytes = Data(repeating: 7, count: 3 * 1024 * 1024 + 17)
        try bytes.write(to: original)
        let capture = Date(timeIntervalSince1970: 978404645)
        let item = try source.add(file: original, name: "old-photo.jpg", contentType: "public.jpeg",
            details: .init(captured: capture, latitude: 37.3, longitude: -122.0))
        try source.update(id: item.id, favorite: true)
        try source.organize(ids: [item.id], albums: ["Trip"], tags: ["memory"], mode: .add)
        let expected = source.items
        let archive = try export(source)
        XCTAssertEqual(try Data(contentsOf: archive).prefix(8), ArithenBackupArchive.magic)
        source.lock(); try FileManager.default.removeItem(at: source.root)
        try FileManager.default.removeItem(at: original)
        let restored = destination()
        try restored.restore(from: archive, password: secret)
        XCTAssertEqual(restored.items, expected)
        XCTAssertEqual(try restored.contents(of: item.id), bytes)
        XCTAssertFalse(restored.restorationRecoveredMetadata)
        try assertNoStages()
    }

    func testEitherDamagedCatalogStillRestoresAndReportsMetadataRecovery() throws {
        let source = try library(), item = try add(source, name: "keep")
        let archive = try export(source), metadata = try opened(archive, source: source)
        let bodyEnd = Int(metadata.bodyStart) + metadata.records.reduce(0) { $0 + $1.bytes }
        for index in [16, bodyEnd] {
            var bytes = try Data(contentsOf: archive); bytes[index] ^= 255
            let damaged = root.appendingPathComponent(UUID().uuidString)
            try bytes.write(to: damaged)
            let restored = destination()
            try restored.restore(from: damaged, password: secret)
            XCTAssertTrue(restored.restorationRecoveredMetadata)
            XCTAssertEqual(try restored.contents(of: item.id), Data("keep".utf8))
        }
        try assertNoStages()
    }

    func testDamagedAssetStrictlyRejectsButExplicitRecoveryReportsOnlyIntactItems() throws {
        let source = try library(), good = try add(source, name: "good"), bad = try add(source, name: "bad")
        let archive = try corrupt(export(source), id: bad.id, source: source)
        let originalBytes = try Data(contentsOf: archive)
        let strict = destination()
        XCTAssertThrowsError(try strict.restore(from: archive, password: secret))
        XCTAssertFalse(strict.exists); XCTAssertTrue(strict.items.isEmpty)
        try assertNoStages()
        let recovered = destination(), report = try recovered.restoreRecoverable(from: archive, password: secret)
        XCTAssertEqual(report.skippedItemCount, 1); XCTAssertEqual(report.damagedResourceCount, 1)
        XCTAssertFalse(report.metadataRecovered)
        XCTAssertEqual(report.items.map(\.id), [good.id])
        XCTAssertEqual(try recovered.contents(of: good.id), Data("good".utf8))
        XCTAssertThrowsError(try recovered.contents(of: bad.id))
        XCTAssertEqual(try Data(contentsOf: archive), originalBytes)
        let cleanArchive = try export(recovered), reopened = destination()
        try reopened.restore(from: cleanArchive, password: secret)
        XCTAssertEqual(reopened.items.map(\.id), [good.id])
        try assertNoStages()
    }

    func testDamagedLivePhotoCompanionExcludesItsStillAndClearsAlbumCover() throws {
        let source = try library()
        let still = try source.add(data: Data("still".utf8), name: "still.heic", contentType: "public.heic", pending: true)
        let motion = try source.add(data: Data("motion".utf8), name: "motion.mov", contentType: "com.apple.quicktime-movie", pending: true)
        try source.associate(primary: still.id, companion: motion.id, thumbnail: nil)
        let keep = try add(source, name: "keep")
        try source.organize(ids: [still.id, keep.id], albums: ["Trip"], tags: [], mode: .add)
        try source.setAlbumPreference(.init(pinned: true, coverID: still.id), name: "Trip")
        let archive = try corrupt(export(source), id: motion.id, source: source)
        let recovered = destination(), report = try recovered.restoreRecoverable(from: archive, password: secret)
        XCTAssertEqual(report.skippedItemCount, 1); XCTAssertEqual(report.damagedResourceCount, 1)
        XCTAssertEqual(report.items.map(\.id), [keep.id])
        XCTAssertNil(try recovered.albumPreferences()["Trip"]?.coverID)
        XCTAssertEqual(try recovered.albumPreferences()["Trip"]?.pinned, true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recovered.root.appendingPathComponent(still.id.uuidString + ".enc").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: recovered.root.appendingPathComponent(motion.id.uuidString + ".enc").path))
        XCTAssertEqual(try recovered.contents(of: keep.id), Data("keep".utf8))
        try assertNoStages()
    }

    func testDamagedThumbnailIsDroppedWithoutLosingOriginal() throws {
        let source = try library()
        let primary = try source.add(data: Data("original".utf8), name: "original.jpg", contentType: "public.jpeg", pending: true)
        let thumbnail = try source.add(data: Data("preview".utf8), name: "preview.jpg", contentType: "public.jpeg", pending: true)
        try source.associate(primary: primary.id, companion: nil, thumbnail: thumbnail.id)
        let archive = try corrupt(export(source), id: thumbnail.id, source: source)
        let recovered = destination(), report = try recovered.restoreRecoverable(from: archive, password: secret)
        XCTAssertEqual(report.skippedItemCount, 0); XCTAssertEqual(report.damagedResourceCount, 1)
        XCTAssertEqual(report.items.map(\.id), [primary.id]); XCTAssertNil(report.items.first?.thumbnailID)
        XCTAssertEqual(try recovered.contents(of: primary.id), Data("original".utf8))
        let strict = destination(); try strict.restore(from: export(recovered), password: secret)
        XCTAssertNil(strict.items.first?.thumbnailID)
        try assertNoStages()
    }

    func testWrongKeyAndExistingLibraryNeverPublishOrReplaceDataDuringRecovery() throws {
        let source = try library(), bad = try add(source, name: "broken"), keep = try add(source, name: "keep")
        let archive = try corrupt(export(source), id: bad.id, source: source)
        let empty = destination()
        XCTAssertThrowsError(try empty.restoreRecoverable(from: archive, password: "incorrect disposable password"))
        XCTAssertFalse(empty.exists)
        let existing = try library(), local = try add(existing, name: "existing original")
        let before = try Data(contentsOf: existing.root.appendingPathComponent("index.enc"))
        XCTAssertThrowsError(try existing.restoreRecoverable(from: archive, password: secret))
        XCTAssertEqual(try Data(contentsOf: existing.root.appendingPathComponent("index.enc")), before)
        XCTAssertEqual(existing.items.map(\.id), [local.id])
        XCTAssertEqual(try existing.contents(of: local.id), Data("existing original".utf8))
        XCTAssertEqual(try source.contents(of: keep.id), Data("keep".utf8))
        try assertNoStages()
    }
}
