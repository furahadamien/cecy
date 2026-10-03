import XCTest

final class LaunchReadinessUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "sparse"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Calendar"].tap()
        return app
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : app.frame.minY + 60
            let bottom = app.tabBars.firstMatch.isHittable ? app.tabBars.firstMatch.frame.minY : app.frame.maxY - 25
            if element.exists && element.isHittable && element.frame.minY >= top && element.frame.maxY <= bottom { return }
            let scroll = app.scrollViews.firstMatch
            if element.exists && element.frame.maxY > top && element.frame.minY < bottom {
                let delta = element.frame.minY < top ? top + 16 - element.frame.minY : bottom - 16 - element.frame.maxY
                let start = app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: app.frame.midX, dy: delta > 0 ? top + 24 : bottom - 24))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)),
                            withVelocity: .slow, thenHoldForDuration: 0.1)
            } else if element.exists && element.frame.minY < top { scroll.swipeDown() } else { scroll.swipeUp() }
        }
        XCTFail("Could not reveal \(element.identifier): \(element.frame)\n\(app.debugDescription)")
    }

    @MainActor func testEarlyMonthLargeTextLoggingPrecedesNextDateAndPreservesSelection() {
        let app = launch()
        let selected = app.buttons["calendarDay_20260901"]
        reveal(selected, in: app)
        selected.tap()
        let period = app.buttons["calendarLogPeriod"]
        let nextDay = app.buttons["calendarDay_20260902"]
        XCTAssertTrue(period.waitForExistence(timeout: 5))
        XCTAssertTrue(nextDay.exists)
        // Source order and rendered placement must not require traversing the rest of the month.
        XCTAssertGreaterThan(period.frame.height, 0)
        XCTAssertLessThanOrEqual(period.frame.maxY, nextDay.frame.minY)
        XCTAssertEqual(app.buttons.matching(identifier: "calendarLogPeriod").count, 1)
        reveal(period, in: app)
        XCTAssertTrue(period.isEnabled)
        XCTAssertGreaterThanOrEqual(period.frame.height, 44)
        period.tap()
        XCTAssertTrue(app.navigationBars["Record a period"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(selected.isSelected)
        XCTAssertTrue(selected.label.contains("No recorded period"))
        let symptoms = app.buttons["logSymptoms"]
        reveal(symptoms, in: app)
        symptoms.tap()
        XCTAssertTrue(app.navigationBars["Log symptoms"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(selected.isSelected)
    }

    @MainActor func testFutureLargeTextLoggingIsContextualAndDisabled() {
        let app = launch()
        let nextMonth = app.buttons["nextMonth"]
        reveal(nextMonth, in: app)
        nextMonth.tap()
        let selected = app.buttons["calendarDay_20261029"]
        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        XCTAssertTrue(selected.isSelected)
        let nextDay = app.buttons["calendarDay_20261030"]
        for identifier in ["calendarLogPeriod", "logSymptoms", "logSexualActivity"] {
            let button = app.buttons[identifier]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            XCTAssertFalse(button.isEnabled)
            XCTAssertGreaterThan(button.frame.height, 0)
            XCTAssertLessThanOrEqual(button.frame.maxY, nextDay.frame.minY)
        }
    }
}
