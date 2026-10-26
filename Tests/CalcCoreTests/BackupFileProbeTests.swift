import XCTest
@testable import CalcCore

final class BackupFileProbeTests: XCTestCase {
    func testFolderBrowsingKeepsRenamedFilesAndSkipsDirectoriesLinksAndHiddenFiles() throws {
        let fm = FileManager.default, root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        for name in ["renamed.bin", "Library.c84backup", ".hidden.c84backup", "music.mp3"] {
            try Data("sample".utf8).write(to: root.appendingPathComponent(name))
        }
        try fm.createDirectory(at: root.appendingPathComponent("child"), withIntermediateDirectories: false)
        try fm.createSymbolicLink(at: root.appendingPathComponent("linked.c84backup"), withDestinationURL: root.appendingPathComponent("Library.c84backup"))
        let files = try BackupFileProbe.files(in: root)
        XCTAssertEqual(files.first?.lastPathComponent, "Library.c84backup")
        XCTAssertEqual(Set(files.map(\.lastPathComponent)), ["Library.c84backup", "renamed.bin", "music.mp3"])
        XCTAssertThrowsError(try BackupFileProbe.files(in: files[0]))
        XCTAssertThrowsError(try BackupFileProbe.validate(files[0])) // Listing is not authentication.
    }

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
