import XCTest

final class PhaseSixUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(mode: String, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "history"
        app.launchEnvironment["CECY_UI_HEALTH"] = mode
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 15))
        openHealth(app)
        return app
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        if element.isHittable { return }
        for _ in 0..<4 { app.swipeDown() }
        for _ in 0..<8 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    @MainActor private func openHealth(_ app: XCUIApplication) {
        app.tabBars.buttons["Settings"].tap()
        if app.navigationBars["Apple Health"].exists { return }
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10), app.debugDescription)
        let health = app.buttons["healthSettings"]
        reveal(health, in: app); health.tap()
    }

    @MainActor func testUnavailableAndEmptyDoNotBlockLocalTracking() {
        let app = launch(mode: "unavailable")
        XCTAssertTrue(app.staticTexts["healthUnavailable"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["reviewAppleHealth"].exists)
        app.terminate()
        app.launchEnvironment["CECY_UI_HEALTH"] = "empty"
        app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 15))
        openHealth(app)
        app.buttons["reviewAppleHealth"].tap()
        XCTAssertTrue(app.staticTexts["healthReviewResult"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["reviewAppleHealth"].label, "Check again")
        app.buttons["reviewAppleHealth"].tap()
        XCTAssertTrue(app.staticTexts["healthReviewResult"].waitForExistence(timeout: 5))
        let empty = app.staticTexts["No readable flow samples"]
        UIViewport.reveal(empty, in: app)
        XCTAssertTrue(empty.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "does not tell Cecy which")).firstMatch.exists)
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 5))
    }

    @MainActor func testHealthAccessHelpIsReachableAtLargestTextSize() {
        let app = launch(mode: "empty", largeText: true)
        let help = app.buttons["healthAccessHelp"]
        UIViewport.reveal(help, in: app)
        XCTAssertGreaterThanOrEqual(help.frame.height, 44)
        help.tap()
        XCTAssertTrue(app.navigationBars["Health access"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["healthAccessExplanation"].label.contains("no separate account"))
        let step = app.staticTexts["healthReadPermissionStep"]
        UIViewport.reveal(step, in: app)
        XCTAssertTrue(step.label.contains("Menstrual Flow"))
        XCTAssertTrue(step.label.contains("read"))
        let done = app.buttons["closeHealthAccessHelp"]
        XCTAssertTrue(done.isHittable)
        done.tap()
        XCTAssertTrue(app.navigationBars["Apple Health"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["healthReviewResult"].exists)
        let review = app.buttons["reviewAppleHealth"]
        UIViewport.reveal(review, in: app)
        review.tap()
        let result = app.staticTexts["healthReviewResult"]
        UIViewport.reveal(result, in: app)
        XCTAssertTrue(result.label.contains("Review finished"))
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 5))
    }

    @MainActor func testReadErrorOffersRetryAndLocalTrackingRemainsAvailable() {
        let app = launch(mode: "error")
        app.buttons["reviewAppleHealth"].tap()
        let message = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Apple Health isn’t available here")).firstMatch
        UIViewport.reveal(message, in: app)
        XCTAssertTrue(message.exists)
        let retry = app.buttons["reviewAppleHealth"]
        UIViewport.reveal(retry, in: app)
        XCTAssertEqual(retry.label, "Check again")
        XCTAssertTrue(retry.isEnabled)
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 5))
    }

    @MainActor func testConfirmStartPersistsAndRepeatReviewDoesNotDuplicate() {
        let app = launch(mode: "samples")
        app.buttons["reviewAppleHealth"].tap()
        let sample = app.buttons["healthSample_00000000-0000-0000-0000-000000000006"]
        XCTAssertTrue(sample.waitForExistence(timeout: 5))
        reveal(sample, in: app); sample.tap()
        let save = app.buttons["saveHealthStart"]
        reveal(save, in: app)
        XCTAssertFalse(save.isEnabled)
        let confirmation = app.switches["confirmHealthStart"]
        XCTAssertTrue(confirmation.exists)
        confirmation.switches.firstMatch.exists ? confirmation.switches.firstMatch.tap() : confirmation.tap()
        reveal(save, in: app)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts["Already imported"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 15))
        openHealth(app)
        app.buttons["reviewAppleHealth"].tap()
        XCTAssertTrue(app.staticTexts["Already imported"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["healthSample_00000000-0000-0000-0000-000000000006"].exists)
    }

    @MainActor func testStopDiscardsUnconfirmedSamples() {
        let app = launch(mode: "samples")
        app.buttons["reviewAppleHealth"].tap()
        let sample = app.buttons["healthSample_00000000-0000-0000-0000-000000000006"]
        XCTAssertTrue(sample.waitForExistence(timeout: 5))
        app.buttons["stopHealthReview"].tap()
        XCTAssertFalse(sample.exists)
        app.buttons["reviewAppleHealth"].tap()
        XCTAssertTrue(sample.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Already imported"].exists)
    }
}
