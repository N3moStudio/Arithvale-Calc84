import XCTest
@testable import CalcCore

final class SelectionSweepTests: XCTestCase {
    func testAddingRangeReversesWithoutLosingExistingSelection() throws {
        let ids = (0..<9).map { _ in UUID() }
        let initial: Set<UUID> = [ids[0], ids[4], ids[8]]
        let sweep = try XCTUnwrap(LibrarySelectionSweep(items: ids, anchor: 2, selection: initial))
        XCTAssertEqual(sweep.selection(through: 6), initial.union(ids[2...6]))
        XCTAssertEqual(sweep.selection(through: 3), Set([ids[0], ids[2], ids[3], ids[4], ids[8]]))
        XCTAssertEqual(sweep.selection(through: 1), initial.union(ids[1...2]))
        XCTAssertEqual(sweep.selection(through: 2), initial.union([ids[2]]))
    }
    func testStartingOnSelectedItemRemovesRangeAndRestoresOnReverse() throws {
        let ids = (0..<7).map { _ in UUID() }
        let initial: Set<UUID> = [ids[0], ids[2], ids[3], ids[5], ids[6]]
        let sweep = try XCTUnwrap(LibrarySelectionSweep(items: ids, anchor: 5, selection: initial))
        XCTAssertEqual(sweep.selection(through: 1), Set([ids[0], ids[6]]))
        XCTAssertEqual(sweep.selection(through: 4), Set([ids[0], ids[2], ids[3], ids[6]]))
        XCTAssertEqual(sweep.selection(through: 6), Set([ids[0], ids[2], ids[3]]))
        XCTAssertEqual(sweep.selection(through: 5), initial.subtracting([ids[5]]))
    }
    func testUsesDisplayedOrderAcrossSectionsAndIgnoresInvalidEndpoints() throws {
        let firstMonth = [UUID(), UUID()], secondMonth = [UUID(), UUID(), UUID()]
        let hidden = UUID()
        let displayed = firstMonth + secondMonth
        let sweep = try XCTUnwrap(LibrarySelectionSweep(items: displayed, anchor: 1, selection: [hidden]))
        XCTAssertEqual(sweep.selection(through: 4), Set([hidden] + Array(displayed[1...4])))
        XCTAssertEqual(sweep.selection(through: 0), Set([hidden] + firstMonth))
        XCTAssertNil(sweep.selection(through: -1)); XCTAssertNil(sweep.selection(through: 5))
        XCTAssertNil(LibrarySelectionSweep(items: [], anchor: 0, selection: []))
        XCTAssertNil(LibrarySelectionSweep(items: displayed, anchor: 5, selection: []))
    }
    func testEdgeScrollingStopsInMiddleAndRemainsBounded() {
        XCTAssertEqual(LibrarySelectionSweep.scrollSpeed(location: 300, viewport: 600), 0)
        XCTAssertEqual(LibrarySelectionSweep.scrollSpeed(location: 64, viewport: 600), 0)
        XCTAssertEqual(LibrarySelectionSweep.scrollSpeed(location: 536, viewport: 600), 0)
        XCTAssertEqual(LibrarySelectionSweep.scrollSpeed(location: 32, viewport: 600), -300)
        XCTAssertEqual(LibrarySelectionSweep.scrollSpeed(location: 568, viewport: 600), 300)
        XCTAssertEqual(LibrarySelectionSweep.scrollSpeed(location: -100, viewport: 600), -600)
        XCTAssertEqual(LibrarySelectionSweep.scrollSpeed(location: 900, viewport: 600), 600)
        XCTAssertEqual(LibrarySelectionSweep.scrollSpeed(location: 50, viewport: 100), 0)
        XCTAssertEqual(LibrarySelectionSweep.scrollSpeed(location: .nan, viewport: 600), 0)
        XCTAssertEqual(LibrarySelectionSweep.scrollSpeed(location: 0, viewport: 0), 0)
    }
}
