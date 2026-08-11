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
    func testHistoryPopulatedExpiredAndCorruptStates() throws {
        let populated = launchHistoryFixture(
            fixture: "populated",
            appearance: "light"
        )
        defer {
            populated.app.terminate()
            _ = populated.app.wait(for: .notRunning, timeout: 5)
        }
        XCTAssertTrue(
            element("history.state.phase", in: populated.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("history.navigator", in: populated.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("history.detail", in: populated.app)
                .waitForExistence(timeout: 5)
        )
        let knownMetric = element(
            "history.ledger.metric.known",
            in: populated.app
        )
        XCTAssertTrue(knownMetric.waitForExistence(timeout: 5))
        XCTAssertEqual(knownMetric.label, "Known")
        XCTAssertTrue(
            element("history.action.delete", in: populated.app).exists
        )
        XCTAssertFalse(populated.app.staticTexts["Cleanup Manifest"].exists)
        focusHistory(populated.window, in: populated.app)
        addScreenshot(
            populated.window.screenshot(),
            named: "stornaut-history-populated-light"
        )

        populated.app.terminate()
        XCTAssertTrue(populated.app.wait(for: .notRunning, timeout: 5))

        let expired = launchHistoryFixture(
            fixture: "expired",
            appearance: "dark"
        )
        defer {
            expired.app.terminate()
            _ = expired.app.wait(for: .notRunning, timeout: 5)
        }
        XCTAssertTrue(
            element("history.state.phase", in: expired.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(expired.app.staticTexts["Expired"].exists)
        XCTAssertTrue(
            element("history.detail", in: expired.app)
                .waitForExistence(timeout: 5)
        )
        focusHistory(expired.window, in: expired.app)
        addScreenshot(
            expired.window.screenshot(),
            named: "stornaut-history-expired-dark"
        )

        expired.app.terminate()
        XCTAssertTrue(expired.app.wait(for: .notRunning, timeout: 5))

        let corrupt = launchHistoryFixture(
            fixture: "corrupt",
            appearance: "light"
        )
        defer {
            corrupt.app.terminate()
            _ = corrupt.app.wait(for: .notRunning, timeout: 5)
        }
        XCTAssertTrue(
            element("history.state.phase", in: corrupt.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element(
                "history.corrupt.scan-fixture-unreadable",
                in: corrupt.app
            ).exists
        )
        XCTAssertTrue(
            element("history.detail", in: corrupt.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            corrupt.app.staticTexts["Quick Scan"].exists
        )
        focusHistory(corrupt.window, in: corrupt.app)
        addScreenshot(
            corrupt.window.screenshot(),
            named: "stornaut-history-corrupt-light"
        )
    }

    @MainActor
    func testHistoryDeleteConfirmationAndStorageTrend() throws {
        let deletion = launchHistoryFixture(
            fixture: "populated",
            appearance: "light"
        )
        defer {
            deletion.app.terminate()
            _ = deletion.app.wait(for: .notRunning, timeout: 5)
        }
        let deleteButton = element(
            "history.action.delete",
            in: deletion.app
        )
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        let recordCountBefore = deletion.app.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "identifier BEGINSWITH 'history.record.'"
                )
            ).count
        deleteButton.click()
        XCTAssertTrue(
            deletion.app.buttons["Delete Record"].waitForExistence(
                timeout: 5
            )
        )
        let confirmationMessage = deletion.app.staticTexts.matching(
            NSPredicate(
                format:
                    "label CONTAINS[c] 'Files, Trash' OR value CONTAINS[c] 'Files, Trash'"
            )
        ).firstMatch
        XCTAssertTrue(confirmationMessage.waitForExistence(timeout: 5))
        let confirmationSheet = deletion.app.sheets.firstMatch
        XCTAssertTrue(confirmationSheet.waitForExistence(timeout: 5))
        confirmationSheet.buttons["Delete Record"].click()
        XCTAssertTrue(waitUntil(timeout: 5) {
            deletion.app.descendants(matching: .any)
                .matching(
                    NSPredicate(
                        format: "identifier BEGINSWITH 'history.record.'"
                    )
                ).count == recordCountBefore - 1
        })
        XCTAssertTrue(element("history.detail", in: deletion.app).exists)

        deletion.app.terminate()
        XCTAssertTrue(deletion.app.wait(for: .notRunning, timeout: 5))

        let trend = launchHistoryFixture(
            fixture: "trend",
            appearance: "dark"
        )
        defer {
            trend.app.terminate()
            _ = trend.app.wait(for: .notRunning, timeout: 5)
        }
        let trendButton = element("history.action.trend", in: trend.app)
        XCTAssertTrue(trendButton.waitForExistence(timeout: 5))
        trendButton.click()
        XCTAssertTrue(
            element("history.trend", in: trend.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            trend.app.staticTexts[
                "Events mark when records were created. They do not prove what caused a storage change."
            ].exists
        )
        XCTAssertTrue(
            element("history.trend.dataTable", in: trend.app).exists
        )
        focusHistory(trend.window, in: trend.app)
        addScreenshot(
            trend.window.screenshot(),
            named: "stornaut-history-trend-dark"
        )
    }

    @MainActor
    func testSettingsSixSectionsAndRepresentativeStates() throws {
        let light = launchSettingsFixture(
            fixture: "populated",
            appearance: "light",
            section: "general"
        )
        defer {
            closeResidualSettingsWindow(in: light.app)
            light.app.terminate()
            _ = light.app.wait(for: .notRunning, timeout: 5)
        }
        for identifier in [
            "settings.sidebar.general",
            "settings.sidebar.scanning",
            "settings.sidebar.permissions",
            "settings.sidebar.codexAndDeepDive",
            "settings.sidebar.privacyAndData",
            "settings.sidebar.localKnowledge",
        ] {
            XCTAssertTrue(
                element(identifier, in: light.app)
                    .waitForExistence(timeout: 5)
            )
        }
        XCTAssertTrue(
            element("settings.page.general", in: light.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(light.app.staticTexts["Background Monitoring"].exists)
        XCTAssertFalse(light.app.buttons["Run Safety Check"].exists)

        selectSettings(.scanning, in: light.app)
        XCTAssertTrue(
            element("settings.page.scanning", in: light.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("settings.scanning.primaryRoot", in: light.app).exists
        )
        addScreenshot(
            light.window.screenshot(),
            named: "stornaut-settings-scanning-light"
        )

        selectSettings(.privacyAndData, in: light.app)
        XCTAssertTrue(
            element("settings.page.privacyAndData", in: light.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("settings.action.clearEvidence", in: light.app).exists
        )
        XCTAssertTrue(
            element("settings.action.clearManifests", in: light.app).exists
        )
        XCTAssertFalse(light.app.steppers["Evidence"].exists)
        addScreenshot(
            light.window.screenshot(),
            named: "stornaut-settings-privacy-light"
        )

        light.app.terminate()
        XCTAssertTrue(light.app.wait(for: .notRunning, timeout: 5))

        let dark = launchSettingsFixture(
            fixture: "populated",
            appearance: "dark",
            section: "codexAndDeepDive"
        )
        defer {
            closeResidualSettingsWindow(in: dark.app)
            dark.app.terminate()
            _ = dark.app.wait(for: .notRunning, timeout: 5)
        }
        XCTAssertTrue(
            element("settings.page.codexAndDeepDive", in: dark.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            dark.app.staticTexts.matching(
                NSPredicate(
                    format:
                        "label CONTAINS[c] 'Paused · Required' OR "
                        + "value CONTAINS[c] 'Paused · Required'"
                )
            ).firstMatch.exists
        )
        XCTAssertFalse(dark.app.buttons["Start Deep Dive"].exists)
        XCTAssertFalse(dark.app.buttons["Trust Codex"].exists)
        addScreenshot(
            dark.window.screenshot(),
            named: "stornaut-settings-codex-dark"
        )

        selectSettings(.localKnowledge, in: dark.app)
        XCTAssertTrue(
            element("settings.page.localKnowledge", in: dark.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            dark.app.descendants(matching: .any)
                .matching(
                    NSPredicate(
                        format:
                            "identifier BEGINSWITH 'settings.knowledge.knowledge-'"
                    )
                ).firstMatch.waitForExistence(timeout: 5)
        )
        XCTAssertFalse(dark.app.textFields["Agent Memory"].exists)
        addScreenshot(
            dark.window.screenshot(),
            named: "stornaut-settings-knowledge-dark"
        )
    }

    @MainActor
    func testSettingsImmediatePreferencesAndConfirmedDeletion() throws {
        let launched = launchSettingsFixture(
            fixture: "populated",
            appearance: "system",
            section: "general"
        )
        defer {
            closeResidualSettingsWindow(in: launched.app)
            launched.app.terminate()
            _ = launched.app.wait(for: .notRunning, timeout: 5)
        }

        let language = element("settings.general.language", in: launched.app)
        XCTAssertTrue(language.waitForExistence(timeout: 5))
        launched.app.activate()
        XCTAssertTrue(waitUntil(timeout: 5) { language.isHittable })
        language.click()
        let simplifiedChinese = launched.app.menuItems[
            "Simplified Chinese"
        ]
        XCTAssertTrue(
            simplifiedChinese.waitForExistence(timeout: 5)
        )
        simplifiedChinese.click()
        XCTAssertTrue(
            launched.app.staticTexts["通用"].waitForExistence(timeout: 5)
        )

        let appearance = element(
            "settings.general.appearance",
            in: launched.app
        )
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        let darkOption = element(
            "settings.general.appearance.dark",
            in: launched.app
        )
        XCTAssertTrue(darkOption.waitForExistence(timeout: 5))
        darkOption.click()
        XCTAssertTrue(waitUntil(timeout: 5) {
            element("settings.appearance", in: launched.app).label == "dark"
        })
        XCTAssertTrue(waitUntil(timeout: 5) {
            element("app.appearance", in: launched.app).label == "dark"
        })

        selectSettings(.privacyAndData, in: launched.app)
        let clear = element("settings.action.clearEvidence", in: launched.app)
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        XCTAssertTrue(
            presentConfirmation(
                actionIdentifier: "settings.action.clearEvidence",
                confirmationIdentifier:
                    "settings.confirm.clearEvidence.action",
                in: launched.app
            )
        )
        let clearSheet = launched.app.sheets.firstMatch
        XCTAssertTrue(clearSheet.exists)
        XCTAssertTrue(
            clearSheet.staticTexts.matching(
                NSPredicate(
                    format:
                        "label CONTAINS[c] '用户文件' OR value CONTAINS[c] '用户文件'"
                )
            ).firstMatch.exists
        )
        element(
            "settings.confirm.clearEvidence.action",
            in: launched.app
        ).click()
        XCTAssertTrue(waitUntil(timeout: 5) {
            !element(
                "settings.action.clearEvidence",
                in: launched.app
            ).isEnabled
        })

        selectSettings(.localKnowledge, in: launched.app)
        let rows = launched.app.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format:
                        "identifier BEGINSWITH 'settings.knowledge.knowledge-'"
                )
            )
        let countBefore = rows.count
        XCTAssertGreaterThan(countBefore, 0)
        let forget = element(
            "settings.action.forgetKnowledge",
            in: launched.app
        )
        XCTAssertTrue(forget.waitForExistence(timeout: 5))
        XCTAssertTrue(forget.isEnabled)
        XCTAssertTrue(
            presentConfirmation(
                actionIdentifier: "settings.action.forgetKnowledge",
                confirmationIdentifier:
                    "settings.confirm.forgetKnowledge.action",
                in: launched.app
            )
        )
        let forgetSheet = launched.app.sheets.firstMatch
        XCTAssertTrue(forgetSheet.exists)
        element(
            "settings.confirm.forgetKnowledge.action",
            in: launched.app
        ).click()
        XCTAssertTrue(waitUntil(timeout: 5) {
            rows.count == countBefore - 1
        })
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
        if !settingsWindow.isHittable {
            app.activate()
        }
        let settingsSidebar = element("settings.sidebar.general", in: app)
        XCTAssertTrue(settingsSidebar.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil(timeout: 5) {
            settingsWindow.isHittable && settingsSidebar.isHittable
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
        navigate(
            item: scanItem,
            pageMarker: element("scan.results.table", in: app),
            in: app
        )
        return (app, window)
    }

    @MainActor
    private func launchHistoryFixture(
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
            "--stornaut-debug-fixture=success",
            "--stornaut-debug-history=\(fixture)",
            "--stornaut-debug-destination=history",
        ]
        app.launch()
        let window = app.windows["main"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let historyItem = element("sidebar.history", in: app)
        XCTAssertTrue(historyItem.waitForExistence(timeout: 5))
        navigate(
            item: historyItem,
            pageMarker: element("history.navigator", in: app),
            in: app
        )
        return (app, window)
    }

    @MainActor
    private func launchSettingsFixture(
        fixture: String,
        appearance: String,
        section: String
    ) -> (app: XCUIApplication, window: XCUIElement) {
        let app = XCUIApplication()
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "--stornaut-ui-test-appearance=\(appearance)",
            "--stornaut-debug-fixture=success",
            "--stornaut-debug-settings=\(fixture)",
            "--stornaut-debug-settings-section=\(section)",
        ]
        app.launch()
        XCTAssertTrue(app.windows["main"].waitForExistence(timeout: 10))
        app.typeKey(",", modifierFlags: .command)
        let content = element("settings.content", in: app)
        XCTAssertTrue(content.waitForExistence(timeout: 10))
        let window = app.windows
            .containing(.any, identifier: "settings.content")
            .firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        if !window.isHittable {
            app.activate()
        }
        XCTAssertTrue(waitUntil(timeout: 5) {
            window.isHittable
        })
        if let requestedSection = SettingsTestSection(rawValue: section) {
            selectSettings(requestedSection, in: app)
        } else {
            XCTFail("Unknown Settings section: \(section)")
        }
        return (app, window)
    }

    @MainActor
    private func selectSettings(
        _ section: SettingsTestSection,
        in app: XCUIApplication
    ) {
        app.activate()
        let items = app.descendants(matching: .any).matching(
            identifier: "settings.sidebar.\(section.rawValue)"
        )
        XCTAssertTrue(waitUntil(timeout: 5) { items.count > 0 })
        var item: XCUIElement?
        XCTAssertTrue(waitUntil(timeout: 5) {
            item = items.allElementsBoundByIndex.first(where: \.isHittable)
            return item != nil
        })
        guard let item else {
            return
        }
        item.click()
        XCTAssertTrue(
            element(section.pageIdentifier, in: app)
                .waitForExistence(timeout: 5)
        )
    }

    @MainActor
    private func presentConfirmation(
        actionIdentifier: String,
        confirmationIdentifier: String,
        in app: XCUIApplication
    ) -> Bool {
        for _ in 0..<2 {
            app.activate()
            if element(confirmationIdentifier, in: app).exists {
                return true
            }
            let actions = app.descendants(matching: .any).matching(
                identifier: actionIdentifier
            )
            var action: XCUIElement?
            guard waitUntil(timeout: 5, condition: {
                action = actions.allElementsBoundByIndex.first(
                    where: \.isHittable
                )
                return action != nil
            }), let action else {
                continue
            }
            action.click()
            if element(confirmationIdentifier, in: app)
                .waitForExistence(timeout: 5)
            {
                return true
            }
        }
        return element(confirmationIdentifier, in: app).exists
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
        let overviewItem = element("sidebar.overview", in: app)
        navigate(
            item: overviewItem,
            pageMarker: element("overview.ledger", in: app),
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 5) {
            window.isHittable
        })
    }

    @MainActor
    private func focusScan(
        _ window: XCUIElement,
        in app: XCUIApplication
    ) {
        let scanItem = element("sidebar.scan", in: app)
        navigate(
            item: scanItem,
            pageMarker: element("scan.results.table", in: app),
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 5) {
            window.isHittable
        })
    }

    @MainActor
    private func focusHistory(
        _ window: XCUIElement,
        in app: XCUIApplication
    ) {
        let historyItem = element("sidebar.history", in: app)
        navigate(
            item: historyItem,
            pageMarker: element("history.navigator", in: app),
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 5) {
            window.isHittable
        })
    }

    @MainActor
    private func navigate(
        item: XCUIElement,
        pageMarker: XCUIElement,
        in app: XCUIApplication
    ) {
        app.activate()
        if pageMarker.exists {
            return
        }
        XCTAssertTrue(waitUntil(timeout: 5) {
            item.isHittable
        })
        item.click()
        XCTAssertTrue(pageMarker.waitForExistence(timeout: 5))
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

private enum SettingsTestSection: String {
    case general
    case scanning
    case permissions
    case codexAndDeepDive
    case privacyAndData
    case localKnowledge

    var pageIdentifier: String {
        "settings.page.\(rawValue)"
    }
}
