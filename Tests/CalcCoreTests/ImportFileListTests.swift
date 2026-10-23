import XCTest
@testable import CalcCore

final class ImportFileListTests: XCTestCase {
    func testFolderExpansionIsBoundedDeduplicatedAndSkipsLinksAndHiddenFiles() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root.appendingPathComponent("nested"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let a = root.appendingPathComponent("a.txt"), b = root.appendingPathComponent("nested/b.txt")
        try Data([1]).write(to: a); try Data([2]).write(to: b)
        try Data([3]).write(to: root.appendingPathComponent(".hidden"))
        try fm.createSymbolicLink(at: root.appendingPathComponent("link"), withDestinationURL: a)
        XCTAssertEqual(Set(try ImportFileList.expand([root, a])), [a, b])
        XCTAssertThrowsError(try ImportFileList.expand([root], limit: 1))
        XCTAssertTrue(try ImportFileList.expand([root.appendingPathComponent("link")]).isEmpty)
    }
    func testCalculatorClearEntryKeepsPreviousOperation() throws {
        XCTAssertEqual(Calculator.clearEntry("18+45"), "18+")
        XCTAssertEqual(Calculator.clearEntry("48÷8"), "48÷")
        XCTAssertEqual(Calculator.clearEntry("160160"), "")
        XCTAssertEqual(try Calculator.evaluate(Calculator.clearEntry("18+45") + "2"), 20)
    }
}
