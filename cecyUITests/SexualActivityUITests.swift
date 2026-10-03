import XCTest

final class SexualActivityUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "history"
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

    @MainActor private func tap(_ identifier: String, in app: XCUIApplication) {
        let button = app.buttons[identifier]
        reveal(button, in: app); button.tap()
    }

    @MainActor func testMultipleActivitiesPersistCanBeEditedCancelledAndDeleted() {
        let app = launch()
        tap("logSexualActivity", in: app)
        XCTAssertFalse(app.buttons["saveSexualActivity"].isEnabled)
        tap("sexualActivityKind_vaginalSex", in: app)
        tap("sexualActivityKind_oralSex", in: app)
        XCTAssertTrue(app.buttons["sexualActivityKind_vaginalSex"].isSelected)
        XCTAssertTrue(app.buttons["sexualActivityKind_oralSex"].isSelected)
        app.buttons["saveSexualActivity"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 10))
        tap("sexualActivityHistory", in: app)
        let summary = app.staticTexts["sexualActivitySummary_20260929"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertEqual(summary.label, "Vaginal sex, Oral sex")
        tap("editSexualActivity_20260929", in: app)
        XCTAssertTrue(app.buttons["sexualActivityKind_oralSex"].isSelected)
        tap("sexualActivityKind_oralSex", in: app)
        XCTAssertFalse(app.buttons["sexualActivityKind_oralSex"].isSelected)
        XCTAssertTrue(app.buttons["saveSexualActivity"].isEnabled)
        app.buttons["Cancel"].tap()
        let discard = app.alerts.buttons["Discard changes"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap()
        XCTAssertEqual(summary.label, "Vaginal sex, Oral sex")
        tap("editSexualActivity_20260929", in: app)
        tap("sexualActivityKind_oralSex", in: app)
        tap("sexualActivityKind_masturbation", in: app)
        app.buttons["saveSexualActivity"].tap()
        XCTAssertEqual(summary.label, "Vaginal sex, Masturbation")
        // Logging again on the same day opens the existing record, not a duplicate.
        tap("logSexualActivity", in: app)
        XCTAssertTrue(app.buttons["sexualActivityKind_masturbation"].isSelected)
        XCTAssertFalse(app.buttons["saveSexualActivity"].isEnabled)
        app.buttons["Cancel"].tap()
        XCTAssertEqual(app.staticTexts.matching(identifier: "sexualActivitySummary_20260929").count, 1)
        tap("deleteSexualActivity_20260929", in: app)
        app.buttons["Keep record"].tap()
        XCTAssertTrue(summary.exists)
        tap("deleteSexualActivity_20260929", in: app)
        app.buttons["Delete activity record"].tap()
        XCTAssertTrue(app.staticTexts["No sexual activity recorded yet."].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 10))
        tap("sexualActivityHistory", in: app)
        XCTAssertTrue(app.staticTexts["No sexual activity recorded yet."].exists)
    }

    @MainActor func testCalendarRecordsPastDayAndDoesNotOfferFutureLogging() {
        let app = launch()
        app.tabBars.buttons["Calendar"].tap()
        tap("calendarDay_20260928", in: app)
        tap("logSexualActivity", in: app)
        tap("sexualActivityKind_other", in: app)
        app.buttons["saveSexualActivity"].tap()
        let summary = app.staticTexts["sexualActivitySummary_20260928"]
        reveal(summary, in: app)
        XCTAssertEqual(summary.label, "Other activity")
        let day = app.buttons["calendarDay_20260928"]
        reveal(day, in: app)
        XCTAssertTrue(day.label.contains("1 recorded observations"))
        tap("calendarDay_20260930", in: app)
        let futureLog = app.buttons["logSexualActivity"]
        reveal(futureLog, in: app)
        XCTAssertTrue(futureLog.exists)
        XCTAssertFalse(futureLog.isEnabled)
    }

    @MainActor func testActivityChoicesSupportLargestTextAndExportDefaultsOff() {
        let app = launch(largeText: true)
        tap("logSexualActivity", in: app)
        for kind in ["vaginalSex", "oralSex", "analSex", "masturbation", "other"] {
            let button = app.buttons["sexualActivityKind_\(kind)"]
            reveal(button, in: app)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.width)
            button.tap()
            XCTAssertTrue(button.isSelected)
        }
        app.buttons["saveSexualActivity"].tap()
        app.tabBars.buttons["Settings"].tap()
        tap("privacySettings", in: app)
        let toggle = app.switches["exportSexualActivity"]
        reveal(toggle, in: app)
        XCTAssertEqual(toggle.value as? String, "0")
    }
}
