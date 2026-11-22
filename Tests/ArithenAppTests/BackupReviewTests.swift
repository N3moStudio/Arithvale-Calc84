import XCTest
import CryptoKit
import CalcCore
@testable import Arithen

/// Exercises the production review model with real encryption and disposable
/// archives. No authentication bypass or fixture path is installed in the app.
@MainActor
final class BackupReviewTests: XCTestCase {
    private var root: URL!
    private let secret = "disposable review recovery password"
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    private func archive(damaged: Bool) throws -> URL {
        let source = VaultRepository(root: root.appendingPathComponent(UUID().uuidString))
        try source.create(password: secret)
        _ = try source.add(data: Data("intact original".utf8), name: "intact.txt", contentType: "public.plain-text")
        let bad = try source.add(data: Data("second original".utf8), name: "second.txt", contentType: "public.plain-text")
        let url = root.appendingPathComponent(UUID().uuidString + ".arithenbackup")
        try source.exportBackup(to: url)
        if damaged {
            let key = SymmetricKey(data: try source.credential().key)
            let opened = try ArithenBackupArchive.read(url) { _ in key }
            let index = try XCTUnwrap(opened.records.firstIndex { $0.id == bad.id })
            let offset = Int(opened.bodyStart) + opened.records.prefix(index).reduce(0) { $0 + $1.bytes }
            var bytes = try Data(contentsOf: url)
            bytes[offset + opened.records[index].bytes / 2] ^= 1
            try bytes.write(to: url)
        }
        return url
    }
    private func settle(_ review: BackupReviewModel) async throws {
        for _ in 0..<1200 {
            if !review.working { return }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail("Review operation did not finish")
        throw NSError(domain: "BackupReviewTests", code: 1)
    }
    private func clear(_ review: BackupReviewModel) async throws {
        review.clear(); try await settle(review)
        XCTAssertFalse(review.readyToImport)
        XCTAssertNil(review.credential)
        XCTAssertNil(review.recoveryReport)
        XCTAssertTrue(review.items.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: review.root.path))
    }
    func testNormalVerifiedRestoreBecomesReady() async throws {
        let url = try archive(damaged: false), original = try Data(contentsOf: url)
        let review = BackupReviewModel(); defer { review.clear() }
        review.prepare(BackupSelection(url), key: secret)
        try await settle(review)
        XCTAssertNil(review.error)
        XCTAssertTrue(review.readyToImport)
        XCTAssertNotNil(review.credential)
        XCTAssertEqual(review.items.count, 2)
        XCTAssertNil(review.recoveryReport)
        XCTAssertFalse(review.partialRecovery)
        XCTAssertEqual(try Data(contentsOf: url), original)
        try await clear(review)
    }
    func testDamagedRestoreRequiresExplicitRecoveryAndConfirmation() async throws {
        let url = try archive(damaged: true), original = try Data(contentsOf: url)
        let review = BackupReviewModel(); defer { review.clear() }
        review.prepare(BackupSelection(url), key: secret)
        try await settle(review)
        XCTAssertNotNil(review.error)
        XCTAssertTrue(review.canRecover)
        XCTAssertFalse(review.readyToImport)
        XCTAssertNil(review.credential)
        review.prepare(BackupSelection(url), key: secret, recoverIntact: true)
        try await settle(review)
        let report = try XCTUnwrap(review.recoveryReport)
        XCTAssertEqual(report.skippedItemCount, 1)
        XCTAssertEqual(report.damagedResourceCount, 1)
        XCTAssertEqual(review.items.map(\.name), ["intact.txt"])
        XCTAssertFalse(review.readyToImport, "Scanning alone must never authorize partial import")
        XCTAssertNil(review.credential)
        XCTAssertTrue(review.partialRecovery)
        review.confirmRecovery()
        XCTAssertTrue(review.readyToImport)
        XCTAssertNotNil(review.credential)
        XCTAssertNil(review.recoveryReport)
        XCTAssertEqual(try Data(contentsOf: url), original)
        try await clear(review)
    }
    func testCancelStagedRecoveryClearsOnlyReviewAndCannotConfirmLater() async throws {
        let url = try archive(damaged: true), original = try Data(contentsOf: url)
        let review = BackupReviewModel(); defer { review.clear() }
        review.prepare(BackupSelection(url), key: secret, recoverIntact: true)
        try await settle(review)
        XCTAssertNotNil(review.recoveryReport)
        try await clear(review)
        review.confirmRecovery()
        XCTAssertFalse(review.readyToImport)
        XCTAssertNil(review.credential)
        XCTAssertEqual(try Data(contentsOf: url), original)
        // Cancellation is retryable; it must not invalidate the original archive.
        review.prepare(BackupSelection(url), key: secret, recoverIntact: true)
        try await settle(review)
        XCTAssertNotNil(review.recoveryReport)
        XCTAssertFalse(review.readyToImport)
        try await clear(review)
    }
    func testWrongKeyAndImmediateCancellationNeverAuthorizeRecovery() async throws {
        let url = try archive(damaged: true), original = try Data(contentsOf: url)
        let review = BackupReviewModel(); defer { review.clear() }
        review.prepare(BackupSelection(url), key: "incorrect recovery password", recoverIntact: true)
        try await settle(review)
        XCTAssertNotNil(review.error)
        XCTAssertNil(review.recoveryReport)
        review.confirmRecovery()
        XCTAssertNil(review.credential)
        XCTAssertFalse(review.readyToImport)
        review.prepare(BackupSelection(url), key: secret, recoverIntact: true)
        // Invalidate before the asynchronous restore can publish a credential.
        try await clear(review)
        XCTAssertFalse(review.readyToImport)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
}
