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
            "--stornaut-ui-test-appearance=light",
            "--stornaut-debug-fixture=limited-permission",
        ]

        app.launch()

        let shellWindow = app.windows["main"]
        XCTAssertTrue(shellWindow.waitForExistence(timeout: 10))
        let phase = element("app.state.phase", in: app)
        XCTAssertTrue(phase.waitForExistence(timeout: 5))
        XCTAssertEqual(phase.label, "limitedPermission")
        let appearanceElement = element("app.appearance", in: app)
        XCTAssertTrue(appearanceElement.waitForExistence(timeout: 5))
        XCTAssertEqual(appearanceElement.label, "light")
        XCTAssertEqual(
            element("app.appearance.requested", in: app).label,
            "light"
        )
        XCTAssertTrue(
            element("overview.status.limitedPermission", in: app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(element("overview.coverage", in: app).exists)
        XCTAssertTrue(element("overview.ledger", in: app).exists)
        XCTAssertTrue(app.descendants(matching: .any)["Unmeasurable"].exists)
        XCTAssertFalse(app.staticTexts[
            "Foundation shell — implementation follows the approved roadmap."
        ].exists)

        focus(shellWindow, in: app)
        addScreenshot(
            shellWindow.screenshot(),
            named: "stornaut-overview-limited"
        )

        let quickScan = element("overview.action.quickScan", in: app)
        XCTAssertTrue(quickScan.waitForExistence(timeout: 5))
        quickScan.click()
        XCTAssertTrue(
            element("scan.state.phase", in: app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertEqual(element("scan.state.phase", in: app).label, "limitedPermission")
        XCTAssertTrue(element("scan.results.table", in: app).exists)
        XCTAssertTrue(element("scan.review.unavailable", in: app).exists)
        XCTAssertFalse(app.staticTexts[
            "Foundation shell — implementation follows the approved roadmap."
        ].exists)
    }

    @MainActor
    func testChineseOverviewLocalization() throws {
        let app = XCUIApplication()
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
        addTeardownBlock {
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 5)
        }
        app.launchArguments = [
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN",
            "--stornaut-ui-test-appearance=light",
            "--stornaut-debug-fixture=success",
        ]

        app.launch()

        let shellWindow = app.windows["main"]
        XCTAssertTrue(shellWindow.waitForExistence(timeout: 10))
        XCTAssertTrue(
            element("overview.metric.free", in: app)
                .waitForExistence(timeout: 5)
        )
        let appearanceElement = element("app.appearance", in: app)
        XCTAssertTrue(appearanceElement.waitForExistence(timeout: 5))
        XCTAssertEqual(appearanceElement.label, "light")
        XCTAssertEqual(
            element("app.appearance.requested", in: app).label,
            "light"
        )
        XCTAssertTrue(app.staticTexts["空间账本"].exists)
        XCTAssertTrue(app.staticTexts["安全暂停"].exists)
        XCTAssertTrue(app.buttons["快速扫描"].exists)
        XCTAssertFalse(app.staticTexts["Space Ledger"].exists)

        focus(shellWindow, in: app)
        addScreenshot(
            shellWindow.screenshot(),
            named: "stornaut-overview-zh-Hans"
        )
    }

    @MainActor
    func testQuickScanProgressResultsAndInspector() throws {
        let progress = launchScanFixture(
            fixture: "loading",
            appearance: "dark"
        )
        defer {
            progress.app.terminate()
            _ = progress.app.wait(for: .notRunning, timeout: 5)
        }

        XCTAssertTrue(
            element("scan.state.phase", in: progress.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertEqual(element("scan.state.phase", in: progress.app).label, "active")
        XCTAssertTrue(
            element("scan.action.stop", in: progress.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("scan.currentScope", in: progress.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("scan.stage.classifyArtifacts", in: progress.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("scan.metric.scope", in: progress.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("scan.metric.candidates", in: progress.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("scan.metric.measured", in: progress.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("scan.metric.elapsed", in: progress.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("scan.results.table", in: progress.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(progress.app.buttons["Trash"].exists)
        XCTAssertFalse(progress.app.buttons["Investigate with Codex"].exists)
        focusScan(progress.window, in: progress.app)
        addScreenshot(
            progress.window.screenshot(),
            named: "stornaut-scan-progress-dark"
        )

        progress.app.terminate()
        XCTAssertTrue(progress.app.wait(for: .notRunning, timeout: 5))

        let partial = launchScanFixture(
            fixture: "partial",
            appearance: "light"
        )
        defer {
            partial.app.terminate()
            _ = partial.app.wait(for: .notRunning, timeout: 5)
        }
        XCTAssertTrue(
            element("scan.state.phase", in: partial.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertEqual(element("scan.state.phase", in: partial.app).label, "partial")
        XCTAssertTrue(
            element("scan.terminalStatus", in: partial.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("scan.results.table", in: partial.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("scan.action.start", in: partial.app)
                .waitForExistence(timeout: 5)
        )
        focusScan(partial.window, in: partial.app)
        addScreenshot(
            partial.window.screenshot(),
            named: "stornaut-scan-partial-light"
        )

        partial.app.terminate()
        XCTAssertTrue(partial.app.wait(for: .notRunning, timeout: 5))

        let completed = launchScanFixture(
            fixture: "success",
            appearance: "light"
        )
        defer {
            completed.app.terminate()
            _ = completed.app.wait(for: .notRunning, timeout: 5)
        }
        XCTAssertTrue(
            element("scan.state.phase", in: completed.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertEqual(element("scan.state.phase", in: completed.app).label, "completed")
        XCTAssertTrue(
            element("scan.results.table", in: completed.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("scan.summary", in: completed.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("scan.review.unavailable", in: completed.app)
                .waitForExistence(timeout: 5)
        )

        let buildRow = completed.app.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "identifier BEGINSWITH 'scan.row.'"
                )
            )
            .firstMatch
        XCTAssertTrue(buildRow.waitForExistence(timeout: 5))
        buildRow.click()
        XCTAssertTrue(
            element("scan.inspector", in: completed.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            completed.app.staticTexts["Library/Caches/build"].exists
        )
        XCTAssertTrue(
            element("scan.inspector.deepDivePaused", in: completed.app).exists
        )
        XCTAssertFalse(completed.app.buttons["Move to Trash"].exists)
        completed.app.activate()
        XCTAssertTrue(completed.window.waitForExistence(timeout: 5))
        addScreenshot(
            completed.window.screenshot(),
            named: "stornaut-scan-results-inspector-light"
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
            "--stornaut-debug-fixture=success",
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
        XCTAssertTrue(
            element("overview.metric.free", in: app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(element("overview.metric.free", in: app).exists)
        XCTAssertTrue(element("overview.metric.explained", in: app).exists)
        XCTAssertTrue(element("overview.metric.ready", in: app).exists)
        XCTAssertTrue(element("overview.coverage", in: app).exists)
        XCTAssertTrue(element("overview.ledger", in: app).exists)
        XCTAssertTrue(element("overview.probe.paused", in: app).exists)
        XCTAssertTrue(element("overview.deepDive.paused", in: app).exists)
        XCTAssertTrue(element("overview.action.quickScan", in: app).exists)
        XCTAssertFalse(app.staticTexts[
            "Foundation shell — implementation follows the approved roadmap."
        ].exists)

        let settingsButton = element("sidebar.settings", in: app)
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))

        focus(shellWindow, in: app)
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
            XCTAssertTrue(waitUntil(timeout: 5) {
                settingsButton.isHittable
            })
            settingsButton.click()
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
    private func launchScanFixture(
        fixture: String,
        appearance: String
    ) -> (app: XCUIApplication, window: XCUIElement) {
        let app = XCUIApplication()
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "--stornaut-ui-test-appearance=\(appearance)",
            "--stornaut-debug-fixture=\(fixture)",
        ]
        app.launch()
        let window = app.windows["main"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let scanItem = element("sidebar.scan", in: app)
        XCTAssertTrue(scanItem.waitForExistence(timeout: 5))
        app.activate()
        XCTAssertTrue(waitUntil(timeout: 5) {
            scanItem.isHittable
        })
        scanItem.click()
        return (app, window)
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
    private func focus(
        _ window: XCUIElement,
        in app: XCUIApplication
    ) {
        app.activate()
        let overviewItem = element("sidebar.overview", in: app)
        XCTAssertTrue(waitUntil(timeout: 5) {
            overviewItem.isHittable
        })
        overviewItem.click()
        XCTAssertTrue(waitUntil(timeout: 5) {
            window.isHittable
        })
    }

    @MainActor
    private func focusScan(
        _ window: XCUIElement,
        in app: XCUIApplication
    ) {
        app.activate()
        let scanItem = element("sidebar.scan", in: app)
        XCTAssertTrue(waitUntil(timeout: 5) {
            scanItem.isHittable
        })
        scanItem.click()
        XCTAssertTrue(waitUntil(timeout: 5) {
            window.isHittable
        })
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
