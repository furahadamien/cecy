import XCTest

/// Today follow-up pop-up and the dynamic cards between Today's insights and the forecast.
final class TodayEngagementUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(id: String = UUID().uuidString, followUps: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = id
        app.launchEnvironment["CECY_UI_FIXTURE"] = "followUps"
        app.launchEnvironment["CECY_UI_AI"] = "success"
        if followUps { app.launchEnvironment["CECY_UI_FOLLOW_UPS"] = "1" }
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    @MainActor func testUnusualCycleQuestionSavesAFactorAndDoesNotReturn() {
        let id = UUID().uuidString
        let launchedAt = Date()
        let app = launch(id: id)

        // The question appears on its own after Today settles, never sooner than 3 seconds after launch.
        let title = app.staticTexts["followUpTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 12))
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(launchedAt), 3)
        XCTAssertEqual(title.label, "Your last cycle was longer than usual")
        XCTAssertTrue(app.buttons["followUpNotNow"].exists)

        // "Why am I seeing this?" explains which records triggered it.
        let why = app.buttons["followUpWhy"].exists ? app.buttons["followUpWhy"] : app.otherElements["followUpWhy"]
        why.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'no cycle factor covers'")).firstMatch
            .waitForExistence(timeout: 3))

        // Choosing a factor reveals Save; saving confirms and closes the pop-up.
        app.buttons["followUpFactor.travel"].tap()
        let save = app.buttons["followUpSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()
        XCTAssertTrue(app.descendants(matching: .any)["followUpSaved"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(title.waitForNonExistence(timeout: 5))

        // The answer is a real record: it shows in Settings → Cycle factors.
        app.tabBars.buttons["Settings"].tap()
        let factors = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Cycle factors'")).firstMatch
        UIViewport.reveal(factors, in: app)
        factors.tap()
        XCTAssertTrue(app.staticTexts["Travel"].waitForExistence(timeout: 5))

        // Relaunching the same day never asks again.
        app.terminate()
        let again = launch(id: id)
        XCTAssertTrue(again.buttons["logPeriod"].waitForExistence(timeout: 10))
        XCTAssertFalse(again.staticTexts["followUpTitle"].waitForExistence(timeout: 7))
    }

    @MainActor func testNotNowClosesWithoutSavingAndTheDailyLimitHolds() {
        let id = UUID().uuidString
        let app = launch(id: id)
        XCTAssertTrue(app.staticTexts["followUpTitle"].waitForExistence(timeout: 10))
        app.buttons["followUpNotNow"].tap()
        XCTAssertTrue(app.staticTexts["followUpTitle"].waitForNonExistence(timeout: 5))

        app.terminate()
        let again = launch(id: id)
        XCTAssertTrue(again.buttons["logPeriod"].waitForExistence(timeout: 10))
        XCTAssertFalse(again.staticTexts["followUpTitle"].waitForExistence(timeout: 7))
    }

    @MainActor func testDynamicCardsSitBetweenInsightsAndForecast() {
        let app = launch(followUps: false)
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["followUpTitle"].waitForExistence(timeout: 6))

        let highlight = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'todayHighlight.'")).firstMatch
        UIViewport.reveal(highlight, in: app)
        XCTAssertTrue(highlight.exists)
        let insights = app.otherElements["dailyInsightsCard"]
        let forecast = app.descendants(matching: .any)["upcomingCycleForecast"].firstMatch
        UIViewport.reveal(forecast, in: app)
        XCTAssertTrue(insights.exists && forecast.exists)
        XCTAssertGreaterThan(highlight.frame.minY, insights.frame.minY)
        XCTAssertLessThan(highlight.frame.minY, forecast.frame.minY)
    }
}
