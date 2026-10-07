import XCTest

final class DailyBleedingUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(large: Bool = false, fixture: String = "sparse") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = fixture
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor private func tap(_ id: String, in app: XCUIApplication) {
        let button = app.buttons[id]
        UIViewport.reveal(button, in: app)
        button.tap()
    }

    @MainActor private func setSwitch(_ id: String, to enabled: Bool, in app: XCUIApplication) {
        let row = app.switches[id]
        UIViewport.reveal(row, in: app)
        let value = enabled ? "1" : "0"
        if row.value as? String != value {
            if row.switches.firstMatch.exists { row.switches.firstMatch.tap() }
            else { row.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
        }
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: row)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
    }

    @MainActor func testCalendarLoggingActionsShareOneRowAndKeepDateGuards() {
        let app = launch()
        app.tabBars.buttons["Calendar"].tap()
        tap("calendarDay_20260928", in: app)
        let actions = app.otherElements["calendarLoggingActions"]
        let identifiers = ["calendarLogPeriod", "logSymptoms", "logSexualActivity", "logDailyBleeding"]
        let first = actions.buttons[identifiers[0]]
        UIViewport.reveal(first, in: app)
        var previous: CGRect?
        for id in identifiers {
            let button = actions.buttons[id]
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertEqual(button.frame.midY, first.frame.midY, accuracy: 1,
                           identifiers.map { "\($0): \(actions.buttons[$0].frame)" }.joined(separator: ", "))
            XCTAssertTrue(app.frame.contains(button.frame))
            if let previous { XCTAssertGreaterThanOrEqual(button.frame.minX, previous.maxX) }
            previous = button.frame
        }
        actions.buttons["logDailyBleeding"].tap()
        XCTAssertTrue(app.navigationBars["Daily bleeding"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["September 28, 2026"].exists)
        app.navigationBars.buttons["Cancel"].tap()
        tap("calendarDay_20260930", in: app)
        for id in identifiers { XCTAssertFalse(actions.buttons[id].isEnabled) }
        tap("calendarDay_20260928", in: app)
        for id in identifiers { XCTAssertTrue(actions.buttons[id].isEnabled) }
    }

    @MainActor func testCalendarLoggingActionsAtLargestText() {
        let app = launch(large: true)
        app.tabBars.buttons["Calendar"].tap()
        tap("calendarDay_20260902", in: app)
        let actions = app.otherElements["calendarLoggingActions"]
        for id in ["calendarLogPeriod", "logSymptoms", "logSexualActivity", "logDailyBleeding"] {
            let button = actions.buttons[id]
            UIViewport.reveal(button, in: app)
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertGreaterThanOrEqual(button.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX)
        }
        actions.buttons["logDailyBleeding"].tap()
        XCTAssertTrue(app.navigationBars["Daily bleeding"].waitForExistence(timeout: 5))
    }

    @MainActor func testTodayLoggingActionsShareOneRow() {
        let app = launch()
        let actions = app.otherElements["todayLogActions"]
        let identifiers = ["logPeriod", "logSymptoms", "logSexualActivity", "logDailyBleeding"]
        let first = actions.buttons[identifiers[0]]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        var previous: CGRect?
        for id in identifiers {
            let button = actions.buttons[id]
            XCTAssertTrue(button.exists)
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertEqual(button.frame.midY, first.frame.midY, accuracy: 1,
                           identifiers.map { "\($0): \(actions.buttons[$0].frame)" }.joined(separator: ", "))
            XCTAssertTrue(app.frame.contains(button.frame))
            if let previous { XCTAssertGreaterThanOrEqual(button.frame.minX, previous.maxX) }
            previous = button.frame
        }
    }

    @MainActor func testDailyFlowChipsPersistAndClear() {
        let app = launch()
        tap("logDailyBleeding", in: app)
        tap("dailyState_bleeding", in: app)
        let none = app.buttons["dailyFlow_none"]
        XCTAssertTrue(none.waitForExistence(timeout: 5))
        XCTAssertEqual(none.value as? String, "Selected")
        let light = app.buttons["dailyFlow_light"]
        XCTAssertEqual(light.frame.midY, none.frame.midY, accuracy: 1)
        XCTAssertGreaterThanOrEqual(light.frame.minX, none.frame.maxX)
        for value in ["light", "moderate", "heavy"] {
            tap("dailyFlow_\(value)", in: app)
            XCTAssertEqual(app.buttons["dailyFlow_\(value)"].value as? String, "Selected")
        }
        app.buttons["saveDailyBleeding"].tap()
        XCTAssertTrue(app.navigationBars["Daily bleeding"].waitForNonExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15))
        tap("logDailyBleeding", in: app)
        XCTAssertEqual(app.buttons["dailyFlow_heavy"].value as? String, "Selected")
        tap("dailyFlow_none", in: app)
        app.buttons["saveDailyBleeding"].tap()
        XCTAssertTrue(app.navigationBars["Edit daily answer"].waitForNonExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15))
        tap("logDailyBleeding", in: app)
        XCTAssertEqual(app.buttons["dailyFlow_none"].value as? String, "Selected")
        tap("dailyState_spotting", in: app)
        XCTAssertFalse(app.buttons["dailyFlow_none"].exists)
    }

    @MainActor func testDailyFlowChipsAndActionsAtLargestText() {
        let app = launch(large: true)
        for id in ["logPeriod", "logSymptoms", "logSexualActivity", "logDailyBleeding"] {
            let button = app.buttons[id]
            UIViewport.reveal(button, in: app)
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertGreaterThanOrEqual(button.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX)
        }
        tap("logDailyBleeding", in: app)
        tap("dailyState_bleeding", in: app)
        for value in ["none", "light", "moderate", "heavy"] {
            let chip = app.buttons["dailyFlow_\(value)"]
            UIViewport.reveal(chip, in: app)
            XCTAssertTrue(chip.isHittable)
            XCTAssertGreaterThanOrEqual(chip.frame.height, 44)
            XCTAssertGreaterThanOrEqual(chip.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(chip.frame.maxX, app.frame.maxX)
            chip.tap()
            XCTAssertEqual(chip.value as? String, "Selected")
        }
    }

    @MainActor func testStandaloneAnswerPersistsAcrossTabsEditAndDelete() {
        let app = launch()
        tap("logDailyBleeding", in: app)
        XCTAssertFalse(app.buttons["saveDailyBleeding"].isEnabled)
        tap("dailyState_spotting", in: app)
        app.buttons["saveDailyBleeding"].tap()
        XCTAssertTrue(app.navigationBars["Daily bleeding"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["todayDate_20260929"].label.contains("Daily answer: Spotting"))
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.buttons["calendarDay_20260929"].label.contains("Daily answer: Spotting"))
        tap("logDailyBleeding", in: app)
        tap("dailyState_noBleeding", in: app)
        app.buttons["saveDailyBleeding"].tap()
        XCTAssertTrue(app.navigationBars["Edit daily answer"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["calendarDay_20260929"].label.contains("Daily answer: No bleeding"))
        tap("deleteDailyBleeding", in: app)
        app.alerts.buttons["Delete answer"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertFalse(app.buttons["calendarDay_20260929"].label.contains("Daily answer:"))
        XCTAssertTrue(app.buttons["calendarDay_20260902"].label.contains("Recorded period start"))
        app.buttons["nextMonth"].tap()
        app.buttons["calendarDay_20261001"].tap()
        XCTAssertFalse(app.buttons["logDailyBleeding"].isEnabled)
    }

    @MainActor func testLinkedAnswerSurvivesReviewedPeriodDeletion() {
        let app = launch()
        app.tabBars.buttons["Calendar"].tap()
        app.buttons["calendarDay_20260902"].tap()
        tap("logDailyBleeding", in: app)
        tap("dailyState_bleeding", in: app)
        setSwitch("dailyPeriodLink", to: true, in: app)
        app.buttons["saveDailyBleeding"].tap()
        XCTAssertTrue(app.navigationBars["Daily bleeding"].waitForNonExistence(timeout: 10))
        tap("deletePeriod", in: app)
        XCTAssertTrue(app.alerts.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Daily answers stay saved'")).firstMatch.exists)
        app.alerts.buttons["Delete recorded period"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForNonExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Calendar"].tap()
        let date = app.buttons["calendarDay_20260902"]
        XCTAssertTrue(date.label.contains("Daily answer: Bleeding"))
        XCTAssertFalse(date.label.contains("Recorded period start"))
    }

    @MainActor func testLargeTextCancellationAndConflictingDailyAnswer() {
        let app = launch(large: true)
        tap("logDailyBleeding", in: app)
        tap("dailyState_unsure", in: app)
        XCTAssertEqual(app.buttons["dailyState_unsure"].value as? String, "Selected")
        app.navigationBars.buttons["Cancel"].tap()
        app.buttons["Discard changes"].tap()
        XCTAssertTrue(app.navigationBars["Daily bleeding"].waitForNonExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["todayDate_20260929"].label.contains("Daily answer:"))
        app.tabBars.buttons["Calendar"].tap()
        tap("calendarDay_20260902", in: app)
        tap("logDailyBleeding", in: app)
        tap("dailyState_noBleeding", in: app)
        XCTAssertFalse(app.buttons["saveDailyBleeding"].isEnabled)
        UIViewport.reveal(app.buttons["correctDailyPeriod"], in: app)
        XCTAssertTrue(app.buttons["correctDailyPeriod"].isHittable)
    }

    @MainActor func testSummaryPreviewPrivacyAndShareCancellation() {
        let app = launch()
        app.tabBars.buttons["Insights"].tap()
        XCTAssertEqual(app.staticTexts["recordingCoverage"].label, "Days logged: 0 of 30")
        tap("appointmentSummary", in: app)
        for id in ["summarySymptoms", "summaryContext", "summaryNotes"] {
            let toggle = app.switches[id]
            UIViewport.reveal(toggle, in: app)
            XCTAssertEqual(toggle.value as? String, "0")
        }
        tap("previewSummary", in: app)
        let text = app.staticTexts["summaryPreviewText"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue(text.label.contains("Days logged: 0 of 90"))
        XCTAssertTrue(text.label.contains("end not recorded"))
        XCTAssertFalse(text.label.contains("Synthetic Alex"))
        XCTAssertFalse(text.label.contains("Cramps"))
        app.buttons["shareSummary"].tap()
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: close)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["shareSummary"].isEnabled)
        app.navigationBars.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["previewSummary"].waitForExistence(timeout: 5))
    }

    @MainActor func testCoverageAndSummaryAtLargestTextSize() {
        let app = launch(large: true)
        tap("logDailyBleeding", in: app)
        tap("dailyState_unsure", in: app)
        app.buttons["saveDailyBleeding"].tap()
        XCTAssertTrue(app.navigationBars["Daily bleeding"].waitForNonExistence(timeout: 10))
        app.tabBars.buttons["Insights"].tap()
        UIViewport.reveal(app.staticTexts["recordingCoverage"], in: app)
        XCTAssertEqual(app.staticTexts["recordingCoverage"].label, "Days logged: 1 of 30")
        tap("appointmentSummary", in: app)
        tap("previewSummary", in: app)
        let text = app.staticTexts["summaryPreviewText"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue(text.label.contains("Not sure: 1"))
        XCTAssertTrue(text.label.contains("Not logged: 89"))
        XCTAssertGreaterThanOrEqual(app.buttons["shareSummary"].frame.height, 44)
    }

    @MainActor func testDailyConflictCorrectionRequiresFinalConfirmation() {
        let app = launch(fixture: "ai")
        app.tabBars.buttons["Calendar"].tap()
        app.buttons["calendarDay_20260906"].tap()
        tap("logDailyBleeding", in: app)
        tap("dailyState_noBleeding", in: app)
        XCTAssertFalse(app.buttons["saveDailyBleeding"].isEnabled)
        tap("correctDailyPeriod", in: app)
        let includeEnd = app.switches["includeEndDate"]
        XCTAssertTrue(includeEnd.waitForExistence(timeout: 5))
        setSwitch("includeEndDate", to: false, in: app)
        XCTAssertTrue(app.buttons["savePeriod"].isEnabled)
        app.buttons["savePeriod"].tap()
        XCTAssertTrue(app.navigationBars["Edit period"].waitForNonExistence(timeout: 10))
        app.buttons["saveDailyBleeding"].tap()
        app.alerts.buttons["Keep editing"].tap()
        app.navigationBars.buttons["Cancel"].tap()
        app.buttons["Discard changes"].tap()
        XCTAssertTrue(app.navigationBars["Daily bleeding"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["calendarDay_20260906"].label.contains("Confirmed bleeding"))
        tap("logDailyBleeding", in: app)
        tap("dailyState_noBleeding", in: app)
        tap("correctDailyPeriod", in: app)
        XCTAssertTrue(includeEnd.waitForExistence(timeout: 5))
        setSwitch("includeEndDate", to: false, in: app)
        app.buttons["savePeriod"].tap()
        XCTAssertTrue(app.navigationBars["Edit period"].waitForNonExistence(timeout: 10))
        app.buttons["saveDailyBleeding"].tap()
        app.alerts.buttons["Save changes"].tap()
        XCTAssertTrue(app.navigationBars["Daily bleeding"].waitForNonExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.buttons["calendarDay_20260906"].label.contains("Daily answer: No bleeding"))
        XCTAssertFalse(app.buttons["calendarDay_20260906"].label.contains("Confirmed bleeding"))
        XCTAssertTrue(app.buttons["calendarDay_20260902"].label.contains("Recorded period start"))
    }

    @MainActor func testPeriodBoundaryReviewRetainsDailyAnswer() {
        let app = launch(fixture: "ai")
        app.tabBars.buttons["Calendar"].tap()
        app.buttons["calendarDay_20260906"].tap()
        tap("logDailyBleeding", in: app)
        tap("dailyState_bleeding", in: app)
        setSwitch("dailyPeriodLink", to: true, in: app)
        app.buttons["saveDailyBleeding"].tap()
        XCTAssertTrue(app.navigationBars["Daily bleeding"].waitForNonExistence(timeout: 10))
        tap("calendarLogPeriod", in: app)
        setSwitch("includeEndDate", to: false, in: app)
        XCTAssertTrue(app.buttons["savePeriod"].isEnabled)
        app.buttons["savePeriod"].tap()
        XCTAssertTrue(app.alerts["Keep daily answers separately?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Keep editing"].tap()
        XCTAssertTrue(app.navigationBars["Edit period"].exists)
        app.buttons["savePeriod"].tap()
        app.alerts.buttons["Save reviewed changes"].tap()
        XCTAssertTrue(app.navigationBars["Edit period"].waitForNonExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.buttons["calendarDay_20260906"].label.contains("Daily answer: Bleeding"))
        XCTAssertFalse(app.buttons["calendarDay_20260906"].label.contains("Confirmed bleeding"))
        XCTAssertTrue(app.buttons["calendarDay_20260902"].label.contains("Recorded period start"))
    }
}
