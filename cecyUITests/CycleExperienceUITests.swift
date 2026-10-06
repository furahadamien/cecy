import XCTest

final class CycleExperienceUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "sparse"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 30))
        app.launchEnvironment.removeValue(forKey: "CECY_UI_FIXTURE")
        return app
    }
    @MainActor private func tap(_ id: String, in app: XCUIApplication) {
        let button = app.buttons[id]
        UIViewport.reveal(button, in: app)
        button.tap()
    }

    @MainActor func testPeriodSummaryIsCombinedAndPhaseRangesAreInteractive() {
        let app = launch()
        let window = app.staticTexts["predictionWindow"]
        UIViewport.reveal(window, in: app)
        XCTAssertEqual(app.staticTexts.matching(identifier: "predictionWindow").count, 1)
        XCTAssertFalse(app.staticTexts["Estimated next period start"].exists)
        XCTAssertTrue(app.otherElements["nextPeriodCard"].descendants(matching: .any)["predictionWindow"].exists)
        tap("cyclePhase_follicular", in: app)
        XCTAssertTrue(app.staticTexts["phaseDayRange"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["phaseDayRange"].label, "Estimated days 6–14")
        app.buttons["Done"].tap()
        tap("cyclePhase_ovulation", in: app)
        XCTAssertTrue(app.staticTexts["phaseDayRange"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["phaseDayRange"].label, "Estimated days 15–15")
        app.buttons["Done"].tap()
        let estimates = app.otherElements["todayEstimates"]
        UIViewport.reveal(estimates, in: app)
        XCTAssertLessThan(estimates.frame.minY, app.otherElements["upcomingCycleForecast"].frame.minY)
    }

    @MainActor func testMovedTilesAndCalendarHistoryActions() {
        let app = launch()
        XCTAssertFalse(app.otherElements["forTodayCard"].exists)
        XCTAssertFalse(app.buttons["sexualActivityHistory"].exists)
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.otherElements["forTodayCard"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.staticTexts["calendarMonth"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["todayEstimates"].exists)
        let records = app.otherElements["calendarRecordedDayCard"]
        UIViewport.reveal(records, in: app)
        XCTAssertTrue(records.descendants(matching: .any)["editSymptom_cramps"].exists)
        tap("sexualActivityHistory", in: app)
        XCTAssertTrue(app.navigationBars["Sexual activity"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        tap("addPreviousPeriods", in: app)
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
    }

    @MainActor func testExpandedSymptomCanBeSearchedSavedAndReopened() {
        let app = launch()
        tap("logSymptoms", in: app)
        let search = app.textFields["symptomSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("Night sweats")
        tap("symptomKind_nightSweats", in: app)
        app.buttons["saveSymptom"].tap()
        XCTAssertTrue(app.buttons["saveSymptom"].waitForNonExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logSymptoms"].waitForExistence(timeout: 10))
        tap("dailyLog_20260929", in: app)
        tap("editSymptom_nightSweats", in: app)
        XCTAssertTrue(app.navigationBars["Edit observation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["selectedSymptoms"].label.contains("Night sweats"))
    }

    @MainActor func testPhaseControlsRemainReachableAtLargestTextSize() {
        let app = launch(largeText: true)
        let phase = app.buttons["cyclePhase_menstrual"]
        UIViewport.reveal(phase, in: app)
        XCTAssertTrue(phase.isHittable)
        XCTAssertGreaterThanOrEqual(phase.frame.height, 44)
        XCTAssertGreaterThanOrEqual(phase.frame.minX, 0)
        XCTAssertLessThanOrEqual(phase.frame.maxX, app.frame.maxX)
        phase.tap()
        XCTAssertTrue(app.staticTexts["phaseDayRange"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].isHittable)
    }
}
