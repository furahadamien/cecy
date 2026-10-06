import XCTest

final class ForecastCardHierarchyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "sparse"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 30))
        return app
    }

    @MainActor private func checkHierarchy(_ details: XCUIElement, app: XCUIApplication) {
        let window = details.staticTexts["forecastPeriodWindow_0"]
        UIViewport.reveal(window, in: app)
        XCTAssertTrue(window.isHittable)
        XCTAssertGreaterThanOrEqual(window.frame.minX, 0)
        XCTAssertLessThanOrEqual(window.frame.maxX, app.frame.maxX)
        let period = details.otherElements["forecastPeriodSection_0"]
        let bleeding = details.staticTexts["forecastBleedingDates_0"]
        let ovulation = details.staticTexts["forecastOvulation_0"]
        let fertile = details.staticTexts["forecastFertileWindow_0"]
        XCTAssertTrue(bleeding.exists && ovulation.exists && fertile.exists)
        XCTAssertLessThan(period.frame.maxY, bleeding.frame.minY)
        XCTAssertLessThan(bleeding.frame.minY, ovulation.frame.minY)
        XCTAssertLessThan(ovulation.frame.minY, fertile.frame.minY)
        for id in ["forecastBleedingDates_0_value", "forecastOvulation_0_value", "forecastFertileWindow_0_value"] {
            let value = details.staticTexts[id]
            UIViewport.reveal(value, in: app)
            XCTAssertTrue(value.isHittable)
            XCTAssertLessThanOrEqual(value.frame.maxX, app.frame.maxX)
        }
    }

    @MainActor func testUpcomingForecastHierarchyOnBothTabsAndExpandedProjection() {
        let app = launch()
        for tab in ["Today", "Calendar"] {
            app.tabBars.buttons[tab].tap()
            let upcoming = app.otherElements["upcomingCycleForecast"]
            checkHierarchy(upcoming.otherElements["projectedCycle_0"], app: app)
            XCTAssertTrue(upcoming.staticTexts["Remaining start window"].exists)
            let more = upcoming.buttons["nextProjectedOvulation"]
            UIViewport.reveal(more, in: app)
            XCTAssertGreaterThanOrEqual(more.frame.height, 44)
            more.tap()
            let nextWindow = upcoming.staticTexts["forecastPeriodWindow_1"]
            UIViewport.reveal(nextWindow, in: app)
            XCTAssertTrue(nextWindow.isHittable)
            XCTAssertTrue(upcoming.staticTexts["Following period start · Projection"].exists)
        }
    }

    @MainActor func testSelectedDateUsesTheSameSeparatedSections() {
        let app = launch()
        app.buttons["expandTodayCalendar"].tap()
        let date = app.buttons["todayMonthDate_20260916"]
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        date.tap()
        app.buttons["expandTodayCalendar"].tap()
        let selected = app.otherElements["projectedCycle_0"].firstMatch
        checkHierarchy(selected, app: app)
        XCTAssertTrue(selected.staticTexts["Start window"].exists)
        XCTAssertFalse(selected.staticTexts["Remaining start window"].exists)
    }
}