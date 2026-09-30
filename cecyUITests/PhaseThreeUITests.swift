import XCTest

final class PhaseThreeUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(fixture: String = "history") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = fixture
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["logSymptoms"].waitForExistence(timeout: 10))
        app.launchEnvironment.removeValue(forKey: "CECY_UI_FIXTURE")
        return app
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    @MainActor private func choose(_ identifier: String, _ title: String, in app: XCUIApplication) {
        let picker = app.buttons[identifier]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), app.debugDescription)
        reveal(picker, in: app)
        picker.tap()
        app.buttons[title].firstMatch.tap()
    }

    @MainActor private func note(in app: XCUIApplication) -> XCUIElement {
        let field = app.textFields["symptomNotes"]
        return field.exists ? field : app.textViews["symptomNotes"]
    }

    @MainActor private func observations(in app: XCUIApplication) {
        app.tabBars.buttons["Insights"].tap()
        let link = app.buttons["manageObservations"]
        reveal(link, in: app)
        link.tap()
    }

    @MainActor func testTodayObservationDuplicateEditCancelDeleteAndRelaunch() {
        let app = launch()
        let log = app.buttons["logSymptoms"]
        reveal(log, in: app); log.tap()
        XCTAssertFalse(app.buttons["saveSymptom"].isEnabled)
        choose("symptomKind", "Headache", in: app)
        choose("symptomRating", "Moderate", in: app)
        let field = note(in: app)
        field.tap(); field.typeText("Synthetic observation")
        app.buttons["saveSymptom"].tap()
        reveal(log, in: app); log.tap()
        choose("symptomKind", "Headache", in: app)
        XCTAssertFalse(app.buttons["saveSymptom"].isEnabled)
        app.buttons["Cancel"].tap(); app.buttons["Discard changes"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(log.waitForExistence(timeout: 10))
        observations(in: app)
        let edit = app.buttons["editSymptom_headache"]
        reveal(edit, in: app); edit.tap()
        XCTAssertEqual(note(in: app).value as? String, "Synthetic observation")
        note(in: app).tap(); note(in: app).typeText(" discarded")
        app.buttons["Cancel"].tap(); app.buttons["Discard changes"].tap()
        reveal(edit, in: app); edit.tap()
        XCTAssertEqual(note(in: app).value as? String, "Synthetic observation")
        choose("symptomRating", "Severe", in: app)
        app.buttons["saveSymptom"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(log.waitForExistence(timeout: 10))
        observations(in: app)
        reveal(edit, in: app); edit.tap()
        XCTAssertTrue(app.buttons["symptomRating"].label.contains("Severe"))
        app.buttons["Cancel"].tap()
        let delete = app.buttons["deleteSymptom_headache"]
        reveal(delete, in: app); delete.tap()
        app.buttons["Keep observation"].tap()
        delete.tap(); app.buttons["Delete recorded observation"].tap()
        XCTAssertFalse(delete.exists)
        app.terminate(); app.launch()
        XCTAssertTrue(log.waitForExistence(timeout: 10))
        observations(in: app)
        XCTAssertTrue(app.staticTexts["No observations recorded yet."].exists)
    }

    @MainActor func testCalendarRatingsMarkerAndReset() {
        let app = launch()
        app.tabBars.buttons["Calendar"].tap()
        let log = app.buttons["logSymptoms"]
        reveal(log, in: app); log.tap()
        choose("symptomKind", "Energy level", in: app)
        choose("symptomRating", "Low", in: app)
        choose("symptomKind", "Sleep quality", in: app)
        XCTAssertTrue(app.buttons["symptomRating"].label.contains("Not rated"))
        choose("symptomRating", "Good", in: app)
        app.buttons["saveSymptom"].tap()
        let edit = app.buttons["editSymptom_sleepQuality"]
        reveal(edit, in: app); edit.tap()
        XCTAssertTrue(app.buttons["symptomRating"].label.contains("Good"))
        app.buttons["Cancel"].tap()
        for _ in 0..<6 { app.swipeDown() }
        XCTAssertTrue(app.buttons["calendarDay_20260929"].label.contains("1 recorded observations"))
        app.tabBars.buttons["Settings"].tap()
        let reset = app.buttons["deleteAllData"]
        reveal(reset, in: app); reset.tap()
        let confirmation = app.textFields["resetConfirmation"]
        reveal(confirmation, in: app); confirmation.tap(); confirmation.typeText("DELETE")
        let commit = app.buttons["confirmReset"]
        reveal(commit, in: app); commit.tap()
        OnboardingUITestSupport.complete(in: app)
        observations(in: app)
        XCTAssertTrue(app.staticTexts["No observations recorded yet."].exists)
    }

    @MainActor func testPatternEvidenceIsVisible() {
        let app = launch(fixture: "patterns")
        observations(in: app)
        let evidence = app.buttons["Supporting records"].firstMatch
        reveal(evidence, in: app); evidence.tap()
        let text = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Logged:")).firstMatch
        reveal(text, in: app)
        XCTAssertTrue(text.exists)
        XCTAssertTrue(app.staticTexts["Repeated recorded evidence"].exists)
    }
}
