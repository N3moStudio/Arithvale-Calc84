import XCTest
@testable import CalcCore

final class VaultTests: XCTestCase {
    private var temporary: URL!
    private let password = "violet lantern river paper"
    override func setUpWithError() throws {
        temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: temporary) }
    private func repository(_ name: String = "library") -> VaultRepository {
        VaultRepository(root: temporary.appendingPathComponent(name))
    }
    func testPBKDF2MatchesIndependentSHA256KnownAnswer() throws {
        // Independently generated with Python/OpenSSL hashlib.pbkdf2_hmac, using production rounds.
        let key = try VaultCrypto.derive(password: "password", salt: Data("salt".utf8), rounds: 600_000)
        let hex = key.withUnsafeBytes { $0.map { String(format: "%02x", $0) }.joined() }
        XCTAssertEqual(hex, "669cfe52482116fda1aa2cbe409b2f56c8e4563752b7a28f6eaab614ee005178")
    }
    func testEncryptionLockAndReopen() throws {
        let repo = repository()
        try repo.create(password: password)
        let bytes = Data("private contents not plaintext".utf8)
        let item = try repo.add(data: bytes, name: "confidential-name.txt", contentType: "public.plain-text")
        for url in try FileManager.default.contentsOfDirectory(at: repo.root, includingPropertiesForKeys: nil) {
            let raw = try Data(contentsOf: url)
            XCTAssertNil(raw.range(of: bytes))
            XCTAssertNil(raw.range(of: Data(item.name.utf8)))
        }
        repo.lock()
        XCTAssertTrue(repo.items.isEmpty)
        XCTAssertThrowsError(try repo.contents(of: item.id))
        XCTAssertThrowsError(try repo.unlock(password: "incorrect password"))
        XCTAssertFalse(repo.isUnlocked)
        try repo.unlock(password: password)
        XCTAssertEqual(try repo.contents(of: item.id), bytes)
    }
    func testBackupSurvivesRemovalOfSourceAndRestoresNamesAndBytes() throws {
        let original = repository()
        try original.create(password: password)
        let first = try original.add(data: Data([0, 1, 2, 255]), name: "photo.heic", contentType: "public.heic")
        let second = try original.add(data: Data("pdf sample".utf8), name: "scan.pdf", contentType: "com.adobe.pdf")
        let archive = temporary.appendingPathComponent("backup.c84backup")
        try original.exportBackup(to: archive)
        original.lock()
        try FileManager.default.removeItem(at: original.root)
        let restored = repository("restored")
        try restored.restore(from: archive, password: password)
        XCTAssertEqual(restored.items, [second, first])
        XCTAssertEqual(try restored.contents(of: first.id), Data([0, 1, 2, 255]))
        restored.lock()
        try restored.unlock(password: password)
        XCTAssertEqual(try restored.contents(of: second.id), Data("pdf sample".utf8))
    }
    func testTamperingTruncationWrongPasswordAndTrailingBytesCannotCommit() throws {
        let original = repository()
        try original.create(password: password)
        try original.add(data: Data("content".utf8), name: "sample", contentType: "public.data")
        let archive = temporary.appendingPathComponent("good.c84backup")
        try original.exportBackup(to: archive)
        let data = try Data(contentsOf: archive)
        let wrong = repository("wrong")
        XCTAssertThrowsError(try wrong.restore(from: archive, password: "wrong password"))
        XCTAssertFalse(wrong.exists)
        var flipped = data
        flipped[flipped.count - 1] ^= 1
        for (i, candidate) in [flipped, Data(data.dropLast(10)), data + Data([0]), Data("bad".utf8)].enumerated() {
            let badFile = temporary.appendingPathComponent("bad\(i)")
            try candidate.write(to: badFile)
            let restore = repository("restore\(i)")
            XCTAssertThrowsError(try restore.restore(from: badFile, password: password))
            XCTAssertFalse(restore.exists)
        }
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: temporary.path).contains { $0.hasPrefix("stage-") })
    }
    func testSwappedFilesFailAuthenticationAndBlockExport() throws {
        let repo = repository()
        try repo.create(password: password)
        let a = try repo.add(data: Data("aaa".utf8), name: "a", contentType: "public.data")
        let b = try repo.add(data: Data("bbb".utf8), name: "b", contentType: "public.data")
        let first = repo.root.appendingPathComponent(a.id.uuidString + ".enc")
        let second = repo.root.appendingPathComponent(b.id.uuidString + ".enc")
        try Data(contentsOf: first).write(to: second)
        XCTAssertThrowsError(try repo.contents(of: b.id))
        let output = temporary.appendingPathComponent("bad-export")
        XCTAssertThrowsError(try repo.exportBackup(to: output))
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    }
    func testRestoreCannotOverwriteExistingLibraryAndDeletePersists() throws {
        let repo = repository()
        try repo.create(password: password)
        let item = try repo.add(data: Data([7]), name: "keep", contentType: "public.data")
        let backup = temporary.appendingPathComponent("backup")
        try repo.exportBackup(to: backup)
        XCTAssertThrowsError(try repo.restore(from: backup, password: password))
        XCTAssertEqual(try repo.contents(of: item.id), Data([7]))
        try repo.remove(id: item.id)
        repo.lock()
        try repo.unlock(password: password)
        XCTAssertTrue(repo.items.isEmpty)
        XCTAssertThrowsError(try repo.contents(of: item.id))
    }
    func testShortPasswordsAndOversizedBackupHeaderFailWithoutCreatingLibrary() throws {
        let repo = repository()
        XCTAssertThrowsError(try repo.create(password: "123456"))
        XCTAssertFalse(repo.exists)
        let file = temporary.appendingPathComponent("oversized")
        try (Data("C84B0001".utf8) + Data(repeating: 255, count: 8)).write(to: file)
        XCTAssertThrowsError(try repo.restore(from: file, password: password))
        XCTAssertFalse(repo.exists)
    }
}
