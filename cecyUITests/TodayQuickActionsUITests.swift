import XCTest

final class TodayQuickActionsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(largeText: Bool = false, ai: String = "success") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "sparse"
        app.launchEnvironment["CECY_UI_AI"] = ai
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 10))
        app.launchEnvironment.removeValue(forKey: "CECY_UI_FIXTURE")
        return app
    }

    @MainActor func testLoggingIsImmediatelyBelowDaysWithoutScrollingAndCountdownIsPrimary() {
        let app = launch()
        let period = app.buttons["logPeriod"]
        let symptoms = app.buttons["logSymptoms"]
        let sex = app.buttons["logSexualActivity"]
        let strip = app.scrollViews["todayDateStrip"]
        XCTAssertFalse(app.otherElements["todayCalendarLegend"].exists)
        let nextPeriod = app.otherElements["nextPeriodCard"]
        for button in [period, symptoms, sex, app.buttons["logDailyBleeding"]] {
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertGreaterThanOrEqual(button.frame.minY, strip.frame.maxY)
            XCTAssertLessThanOrEqual(button.frame.maxY, nextPeriod.frame.minY)
            XCTAssertLessThan(button.frame.maxY, app.tabBars.firstMatch.frame.minY)
        }
        XCTAssertEqual(period.label, "Log period")
        for button in [symptoms, sex, app.buttons["logDailyBleeding"]] {
            XCTAssertGreaterThan(button.frame.minY, period.frame.maxY)
            XCTAssertEqual(button.frame.midY, symptoms.frame.midY, accuracy: 1)
        }
        XCTAssertLessThan(symptoms.frame.maxX, sex.frame.minX)
        XCTAssertLessThan(sex.frame.maxX, app.buttons["logDailyBleeding"].frame.minX)
        let countdown = app.staticTexts["periodCountdown"]
        UIViewport.reveal(countdown, in: app)
        XCTAssertEqual(countdown.label, "About 1 day")
        let cycleDay = app.staticTexts["cycleDay"]
        XCTAssertEqual(cycleDay.label, "Day 28")
        XCTAssertGreaterThanOrEqual(cycleDay.frame.minY, countdown.frame.maxY)
        XCTAssertLessThan(cycleDay.frame.height, countdown.frame.height)
    }

    @MainActor func testLoggingKeepsSelectedDayAndFutureGuards() {
        let app = launch()
        app.buttons["todayDate_20260928"].tap()
        let actions = app.otherElements["todayLogActions"]
        XCTAssertTrue(actions.label.contains("September 28"))
        for (identifier, title) in [("logPeriod", "Record a period"), ("logSymptoms", "Log symptoms"), ("logSexualActivity", "Log sex"), ("logDailyBleeding", "Daily bleeding")] {
            app.buttons[identifier].tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
            app.navigationBars.buttons["Cancel"].tap()
            XCTAssertTrue(actions.label.contains("September 28"))
        }
        app.buttons["todayDate_20260930"].tap()
        for identifier in ["logPeriod", "logSymptoms", "logSexualActivity", "logDailyBleeding"] {
            XCTAssertFalse(app.buttons[identifier].isEnabled)
        }
        app.buttons["stripReturnToToday"].tap()
        for identifier in ["logPeriod", "logSymptoms", "logSexualActivity", "logDailyBleeding"] {
            XCTAssertTrue(app.buttons[identifier].isEnabled)
        }
    }

    @MainActor func testLoggingRemainsReachableAtLargestTextSize() {
        let app = launch(largeText: true)
        let actions = app.otherElements["todayLogActions"]
        for identifier in ["logPeriod", "logSymptoms", "logSexualActivity", "logDailyBleeding"] {
            let button = app.buttons[identifier]
            UIViewport.reveal(button, in: app)
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertGreaterThanOrEqual(button.frame.minX, 0)
            XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX)
            XCTAssertEqual(button.frame.midX, actions.frame.midX, accuracy: 1)
        }
    }

    @MainActor private func enableDailyPreparation(in app: XCUIApplication) {
        app.tabBars.buttons["Insights"].tap()
        let options = app.buttons["Daily preparation"]
        UIViewport.reveal(options, in: app); options.tap()
        let review = app.buttons["Enable optional insights"]
        UIViewport.reveal(review, in: app); review.tap()
        let enable = app.buttons["enableAI"]
        UIViewport.reveal(enable, in: app); enable.tap()
        XCTAssertTrue(app.navigationBars["Optional insights"].waitForNonExistence(timeout: 5))
        let toggle = app.switches["Prepare daily insights"]
        UIViewport.reveal(toggle, in: app)
        XCTAssertEqual(toggle.value as? String, "0")
        // Manual consent alone must not start automatic processing.
        XCTAssertTrue(app.staticTexts["Calculated on this device"].exists)
        XCTAssertFalse(app.otherElements["aiOutput"].exists)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["enableDailyInsights"].firstMatch.tap()
    }

    @MainActor func testDailyInsightAppearsInInsightsAutomaticallyAndSurvivesTabChanges() {
        let app = launch()
        enableDailyPreparation(in: app)
        let card = app.otherElements["forTodayCard"]
        let answer = card.staticTexts["Synthetic answer from selected facts"]
        UIViewport.reveal(answer, in: app, searchEarlierFirst: true)
        XCTAssertTrue(answer.isHittable)
        app.tabBars.buttons["Today"].tap()
        XCTAssertFalse(app.otherElements["forTodayCard"].exists)
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(answer.exists)
        // Generated text remains ephemeral, and relaunch does not spend another daily request.
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Insights"].tap()
        let local = app.staticTexts["Calculated on this device"]
        UIViewport.reveal(local, in: app)
        XCTAssertTrue(local.isHittable)
        XCTAssertFalse(app.staticTexts["Synthetic answer from selected facts"].exists)
    }

    @MainActor func testDailyFailureKeepsLocalFactsAndManualLoggingAvailable() {
        let app = launch(ai: "unavailable")
        enableDailyPreparation(in: app)
        let local = app.staticTexts["Calculated on this device"]
        UIViewport.reveal(local, in: app, searchEarlierFirst: true)
        XCTAssertTrue(local.isHittable)
        XCTAssertTrue(app.otherElements["forTodayCard"].descendants(matching: .any)["aiError"].firstMatch.exists)
        app.tabBars.buttons["Today"].tap()
        let period = app.buttons["logPeriod"]
        UIViewport.reveal(period, in: app, searchEarlierFirst: true)
        XCTAssertTrue(period.isEnabled)
        period.tap()
        XCTAssertTrue(app.navigationBars["Record a period"].waitForExistence(timeout: 5))
    }
}
