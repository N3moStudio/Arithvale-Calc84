import XCTest
@testable import CalcCore

final class BackupFileProbeTests: XCTestCase {
    func testExportCanBeSelectedByContentAndRestoredAfterRename() throws {
        let fm = FileManager.default, root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let original = VaultRepository(root: root.appendingPathComponent("original"))
        let secret = "a separate recovery password"
        try original.create(password: secret)
        let item = try original.add(data: Data("sample".utf8), name: "sample", contentType: "public.data")
        let backup = root.appendingPathComponent("provider-renamed.bin")
        try original.exportBackup(to: backup)
        try BackupFileProbe.validate(backup)
        let staged = root.appendingPathComponent("staged.c84backup")
        try BackupCopy.copy(backup, to: staged)
        let restored = VaultRepository(root: root.appendingPathComponent("restored"))
        XCTAssertThrowsError(try restored.restore(from: staged, password: "wrong recovery password"))
        XCTAssertFalse(restored.exists)
        try restored.restore(from: staged, password: secret)
        XCTAssertEqual(try restored.contents(of: item.id), Data("sample".utf8))
        XCTAssertEqual(try original.contents(of: item.id), Data("sample".utf8))
        XCTAssertThrowsError(try BackupFileProbe.validate(root))
        let fake = root.appendingPathComponent("fake.c84backup")
        try Data("not a backup".utf8).write(to: fake)
        XCTAssertThrowsError(try BackupFileProbe.validate(fake))
        try Data("C84".utf8).write(to: fake)
        XCTAssertThrowsError(try BackupFileProbe.validate(fake))
    }
}
