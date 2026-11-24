import XCTest
import UIKit
import CalcCore
@testable import Arithen

/// Real iOS coordination, staging, and encryption; only disposable test files.
@MainActor
final class BackupPresentationTests: XCTestCase {
    private var root: URL!
    private let secret = "disposable simulator recovery password"
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    private func archive() throws -> URL {
        let source = VaultRepository(root: root.appendingPathComponent("source-" + UUID().uuidString))
        try source.create(password: secret)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).pngData { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        _ = try source.add(data: image, name: "sample.png", contentType: "public.png")
        _ = try source.add(data: Data("Original document bytes".utf8), name: "sample.txt", contentType: "public.plain-text")
        let url = root.appendingPathComponent(UUID().uuidString + ".c84backup")
        try source.exportBackup(to: url)
        return url
    }
    private func settle(_ input: BackupInputModel) async throws {
        for _ in 0..<400 {
            if !input.working { return }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail("Backup staging did not finish")
    }
    func testPickerSelectionStagesAndRestoresExactContents() async throws {
        let original = try archive(), bytes = try Data(contentsOf: original)
        let input = BackupInputModel()
        input.choose(.file)
        let request = try XCTUnwrap(input.request)
        input.picked(.success([original]), for: request)
        try await settle(input)
        let selected = try XCTUnwrap(input.backup)
        XCTAssertNotEqual(selected.url, original)
        XCTAssertEqual(try Data(contentsOf: selected.url), bytes)
        let restored = VaultRepository(root: root.appendingPathComponent("restored"))
        XCTAssertThrowsError(try restored.restore(from: selected.url, password: "wrong recovery password"))
        try restored.restore(from: selected.url, password: secret)
        XCTAssertEqual(restored.items.count, 2)
        let text = try XCTUnwrap(restored.items.first { $0.name == "sample.txt" })
        XCTAssertEqual(try restored.contents(of: text.id), Data("Original document bytes".utf8))
        XCTAssertEqual(try Data(contentsOf: original), bytes)
    }
    func testInvalidReplacementCannotImportPreviousSelection() async throws {
        let input = BackupInputModel()
        input.prepare(try archive()); try await settle(input)
        XCTAssertNotNil(input.backup)
        let invalid = root.appendingPathComponent("broken.c84backup")
        try Data("not a backup".utf8).write(to: invalid)
        input.prepare(invalid); try await settle(input)
        XCTAssertNil(input.backup)
        XCTAssertNotNil(input.error)
        XCTAssertEqual(try Data(contentsOf: invalid), Data("not a backup".utf8))
    }
    func testPickerCancellationAndStaleCallbackDoNotSelectAnything() throws {
        let input = BackupInputModel()
        input.choose(.file); let old = try XCTUnwrap(input.request)
        input.selectionCancelled()
        XCTAssertNil(input.backup); XCTAssertFalse(input.working)
        input.choose(.file); let current = try XCTUnwrap(input.request)
        input.picked(.success([root.appendingPathComponent("old.c84backup")]), for: old)
        XCTAssertEqual(input.request?.id, current.id)
        input.picked(.success([]), for: current)
        XCTAssertNil(input.backup)
    }
    func testFolderBrowseAndCancelledPreparationAreRetryable() async throws {
        let original = try archive()
        let input = BackupInputModel()
        input.choose(.folder); let request = try XCTUnwrap(input.request)
        input.picked(.success([root]), for: request); try await settle(input)
        XCTAssertTrue(input.entries.contains(original))
        input.prepare(original); input.cancelPreparation(); try await settle(input)
        XCTAssertNil(input.backup)
        input.prepare(original); try await settle(input)
        XCTAssertNotNil(input.backup)
    }
    func testDelegateCompletesOnlyOnceAndIgnoresTeardown() {
        var callbacks = 0
        let coordinator = BackupDocumentPicker.Coordinator({ _ in callbacks += 1 }, failure: nil)
        coordinator.finish(nil); coordinator.finish(root)
        XCTAssertEqual(callbacks, 1)
        let obsolete = BackupDocumentPicker.Coordinator({ _ in callbacks += 1 }, failure: nil)
        obsolete.invalidate(); obsolete.finish(root)
        XCTAssertEqual(callbacks, 1)
    }
    func testLockKeepsOperationOwnedUntilDrainThenAllowsNextOwner() {
        let vault = VaultModel(engine: VaultEngine(root: root.appendingPathComponent("gate")))
        let old = vault.beginOperation()
        vault.lock()
        XCTAssertTrue(vault.busy)
        XCTAssertFalse(vault.unlocked)
        vault.endOperation(old)
        XCTAssertFalse(vault.busy)
        let next = vault.beginOperation()
        vault.endOperation(old)
        XCTAssertTrue(vault.busy, "A stale callback cannot release new work")
        vault.endOperation(next)
        XCTAssertFalse(vault.busy)
    }
    func testActualBackupInterruptedByLockReleasesBusyAndRetainsLibrary() async throws {
        let engine = VaultEngine(root: root.appendingPathComponent("interrupted"))
        _ = try await engine.create(password: secret)
        _ = try await engine.add(data: Data("keep this".utf8), name: "original.txt", contentType: "public.plain-text")
        let vault = VaultModel(engine: engine)
        vault.unlocked = true
        let work = Task { await vault.backup() }
        for _ in 0..<100 {
            if vault.busy { break }
            await Task.yield()
        }
        XCTAssertTrue(vault.busy)
        vault.lock()
        await work.value
        XCTAssertFalse(vault.busy, "Lock must not strand the backup's operation owner")
        // Drain the queued lock before independently checking stored bytes.
        await engine.lock()
        let restored = try await engine.unlock(password: secret)
        XCTAssertEqual(restored.count, 1)
        let bytes = try await engine.contents(id: XCTUnwrap(restored.first).id)
        XCTAssertEqual(bytes, Data("keep this".utf8))
    }
    func testExportCompletionCleansOnlyItsOwnedFolderOnce() throws {
        let owned = root.appendingPathComponent("export"), other = root.appendingPathComponent("other")
        try FileManager.default.createDirectory(at: owned, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        var completions = 0
        let coordinator = ActivitySheet.Coordinator(folder: owned) { _ in completions += 1 }
        coordinator.finish(false); coordinator.finish(true)
        XCTAssertEqual(completions, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: owned.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: other.path))
    }
}
