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
        UIViewport.reveal(element, in: app)
    }

    @MainActor private func choose(_ identifier: String, _ title: String, in app: XCUIApplication) {
        let picker = app.buttons[identifier]
        reveal(picker, in: app)
        XCTAssertTrue(picker.exists, app.debugDescription)
        picker.tap()
        app.buttons[title].firstMatch.tap()
    }

    @MainActor private func toggleSymptom(_ kind: String, in app: XCUIApplication) {
        let button = app.buttons["symptomKind_\(kind)"]
        reveal(button, in: app)
        XCTAssertTrue(button.exists)
        button.tap()
    }

    @MainActor private func note(in app: XCUIApplication) -> XCUIElement {
        // A lazy field may not exist yet; do not permanently choose the wrong
        // UIKit element type before scrolling materializes the input.
        app.descendants(matching: .any).matching(identifier: "symptomNotes").firstMatch
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
        toggleSymptom("headache", in: app)
        XCTAssertTrue(app.buttons["symptomKind_headache"].isSelected)
        toggleSymptom("headache", in: app)
        XCTAssertFalse(app.buttons["saveSymptom"].isEnabled)
        toggleSymptom("headache", in: app)
        choose("symptomRating_headache", "Moderate", in: app)
        let field = note(in: app)
        reveal(field, in: app); field.tap(); field.typeText("Synthetic observation")
        app.buttons["saveSymptom"].tap()
        XCTAssertTrue(app.navigationBars["Log symptoms"].waitForNonExistence(timeout: 10))
        reveal(log, in: app); log.tap()
        toggleSymptom("headache", in: app)
        XCTAssertFalse(app.buttons["saveSymptom"].isEnabled)
        app.buttons["Cancel"].tap(); app.buttons["Discard changes"].tap()
        XCTAssertTrue(app.navigationBars["Log symptoms"].waitForNonExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(log.waitForExistence(timeout: 10))
        observations(in: app)
        let edit = app.buttons["editSymptom_headache"]
        reveal(edit, in: app); edit.tap()
        reveal(note(in: app), in: app)
        XCTAssertEqual(note(in: app).value as? String, "Synthetic observation")
        note(in: app).tap(); note(in: app).typeText(" discarded")
        app.buttons["Cancel"].tap(); app.buttons["Discard changes"].tap()
        XCTAssertTrue(app.navigationBars["Edit observation"].waitForNonExistence(timeout: 10))
        reveal(edit, in: app); edit.tap()
        reveal(note(in: app), in: app)
        XCTAssertEqual(note(in: app).value as? String, "Synthetic observation")
        choose("symptomRating_headache", "Severe", in: app)
        app.buttons["saveSymptom"].tap()
        XCTAssertTrue(app.navigationBars["Edit observation"].waitForNonExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(log.waitForExistence(timeout: 10))
        observations(in: app)
        reveal(edit, in: app); edit.tap()
        reveal(app.buttons["symptomRating_headache"], in: app)
        XCTAssertTrue(app.buttons["symptomRating_headache"].label.contains("Severe"))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Edit observation"].waitForNonExistence(timeout: 10))
        let delete = app.buttons["deleteSymptom_headache"]
        reveal(delete, in: app); delete.tap()
        app.buttons["Keep observation"].tap()
        delete.tap(); app.buttons["Delete recorded observation"].tap()
        XCTAssertTrue(delete.waitForNonExistence(timeout: 10))
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
        toggleSymptom("energyLevel", in: app)
        choose("symptomRating_energyLevel", "Low", in: app)
        toggleSymptom("sleepQuality", in: app)
        reveal(app.buttons["symptomRating_sleepQuality"], in: app)
        XCTAssertTrue(app.buttons["symptomRating_sleepQuality"].label.contains("Not rated"))
        choose("symptomRating_sleepQuality", "Good", in: app)
        XCTAssertTrue(app.buttons["symptomRating_energyLevel"].label.contains("Low"))
        app.buttons["saveSymptom"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Calendar"].tap()
        let groupEdit = app.buttons["editDaySymptoms"]
        reveal(groupEdit, in: app); groupEdit.tap()
        let edit = app.buttons["chooseDaySymptom_sleepQuality"]
        reveal(edit, in: app); edit.tap()
        reveal(app.buttons["symptomRating_sleepQuality"], in: app)
        XCTAssertTrue(app.buttons["symptomRating_sleepQuality"].label.contains("Good"))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Edit observation"].waitForNonExistence(timeout: 10))
        let editEnergy = app.buttons["chooseDaySymptom_energyLevel"]
        reveal(editEnergy, in: app); editEnergy.tap()
        reveal(app.buttons["symptomRating_energyLevel"], in: app)
        XCTAssertTrue(app.buttons["symptomRating_energyLevel"].label.contains("Low"))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Edit observation"].waitForNonExistence(timeout: 10))
        app.buttons["Done"].tap()
        for _ in 0..<6 { app.swipeDown() }
        XCTAssertTrue(app.buttons["calendarDay_20260929"].label.contains("2 recorded observations"))
        app.tabBars.buttons["Settings"].tap()
        let reset = app.buttons["deleteAllData"]
        reveal(reset, in: app); reset.tap()
        XCTAssertTrue(app.alerts["Delete all data?"].waitForExistence(timeout: 5))
        app.alerts["Delete all data?"].buttons["reviewDataDeletion"].firstMatch.tap()
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
