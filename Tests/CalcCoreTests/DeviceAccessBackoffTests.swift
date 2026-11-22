import XCTest
@testable import CalcCore

final class DeviceAccessBackoffTests: XCTestCase {
    func testThresholdAndCappedProgression() {
        for failures in [-1, 0, 1, 4] { XCTAssertNil(DeviceAccessBackoff.delay(failures: failures)) }
        XCTAssertEqual(DeviceAccessBackoff.delay(failures: 5), 30)
        XCTAssertEqual(DeviceAccessBackoff.delay(failures: 6), 60)
        XCTAssertEqual(DeviceAccessBackoff.delay(failures: 7), 120)
        XCTAssertEqual(DeviceAccessBackoff.delay(failures: 8), 240)
        XCTAssertEqual(DeviceAccessBackoff.delay(failures: 9), 300)
        XCTAssertEqual(DeviceAccessBackoff.delay(failures: 20), 300)
        XCTAssertEqual(DeviceAccessBackoff.delay(failures: Int.max), 300)
    }
}
