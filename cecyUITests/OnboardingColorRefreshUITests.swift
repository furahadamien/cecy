import XCTest

/// Walks the current eight-step onboarding with the color refresh and checks the contracts it must keep.
final class OnboardingColorRefreshUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_APPLE_AUTH"] = "success"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    @MainActor private func heading(_ app: XCUIApplication, is title: String) {
        let heading = app.staticTexts["onboardingHeading"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        let predicate = NSPredicate(format: "label == %@", title)
        let match = app.staticTexts.matching(identifier: "onboardingHeading").matching(predicate).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 5), "Expected heading \(title)\n\(app.debugDescription)")
        XCTAssertTrue(app.progressIndicators["Onboarding progress"].exists)
    }

    @MainActor private func next(_ app: XCUIApplication) {
        let next = app.buttons["onboardingContinue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        OnboardingUITestSupport.reveal(next, in: app)
        next.tap()
    }

    @MainActor private func reachReview(_ app: XCUIApplication) {
        heading(app, is: "Understand your cycle.")
        XCTAssertEqual(app.buttons["onboardingContinue"].label, "Get started")
        XCTAssertTrue(app.staticTexts["Stored on this device"].exists)
        next(app)
        heading(app, is: "About you")
        let name = app.textFields["profileName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Synthetic Alex")
        OnboardingUITestSupport.birthday(in: app)
        next(app)
        heading(app, is: "When did your last period start?")
        OnboardingUITestSupport.lastStart(in: app)
        XCTAssertTrue(app.staticTexts["onboardingLastStart"].waitForExistence(timeout: 5))
        next(app)
        heading(app, is: "How long is your period?")
        app.buttons["onboardingPeriodLengthKnown"].tap()
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "5 days")
        next(app)
        heading(app, is: "How long is your cycle?")
        app.buttons["onboardingCycleLengthKnown"].tap()
        XCTAssertEqual(app.buttons["onboardingCycleLengthKnown"].value as? String, "Selected")
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "28 days")
        next(app)
        heading(app, is: "Your Today view")
        next(app)
        heading(app, is: "Review your profile")
    }

    @MainActor func testColorfulFlowKeepsIdentifiersAndCompletes() {
        let app = launch()
        reachReview(app)

        // Review tiles jump back to their step and return to review.
        let cycleTile = app.buttons["Typical cycle, 28 days"]
        OnboardingUITestSupport.reveal(cycleTile, in: app)
        cycleTile.tap()
        heading(app, is: "How long is your cycle?")
        XCTAssertEqual(app.buttons["onboardingContinue"].label, "Back to review")
        next(app)
        heading(app, is: "Review your profile")

        next(app)
        heading(app, is: "Let's save your profile")
        let note = app.staticTexts["onboardingLocalProfileNote"]
        XCTAssertEqual(note.label, "Your records are stored on this device. Optional AI insights send selected information for online processing only with your consent.")
        let apple = app.buttons["continueWithApple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 5))
        XCTAssertTrue(apple.isHittable)
        XCTAssertGreaterThanOrEqual(apple.frame.height, 44)
        XCTAssertLessThan(note.frame.maxY, apple.frame.minY)
        XCTAssertFalse(app.buttons["onboardingContinue"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "onboardingBack").count, 1)

        apple.tap()
        let progress = app.staticTexts["creatingAccountMessage"]
        XCTAssertTrue(progress.exists || progress.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15), app.debugDescription)
    }

    @MainActor func testBackNavigationAtLargestTextSize() {
        let app = launch(largeText: true)
        heading(app, is: "Understand your cycle.")
        next(app)
        heading(app, is: "About you")
        app.navigationBars.buttons["onboardingBack"].tap()
        heading(app, is: "Understand your cycle.")
        XCTAssertTrue(app.buttons["onboardingContinue"].isHittable)
    }
}
