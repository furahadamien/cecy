import XCTest

final class PhaseEightUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(mode: String = "success") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "ai"
        app.launchEnvironment["CECY_UI_AI"] = mode
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 15))
        return app
    }
    @MainActor private func visible(_ element: XCUIElement, app: XCUIApplication) -> Bool {
        guard element.exists, element.isHittable else { return false }
        let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : 70
        let bottom = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY
            : app.tabBars.buttons.firstMatch.isHittable ? app.tabBars.firstMatch.frame.minY : app.frame.maxY - 20
        return element.frame.minY >= top && element.frame.maxY <= bottom
    }
    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        func scroll(up: Bool) {
            let container = app.collectionViews.allElementsBoundByIndex.last(where: { $0.isHittable })
                ?? app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable }) ?? app
            if up { container.swipeUp() } else { container.swipeDown() }
        }
        for _ in 0..<12 {
            if visible(element, app: app) { return }
            scroll(up: true)
        }
        for _ in 0..<12 {
            if visible(element, app: app) { return }
            scroll(up: false)
        }
        XCTAssertTrue(visible(element, app: app), app.debugDescription)
    }
    @MainActor private func tap(_ id: String, app: XCUIApplication) {
        // Today's insights card can expose the same control behind a presented sheet; prefer the other copy.
        let matches = app.buttons.matching(identifier: id).allElementsBoundByIndex
        let behind = app.otherElements["dailyInsightsCard"].buttons.matching(identifier: id).allElementsBoundByIndex.map(\.frame)
        let element = matches.count > 1 ? (matches.first { !behind.contains($0.frame) } ?? app.buttons[id]) : app.buttons[id]
        reveal(element, app: app); element.tap()
    }
    @MainActor private func consent(_ app: XCUIApplication) {
        tap("reviewAIConsent", app: app)
        XCTAssertTrue(app.navigationBars["Optional insights"].waitForExistence(timeout: 5))
        tap("enableAI", app: app)
        XCTAssertTrue(app.navigationBars["Optional insights"].waitForNonExistence(timeout: 5), app.debugDescription)
    }
    @MainActor private func describe(_ app: XCUIApplication, text: String = "Synthetic fatigue and digestive changes") {
        tap("logSymptoms", app: app)
        XCTAssertTrue(app.navigationBars["Log symptoms"].waitForExistence(timeout: 5))
        tap("describeSymptoms", app: app)
        XCTAssertTrue(app.navigationBars["Describe symptoms"].waitForExistence(timeout: 5))
        let field = app.textViews["aiSymptomText"].exists ? app.textViews["aiSymptomText"] : app.textFields["aiSymptomText"]
        reveal(field, app: app); field.tap(); field.typeText(text)
        app.buttons["Hide keyboard"].tap()
    }
    @MainActor private func back(_ app: XCUIApplication) { app.navigationBars.buttons.firstMatch.tap() }
    @MainActor private func output(_ text: String, app: XCUIApplication) {
        let value = app.staticTexts[text]
        XCTAssertTrue(value.waitForExistence(timeout: 10), app.debugDescription)
        reveal(value, app: app)
    }
    @MainActor func testConsentDeclineConfirmSaveRelaunchAndRevoke() {
        let app = launch()
        describe(app)
        tap("reviewAIConsent", app: app)
        tap("declineAI", app: app)
        XCTAssertFalse(app.buttons["normalizeSymptoms"].isEnabled)
        consent(app)
        tap("normalizeSymptoms", app: app)
        XCTAssertTrue(app.staticTexts["Review symptoms before saving"].waitForExistence(timeout: 10), app.debugDescription)
        tap("saveAISymptoms", app: app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Insights"].tap()
        tap("manageObservations", app: app)
        output("Fatigue: 1 recorded days", app: app)
        app.tabBars.buttons["Settings"].tap()
        tap("privacySettings", app: app)
        XCTAssertTrue(app.buttons["disableAI"].waitForExistence(timeout: 5))
        tap("disableAI", app: app)
        XCTAssertTrue(app.buttons["reviewAIConsent"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Settings"].tap()
        tap("privacySettings", app: app)
        XCTAssertTrue(app.buttons["reviewAIConsent"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["disableAI"].exists)
    }
    @MainActor func testExpandedCatalogReviewRequiresExplicitRatingAndSave() {
        let app = launch(mode: "catalogV2")
        describe(app, text: "Synthetic dizziness, vaginal itching, and high sex drive")
        tap("reviewAIConsent", app: app)
        let notice = app.staticTexts["aiExpandedCatalogDisclosure"]
        UIViewport.reveal(notice, in: app)
        XCTAssertTrue(notice.label.contains("sensitive health details"))
        UIViewport.reveal(app.buttons["enableAI"], in: app)
        app.buttons["enableAI"].tap()
        XCTAssertTrue(app.navigationBars["Optional insights"].waitForNonExistence(timeout: 5))
        tap("normalizeSymptoms", app: app)
        XCTAssertTrue(app.staticTexts["Review symptoms before saving"].waitForExistence(timeout: 10))
        for id in ["aiSymptom_dizziness", "aiSymptom_vaginalItching", "aiSymptom_libido"] {
            let choice = app.buttons[id]
            UIViewport.reveal(choice, in: app)
            XCTAssertTrue(choice.isSelected)
        }
        let rating = app.buttons["aiSymptomRating_libido"]
        UIViewport.reveal(rating, in: app)
        XCTAssertTrue(rating.label.contains("Not rated"))
        rating.tap()
        app.buttons["High"].firstMatch.tap()
        XCTAssertTrue(rating.label.contains("High"))
        UIViewport.reveal(app.buttons["saveAISymptoms"], in: app)
        app.buttons["saveAISymptoms"].tap()
        XCTAssertTrue(app.buttons["saveAISymptoms"].waitForNonExistence(timeout: 15))
        app.launchEnvironment.removeValue(forKey: "CECY_UI_FIXTURE")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 15))
        tap("editDaySymptoms", app: app)
        let edit = app.buttons["chooseDaySymptom_libido"]
        UIViewport.reveal(edit, in: app); edit.tap()
        let stored = app.buttons["symptomRating_libido"]
        UIViewport.reveal(stored, in: app)
        XCTAssertTrue(stored.label.contains("High"))
    }

    @MainActor func testAllFourReadOnlyFeaturesShowLocalFactsAndAIOutput() {
        let app = launch()
        app.tabBars.buttons["Insights"].tap()
        tap("dailyWellnessAI", app: app)
        XCTAssertTrue(app.staticTexts["localSevereSymptomNotice"].exists || app.otherElements["localSevereSymptomNotice"].exists)
        consent(app)
        tap("generateAI", app: app)
        output("Synthetic self-care suggestion", app: app)
        back(app)
        app.tabBars.buttons["Insights"].tap()
        tap("askCecy", app: app)
        tap("generateAI", app: app)
        output("Synthetic answer from selected facts", app: app)
        back(app)
        tap("cycleSummaryAI_20260804", app: app)
        tap("generateAI", app: app)
        output("Synthetic completed cycle summary", app: app)
        back(app)
        tap("manageObservations", app: app)
        tap("explainInsight_v1.timing.headache", app: app)
        let localInsight = app.otherElements["aiLocalInsight"]
        XCTAssertTrue(localInsight.waitForExistence(timeout: 5))
        let originalFacts = localInsight.staticTexts.allElementsBoundByIndex.map(\.label)
        XCTAssertGreaterThanOrEqual(originalFacts.count, 3)
        tap("generateAI", app: app)
        output("Synthetic insight explanation", app: app)
        output("AI interpretation · Check against your records", app: app)
        reveal(localInsight.staticTexts.firstMatch, app: app)
        XCTAssertEqual(localInsight.staticTexts.allElementsBoundByIndex.map(\.label), originalFacts)
    }

    @MainActor func testLocalInsightSurvivesDeclinedConsentAndFailedExplanation() {
        let app = launch(mode: "failure")
        app.tabBars.buttons["Insights"].tap()
        tap("manageObservations", app: app)
        tap("explainInsight_v1.timing.headache", app: app)
        let localInsight = app.otherElements["aiLocalInsight"]
        XCTAssertTrue(localInsight.waitForExistence(timeout: 5))
        let originalFacts = localInsight.staticTexts.allElementsBoundByIndex.map(\.label)
        XCTAssertGreaterThanOrEqual(originalFacts.count, 3)
        tap("reviewAIConsent", app: app)
        tap("declineAI", app: app)
        XCTAssertFalse(app.buttons["generateAI"].isEnabled)
        reveal(localInsight.staticTexts.firstMatch, app: app)
        XCTAssertEqual(localInsight.staticTexts.allElementsBoundByIndex.map(\.label), originalFacts)
        consent(app)
        tap("generateAI", app: app)
        XCTAssertTrue(app.staticTexts["aiError"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.otherElements["aiOutput"].exists)
        reveal(localInsight.staticTexts.firstMatch, app: app)
        XCTAssertEqual(localInsight.staticTexts.allElementsBoundByIndex.map(\.label), originalFacts)
    }
    @MainActor func testNetworkFailurePreservesDescriptionAndManualTracking() {
        let app = launch(mode: "failure")
        describe(app)
        consent(app)
        XCTAssertTrue(app.buttons["normalizeSymptoms"].isEnabled)
        tap("normalizeSymptoms", app: app)
        let failure = app.staticTexts["aiError"]
        UIViewport.reveal(failure, in: app)
        XCTAssertTrue(failure.waitForExistence(timeout: 10))
        XCTAssertFalse(app.progressIndicators["aiLoading"].exists)
        let field = app.descendants(matching: .any).matching(identifier: "aiSymptomText").firstMatch
        UIViewport.reveal(field, in: app, searchEarlierFirst: true)
        XCTAssertTrue((field.value as? String)?.contains("Synthetic fatigue") == true)
        tap("aiManualFallback", app: app)
        let fatigue = app.buttons.matching(NSPredicate(format: "label == %@", "Fatigue")).firstMatch
        reveal(fatigue, app: app); fatigue.tap()
        tap("saveAISymptoms", app: app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Insights"].tap()
        tap("manageObservations", app: app)
        output("Fatigue: 1 recorded days", app: app)
    }
    @MainActor func testCancellationAndBackgroundDiscardUnsavedRequest() {
        let app = launch(mode: "slow")
        describe(app)
        consent(app)
        tap("normalizeSymptoms", app: app)
        tap("cancelAIRequest", app: app)
        XCTAssertFalse(app.buttons["saveAISymptoms"].exists)
        tap("normalizeSymptoms", app: app)
        XCUIDevice.shared.press(.home)
        app.activate()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["logPeriod"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Insights"].tap()
        tap("manageObservations", app: app)
        XCTAssertFalse(app.staticTexts["Fatigue: 1 recorded days"].exists)
    }
}
