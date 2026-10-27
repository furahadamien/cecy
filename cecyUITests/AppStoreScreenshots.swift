import XCTest

/// Captures App Store screenshots. Run with TEST_RUNNER_SCREENSHOT_DIR (seen as SCREENSHOT_DIR) set to an absolute host path;
/// images are written to <dir>/<width>x<height>/NN_name.png.
final class AppStoreScreenshots: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = true }

    private var directory: URL? {
        ProcessInfo.processInfo.environment["SCREENSHOT_DIR"].map { URL(fileURLWithPath: $0) }
    }

    @MainActor private func launch(fixture: String?) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CECY_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CECY_UI_APPLE_AUTH"] = "success"
        app.launchEnvironment["CECY_UI_AI"] = "showcase"
        if let fixture { app.launchEnvironment["CECY_UI_FIXTURE"] = fixture }
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        current = app
        return app
    }

    private var current: XCUIApplication?

    @MainActor private func shot(_ name: String) {
        sleep(1) // let animations settle
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
        guard let directory else { return }
        let image = screenshot.image
        let size = "\(Int(image.size.width * image.scale))x\(Int(image.size.height * image.scale))"
        let folder = directory.appendingPathComponent(size, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
        // Text dump of what is on screen, for checking content without opening images.
        let labels = current?.staticTexts.allElementsBoundByIndex.filter { $0.isHittable }.map(\.label).joined(separator: "\n") ?? ""
        try? labels.write(to: folder.appendingPathComponent("\(name).txt"), atomically: true, encoding: .utf8)
    }

    @MainActor private func tab(_ title: String, in app: XCUIApplication) {
        let button = app.tabBars.buttons[title].exists ? app.tabBars.buttons[title].firstMatch : app.buttons[title].firstMatch
        if button.waitForExistence(timeout: 5) { button.tap() }
    }

    @MainActor private func dismissSheet(_ app: XCUIApplication) {
        let cancel = app.navigationBars.buttons["Cancel"].firstMatch
        if cancel.waitForExistence(timeout: 5) { cancel.tap() } else { app.swipeDown(velocity: .fast) }
        _ = cancel.waitForNonExistence(timeout: 5)
    }

    @MainActor func testCaptureAppStoreScreens() {
        // Onboarding welcome on a fresh install.
        var app = launch(fixture: nil)
        _ = app.buttons["onboardingContinue"].waitForExistence(timeout: 10)
        sleep(1)
        shot("01_welcome")
        app.terminate()

        app = launch(fixture: "showcase")
        _ = app.tabBars.buttons["Today"].waitForExistence(timeout: 15)
        let prepare = app.buttons["prepareDailyInsights"]
        if prepare.waitForExistence(timeout: 3) {
            if !prepare.isHittable { app.swipeUp(velocity: .slow) }
            prepare.tap()
            _ = app.otherElements["dailyInsightsCard"].waitForExistence(timeout: 8)
            app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast)
        }
        shot("02_today")
        let today = app.scrollViews.firstMatch.exists ? app.scrollViews.firstMatch : app.collectionViews.firstMatch
        today.swipeUp(velocity: .slow); today.swipeUp(velocity: .slow)
        shot("03_today_details")
        app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast)

        let checkIn = app.buttons["dailyCheckIn"]
        if checkIn.waitForExistence(timeout: 3) {
            if !checkIn.isHittable { app.swipeUp(velocity: .slow) }
            checkIn.tap()
            shot("04_daily_check_in")
            dismissSheet(app)
        }

        tab("Calendar", in: app)
        shot("05_calendar")

        tab("Insights", in: app)
        shot("06_insights")
        app.swipeUp(velocity: .slow)
        shot("07_insights_charts")

        let summary = app.buttons["appointmentSummary"]
        for _ in 0..<4 where !summary.exists || !summary.isHittable { app.swipeUp(velocity: .slow) }
        if summary.exists && summary.isHittable {
            summary.tap()
            let preview = app.buttons["previewSummary"]
            _ = app.staticTexts["Prepare your visit"].waitForExistence(timeout: 5)
            for _ in 0..<8 where !(preview.exists && preview.isHittable) { app.swipeUp(velocity: .slow) }
            if preview.exists && preview.isHittable {
                preview.tap()
                _ = app.staticTexts["summaryPreviewTitle"].waitForExistence(timeout: 5)
            }
            shot("08_appointment_summary")
        }

        for _ in 0..<3 where !app.tabBars.buttons["Settings"].firstMatch.isHittable {
            let done = app.navigationBars.buttons["Done"].firstMatch
            if done.exists { done.tap() } else { app.swipeDown(velocity: .fast) }
            sleep(1)
        }
        tab("Settings", in: app)
        shot("09_settings")
    }
}
