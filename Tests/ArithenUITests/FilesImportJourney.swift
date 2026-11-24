import XCTest

extension ArithenUITests {
    private func filesNavigation(_ host: XCUIApplication) -> XCUIElement {
        host.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
    }

    private func openLocalRoot(_ host: XCUIApplication) {
        let bar = filesNavigation(host)
        XCTAssertTrue(bar.waitForExistence(timeout: 30), host.debugDescription)
        let title = bar.descendants(matching: .any).matching(NSPredicate(
            format: "identifier != 'BackButton' AND (label == 'On My iPhone' OR label BEGINSWITH 'On My iPhone,')")).firstMatch
        if title.waitForExistence(timeout: 2) { return }
        let back = bar.buttons["BackButton"]
        if back.exists && back.label == "On My iPhone" { back.tap() }
        if title.waitForExistence(timeout: 2) { return }
        let browse = host.tabBars["DOC.browsingModeTabBar"].buttons["Browse"]
        if browse.exists && browse.isHittable { browse.tap(); browse.tap() }
        else if back.exists { back.tap() }
        let local = host.staticTexts["On My iPhone"].firstMatch
        XCTAssertTrue(local.waitForExistence(timeout: 15), host.debugDescription)
        let row = host.cells.containing(.staticText, identifier: "On My iPhone").firstMatch
        if row.exists { row.tap() } else { local.tap() }
        XCTAssertTrue(title.waitForExistence(timeout: 15), host.debugDescription)
    }

    private func fileCell(_ name: String, in host: XCUIApplication) -> XCUIElement {
        let stem = (name as NSString).deletingPathExtension
        return host.cells.matching(NSPredicate(format: "label BEGINSWITH %@ OR label == %@ OR label BEGINSWITH %@",
                                               name, stem, stem + ",")).firstMatch
    }

    private func openSampleDownloads(_ host: XCUIApplication) {
        let bar = filesNavigation(host)
        XCTAssertTrue(bar.waitForExistence(timeout: 30), host.debugDescription)
        func title(_ name: String) -> XCUIElement {
            bar.descendants(matching: .any).matching(NSPredicate(
                format: "identifier != 'BackButton' AND (label == %@ OR label BEGINSWITH %@)", name, name + ",")).firstMatch
        }
        if title("Downloads").waitForExistence(timeout: 3) { return }
        if !title("Arithen Samples").exists {
            openLocalRoot(host)
            let samples = fileCell("Arithen Samples", in: host)
            XCTAssertTrue(samples.waitForExistence(timeout: 25), host.debugDescription)
            samples.tap()
        }
        let folder = fileCell("Downloads", in: host)
        XCTAssertTrue(folder.waitForExistence(timeout: 15), host.debugDescription)
        folder.tap()
        XCTAssertTrue(title("Downloads").waitForExistence(timeout: 15), host.debugDescription)
    }

    func saveSamples() {
        let exporter = XCUIApplication(bundleIdentifier: "studio.n3mo.files-sample-exporter")
        exporter.launch()
        exporter.buttons["Export samples to folder"].tap()
        openSampleDownloads(exporter)
        let open = filesNavigation(exporter).buttons["Open"].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 10) && open.isEnabled, exporter.debugDescription)
        open.tap()
        XCTAssertTrue(exporter.staticTexts["Saved four samples to Downloads"].waitForExistence(timeout: 30), exporter.debugDescription)
        exporter.terminate()
    }

    private func selectSample(_ name: String, until destination: XCUIElement) {
        openSampleDownloads(app)
        let cell = fileCell(name, in: app)
        XCTAssertTrue(cell.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(cell.isEnabled)
        capture("files-select-" + name)
        let thumb = cell.images.firstMatch
        if thumb.exists && thumb.isHittable { thumb.tap() }
        else { cell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap() }
        // The filename is visible both in Files and in Arithen. Confirm the
        // multi-selection before treating the destination as the app's screen.
        let picker = filesNavigation(app)
        if !picker.waitForNonExistence(timeout: 2) {
            let open = picker.buttons["Open"]
            XCTAssertTrue(open.waitForExistence(timeout: 5), app.debugDescription)
            let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: open)
            XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
            open.tap()
            XCTAssertTrue(picker.waitForNonExistence(timeout: 15), app.debugDescription)
        }
        XCTAssertTrue(destination.waitForExistence(timeout: 20), app.debugDescription)
    }

    func verifyNativeFilesImport() throws {
        app.terminate()
        app.launchArguments = []
        app.launch()
        enter("963852"); holdEquals()
        tap("Add to Library"); tap("From a Backup")
        tap("Import")
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 15))
        cancel.tap()
        XCTAssertTrue(app.staticTexts["No file selected."].waitForExistence(timeout: 10))
        tap("Import")
        let invalid = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Couldn’t prepare this backup")).firstMatch
        selectSample("Invalid-sample.arithenbackup", until: invalid)
        XCTAssertFalse(app.buttons["Review Backup"].isEnabled)
        tap("Import")
        selectSample("Orchard-sample.arithenbackup", until: app.staticTexts["Orchard-sample.arithenbackup"])
        func authenticate() {
            let key = app.secureTextFields["Backup recovery key"]
            key.tap(); key.typeText("orchard-rain-test-key")
            tap("Review Backup")
            XCTAssertTrue(app.staticTexts["Orchard-rain-47.txt"].waitForExistence(timeout: 30), app.debugDescription)
        }
        authenticate()
        capture("files-authenticated-review")
        tap("Cancel Review"); tap("Close")
        XCTAssertTrue(app.buttons["1 Snap"].waitForExistence(timeout: 10), app.debugDescription)

        // The ordinary Files entrance must also recognize an archive that a
        // provider presents as generic binary data.
        tap("Add to Library"); tap("Import from Files"); tap("Import")
        selectSample("Generic-sample.bin", until: app.staticTexts["Generic-sample.bin"])
        authenticate()
        app.buttons["backup.apply"].tap()
        XCTAssertTrue(app.buttons["View Library"].waitForExistence(timeout: 30), app.debugDescription)
        tap("View Library")
        XCTAssertTrue(app.buttons["2 Snaps"].waitForExistence(timeout: 10), app.debugDescription)
        tap("Add to Library"); tap("Import from Files"); tap("Import")
        selectSample("River-reading-52.txt", until: app.staticTexts["River-reading-52.txt"])
        app.buttons["files.apply"].tap()
        XCTAssertTrue(app.staticTexts["1 file imported"].waitForExistence(timeout: 30), app.debugDescription)
        app.terminate(); app.launch()
        enter("963852"); holdEquals()
        XCTAssertTrue(app.buttons["3 Snaps"].waitForExistence(timeout: 15), app.debugDescription)
        let orchard = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Orchard-rain-47.txt")).firstMatch
        XCTAssertTrue(orchard.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "River-reading-52.txt")).firstMatch.exists)
        capture("files-relaunched-library")
    }
}
