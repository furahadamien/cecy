import XCTest

final class InsightsRefreshUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(fixture: String = "sparse") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = fixture
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Insights"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Insights"].tap()
        return app
    }

    @MainActor func testCoverageRangesAndAppointmentRouteRemainAvailable() {
        let app = launch()
        let coverage = app.staticTexts["recordingCoverage"]
        XCTAssertTrue(coverage.waitForExistence(timeout: 5))
        XCTAssertTrue(coverage.label.contains("of 30"))
        app.segmentedControls.buttons["90 days"].tap()
        XCTAssertTrue(coverage.label.contains("of 90"))
        app.segmentedControls.buttons["30 days"].tap()
        XCTAssertTrue(coverage.label.contains("of 30"))
        for title in ["Bleeding", "Spotting", "No bleeding", "Not sure", "Not logged"] {
            XCTAssertTrue(app.descendants(matching: .any)["recordingState_\(title)"].firstMatch.exists)
        }
        let summary = app.buttons["appointmentSummary"]
        UIViewport.reveal(summary, in: app); summary.tap()
        XCTAssertTrue(app.switches["summaryPeriods"].waitForExistence(timeout: 5))
    }

    @MainActor func testSuggestionsKeepConsentGate() {
        let app = launch(fixture: "ai")
        XCTAssertFalse(app.otherElements["aiOutput"].exists)
        let suggestions = app.buttons["dailyWellnessAI"]
        UIViewport.reveal(suggestions, in: app); suggestions.tap()
        UIViewport.reveal(app.buttons["reviewAIConsent"], in: app)
        XCTAssertTrue(app.buttons["reviewAIConsent"].isHittable)
        UIViewport.reveal(app.buttons["generateAI"], in: app)
        XCTAssertFalse(app.buttons["generateAI"].isEnabled)
    }

    @MainActor func testSuggestionsStillRequireLocalWellnessPreferences() {
        let app = launch()
        let setup = app.buttons["finishInsightSetup"].firstMatch
        UIViewport.reveal(setup, in: app)
        XCTAssertTrue(app.staticTexts["dailyInsightsNeedsSetup"].exists)
        setup.tap()
        XCTAssertTrue(app.navigationBars["Wellness preferences"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["applyWellness"].isEnabled)
        XCTAssertFalse(app.buttons["generateAI"].exists)
    }
}
