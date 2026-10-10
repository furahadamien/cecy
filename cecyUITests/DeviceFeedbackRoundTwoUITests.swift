import XCTest

final class DeviceFeedbackRoundTwoUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "ai"
        app.launchEnvironment["CECY_UI_AI"] = "success"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<12 {
            let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : app.frame.minY + 64
            let bottom = app.tabBars.firstMatch.isHittable ? app.tabBars.firstMatch.frame.minY : app.frame.maxY - 30
            if element.exists && element.isHittable && element.frame.minY >= top && element.frame.maxY <= bottom { return }
            if app.pickerWheels.firstMatch.exists {
                let downward = element.exists && element.frame.minY < top
                let start = app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: app.frame.minX + 8, dy: (top + bottom) / 2))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: downward ? 120 : -120)),
                            withVelocity: .slow, thenHoldForDuration: 0.1)
                continue
            }
            let container = app.collectionViews.allElementsBoundByIndex.last(where: { $0.isHittable })
                ?? app.scrollViews.allElementsBoundByIndex.first(where: { $0.isHittable && $0.identifier != "todayDateStrip" }) ?? app
            if element.exists && element.frame.maxY > top && element.frame.minY < bottom {
                let delta = element.frame.minY < top ? top + 16 - element.frame.minY : bottom - 16 - element.frame.maxY
                let distance = min(abs(delta), (bottom - top) / 2)
                let start = app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: app.frame.midX, dy: delta > 0 ? top + 24 : bottom - 24))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta > 0 ? distance : -distance)),
                            withVelocity: .slow, thenHoldForDuration: 0.1)
            } else if element.exists && element.frame.minY < top { container.swipeDown() } else { container.swipeUp() }
        }
        XCTFail("Could not reveal \(element)")
    }

    @MainActor private func tap(_ id: String, app: XCUIApplication) {
        if id == "dailyWellnessAI" { app.tabBars.buttons["Insights"].tap() }
        let button = app.buttons[id]
        reveal(button, app: app)
        button.tap()
    }

    @MainActor func testWellnessAppearsInInsightsAndSharesDailyResultUntilRelaunch() {
        let app = launch()
        XCTAssertFalse(app.staticTexts["Synthetic gentle movement"].exists)
        tap("dailyWellnessAI", app: app)
        tap("reviewAIConsent", app: app)
        tap("enableAI", app: app)
        XCTAssertTrue(app.navigationBars["Optional insights"].waitForNonExistence(timeout: 5))
        tap("generateAI", app: app)
        let suggestion = app.staticTexts["Synthetic gentle movement"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 10))
        reveal(suggestion, app: app)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Today’s insights"].waitForNonExistence(timeout: 5))
        reveal(suggestion, app: app)
        XCTAssertTrue(suggestion.exists)
        tap("dailyWellnessAI", app: app)
        tap("wellnessPreferencesLink", app: app)
        XCTAssertTrue(app.navigationBars["Wellness preferences"].waitForExistence(timeout: 5))
        app.buttons["cancelWellness"].tap()
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(suggestion.exists)
        app.terminate(); app.launch()
        tap("dailyWellnessAI", app: app)
        XCTAssertTrue(app.staticTexts["Synthetic gentle movement"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["generateAI"].exists)
        let tomorrow = app.staticTexts["New insights tomorrow"].firstMatch
        reveal(tomorrow, app: app)
        XCTAssertTrue(tomorrow.exists)
        XCTAssertFalse(app.buttons["generateAI"].exists)
    }

    @MainActor func testChartsAndScopeChipsAreAvailableWithoutConsent() {
        let app = launch()
        app.tabBars.buttons["Insights"].tap()
        let cycle = app.descendants(matching: .any).matching(identifier: "cycleLengthChart").firstMatch
        XCTAssertTrue(cycle.waitForExistence(timeout: 5))
        let observations = app.descendants(matching: .any).matching(identifier: "observationDaysChart").firstMatch
        XCTAssertTrue(observations.exists)
        tap("askCecy", app: app)
        XCTAssertEqual(app.buttons["aiQuestionScope_cycleLengths"].value as? String, "Selected")
        let row = app.scrollViews["aiQuestionScope"]
        let choice = app.buttons["aiQuestionScope_symptomFrequency"]
        for _ in 0..<4 {
            if choice.isHittable { break }
            row.swipeLeft()
        }
        XCTAssertTrue(choice.isHittable)
        choice.tap()
        XCTAssertEqual(choice.value as? String, "Selected")
        XCTAssertFalse(app.staticTexts["Up to 75 seconds. Your records won’t change."].exists)
    }

    @MainActor func testProfileMeasurementsCollapseAndReopenWithoutChangingValue() {
        let app = launch()
        app.tabBars.buttons["Settings"].tap()
        tap("profileSettings", app: app)
        let units = app.segmentedControls["profileUnits"]
        reveal(units, app: app)
        XCTAssertTrue(units.buttons["Metric"].exists && units.buttons["Imperial"].exists)
        let addOrEdit = app.buttons["profileHeightAdd"].exists ? "profileHeightAdd" : "profileHeightEdit"
        tap(addOrEdit, app: app)
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        XCTAssertTrue(wheel.isHittable)
        wheel.adjust(toPickerWheelValue: "180 cm")
        tap("profileHeightDone", app: app)
        XCTAssertEqual(app.pickerWheels.count, 0)
        app.swipeDown()
        tap("profileHeightEdit", app: app)
        XCTAssertEqual(app.staticTexts["profileHeightValue"].label, "180 cm")
        XCTAssertTrue(app.pickerWheels.firstMatch.exists)
        tap("profileHeightDone", app: app)
        app.navigationBars.buttons["saveProfile"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForNonExistence(timeout: 5))
        tap("profileSettings", app: app)
        reveal(app.staticTexts["profileHeightValue"], app: app)
        XCTAssertEqual(app.staticTexts["profileHeightValue"].label, "180 cm")
        XCTAssertEqual(app.pickerWheels.count, 0)
    }
}
