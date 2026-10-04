import XCTest

final class DeviceFeedbackRoundFourUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "sparse"
        app.launchEnvironment["CECY_UI_AI"] = "success"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<10 {
            let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : app.frame.minY + 60
            let bottom = app.tabBars.firstMatch.isHittable ? app.tabBars.firstMatch.frame.minY : app.frame.maxY - 25
            if element.exists && element.isHittable && element.frame.minY >= top && element.frame.maxY <= bottom { return }
            let scroll = app.collectionViews.allElementsBoundByIndex.last(where: { $0.isHittable })
                ?? app.scrollViews.allElementsBoundByIndex.first(where: { $0.isHittable && $0.identifier != "todayDateStrip" }) ?? app
            if element.exists && element.frame.maxY > top && element.frame.minY < bottom {
                let delta = element.frame.minY < top ? top + 16 - element.frame.minY : bottom - 16 - element.frame.maxY
                let start = app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: app.frame.midX, dy: delta > 0 ? top + 24 : bottom - 24))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)),
                            withVelocity: .slow, thenHoldForDuration: 0.1)
            } else if element.exists && element.frame.minY < top { scroll.swipeDown() } else { scroll.swipeUp() }
        }
        XCTFail("Could not reveal \(element)\n\(app.debugDescription)")
    }

    @MainActor private func tap(_ identifier: String, app: XCUIApplication) {
        let element = app.buttons[identifier]
        reveal(element, app: app)
        element.tap()
    }

    @MainActor func testTodayLoggingStaysBelowDaysAndCalendarKeepsMarkers() {
        let app = launch()
        let period = app.buttons["logPeriod"]
        let symptoms = app.buttons["logSymptoms"]
        XCTAssertFalse(app.otherElements["todayQuickActions"].exists)
        let today = app.buttons["todayDate_20260929"]
        XCTAssertTrue(today.label.contains("Cramps"))
        XCTAssertTrue(today.label.contains("Estimated start window"))
        tap("expandTodayCalendar", app: app)
        let expanded = app.buttons["todayMonthDate_20260929"]
        XCTAssertTrue(expanded.waitForExistence(timeout: 3))
        XCTAssertTrue(expanded.label.contains("Cramps"))
        XCTAssertTrue(expanded.label.contains("Estimated start window"))
        XCTAssertTrue(app.buttons["todayMonthDate_20260902"].label.contains("Period start"))
        tap("todayNextMonth", app: app)
        let future = app.buttons["todayMonthDate_20261002"]
        XCTAssertTrue(future.label.contains("Estimated start window"))
        future.tap()
        tap("expandTodayCalendar", app: app)
        XCTAssertTrue(app.buttons["todayDate_20261002"].label.contains("Estimated start window"))
        XCTAssertFalse(period.isEnabled)
        XCTAssertFalse(symptoms.isEnabled)
        tap("stripReturnToToday", app: app)
        XCTAssertTrue(period.isEnabled && symptoms.isEnabled)
        reveal(period, app: app)
        XCTAssertGreaterThanOrEqual(period.frame.height, 44)
        XCTAssertGreaterThanOrEqual(period.frame.minY, app.scrollViews["todayDateStrip"].frame.maxY)
        XCTAssertLessThan(period.frame.maxY, app.staticTexts["periodCountdown"].frame.minY)
        let activity = app.buttons["logSexualActivity"]
        // Ordinary text uses a compact row; accessibility sizes are tested separately below.
        for action in [symptoms, activity] {
            XCTAssertGreaterThanOrEqual(action.frame.height, 44)
            XCTAssertGreaterThanOrEqual(action.frame.minY, app.scrollViews["todayDateStrip"].frame.maxY)
            XCTAssertLessThan(action.frame.maxY, app.staticTexts["periodCountdown"].frame.minY)
            XCTAssertTrue(action.isHittable)
        }
        XCTAssertFalse(period.frame.intersects(symptoms.frame))
        XCTAssertFalse(symptoms.frame.intersects(activity.frame))
        tap("logSymptoms", app: app)
        XCTAssertTrue(app.buttons["symptomKind_cramps"].waitForExistence(timeout: 5))
    }

    @MainActor func testOneStartShowsChartAndCanGenerateInsightsAfterConsent() {
        let app = launch()
        app.tabBars.buttons["Insights"].tap()
        let chart = app.otherElements["periodStartChart"]
        reveal(chart, app: app)
        XCTAssertTrue(chart.exists)
        let observationChart = app.otherElements["observationDaysChart"]
        reveal(observationChart, app: app)
        XCTAssertTrue(observationChart.exists)
        tap("generateRecordInsights", app: app)
        let generate = app.buttons["generateAI"]
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        XCTAssertFalse(generate.isEnabled)
        tap("reviewAIConsent", app: app)
        tap("enableAI", app: app)
        XCTAssertTrue(app.navigationBars["Optional insights"].waitForNonExistence(timeout: 5))
        tap("generateAI", app: app)
        XCTAssertTrue(app.staticTexts["Synthetic answer from selected facts"].waitForExistence(timeout: 10))
    }

    @MainActor func testLargeTextKeepsQuickActionsAndCalendarMarkersAccessible() {
        let app = launch(largeText: true)
        let period = app.buttons["logPeriod"]
        reveal(period, app: app)
        XCTAssertGreaterThanOrEqual(period.frame.height, 44)
        let symptoms = app.buttons["logSymptoms"]
        reveal(symptoms, app: app)
        XCTAssertGreaterThanOrEqual(symptoms.frame.minY, period.frame.maxY)
        tap("expandTodayCalendar", app: app)
        let today = app.buttons["todayMonthDate_20260929"]
        reveal(today, app: app)
        XCTAssertTrue(today.label.contains("Cramps"))
        XCTAssertTrue(today.label.contains("Estimated start window"))
    }
}
