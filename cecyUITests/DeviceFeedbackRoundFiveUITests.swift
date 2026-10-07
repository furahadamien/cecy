import XCTest

final class DeviceFeedbackRoundFiveUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(onboarding: Bool = false, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_APPLE_AUTH"] = "success"
        if !onboarding { app.launchEnvironment["CECY_UI_FIXTURE"] = "sparse" }
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue((onboarding ? app.buttons["onboardingContinue"] : app.tabBars.buttons["Today"]).waitForExistence(timeout: 10))
        return app
    }

    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<14 {
            let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : app.frame.minY + 60
            let bottom = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY
                : app.tabBars.firstMatch.isHittable ? app.tabBars.firstMatch.frame.minY : app.frame.maxY - 25
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
        let button = app.buttons[identifier]
        reveal(button, app: app)
        button.tap()
    }

    @MainActor func testTodayLegendAndDatesAreCompact() {
        let app = launch()
        let legend = app.otherElements["todayCalendarLegend"]
        XCTAssertTrue(legend.waitForExistence(timeout: 5))
        let items = legend.staticTexts.allElementsBoundByIndex
        XCTAssertEqual(items.count, 8)
        XCTAssertTrue(legend.buttons["dailyBleedingLegend"].exists)
        XCTAssertEqual(legend.scrollViews.count, 0)
        XCTAssertGreaterThan((items.map(\.frame.minY).max() ?? 0) - (items.map(\.frame.minY).min() ?? 0), 5)
        for item in items {
            XCTAssertGreaterThanOrEqual(item.frame.minX, legend.frame.minX - 1)
            XCTAssertLessThanOrEqual(item.frame.maxX, legend.frame.maxX + 1)
            XCTAssertLessThanOrEqual(item.frame.maxY, legend.frame.maxY + 1)
        }
        XCTAssertFalse(app.staticTexts["Dashed dates are possible starts, not recorded bleeding. Symptoms use their individual icons."].exists)
        XCTAssertFalse(app.staticTexts["todayStripSelectedDate"].exists)
        XCTAssertFalse(app.scrollViews["todayDateStrip"].staticTexts["September 29, 2026"].exists)
        let date = app.buttons["todayDate_20260929"]
        XCTAssertTrue(date.exists)
        XCTAssertGreaterThanOrEqual(date.frame.width, 44)
        XCTAssertLessThan(date.frame.width, 56)
        XCTAssertGreaterThanOrEqual(date.frame.height, 44)
        XCTAssertLessThanOrEqual(date.frame.maxY, app.scrollViews["todayDateStrip"].frame.maxY + 1)
    }

    @MainActor func testTodayLegendWrapsAtLargestTextSize() {
        let app = launch(largeText: true)
        let legend = app.otherElements["todayCalendarLegend"]
        reveal(legend, app: app)
        let items = legend.staticTexts.allElementsBoundByIndex
        XCTAssertEqual(items.count, 8)
        XCTAssertTrue(legend.buttons["dailyBleedingLegend"].exists)
        XCTAssertEqual(legend.scrollViews.count, 0)
        for item in items {
            XCTAssertGreaterThanOrEqual(item.frame.minX, legend.frame.minX - 1)
            XCTAssertLessThanOrEqual(item.frame.maxX, legend.frame.maxX + 1)
            XCTAssertLessThanOrEqual(item.frame.maxY, legend.frame.maxY + 1)
        }
        XCTAssertGreaterThan((items.map(\.frame.minY).max() ?? 0) - (items.map(\.frame.minY).min() ?? 0), 5)
    }

    @MainActor func testTodayCompactLoggingKeepsEntryActions() {
        let app = launch()
        for (identifier, title, sheet) in [
            ("logPeriod", "Log period", "Record a period"),
            ("logSymptoms", "Symptoms", "Log symptoms"),
            ("logSexualActivity", "Log sex", "Log sex")
        ] {
            let button = app.buttons[identifier]
            reveal(button, app: app)
            XCTAssertEqual(button.frame.height, 44, accuracy: 1)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertLessThan(button.frame.width, 150)
            let text = button.staticTexts[title]
            XCTAssertTrue(text.exists)
            // SwiftUI can expose the full control as the text's accessibility frame.
            XCTAssertGreaterThanOrEqual(text.frame.minY, button.frame.minY)
            XCTAssertLessThanOrEqual(text.frame.maxY, button.frame.maxY)
            button.tap()
            XCTAssertTrue(app.navigationBars[sheet].waitForExistence(timeout: 5))
            app.navigationBars.buttons["Cancel"].tap()
        }
    }

    @MainActor func testCalendarLegendContainsOnlySymbolDescriptions() {
        let app = launch()
        app.tabBars.buttons["Calendar"].tap()
        let legend = app.otherElements["calendarLegend"]
        reveal(legend, app: app)
        XCTAssertEqual(legend.staticTexts.count, 8)
        XCTAssertTrue(legend.buttons["dailyBleedingLegend"].exists)
        XCTAssertTrue(legend.staticTexts["Estimated fertile window"].exists)
        XCTAssertTrue(legend.staticTexts["Expected bleeding · Not recorded"].exists)
        XCTAssertFalse(app.staticTexts["A dot beside the date marks today. Tap a date for all records."].exists)
        XCTAssertFalse(app.staticTexts["An underlined date is selected. Estimates are not recorded bleeding days."].exists)
        XCTAssertFalse(app.staticTexts["Later cycles assume estimated periods occur. Only three cycles are projected from your last recorded start."].exists)
    }

    @MainActor func testCalendarLoggingIsBelowDatesBeforeLegendAndKeepsSelectionGuards() {
        let app = launch()
        app.tabBars.buttons["Calendar"].tap()
        let period = app.buttons["calendarLogPeriod"]
        let symptoms = app.buttons["logSymptoms"]
        let sex = app.buttons["logSexualActivity"]
        reveal(period, app: app)
        for button in [period, symptoms, sex] {
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertLessThanOrEqual(button.frame.height, 45)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertLessThan(button.frame.width, 150)
            XCTAssertGreaterThanOrEqual(button.frame.minY, app.buttons["calendarDay_20260930"].frame.maxY)
            XCTAssertLessThanOrEqual(button.frame.maxY, app.otherElements["calendarLegend"].frame.minY)
        }
        XCTAssertEqual(app.buttons.matching(identifier: "calendarLogPeriod").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "logSymptoms").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "logSexualActivity").count, 1)
        for (button, title) in [(period, "Log period"), (symptoms, "Symptoms"), (sex, "Log sex")] {
            let text = button.staticTexts[title]
            XCTAssertTrue(text.exists)
            XCTAssertGreaterThanOrEqual(text.frame.minY, button.frame.minY)
            XCTAssertLessThanOrEqual(text.frame.maxY, button.frame.maxY)
            XCTAssertGreaterThanOrEqual(text.frame.minX, button.frame.minX)
            XCTAssertLessThanOrEqual(text.frame.maxX, button.frame.maxX)
        }
        XCTAssertTrue(app.buttons["calendarDay_20260929"].label.contains("Cramps"))
        XCTAssertTrue(app.buttons["calendarDay_20260929"].label.contains("estimate"))
        period.tap()
        XCTAssertTrue(app.navigationBars["Record a period"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Cancel"].tap()
        tap("logSymptoms", app: app)
        XCTAssertTrue(app.navigationBars["Log symptoms"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Cancel"].tap()
        tap("logSexualActivity", app: app)
        XCTAssertTrue(app.navigationBars["Log sex"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Cancel"].tap()
        tap("calendarDay_20260902", app: app)
        reveal(period, app: app)
        XCTAssertTrue(period.isEnabled)
        XCTAssertTrue(symptoms.isEnabled && sex.isEnabled)
        period.tap()
        XCTAssertTrue(app.navigationBars["Edit period"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Cancel"].tap()
        tap("calendarDay_20260930", app: app)
        reveal(period, app: app)
        XCTAssertFalse(period.isEnabled || symptoms.isEnabled || sex.isEnabled)
    }

    @MainActor func testOnboardingContextAndGoalChipsPreserveSelectionsAndSave() {
        let app = launch(onboarding: true)
        OnboardingUITestSupport.next(in: app)
        let name = app.textFields["profileName"]
        name.tap(); name.typeText("Synthetic Alex")
        OnboardingUITestSupport.birthday(in: app)
        OnboardingUITestSupport.next(in: app)
        app.buttons["onboardingSkip"].tap()
        OnboardingUITestSupport.skipIdentity(in: app)
        OnboardingUITestSupport.lastStart(in: app)
        OnboardingUITestSupport.next(in: app)
        app.buttons["onboardingPeriodLengthKnown"].tap()
        OnboardingUITestSupport.next(in: app)
        app.buttons["onboardingCycleLengthKnown"].tap()
        OnboardingUITestSupport.next(in: app)
        XCTAssertEqual(app.staticTexts["onboardingHeading"].label, "Common symptoms")
        app.buttons["onboardingSkip"].tap()
        XCTAssertEqual(app.staticTexts["onboardingHeading"].label, "Cycle context")
        for id in ["cycleContext_postpartum", "cycleContext_breastfeeding"] {
            let chip = app.buttons[id]
            OnboardingUITestSupport.reveal(chip, in: app); chip.tap()
            XCTAssertEqual(chip.value as? String, "Selected")
            XCTAssertGreaterThanOrEqual(chip.frame.height, 44)
        }
        let none = app.buttons["cycleContext_none"]
        OnboardingUITestSupport.reveal(none, in: app); none.tap()
        XCTAssertEqual(app.buttons["cycleContext_postpartum"].value as? String, "Not selected")
        XCTAssertEqual(app.buttons["cycleContext_breastfeeding"].value as? String, "Not selected")
        OnboardingUITestSupport.next(in: app)
        XCTAssertEqual(app.staticTexts["onboardingHeading"].label, "Your goals")
        for id in ["goal_predictPeriod", "goal_healthAndWellness"] {
            let chip = app.buttons[id]
            OnboardingUITestSupport.reveal(chip, in: app); chip.tap()
            XCTAssertEqual(chip.value as? String, "Selected")
        }
        app.buttons["onboardingBack"].tap()
        XCTAssertEqual(app.buttons["cycleContext_none"].value as? String, "Selected")
        OnboardingUITestSupport.next(in: app)
        XCTAssertEqual(app.buttons["goal_predictPeriod"].value as? String, "Selected")
        XCTAssertEqual(app.buttons["goal_healthAndWellness"].value as? String, "Selected")
        for _ in 0..<3 { OnboardingUITestSupport.next(in: app) }
        app.buttons["continueWithApple"].tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Settings"].tap()
        tap("profileSettings", app: app)
        tap("Cycle context (1)", app: app)
        XCTAssertEqual(app.buttons["cycleContext_none"].value as? String, "Selected")
        tap("Tracking goals (2)", app: app)
        XCTAssertEqual(app.buttons["goal_predictPeriod"].value as? String, "Selected")
        XCTAssertEqual(app.buttons["goal_healthAndWellness"].value as? String, "Selected")
    }

    @MainActor func testContextAndGoalsWrapAtLargestTextSize() {
        let app = launch(largeText: true)
        app.tabBars.buttons["Settings"].tap()
        tap("profileSettings", app: app)
        tap("Cycle context (0)", app: app)
        for id in ["cycleContext_recentlyStoppedBirthControl", "cycleContext_preferNotToSay"] {
            let chip = app.buttons[id]
            reveal(chip, app: app)
            XCTAssertGreaterThanOrEqual(chip.frame.height, 44)
            XCTAssertGreaterThanOrEqual(chip.frame.minX, 0)
            XCTAssertLessThanOrEqual(chip.frame.maxX, app.frame.maxX)
            chip.tap()
            XCTAssertEqual(chip.value as? String, "Selected")
        }
        tap("Tracking goals (0)", app: app)
        let goal = app.buttons["goal_healthAndWellness"]
        reveal(goal, app: app)
        XCTAssertGreaterThanOrEqual(goal.frame.height, 44)
        XCTAssertGreaterThanOrEqual(goal.frame.minX, 0)
        XCTAssertLessThanOrEqual(goal.frame.maxX, app.frame.maxX)
        goal.tap()
        XCTAssertEqual(goal.value as? String, "Selected")
    }
}
