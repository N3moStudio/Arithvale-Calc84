import XCTest
@testable import CalcCore

final class OperationAndReceiptTests: XCTestCase {
    func testCancelledOwnerMustDrainBeforeAnotherOperationCanBegin() throws {
        var gate = VaultOperationGate()
        let cancelled = try XCTUnwrap(gate.begin())
        // Changing a view/session generation does not remove the operation owner.
        XCTAssertNil(gate.begin())
        XCTAssertTrue(gate.end(cancelled))
        XCTAssertNotNil(gate.begin())
    }
    func testStaleAndDuplicateCompletionCannotReleaseNewOwner() throws {
        var gate = VaultOperationGate()
        let old = try XCTUnwrap(gate.begin())
        XCTAssertTrue(gate.end(old))
        let current = try XCTUnwrap(gate.begin())
        XCTAssertFalse(gate.end(old))
        XCTAssertEqual(gate.owner, current)
        XCTAssertTrue(gate.end(current))
        XCTAssertFalse(gate.end(current))
    }
    func testReceiptCannotApplyToUnknownOrFreshLibrary() throws {
        let oldLibrary = UUID()
        var receipt = CloudReceipt()
        receipt.vaultID = oldLibrary; receipt.saved = Date(); receipt.needsBackup = false
        let restored = try JSONDecoder().decode(CloudReceipt.self, from: JSONEncoder().encode(receipt))
        XCTAssertTrue(restored.matches(libraryID: oldLibrary))
        XCTAssertFalse(restored.matches(libraryID: UUID()))
        XCTAssertFalse(restored.matches(libraryID: nil))
        XCTAssertFalse(CloudReceipt().matches(libraryID: oldLibrary))
    }
}
