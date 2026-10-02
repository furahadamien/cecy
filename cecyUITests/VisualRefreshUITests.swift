import XCTest

final class VisualRefreshUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_FIXTURE"] = "ai"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<20 {
            let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : app.frame.minY + 64
            let bottom = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : app.frame.maxY
            if element.exists && element.isHittable && element.frame.minY >= top && element.frame.maxY <= bottom { return }
            let container = app.collectionViews.allElementsBoundByIndex.last(where: { $0.isHittable })
                ?? app.scrollViews.allElementsBoundByIndex.first(where: { $0.isHittable && $0.identifier != "todayDateStrip" }) ?? app
            if element.exists && element.frame.maxY > top && element.frame.minY < bottom {
                let delta = element.frame.minY < top ? top + 16 - element.frame.minY : bottom - 16 - element.frame.maxY
                let distance = min(abs(delta), (bottom - top) / 2)
                let startY = delta > 0 ? top + 24 : bottom - 24
                let start = app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: app.frame.midX, dy: startY))
                let end = start.withOffset(CGVector(dx: 0, dy: delta > 0 ? distance : -distance))
                start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
            } else if element.exists && element.frame.minY < top { container.swipeDown() } else { container.swipeUp() }
        }
        XCTFail("Could not reveal \(element)\n\(app.debugDescription)")
    }

    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor private func checkTabs(in app: XCUIApplication) {
        for title in ["Today", "Calendar", "Insights", "Settings"] {
            let tab = app.tabBars.buttons[title]
            XCTAssertTrue(tab.exists && tab.isHittable, title)
            XCTAssertGreaterThanOrEqual(tab.frame.height, 44, title)
        }
    }

    @MainActor func testNativeTabsSheetsAndAppearance() {
        let app = launch()
        checkTabs(in: app)
        capture("Today · Light", app: app)
        let log = app.buttons["logPeriod"]
        reveal(log, in: app)
        checkTabs(in: app) // Labels stay available while content scrolls.
        log.tap()
        XCTAssertTrue(app.buttons["savePeriod"].waitForExistence(timeout: 5))
        capture("Period editor", app: app)
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.buttons["calendarDay_20260929"].waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(app.buttons["calendarDay_20260929"].frame.height, 44)
        capture("Calendar · Light", app: app)
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.buttons["askCecy"].waitForExistence(timeout: 5))
        capture("Insights · Light", app: app)
        app.buttons["askCecy"].tap()
        XCTAssertTrue(app.navigationBars["Ask about your records"].waitForExistence(timeout: 5))
        // Changing tabs must not reset another tab's NavigationStack.
        app.tabBars.buttons["Today"].tap()
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.navigationBars["Ask about your records"].exists)

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["profileSettings"].waitForExistence(timeout: 5))
        capture("Settings · Light", app: app)
        let dark = app.switches["darkMode"]
        reveal(dark, in: app)
        if dark.value as? String != "1" {
            // SwiftUI exposes the whole labeled row; the native thumb is trailing.
            dark.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: dark)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        capture("Settings · Dark", app: app)
        app.tabBars.buttons["Today"].tap()
        checkTabs(in: app)
        capture("Today · Dark", app: app)
    }

    @MainActor func testLargestTextKeepsSelectionAndLoggingReachable() {
        let app = launch(largeText: true)
        app.tabBars.buttons["Calendar"].tap()
        let day = app.buttons["calendarDay_20260929"]
        reveal(day, in: app)
        XCTAssertTrue(day.isSelected)
        XCTAssertGreaterThanOrEqual(day.frame.height, 44)
        capture("Calendar · Accessibility XXXL", app: app)
        let log = app.buttons["logSymptoms"]
        reveal(log, in: app)
        log.tap()
        XCTAssertTrue(app.navigationBars["Log symptoms"].waitForExistence(timeout: 5))
        let choice = app.buttons["symptomKind_headache"]
        reveal(choice, in: app)
        XCTAssertGreaterThanOrEqual(choice.frame.height, 44)
        XCTAssertGreaterThanOrEqual(choice.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(choice.frame.maxX, app.frame.maxX)
        choice.tap()
        XCTAssertEqual(choice.value as? String, "Selected")
        capture("Symptom selection · Accessibility XXXL", app: app)
    }
}
