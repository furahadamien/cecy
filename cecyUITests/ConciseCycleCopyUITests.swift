import XCTest

final class ConciseCycleCopyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testPhaseRingAndForecastsKeepEssentialCopy() {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "sparse"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 30))
        let fertile = app.staticTexts["phaseFertileWindow"]
        UIViewport.reveal(fertile, in: app)
        XCTAssertNotNil(fertile.label.range(of: "^Estimated fertile window: days [0-9]+–[0-9]+$", options: .regularExpression))
        let ring = app.otherElements["cyclePhaseRing"]
        for text in ["Solid inner arc", "not a multi-day", "Calendar estimates—not confirmed"] {
            XCTAssertFalse(ring.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch.exists)
        }
        let summary = app.descendants(matching: .any).matching(identifier: "phaseRingSummary").firstMatch
        XCTAssertTrue((summary.value as? String ?? "").contains("Today: day 28"))
        let phase = app.buttons["cyclePhase_follicular"]
        UIViewport.reveal(phase, in: app); phase.tap()
        XCTAssertTrue(app.staticTexts["phaseDayRange"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["phaseDayRange"].label, "Estimated days 6–14")
        XCTAssertTrue(app.staticTexts["phaseExplanation"].exists)
        XCTAssertTrue(app.staticTexts["phaseExperiences"].exists)
        for text in ["Biologically, the follicular phase", "Timing comes from", "Experiences vary"] {
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch.exists)
        }
        app.buttons["Done"].tap()
        XCTAssertFalse(app.otherElements["todayEstimates"].exists)
        UIViewport.reveal(app.buttons["dailyWellnessAI"], in: app)
        XCTAssertTrue(app.otherElements["dailyInsightsCard"].exists)
        for tab in ["Today", "Calendar"] {
            app.tabBars.buttons[tab].tap()
            let forecast = app.otherElements["upcomingCycleForecast"]
            let label = forecast.staticTexts["Possible period start · Estimate"]
            UIViewport.reveal(label, in: app)
            XCTAssertTrue(label.isHittable)
            XCTAssertFalse(forecast.buttons["How this forecast works"].exists)
            XCTAssertFalse(forecast.buttons["Bleeding timing uncertainty"].exists)
            XCTAssertFalse(forecast.buttons["ovulationUncertainty_0"].exists)
        }
    }
}
