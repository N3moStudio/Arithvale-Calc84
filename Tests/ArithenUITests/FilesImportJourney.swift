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

    private func openDownloads(_ host: XCUIApplication, createIfMissing: Bool = false) {
        openLocalRoot(host)
        let folder = fileCell("Downloads", in: host)
        if !folder.waitForExistence(timeout: 3), createIfMissing {
            let bar = filesNavigation(host)
            let newFolder = host.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'New Folder'")).firstMatch
            if !newFolder.exists {
                let more = bar.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'more'")).firstMatch
                XCTAssertTrue(more.exists, host.debugDescription)
                more.tap()
            }
            XCTAssertTrue(newFolder.waitForExistence(timeout: 5), host.debugDescription)
            newFolder.tap()
            let field = host.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 5), host.debugDescription)
            field.tap()
            if let old = field.value as? String, !old.isEmpty && old != field.placeholderValue {
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
            }
            field.typeText("Downloads")
            let create = host.buttons["Create"].firstMatch
            if create.exists { create.tap() } else { field.typeText("\n") }
        }
        let title = filesNavigation(host).descendants(matching: .any).matching(NSPredicate(
            format: "identifier != 'BackButton' AND (label == 'Downloads' OR label BEGINSWITH 'Downloads,')")).firstMatch
        if !title.waitForExistence(timeout: 2) {
            XCTAssertTrue(folder.waitForExistence(timeout: 10), host.debugDescription)
            folder.tap()
        }
        XCTAssertTrue(title.waitForExistence(timeout: 15), host.debugDescription)
    }

    private func saveSamples() {
        // First let the real local Files provider finish first-run setup.
        let files = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        files.launch()
        let browse = files.tabBars["DOC.browsingModeTabBar"].buttons["Browse"]
        XCTAssertTrue(browse.waitForExistence(timeout: 60), files.debugDescription)
        browse.tap(); browse.tap()
        let local = files.staticTexts["On My iPhone"].firstMatch
        XCTAssertTrue(local.waitForExistence(timeout: 30), files.debugDescription)
        local.tap()

        let exporter = XCUIApplication(bundleIdentifier: "studio.n3mo.files-sample-exporter")
        exporter.launch()
        exporter.buttons["Save samples to Files"].tap()
        openDownloads(exporter, createIfMissing: true)
        let bar = filesNavigation(exporter)
        let save = bar.buttons.matching(NSPredicate(format: "label == 'Save' OR label == 'Export' OR label == 'Move'")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 10), exporter.debugDescription)
        save.tap()
        XCTAssertTrue(bar.waitForNonExistence(timeout: 20), exporter.debugDescription)
        exporter.terminate()
    }

    private func selectSample(_ name: String, until destination: XCUIElement) {
        openDownloads(app)
        let cell = fileCell(name, in: app)
        XCTAssertTrue(cell.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(cell.isEnabled)
        capture("files-select-" + name)
        let thumb = cell.images.firstMatch
        if thumb.exists && thumb.isHittable { thumb.tap() }
        else { cell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap() }
        if !destination.waitForExistence(timeout: 3) {
            let open = filesNavigation(app).buttons["Open"]
            if open.waitForExistence(timeout: 3), open.isEnabled { open.tap() }
        }
        XCTAssertTrue(destination.waitForExistence(timeout: 20), app.debugDescription)
    }

    func verifyNativeFilesImport() throws {
        app.terminate()
        saveSamples()
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
        app.terminate(); app.launch()
        enter("963852"); holdEquals()
        XCTAssertTrue(app.buttons["2 Snaps"].waitForExistence(timeout: 15), app.debugDescription)
        let orchard = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Orchard-rain-47.txt")).firstMatch
        XCTAssertTrue(orchard.waitForExistence(timeout: 15), app.debugDescription)
        capture("files-relaunched-library")
    }
}
