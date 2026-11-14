import XCTest

final class ArithenUITests: XCTestCase {
    private let app = XCUIApplication()
    override func setUpWithError() throws { continueAfterFailure = false }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "Not reachable: \(element)")
    }
    private func tap(_ label: String) {
        let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Missing button: \(label)")
        reveal(button); button.tap()
    }
    private func enter(_ digits: String) {
        tap("Clear all")
        for digit in digits { tap(String(digit)) }
    }
    private func holdEquals() { app.buttons["Equals"].press(forDuration: 0.65) }
    private func back() { app.navigationBars.buttons.element(boundBy: 0).tap() }

    func testCalculatorSetupLibraryAndBackupJourneys() throws {
        app.launch()
        XCTAssertTrue(app.buttons["Equals"].waitForExistence(timeout: 15))
        tap("7"); tap("Add"); tap("6"); tap("Equals")
        let display = app.descendants(matching: .any).matching(identifier: "Calculator display").firstMatch
        XCTAssertEqual(display.value as? String, "13")
        capture("01-calculator")

        // Evaluating the starter entry must not turn a later hold into access.
        enter("160160"); tap("Equals"); holdEquals()
        XCTAssertFalse(app.staticTexts["A space of your own."].exists)
        XCTAssertFalse(app.staticTexts["Recover access."].exists)
        enter("160160"); holdEquals()
        XCTAssertTrue(app.staticTexts["A space of your own."].waitForExistence(timeout: 15))

        // Create only this disposable simulator's vault through ordinary setup.
        let key = app.staticTexts["setup.newRecoveryKey"]
        reveal(key)
        let tail = String(key.label.filter { $0.isHexDigit }.suffix(8))
        XCTAssertEqual(tail.count, 8)
        let saved = app.switches["setup.savedRecoveryKey"]
        reveal(saved); saved.tap()
        let confirm = app.textFields["setup.confirmRecoveryKey"]
        reveal(confirm); confirm.tap(); confirm.typeText(tail)
        for label in ["New calculator code", "Confirm calculator code"] {
            let field = app.secureTextFields[label]
            reveal(field); field.tap(); field.typeText("963852")
        }
        tap("Create Library")
        XCTAssertTrue(app.buttons["Add to Library"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.tabBars.count, 0, "The hidden native dock must not duplicate the custom dock")
        XCTAssertEqual(app.buttons.matching(identifier: "Library").count, 1)
        tap("Photos")
        XCTAssertTrue(app.staticTexts["No Photos"].waitForExistence(timeout: 5))
        tap("Show All Snaps")
        tap("Sort Snaps")
        XCTAssertTrue(app.buttons["Date Imported"].waitForExistence(timeout: 5))
        app.buttons["Date Imported"].tap()
        capture("02-library")

        tap("Albums")
        let deleted = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Recently Deleted")).firstMatch
        reveal(deleted); deleted.tap()
        XCTAssertTrue(app.staticTexts["Nothing Deleted"].waitForExistence(timeout: 5))
        tap("Library"); tap("Albums")
        XCTAssertTrue(app.staticTexts["Nothing Deleted"].exists)
        capture("03-recently-deleted")
        tap("Albums")
        XCTAssertFalse(app.staticTexts["Nothing Deleted"].exists)
        tap("Library"); tap("Settings")
        capture("04-settings")
        tap("Privacy & Access"); tap("Photo Indexing")
        XCTAssertTrue(app.switches["Photo Indexing"].waitForExistence(timeout: 5))
        back(); back()
        tap("Backups")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Create Backup")).firstMatch.exists)
        tap("Import Backup")
        XCTAssertTrue(app.buttons["Choose Backup File"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Import"].isEnabled)
        capture("05-backup-import")
        tap("Close")
        tap("Check a Backup")
        XCTAssertTrue(app.buttons["Choose Backup File"].waitForExistence(timeout: 5))
        capture("06-backup-check")
        back(); back(); tap("Done")
        tap("Add to Library"); tap("Import from Files")
        XCTAssertTrue(app.buttons["Choose Files"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Import"].isEnabled)
        capture("07-files-import"); tap("Close")
        tap("Lock & Return to Calculator")
        XCTAssertTrue(app.buttons["Equals"].waitForExistence(timeout: 10))
        enter("963852"); holdEquals()
        XCTAssertTrue(app.buttons["Add to Library"].waitForExistence(timeout: 15))
        app.terminate()

        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        enter("963852"); holdEquals()
        XCTAssertTrue(app.buttons["Add to Library"].waitForExistence(timeout: 15))
        capture("08-library-accessibility")
        tap("Settings")
        capture("09-settings-accessibility")
        let appearance = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Make it yours")).firstMatch
        reveal(appearance); appearance.tap()
        tap("Ion"); back()
        capture("10-settings-ion-accessibility")
        tap("Done"); tap("Lock & Return to Calculator")
        XCTAssertTrue(app.buttons["Equals"].waitForExistence(timeout: 10))
        capture("11-calculator-ion-accessibility")
    }
}
