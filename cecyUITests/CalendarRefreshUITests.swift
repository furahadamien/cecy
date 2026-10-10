import XCTest

final class CalendarRefreshUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "sparse"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.staticTexts["calendarMonth"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor private func tap(_ id: String, in app: XCUIApplication) {
        let button = app.buttons[id]
        let topControl = id == "calendarReturnToToday" || id == "goToDate"
        if !topControl || !button.isHittable { UIViewport.reveal(button, in: app) }
        button.tap()
    }

    @MainActor private func expectMonth(_ title: String, in app: XCUIApplication) {
        let month = app.staticTexts["calendarMonth"]
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", title), object: month)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed, app.debugDescription)
    }

    @MainActor private func moveMonth(_ id: String, to title: String, in app: XCUIApplication) {
        let month = app.staticTexts["calendarMonth"]
        for _ in 0..<2 {
            if month.label == title { return }
            tap(id, in: app)
            let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", title), object: month)
            if XCTWaiter.wait(for: [changed], timeout: 3) == .completed { return }
        }
        XCTAssertEqual(month.label, title, app.debugDescription)
    }

    @MainActor func testCenteredMonthKeepsDateNavigationAndLegendDisclosure() {
        let app = launch()
        let month = app.staticTexts["calendarMonth"]
        XCTAssertEqual(month.label, "September 2026")
        XCTAssertEqual(month.frame.midX, app.frame.midX, accuracy: 1)
        XCTAssertEqual(month.frame.midY, app.buttons["nextMonth"].frame.midY, accuracy: 1)
        let date = app.buttons["calendarDay_20260929"]
        XCTAssertGreaterThanOrEqual(date.frame.height, 44)
        XCTAssertLessThanOrEqual(date.frame.height, 52)
        XCTAssertLessThanOrEqual(app.otherElements["calendarLegend"].frame.height, 165)
        moveMonth("nextMonth", to: "October 2026", in: app)
        tap("calendarReturnToToday", in: app)
        expectMonth("September 2026", in: app)
        moveMonth("previousMonth", to: "August 2026", in: app)
        tap("calendarReturnToToday", in: app)
        expectMonth("September 2026", in: app)
        tap("goToDate", in: app)
        XCTAssertTrue(app.navigationBars["Choose a date"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertEqual(month.label, "September 2026")
        tap("dailyBleedingLegend", in: app)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Logged:")).count, 4)
    }

    @MainActor func testSelectedRecordsFollowForecastAndKeepPeriodActions() {
        let app = launch()
        tap("calendarDay_20260902", in: app)
        let records = app.otherElements["calendarRecordedDayCard"]
        tap("editPeriod", in: app)
        XCTAssertTrue(app.navigationBars["Edit period"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        tap("deletePeriod", in: app)
        XCTAssertTrue(app.alerts["Delete this period?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Keep period"].tap()
        let edit = app.buttons["editPeriod"]
        UIViewport.reveal(edit, in: app)
        XCTAssertTrue(edit.isHittable)
        let delete = app.buttons["deletePeriod"]
        XCTAssertFalse(edit.staticTexts["Edit"].exists)
        XCTAssertFalse(delete.staticTexts["Delete"].exists)
        XCTAssertGreaterThan(edit.frame.minX, records.staticTexts["Recorded period start"].frame.maxX)
        XCTAssertGreaterThan(delete.frame.minX, edit.frame.maxX)
        XCTAssertEqual(edit.frame.midY, delete.frame.midY, accuracy: 1)
        XCTAssertGreaterThanOrEqual(edit.frame.width, 44)
        XCTAssertGreaterThan(records.frame.minY, app.otherElements["upcomingCycleForecast"].frame.maxY)
        XCTAssertGreaterThan(records.frame.minY, app.otherElements["calendarLoggingActions"].frame.maxY)
        XCTAssertTrue(records.staticTexts["End not recorded"].exists)
        XCTAssertTrue(app.buttons["sexualActivityHistory"].exists)
        XCTAssertTrue(app.buttons["addPreviousPeriods"].exists)
    }

    @MainActor func testSymptomActionsAreOnTheRightAndKeepConfirmation() {
        let app = launch()
        let edit = app.buttons["editDaySymptoms"]
        UIViewport.reveal(edit, in: app)
        let symptom = app.descendants(matching: .any)["calendarSymptom_cramps"].firstMatch
        XCTAssertGreaterThan(edit.frame.minX, symptom.frame.maxX)
        let delete = app.buttons["deleteDaySymptoms"]
        XCTAssertGreaterThan(delete.frame.minX, edit.frame.maxX)
        XCTAssertEqual(edit.frame.midY, delete.frame.midY, accuracy: 1)
        XCTAssertFalse(edit.staticTexts["Edit"].exists)
        XCTAssertFalse(delete.staticTexts["Delete"].exists)
        tap("deleteDaySymptoms", in: app)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["Keep symptoms"].tap()
        tap("editDaySymptoms", in: app)
        XCTAssertTrue(app.buttons["chooseDaySymptom_cramps"].waitForExistence(timeout: 5))
    }
}
