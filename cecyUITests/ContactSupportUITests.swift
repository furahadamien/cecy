import XCTest

final class ContactSupportUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testSettingsSupportAddressAndCopyWithoutSendingEmail() {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "sparse"
        app.launchEnvironment["CECY_UI_AI"] = "success"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Settings"].tap()
        let support = app.buttons["contactSupport"]
        for _ in 0..<5 {
            if support.exists && support.isHittable && support.frame.maxY < app.tabBars.firstMatch.frame.minY { break }
            app.swipeUp()
        }
        XCTAssertTrue(support.isHittable)
        support.tap()
        XCTAssertTrue(app.navigationBars["Contact support"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["supportEmailAddress"].label, "support@thabo.xyz")
        XCTAssertTrue(app.buttons["emailSupport"].isEnabled)
        let copy = app.buttons["copySupportEmail"]
        XCTAssertTrue(copy.isHittable)
        copy.tap()
        XCTAssertEqual(app.staticTexts["supportStatus"].label, "Email address copied.")
        // Navigation and copying must never launch a composer or send mail.
        XCTAssertTrue(app.navigationBars["Contact support"].exists)
        app.navigationBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }
}