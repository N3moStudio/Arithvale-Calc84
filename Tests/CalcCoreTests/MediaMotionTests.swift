import XCTest
@testable import CalcCore

final class MediaMotionTests: XCTestCase {
    func testCancelledSwipeKeepsVisiblePageAndPlaybackTarget() {
        var state = MediaPagingState(count: 5, initial: 2)
        let ticket = state.revision
        state.settled(at: 2, startedAt: ticket)
        XCTAssertEqual(state.visible, 2)
        XCTAssertEqual(state.requested, 2)
    }
    func testCompletedSwipeUpdatesBothPositions() {
        var state = MediaPagingState(count: 5, initial: 2)
        state.settled(at: 3, startedAt: state.revision)
        XCTAssertEqual(state.visible, 3)
        XCTAssertEqual(state.requested, 3)
    }
    func testRapidButtonRequestsDoNotCommitBeforeAnimation() {
        var state = MediaPagingState(count: 7, initial: 0)
        state.request(1)
        let ticket = state.revision
        state.request(2); state.request(3)
        XCTAssertEqual(state.visible, 0)
        state.settled(at: 1, startedAt: ticket)
        XCTAssertEqual(state.visible, 1)
        XCTAssertEqual(state.requested, 3)
        state.settled(at: 3, startedAt: state.revision)
        XCTAssertEqual(state.visible, 3)
    }
    func testReversalDuringSwipeSurvivesCancelledGesture() {
        var state = MediaPagingState(count: 5, initial: 2)
        let ticket = state.revision
        state.request(1)
        state.settled(at: 2, startedAt: ticket)
        XCTAssertEqual(state.requested, 1)
        state.settled(at: 1, startedAt: state.revision)
        XCTAssertEqual(state.visible, 1)
    }
    func testUncompletedButtonTransitionReconcilesToActualPage() {
        var state = MediaPagingState(count: 5, initial: 2)
        state.request(3)
        state.settled(at: 2, startedAt: state.revision)
        XCTAssertEqual(state.visible, 2)
        XCTAssertEqual(state.requested, 2)
    }
    func testInvalidPageAndBoundaryRequestsAreSafe() {
        var empty = MediaPagingState(count: 0, initial: 9)
        empty.request(4); empty.settled(at: 1, startedAt: 0)
        XCTAssertEqual(empty.visible, 0)
        var state = MediaPagingState(count: 3, initial: -9)
        state.request(99)
        XCTAssertEqual(state.requested, 2)
        state.settled(at: 9, startedAt: state.revision)
        XCTAssertEqual(state.visible, 0)
    }
    func testLayoutChangePreservesPartiallyVisiblePhotoOffset() {
        XCTAssertEqual(LibraryViewportAnchor.offset(itemTop: 900, relativeTop: -28, minimum: 0, maximum: 1600), 928)
        XCTAssertEqual(LibraryViewportAnchor.offset(itemTop: 900, relativeTop: 28, minimum: 0, maximum: 1600), 872)
    }
    func testScrollAnchorClampsForShorterLayoutsAndInvalidGeometry() {
        XCTAssertEqual(LibraryViewportAnchor.offset(itemTop: 900, relativeTop: -28, minimum: -10, maximum: 500), 500)
        XCTAssertEqual(LibraryViewportAnchor.offset(itemTop: 0, relativeTop: 80, minimum: -10, maximum: -20), -10)
        XCTAssertEqual(LibraryViewportAnchor.offset(itemTop: .nan, relativeTop: 0, minimum: 0, maximum: 500), 0)
    }
}
