import XCTest
@testable import CalcCore

final class BackupAndScrollTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testExternalBackupCopyRestoresOriginalAndDates() throws {
        let original = VaultRepository(root: directory.appendingPathComponent("original"))
        let secret = VaultCode.generateRecovery()
        try original.create(password: secret)
        let bytes = Data(repeating: 0x64, count: 2 * 1024 * 1024 + 7)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let item = try original.add(data: bytes, name: "sample.mov", contentType: "public.movie", details: MediaDetails(captured: date))
        let source = directory.appendingPathComponent("prepared.c84backup")
        let copy = directory.appendingPathComponent("external.c84backup")
        try original.exportBackup(to: source)
        try BackupCopy.copy(source, to: copy)
        try FileManager.default.removeItem(at: source)
        let restored = VaultRepository(root: directory.appendingPathComponent("restored"))
        try restored.restore(from: copy, password: secret)
        XCTAssertEqual(try restored.contents(of: item.id), bytes)
        XCTAssertEqual(restored.items.first?.captured, date)
    }

    func testExistingBackupIsNeverOverwritten() throws {
        let source = directory.appendingPathComponent("source")
        let destination = directory.appendingPathComponent("saved")
        try Data("new snapshot".utf8).write(to: source)
        let old = Data("keep this snapshot".utf8)
        try old.write(to: destination)
        XCTAssertThrowsError(try BackupCopy.copy(source, to: destination))
        XCTAssertEqual(try Data(contentsOf: destination), old)
    }

    func testVerificationRejectsTruncationAndAppendedDataWithoutDeletingCopy() throws {
        let source = directory.appendingPathComponent("source")
        let copy = directory.appendingPathComponent("copy")
        let bytes = Data(repeating: 0xA1, count: 1024 * 1024 + 9)
        try bytes.write(to: source)
        let expected = try BackupCopy.digest(source)
        try BackupCopy.copy(source, to: copy)
        try BackupCopy.verify(copy, expected: expected)
        try bytes.dropLast().write(to: copy)
        XCTAssertThrowsError(try BackupCopy.verify(copy, expected: expected))
        try (bytes + Data([0])).write(to: copy)
        XCTAssertThrowsError(try BackupCopy.verify(copy, expected: expected))
        XCTAssertTrue(FileManager.default.fileExists(atPath: copy.path))
        XCTAssertEqual(try Data(contentsOf: source), bytes)
    }

    func testDateHandleMapsToActualContentAndClampsOverscroll() {
        XCTAssertEqual(LibraryScrollPosition.fraction(offset: -60, content: 3000, viewport: 600), 0)
        XCTAssertEqual(LibraryScrollPosition.fraction(offset: 1200, content: 3000, viewport: 600), 0.5)
        XCTAssertEqual(LibraryScrollPosition.fraction(offset: 3000, content: 3000, viewport: 600), 1)
        XCTAssertEqual(LibraryScrollPosition.offset(fraction: 0.5, content: 3000, viewport: 600), 1200)
        XCTAssertEqual(LibraryScrollPosition.offset(fraction: 2, content: 3000, viewport: 600), 2400)
        XCTAssertEqual(LibraryScrollPosition.offset(fraction: -1, content: 3000, viewport: 600), 0)
    }

    func testShortAndEmptyLibrariesNeverProduceInvalidScrollPositions() {
        XCTAssertEqual(LibraryScrollPosition.fraction(offset: 20, content: 100, viewport: 600), 0)
        XCTAssertEqual(LibraryScrollPosition.offset(fraction: 0.8, content: 100, viewport: 600), 0)
        XCTAssertEqual(LibraryScrollPosition.fraction(offset: .nan, content: 3000, viewport: 600), 0)
        XCTAssertEqual(LibraryScrollPosition.offset(fraction: .infinity, content: 3000, viewport: 600), 0)
    }
}
