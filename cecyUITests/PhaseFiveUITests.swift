import XCTest

final class PhaseFiveUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "history"
        app.launchEnvironment["CECY_UI_AUTH"] = "success"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 10))
        app.launchEnvironment.removeValue(forKey: "CECY_UI_FIXTURE")
        return app
    }
    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        UIViewport.reveal(element, in: app)
    }
    @MainActor private func privacy(in app: XCUIApplication) {
        app.tabBars.buttons["Settings"].tap()
        let link = app.buttons["privacySettings"]
        reveal(link, in: app); link.tap()
    }

    @MainActor func testAppearanceTogglePersistsAndCanFollowDevice() {
        let app = launch()
        app.tabBars.buttons["Settings"].tap()
        let dark = app.switches["darkMode"]
        reveal(dark, in: app)
        let target = dark.value as? String == "1" ? "0" : "1"
        dark.switches.firstMatch.exists ? dark.switches.firstMatch.tap() : dark.tap()
        XCTAssertEqual(dark.value as? String, target)
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Settings"].tap()
        reveal(dark, in: app)
        XCTAssertEqual(dark.value as? String, target)
        let automatic = app.buttons["systemAppearance"]
        reveal(automatic, in: app); automatic.tap()
        XCTAssertFalse(automatic.isEnabled)
        XCTAssertEqual(app.staticTexts["appearanceStatus"].label, "Following your device’s appearance.")
    }

    @MainActor func testSettingsSummaryAndDetailNavigation() {
        let app = launch()
        app.tabBars.buttons["Settings"].tap()
        let privacyLink = app.buttons["privacySettings"]
        XCTAssertTrue(privacyLink.waitForExistence(timeout: 5))
        XCTAssertTrue(privacyLink.label.contains("App lock: Off"))
        XCTAssertTrue(app.buttons["reminderSettings"].label.contains("Off"))
        XCTAssertFalse(app.staticTexts["Internal prototype"].exists)

        let predictions = app.buttons["predictionSettings"]
        reveal(predictions, in: app); predictions.tap()
        let details = app.buttons["predictionCalculationDetails"]
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        let calculation = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "The center uses the median.")).firstMatch
        XCTAssertFalse(calculation.exists)
        details.tap()
        reveal(calculation, in: app)
        XCTAssertTrue(calculation.exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let about = app.buttons["aboutCecy"]
        reveal(about, in: app)
        XCTAssertTrue(about.label.contains("Version"))
        about.tap()
        XCTAssertTrue(app.navigationBars["About Cecy"].waitForExistence(timeout: 5))
        let disclosure = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Records and calculations stay on-device.")).firstMatch
        reveal(disclosure, in: app)
        XCTAssertTrue(disclosure.label.contains("only with consent and a request"))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        UIViewport.reveal(privacyLink, in: app, searchEarlierFirst: true); privacyLink.tap()
        XCTAssertTrue(["Off", "Status, Off"].contains(app.staticTexts["lockState"].label))
        let storage = app.buttons["storageSettings"]
        reveal(storage, in: app); storage.tap()
        XCTAssertTrue(app.navigationBars["Storage and backups"].waitForExistence(timeout: 5))
    }

    @MainActor func testSettingsRemainAccessibleAtLargestTextSize() {
        let app = launch(largeText: true)
        app.tabBars.buttons["Settings"].tap()
        for identifier in ["profileSettings", "accountSettings", "privacySettings", "reminderSettings", "predictionSettings", "aboutCecy", "deleteAllData"] {
            let row = app.buttons[identifier]
            reveal(row, in: app)
            XCTAssertGreaterThanOrEqual(row.frame.height, 44)
        }
        let privacyLink = app.buttons["privacySettings"]
        UIViewport.reveal(privacyLink, in: app, searchEarlierFirst: true); privacyLink.tap()
        let notes = app.switches["exportNotes"]
        reveal(notes, in: app)
        XCTAssertEqual(notes.value as? String, "0")
        let export = app.buttons["prepareExport"]
        reveal(export, in: app)
        XCTAssertGreaterThanOrEqual(export.frame.height, 44)
    }

    @MainActor func testLockPersistsCancelFailsClosedAndBackgroundRelocks() {
        let app = launch()
        privacy(in: app)
        app.buttons["enableAppLock"].tap()
        let lock = app.buttons["lockNow"]
        XCTAssertTrue(lock.waitForExistence(timeout: 5)); lock.tap()
        XCTAssertTrue(app.buttons["unlockCecy"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["logPeriod"].exists)
        app.terminate()
        app.launchEnvironment["CECY_UI_AUTH"] = "cancel"
        app.launch()
        let unlock = app.buttons["unlockCecy"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 10))
        let icon = app.images["lockedCecyIcon"]
        XCTAssertTrue(icon.exists)
        XCTAssertEqual(icon.label, "Cecy")
        XCTAssertGreaterThanOrEqual(icon.frame.width, 120)
        XCTAssertFalse(app.staticTexts["Cecy · Private"].exists)
        XCTAssertEqual(unlock.label, "Unlock")
        XCTAssertFalse(app.staticTexts["Cecy is locked"].exists)
        XCTAssertFalse(app.staticTexts["Device-owner authentication"].exists)
        XCTAssertTrue(unlock.isEnabled)
        unlock.tap()
        XCTAssertTrue(icon.exists)
        XCTAssertFalse(app.buttons["logPeriod"].exists)
        app.terminate(); app.launchEnvironment["CECY_UI_AUTH"] = "success"; app.launch()
        // Launch and foreground return authenticate without a button tap.
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 10))
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 10))
        privacy(in: app)
        app.buttons["Turn off app lock"].tap()
        app.buttons["Authenticate to turn off"].tap()
        XCTAssertTrue(app.buttons["enableAppLock"].waitForExistence(timeout: 5))
    }

    @MainActor func testExportIsExplicitNotesDefaultOffAndSharingCanCancel() {
        let app = launch()
        privacy(in: app)
        let notes = app.switches["exportNotes"]
        reveal(notes, in: app)
        XCTAssertEqual(notes.value as? String, "0")
        let prepare = app.buttons["prepareExport"]
        reveal(prepare, in: app); prepare.tap()
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10), app.debugDescription)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: close)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        close.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: close)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 10), .completed, app.debugDescription)
        XCTAssertTrue(prepare.waitForExistence(timeout: 5))
        reveal(prepare, in: app)
        XCTAssertTrue(prepare.isEnabled)
    }

    @MainActor func testReminderChoicesPersistAndResetDisablesThem() {
        let app = launch()
        app.tabBars.buttons["Settings"].tap()
        let reminders = app.buttons["reminderSettings"]
        reveal(reminders, in: app); reminders.tap()
        let toggle = app.switches["dailyReminder"]
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1")
        let details = app.switches["reminderDetails"]
        reveal(details, in: app)
        XCTAssertEqual(details.value as? String, "0")
        details.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let preview = app.staticTexts["reminderPreview_daily"]
        reveal(preview, in: app)
        XCTAssertTrue(preview.label.contains("Log your period, symptoms or how you feel today."))
        reveal(app.buttons["saveReminders"], in: app)
        XCTAssertTrue(app.staticTexts["reminderDraftStatus"].exists)
        app.buttons["saveReminders"].tap()
        let savedDaily = app.staticTexts["savedDailyReminder"]
        reveal(savedDaily, in: app)
        let saved = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label IN %@", ["On", "Daily check-in, On"]), object: savedDaily)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed, app.debugDescription)
        XCTAssertFalse(app.staticTexts["reminderDraftStatus"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Settings"].tap()
        reveal(reminders, in: app); reminders.tap()
        XCTAssertEqual(app.switches["dailyReminder"].value as? String, "1")
        reveal(details, in: app)
        XCTAssertEqual(details.value as? String, "1")
        app.navigationBars["Reminders"].buttons.element(boundBy: 0).tap()
        let reset = app.buttons["deleteAllData"]
        reveal(reset, in: app); reset.tap()
        XCTAssertTrue(app.alerts["Delete all data?"].waitForExistence(timeout: 5))
        app.alerts["Delete all data?"].buttons["reviewDataDeletion"].firstMatch.tap()
        let confirmation = app.textFields["resetConfirmation"]
        reveal(confirmation, in: app); confirmation.tap(); confirmation.typeText("DELETE")
        let commit = app.buttons["confirmReset"]
        reveal(commit, in: app); commit.tap()
        OnboardingUITestSupport.complete(in: app)
        app.tabBars.buttons["Settings"].tap()
        reveal(reminders, in: app); reminders.tap()
        XCTAssertEqual(app.switches["dailyReminder"].value as? String, "0")
        reveal(app.staticTexts["savedDailyReminder"], in: app)
        XCTAssertTrue(["Off", "Daily check-in, Off"].contains(app.staticTexts["savedDailyReminder"].label))
    }
}
