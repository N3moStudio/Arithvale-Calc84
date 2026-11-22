import XCTest
@testable import CalcCore

final class InboxReliabilityTests: XCTestCase {
    private func fixture(_ body: (URL, SharedFileInbox, Data) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root, SharedFileInbox(root: root.appendingPathComponent("inbox")), SharedFileInbox.newKey())
    }
    func testOneDamagedReceiptDoesNotHideReadableCopies() throws {
        try fixture { root, inbox, key in
            let source = root.appendingPathComponent("photo.jpg")
            let original = Data("original bytes".utf8); try original.write(to: source)
            let first = try inbox.receive(source, key: key)
            let damaged = try inbox.receive(source, key: key)
            let third = try inbox.receive(source, key: key)
            try Data("corrupt".utf8).write(to: inbox.root.appendingPathComponent(damaged.id.uuidString).appendingPathComponent("metadata"))
            let scan = try inbox.scan(key: key)
            XCTAssertEqual(Set(scan.entries.map(\.id)), [first.id, third.id])
            XCTAssertEqual(scan.unreadableIDs, [damaged.id])
            XCTAssertThrowsError(try inbox.entries(key: key))
            let output = root.appendingPathComponent("restored.jpg")
            try inbox.materialize(first, key: key, to: output)
            XCTAssertEqual(try Data(contentsOf: output), original)
            try inbox.discard(damaged.id)
            XCTAssertEqual(try inbox.scan(key: key).unreadableIDs, [])
            XCTAssertEqual(try Data(contentsOf: source), original)
        }
    }
    func testLostKeyCopiesCanBeExplicitlyDiscardedWithoutDecrypting() throws {
        try fixture { root, inbox, key in
            let source = root.appendingPathComponent("note.txt")
            try Data("keep original".utf8).write(to: source)
            let receipt = try inbox.receive(source, key: key)
            let wrongKeyScan = try inbox.scan(key: SharedFileInbox.newKey())
            XCTAssertTrue(wrongKeyScan.entries.isEmpty)
            XCTAssertEqual(wrongKeyScan.unreadableIDs, [receipt.id])
            let ids = try inbox.receivedIDs()
            XCTAssertEqual(ids, [receipt.id])
            for id in ids { try inbox.discard(id) }
            XCTAssertTrue(try inbox.receivedIDs().isEmpty)
            XCTAssertEqual(try Data(contentsOf: source), Data("keep original".utf8))
            let replacement = try inbox.receive(source, key: SharedFileInbox.newKey())
            XCTAssertNotEqual(replacement.id, receipt.id)
        }
    }
    func testMissingContentsAndLinkedReceiptAreIsolated() throws {
        try fixture { root, inbox, key in
            let source = root.appendingPathComponent("note.txt"); try Data("safe".utf8).write(to: source)
            let receipt = try inbox.receive(source, key: key)
            try FileManager.default.removeItem(at: inbox.root.appendingPathComponent(receipt.id.uuidString).appendingPathComponent("contents"))
            let outside = root.appendingPathComponent("outside")
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
            let sentinel = outside.appendingPathComponent("keep"); try Data("keep".utf8).write(to: sentinel)
            let linkedID = UUID()
            try FileManager.default.createSymbolicLink(at: inbox.root.appendingPathComponent(linkedID.uuidString), withDestinationURL: outside)
            XCTAssertEqual(Set(try inbox.scan(key: key).unreadableIDs), [receipt.id, linkedID])
            try inbox.discard(linkedID)
            XCTAssertTrue(FileManager.default.fileExists(atPath: sentinel.path))
        }
    }
    func testDownloadLengthRejectsTruncationOversizeAndInvalidSizes() throws {
        XCTAssertNoThrow(try DownloadLength.validate(actual: 0, expected: 0, maximum: 100))
        XCTAssertNoThrow(try DownloadLength.validate(actual: 100, expected: 100, maximum: 100))
        for (actual, expected, maximum) in [(99, 100, 100), (101, 100, 100), (101, 101, 100), (0, -1, 100), (-1, 0, 100), (0, 0, -1)] {
            XCTAssertThrowsError(try DownloadLength.validate(actual: actual, expected: expected, maximum: maximum))
        }
    }
}
