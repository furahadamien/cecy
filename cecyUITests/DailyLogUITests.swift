import XCTest

final class DailyLogUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(largeText: Bool = false, fixture: String = "sparse") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = fixture
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName",
            largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(app.buttons["logSymptoms"].waitForExistence(timeout: 30), app.debugDescription)
        app.launchEnvironment.removeValue(forKey: "CECY_UI_FIXTURE")
        return app
    }

    @MainActor private func tap(_ id: String, in app: XCUIApplication) {
        let element = app.buttons[id]
        UIViewport.reveal(element, in: app)
        element.tap()
    }

    @MainActor func testDayRowsGroupSymbolsAndDeletionDoesNotTouchAnotherDay() {
        let app = launch()
        tap("logSexualActivity", in: app)
        tap("sexualActivityKind_other", in: app)
        app.buttons["saveSexualActivity"].tap()
        XCTAssertTrue(app.buttons["saveSexualActivity"].waitForNonExistence(timeout: 10))
        tap("todayDate_20260928", in: app)
        tap("logSymptoms", in: app)
        tap("symptomKind_cramps", in: app)
        app.buttons["saveSymptom"].tap()
        XCTAssertTrue(app.buttons["saveSymptom"].waitForNonExistence(timeout: 10))

        tap("dailyLogHistory", in: app)
        let today = app.buttons["dailyLog_20260929"]
        UIViewport.reveal(today, in: app)
        XCTAssertTrue(today.label.contains("Cramps"))
        XCTAssertTrue(today.label.contains("Sexual activity"))
        XCTAssertEqual(app.buttons.matching(identifier: "dailyLog_20260929").count, 1)
        XCTAssertFalse(app.buttons["dailyLog_20260930"].exists)
        today.tap()
        XCTAssertTrue(app.staticTexts["September 29, 2026"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "editSymptom_cramps").count, 1)
        XCTAssertFalse(app.buttons["editPeriod"].exists)
        tap("editSymptom_cramps", in: app)
        XCTAssertTrue(app.navigationBars["Edit observation"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Edit observation"].waitForNonExistence(timeout: 5))
        tap("deleteSymptom_cramps", in: app)
        app.buttons["Keep observation"].tap()
        XCTAssertTrue(app.buttons["editSymptom_cramps"].exists)
        tap("deleteSymptom_cramps", in: app)
        app.buttons["Delete recorded observation"].tap()
        XCTAssertTrue(app.buttons["editSymptom_cramps"].waitForNonExistence(timeout: 10))
        tap("editSexualActivity_20260929", in: app)
        XCTAssertTrue(app.buttons["sexualActivityKind_other"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sexualActivityKind_other"].isSelected)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["sexualActivityKind_other"].waitForNonExistence(timeout: 5))
        tap("deleteSexualActivity_20260929", in: app)
        app.buttons["Delete activity record"].tap()
        XCTAssertTrue(app.staticTexts["emptyDailyLogs"].waitForExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logSymptoms"].waitForExistence(timeout: 10))
        tap("dailyLogHistory", in: app)
        tap("dailyLog_20260928", in: app)
        XCTAssertTrue(app.buttons["editSymptom_cramps"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["editSexualActivity_20260929"].exists)
        XCTAssertFalse(app.buttons["editPeriod"].exists)
    }

    @MainActor func testOlderAndNewerPagesKeepDaysReachable() {
        let app = launch(fixture: "ai")
        tap("dailyLogHistory", in: app)
        tap("olderLoggedDays", in: app)
        let olderDay = app.buttons["dailyLog_20260508"]
        UIViewport.reveal(olderDay, in: app)
        XCTAssertTrue(olderDay.label.contains("Headache"))
        tap("newerLoggedDays", in: app)
        tap("dailyLog_20260929", in: app)
        XCTAssertTrue(app.buttons["editSymptom_cramps"].waitForExistence(timeout: 5))
    }

    @MainActor func testDailyRowsRemainReachableAtLargestTextSize() {
        let app = launch(largeText: true)
        tap("dailyLogHistory", in: app)
        let row = app.buttons["dailyLog_20260929"]
        UIViewport.reveal(row, in: app)
        XCTAssertTrue(row.isHittable)
        XCTAssertGreaterThanOrEqual(row.frame.height, 44)
        XCTAssertGreaterThanOrEqual(row.frame.minX, 0)
        XCTAssertLessThanOrEqual(row.frame.maxX, app.frame.maxX)
        row.tap()
        tap("editSymptom_cramps", in: app)
        XCTAssertTrue(app.navigationBars["Edit observation"].waitForExistence(timeout: 5))
    }

    @MainActor func testTodaySharesCalendarEditorAndRefreshesAfterSaving() {
        let app = launch()
        tap("logSexualActivity", in: app)
        tap("sexualActivityKind_other", in: app)
        app.buttons["saveSexualActivity"].tap()
        XCTAssertTrue(app.buttons["saveSexualActivity"].waitForNonExistence(timeout: 10))

        let card = app.otherElements["todayRecordedDayCard"]
        UIViewport.reveal(card, in: app)
        XCTAssertTrue(card.descendants(matching: .any)["calendarSymptom_cramps"].exists)
        XCTAssertTrue(card.buttons["editSexualActivity_20260929"].exists)
        XCTAssertFalse(app.buttons["editSymptom_cramps"].exists)
        tap("editDaySymptoms", in: app)
        XCTAssertTrue(app.navigationBars["Edit symptoms"].waitForExistence(timeout: 5))
        tap("chooseDaySymptom_cramps", in: app)
        XCTAssertTrue(app.navigationBars["Edit observation"].waitForExistence(timeout: 5))
        let search = app.textFields["symptomSearch"]
        search.tap(); search.typeText("Headache")
        tap("symptomKind_headache", in: app)
        app.buttons["saveSymptom"].tap()
        XCTAssertTrue(app.navigationBars["Edit observation"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["chooseDaySymptom_headache"].exists)
        XCTAssertFalse(app.buttons["chooseDaySymptom_cramps"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(card.descendants(matching: .any)["calendarSymptom_headache"].waitForExistence(timeout: 5))
        XCTAssertFalse(card.descendants(matching: .any)["calendarSymptom_cramps"].exists)

        app.tabBars.buttons["Calendar"].tap()
        tap("editDaySymptoms", in: app)
        XCTAssertTrue(app.navigationBars["Edit symptoms"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["chooseDaySymptom_headache"].exists)
        app.buttons["Done"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logSymptoms"].waitForExistence(timeout: 10))
        tap("editDaySymptoms", in: app)
        XCTAssertTrue(app.buttons["chooseDaySymptom_headache"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["chooseDaySymptom_cramps"].exists)
    }

    @MainActor func testSelectedDayGroupDeletionPreservesTodayAndActivity() {
        let app = launch()
        tap("todayDate_20260928", in: app)
        tap("logSymptoms", in: app)
        tap("symptomKind_headache", in: app)
        app.buttons["saveSymptom"].tap()
        XCTAssertTrue(app.buttons["saveSymptom"].waitForNonExistence(timeout: 10))
        tap("logSexualActivity", in: app)
        tap("sexualActivityKind_other", in: app)
        app.buttons["saveSexualActivity"].tap()
        XCTAssertTrue(app.buttons["saveSexualActivity"].waitForNonExistence(timeout: 10))

        tap("editDaySymptoms", in: app)
        XCTAssertTrue(app.buttons["chooseDaySymptom_headache"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["chooseDaySymptom_cramps"].exists)
        app.buttons["Done"].tap()
        tap("deleteDaySymptoms", in: app)
        app.alerts.buttons["Keep symptoms"].tap()
        XCTAssertTrue(app.buttons["editDaySymptoms"].exists)
        tap("deleteDaySymptoms", in: app)
        app.alerts.buttons["Delete all symptoms"].tap()
        XCTAssertTrue(app.buttons["editDaySymptoms"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["editSexualActivity_20260928"].exists)
        tap("todayDate_20260929", in: app)
        tap("editDaySymptoms", in: app)
        XCTAssertTrue(app.buttons["chooseDaySymptom_cramps"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["chooseDaySymptom_headache"].exists)
        app.buttons["Done"].tap()
        tap("todayDate_20260930", in: app)
        let card = app.otherElements["todayRecordedDayCard"]
        UIViewport.reveal(card, in: app)
        XCTAssertTrue(card.staticTexts["No period recorded for this day."].exists)
        XCTAssertFalse(app.buttons["editDaySymptoms"].exists)
        XCTAssertFalse(app.buttons["editSexualActivity_20260928"].exists)
    }

    @MainActor func testTodayGroupedActionsFitLargestText() {
        let app = launch(largeText: true)
        for id in ["editDaySymptoms", "deleteDaySymptoms", "dailyLogHistory"] {
            let button = app.buttons[id]
            UIViewport.reveal(button, in: app)
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertGreaterThanOrEqual(button.frame.minX, 0)
            XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX)
        }
        tap("editDaySymptoms", in: app)
        XCTAssertTrue(app.navigationBars["Edit symptoms"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["chooseDaySymptom_cramps"].exists)
    }
}
