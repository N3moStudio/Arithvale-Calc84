import XCTest
import UIKit

final class ArithenUITests: XCTestCase {
    let app = XCUIApplication()
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 { capture("failure-screen") }
    }

    func capture(_ name: String) {
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
    func tap(_ label: String) {
        let matches = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label))
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 10), "Missing button: \(label)")
        // Full-screen covers can leave the calculator in the AX tree. Interact
        // with the visible control, not a same-labelled button behind the cover.
        let candidates = matches.allElementsBoundByIndex
        let button = candidates.first(where: { $0.isHittable }) ?? candidates.last!
        reveal(button)
        XCTAssertTrue(button.isEnabled, "Disabled button: \(label)")
        button.tap()
    }
    func enter(_ digits: String) {
        tap("Clear all")
        for digit in digits { tap(String(digit)) }
    }
    func holdEquals() { app.buttons["Equals"].press(forDuration: 0.65) }
    private func selectSeededPhoto() throws {
        let picker = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow.photospicker")
        let photo = picker.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        let add = picker.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ OR label == %@", "Add", "Done")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 15), picker.debugDescription)
        XCTAssertTrue(add.waitForExistence(timeout: 10), picker.debugDescription)
        XCTAssertFalse(add.isEnabled, "Picker must begin with zero selected items")
        let iconURL = try XCTUnwrap(Bundle(for: ArithenUITests.self).url(forResource: "AppIcon", withExtension: "png"))
        let iconImage = try XCTUnwrap(UIImage(contentsOfFile: iconURL.path)?.cgImage)
        let icon = try XCTUnwrap(PickerScreenshot(iconImage, width: 72))
        let window = app.windows.firstMatch
        func screenshot() throws -> PickerScreenshot {
            let image = try XCTUnwrap(app.screenshot().image.cgImage)
            return try XCTUnwrap(PickerScreenshot(image))
        }
        var before = try screenshot()
        var matchedTile = before.thumbnail(matching: icon)
        let loadDeadline = Date().addingTimeInterval(6)
        while matchedTile == nil && Date() < loadDeadline {
            Thread.sleep(forTimeInterval: 0.2)
            before = try screenshot()
            matchedTile = before.thumbnail(matching: icon)
        }
        let tile = try XCTUnwrap(matchedTile, "Seeded AppIcon thumbnail missing from visible picker")
        let appFrame = app.frame, windowFrame = window.frame
        func tapImagePoint(_ point: CGPoint) {
            let x = appFrame.minX + point.x * appFrame.width / CGFloat(before.width)
            let y = appFrame.minY + point.y * appFrame.height / CGFloat(before.height)
            window.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: x - windowFrame.minX, dy: y - windowFrame.minY)).tap()
        }
        let photoFrame = photo.frame
        tapImagePoint(CGPoint(x: tile.midX, y: tile.midY))
        // A single tap from an empty picker must enable Add; never toggle the tile again.
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: add)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 10), .completed, picker.debugDescription)
        let button = add.frame
        let scale = tile.width / photoFrame.width
        XCTAssertTrue(scale.isFinite && scale > 0)
        let radius = min(button.width, button.height) * scale / 2
        let screenPoint = add.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).screenPoint
        let resolved = CGPoint(x: (screenPoint.x - appFrame.minX) / appFrame.width * CGFloat(before.width),
                               y: (screenPoint.y - appFrame.minY) / appFrame.height * CGFloat(before.height))
        let predicted = CGPoint(x: tile.midX + (button.midX - photoFrame.midX) * scale,
                                y: tile.midY + (button.midY - photoFrame.midY) * scale)
        var target: CGPoint?
        let tintDeadline = Date().addingTimeInterval(5)
        repeat {
            let after = try screenshot()
            target = [resolved, predicted].filter { $0.y < tile.minY }.compactMap {
                before.confirmation(after: after, near: $0, radius: radius)
            }.first ?? before.changedHeaderButton(after: after, above: tile, radius: radius)
            if target == nil { Thread.sleep(forTimeInterval: 0.2) }
        } while target == nil && Date() < tintDeadline
        tapImagePoint(try XCTUnwrap(target, "Enabled picker checkmark missing from the visible header"))
    }
    private func back() { app.navigationBars.buttons.element(boundBy: 0).tap() }
    private func checkFilesPickerAndCancel(_ title: String = "Choose Backup File") {
        tap(title)
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 15), "System Files picker must remain presented")
        capture("files-picker-presented")
        cancel.tap()
        XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 10))
    }

    func testCalculatorAcceptsOffCenterAndRapidKeypadTaps() {
        app.launch()
        let one = app.buttons["1"]
        XCTAssertTrue(one.waitForExistence(timeout: 15))
        let six = app.buttons["6"]
        let display = app.descendants(matching: .any).matching(identifier: "Calculator display").firstMatch
        // Use the regular key grid to target the AC half of the shared capsule,
        // even if its accessibility frame regresses to the size of the letters.
        let acCenter = app.buttons["Clear all"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let acEdge = acCenter.withOffset(CGVector(dx: one.frame.width * 0.33, dy: one.frame.height * 0.15))
        let digitEdge = CGVector(dx: 0.82, dy: 0.66)
        one.tap()
        XCTAssertEqual(display.value as? String, "1")
        acEdge.tap()
        XCTAssertEqual(display.value as? String, "0")
        one.coordinate(withNormalizedOffset: digitEdge).tap()
        six.coordinate(withNormalizedOffset: digitEdge).tap()
        XCTAssertEqual(display.value as? String, "16")
        six.coordinate(withNormalizedOffset: digitEdge).doubleTap()
        XCTAssertEqual(display.value as? String, "1666")
        app.buttons["Add"].tap()
        one.tap()
        app.buttons["Equals"].tap()
        XCTAssertEqual(display.value as? String, "1667")
        acEdge.tap()
        XCTAssertEqual(display.value as? String, "0")
    }

    func testCalculatorSetupLibraryAndBackupJourneys() throws {
        saveSamples()
        app.launch()
        XCTAssertTrue(app.buttons["Equals"].waitForExistence(timeout: 15))
        tap("7"); tap("Add"); tap("6"); tap("Equals")
        let display = app.descendants(matching: .any).matching(identifier: "Calculator display").firstMatch
        XCTAssertEqual(display.value as? String, "13")
        capture("01-calculator")

        enter("1"); tap("Divide"); tap("0"); tap("Equals")
        XCTAssertEqual(display.value as? String, "Result is undefined.")
        tap("Delete last character"); tap("2"); tap("Equals")
        XCTAssertEqual(display.value as? String, "0.5")
        enter("1"); tap("Add"); tap("Equals")
        XCTAssertEqual(display.value as? String, "Check the expression.")
        tap("2"); tap("Equals")
        XCTAssertEqual(display.value as? String, "3")
        enter("5"); tap("Add"); tap("3"); tap("Change sign"); tap("Equals")
        XCTAssertEqual(display.value as? String, "2")
        tap("Change sign"); tap("Equals")
        XCTAssertEqual(display.value as? String, "-2")

        // Evaluating the starter entry must not turn a later hold into access.
        enter("160159"); tap("Add"); tap("1"); tap("Equals")
        tap("Change sign"); tap("Change sign"); holdEquals()
        XCTAssertFalse(app.staticTexts["A space of your own."].exists)
        XCTAssertFalse(app.staticTexts["Recover access."].exists)
        // History results retain computed provenance even when edited down to
        // the exact starter code; fresh digits after a result remain allowed.
        enter("1601599"); tap("Add"); tap("1"); tap("Equals"); tap("History"); tap("1601599+1")
        tap("Delete last character"); holdEquals()
        XCTAssertFalse(app.staticTexts["A space of your own."].exists)
        XCTAssertFalse(app.staticTexts["Recover access."].exists)
        enter("160160"); tap("Equals"); holdEquals()
        XCTAssertFalse(app.staticTexts["A space of your own."].exists)
        XCTAssertFalse(app.staticTexts["Recover access."].exists)
        for digit in "160160" { tap(String(digit)) }
        holdEquals()
        XCTAssertTrue(app.staticTexts["A space of your own."].waitForExistence(timeout: 15))

        // Create only this disposable simulator's vault through ordinary setup.
        let key = app.staticTexts["setup.newRecoveryKey"]
        reveal(key)
        let tail = String(key.label.filter { $0.isHexDigit }.suffix(8))
        XCTAssertEqual(tail.count, 8)
        let saved = app.switches["setup.savedRecoveryKey"]
        reveal(saved)
        // SwiftUI exposes a labelled row and its native switch separately.
        // Tap the actual switch instead of the row's non-interactive label.
        let toggle = saved.switches.firstMatch.exists ? saved.switches.firstMatch : saved
        toggle.tap()
        XCTAssertEqual(saved.value as? String, "1")
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
        XCTAssertTrue(app.buttons["Import"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Review Backup"].isEnabled)
        capture("05-backup-import")
        checkFilesPickerAndCancel("Import")
        XCTAssertFalse(app.buttons["Review Backup"].isEnabled)
        tap("Close")
        tap("Check a Backup")
        XCTAssertTrue(app.buttons["Choose Backup File"].waitForExistence(timeout: 5))
        capture("06-backup-check")
        checkFilesPickerAndCancel()
        back(); back(); tap("Done")
        tap("Add to Library"); tap("Import from Files")
        XCTAssertTrue(app.buttons["Import"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["files.apply"].isEnabled)
        capture("07-files-import"); tap("Close")
        tap("Add to Library"); tap("Photos & Videos")
        try selectSeededPhoto()
        // Import requests Photos access for original metadata/deletion. Exercise
        // the real permission prompt in this disposable simulator library.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let fullAccess = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Full Access")).firstMatch
        if fullAccess.waitForExistence(timeout: 15) { fullAccess.tap() }
        let imported = app.staticTexts["1 Snap Imported"]
        XCTAssertTrue(imported.waitForExistence(timeout: 60), "Photo import must commit: \(app.debugDescription)\nSystem: \(springboard.debugDescription)")
        capture("photo-import-completed")
        if app.buttons["Keep Originals"].exists { tap("Keep Originals") } else { tap("Done") }
        // The count is a button that clears the active filter, not static text.
        XCTAssertTrue(app.buttons["1 Snap"].waitForExistence(timeout: 10), app.debugDescription)
        capture("populated-library")
        let importedPhoto = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Photo, ")).firstMatch
        XCTAssertTrue(importedPhoto.waitForExistence(timeout: 10))
        importedPhoto.press(forDuration: 0.85)
        tap("Share")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "1 selected")).firstMatch.waitForExistence(timeout: 10), app.debugDescription)
        tap("Save to Photos")
        XCTAssertTrue(app.staticTexts["Saved 1 to Photos with their stored dates."].waitForExistence(timeout: 30))
        capture("save-original-to-photos")
        tap("Done")
        if app.buttons["Cancel"].exists { tap("Cancel") }
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

        try verifyNativeFilesImport()
    }
}
