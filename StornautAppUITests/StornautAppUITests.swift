import XCTest

final class StornautAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLightShellAndSettings() throws {
        try verifyShellAndSettings(
            appearance: "light",
            screenshotSuffix: "light",
            openSettings: { app, settingsButton in
                if !settingsButton.isHittable {
                    app.activate()
                }
                XCTAssertTrue(waitUntil(timeout: 5) {
                    settingsButton.isHittable
                })
                settingsButton.click()
                let settingsContent = app.descendants(matching: .any)
                    .matching(identifier: "settings.content")
                    .firstMatch
                if !settingsContent.waitForExistence(timeout: 2) {
                    app.activate()
                    XCTAssertTrue(settingsButton.waitForExistence(timeout: 2))
                    XCTAssertTrue(settingsButton.isHittable)
                    settingsButton.click()
                }
            }
        )
    }

    @MainActor
    func testDarkShellAndSettings() throws {
        try verifyShellAndSettings(
            appearance: "dark",
            screenshotSuffix: "dark",
            openSettings: { app, _ in
                app.typeKey(",", modifierFlags: .command)
            }
        )
    }

    @MainActor
    func testDebugFixtureSelection() throws {
        let app = XCUIApplication()
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
        addTeardownBlock {
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 5)
        }
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "--stornaut-debug-fixture=limited-permission",
        ]

        app.launch()

        let shellWindow = app.windows["main"]
        XCTAssertTrue(shellWindow.waitForExistence(timeout: 10))
        let phase = element("app.state.phase", in: app)
        XCTAssertTrue(phase.waitForExistence(timeout: 5))
        XCTAssertEqual(phase.label, "limitedPermission")
        XCTAssertTrue(app.staticTexts["Overview"].exists)
        XCTAssertTrue(app.staticTexts[
            "Foundation shell — implementation follows the approved roadmap."
        ].exists)
    }

    @MainActor
    private func verifyShellAndSettings(
        appearance: String,
        screenshotSuffix: String,
        openSettings: (XCUIApplication, XCUIElement) -> Void
    ) throws {
        let app = XCUIApplication()
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
        addTeardownBlock {
            self.closeResidualSettingsWindow(in: app)
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 5)
        }
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "--stornaut-ui-test-appearance=\(appearance)",
            "--stornaut-debug-fixture=empty",
        ]

        app.launch()

        let shellWindow = app.windows["main"]
        XCTAssertTrue(shellWindow.waitForExistence(timeout: 10))

        let appearanceElement = element("app.appearance", in: app)
        XCTAssertTrue(appearanceElement.waitForExistence(timeout: 5))
        XCTAssertEqual(appearanceElement.label, appearance)

        for identifier in [
            "sidebar.overview",
            "sidebar.scan",
            "sidebar.investigations",
            "sidebar.history",
        ] {
            XCTAssertTrue(element(identifier, in: app).waitForExistence(timeout: 5))
        }

        XCTAssertTrue(app.staticTexts["Overview"].exists)
        XCTAssertTrue(app.staticTexts["Scan"].exists)
        XCTAssertTrue(app.staticTexts["Investigations"].exists)
        XCTAssertTrue(app.staticTexts["History"].exists)
        XCTAssertFalse(app.staticTexts["destination.overview"].exists)

        let settingsButton = element("sidebar.settings", in: app)
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))

        addScreenshot(
            shellWindow.screenshot(),
            named: "stornaut-shell-\(screenshotSuffix)"
        )

        openSettings(app, settingsButton)

        let settingsContent = element("settings.content", in: app)
        XCTAssertTrue(settingsContent.waitForExistence(timeout: 5))
        let settingsAppearance = element("settings.appearance", in: app)
        XCTAssertTrue(settingsAppearance.waitForExistence(timeout: 5))
        XCTAssertEqual(settingsAppearance.label, appearance)
        let settingsWindow = app.windows
            .containing(.any, identifier: "settings.content")
            .firstMatch
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))
        if !settingsContent.isHittable || !settingsWindow.isHittable {
            app.activate()
            settingsContent.click()
        }
        XCTAssertTrue(waitUntil(timeout: 5) {
            settingsContent.isHittable && settingsWindow.isHittable
        })

        addScreenshot(
            settingsWindow.screenshot(),
            named: "stornaut-settings-\(screenshotSuffix)"
        )
    }

    @MainActor
    private func element(
        _ identifier: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    private func addScreenshot(
        _ screenshot: XCUIScreenshot,
        named name: String
    ) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func waitUntil(
        timeout: TimeInterval,
        condition: () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        return condition()
    }

    @MainActor
    private func closeResidualSettingsWindow(in app: XCUIApplication) {
        let settingsContent = element("settings.content", in: app)
        guard settingsContent.exists else {
            return
        }
        let settingsWindow = app.windows
            .containing(.any, identifier: "settings.content")
            .firstMatch
        if settingsWindow.exists {
            settingsWindow.typeKey("w", modifierFlags: .command)
        }
    }
}
