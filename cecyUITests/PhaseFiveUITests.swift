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
        if element.isHittable { return }
        // Navigation can restore a previous scroll offset; search from the top, not only downward.
        for _ in 0..<4 { app.swipeDown() }
        for _ in 0..<12 { if element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.isHittable, app.debugDescription)
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
        reveal(about, in: app); about.tap()
        XCTAssertTrue(app.staticTexts["Internal prototype"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        reveal(privacyLink, in: app); privacyLink.tap()
        XCTAssertEqual(app.staticTexts["lockState"].label, "Off")
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
        reveal(privacyLink, in: app); privacyLink.tap()
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
        XCTAssertTrue(unlock.waitForExistence(timeout: 10)); unlock.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Authentication was cancelled")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["logPeriod"].exists)
        app.terminate(); app.launchEnvironment["CECY_UI_AUTH"] = "success"; app.launch()
        XCTAssertTrue(unlock.waitForExistence(timeout: 10)); unlock.tap()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 10))
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(unlock.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["logPeriod"].exists)
        unlock.tap()
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
        toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.tap()
        XCTAssertTrue(app.staticTexts["reminderDraftStatus"].exists)
        app.buttons["saveReminders"].tap()
        let savedDaily = app.staticTexts["savedDailyReminder"]
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "On"), object: savedDaily)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed)
        XCTAssertFalse(app.staticTexts["reminderDraftStatus"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Settings"].tap()
        reveal(reminders, in: app); reminders.tap()
        XCTAssertEqual(app.switches["dailyReminder"].value as? String, "1")
        app.navigationBars["Reminders"].buttons.element(boundBy: 0).tap()
        let reset = app.buttons["deleteAllData"]
        reveal(reset, in: app); reset.tap()
        let confirmation = app.textFields["resetConfirmation"]
        reveal(confirmation, in: app); confirmation.tap(); confirmation.typeText("DELETE")
        let commit = app.buttons["confirmReset"]
        reveal(commit, in: app); commit.tap()
        OnboardingUITestSupport.complete(in: app)
        app.tabBars.buttons["Settings"].tap()
        reveal(reminders, in: app); reminders.tap()
        XCTAssertEqual(app.switches["dailyReminder"].value as? String, "0")
        XCTAssertEqual(app.staticTexts["savedDailyReminder"].label, "Off")
    }
}
