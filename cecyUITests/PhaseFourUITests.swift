import XCTest

final class PhaseFourUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = fixture
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor func testSparseReplayChecksAvailableIntervalsWithoutInventedAccuracy() {
        let app = launch(fixture: "history")
        app.tabBars.buttons["Insights"].tap()
        app.buttons["predictionReplayLink"].tap()
        XCTAssertTrue(app.staticTexts["replayDisclosure"].waitForExistence(timeout: 5))
        let coverage = app.staticTexts["replayCoverage"]
        reveal(coverage, in: app)
        XCTAssertEqual(coverage.label, "2 of 2 checked starts inside their windows")
        let empty = app.staticTexts["replayEmpty"]
        XCTAssertFalse(empty.exists)
    }

    @MainActor func testSourceDatesConfidenceAndReconstructedEvidence() {
        let app = launch(fixture: "patterns")
        let explain = app.buttons["How this estimate works"]
        reveal(explain, in: app); explain.tap()
        let reason = app.staticTexts["confidenceReason"]
        reveal(reason, in: app)
        XCTAssertTrue(reason.label.contains("Fewer than six"))
        let dates = app.staticTexts["Source dates"]
        reveal(dates, in: app)
        XCTAssertTrue(dates.exists)
        let history = app.buttons["predictionReplayLink"]
        reveal(history, in: app); history.tap()
        XCTAssertTrue(app.staticTexts["replayDisclosure"].waitForExistence(timeout: 5))
        let coverage = app.staticTexts["replayCoverage"]
        reveal(coverage, in: app)
        XCTAssertEqual(coverage.label, "4 of 4 checked starts inside their windows")
        let sources = app.buttons["Source intervals"].firstMatch
        reveal(sources, in: app); sources.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Recorded next start:")).firstMatch.exists)
    }
}
