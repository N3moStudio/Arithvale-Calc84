import XCTest
@testable import CalcCore

final class BackupInboxTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    private func fixture(_ name: String = "Library.c84backup", secret: String = "original recovery secret") throws -> URL {
        let library = VaultRepository(root: directory.appendingPathComponent(UUID().uuidString))
        try library.create(password: secret)
        _ = try library.add(data: Data("private media".utf8), name: "photo.jpg", contentType: "public.jpeg")
        let url = directory.appendingPathComponent(name)
        try library.exportBackup(to: url)
        return url
    }

    func testSharedBackupSurvivesRestartAndRestoresWithOriginalKey() throws {
        let source = try fixture("Renamed file.bin")
        let root = directory.appendingPathComponent("inbox")
        let received = try BackupInbox(root: root).receive(source)
        XCTAssertEqual(received.displayName, "Renamed file.bin")
        XCTAssertEqual(try BackupCopy.digest(source), try BackupCopy.digest(received.url))
        let reloaded = try XCTUnwrap(BackupInbox(root: root).load())
        XCTAssertEqual(received, reloaded)
        // The received copy no longer depends on the original provider URL.
        try FileManager.default.removeItem(at: source)
        let restored = VaultRepository(root: directory.appendingPathComponent("restore"))
        XCTAssertThrowsError(try restored.restore(from: reloaded.url, password: "wrong key"))
        XCTAssertFalse(restored.exists)
        try restored.restore(from: reloaded.url, password: "original recovery secret")
        let item = try XCTUnwrap(restored.items.first)
        XCTAssertEqual(try restored.contents(of: item.id), Data("private media".utf8))
        XCTAssertThrowsError(try restored.restore(from: reloaded.url, password: "original recovery secret"))
        XCTAssertEqual(try restored.contents(of: item.id), Data("private media".utf8))
    }

    func testDuplicateHandoffAndDiscardCannotOverwriteOrDeleteOriginal() throws {
        let first = try fixture(), second = try fixture("second.c84backup", secret: "different secret")
        let inbox = BackupInbox(root: directory.appendingPathComponent("inbox"))
        let entry = try inbox.receive(first), digest = try BackupCopy.digest(entry.url)
        XCTAssertThrowsError(try inbox.receive(first))
        XCTAssertThrowsError(try inbox.receive(second))
        XCTAssertEqual(try BackupCopy.digest(entry.url), digest)
        try inbox.discard()
        XCTAssertNil(try inbox.load())
        XCTAssertEqual(try BackupCopy.digest(first), digest)
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
        XCTAssertEqual(try inbox.receive(second).displayName, "second.c84backup")
    }

    func testReceivingRejectsLinksFoldersAndFakeFiles() throws {
        let inbox = BackupInbox(root: directory.appendingPathComponent("inbox"))
        for string in ["https://example.com/Library.c84backup", "arithvale://restore", "file://remote-host/backup"] {
            XCTAssertThrowsError(try inbox.receive(XCTUnwrap(URL(string: string))))
        }
        XCTAssertThrowsError(try inbox.receive(directory))
        let source = try fixture(), link = directory.appendingPathComponent("link.c84backup")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        XCTAssertThrowsError(try inbox.receive(link))
        let fake = directory.appendingPathComponent("fake.c84backup")
        try Data("not a backup".utf8).write(to: fake)
        XCTAssertThrowsError(try inbox.receive(fake))
        XCTAssertNil(try inbox.load())
    }

    func testHeaderRecognitionDoesNotClaimAuthentication() throws {
        let source = try fixture(), inbox = BackupInbox(root: directory.appendingPathComponent("inbox"))
        var bytes = try Data(contentsOf: source)
        bytes[bytes.count - 1] ^= 1
        try bytes.write(to: source)
        // Receipt verifies the copy, not the key or cryptographic authenticity.
        let entry = try inbox.receive(source)
        let restored = VaultRepository(root: directory.appendingPathComponent("restore"))
        XCTAssertThrowsError(try restored.restore(from: entry.url, password: "original recovery secret"))
        XCTAssertFalse(restored.exists)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testInterruptedCopyIsNeverPublishedAndRestartRemovesOnlyItsStaging() async throws {
        let source = try fixture(), root = directory.appendingPathComponent("inbox")
        let inbox = BackupInbox(root: root)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try inbox.receive(source)
        }
        do { _ = try await task.value; XCTFail("Cancelled receipt must fail") }
        catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
        XCTAssertNil(try inbox.load())
        let pending = root.appendingPathComponent("pending-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: pending, withIntermediateDirectories: true)
        try Data("incomplete".utf8).write(to: pending.appendingPathComponent("archive.c84backup"))
        let unrelated = root.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: unrelated)
        XCTAssertNil(try inbox.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: pending.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testInboxPathAndMetadataCannotRedirectToAnotherFile() throws {
        let source = try fixture(), root = directory.appendingPathComponent("inbox")
        let inbox = BackupInbox(root: root)
        let entry = try inbox.receive(source)
        let metadata = entry.url.deletingLastPathComponent().appendingPathComponent("name.json")
        try FileManager.default.removeItem(at: metadata)
        try FileManager.default.createSymbolicLink(at: metadata, withDestinationURL: source)
        XCTAssertThrowsError(try inbox.load())
        try inbox.discard()
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        let linkedRoot = directory.appendingPathComponent("linked")
        try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: root)
        XCTAssertThrowsError(try BackupInbox(root: linkedRoot).load())
    }
}
