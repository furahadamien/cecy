import XCTest

final class TodayDetailsAndWelcomeUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "sparse"
        app.launchEnvironment["CECY_UI_APPLE_AUTH"] = "success"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 10))
        app.launchEnvironment.removeValue(forKey: "CECY_UI_FIXTURE")
        return app
    }

    @MainActor private func tap(_ button: XCUIElement, in app: XCUIApplication) {
        UIViewport.reveal(button, in: app)
        button.tap()
    }

    @MainActor private func signOut(in app: XCUIApplication) {
        app.tabBars.buttons["Settings"].tap()
        tap(app.buttons["accountSettings"], in: app)
        tap(app.buttons["continueWithApple"], in: app)
        let logout = app.buttons["logOut"]
        XCTAssertTrue(logout.waitForExistence(timeout: 5))
        app.navigationBars["Apple Account"].buttons.element(boundBy: 0).tap()
        let account = app.buttons["accountSettings"]
        XCTAssertTrue(account.waitForExistence(timeout: 5))
        XCTAssertTrue(account.label.contains("Connected"))
        XCTAssertFalse(account.label.contains("Identity only"))
        tap(account, in: app)
        let status = app.descendants(matching: .any)["appleAccountStatus"].firstMatch
        XCTAssertTrue(status.exists)
        let explanation = app.staticTexts["appleAccountIdentityExplanation"]
        XCTAssertTrue(explanation.exists)
        XCTAssertEqual(explanation.label, "Your Apple Account identifies you so you can access your records on this device.")
        XCTAssertGreaterThanOrEqual(explanation.frame.minY, status.frame.maxY)
        XCTAssertTrue(logout.isHittable)
        XCTAssertGreaterThanOrEqual(logout.frame.height, 44)
        XCTAssertEqual(logout.frame.midX, app.frame.midX, accuracy: 2)
        XCTAssertGreaterThan(logout.frame.minY, app.frame.height * 0.65)
        XCTAssertLessThanOrEqual(logout.frame.maxY, app.tabBars.firstMatch.frame.minY - 32)
        XCTAssertFalse(app.buttons["continueWithApple"].exists)
        XCTAssertFalse(app.staticTexts["appleSignInPurpose"].exists)
        for removedText in ["Your Apple identity is stored securely", "Keeps your local records",
                            "Change or remove your account", "Use Delete all data in Settings",
                            "This does not delete your Apple Account", "Revoking authorization"] {
            XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", removedText)).firstMatch.exists)
        }
        tap(logout, in: app)
        let confirmation = app.alerts["Log out of Cecy?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.buttons["Cancel"].tap()
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5))
        XCTAssertTrue(status.exists)
        XCTAssertTrue(logout.isEnabled)
        XCTAssertFalse(app.staticTexts["signedOutScreen"].exists)
        tap(logout, in: app)
        app.alerts.buttons["confirmLogout"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["signedOutScreen"].waitForExistence(timeout: 5))
    }

    @MainActor func testSelectedRecordsSitAboveHistoryAndKeepEditing() {
        let app = launch()
        app.buttons["expandTodayCalendar"].tap()
        app.buttons["todayMonthDate_20260902"].tap()
        app.buttons["expandTodayCalendar"].tap()
        let card = app.otherElements["todayRecordedDayCard"]
        UIViewport.reveal(card, in: app)
        XCTAssertTrue(card.staticTexts["September 2, 2026"].firstMatch.exists)
        XCTAssertTrue(card.staticTexts["Recorded period start"].exists)
        XCTAssertGreaterThan(card.frame.minY, app.otherElements["upcomingCycleForecast"].frame.maxY)
        XCTAssertFalse(app.buttons["sexualActivityHistory"].exists)
        let edit = app.buttons["editPeriod"].firstMatch
        UIViewport.reveal(edit, in: app)
        edit.tap()
        XCTAssertTrue(app.navigationBars["Edit period"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Edit period"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["September 2, 2026"].firstMatch.exists)
    }

    @MainActor func testSaveConfirmationIsBelowForecastAndRecordPersists() {
        let app = launch()
        app.buttons["logSymptoms"].tap()
        tap(app.buttons["symptomKind_headache"], in: app)
        app.buttons["saveSymptom"].tap()
        XCTAssertTrue(app.navigationBars["Log symptoms"].waitForNonExistence(timeout: 10))
        let confirmation = app.descendants(matching: .any)["saveConfirmation"].firstMatch
        UIViewport.reveal(confirmation, in: app)
        XCTAssertGreaterThan(confirmation.frame.minY, app.otherElements["upcomingCycleForecast"].frame.maxY)
        let dismiss = app.buttons["Dismiss confirmation"]
        UIViewport.reveal(dismiss, in: app)
        XCTAssertFalse(app.buttons["sexualActivityHistory"].exists)
        dismiss.tap()
        XCTAssertFalse(confirmation.exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["todayDate_20260929"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["todayDate_20260929"].label.contains("Headache"))
    }

    @MainActor func testWelcomeRetainsProfileSignInAndDeletionSafeguards() {
        let app = launch()
        signOut(in: app)
        XCTAssertTrue(app.staticTexts["Welcome back"].exists)
        XCTAssertTrue(app.staticTexts["signedOutScreen"].label.contains("A profile is already saved on this device"))
        XCTAssertFalse(app.staticTexts["You’re logged out"].exists)
        XCTAssertFalse(app.staticTexts["appleSignInPurpose"].exists)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Keychain")).firstMatch.exists)
        XCTAssertTrue(app.buttons["continueWithApple"].isHittable)
        let apple = app.buttons["continueWithApple"]
        XCTAssertEqual(apple.frame.midX, app.frame.midX, accuracy: 2)
        XCTAssertLessThan(abs(apple.frame.midY - app.frame.midY), app.frame.height * 0.12)
        let reset = app.buttons["signedOutReset"]
        XCTAssertEqual(reset.label, "Delete local data and start over")
        XCTAssertGreaterThanOrEqual(reset.frame.height, 44)
        XCTAssertLessThan(reset.frame.width, apple.frame.width)
        XCTAssertGreaterThan(reset.frame.minY, app.frame.height * 0.75)
        tap(reset, in: app)
        XCTAssertTrue(app.navigationBars["Delete all data?"].waitForExistence(timeout: 5))
        let confirmation = app.textFields["resetConfirmation"]
        UIViewport.reveal(confirmation, in: app)
        XCTAssertTrue(confirmation.exists)
        let commit = app.buttons["confirmReset"]
        UIViewport.reveal(commit, in: app)
        XCTAssertFalse(commit.isEnabled)
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["signedOutScreen"].exists)
        app.terminate()
        app.launchEnvironment["CECY_UI_APPLE_AUTH"] = "cancel"
        app.launch()
        XCTAssertTrue(app.buttons["continueWithApple"].waitForExistence(timeout: 10))
        app.buttons["continueWithApple"].tap()
        XCTAssertTrue(app.staticTexts["signedOutScreen"].exists)
        XCTAssertFalse(app.tabBars.buttons["Today"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Sign-in was cancelled")).firstMatch.exists)
        app.terminate()
        app.launchEnvironment["CECY_UI_APPLE_AUTH"] = "success"
        app.launch()
        XCTAssertTrue(app.buttons["continueWithApple"].waitForExistence(timeout: 10))
        app.buttons["continueWithApple"].tap()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["cycleDay"].label, "Day 28")
        app.tabBars.buttons["Settings"].tap()
        tap(app.buttons["profileSettings"], in: app)
        XCTAssertEqual(app.textFields["profileName"].value as? String, "Synthetic Alex")
    }

    @MainActor func testWelcomeButtonsRemainAccessibleAtLargestTextSize() {
        let app = launch(largeText: true)
        signOut(in: app)
        for identifier in ["continueWithApple", "signedOutReset"] {
            let button = app.buttons[identifier]
            UIViewport.reveal(button, in: app)
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertGreaterThanOrEqual(button.frame.minX, 0)
            XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX)
        }
        app.buttons["signedOutReset"].tap()
        XCTAssertTrue(app.navigationBars["Delete all data?"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["signedOutScreen"].exists)
    }
}
