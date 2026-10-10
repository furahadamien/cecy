import XCTest

final class TodayQuickActionsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(largeText: Bool = false, ai: String = "success", fixture: String = "sparse") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = fixture
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

    @MainActor private func logPeriodForSelectedDay(in app: XCUIApplication) {
        let log = app.buttons["logPeriod"]
        UIViewport.reveal(log, in: app)
        log.tap()
        XCTAssertTrue(app.navigationBars["Record a period"].waitForExistence(timeout: 5))
        let newPeriod = app.buttons["newPeriodEntry"]
        // Every sparse fixture has an earlier period; the choice can be below
        // the initial viewport when the explanatory text uses its largest size.
        UIViewport.reveal(newPeriod, in: app)
        newPeriod.tap()
        UIViewport.reveal(app.switches["includeEndDate"], in: app)
        XCTAssertEqual(app.switches["includeEndDate"].value as? String, "0")
        XCTAssertTrue(app.buttons["savePeriod"].isEnabled)
        app.buttons["savePeriod"].tap()
        XCTAssertTrue(app.navigationBars["Record a period"].waitForNonExistence(timeout: 10))
    }

    @MainActor private func assertCurrentPeriodStatus(in app: XCUIApplication, estimated: Bool) {
        let status = app.descendants(matching: .any)["currentPeriodStatus"].firstMatch
        UIViewport.reveal(status, in: app)
        XCTAssertEqual(status.label, estimated ? "You may be on your period" : "You’re on your period")
        // The combined accessibility frame follows the droplet's glyph bounds,
        // which differs by up to 2.5 points at the largest Dynamic Type size.
        XCTAssertEqual(status.frame.midX, app.frame.midX, accuracy: 3)
        XCTAssertGreaterThanOrEqual(status.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(status.frame.maxX, app.frame.maxX)
        XCTAssertFalse(app.otherElements["currentPeriodCard"].exists)
        XCTAssertFalse(app.staticTexts["Estimated · Not recorded"].exists)
        XCTAssertFalse(app.staticTexts["Recorded today"].exists)
        let hero = app.otherElements["nextPeriodCard"]
        XCTAssertGreaterThan(status.frame.minY, hero.frame.minY)
        XCTAssertLessThanOrEqual(status.frame.maxY, hero.frame.maxY)
        XCTAssertFalse(app.otherElements["todayEstimates"].exists)
        XCTAssertTrue(app.otherElements["dailyInsightsCard"].exists)
    }

    @MainActor func testRecordedCurrentPeriodStatusAppearsAboveCountdownAndSurvivesRelaunch() {
        let app = launch()
        XCTAssertFalse(app.descendants(matching: .any)["currentPeriodStatus"].firstMatch.exists)
        logPeriodForSelectedDay(in: app)
        assertCurrentPeriodStatus(in: app, estimated: false)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 10))
        assertCurrentPeriodStatus(in: app, estimated: false)
    }

    @MainActor func testCurrentPeriodStatusRemainsCenteredAtLargestTextSize() {
        let app = launch(largeText: true)
        logPeriodForSelectedDay(in: app)
        assertCurrentPeriodStatus(in: app, estimated: false)
    }

    @MainActor func testEstimatedCurrentPeriodStatusUsesTodayNotSelectedDate() {
        let app = launch()
        app.buttons["todayDate_20260928"].tap()
        logPeriodForSelectedDay(in: app)
        // Yesterday is recorded; today's remaining period day is only estimated.
        assertCurrentPeriodStatus(in: app, estimated: true)
        let today = app.buttons["stripReturnToToday"]
        if !today.isHittable { UIViewport.reveal(today, in: app) }
        today.tap()
        assertCurrentPeriodStatus(in: app, estimated: true)
    }

    @MainActor func testHeroPrecedesOneRowOfLoggingActionsAndPhaseTiles() {
        let app = launch()
        assertPhasesFitInitialViewport(in: app)
        let period = app.buttons["logPeriod"]
        let symptoms = app.buttons["logSymptoms"]
        let sex = app.buttons["logSexualActivity"]
        let strip = app.scrollViews["todayDateStrip"]
        XCTAssertFalse(app.otherElements["todayCalendarLegend"].exists)
        let nextPeriod = app.otherElements["nextPeriodCard"]
        let ring = app.descendants(matching: .any)["phaseRingSummary"].firstMatch
        XCTAssertTrue(ring.exists)
        XCTAssertLessThanOrEqual(ring.frame.maxX, app.staticTexts["periodCountdown"].frame.minX)
        XCTAssertGreaterThanOrEqual(nextPeriod.frame.minY, strip.frame.maxY)
        UIViewport.reveal(period, in: app)
        for button in [period, symptoms, sex, app.buttons["logDailyBleeding"]] {
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertGreaterThanOrEqual(button.frame.minY, strip.frame.maxY)
            XCTAssertGreaterThanOrEqual(button.frame.minY, nextPeriod.frame.maxY)
            XCTAssertLessThan(button.frame.maxY, app.tabBars.firstMatch.frame.minY)
        }
        XCTAssertEqual(period.label, "Log period")
        for button in [symptoms, sex, app.buttons["logDailyBleeding"]] {
            XCTAssertEqual(button.frame.minY, period.frame.minY, accuracy: 1)
        }
        XCTAssertLessThan(symptoms.frame.maxX, sex.frame.minX)
        XCTAssertLessThan(sex.frame.maxX, app.buttons["logDailyBleeding"].frame.minX)
        let countdown = app.staticTexts["periodCountdown"]
        UIViewport.reveal(countdown, in: app)
        XCTAssertEqual(countdown.label, "About 1 day")
        XCTAssertTrue((ring.value as? String ?? "").contains("day 28"))
    }

    @MainActor private func assertPhasesFitInitialViewport(in app: XCUIApplication) {
        let cards = ["menstrual", "follicular", "ovulation", "luteal"].map { app.buttons["cyclePhase_\($0)"] }
        let bottom = app.tabBars.firstMatch.frame.minY
        let actions = app.otherElements["todayLogActions"]
        for card in cards {
            XCTAssertTrue(card.exists && card.isHittable, app.debugDescription)
            XCTAssertGreaterThanOrEqual(card.frame.minY, actions.frame.maxY)
            XCTAssertLessThanOrEqual(card.frame.maxY, bottom, app.debugDescription)
            XCTAssertEqual(card.frame.height, cards[0].frame.height, accuracy: 1)
            XCTAssertEqual(card.frame.minY, cards[0].frame.minY, accuracy: 1)
        }
    }

    @MainActor func testPhasesFitInitialViewportDuringRecordedPeriod() {
        let app = launch()
        logPeriodForSelectedDay(in: app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 10))
        // No reveal or swipe: the status row must leave space for every phase.
        assertPhasesFitInitialViewport(in: app)
        app.buttons["cyclePhase_menstrual"].tap()
        XCTAssertTrue(app.staticTexts["phaseDayRange"].waitForExistence(timeout: 5))
    }

    @MainActor func testLoggingKeepsSelectedDayAndFutureGuards() {
        let app = launch()
        app.buttons["todayDate_20260928"].tap()
        let actions = app.otherElements["todayLogActions"]
        XCTAssertTrue(actions.label.contains("September 28"))
        for (identifier, title) in [("logPeriod", "Record a period"), ("logSymptoms", "Log symptoms"), ("logSexualActivity", "Log sex"), ("logDailyBleeding", "Daily bleeding")] {
            UIViewport.reveal(app.buttons[identifier], in: app)
            app.buttons[identifier].tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
            app.navigationBars.buttons["Cancel"].tap()
            XCTAssertTrue(actions.label.contains("September 28"))
        }
        UIViewport.reveal(app.buttons["todayDate_20260930"], in: app, searchEarlierFirst: true)
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
        let options = app.buttons["dailyWellnessAI"]
        UIViewport.reveal(options, in: app); options.tap()
        XCTAssertTrue(app.navigationBars["Today’s insights"].waitForExistence(timeout: 5))
        let review = app.buttons["reviewAIConsent"]
        for _ in 0..<2 {
            UIViewport.reveal(review, in: app); review.tap()
            if app.navigationBars["Optional insights"].waitForExistence(timeout: 3) { break }
        }
        XCTAssertTrue(app.navigationBars["Optional insights"].exists)
        let enable = app.buttons["enableAI"]
        UIViewport.reveal(enable, in: app); enable.tap()
        XCTAssertTrue(app.navigationBars["Optional insights"].waitForNonExistence(timeout: 5))
        let toggle = app.switches["dailyInsightsToggle"]
        UIViewport.reveal(toggle, in: app)
        XCTAssertEqual(toggle.value as? String, "0")
        // Manual consent alone must not start automatic processing.
        XCTAssertFalse(app.otherElements["aiOutput"].exists)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["enableDailyInsights"].firstMatch.tap()
    }

    @MainActor func testDailyInsightAppearsInInsightsAutomaticallyAndSurvivesTabChanges() {
        let app = launch(fixture: "ai")
        enableDailyPreparation(in: app)
        let generated = app.staticTexts["Synthetic gentle movement"]
        UIViewport.reveal(generated, in: app, searchEarlierFirst: true)
        XCTAssertTrue(generated.isHittable)
        app.navigationBars.buttons.firstMatch.tap()
        let card = app.otherElements["forTodayCard"]
        let answer = card.staticTexts["Synthetic gentle movement"]
        UIViewport.reveal(answer, in: app, searchEarlierFirst: true)
        XCTAssertTrue(answer.isHittable)
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.otherElements["dailyInsightsCard"].staticTexts["Synthetic gentle movement"].exists)
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(answer.exists)
        // Generated text remains ephemeral, and relaunch does not spend another daily request.
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 10))
        for _ in 0..<2 {
            app.tabBars.buttons["Insights"].tap()
            if card.waitForExistence(timeout: 5) { break }
        }
        XCTAssertTrue(card.exists)
        XCTAssertFalse(app.staticTexts["Synthetic gentle movement"].exists)
        XCTAssertTrue(app.buttons["dailyWellnessAI"].exists)
    }

    @MainActor func testDailyFailureKeepsManualLoggingAvailable() {
        let app = launch(ai: "unavailable", fixture: "ai")
        enableDailyPreparation(in: app)
        let error = app.descendants(matching: .any)["aiError"].firstMatch
        UIViewport.reveal(error, in: app)
        XCTAssertTrue(error.isHittable)
        app.tabBars.buttons["Today"].tap()
        let period = app.buttons["logPeriod"]
        UIViewport.reveal(period, in: app, searchEarlierFirst: true)
        XCTAssertTrue(period.isEnabled)
        period.tap()
        XCTAssertTrue(app.navigationBars["Record a period"].waitForExistence(timeout: 5))
    }
}
