import XCTest

@MainActor enum OnboardingUITestSupport {
    static func skipIdentity(in app: XCUIApplication) {
        for title in ["Your gender", "Who do you have sex with?"] {
            XCTAssertTrue(app.staticTexts["onboardingHeading"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.staticTexts["onboardingHeading"].label, title)
            XCTAssertTrue(app.buttons["onboardingSkip"].isEnabled)
            app.buttons["onboardingSkip"].tap()
        }
    }
    static func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.isHittable && ["onboardingContinue", "onboardingSkip"].contains(element.identifier) { return }
            if element.exists && element.elementType == .pickerWheel && element.isHittable { return }
            let navigationBottom = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : app.frame.minY
            let progress = app.progressIndicators["Onboarding progress"]
            let top = progress.exists ? max(navigationBottom, progress.frame.maxY + 12) : navigationBottom
            let next = app.buttons["onboardingContinue"]
            let bottom = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY
                : next.exists ? next.frame.minY - 12 : app.frame.maxY - 24
            if element.exists && element.isHittable && element.frame.minY >= top && element.frame.maxY <= bottom { return }
            if element.exists && element.frame.maxY > top && element.frame.minY < bottom {
                let delta = element.frame.minY < top ? top + 12 - element.frame.minY : bottom - 12 - element.frame.maxY
                let distance = min(abs(delta), (bottom - top) / 2)
                let startY = delta > 0 ? top + 24 : bottom - 24
                let start = app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: 12, dy: startY))
                let end = start.withOffset(CGVector(dx: 0, dy: delta > 0 ? distance : -distance))
                start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
            } else if element.exists && element.frame.minY < top { app.swipeDown() } else { app.swipeUp() }
        }
        XCTFail("Could not fully reveal \(element)\n\(app.debugDescription)")
    }

    static func next(in app: XCUIApplication) {
        let next = app.buttons["onboardingContinue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        let isWelcome = app.staticTexts["onboardingHeading"].label == "Understand your cycle."
        XCTAssertEqual(next.label, isWelcome ? "Get started" : "Continue")
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
            let viewport = list.frame.intersection(app.frame).insetBy(dx: 22, dy: 0)
            if choice.isHittable && viewport.contains(CGPoint(x: choice.frame.midX, y: choice.frame.midY)) { break }
            let moveRight = choice.frame.midX < viewport.midX
            let start = list.coordinate(withNormalizedOffset: CGVector(dx: moveRight ? 0.25 : 0.75, dy: 0.5))
            let end = list.coordinate(withNormalizedOffset: CGVector(dx: moveRight ? 0.75 : 0.25, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        XCTAssertTrue(choice.isHittable, app.debugDescription)
        XCTAssertGreaterThanOrEqual(choice.frame.height, 44)
        choice.tap()
    }

    static func lastStart(in app: XCUIApplication) {
        let add = app.buttons["addOnboardingPeriod"]
        reveal(add, in: app); add.tap()
        let wheels = app.pickerWheels
        XCTAssertTrue(wheels.firstMatch.waitForExistence(timeout: 5))
        wheels.element(boundBy: 2).adjust(toPickerWheelValue: "2026")
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "September")
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: "2")
        app.buttons["saveOnboardingPeriod"].tap()
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
        skipIdentity(in: app)
        lastStart(in: app)
        next(in: app)
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "5 days")
        next(in: app)
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "28 days")
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
        reveal(app.staticTexts["starterEstimateNotice"], in: app)
        XCTAssertTrue(app.staticTexts["starterEstimateNotice"].exists)
        next(in: app)
        XCTAssertTrue(app.buttons["continueWithApple"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["onboardingHeading"].label, "Let's save your profile")
        let storageNote = app.staticTexts["onboardingLocalProfileNote"]
        XCTAssertEqual(storageNote.label, "Your data stays on your device, we never store it in the cloud")
        XCTAssertGreaterThan(storageNote.frame.minY, app.staticTexts["onboardingHeading"].frame.maxY)
        XCTAssertLessThan(storageNote.frame.maxY, app.buttons["continueWithApple"].frame.minY)
        let back = app.navigationBars.buttons["onboardingBack"]
        XCTAssertEqual(back.label, "Back")
        XCTAssertTrue(back.isHittable)
        XCTAssertEqual(app.buttons.matching(identifier: "onboardingBack").count, 1)
        XCTAssertTrue(app.progressIndicators["Onboarding progress"].exists)
        let apple = app.buttons["continueWithApple"]
        XCTAssertEqual(apple.label, "Sign up with Apple")
        XCTAssertTrue(apple.isHittable)
        XCTAssertGreaterThanOrEqual(apple.frame.height, 44)
        XCTAssertGreaterThan(apple.frame.minY, app.staticTexts["onboardingHeading"].frame.maxY)
        XCTAssertFalse(app.staticTexts["appleSignInPurpose"].exists)
        XCTAssertFalse(app.buttons["onboardingContinue"].exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Google")).firstMatch.exists)
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
        XCTAssertTrue(app.staticTexts["starterPrediction"].exists)
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
        app.buttons["onboardingBack"].tap()
        XCTAssertEqual(app.staticTexts["onboardingHeading"].label, "Review your profile")
        OnboardingUITestSupport.next(in: app)
        XCTAssertTrue(app.buttons["continueWithApple"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["onboardingHeading"].label, "Let's save your profile")
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
        app.buttons["profileHeightDone"].tap()
        XCTAssertEqual(app.pickerWheels.count, 0)
        units.buttons["Imperial"].tap()
        XCTAssertTrue(app.staticTexts["profileHeightValue"].label.contains("ft"))
        units.buttons["Metric"].tap()
        XCTAssertEqual(app.staticTexts["profileHeightValue"].label, "180 cm")
        units.buttons["Imperial"].tap()
        app.buttons["profileHeightEdit"].tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "5 ft 7 in")
        XCTAssertEqual(app.staticTexts["profileHeightValue"].label, "5 ft 7 in")
        app.buttons["profileHeightClear"].tap()
        XCTAssertEqual(app.staticTexts["profileHeightValue"].label, "Not added")
        XCTAssertEqual(app.pickerWheels.count, 0)
        XCTAssertEqual(app.staticTexts["profileWeightValue"].label, "Not added")
        app.buttons["profileWeightAdd"].tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "150 lb")
        XCTAssertEqual(app.staticTexts["profileWeightValue"].label, "150 lb")
        app.buttons["profileWeightDone"].tap()
        XCTAssertEqual(app.pickerWheels.count, 0)
        units.buttons["Metric"].tap()
        app.buttons["profileWeightEdit"].tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "70 kg")
        XCTAssertEqual(app.staticTexts["profileWeightValue"].label, "70 kg")
        OnboardingUITestSupport.reveal(app.buttons["profileWeightClear"], in: app)
        app.buttons["profileWeightClear"].tap()
        XCTAssertEqual(app.staticTexts["profileWeightValue"].label, "Not added")
        app.buttons["onboardingSkip"].tap()
        OnboardingUITestSupport.skipIdentity(in: app)
        XCTAssertEqual(app.staticTexts["onboardingHeading"].label, "When did your last period start?")
    }

    @MainActor func testCycleWheelsAreAccessibleAtLargestTextSize() {
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
        OnboardingUITestSupport.skipIdentity(in: app)
        OnboardingUITestSupport.lastStart(in: app)
        OnboardingUITestSupport.next(in: app)
        let duration = app.pickerWheels.firstMatch
        XCTAssertEqual(duration.value as? String, "5 days")
        OnboardingUITestSupport.reveal(duration, in: app)
        duration.adjust(toPickerWheelValue: "7 days")
        OnboardingUITestSupport.next(in: app)
        let cycle = app.pickerWheels.firstMatch
        OnboardingUITestSupport.reveal(cycle, in: app)
        XCTAssertEqual(cycle.value as? String, "28 days")
        cycle.adjust(toPickerWheelValue: "30 days")
        OnboardingUITestSupport.next(in: app)
        XCTAssertEqual(app.staticTexts["onboardingHeading"].label, "Common symptoms")
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
