import XCTest

@MainActor enum OnboardingUITestSupport {
    static func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    static func next(in app: XCUIApplication) {
        let next = app.buttons["onboardingContinue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertEqual(next.label, "Continue")
        XCTAssertFalse(app.buttons["continueWithApple"].exists)
        let earlyAccountCopy = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "Apple", "account"))
        XCTAssertEqual(earlyAccountCopy.count, 0)
        XCTAssertFalse(app.staticTexts["Your health data stays on your device."].exists)
        reveal(next, in: app); next.tap()
    }

    static func birthday(in app: XCUIApplication) {
        let keyboardReturn = app.keyboards.buttons["Return"]
        if keyboardReturn.exists && keyboardReturn.isHittable { keyboardReturn.tap() }
        reveal(app.buttons["profileBirthday"], in: app)
        app.buttons["profileBirthday"].tap()
        let wheels = app.pickerWheels
        XCTAssertTrue(wheels.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        wheels.element(boundBy: 2).adjust(toPickerWheelValue: "1995")
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "May")
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: "12")
        app.buttons["confirmBirthday"].tap()
    }

    static func choose(_ identifier: String, inRow row: String, app: XCUIApplication) {
        let choice = app.buttons[identifier]
        let list = app.scrollViews[row]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        reveal(list, in: app)
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        for _ in 0..<15 {
            if choice.isHittable { break }
            let moveRight = choice.frame.midX < list.frame.minX
            let start = list.coordinate(withNormalizedOffset: CGVector(dx: moveRight ? 0.25 : 0.75, dy: 0.5))
            let end = list.coordinate(withNormalizedOffset: CGVector(dx: moveRight ? 0.75 : 0.25, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        XCTAssertTrue(choice.isHittable, app.debugDescription)
        XCTAssertGreaterThanOrEqual(choice.frame.height, 44)
        choice.tap()
    }

    static func reachApple(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["onboardingContinue"].waitForExistence(timeout: 10))
        next(in: app)
        let name = app.textFields["profileName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Synthetic Alex")
        birthday(in: app)
        next(in: app)
        app.buttons["onboardingSkip"].tap()
        choose("profileDuration_5", inRow: "profileDuration", app: app)
        next(in: app)
        // Exactly four starts, most recent first, with no invented end dates.
        for (month, day) in [("September", "2"), ("August", "4"), ("July", "5"), ("June", "7")] {
            let add = app.buttons["addOnboardingPeriod"]
            reveal(add, in: app); add.tap()
            let wheels = app.pickerWheels
            XCTAssertTrue(wheels.firstMatch.waitForExistence(timeout: 5))
            wheels.element(boundBy: 2).adjust(toPickerWheelValue: "2026")
            wheels.element(boundBy: 0).adjust(toPickerWheelValue: month)
            wheels.element(boundBy: 1).adjust(toPickerWheelValue: day)
            app.buttons["saveOnboardingPeriod"].tap()
        }
        next(in: app)
        XCTAssertFalse(app.scrollViews["commonSymptoms"].exists)
        app.buttons["commonSymptom_cramps"].tap()
        XCTAssertEqual(app.buttons["commonSymptom_cramps"].value as? String, "Selected")
        let headaches = app.buttons["commonSymptom_headaches"]
        reveal(headaches, in: app); headaches.tap()
        XCTAssertEqual(app.buttons["commonSymptom_headaches"].value as? String, "Selected")
        XCTAssertEqual(app.buttons["commonSymptom_cramps"].value as? String, "Selected")
        let none = app.buttons["commonSymptom_none"]
        reveal(none, in: app)
        XCTAssertGreaterThanOrEqual(none.frame.height, 44)
        XCTAssertGreaterThanOrEqual(none.frame.minX, 0)
        XCTAssertLessThanOrEqual(none.frame.maxX, app.frame.width)
        next(in: app)
        let skip = app.buttons["onboardingSkip"]
        reveal(skip, in: app); skip.tap()
        app.buttons["goal_predictPeriod"].tap()
        next(in: app)
        next(in: app)
        XCTAssertTrue(app.staticTexts["29.0 days"].exists)
        next(in: app)
        XCTAssertTrue(app.buttons["continueWithApple"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["appleSignInPurpose"].label, "Sign in with Apple to save your data and begin cycle tracking.")
        XCTAssertFalse(app.staticTexts["No cloud backup or cross-device restore. Internet is needed for Apple sign-in."].exists)
    }

    static func complete(in app: XCUIApplication) {
        reachApple(in: app)
        let apple = app.buttons["continueWithApple"]
        reveal(apple, in: app); apple.tap()
        XCTAssertTrue(app.staticTexts["creatingAccountMessage"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
    }
}

final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(cancelApple: Bool = false, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_APPLE_AUTH"] = cancelApple ? "cancel" : "success"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    @MainActor func testOnboardingProfilePersistsAndCanBeEdited() {
        let app = launch()
        OnboardingUITestSupport.complete(in: app)
        XCTAssertEqual(app.staticTexts["cycleDay"].label, "Day 28")
        XCTAssertTrue(app.staticTexts["predictionWindow"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Settings"].tap()
        app.buttons["profileSettings"].tap()
        let name = app.textFields["profileName"]
        XCTAssertEqual(name.value as? String, "Synthetic Alex")
        name.tap(); name.typeText(" Updated")
        app.buttons["saveProfile"].tap()
        XCTAssertTrue(app.buttons["profileSettings"].waitForExistence(timeout: 5))
        app.buttons["profileSettings"].tap()
        XCTAssertEqual(app.textFields["profileName"].value as? String, "Synthetic Alex Updated")
    }

    @MainActor func testAppleCancellationLeavesSetupIncomplete() {
        let app = launch(cancelApple: true)
        OnboardingUITestSupport.reachApple(in: app)
        app.buttons["continueWithApple"].tap()
        XCTAssertTrue(app.staticTexts["Sign-in was cancelled. Your draft is still here."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["creatingAccountMessage"].exists)
        XCTAssertFalse(app.tabBars.buttons["Today"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["onboardingContinue"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["onboardingHeading"].label, "Understand your cycle.")
    }

    @MainActor func testMeasurementWheelsAreOptionalClearableAndConvertUnits() {
        let app = launch()
        OnboardingUITestSupport.next(in: app)
        let name = app.textFields["profileName"]
        XCTAssertFalse(app.segmentedControls["profileUnits"].exists)
        name.tap(); name.typeText("Synthetic Alex")
        OnboardingUITestSupport.birthday(in: app)
        OnboardingUITestSupport.next(in: app)
        let units = app.segmentedControls["profileUnits"]
        XCTAssertTrue(units.waitForExistence(timeout: 5))
        XCTAssertEqual(app.sliders.count, 0)
        XCTAssertEqual(app.pickerWheels.count, 0)
        XCTAssertEqual(app.staticTexts["profileHeightValue"].label, "Not added")
        app.buttons["profileHeightAdd"].tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "180 cm")
        XCTAssertEqual(app.staticTexts["profileHeightValue"].label, "180 cm")
        units.buttons["ft + in / lb"].tap()
        XCTAssertTrue(app.staticTexts["profileHeightValue"].label.contains("ft"))
        units.buttons["cm / kg"].tap()
        XCTAssertEqual(app.staticTexts["profileHeightValue"].label, "180 cm")
        units.buttons["ft + in / lb"].tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "5 ft 7 in")
        XCTAssertEqual(app.staticTexts["profileHeightValue"].label, "5 ft 7 in")
        app.buttons["profileHeightClear"].tap()
        XCTAssertEqual(app.staticTexts["profileHeightValue"].label, "Not added")
        XCTAssertEqual(app.pickerWheels.count, 0)
        XCTAssertEqual(app.staticTexts["profileWeightValue"].label, "Not added")
        app.buttons["profileWeightAdd"].tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "150 lb")
        XCTAssertEqual(app.staticTexts["profileWeightValue"].label, "150 lb")
        units.buttons["cm / kg"].tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "70 kg")
        XCTAssertEqual(app.staticTexts["profileWeightValue"].label, "70 kg")
        OnboardingUITestSupport.reveal(app.buttons["profileWeightClear"], in: app)
        app.buttons["profileWeightClear"].tap()
        XCTAssertEqual(app.staticTexts["profileWeightValue"].label, "Not added")
        app.buttons["onboardingSkip"].tap()
        XCTAssertEqual(app.staticTexts["onboardingHeading"].label, "Cycle basics")
    }

    @MainActor func testCycleChoicesAreHorizontalAndAccessibleAtLargestTextSize() {
        let app = launch(largeText: true)
        OnboardingUITestSupport.next(in: app)
        let name = app.textFields["profileName"]
        name.tap(); name.typeText("Synthetic Alex")
        OnboardingUITestSupport.birthday(in: app)
        OnboardingUITestSupport.next(in: app)
        OnboardingUITestSupport.reveal(app.buttons["profileHeightAdd"], in: app)
        app.buttons["profileHeightAdd"].tap()
        OnboardingUITestSupport.reveal(app.pickerWheels.firstMatch, in: app)
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "175 cm")
        app.buttons["onboardingSkip"].tap()
        OnboardingUITestSupport.choose("profilePredictability_sometimes", inRow: "profilePredictability", app: app)
        XCTAssertEqual(app.buttons["profilePredictability_sometimes"].value as? String, "Selected")
        let duration = app.scrollViews["profileDuration"]
        OnboardingUITestSupport.reveal(duration, in: app)
        OnboardingUITestSupport.choose("profileDuration_5", inRow: "profileDuration", app: app)
        XCTAssertEqual(app.buttons["profileDuration_5"].value as? String, "Selected")
        OnboardingUITestSupport.next(in: app)
        XCTAssertEqual(app.staticTexts["onboardingHeading"].label, "Add your last 4 periods")
    }

    @MainActor func testLogoutCancelRelaunchAndSameAccountReconnect() {
        let app = launch()
        OnboardingUITestSupport.complete(in: app)
        app.tabBars.buttons["Settings"].tap()
        app.buttons["accountSettings"].tap()
        let logout = app.buttons["logOut"]
        OnboardingUITestSupport.reveal(logout, in: app); logout.tap()
        app.alerts.buttons["Cancel"].tap()
        XCTAssertFalse(app.staticTexts["signedOutScreen"].exists)
        logout.tap()
        app.alerts.buttons["confirmLogout"].tap()
        XCTAssertTrue(app.staticTexts["signedOutScreen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["logPeriod"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["signedOutScreen"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.buttons["Today"].exists)
        let reconnect = app.buttons["continueWithApple"]
        OnboardingUITestSupport.reveal(reconnect, in: app); reconnect.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["cycleDay"].label, "Day 28")
        app.tabBars.buttons["Settings"].tap()
        app.buttons["profileSettings"].tap()
        XCTAssertEqual(app.textFields["profileName"].value as? String, "Synthetic Alex")
    }
}
