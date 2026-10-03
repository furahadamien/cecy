import XCTest

final class DeviceFeedbackUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(onboarding: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        if !onboarding { app.launchEnvironment["CECY_UI_FIXTURE"] = "ai" }
        app.launchEnvironment["CECY_UI_AI"] = "success"
        app.launchEnvironment["CECY_UI_APPLE_AUTH"] = "success"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue((onboarding ? app.buttons["onboardingContinue"] : app.buttons["todayDate_20260929"]).waitForExistence(timeout: 15))
        return app
    }

    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<20 {
            let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : 65
            let bottom = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY
                : app.tabBars.buttons.firstMatch.isHittable ? app.tabBars.firstMatch.frame.minY : app.frame.maxY - 25
            if element.exists && element.isHittable && element.frame.minY >= top && element.frame.maxY <= bottom { return }
            let container = app.collectionViews.allElementsBoundByIndex.last(where: { $0.isHittable })
                ?? app.scrollViews.allElementsBoundByIndex.first(where: { $0.isHittable && $0.identifier != "todayDateStrip" }) ?? app
            if element.exists && element.frame.minY < top { container.swipeDown() } else { container.swipeUp() }
        }
        XCTFail("Could not reveal element: \(element)\n\(app.debugDescription)")
    }

    @MainActor private func tap(_ identifier: String, app: XCUIApplication) {
        if identifier == "profileGenderChoices" || identifier == "profilePartnerChoices" {
            let label = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            reveal(label, app: app); label.tap(); return
        }
        let button = app.buttons[identifier]
        if app.navigationBars.buttons[identifier].exists && button.isHittable { button.tap(); return }
        reveal(button, app: app); button.tap()
    }

    @MainActor func testTodayStripCentersBrowsesAndMatchesMonthActivities() {
        let app = launch()
        let today = app.buttons["todayDate_20260929"]
        XCTAssertTrue(today.isHittable)
        XCTAssertLessThan(abs(today.frame.midX - app.frame.midX), 25)
        XCTAssertTrue(today.label.contains("Cramps"))
        let strip = app.scrollViews["todayDateStrip"]
        // A full fling can skip October 1 and evict it from the lazy strip.
        let start = strip.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
        let end = strip.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        let october = app.buttons["todayDate_20261001"]
        XCTAssertTrue(october.waitForExistence(timeout: 5))
        XCTAssertTrue(october.isHittable)
        tap("stripReturnToToday", app: app)
        let future = app.buttons["todayDate_20260930"]
        XCTAssertTrue(future.isHittable); future.tap()
        reveal(app.buttons["logPeriod"], app: app)
        XCTAssertFalse(app.buttons["logPeriod"].isEnabled)
        XCTAssertFalse(app.buttons["logSymptoms"].isEnabled)
        tap("stripReturnToToday", app: app)
        tap("logSexualActivity", app: app)
        tap("sexualActivityKind_vaginalSex", app: app)
        tap("saveSexualActivity", app: app)
        XCTAssertTrue(app.navigationBars["Log sex"].waitForNonExistence(timeout: 5))
        reveal(today, app: app)
        XCTAssertTrue(today.label.contains("Cramps") && today.label.contains("Vaginal sex"))
        app.tabBars.buttons["Calendar"].tap()
        let monthDay = app.buttons["calendarDay_20260929"]
        XCTAssertTrue(monthDay.waitForExistence(timeout: 5))
        XCTAssertTrue(monthDay.label.contains("Cramps") && monthDay.label.contains("Vaginal sex"))
    }

    @MainActor func testQuestionInputCapsAt100AndScopeChangeResetsDraft() {
        let app = launch()
        app.tabBars.buttons["Insights"].tap()
        tap("askCecy", app: app)
        let field = app.textViews["aiQuestionText"].exists ? app.textViews["aiQuestionText"] : app.textFields["aiQuestionText"]
        reveal(field, app: app); field.tap()
        field.typeText(String(repeating: "z", count: 110))
        XCTAssertEqual((field.value as? String)?.count, 100)
        XCTAssertEqual(app.staticTexts["questionCharacterCount"].label, "100 / 100")
        app.buttons["Hide keyboard"].tap()
        let scope = app.buttons["aiQuestionScope_symptomFrequency"]
        reveal(app.scrollViews["aiQuestionScope"], app: app)
        for _ in 0..<4 { if scope.isHittable { break }; app.scrollViews["aiQuestionScope"].swipeLeft() }
        scope.tap()
        reveal(field, app: app)
        XCTAssertLessThan((field.value as? String)?.count ?? 101, 100)
        XCTAssertFalse(app.buttons["Use suggested question"].exists)
        XCTAssertFalse(app.staticTexts["Waiting for AI…"].exists)
    }

    @MainActor func testProfileIdentityChoicesPersistAndCanBeCleared() {
        let app = launch()
        func openProfile() {
            app.tabBars.buttons["Settings"].tap()
            tap("profileSettings", app: app)
            tap("profileGenderChoices", app: app)
            XCTAssertTrue(app.buttons["profileGender_nonbinary"].waitForExistence(timeout: 5), app.debugDescription)
        }
        openProfile()
        tap("profileGender_nonbinary", app: app)
        tap("profilePartnerChoices", app: app)
        tap("profilePartner_women", app: app)
        tap("profilePartner_men", app: app)
        XCTAssertEqual(app.buttons["profilePartner_women"].value as? String, "Selected")
        tap("saveProfile", app: app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 10))
        openProfile()
        XCTAssertEqual(app.buttons["profileGender_nonbinary"].value as? String, "Selected")
        tap("clearGender", app: app)
        tap("profilePartnerChoices", app: app)
        XCTAssertEqual(app.buttons["profilePartner_men"].value as? String, "Selected")
        tap("clearPartners", app: app)
        tap("saveProfile", app: app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 10))
        openProfile()
        XCTAssertEqual(app.buttons["profileGender_nonbinary"].value as? String, "Not selected")
        tap("profilePartnerChoices", app: app)
        XCTAssertEqual(app.buttons["profilePartner_men"].value as? String, "Not selected")
    }

    @MainActor func testNewOnboardingStepsAreOptionalAndRetainBackNavigation() {
        let app = launch(onboarding: true)
        OnboardingUITestSupport.next(in: app)
        let name = app.textFields["profileName"]
        name.tap(); name.typeText("Synthetic Alex")
        OnboardingUITestSupport.birthday(in: app)
        OnboardingUITestSupport.next(in: app)
        app.buttons["onboardingSkip"].tap()
        XCTAssertEqual(app.staticTexts["onboardingHeading"].label, "Your gender")
        tap("profileGender_nonbinary", app: app)
        OnboardingUITestSupport.next(in: app)
        XCTAssertEqual(app.staticTexts["onboardingHeading"].label, "Who do you have sex with?")
        tap("profilePartner_women", app: app)
        tap("profilePartner_men", app: app)
        tap("profilePartner_preferNotToSay", app: app)
        XCTAssertEqual(app.buttons["profilePartner_women"].value as? String, "Not selected")
        app.buttons["onboardingBack"].tap()
        XCTAssertEqual(app.buttons["profileGender_nonbinary"].value as? String, "Selected")
        OnboardingUITestSupport.skipIdentity(in: app)
        XCTAssertEqual(app.staticTexts["onboardingHeading"].label, "When did your last period start?")
    }
}
