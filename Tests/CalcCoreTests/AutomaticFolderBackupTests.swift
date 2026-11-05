import XCTest
@testable import CalcCore

final class AutomaticFolderBackupTests: XCTestCase {
    private var root: URL!
    private var folder: URL!
    private var history: URL!
    private var source: URL!
    private var store: AutomaticFolderBackups!
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        folder = root.appendingPathComponent("destination")
        history = root.appendingPathComponent("private-history")
        source = root.appendingPathComponent("source.c84backup")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("verified encrypted archive fixture".utf8).write(to: source)
        store = AutomaticFolderBackups(folder: folder, historyDirectory: history, library: UUID())
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    private func populate(_ count: Int) throws -> [AutomaticFolderBackups.Saved] {
        try (0..<count).map { try store.save(source, at: start.addingTimeInterval(Double($0) * AutomaticFolderBackups.interval)) }
    }
    private func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }
    private func count() throws -> Int { try FileManager.default.contentsOfDirectory(atPath: folder.path).count }

    func testDailyLimitPersistsAndHandlesClockChanges() throws {
        XCTAssertEqual(try store.delay(at: start), 0)
        _ = try store.save(source, at: start)
        let reopened = AutomaticFolderBackups(folder: folder, historyDirectory: history, library: store.library)
        XCTAssertEqual(try reopened.delay(at: start.addingTimeInterval(3600)), 23 * 3600)
        XCTAssertEqual(try reopened.delay(at: start.addingTimeInterval(86400)), 0)
        XCTAssertEqual(try reopened.delay(at: start.addingTimeInterval(-86400)), 86400)
    }

    func testRetainsSevenAndPreservesLegacyManualAndOtherLibraryCopies() throws {
        let legacy = folder.appendingPathComponent("Library-older.c84backup")
        let manual = folder.appendingPathComponent("Manual.c84backup")
        try BackupCopy.copy(source, to: legacy); try BackupCopy.copy(source, to: manual)
        let other = AutomaticFolderBackups(folder: folder, historyDirectory: history, library: UUID())
        let otherCopy = try other.save(source)
        let saved = try populate(8)
        XCTAssertEqual(saved.last?.removed, 1)
        XCTAssertFalse(exists(saved[0].url))
        XCTAssertTrue(saved.dropFirst().allSatisfy { exists($0.url) })
        XCTAssertTrue(exists(legacy)); XCTAssertTrue(exists(manual)); XCTAssertTrue(exists(otherCopy.url))
        XCTAssertEqual(try count(), 10)
    }

    func testCorruptRetainedCopyPreventsEveryDeletion() throws {
        let saved = try populate(7)
        try Data("corrupted".utf8).write(to: saved[3].url)
        let result = try store.save(source)
        XCTAssertTrue(result.cleanupDeferred); XCTAssertEqual(result.removed, 0)
        XCTAssertTrue(saved.allSatisfy { exists($0.url) }); XCTAssertEqual(try count(), 8)
    }

    func testMissingRetainedCopyPreventsDeletionOfOlderGoodCopy() throws {
        let saved = try populate(7)
        try FileManager.default.removeItem(at: saved[4].url)
        let result = try store.save(source)
        XCTAssertTrue(result.cleanupDeferred); XCTAssertEqual(result.removed, 0)
        XCTAssertTrue(exists(saved[0].url))
    }

    func testChangedOldCandidateIsNeverDeleted() throws {
        let saved = try populate(7)
        let replacement = Data("user replaced this file".utf8)
        try replacement.write(to: saved[0].url)
        let result = try store.save(source)
        XCTAssertTrue(result.cleanupDeferred); XCTAssertEqual(result.removed, 0)
        XCTAssertEqual(try Data(contentsOf: saved[0].url), replacement)
    }

    func testFailedNewCopyDoesNotAdvanceScheduleOrCleanUp() throws {
        let saved = try populate(7)
        let before = try Data(contentsOf: store.journalURL)
        XCTAssertThrowsError(try store.save(source) { url, operation, action in
            if operation == .write { throw CocoaError(.fileWriteOutOfSpace) }
            try action(url)
        })
        XCTAssertEqual(try Data(contentsOf: store.journalURL), before)
        XCTAssertTrue(saved.allSatisfy { exists($0.url) }); XCTAssertEqual(try count(), 7)
    }

    func testUnreadableHistoryFailsClosed() throws {
        let saved = try populate(7)
        try Data("broken journal".utf8).write(to: store.journalURL)
        XCTAssertThrowsError(try store.save(source))
        XCTAssertThrowsError(try store.delay())
        XCTAssertTrue(saved.allSatisfy { exists($0.url) }); XCTAssertEqual(try count(), 7)
    }

    func testNewCopyMustMatchTheRecordedDigestBeforeCleanup() throws {
        let saved = try populate(7)
        let before = try Data(contentsOf: store.journalURL)
        XCTAssertThrowsError(try store.save(source) { url, operation, action in
            if operation == .write { try Data("unexpected change".utf8).write(to: self.source) }
            try action(url)
        })
        XCTAssertEqual(try Data(contentsOf: store.journalURL), before)
        XCTAssertTrue(saved.allSatisfy { exists($0.url) }); XCTAssertEqual(try count(), 7)
    }

    func testJournalWriteFailureCannotAuthorizeCleanup() throws {
        let saved = try populate(7)
        XCTAssertThrowsError(try store.save(source) { url, operation, action in
            try action(url)
            if operation == .write {
                // Make the private journal unwritable after the new copy is saved.
                try FileManager.default.removeItem(at: self.store.journalURL)
                try FileManager.default.createDirectory(at: self.store.journalURL, withIntermediateDirectories: false)
            }
        })
        XCTAssertTrue(saved.allSatisfy { exists($0.url) }); XCTAssertEqual(try count(), 8)
    }

    func testDuplicateReceiptCannotCountAsMultipleSafeCopies() throws {
        let saved = try populate(7)
        var journal = try JSONDecoder().decode(AutomaticFolderBackups.Journal.self, from: Data(contentsOf: store.journalURL))
        journal.receipts.append(journal.receipts[0])
        try JSONEncoder().encode(journal).write(to: store.journalURL)
        XCTAssertThrowsError(try store.save(source))
        XCTAssertTrue(saved.allSatisfy { exists($0.url) }); XCTAssertEqual(try count(), 7)
    }

    func testFileChangedBetweenPreflightAndDeleteIsKept() throws {
        let saved = try populate(7)
        let changed = Data("changed after preflight".utf8)
        let result = try store.save(source) { url, operation, action in
            if operation == .delete { try changed.write(to: url) }
            try action(url)
        }
        XCTAssertTrue(result.cleanupDeferred); XCTAssertEqual(result.removed, 0)
        XCTAssertEqual(try Data(contentsOf: saved[0].url), changed)
    }

    func testNewFolderAndLibraryHaveIndependentOwnershipAndSchedule() throws {
        let saved = try populate(7)
        let elsewhere = root.appendingPathComponent("elsewhere")
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        let moved = AutomaticFolderBackups(folder: elsewhere, historyDirectory: history, library: store.library)
        XCTAssertEqual(try moved.delay(), 0)
        _ = try moved.save(source)
        let otherLibrary = AutomaticFolderBackups(folder: folder, historyDirectory: history, library: UUID())
        try FileManager.default.copyItem(at: store.journalURL, to: otherLibrary.journalURL)
        XCTAssertThrowsError(try otherLibrary.save(source))
        XCTAssertTrue(saved.allSatisfy { exists($0.url) })
    }

    func testSymlinkCandidateCannotDeleteAnOutsideFile() throws {
        let saved = try populate(7)
        try FileManager.default.removeItem(at: saved[0].url)
        try FileManager.default.createSymbolicLink(at: saved[0].url, withDestinationURL: source)
        let result = try store.save(source)
        XCTAssertTrue(result.cleanupDeferred); XCTAssertEqual(result.removed, 0)
        XCTAssertTrue(exists(source)); XCTAssertTrue(exists(saved[0].url))
    }

    func testCancellationDuringVerificationKeepsAllOldCopies() async throws {
        let saved = try populate(7)
        let store = store!, source = source!
        let work = Task.detached {
            try store.save(source) { url, operation, action in
                if operation == .read { withUnsafeCurrentTask { $0?.cancel() } }
                try action(url)
            }
        }
        let result = try await work.value
        XCTAssertTrue(result.cleanupDeferred); XCTAssertEqual(result.removed, 0)
        XCTAssertTrue(saved.allSatisfy { exists($0.url) }); XCTAssertEqual(try count(), 8)
    }

    func testDeletionFailureKeepsReplacementAndRetriesNextSave() throws {
        let saved = try populate(7)
        let result = try store.save(source) { url, operation, action in
            if operation == .delete { throw CocoaError(.fileWriteNoPermission) }
            try action(url)
        }
        XCTAssertTrue(result.cleanupDeferred); XCTAssertTrue(exists(result.url))
        XCTAssertTrue(saved.allSatisfy { exists($0.url) })
        let retry = try store.save(source)
        XCTAssertFalse(retry.cleanupDeferred); XCTAssertEqual(retry.removed, 2)
        XCTAssertEqual(try count(), 7)
    }

    func testInterruptedJournalUpdateWithAlreadyMissingOldFileRecovers() throws {
        let saved = try populate(7)
        try FileManager.default.removeItem(at: saved[0].url)
        let result = try store.save(source)
        XCTAssertFalse(result.cleanupDeferred); XCTAssertEqual(try count(), 7)
        XCTAssertEqual(try store.delay(at: Date()), 86400, accuracy: 2)
    }

    func testRetainedEncryptedArchiveRestoresAfterRotation() throws {
        let repository = VaultRepository(root: root.appendingPathComponent("original"))
        let key = VaultCode.generateRecovery()
        try repository.create(password: key)
        let bytes = Data(repeating: 7, count: 1_048_600)
        let item = try repository.add(data: bytes, name: "video.mov", contentType: "public.movie")
        try FileManager.default.removeItem(at: source)
        try repository.exportBackup(to: source)
        let saved = try populate(9)
        for index in [2, 8] {
            let restored = VaultRepository(root: root.appendingPathComponent("restored-\(index)"))
            try restored.restore(from: saved[index].url, password: key)
            _ = try restored.unlock(password: key)
            XCTAssertEqual(try restored.contents(of: item.id), bytes)
        }
        XCTAssertEqual(try count(), 7)
    }
}
