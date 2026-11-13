import XCTest
@testable import CalcCore

final class VaultResetTests: XCTestCase {
    func testConfirmedEraseAllowsFreshIdentityAndPreservesExternalBackup() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let vault = VaultRepository(root: parent.appendingPathComponent("library"))
        let oldKey = VaultCode.generateRecovery()
        try vault.create(password: oldKey)
        let oldCredential = try vault.credential()
        let item = try vault.add(data: Data("private photo".utf8), name: "photo.txt", contentType: "public.plain-text")
        let backup = parent.appendingPathComponent("saved.c84backup")
        try vault.exportBackup(to: backup)
        let saved = try Data(contentsOf: backup)
        vault.lock()
        try vault.erase(expectedID: oldCredential.id)
        XCTAssertFalse(vault.exists)
        XCTAssertFalse(vault.isUnlocked)
        XCTAssertEqual(try Data(contentsOf: backup), saved)
        try vault.create(password: VaultCode.generateRecovery())
        XCTAssertNotEqual(try vault.identifier(), oldCredential.id)
        XCTAssertTrue(vault.items.isEmpty)
        XCTAssertThrowsError(try vault.unlock(credential: oldCredential))
        XCTAssertThrowsError(try vault.unlock(password: oldKey))
        let restored = VaultRepository(root: parent.appendingPathComponent("restored"))
        try restored.restore(from: backup, password: oldKey)
        XCTAssertEqual(try restored.contents(of: item.id), Data("private photo".utf8))
    }

    func testStaleEraseRequestCannotDeleteLibrary() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = VaultRepository(root: root)
        try vault.create(password: VaultCode.generateRecovery())
        let id = try vault.identifier()
        XCTAssertThrowsError(try vault.erase(expectedID: UUID()))
        XCTAssertTrue(vault.exists)
        XCTAssertEqual(try vault.identifier(), id)
        XCTAssertTrue(vault.isUnlocked)
        XCTAssertFalse(VaultCode.valid("160"))
        XCTAssertFalse(VaultCode.valid("160160"))
    }
}
