import XCTest

/// A forgotten month must still produce a forecast on Today and Calendar, without the old
/// "expected bleeding dates" row, and the card says which start was assumed.
final class MissedMonthForecastUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testForecastSurvivesAMissedMonthOnBothTabs() {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "missedMonth"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 30))

        for tab in ["Today", "Calendar"] {
            app.tabBars.buttons[tab].tap()
            let upcoming = app.otherElements["upcomingCycleForecast"]
            UIViewport.reveal(upcoming, in: app)
            XCTAssertTrue(upcoming.exists, "\(tab): forecast card missing")
            XCTAssertFalse(upcoming.staticTexts["Forecast unavailable"].exists, "\(tab): forecast unavailable")
            let window = upcoming.buttons["forecastPeriodSection_0"]
            XCTAssertTrue(window.exists, "\(tab): period start window missing")
            XCTAssertTrue(window.label.hasPrefix("Period start window"), window.label)
            XCTAssertFalse(upcoming.buttons["forecastBleedingDates_0"].exists, "\(tab): bleeding dates still shown")
            XCTAssertFalse(upcoming.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Expected bleeding dates")).firstMatch.exists)
            XCTAssertFalse(upcoming.staticTexts["Bleeding duration unavailable"].exists)
            let notice = upcoming.descendants(matching: .any)["forecastInferredNotice"].firstMatch
            UIViewport.reveal(notice, in: app)
            XCTAssertTrue(notice.exists, "\(tab): inferred-start notice missing")
            XCTAssertTrue(notice.label.contains("Sep 1"), notice.label)
        }
    }
}
