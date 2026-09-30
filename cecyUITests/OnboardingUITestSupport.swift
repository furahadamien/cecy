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
        reveal(next, in: app); next.tap()
    }

    static func birthday(in app: XCUIApplication) {
        app.buttons["profileBirthday"].tap()
        let wheels = app.pickerWheels
        XCTAssertTrue(wheels.firstMatch.waitForExistence(timeout: 5))
        wheels.element(boundBy: 2).adjust(toPickerWheelValue: "1995")
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "May")
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: "12")
        app.buttons["confirmBirthday"].tap()
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
        app.buttons["profileDuration"].tap()
        app.buttons["5 days"].tap()
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
        app.buttons["commonSymptom_cramps"].tap()
        next(in: app)
        let skip = app.buttons["onboardingSkip"]
        reveal(skip, in: app); skip.tap()
        app.buttons["goal_predictPeriod"].tap()
        next(in: app)
        next(in: app)
        XCTAssertTrue(app.staticTexts["29.0 days"].exists)
        next(in: app)
        XCTAssertTrue(app.buttons["continueWithApple"].waitForExistence(timeout: 5))
    }

    static func complete(in app: XCUIApplication) {
        reachApple(in: app)
        let apple = app.buttons["continueWithApple"]
        reveal(apple, in: app); apple.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
    }
}

final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(cancelApple: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_APPLE_AUTH"] = cancelApple ? "cancel" : "success"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
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
        XCTAssertFalse(app.tabBars.buttons["Today"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["onboardingContinue"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["Understand your cycle."].exists)
    }
}