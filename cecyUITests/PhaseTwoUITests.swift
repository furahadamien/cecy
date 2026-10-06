import XCTest

final class PhaseTwoUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "history"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.staticTexts["cycleDay"].waitForExistence(timeout: 10))
        // Seed only this first launch; subsequent launches must demonstrate actual persistence.
        app.launchEnvironment.removeValue(forKey: "CECY_UI_FIXTURE")
        return app
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : app.frame.minY
            let bottom = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY
                : app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : app.frame.maxY
            if element.exists && element.isHittable && element.frame.minY >= top && element.frame.maxY <= bottom { return }
            // A full-screen swipe starts on the keyboard when it is open, not on the form.
            let downward = element.exists && element.frame.minY < top
            let height = bottom - top
            guard height > 0 else { break }
            let start = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: app.frame.midX, dy: top + height * (downward ? 0.25 : 0.75)))
            let end = start.withOffset(CGVector(dx: 0, dy: height * (downward ? 0.5 : -0.5)))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTFail("Could not fully reveal \(element)\n\(app.debugDescription)")
    }

    @MainActor private func notes(in app: XCUIApplication) -> XCUIElement {
        let field = app.textFields["periodNotes"]
        return field.exists ? field : app.textViews["periodNotes"]
    }

    @MainActor func testEditMetadataEndAndCancelSurviveRelaunch() {
        let app = launch()
        UIViewport.reveal(app.buttons["dailyLogHistory"], in: app)
        app.buttons["dailyLogHistory"].tap()
        let day = app.buttons["dailyLog_20260902"]
        UIViewport.reveal(day, in: app); day.tap()
        let edit = app.buttons["editPeriod"].firstMatch
        reveal(edit, in: app)
        XCTAssertTrue(edit.label.contains("Edit period range"))
        edit.tap()
        let endToggle = app.switches["includeEndDate"]
        XCTAssertTrue(endToggle.waitForExistence(timeout: 5))
        // SwiftUI exposes the labeled row as the switch element; target its trailing control.
        endToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(endToggle.value as? String, "1")
        let note = notes(in: app)
        reveal(note, in: app)
        note.tap()
        note.typeText("Synthetic saved note")
        app.buttons["savePeriod"].tap()
        XCTAssertTrue(app.navigationBars["Edit period"].waitForNonExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["cycleDay"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Insights"].tap()
        let duration = app.staticTexts["averageDuration"]
        reveal(duration, in: app)
        XCTAssertEqual(duration.label, "Average: 1.0 days")
        app.tabBars.buttons["Today"].tap()
        UIViewport.reveal(app.buttons["dailyLogHistory"], in: app)
        app.buttons["dailyLogHistory"].tap()
        UIViewport.reveal(day, in: app); day.tap()
        reveal(edit, in: app)
        edit.tap()
        let savedNote = notes(in: app)
        reveal(savedNote, in: app)
        XCTAssertEqual(savedNote.value as? String, "Synthetic saved note")
        savedNote.tap()
        savedNote.typeText(" discarded")
        app.buttons["Cancel"].tap()
        app.buttons["Discard changes"].tap()
        XCTAssertTrue(app.navigationBars["Edit period"].waitForNonExistence(timeout: 10))
        reveal(edit, in: app)
        edit.tap()
        let unchanged = notes(in: app)
        reveal(unchanged, in: app)
        XCTAssertEqual(unchanged.value as? String, "Synthetic saved note")
    }

    @MainActor func testDeleteCancelThenConfirmRecalculates() {
        let app = launch()
        UIViewport.reveal(app.buttons["dailyLogHistory"], in: app)
        app.buttons["dailyLogHistory"].tap()
        let day = app.buttons["dailyLog_20260902"]
        UIViewport.reveal(day, in: app); day.tap()
        let delete = app.buttons["deletePeriod"].firstMatch
        reveal(delete, in: app)
        XCTAssertEqual(delete.label, "Delete entire period")
        delete.tap()
        XCTAssertTrue(app.alerts.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "not just the selected day")).firstMatch.exists)
        app.buttons["Keep period"].tap()
        XCTAssertTrue(delete.exists)
        delete.tap()
        app.buttons["Delete recorded period"].tap()
        XCTAssertTrue(delete.waitForNonExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["cycleDay"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["cycleDay"].label, "Day 57")
        XCTAssertTrue(app.staticTexts["predictionWindow"].exists)
        app.tabBars.buttons["Insights"].tap()
        XCTAssertEqual(app.staticTexts["intervalCount"].label, "2 completed intervals")
    }

    @MainActor func testResetCancelThenConfirmReturnsToDurableOnboarding() {
        let app = launch()
        app.tabBars.buttons["Settings"].tap()
        let reset = app.buttons["deleteAllData"]
        reveal(reset, in: app)
        reset.tap()
        let warning = app.alerts["Delete all data?"]
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        XCTAssertTrue(warning.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "permanently deleted")).firstMatch.exists)
        XCTAssertFalse(app.textFields["resetConfirmation"].exists)
        warning.buttons["Cancel"].tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertEqual(app.staticTexts["cycleDay"].label, "Day 28")
        app.tabBars.buttons["Settings"].tap()
        reveal(reset, in: app)
        reset.tap()
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        warning.buttons["reviewDataDeletion"].firstMatch.tap()
        let confirmation = app.textFields["resetConfirmation"]
        reveal(confirmation, in: app)
        XCTAssertFalse(app.buttons["confirmReset"].isEnabled)
        confirmation.tap()
        confirmation.typeText("DELETE")
        XCTAssertEqual(confirmation.value as? String, "DELETE")
        let commit = app.buttons["confirmReset"]
        reveal(commit, in: app)
        XCTAssertTrue(commit.isEnabled)
        commit.tap()
        XCTAssertTrue(app.buttons["onboardingContinue"].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["onboardingContinue"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.buttons["Today"].exists)
    }
}
