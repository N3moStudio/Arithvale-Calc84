import XCTest
@testable import CalcCore

final class ImportedCopyVerificationTests: XCTestCase {
    private var folder: URL!
    private var repository: VaultRepository!
    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        repository = VaultRepository(root: folder.appendingPathComponent("library"))
        try repository.create(password: "a disposable recovery secret for tests")
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: folder) }
    private func add(_ name: String = "photo") throws -> VaultItem {
        try repository.add(data: Data(name.utf8), name: name, contentType: "public.jpeg")
    }
    private func damage(_ url: URL) throws {
        var bytes = try Data(contentsOf: url)
        bytes[bytes.count - 1] ^= 1
        try bytes.write(to: url)
    }
    func testVerificationDoesNotDeleteOrExportAnyCopy() throws {
        let a = try add(), b = try add("another photo")
        let before = try FileManager.default.contentsOfDirectory(atPath: repository.root.path).sorted()
        try repository.verifyImportedCopies([a.id, b.id, a.id])
        XCTAssertEqual(before, try FileManager.default.contentsOfDirectory(atPath: repository.root.path).sorted())
        XCTAssertEqual(try repository.contents(of: a.id), Data("photo".utf8))
        XCTAssertEqual(repository.items.count, 2)
    }
    func testRejectsPendingDeletedMissingAndLockedItems() throws {
        let pending = try repository.add(data: Data([1]), name: "partial", contentType: "public.jpeg", pending: true)
        let deleted = try add()
        try repository.update(id: deleted.id, deleted: true)
        XCTAssertThrowsError(try repository.verifyImportedCopies([pending.id]))
        XCTAssertThrowsError(try repository.verifyImportedCopies([deleted.id]))
        XCTAssertThrowsError(try repository.verifyImportedCopies([UUID()]))
        XCTAssertThrowsError(try repository.verifyImportedCopies([]))
        repository.lock()
        XCTAssertThrowsError(try repository.verifyImportedCopies([deleted.id]))
    }
    func testCorruptedMainCopyBlocksEntireBatch() throws {
        let good = try add("good"), bad = try add("bad")
        try damage(repository.root.appendingPathComponent(bad.id.uuidString + ".enc"))
        XCTAssertThrowsError(try repository.verifyImportedCopies([good.id, bad.id]))
        XCTAssertEqual(try repository.contents(of: good.id), Data("good".utf8))
    }
    func testLivePhotoCompanionMustStillAuthenticate() throws {
        let primary = try repository.add(data: Data([1]), name: "still", contentType: "public.heic", pending: true)
        let companion = try repository.add(data: Data([2]), name: "motion", contentType: "public.movie", pending: true)
        try repository.associate(primary: primary.id, companion: companion.id, thumbnail: nil)
        try repository.verifyImportedCopies([primary.id])
        try damage(repository.root.appendingPathComponent(companion.id.uuidString + ".enc"))
        XCTAssertThrowsError(try repository.verifyImportedCopies([primary.id]))
        XCTAssertEqual(try repository.contents(of: primary.id), Data([1]))
    }
    func testReadsCommittedIndexRatherThanTrustingInMemoryItems() throws {
        let item = try add()
        try damage(repository.root.appendingPathComponent("index.enc"))
        XCTAssertTrue(repository.items.contains { $0.id == item.id })
        XCTAssertThrowsError(try repository.verifyImportedCopies([item.id]))
    }

    func testMissingLivePhotoMotionBlocksDeletionEvenWhenStillIsReadable() throws {
        let primary = try repository.add(data: Data([1]), name: "still", contentType: "public.heic", pending: true)
        let companion = try repository.add(data: Data([2]), name: "motion", contentType: "public.movie", pending: true)
        try repository.associate(primary: primary.id, companion: companion.id, thumbnail: nil)
        try FileManager.default.removeItem(at: repository.root.appendingPathComponent(companion.id.uuidString + ".enc"))
        XCTAssertEqual(try repository.contents(of: primary.id), Data([1]))
        XCTAssertThrowsError(try repository.verifyImportedCopies([primary.id]))
    }
}
