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
        XCTAssertTrue(element("scan.review.action", in: app).exists)
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
        XCTAssertTrue(app.staticTexts["尚不可用"].exists)
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
            element("scan.review.action", in: completed.app)
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
            element(
                "scan.inspector.deepDiveImplementationUnavailable",
                in: completed.app
            ).exists
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
    func testReviewWorkflowStatesAndConfirmation() throws {
        let light = launchReviewFixture(
            fixture: "default",
            appearance: "light"
        )
        defer {
            light.app.terminate()
            _ = light.app.wait(for: .notRunning, timeout: 5)
        }
        XCTAssertTrue(
            waitForLabel(
                "ready",
                on: element("review.state.phase", in: light.app)
            )
        )
        XCTAssertTrue(element("review.table", in: light.app).exists)
        XCTAssertTrue(element("review.group.ready", in: light.app).exists)
        XCTAssertTrue(element("review.group.review", in: light.app).exists)
        XCTAssertTrue(
            element("review.group.protected", in: light.app).exists
        )
        XCTAssertTrue(element("review.group.unknown", in: light.app).exists)
        XCTAssertTrue(
            element("review.group.registeredActions", in: light.app).exists
        )
        XCTAssertTrue(
            element("review.action.preflight", in: light.app).exists
        )
        XCTAssertFalse(light.app.buttons["Delete Permanently"].exists)
        focusReview(light.window, in: light.app)
        addScreenshot(
            light.window.screenshot(),
            named: "stornaut-review-default-light"
        )

        XCTAssertTrue(
            performAction(
                in: light.app,
                action: {
                    self.hittableElement(
                        "review.action.preflight",
                        in: light.app
                    )
                },
                until: {
                    self.element(
                        "review.confirmation",
                        in: light.app
                    ).exists
                }
            )
        )
        XCTAssertTrue(
            element("review.confirmation.confirm", in: light.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(
            element("review.confirmation.writeDisabled", in: light.app)
                .exists
        )
        element("review.confirmation.confirm", in: light.app).click()
        XCTAssertTrue(
            waitForLabel(
                "executing",
                on: element("review.state.phase", in: light.app)
            )
        )
        XCTAssertTrue(
            element("review.action.stopAfterCurrent", in: light.app).exists
        )
        element("review.action.stopAfterCurrent", in: light.app).click()
        XCTAssertTrue(
            waitForLabel(
                "executing",
                on: element("review.state.phase", in: light.app)
            )
        )

        light.app.terminate()
        XCTAssertTrue(light.app.wait(for: .notRunning, timeout: 5))

        let dark = launchReviewFixture(
            fixture: "default",
            appearance: "dark"
        )
        defer {
            dark.app.terminate()
            _ = dark.app.wait(for: .notRunning, timeout: 5)
        }
        XCTAssertTrue(element("review.table", in: dark.app).exists)
        focusReview(dark.window, in: dark.app)
        addScreenshot(
            dark.window.screenshot(),
            named: "stornaut-review-default-dark"
        )

        dark.app.terminate()
        XCTAssertTrue(dark.app.wait(for: .notRunning, timeout: 5))

        let inspector = launchReviewFixture(
            fixture: "inspector",
            appearance: "dark"
        )
        defer {
            inspector.app.terminate()
            _ = inspector.app.wait(for: .notRunning, timeout: 5)
        }
        XCTAssertTrue(
            element("review.inspector", in: inspector.app)
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(
            element("review.inspector.readOnly", in: inspector.app)
                .exists
        )
        XCTAssertFalse(
            inspector.app.staticTexts["activity.process.inactive"].exists
        )
        XCTAssertTrue(
            inspector.app.staticTexts[
                "Retained Scan observed no related running process."
            ].exists
        )
        let horizontalScrollBars = inspector.app.scrollBars
            .allElementsBoundByIndex.filter {
                $0.frame.width > 100
                    && $0.frame.width > $0.frame.height * 2
            }
        XCTAssertTrue(horizontalScrollBars.isEmpty)
        inspector.app.activate()
        addScreenshot(
            inspector.window.screenshot(),
            named: "stornaut-review-inspector-dark"
        )

        inspector.app.terminate()
        XCTAssertTrue(inspector.app.wait(for: .notRunning, timeout: 5))

        let stale = launchReviewFixture(
            fixture: "stale",
            appearance: "dark"
        )
        defer {
            stale.app.terminate()
            _ = stale.app.wait(for: .notRunning, timeout: 5)
        }
        XCTAssertTrue(
            element("review.stale", in: stale.app)
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(element("review.stale.refresh", in: stale.app).exists)
        XCTAssertFalse(stale.app.buttons["Proceed Anyway"].exists)
        stale.app.activate()
        addScreenshot(
            stale.window.screenshot(),
            named: "stornaut-review-stale-dark"
        )
        element("review.stale.cancel", in: stale.app).click()
        XCTAssertTrue(
            waitForLabel(
                "stale",
                on: element("review.state.phase", in: stale.app)
            )
        )
        XCTAssertFalse(element("review.stale", in: stale.app).exists)
        XCTAssertFalse(
            element("review.action.preflight", in: stale.app).exists
        )

        stale.app.terminate()
        XCTAssertTrue(stale.app.wait(for: .notRunning, timeout: 5))

        let empty = launchReviewFixture(
            fixture: "empty",
            appearance: "light"
        )
        defer {
            empty.app.terminate()
            _ = empty.app.wait(for: .notRunning, timeout: 5)
        }
        XCTAssertTrue(element("review.empty", in: empty.app).exists)
        XCTAssertFalse(
            element("review.action.preflight", in: empty.app).exists
        )
        focusReview(empty.window, in: empty.app)
        addScreenshot(
            empty.window.screenshot(),
            named: "stornaut-review-empty-light"
        )

        empty.app.terminate()
        XCTAssertTrue(empty.app.wait(for: .notRunning, timeout: 5))

        let chinese = launchReviewFixture(
            fixture: "default",
            appearance: "light",
            language: "zh-Hans",
            locale: "zh_CN"
        )
        defer {
            chinese.app.terminate()
            _ = chinese.app.wait(for: .notRunning, timeout: 5)
        }
        XCTAssertTrue(element("review.table", in: chinese.app).exists)
        XCTAssertTrue(chinese.app.staticTexts["复核回收计划"].exists)
        XCTAssertFalse(chinese.app.staticTexts["Review Reclaim Plan"].exists)
        focusReview(chinese.window, in: chinese.app)
        addScreenshot(
            chinese.window.screenshot(),
            named: "stornaut-review-zh-Hans"
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
        XCTAssertTrue(
            performAction(
                in: deletion.app,
                action: {
                    self.existingElement(
                        "history.action.delete",
                        in: deletion.app
                    )
                },
                until: {
                    self.element(
                        "history.delete.confirm.action",
                        in: deletion.app
                    ).exists
                }
            )
        )
        XCTAssertTrue(
            performAction(
                in: deletion.app,
                action: {
                    self.hittableElement(
                        "history.delete.confirm.action",
                        in: deletion.app
                    )
                },
                until: {
                    deletion.app.descendants(matching: .any)
                        .matching(
                            NSPredicate(
                                format:
                                    "identifier BEGINSWITH 'history.record.'"
                            )
                        ).count == recordCountBefore - 1
                }
            )
        )
        XCTAssertTrue(element("history.detail", in: deletion.app).exists)

        deletion.app.terminate()
        XCTAssertTrue(deletion.app.wait(for: .notRunning, timeout: 5))

        let trend = launchHistoryFixture(
            fixture: "trend",
            appearance: "dark",
            presentation: "trend"
        )
        defer {
            trend.app.terminate()
            _ = trend.app.wait(for: .notRunning, timeout: 5)
        }
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
        let evidence = element("settings.codex.evidence", in: dark.app)
        XCTAssertTrue(
            evidence.waitForExistence(timeout: 5)
        )
        XCTAssertTrue(accessibilityText(of: evidence).contains("Passed"))
        let runtimeGate = element(
            "settings.codex.runtimeGate",
            in: dark.app
        )
        XCTAssertTrue(runtimeGate.waitForExistence(timeout: 5))
        XCTAssertTrue(
            accessibilityText(of: runtimeGate).contains("Verified")
        )
        XCTAssertTrue(
            accessibilityText(of: runtimeGate).contains(
                "Runtime boundary verified · "
                    + "Deep Dive implementation not yet available"
            )
        )
        let availability = element(
            "settings.codex.deepDiveAvailability",
            in: dark.app
        )
        XCTAssertTrue(availability.waitForExistence(timeout: 5))
        XCTAssertTrue(
            accessibilityText(of: availability).contains(
                "Implementation Not Yet Available"
            )
        )
        XCTAssertTrue(
            element("settings.codex.disclosure", in: dark.app).exists
        )
        XCTAssertFalse(dark.app.buttons["Start Deep Dive"].exists)
        XCTAssertFalse(dark.app.buttons["Trust Codex"].exists)
        XCTAssertFalse(dark.app.buttons["Accept"].exists)
        addScreenshot(
            dark.window.screenshot(),
            named: "stornaut-settings-codex-dark"
        )

        dark.app.terminate()
        XCTAssertTrue(dark.app.wait(for: .notRunning, timeout: 5))

        let knowledge = launchSettingsFixture(
            fixture: "populated",
            appearance: "dark",
            section: "localKnowledge"
        )
        defer {
            closeResidualSettingsWindow(in: knowledge.app)
            knowledge.app.terminate()
            _ = knowledge.app.wait(for: .notRunning, timeout: 5)
        }
        XCTAssertTrue(
            element("settings.page.localKnowledge", in: knowledge.app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            knowledge.app.descendants(matching: .any)
                .matching(
                    NSPredicate(
                        format:
                            "identifier BEGINSWITH 'settings.knowledge.knowledge-'"
                    )
                ).firstMatch.waitForExistence(timeout: 5)
        )
        XCTAssertFalse(knowledge.app.textFields["Agent Memory"].exists)
        addScreenshot(
            knowledge.window.screenshot(),
            named: "stornaut-settings-knowledge-dark"
        )
    }

    @MainActor
    func testSettingsRuntimeStatusVariantsRemainNonActionable() throws {
        let variants = [
            ("codex-missing", "Passed", "Blocked"),
            ("syntax-unsupported", "Passed", "Blocked"),
            ("runtime-stale", "Stale", "Blocked"),
            ("runtime-failed", "Failed", "Blocked"),
            ("runtime-unverified", "Unverified", "Unverified"),
        ]

        for (fixture, evidenceValue, gateValue) in variants {
            let launched = launchSettingsFixture(
                fixture: fixture,
                appearance: "light",
                section: "codexAndDeepDive"
            )

            let evidence = element(
                "settings.codex.evidence",
                in: launched.app
            )
            XCTAssertTrue(evidence.waitForExistence(timeout: 5))
            XCTAssertTrue(
                accessibilityText(of: evidence).contains(evidenceValue)
            )
            let runtimeGate = element(
                "settings.codex.runtimeGate",
                in: launched.app
            )
            XCTAssertTrue(runtimeGate.waitForExistence(timeout: 5))
            XCTAssertTrue(
                accessibilityText(of: runtimeGate).contains(gateValue)
            )
            XCTAssertTrue(
                element(
                    "settings.codex.deepDiveAvailability",
                    in: launched.app
                ).exists
            )
            XCTAssertFalse(launched.app.buttons["Start Deep Dive"].exists)
            XCTAssertFalse(launched.app.buttons["Accept"].exists)

            closeResidualSettingsWindow(in: launched.app)
            launched.app.terminate()
            XCTAssertTrue(
                launched.app.wait(for: .notRunning, timeout: 5)
            )
        }
    }

    @MainActor
    func testChineseSettingsRuntimeStatus() throws {
        let launched = launchSettingsFixture(
            fixture: "populated",
            appearance: "light",
            section: "codexAndDeepDive",
            language: "zh-Hans",
            locale: "zh_CN"
        )
        defer {
            closeResidualSettingsWindow(in: launched.app)
            launched.app.terminate()
            _ = launched.app.wait(for: .notRunning, timeout: 5)
        }

        let runtimeGate = element(
            "settings.codex.runtimeGate",
            in: launched.app
        )
        XCTAssertTrue(runtimeGate.waitForExistence(timeout: 5))
        XCTAssertTrue(
            accessibilityText(of: runtimeGate).contains("已验证")
        )
        XCTAssertTrue(
            accessibilityText(of: runtimeGate).contains(
                "运行时边界已验证 · 深度调查实现尚不可用"
            )
        )
        XCTAssertTrue(
            accessibilityText(
                of: element(
                    "settings.codex.deepDiveAvailability",
                    in: launched.app
                )
            ).contains("实现尚不可用")
        )
        XCTAssertFalse(launched.app.buttons["启动深度调查"].exists)
        XCTAssertFalse(launched.app.buttons["接受"].exists)
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
        XCTAssertTrue(
            selectMenuItem(
                in: launched.app,
                actionIdentifier: "settings.general.language",
                menuItemLabel: "Simplified Chinese",
                until: {
                    launched.app.staticTexts["通用"].exists
                }
            )
        )
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
        XCTAssertTrue(
            performAction(
                in: launched.app,
                action: {
                    self.hittableElement(
                        "settings.general.appearance.dark",
                        in: launched.app
                    )
                },
                until: {
                    self.element(
                        "settings.appearance",
                        in: launched.app
                    ).label == "dark"
                }
            )
        )
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
        XCTAssertTrue(
            launched.app.staticTexts.matching(
                NSPredicate(
                    format:
                        "label CONTAINS[c] '用户文件' OR value CONTAINS[c] '用户文件'"
                )
            ).firstMatch.exists
        )
        XCTAssertTrue(
            performAction(
                in: launched.app,
                action: {
                    self.hittableElement(
                        "settings.confirm.clearEvidence.action",
                        in: launched.app
                    )
                },
                until: {
                    !self.element(
                        "settings.confirm.clearEvidence.action",
                        in: launched.app
                    ).exists
                }
            )
        )
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
        XCTAssertTrue(
            element(
                "settings.confirm.forgetKnowledge.action",
                in: launched.app
            ).exists
        )
        XCTAssertTrue(
            performAction(
                in: launched.app,
                action: {
                    self.hittableElement(
                        "settings.confirm.forgetKnowledge.action",
                        in: launched.app
                    )
                },
                until: {
                    !self.element(
                        "settings.confirm.forgetKnowledge.action",
                        in: launched.app
                    ).exists
                }
            )
        )
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
        XCTAssertTrue(
            element(
                "overview.probe.implementationUnavailable",
                in: app
            ).exists
        )
        XCTAssertTrue(
            element(
                "overview.deepDive.implementationUnavailable",
                in: app
            ).exists
        )
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
        app.activate()
        let settingsSidebar = element("settings.sidebar.general", in: app)
        XCTAssertTrue(settingsSidebar.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil(timeout: 5) {
            settingsWindow.isHittable && settingsSidebar.isHittable
        })
        XCTAssertTrue(waitUntil(timeout: 5) {
            focusApplication(
                app,
                via: "settings.sidebar.general"
            )
        })
        XCTAssertTrue(waitUntil(timeout: 5) {
            settingsWindow.isHittable
                && isFrontmost(app)
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
            "--stornaut-debug-destination=scan",
        ]
        app.launch()
        let window = app.windows["main"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertTrue(
            element("sidebar.scan", in: app).waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("scan.results.table", in: app)
                .waitForExistence(timeout: 10)
        )
        return (app, window)
    }

    @MainActor
    private func launchReviewFixture(
        fixture: String,
        appearance: String,
        language: String = "en",
        locale: String = "en_US"
    ) -> (app: XCUIApplication, window: XCUIElement) {
        let app = XCUIApplication()
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
        app.launchArguments = [
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
            "--stornaut-ui-test-appearance=\(appearance)",
            "--stornaut-debug-fixture=success",
            "--stornaut-debug-review=\(fixture)",
            "--stornaut-debug-destination=scan",
        ]
        app.launch()
        let window = app.windows["main"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertTrue(
            element("sidebar.scan", in: app).waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("review.state.phase", in: app)
                .waitForExistence(timeout: 10)
        )
        return (app, window)
    }

    @MainActor
    private func launchHistoryFixture(
        fixture: String,
        appearance: String,
        presentation: String = "detail"
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
            "--stornaut-debug-history-presentation=\(presentation)",
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
        section: String,
        language: String = "en",
        locale: String = "en_US"
    ) -> (app: XCUIApplication, window: XCUIElement) {
        let app = XCUIApplication()
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
        app.launchArguments = [
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
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
    private func accessibilityText(of element: XCUIElement) -> String {
        [
            element.label,
            element.value as? String ?? "",
        ].joined(separator: " ")
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
        XCTAssertTrue(waitUntil(timeout: 5) {
            items.allElementsBoundByIndex.contains(where: \.isHittable)
        })
        XCTAssertTrue(
            performAction(
                in: app,
                action: {
                    self.hittableElement(
                        "settings.sidebar.\(section.rawValue)",
                        in: app
                    )
                },
                until: {
                    self.element(section.pageIdentifier, in: app).exists
                }
            )
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

    @MainActor
    private func hittableElement(
        _ identifier: String,
        in app: XCUIApplication
    ) -> XCUIElement? {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .allElementsBoundByIndex
            .first(where: \.isHittable)
    }

    @MainActor
    private func existingElement(
        _ identifier: String,
        in app: XCUIApplication
    ) -> XCUIElement? {
        let candidate = element(identifier, in: app)
        return candidate.exists ? candidate : nil
    }

    @MainActor
    private func selectMenuItem(
        in app: XCUIApplication,
        actionIdentifier: String,
        menuItemLabel: String,
        until condition: () -> Bool
    ) -> Bool {
        for _ in 0..<2 {
            if condition() {
                return true
            }
            app.activate()
            guard let action = hittableElement(
                actionIdentifier,
                in: app
            ) else {
                continue
            }
            action.click()
            let menuItem = app.menuItems[menuItemLabel]
            guard waitUntil(timeout: 5, condition: {
                menuItem.exists && menuItem.isHittable
            }) else {
                continue
            }
            menuItem.click()
            if waitUntil(timeout: 5, condition: condition) {
                return true
            }
        }
        return condition()
    }

    @MainActor
    private func performAction(
        in app: XCUIApplication,
        action: () -> XCUIElement?,
        until condition: () -> Bool
    ) -> Bool {
        for _ in 0..<2 {
            if condition() {
                return true
            }
            app.activate()
            guard waitUntil(timeout: 5, condition: {
                self.isFrontmost(app)
            }) else {
                continue
            }
            var current: XCUIElement?
            guard waitUntil(timeout: 5, condition: {
                current = action()
                return current != nil
            }), let current else {
                continue
            }
            current.click()
            if waitUntil(timeout: 5, condition: condition) {
                return true
            }
        }
        return condition()
    }

    @MainActor
    private func focusApplication(
        _ app: XCUIApplication,
        via identifier: String
    ) -> Bool {
        for _ in 0..<2 {
            app.activate()
            guard waitUntil(timeout: 5, condition: {
                self.isFrontmost(app)
            }), let current = hittableElement(identifier, in: app) else {
                continue
            }
            current.click()
            if waitUntil(timeout: 5, condition: {
                self.isFrontmost(app)
            }) {
                return true
            }
        }
        return isFrontmost(app)
    }

    @MainActor
    private func isFrontmost(_ app: XCUIApplication) -> Bool {
        app.state == .runningForeground
    }

    @MainActor
    private func waitForLabel(
        _ label: String,
        on element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        waitUntil(timeout: timeout) {
            element.exists && element.label == label
        }
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
        XCTAssertTrue(
            focusApplication(app, via: "sidebar.overview")
        )
        XCTAssertTrue(waitUntil(timeout: 5) {
            window.isHittable && isFrontmost(app)
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
        XCTAssertTrue(
            focusApplication(app, via: "sidebar.scan")
        )
        XCTAssertTrue(waitUntil(timeout: 5) {
            window.isHittable && isFrontmost(app)
        })
    }

    @MainActor
    private func focusReview(
        _ window: XCUIElement,
        in app: XCUIApplication
    ) {
        app.activate()
        XCTAssertTrue(waitUntil(timeout: 5) {
            window.isHittable && isFrontmost(app)
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
        XCTAssertTrue(
            focusApplication(app, via: "sidebar.history")
        )
        XCTAssertTrue(waitUntil(timeout: 5) {
            window.isHittable && isFrontmost(app)
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
        let identifier = item.identifier
        XCTAssertTrue(
            performAction(
                in: app,
                action: {
                    self.hittableElement(identifier, in: app)
                },
                until: {
                    pageMarker.exists
                }
            )
        )
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
