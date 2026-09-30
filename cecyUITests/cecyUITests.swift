//
//  cecyUITests.swift
//  cecyUITests
//
//  Created by Furaha Damien on 9/29/26.
//

import XCTest

final class cecyUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(history: Bool = false, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        if history { app.launchEnvironment["CECY_UI_FIXTURE"] = "history" }
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        return app
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    func testSkipLogAndRelaunch() {
        let app = launch()
        let finish = app.buttons["finishHistory"]
        XCTAssertTrue(finish.waitForExistence(timeout: 10))
        reveal(finish, in: app)
        finish.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["finishHistory"].exists)
        let log = app.buttons["logPeriod"]
        reveal(log, in: app)
        log.tap()
        app.buttons["savePeriod"].tap()
        XCTAssertTrue(app.staticTexts["cycleDay"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["cycleDay"].label, "Day 1")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["cycleDay"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["cycleDay"].label, "Day 1")
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.buttons["calendarDay_20260929"].label.contains("Recorded period start"))
    }

    @MainActor
    func testOnboardingDraftCommitsOnlyOnContinue() {
        let app = launch()
        let add = app.buttons["addHistoryDate"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        reveal(add, in: app)
        add.tap()
        app.buttons["savePeriod"].tap()
        XCTAssertTrue(app.buttons["finishHistory"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.buttons["Today"].exists)
        let finish = app.buttons["finishHistory"]
        reveal(finish, in: app)
        finish.tap()
        XCTAssertTrue(app.staticTexts["cycleDay"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["cycleDay"].label, "Day 1")
        XCTAssertFalse(app.staticTexts["predictionWindow"].exists)
    }

    @MainActor
    func testHistoryPredictionCalendarAndDuplicateProtection() {
        let app = launch(history: true)
        XCTAssertTrue(app.staticTexts["cycleDay"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["cycleDay"].label, "Day 28")
        XCTAssertTrue(app.staticTexts["predictionWindow"].label.contains("Sep 28"))
        app.tabBars.buttons["Calendar"].tap()
        let second = app.buttons["calendarDay_20260902"]
        XCTAssertTrue(second.label.contains("Recorded period start"))
        XCTAssertTrue(app.buttons["calendarDay_20260903"].label.contains("No recorded period"))
        XCTAssertTrue(app.buttons["calendarDay_20260929"].label.contains("estimate"))
        app.buttons["nextMonth"].tap()
        XCTAssertTrue(app.buttons["calendarDay_20261004"].label.contains("estimate"))
        XCTAssertFalse(app.buttons["calendarDay_20261005"].label.contains("estimate"))
        app.buttons["previousMonth"].tap()
        app.tabBars.buttons["Insights"].tap()
        XCTAssertEqual(app.staticTexts["intervalCount"].label, "3 completed intervals")
        app.tabBars.buttons["Today"].tap()
        let log = app.buttons["logPeriod"]
        reveal(log, in: app)
        log.tap()
        app.buttons["savePeriod"].tap()
        reveal(log, in: app)
        log.tap()
        XCTAssertFalse(app.buttons["savePeriod"].isEnabled)
        XCTAssertTrue(app.staticTexts["validationError"].exists)
        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testCalendarGridIdentityAcrossAllLeadingOffsets() {
        let app = launch(history: true)
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Calendar"].tap()
        // The fixture starts in September 2026. July 2026–March 2027
        // covers every leading-cell count (0...6) in the en_US calendar.
        app.buttons["previousMonth"].tap()
        app.buttons["previousMonth"].tap()
        let months = ["202607", "202608", "202609", "202610", "202611",
                      "202612", "202701", "202702", "202703"]
        for (index, month) in months.enumerated() {
            if index > 0 { app.buttons["nextMonth"].tap() }
            for day in ["01", "07"] {
                let matches = app.buttons.matching(identifier: "calendarDay_\(month)\(day)")
                let button = matches.firstMatch
                XCTAssertTrue(button.waitForExistence(timeout: 5))
                XCTAssertEqual(matches.count, 1, "Duplicate calendar date in \(month)")
                button.tap()
                XCTAssertTrue(button.isSelected)
            }
            XCTAssertFalse(app.buttons["calendarDay_\(month)01"].isSelected)
        }
        app.scrollViews.buttons["Today"].tap()
        let today = app.buttons["calendarDay_20260929"]
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        XCTAssertTrue(today.isSelected)
    }

    @MainActor
    func testLargeTextCalendarList() {
        let app = launch(history: true, largeText: true)
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Calendar"].tap()
        let recorded = app.buttons["calendarDay_20260902"]
        reveal(recorded, in: app)
        XCTAssertGreaterThanOrEqual(recorded.frame.height, 44)
        recorded.tap()
        let endDetail = app.staticTexts["End not recorded. No later bleeding days are assumed."]
        reveal(endDetail, in: app)
        XCTAssertTrue(endDetail.exists)
    }
}
