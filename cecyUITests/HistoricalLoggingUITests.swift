import XCTest

final class HistoricalLoggingUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(_ fixture: String = "sparse") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = fixture
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<12 {
            let bottom = app.tabBars.firstMatch.frame.minY
            if element.exists && element.isHittable && element.frame.minY > 70 && element.frame.maxY < bottom { return }
            if element.exists && element.frame.minY < 70 { app.swipeDown() } else { app.swipeUp() }
        }
        XCTFail("Could not reveal \(element)")
    }

    @MainActor func testAddingBleedingDaysKeepsOnePeriodAndPersists() {
        let app = launch()
        app.buttons["expandTodayCalendar"].tap()
        app.buttons["todayMonthDate_20260904"].tap()
        let log = app.buttons["logPeriod"]
        reveal(log, app: app); log.tap()
        XCTAssertTrue(app.navigationBars["Record a period"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["savePeriod"].isEnabled)
        app.buttons["continuePeriodEntry"].tap()
        XCTAssertTrue(app.staticTexts["confirmedBleedingDays"].label.contains("3 confirmed"))
        app.buttons["savePeriod"].tap()
        XCTAssertTrue(app.navigationBars["Record a period"].waitForNonExistence(timeout: 8))
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.buttons["calendarDay_20260903"].label.contains("Confirmed bleeding"))
        XCTAssertTrue(app.buttons["calendarDay_20260902"].label.contains("Recorded period start"))
        app.buttons["calendarDay_20260903"].tap()
        let edit = app.buttons["calendarLogPeriod"]
        reveal(edit, app: app); edit.tap()
        XCTAssertTrue(app.navigationBars["Edit period"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["confirmedBleedingDays"].label.contains("3 confirmed"))
        app.navigationBars.buttons["Cancel"].tap()
    }

    @MainActor func testShortIntervalKeepsRecordsWithoutDatedFallback() {
        let app = launch()
        app.buttons["expandTodayCalendar"].tap()
        app.buttons["todayPreviousMonth"].tap()
        app.buttons["todayMonthDate_20260828"].tap()
        let log = app.buttons["logPeriod"]
        reveal(log, app: app); log.tap()
        XCTAssertTrue(app.navigationBars["Record a period"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["savePeriod"].label, "Save period")
        XCTAssertEqual(app.switches["includeEndDate"].value as? String, "0")
        XCTAssertFalse(app.staticTexts["confirmedBleedingDays"].exists)
        app.buttons["savePeriod"].tap()
        XCTAssertTrue(app.navigationBars["Record a period"].waitForNonExistence(timeout: 8))
        let countdown = app.staticTexts["periodCountdown"]
        UIViewport.reveal(countdown, in: app)
        XCTAssertEqual(countdown.label, "Estimate unavailable")
        XCTAssertFalse(app.staticTexts["nextPeriodCenter"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.buttons["calendarDay_20260902"].label.contains("Recorded period start"))
        app.buttons["previousMonth"].tap()
        XCTAssertTrue(app.buttons["calendarDay_20260828"].label.contains("Recorded period start"))
        app.buttons["nextMonth"].tap()
        app.buttons["nextMonth"].tap()
        app.buttons["calendarDay_20261001"].tap()
        let period = app.buttons["calendarLogPeriod"]
        reveal(period, app: app)
        XCTAssertFalse(period.isEnabled)
        XCTAssertFalse(app.buttons["logSymptoms"].isEnabled)
        XCTAssertFalse(app.buttons["logSexualActivity"].isEnabled)
    }

    @MainActor func testOldLastStartKeepsPrimaryWindowSeparateFromUpcomingProjection() {
        let app = launch("oldStart")
        let center = app.staticTexts["nextPeriodCenter"]
        reveal(center, app: app)
        XCTAssertTrue(center.label.contains("Jan 29"))
        XCTAssertEqual(app.staticTexts["periodCountdown"].label, "Estimated window passed")
        XCTAssertFalse(app.staticTexts["projectedPrediction"].exists)
        app.tabBars.buttons["Calendar"].tap()
        app.buttons["nextMonth"].tap()
        XCTAssertTrue(app.buttons["calendarDay_20261008"].label.contains("Possible period start"))
        XCTAssertTrue(app.buttons["calendarDay_20261022"].label.contains("Possible ovulation"))
    }
}
