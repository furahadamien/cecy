import XCTest

final class DailyGuidanceAndContinuationUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(popup: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = popup ? "ai" : "sparse"
        app.launchEnvironment["CECY_UI_AI"] = "success"
        app.launchEnvironment["CECY_UI_DAILY_POPUP"] = popup ? "1" : "0"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    @MainActor func testPopupEnablesImmediatePreparationAndDoesNotRepeatAfterRelaunch() {
        let app = launch(popup: true)
        XCTAssertTrue(app.buttons["closeDailyInsights"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.otherElements["aiOutput"].exists)
        let consent = app.collectionViews.buttons["reviewAIConsent"].firstMatch
        UIViewport.reveal(consent, in: app); consent.tap()
        let enable = app.buttons["enableAI"]
        UIViewport.reveal(enable, in: app); enable.tap()
        XCTAssertTrue(app.navigationBars["Optional insights"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["aiOutput"].exists)
        let toggle = app.switches["dailyInsightsToggle"]
        UIViewport.reveal(toggle, in: app)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["enableDailyInsights"].firstMatch.tap()
        let guidance = app.collectionViews.staticTexts["Synthetic gentle movement"].firstMatch
        UIViewport.reveal(guidance, in: app, searchEarlierFirst: true)
        XCTAssertTrue(guidance.isHittable)
        app.buttons["closeDailyInsights"].tap()
        let today = app.otherElements["dailyInsightsCard"]
        let inline = today.staticTexts["Synthetic gentle movement"]
        UIViewport.reveal(inline, in: app)
        XCTAssertTrue(inline.exists)
        XCTAssertFalse(app.staticTexts["Get today’s insights"].exists)
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.otherElements["forTodayCard"].staticTexts["Synthetic gentle movement"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["closeDailyInsights"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Synthetic gentle movement"].exists)
    }

    @MainActor func testContinuingBleedingRecordsOnlySelectedDayWithoutEndDate() {
        let app = launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 15))
        app.buttons["logPeriod"].tap()
        let continuing = app.buttons["continuePeriodEntry"]
        UIViewport.reveal(continuing, in: app); continuing.tap()
        XCTAssertTrue(app.staticTexts["Existing period started Sep 2, 2026."].exists)
        XCTAssertTrue(app.descendants(matching: .any)["continuingBleedingDay"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["confirmedDailyBleeding"].firstMatch.exists)
        XCTAssertFalse(app.datePickers["periodStartDate"].exists)
        XCTAssertFalse(app.switches["includeEndDate"].exists)
        XCTAssertFalse(app.datePickers["periodEndDate"].exists)
        app.buttons["savePeriod"].tap()
        XCTAssertTrue(app.navigationBars["Record a period"].waitForNonExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Calendar"].tap()
        let date = app.buttons["calendarDay_20260929"].firstMatch
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        XCTAssertTrue(date.label.contains("Confirmed bleeding day"))
        XCTAssertFalse(date.label.contains("Daily answer: Bleeding"))
        let answer = app.staticTexts["dailyAnswer_20260929"].firstMatch
        UIViewport.reveal(answer, in: app)
        XCTAssertEqual(answer.label, "Period bleeding")
        XCTAssertTrue(app.staticTexts["Linked to recorded period"].exists)
    }
}
