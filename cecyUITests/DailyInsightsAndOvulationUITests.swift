import XCTest

final class DailyInsightsAndOvulationUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "sparse"
        app.launchEnvironment["CECY_UI_AI"] = "success"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<10 {
            let bottom = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : app.frame.maxY - 20
            if element.exists && element.isHittable && element.frame.maxY < bottom { return }
            app.swipeUp()
        }
        XCTFail("Element not visible: \(element)")
    }

    @MainActor func testOvulationMarkerMatchesAcrossCalendars() {
        let app = launch()
        app.buttons["expandTodayCalendar"].tap()
        let expanded = app.buttons["todayMonthDate_20260916"]
        XCTAssertTrue(expanded.waitForExistence(timeout: 5))
        XCTAssertTrue(expanded.label.contains("Possible ovulation"))
        XCTAssertTrue(app.buttons["todayMonthDate_20260929"].label.contains("Estimated start window"))
        app.tabBars.buttons["Calendar"].tap()
        let date = app.buttons["calendarDay_20260916"]
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        XCTAssertTrue(date.label.contains("Possible ovulation"))
        XCTAssertTrue(app.buttons["calendarDay_20260929"].label.contains("estimate"))
        date.tap()
        let details = app.otherElements["selectedCalendarDetails"]
        let detail = details.staticTexts["Possible ovulation · Estimate"].firstMatch
        UIViewport.reveal(detail, in: app)
        XCTAssertTrue(detail.isHittable)
        let uncertainty = details.buttons["ovulationUncertainty_0"]
        UIViewport.reveal(uncertainty, in: app)
        uncertainty.tap()
        let caution = details.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "No dates are identified as safe days.")).firstMatch
        UIViewport.reveal(caution, in: app)
        XCTAssertTrue(caution.isHittable)
    }

    @MainActor func testBleedingAndFertileWindowsRemainDistinctAcrossCalendars() {
        let app = launch()
        app.buttons["expandTodayCalendar"].tap()
        let fertile = app.buttons["todayMonthDate_20260911"]
        XCTAssertTrue(fertile.waitForExistence(timeout: 5))
        XCTAssertTrue((fertile.value as? String ?? "").contains("Estimated fertile window"))
        XCTAssertFalse(fertile.label.contains("Possible ovulation"))
        XCTAssertFalse((app.buttons["todayMonthDate_20260910"].value as? String ?? "").contains("Estimated fertile window"))
        app.buttons["todayNextMonth"].tap()
        let bleeding = app.buttons["todayMonthDate_20261004"]
        XCTAssertTrue(bleeding.waitForExistence(timeout: 5))
        XCTAssertTrue((bleeding.value as? String ?? "").contains("Expected bleeding day"))
        XCTAssertFalse((app.buttons["todayMonthDate_20261005"].value as? String ?? "").contains("Expected bleeding day"))
        bleeding.tap()
        app.buttons["expandTodayCalendar"].tap()
        XCTAssertTrue((app.buttons["todayDate_20261004"].value as? String ?? "").contains("Expected bleeding day"))
        app.tabBars.buttons["Calendar"].tap()
        let fertileDate = app.buttons["calendarDay_20260911"]
        XCTAssertTrue(fertileDate.waitForExistence(timeout: 5))
        XCTAssertTrue(fertileDate.label.contains("Estimated fertile window"))
        fertileDate.tap()
        let detail = app.staticTexts["forecastFertileWindow_0"].firstMatch
        reveal(detail, app: app)
        XCTAssertTrue(detail.isHittable)
    }

    @MainActor func testFuturePeriodAndOvulationProjectionsAppearTogether() {
        let app = launch()
        app.buttons["expandTodayCalendar"].tap()
        app.buttons["todayNextMonth"].tap()
        let ovulation = app.buttons["todayMonthDate_20261014"]
        XCTAssertTrue(ovulation.waitForExistence(timeout: 5))
        XCTAssertTrue(ovulation.label.contains("Possible ovulation"))
        XCTAssertTrue(ovulation.label.contains("Future-cycle projection"))
        for key in ["20261013", "20261015"] {
            XCTAssertFalse(app.buttons["todayMonthDate_\(key)"].label.contains("Possible ovulation"))
        }
        XCTAssertTrue(app.buttons["todayMonthDate_20261028"].label.contains("Estimated start window"))
        ovulation.tap()
        app.buttons["expandTodayCalendar"].tap()
        let strip = app.buttons["todayDate_20261014"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5))
        XCTAssertTrue(strip.label.contains("Possible ovulation"))
        for key in ["20261013", "20261015"] {
            XCTAssertFalse(app.buttons["todayDate_\(key)"].label.contains("Possible ovulation"))
        }
        app.tabBars.buttons["Calendar"].tap()
        app.buttons["nextMonth"].tap()
        let future = app.buttons["calendarDay_20261014"]
        XCTAssertTrue(future.waitForExistence(timeout: 5))
        XCTAssertTrue(future.label.contains("Possible ovulation"))
        XCTAssertTrue(future.label.contains("Future-cycle projection"))
        for key in ["20261013", "20261015"] {
            XCTAssertFalse(app.buttons["calendarDay_\(key)"].label.contains("Possible ovulation"))
        }
        XCTAssertTrue(app.buttons["calendarDay_20261028"].label.contains("estimate"))
        future.tap()
        let period = app.buttons["calendarLogPeriod"]
        reveal(period, app: app)
        XCTAssertFalse(period.isEnabled)
        XCTAssertFalse(app.buttons["logSymptoms"].isEnabled)
        XCTAssertFalse(app.buttons["logSexualActivity"].isEnabled)
    }

    @MainActor func testCycleContextShowsSpecificCautionWithoutHidingDate() {
        let app = launch()
        app.tabBars.buttons["Settings"].tap()
        app.buttons["profileSettings"].tap()
        let context = app.buttons["Cycle context (0)"]
        reveal(context, app: app); context.tap()
        let breastfeeding = app.buttons["cycleContext_breastfeeding"]
        reveal(breastfeeding, app: app); breastfeeding.tap()
        app.navigationBars.buttons["saveProfile"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForNonExistence(timeout: 5))
        app.tabBars.buttons["Calendar"].tap()
        app.buttons["nextMonth"].tap()
        let day = app.buttons["calendarDay_20261014"]
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        XCTAssertTrue(day.label.contains("Possible ovulation"))
        XCTAssertTrue(day.label.contains("Timing may not apply"))
        day.tap()
        let caution = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Breastfeeding:")).firstMatch
        reveal(caution, app: app)
        XCTAssertTrue(caution.label.contains("can still occur"))
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "estimates are hidden")).firstMatch.exists)
    }

    @MainActor func testLocalAnswersAndConsentedDailyPreparation() {
        let app = launch()
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.otherElements["forTodayCard"].waitForExistence(timeout: 5))
        let ask = app.buttons["askCecy"]
        reveal(ask, app: app); ask.tap()
        let answer = app.buttons["preparedAnswer_lengths"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        answer.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "no completed start-to-start interval")).firstMatch.exists)
        XCTAssertFalse(app.otherElements["aiOutput"].exists)
        app.tabBars.buttons["Settings"].tap()
        app.buttons["privacySettings"].tap()
        app.buttons["reviewAIConsent"].tap()
        let enable = app.buttons["enableAI"]
        reveal(enable, app: app); enable.tap()
        XCTAssertTrue(app.navigationBars["Optional insights"].waitForNonExistence(timeout: 5))
        let toggle = app.switches["dailyInsightsToggle"]
        reveal(toggle, app: app)
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["enableDailyInsights"].firstMatch.tap()
        app.tabBars.buttons["Insights"].tap()
        app.navigationBars.buttons.firstMatch.tap() // Return from Ask to the root Insights page.
        for _ in 0..<6 { app.swipeDown() }
        XCTAssertTrue(app.staticTexts["Synthetic answer from selected facts"].waitForExistence(timeout: 10), app.debugDescription)
    }
}
