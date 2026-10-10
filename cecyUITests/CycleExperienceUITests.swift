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
        let insights = app.otherElements["dailyInsightsCard"]
        UIViewport.reveal(insights, in: app)
        XCTAssertFalse(app.otherElements["todayEstimates"].exists)
        XCTAssertLessThan(insights.frame.minY, app.otherElements["upcomingCycleForecast"].frame.minY)
    }

    @MainActor func testRingSegmentStillOpensExistingPhaseDetails() {
        let app = launch()
        let ring = app.descendants(matching: .any)["phaseRingSummary"].firstMatch
        UIViewport.reveal(ring, in: app)
        // Right-hand arc is day 8 of the fixture's 28-day cycle: follicular.
        let radius = min(ring.frame.width, ring.frame.height) * 0.4
        ring.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: ring.frame.width / 2 + radius, dy: ring.frame.height / 2)).tap()
        XCTAssertTrue(app.staticTexts["phaseDayRange"].waitForExistence(timeout: 5), "Ring frame: \(ring.frame)\n\(app.debugDescription)")
        XCTAssertEqual(app.staticTexts["phaseDayRange"].label, "Estimated days 6–14")
        XCTAssertTrue(app.staticTexts["phaseExplanation"].exists)
        app.buttons["Done"].tap()
        tap("cyclePhase_follicular", in: app)
        XCTAssertTrue(app.staticTexts["phaseDayRange"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["phaseDayRange"].label, "Estimated days 6–14")
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
        XCTAssertTrue(records.descendants(matching: .any)["editDaySymptoms"].exists)
        tap("sexualActivityHistory", in: app)
        XCTAssertTrue(app.staticTexts["Sexual activity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No sexual activity recorded yet."].exists)
        app.navigationBars.buttons.firstMatch.tap()
        tap("addPreviousPeriods", in: app)
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
    }

    @MainActor func testCalendarSymptomsShareActionsAndDeleteAfterConfirmation() {
        let app = launch()
        tap("logSymptoms", in: app)
        XCTAssertTrue(app.navigationBars["Log symptoms"].waitForExistence(timeout: 10))
        // This test covers grouped editing/deletion; search has separate coverage.
        tap("symptomKind_headache", in: app)
        app.buttons["saveSymptom"].tap()
        XCTAssertTrue(app.buttons["saveSymptom"].waitForNonExistence(timeout: 10))
        app.tabBars.buttons["Calendar"].tap()
        tap("editDaySymptoms", in: app)
        XCTAssertTrue(app.buttons["chooseDaySymptom_cramps"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["chooseDaySymptom_headache"].exists)
        app.buttons["chooseDaySymptom_cramps"].tap()
        XCTAssertTrue(app.navigationBars["Edit observation"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Edit observation"].waitForNonExistence(timeout: 5))
        app.buttons["Done"].tap()
        tap("deleteDaySymptoms", in: app)
        app.alerts.buttons["Keep symptoms"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "editDaySymptoms").count, 1)
        XCTAssertFalse(app.buttons["editSymptom_cramps"].exists)
        XCTAssertFalse(app.buttons["deleteSymptom_headache"].exists)
        tap("deleteDaySymptoms", in: app)
        app.alerts.buttons["Delete all symptoms"].tap()
        XCTAssertTrue(app.buttons["editDaySymptoms"].waitForNonExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Calendar"].tap()
        UIViewport.reveal(app.buttons["sexualActivityHistory"], in: app)
        XCTAssertFalse(app.buttons["editDaySymptoms"].exists)
    }

    @MainActor func testCalendarSymptomActionsFitLargestText() {
        let app = launch(largeText: true)
        app.tabBars.buttons["Calendar"].tap()
        // The full month and forecast explanations precede the records card.
        // Fast-scroll near the footer before the precise viewport checks.
        for _ in 0..<12 {
            if app.buttons["editDaySymptoms"].isHittable { break }
            app.swipeUp(velocity: .fast)
        }
        for id in ["editDaySymptoms", "deleteDaySymptoms"] {
            let button = app.buttons[id]
            UIViewport.reveal(button, in: app)
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertGreaterThanOrEqual(button.frame.minX, 0)
            XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX)
        }
        app.buttons["deleteDaySymptoms"].tap()
        app.alerts.buttons["Keep symptoms"].tap()
        tap("editDaySymptoms", in: app)
        XCTAssertTrue(app.buttons["chooseDaySymptom_cramps"].waitForExistence(timeout: 5))
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
        tap("editDaySymptoms", in: app)
        tap("chooseDaySymptom_nightSweats", in: app)
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
