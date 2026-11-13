import XCTest
@testable import CalcCore

final class SettingsNavigationTests: XCTestCase {
    func testAlbumRouteSurvivesTabChangesAndReselectPopsIt() {
        var navigation = LibraryTabNavigation()
        navigation.openAlbum("Recently Deleted")
        XCTAssertEqual(navigation.selected, .albums)
        navigation.select(.library)
        XCTAssertEqual(navigation.albumPath, ["Recently Deleted"])
        navigation.select(.albums)
        XCTAssertEqual(navigation.albumPath, ["Recently Deleted"])
        navigation.select(.albums)
        XCTAssertTrue(navigation.albumPath.isEmpty)
    }

    func testDefaultPreferencesPreserveOptOuts() throws {
        let name = "Arithen-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertTrue(AppPreferences.reminders(in: defaults))
        XCTAssertTrue(AppPreferences.cellular(in: defaults))
        defaults.set(false, forKey: AppPreferences.remindersKey)
        defaults.set(false, forKey: AppPreferences.cellularKey)
        AppPreferences.register(in: defaults)
        XCTAssertFalse(AppPreferences.reminders(in: defaults))
        XCTAssertFalse(AppPreferences.cellular(in: defaults))
    }
}
