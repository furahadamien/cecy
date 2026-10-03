import XCTest

final class DeviceFeedbackRoundThreeUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "ai"
        app.launchEnvironment["CECY_UI_AI"] = "success"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15))
        return app
    }
    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        UIViewport.reveal(element, in: app)
    }
    @MainActor private func tap(_ identifier: String, app: XCUIApplication) {
        let button = app.buttons[identifier]
        if app.navigationBars.buttons[identifier].exists { button.tap(); return }
        reveal(button, app: app); button.tap()
    }

    @MainActor func testDateStripExpandsSelectsMonthAndPreservesFutureRestriction() {
        let app = launch()
        let today = app.buttons["todayDate_20260929"]
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        XCTAssertLessThan(abs(today.frame.midX - app.frame.midX), 30)
        tap("expandTodayCalendar", app: app)
        XCTAssertEqual(app.buttons["expandTodayCalendar"].value as? String, "Expanded")
        tap("todayNextMonth", app: app)
        tap("todayMonthDate_20261002", app: app)
        XCTAssertTrue(app.buttons["todayMonthDate_20261002"].isSelected)
        tap("expandTodayCalendar", app: app)
        XCTAssertTrue(app.buttons["todayDate_20261002"].isSelected)
        reveal(app.buttons["logPeriod"], app: app)
        XCTAssertFalse(app.buttons["logPeriod"].isEnabled)
        tap("stripReturnToToday", app: app)
        XCTAssertTrue(today.isSelected)
        XCTAssertTrue(today.label.contains("Cramps"))
    }

    @MainActor func testMultipleSymptomChipsGenerateWithoutRemovedControls() {
        let app = launch()
        app.tabBars.buttons["Insights"].tap()
        tap("askCecy", app: app)
        let scope = app.buttons["aiQuestionScope_symptomFrequency"]
        for _ in 0..<4 { if scope.isHittable { break }; app.scrollViews["aiQuestionScope"].swipeLeft() }
        scope.tap()
        tap("questionSymptom_cramps", app: app)
        XCTAssertEqual(app.buttons["questionSymptom_headache"].value as? String, "Selected")
        XCTAssertEqual(app.buttons["questionSymptom_cramps"].value as? String, "Selected")
        XCTAssertFalse(app.buttons["Use suggested question"].exists)
        XCTAssertFalse(app.staticTexts["Information used for this request"].exists)
        tap("reviewAIConsent", app: app)
        tap("enableAI", app: app)
        XCTAssertTrue(app.navigationBars["Optional insights"].waitForNonExistence(timeout: 5))
        tap("generateAI", app: app)
        let answer = app.staticTexts["Synthetic answer from selected facts"]
        XCTAssertTrue(answer.waitForExistence(timeout: 10))
        reveal(answer, app: app)
    }

    @MainActor func testFlowChipsSaveAndHealthGoalPersists() {
        let app = launch()
        tap("logPeriod", app: app)
        XCTAssertFalse(app.buttons["savePeriod"].isEnabled)
        tap("newPeriodEntry", app: app)
        tap("periodFlow_heavy", app: app)
        XCTAssertEqual(app.buttons["periodFlow_heavy"].value as? String, "Selected")
        XCTAssertTrue(app.buttons["savePeriod"].isEnabled)
        tap("savePeriod", app: app)
        XCTAssertTrue(app.navigationBars["Record a period"].waitForNonExistence(timeout: 5))
        let flow = app.staticTexts["Heavy flow"]
        reveal(flow, app: app)
        XCTAssertTrue(flow.exists)
        app.tabBars.buttons["Settings"].tap()
        tap("profileSettings", app: app)
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
        let goals = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Tracking goals (")).firstMatch
        reveal(goals, app: app); goals.tap()
        tap("goal_healthAndWellness", app: app)
        tap("saveProfile", app: app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15))
        reveal(app.staticTexts["Heavy flow"], app: app)
        app.tabBars.buttons["Settings"].tap()
        tap("profileSettings", app: app)
        reveal(goals, app: app); goals.tap()
        let goal = app.buttons["goal_healthAndWellness"]
        reveal(goal, app: app)
        XCTAssertEqual(goal.value as? String, "Selected")
    }
}
