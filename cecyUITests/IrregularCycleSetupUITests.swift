import XCTest

final class IrregularCycleSetupUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func completeUnknownSetup(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_APPLE_AUTH"] = "success"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        XCTAssertTrue(app.buttons["onboardingContinue"].waitForExistence(timeout: 10))
        OnboardingUITestSupport.next(in: app)
        let name = app.textFields["profileName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Synthetic Alex")
        OnboardingUITestSupport.birthday(in: app)
        OnboardingUITestSupport.next(in: app)
        app.buttons["onboardingSkip"].tap()
        OnboardingUITestSupport.skipIdentity(in: app)
        let unknownStart = app.buttons["onboardingLastStartUnknown"]
        OnboardingUITestSupport.reveal(unknownStart, in: app); unknownStart.tap()
        XCTAssertFalse(app.staticTexts["onboardingLastStart"].exists)
        OnboardingUITestSupport.next(in: app)
        for identifier in ["onboardingPeriodLengthUnknown", "onboardingCycleLengthUnknown"] {
            XCTAssertEqual(app.pickerWheels.count, 0)
            let choice = app.buttons[identifier]
            OnboardingUITestSupport.reveal(choice, in: app); choice.tap()
            XCTAssertEqual(choice.value as? String, "Selected")
            XCTAssertEqual(app.pickerWheels.count, 0)
            OnboardingUITestSupport.next(in: app)
        }
        for _ in 0..<3 { app.buttons["onboardingSkip"].tap() }
        OnboardingUITestSupport.next(in: app) // Reminders remain off.
        let unavailable = app.staticTexts["You can track without an estimate."]
        OnboardingUITestSupport.reveal(unavailable, in: app)
        XCTAssertTrue(unavailable.exists)
        XCTAssertFalse(app.staticTexts["starterEstimateNotice"].exists)
        OnboardingUITestSupport.next(in: app)
        let apple = app.buttons["continueWithApple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 5))
        OnboardingUITestSupport.reveal(apple, in: app); apple.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15), app.debugDescription)
        return app
    }

    @MainActor func testUnknownSetupRelaunchAndFirstPeriod() {
        let app = completeUnknownSetup()
        XCTAssertFalse(app.staticTexts["cycleDay"].exists)
        XCTAssertFalse(app.staticTexts["nextPeriodCenter"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["cycleDay"].exists)
        let log = app.buttons["logPeriod"]
        XCTAssertTrue(log.waitForExistence(timeout: 5)); log.tap()
        let save = app.buttons["savePeriod"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertEqual(app.switches["includeEndDate"].value as? String, "0")
        XCTAssertFalse(app.staticTexts["confirmedBleedingDays"].exists)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.navigationBars["Record a period"].waitForNonExistence(timeout: 10))
        let next = app.staticTexts["nextPeriodCenter"]
        UIViewport.reveal(next, in: app)
        XCTAssertTrue(next.exists)
        let starter = app.staticTexts["starterPrediction"]
        UIViewport.reveal(starter, in: app)
        XCTAssertTrue(starter.label.contains("default"))
        let ring = app.otherElements["phaseRingSummary"]
        UIViewport.reveal(ring, in: app)
        XCTAssertTrue(ring.exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        let day = app.staticTexts["cycleDay"]
        UIViewport.reveal(day, in: app)
        XCTAssertEqual(day.label, "Day 1")
        XCTAssertTrue(app.staticTexts["nextPeriodCenter"].exists)
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.buttons["calendarDay_20260929"].label.contains("Recorded period start"))
        XCTAssertFalse(app.buttons["calendarDay_20260929"].label.contains("Estimated period day"))
        XCTAssertTrue(app.buttons["calendarDay_20260930"].label.contains("Estimated period day"))
        app.buttons["nextMonth"].tap()
        for key in [20261001, 20261002, 20261003] {
            XCTAssertTrue(app.buttons["calendarDay_\(key)"].label.contains("Estimated period day"))
        }
        XCTAssertFalse(app.buttons["calendarDay_20261004"].label.contains("Estimated period day"))
    }

    @MainActor func testUnknownChoicesAtLargestTextSize() {
        let app = completeUnknownSetup(largeText: true)
        XCTAssertFalse(app.staticTexts["nextPeriodCenter"].exists)
        XCTAssertTrue(app.buttons["logPeriod"].exists)
        app.tabBars.buttons["Settings"].tap()
        app.buttons["profileSettings"].tap()
        XCTAssertEqual(app.textFields["profileName"].value as? String, "Synthetic Alex")
    }
}
