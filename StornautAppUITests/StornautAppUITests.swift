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
                settingsButton.click()
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
    private func verifyShellAndSettings(
        appearance: String,
        screenshotSuffix: String,
        openSettings: (XCUIApplication, XCUIElement) -> Void
    ) throws {
        let app = XCUIApplication()
        app.terminate()
        addTeardownBlock {
            app.terminate()
        }
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "--stornaut-ui-test-appearance=\(appearance)",
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

        addScreenshot(
            settingsContent.screenshot(),
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
}
