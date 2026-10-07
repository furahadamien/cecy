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
