import XCTest
@testable import CalcCore

final class LibraryEfficiencyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testOptionalWorkRequiresActiveNormalPowerAndTemperature() {
        for active in [false, true] {
            for lowPower in [false, true] {
                for hot in [false, true] {
                    let allowed = LibraryEfficiency.allowsOptionalWork(active: active, lowPower: lowPower, thermallyLimited: hot)
                    if active && !lowPower && !hot { XCTAssertTrue(allowed) }
                    else { XCTAssertFalse(allowed) }
                }
            }
        }
    }

    private func reminder(enabled: Bool = true, unlocked: Bool = true, hasItems: Bool = true,
                          changed: Bool = true, lastBackup: Date? = nil, snooze: Date? = nil) -> Bool {
        LibraryEfficiency.needsReminder(enabled: enabled, unlocked: unlocked, hasItems: hasItems,
            changed: changed, now: now, lastBackup: lastBackup, snoozedUntil: snooze)
    }

    func testUnbackedChangesCanRemindButOnlyInsideAnOptedInUnlockedLibrary() {
        XCTAssertTrue(reminder())
        XCTAssertFalse(reminder(enabled: false))
        XCTAssertFalse(reminder(unlocked: false))
        XCTAssertFalse(reminder(hasItems: false))
        XCTAssertFalse(reminder(changed: false))
    }

    func testWeeklyThresholdIncludesExactlySevenDays() {
        let week: TimeInterval = 7 * 24 * 60 * 60
        XCTAssertFalse(reminder(lastBackup: now.addingTimeInterval(-week + 1)))
        XCTAssertTrue(reminder(lastBackup: now.addingTimeInterval(-week)))
        XCTAssertTrue(reminder(lastBackup: now.addingTimeInterval(-week - 1)))
        XCTAssertFalse(reminder(changed: false, lastBackup: now.addingTimeInterval(-week * 2)))
    }

    func testSnoozeAppliesEvenWithoutAnyPreviousBackup() {
        XCTAssertFalse(reminder(snooze: now.addingTimeInterval(24 * 60 * 60)))
        XCTAssertFalse(reminder(lastBackup: now.addingTimeInterval(-14 * 24 * 60 * 60), snooze: now.addingTimeInterval(1)))
        XCTAssertTrue(reminder(snooze: now))
        XCTAssertTrue(reminder(snooze: now.addingTimeInterval(-1)))
    }

    func testRecentOrFutureBackupTimestampDoesNotNagAfterClockAdjustment() {
        XCTAssertFalse(reminder(lastBackup: now))
        XCTAssertFalse(reminder(lastBackup: now.addingTimeInterval(60 * 60)))
    }
}
