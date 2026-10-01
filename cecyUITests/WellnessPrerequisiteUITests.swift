import XCTest

final class WellnessPrerequisiteUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "wellness"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        func fullyVisible() -> Bool {
            guard element.exists, element.isHittable else { return false }
            let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : app.frame.minY + 70
            let bottom = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : app.frame.maxY - 40
            return element.frame.minY >= top && element.frame.maxY <= bottom
        }
        if fullyVisible() { return }
        for _ in 0..<4 { app.swipeDown() }
        for _ in 0..<10 {
            if fullyVisible() { return }
            app.swipeUp()
        }
        XCTAssertTrue(fullyVisible(), app.debugDescription)
    }

    @MainActor private func openWellness(_ app: XCUIApplication) {
        app.tabBars.buttons["Settings"].tap()
        if app.navigationBars["Wellness preferences"].exists { return }
        if !app.navigationBars["Profile"].exists {
            let profile = app.buttons["profileSettings"]
            reveal(profile, in: app); profile.tap()
        }
        let wellness = app.buttons["profileWellness"]
        reveal(wellness, in: app); wellness.tap()
        XCTAssertTrue(app.navigationBars["Wellness preferences"].waitForExistence(timeout: 5))
    }

    @MainActor private func choose(_ identifier: String, title: String, in app: XCUIApplication) {
        let picker = app.buttons[identifier]
        reveal(picker, in: app); picker.tap()
        let item = app.buttons[title]
        XCTAssertTrue(item.waitForExistence(timeout: 5), app.debugDescription)
        item.tap()
    }

    @MainActor private func saveProfile(_ app: XCUIApplication) {
        app.buttons["applyWellness"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
        let save = app.buttons["saveProfile"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor func testWellnessSaveRelaunchAndClear() {
        let app = launch()
        openWellness(app)
        choose("wellnessActivity", title: "Moderately active", in: app)
        let walking = app.buttons["wellnessExercise_walking"]
        reveal(walking, in: app); walking.tap()
        choose("wellnessDiet", title: "Vegetarian", in: app)
        choose("wellnessAllergyStatus", title: "List food allergies", in: app)
        let name = app.textFields["foodAllergyName"]
        reveal(name, in: app); name.tap(); name.typeText("Peanuts")
        app.buttons["Hide keyboard"].tap()
        let add = app.buttons["addFoodAllergy"]
        reveal(add, in: app); add.tap()
        XCTAssertTrue(app.buttons["removeFoodAllergy_0"].waitForExistence(timeout: 5), app.debugDescription)
        let goal = app.buttons["wellnessGoal_manageSymptoms"]
        reveal(goal, in: app); goal.tap()
        saveProfile(app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 15))
        openWellness(app)
        let allergy = app.staticTexts["Peanuts"]
        reveal(allergy, in: app)
        XCTAssertTrue(allergy.exists)
        let clear = app.buttons["clearWellness"]
        reveal(clear, in: app); clear.tap()
        app.buttons["Clear preferences"].tap()
        saveProfile(app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 15))
        openWellness(app)
        let status = app.buttons["wellnessAllergyStatus"]
        reveal(status, in: app)
        XCTAssertTrue(status.label.contains("Not answered") || (status.value as? String)?.contains("Not answered") == true)
        XCTAssertFalse(app.staticTexts["Peanuts"].exists)
    }

    @MainActor func testCancellingWellnessDoesNotChangeProfileDraft() {
        let app = launch()
        openWellness(app)
        choose("wellnessActivity", title: "Very active", in: app)
        app.buttons["cancelWellness"].tap()
        app.alerts.buttons["Discard changes"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveProfile"].isEnabled)
        let wellness = app.buttons["profileWellness"]
        reveal(wellness, in: app); wellness.tap()
        let activity = app.buttons["wellnessActivity"]
        XCTAssertTrue(activity.label.contains("Not answered") || (activity.value as? String)?.contains("Not answered") == true)
    }

    @MainActor func testDigestiveSymptomCanBeLoggedAndSurvivesRelaunch() {
        let app = launch()
        let log = app.buttons["logSymptoms"]
        reveal(log, in: app); log.tap()
        XCTAssertTrue(app.navigationBars["Log symptoms"].waitForExistence(timeout: 5), app.debugDescription)
        let digestive = app.buttons.matching(NSPredicate(format: "label == %@", "Digestive changes")).firstMatch
        XCTAssertTrue(digestive.waitForExistence(timeout: 5), app.debugDescription)
        for _ in 0..<5 {
            if digestive.isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(digestive.isHittable, app.debugDescription)
        digestive.tap()
        let save = app.buttons["saveSymptom"]
        XCTAssertTrue(save.isEnabled); save.tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Insights"].tap()
        let observations = app.buttons["manageObservations"]
        reveal(observations, in: app); observations.tap()
        let recorded = app.staticTexts["Digestive changes"].firstMatch
        reveal(recorded, in: app)
        XCTAssertTrue(recorded.exists)
    }
}
