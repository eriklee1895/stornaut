import Foundation
import Testing
@testable import StornautCodex

@Suite("R5 signed runtime diagnostic contract")
struct CapabilityRuntimeDiagnosticContractTests {
    @Test
    func primaryDiagnosticTimeoutRemainsBounded() {
        #expect(
            CapabilityRuntimeWorker.primaryDiagnosticTimeout
                == .seconds(120)
        )
        #expect(
            CapabilityRuntimeWorker.commandDiagnosticMaximumAttempts == 3
        )
    }

    @Test
    func timeoutProgressRetainsOnlyCapabilityCategories() {
        let observation = CodexAppServerObservation(
            notificationMethods: ["/Users/private"],
            itemTypes: ["secret"],
            finalAgentMessage: nil,
            capabilityObservations: [
                .command(
                    source: .agent,
                    succeeded: true,
                    matchedMarkerIDs: ["must-not-be-retained"]
                ),
                .command(
                    source: .agent,
                    succeeded: false,
                    matchedMarkerIDs: ["also-must-not-be-retained"]
                ),
                .webSearchStarted,
                .imageViewCompleted,
                .runtimeSkillSelected,
                .subagentSpawnStarted,
                .subagentSpawnCompleted(receiverCount: 1),
            ],
            upstreamErrors: [
                CodexSanitizedUpstreamError(
                    category: .serverOverloaded,
                    code: 503,
                    willRetry: true
                ),
            ],
            commandIdentityEligibleCount: 1,
            commandOutputDeltaCount: 2,
            commandAggregatedOutputCount: 1
        )

        let reason = capabilityRuntimeProgressReasonKey(
            observation,
            phaseKey: "running-probe"
        )

        #expect(
            reason
                == "phase-running-probe.commands-ok-1."
                + "commands-failed-1.command-source-agent-2."
                + "command-source-user-shell-0."
                + "command-source-unified-startup-0."
                + "command-source-unified-interaction-0."
                + "command-identity-eligible-1."
                + "command-output-delta-2."
                + "command-aggregated-output-1."
                + "web-start-1.web-complete-0."
                + "image-start-0.image-complete-1.skill-1."
                + "subagent-start-1.subagent-result-0."
                + "subagent-complete-1.final-message-0.upstream-1."
                + "upstream-categories-serverOverloaded"
        )
        #expect(!reason.contains("must-not-be-retained"))
        #expect(!reason.contains("also-must-not-be-retained"))
        #expect(!reason.contains("/Users/private"))
        #expect(!reason.contains("secret"))
        #expect(!reason.contains("503"))
    }

    @Test
    func workerFailureReceiptIsClosedBoundedAndRoundTrips() throws {
        let errors: [(CapabilityRuntimeWorkerError, String)] = [
            (.invalidIdentity, "runtime.worker.invalid-identity"),
            (
                .invalidDiagnosticRoot,
                "runtime.worker.invalid-diagnostic-root"
            ),
            (.codexUnavailable, "runtime.worker.codex-unavailable"),
            (.incompatibleCodex, "runtime.worker.incompatible-codex"),
            (
                .fixtureStagingFailed,
                "runtime.worker.fixture-staging-failed"
            ),
            (
                .executableStagingFailed(
                    stage: "/Users/private",
                    errno: 13
                ),
                "runtime.worker.executable-staging-failed"
            ),
            (
                .canaryServerFailed,
                "runtime.worker.canary-server-failed"
            ),
            (
                .modelDiagnosticFailed(
                    reasonKey:
                        "runtime.worker.image-group.session-timeout"
                ),
                "runtime.worker.image-group.session-timeout"
            ),
            (
                .commandNotInvoked(progressKey: "must-not-leak"),
                "runtime.worker.command-not-invoked"
            ),
            (.invalidEnvelope, "runtime.worker.invalid-envelope"),
            (
                .missingCapabilityEvidence,
                "runtime.worker.missing-capability-evidence"
            ),
            (
                .containmentFailed(
                    reasonKey: "runtime.integrity.unix-socket-denial"
                ),
                "runtime.integrity.unix-socket-denial"
            ),
            (
                .cleanupFailed(
                    reasonKey: "runtime.cleanup.workspace-residue"
                ),
                "runtime.cleanup.workspace-residue"
            ),
        ]

        for (error, expected) in errors {
            let receipt = try CapabilityRuntimeWorkerFailureReceipt(
                error: error
            )
            #expect(receipt.reasonKey == expected)
            #expect(
                try CapabilityRuntimeWorkerFailureReceipt.decodeLine(
                    receipt.encodedLine()
                ) == receipt
            )
            let text = String(
                decoding: receipt.encodedLine(),
                as: UTF8.self
            )
            #expect(!text.contains("/Users/private"))
            #expect(!text.contains("must-not-leak"))
            #expect(!text.contains("13"))
        }

        for reasonKey in [
            "",
            "runtime.worker.bad/path",
            "runtime.worker.bad\ninjection",
            String(repeating: "a", count: 513),
        ] {
            #expect(throws: CapabilityRuntimeWorkerError.invalidIdentity) {
                _ = try CapabilityRuntimeWorkerFailureReceipt(
                    reasonKey: reasonKey
                )
            }
        }
    }

    @Test
    func eventCategorySanitizerConvertsMethodsWithoutAcceptingPaths() {
        #expect(
            sanitizedCapabilityRuntimeEventCategory(
                prefix: "notification",
                value: "item/commandExecution/outputDelta"
            ) == "notification.item.commandExecution.outputDelta"
        )
        #expect(
            sanitizedCapabilityRuntimeEventCategory(
                prefix: "item",
                value: "collabAgentToolCall"
            ) == "item.collabAgentToolCall"
        )
        #expect(
            sanitizedCapabilityRuntimeEventCategory(
                prefix: "notification",
                value: "/Users/private"
            ) == nil
        )
        #expect(
            sanitizedCapabilityRuntimeEventCategory(
                prefix: "notification",
                value: "item//completed"
            ) == nil
        )
    }

    @Test(
        arguments: [
            (InvestigationEnvelopeV2Error.invalidContext, "invalid-context"),
            (InvestigationEnvelopeV2Error.invalidJSON, "invalid-json"),
            (
                InvestigationEnvelopeV2Error.invalidStructure,
                "invalid-structure"
            ),
            (
                InvestigationEnvelopeV2Error.inputLimitExceeded,
                "input-limit"
            ),
            (
                InvestigationEnvelopeV2Error.unsupportedVersion,
                "unsupported-version"
            ),
            (
                InvestigationEnvelopeV2Error.identityMismatch,
                "identity-mismatch"
            ),
            (
                InvestigationEnvelopeV2Error.invalidSummary,
                "invalid-summary"
            ),
            (
                InvestigationEnvelopeV2Error.invalidCoverage,
                "invalid-coverage"
            ),
            (
                InvestigationEnvelopeV2Error.invalidEvidence,
                "invalid-evidence"
            ),
            (
                InvestigationEnvelopeV2Error.invalidFinding,
                "invalid-finding"
            ),
            (
                InvestigationEnvelopeV2Error.invalidCandidateProposal,
                "invalid-proposal"
            ),
            (
                InvestigationEnvelopeV2Error.invalidDegradation,
                "invalid-degradation"
            ),
            (
                InvestigationEnvelopeV2Error.invalidPublicURL,
                "invalid-public-url"
            ),
            (
                InvestigationEnvelopeV2Error.collectionLimitExceeded,
                "collection-limit"
            ),
        ]
    )
    func envelopeErrorReasonIsClosedAndPrivacySafe(
        error: InvestigationEnvelopeV2Error,
        expected: String
    ) {
        let reason = capabilityRuntimeEnvelopeErrorReason(error)

        #expect(reason == expected)
        #expect(!reason.contains("/"))
        #expect(!reason.contains(" "))
    }

    @Test
    func groupedObservationsMergeDisjointCapabilityEvidence() {
        let commandGroup = CodexAppServerObservation(
            notificationMethods: ["item/completed"],
            itemTypes: ["commandExecution"],
            finalAgentMessage: #"{"group":"command"}"#,
            capabilityObservations: [
                .command(
                    source: .unifiedExecStartup,
                    succeeded: true,
                    matchedMarkerIDs: ["direct.via-command"]
                ),
            ]
        )
        let mediaGroup = CodexAppServerObservation(
            notificationMethods: ["item/completed"],
            itemTypes: ["imageView"],
            finalAgentMessage: #"{"group":"media"}"#,
            capabilityObservations: [
                .imageViewCompleted,
                .runtimeSkillSelected,
                .subagentSpawnCompleted(receiverCount: 1),
            ]
        )
        let searchGroup = CodexAppServerObservation(
            notificationMethods: ["rawResponseItem/completed"],
            itemTypes: ["webSearch"],
            finalAgentMessage: #"{"group":"search"}"#,
            capabilityObservations: [
                .webSearchStarted,
                .webSearchCompleted,
            ]
        )

        let merged = commandGroup
            .mergingEvidence(from: mediaGroup)
            .mergingEvidence(from: searchGroup)

        #expect(merged.notificationMethods == [
            "item/completed",
            "rawResponseItem/completed",
        ])
        #expect(merged.itemTypes == [
            "commandExecution",
            "imageView",
            "webSearch",
        ])
        #expect(merged.finalAgentMessage == #"{"group":"command"}"#)
        #expect(Set(merged.capabilityObservations) == [
            .command(
                source: .unifiedExecStartup,
                succeeded: true,
                matchedMarkerIDs: ["direct.via-command"]
            ),
            .imageViewCompleted,
            .runtimeSkillSelected,
            .subagentSpawnCompleted(receiverCount: 1),
            .webSearchStarted,
            .webSearchCompleted,
        ])
    }

    @Test
    func commandDiagnosticPlansAreDisjointAndSingleTool() throws {
        let context = try InvestigationProtocolContext(
            investigationID: "command-plan-investigation",
            runID: "command-plan-run",
            targetIDs: ["synthetic-target"],
            candidateTargetIDs: [:],
            requiredCapabilities: Set(
                InvestigationCapability.allCases.filter {
                    $0 != .probeBroker
                }
            )
        )

        let plans = capabilityRuntimeCommandDiagnosticPlans(
            context: context
        )

        #expect(plans.map(\.kind) == [
            .directRead,
            .shellContainment,
            .unifiedExec,
        ])
        #expect(plans.map(\.expectedCommand) == [
            "cat ./direct-read.txt",
            "./capability-probe.zsh",
            "./unified-probe.zsh",
        ])
        #expect(capabilityRuntimeDirectReadCommands() == [
            "/bin/cat ./direct-read.txt",
            "/bin/cat direct-read.txt",
            "cat ./direct-read.txt",
            "cat direct-read.txt",
        ])
        #expect(
            capabilityRuntimeDirectReadCommands().allSatisfy {
                !$0.contains(";")
                    && !$0.contains("|")
                    && !$0.contains(">")
                    && !$0.contains("<")
                    && $0.split(separator: " ").count == 2
            }
        )
        #expect(
            plans[0].probePrompt
                == """
                Run exactly `cat ./direct-read.txt` with the command tool. \
                Wait for it to finish. Then return only the exact file token. \
                Do not use any other tool.
                """
        )
        #expect(plans.map(\.expectedEvidenceIDs) == [
            ["direct-evidence"],
            ["browser-evidence", "shell-evidence"],
            ["unified-evidence"],
        ])
        #expect(plans.map(\.markerIDs) == [
            ["direct.via-command"],
            [
                "browser.fetch",
                "linklocal.denied",
                "linklocal6.denied",
                "loopback.denied",
                "loopback6.denied",
                "nested.write.denied",
                "private.denied",
                "public.direct.denied",
                "public.proxy",
                "shell.read",
                "ula6.denied",
                "unix.denied",
                "write.matrix.denied",
            ],
            ["unified.read"],
        ])
        #expect(plans.map(\.allowedSources) == [
            [
                .agent,
                .unifiedExecInteraction,
                .unifiedExecStartup,
            ],
            [
                .agent,
                .unifiedExecInteraction,
                .unifiedExecStartup,
            ],
            [.unifiedExecInteraction, .unifiedExecStartup],
        ])
        #expect(
            Set(plans.flatMap(\.expectedEvidenceIDs)).count
                == plans.flatMap(\.expectedEvidenceIDs).count
        )
        #expect(
            Set(plans.flatMap(\.markerIDs)).count
                == plans.flatMap(\.markerIDs).count
        )
        for plan in plans {
            #expect(plan.probePrompt.contains(plan.expectedCommand))
            #expect(!plan.probePrompt.contains("Investigation Envelope"))
            #expect(!plan.probePrompt.contains("evidence"))
            #expect(
                plan.finalizationPrompt.contains(
                    "Investigation Envelope v2"
                )
            )
            #expect(
                plan.finalizationPrompt.contains(
                    "summary=Synthetic capability evidence observed."
                )
            )
            #expect(
                plan.finalizationPrompt.contains(
                    "Every evidence targetID=synthetic-target."
                )
            )
            for evidenceID in plan.expectedEvidenceIDs {
                #expect(
                    plan.finalizationPrompt.contains(
                        "id=\(evidenceID), targetID=synthetic-target,"
                    )
                )
            }
            #expect(
                !plan.finalizationPrompt.contains(plan.expectedCommand)
            )
            for otherCommand in plans
                .map(\.expectedCommand)
                .filter({ $0 != plan.expectedCommand })
            {
                #expect(!plan.probePrompt.contains(otherCommand))
                #expect(!plan.finalizationPrompt.contains(otherCommand))
            }
        }
    }

    @Test
    func capabilityGroupSchemaPinsIdentityAndEvidenceContract() throws {
        let context = try InvestigationProtocolContext(
            investigationID: "investigation-synthetic",
            runID: "run-synthetic",
            targetIDs: ["synthetic-target"],
            candidateTargetIDs: [:],
            requiredCapabilities: [.liveSearch]
        )
        let projected = try capabilityRuntimeGroupSchema(
            InvestigationEnvelopeV2Schema
                .loadStructuredOutputJSONValue(),
            context: context,
            expectedEvidenceIDs: ["search-evidence"]
        )

        guard
            case let .object(root) = projected,
            case let .object(properties) = root["properties"],
            case let .object(investigation) =
                properties["investigationID"],
            case let .object(run) = properties["runID"],
            case let .object(evidence) = properties["evidence"],
            case let .object(item) = evidence["items"],
            case let .object(itemProperties) = item["properties"],
            case let .object(identifier) = itemProperties["id"],
            case let .object(target) = itemProperties["targetID"],
            case let .object(sourceProperty) =
                itemProperties["source"]
        else {
            Issue.record("Expected projected capability group schema")
            return
        }

        #expect(
            investigation["enum"]
                == .array([.string(context.investigationID)])
        )
        #expect(investigation["$ref"] == nil)
        #expect(run["enum"] == .array([.string(context.runID)]))
        #expect(run["$ref"] == nil)
        #expect(
            identifier["enum"]
                == .array([.string("search-evidence")])
        )
        #expect(identifier["$ref"] == nil)
        #expect(
            target["enum"]
                == .array([.string("synthetic-target")])
        )
        #expect(target["$ref"] == nil)
        #expect(
            sourceProperty["enum"]
                == .array([.string("liveSearch")])
        )
        #expect(evidence["minItems"] == nil)
        #expect(evidence["maxItems"] == nil)
    }

    @Test
    func commandObservationRetryClassificationFailsClosed() {
        let expected: Set<String> = [
            "shell.read",
            "write.matrix.denied",
        ]
        let notInvoked = CodexAppServerObservation(
            notificationMethods: [],
            itemTypes: ["agentMessage"],
            finalAgentMessage: #"{"verdict":"passed"}"#,
            capabilityObservations: []
        )
        let wrongCommand = CodexAppServerObservation(
            notificationMethods: [],
            itemTypes: ["commandExecution"],
            finalAgentMessage: #"{"verdict":"passed"}"#,
            capabilityObservations: [
                .command(
                    source: .agent,
                    succeeded: true,
                    matchedMarkerIDs: []
                ),
            ]
        )
        let partial = CodexAppServerObservation(
            notificationMethods: [],
            itemTypes: ["commandExecution"],
            finalAgentMessage: #"{"verdict":"passed"}"#,
            capabilityObservations: [
                .command(
                    source: .agent,
                    succeeded: true,
                    matchedMarkerIDs: ["shell.read"]
                ),
            ]
        )
        let failed = CodexAppServerObservation(
            notificationMethods: [],
            itemTypes: ["commandExecution"],
            finalAgentMessage: #"{"verdict":"passed"}"#,
            capabilityObservations: [
                .command(
                    source: .agent,
                    succeeded: false,
                    matchedMarkerIDs: ["shell.read"]
                ),
            ]
        )
        let observed = CodexAppServerObservation(
            notificationMethods: [],
            itemTypes: ["commandExecution"],
            finalAgentMessage: #"{"verdict":"passed"}"#,
            capabilityObservations: [
                .command(
                    source: .agent,
                    succeeded: true,
                    matchedMarkerIDs: [
                        "shell.read",
                        "write.matrix.denied",
                    ]
                ),
            ]
        )

        #expect(
            commandDiagnosticObservationDisposition(
                notInvoked,
                expectedMarkerIDs: expected
            ) == .retryableNotInvoked
        )
        #expect(
            commandDiagnosticObservationDisposition(
                wrongCommand,
                expectedMarkerIDs: expected
            ) == .retryableNotInvoked
        )
        #expect(
            commandDiagnosticObservationDisposition(
                partial,
                expectedMarkerIDs: expected
            ) == .blockedMissingMarkers
        )
        #expect(
            commandDiagnosticObservationDisposition(
                failed,
                expectedMarkerIDs: expected
            ) == .blockedCommandFailed
        )
        #expect(
            commandDiagnosticObservationDisposition(
                observed,
                expectedMarkerIDs: expected
            ) == .observed
        )
        #expect(
            missingCommandDiagnosticMarkerReason(
                partial,
                expectedMarkerIDs: expected
            ) == "write.matrix.denied"
        )
        #expect(
            missingCommandDiagnosticMarkerReason(
                observed,
                expectedMarkerIDs: expected
            ) == "none"
        )
        #expect(
            missingCommandDiagnosticMarkerReason(
                partial,
                expectedMarkerIDs: ["unsafe marker"]
            ) == "invalid"
        )
    }

    @Test
    func imageEvidenceRequiresTheFixedSyntheticToken() {
        let matching = InvestigationEvidenceV2(
            id: "image-evidence",
            targetID: "synthetic-target",
            source: .image,
            summary: "Observed STORNAUT_R5_IMAGE_OK",
            publicURL: nil
        )
        let missing = InvestigationEvidenceV2(
            id: "image-evidence",
            targetID: "synthetic-target",
            source: .image,
            summary: "Observed an unrelated image",
            publicURL: nil
        )
        let wrongSource = InvestigationEvidenceV2(
            id: "image-evidence",
            targetID: "synthetic-target",
            source: .shell,
            summary: "Observed STORNAUT_R5_IMAGE_OK",
            publicURL: nil
        )

        #expect(
            imageEvidenceContainsSyntheticToken(
                [matching],
                token: "STORNAUT_R5_IMAGE_OK"
            )
        )
        #expect(
            !imageEvidenceContainsSyntheticToken(
                [missing],
                token: "STORNAUT_R5_IMAGE_OK"
            )
        )
        #expect(
            !imageEvidenceContainsSyntheticToken(
                [wrongSource],
                token: "STORNAUT_R5_IMAGE_OK"
            )
        )
        #expect(
            !imageEvidenceContainsSyntheticToken(
                [matching],
                token: "STORNAUT_R5_IMAGE_OTHER"
            )
        )
    }

    @Test
    func runtimeDiagnosticTokensAreFreshAndBounded() {
        let first = runtimeDiagnosticToken("DIRECT")
        let second = runtimeDiagnosticToken("DIRECT")

        #expect(first != second)
        #expect(first.hasPrefix("STORNAUT_R5_DIRECT_"))
        #expect(first.utf8.count <= 128)
        #expect(!first.contains("-"))
    }

    @Test
    func fixedNetworkProbeOutputMapsToFreshUnforgeableTokens() throws {
        let tokens = [
            "public.direct.denied": runtimeDiagnosticToken("PUBLIC"),
            "loopback.denied": runtimeDiagnosticToken("LOOPBACK"),
            "linklocal.denied": runtimeDiagnosticToken("LINKLOCAL"),
            "loopback6.denied": runtimeDiagnosticToken("LOOPBACK6"),
            "linklocal6.denied": runtimeDiagnosticToken("LINKLOCAL6"),
            "ula6.denied": runtimeDiagnosticToken("ULA6"),
            "unix.denied": runtimeDiagnosticToken("UNIX"),
            "private.denied": runtimeDiagnosticToken("PRIVATE"),
        ]
        let translation = try runtimeNetworkDenialMarkerTranslation(
            denialTokens: tokens,
            includesPrivateAddress: true
        )

        for fixed in [
            "STORNAUT_R5_PUBLIC_DIRECT_DENIED",
            "STORNAUT_R5_LOOPBACK_DENIED",
            "STORNAUT_R5_LINKLOCAL_DENIED",
            "STORNAUT_R5_LOOPBACK6_DENIED",
            "STORNAUT_R5_LINKLOCAL6_DENIED",
            "STORNAUT_R5_ULA6_DENIED",
            "STORNAUT_R5_UNIX_DENIED",
            "STORNAUT_R5_PRIVATE_DENIED",
        ] {
            #expect(translation.contains(fixed))
        }
        for token in tokens.values {
            #expect(translation.contains(token))
        }
        #expect(translation.contains("exit 72"))

        var injected = tokens
        injected["unix.denied"] = "$(touch /tmp/forged)"
        #expect(
            throws: CapabilityRuntimeWorkerError.fixtureStagingFailed
        ) {
            _ = try runtimeNetworkDenialMarkerTranslation(
                denialTokens: injected,
                includesPrivateAddress: true
            )
        }
    }

    @Test
    func syntheticTokenImageContainsOnlyTheRequestedFreshToken() throws {
        let token = runtimeDiagnosticToken("IMAGE")
        let data = try syntheticTokenPNG(token)

        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        #expect(data.count > 1_024)
        #expect(
            data.range(of: Data("STORNAUT_R5_IMAGE_OK".utf8)) == nil
        )
    }

    @Test
    func liveSearchCompanionRequiresCompletionAndPassedVerdict() {
        let passing = CodexAppServerObservation(
            notificationMethods: [],
            itemTypes: ["webSearch"],
            finalAgentMessage: #"{"verdict":"passed"}"#,
            capabilityObservations: [.webSearchCompleted]
        )
        let missingCompletion = CodexAppServerObservation(
            notificationMethods: [],
            itemTypes: ["webSearch"],
            finalAgentMessage: #"{"verdict":"passed"}"#,
            capabilityObservations: []
        )
        let wrongVerdict = CodexAppServerObservation(
            notificationMethods: [],
            itemTypes: ["webSearch"],
            finalAgentMessage: #"{"verdict":"failed"}"#,
            capabilityObservations: [.webSearchCompleted]
        )

        #expect(liveSearchCompanionSucceeded(passing))
        #expect(!liveSearchCompanionSucceeded(missingCompletion))
        #expect(!liveSearchCompanionSucceeded(wrongVerdict))
    }

    @Test
    func runtimeProbeInstallerRequiresWritableStagingThenSealsExecutable()
        throws
    {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-runtime-probe-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let probeURL = root.appending(path: "probe.zsh")
        try Data("#!/bin/zsh\nexit 70\n".utf8).write(to: probeURL)
        chmod(probeURL.path, 0o700)

        try installRuntimeDiagnosticProbe(
            Data("#!/bin/zsh\nprint -r -- READY\n".utf8),
            at: probeURL
        )

        #expect(
            try String(contentsOf: probeURL, encoding: .utf8)
                == "#!/bin/zsh\nprint -r -- READY\n"
        )
        let attributes = try FileManager.default.attributesOfItem(
            atPath: probeURL.path
        )
        #expect(
            (attributes[.posixPermissions] as? NSNumber)?.intValue
                == 0o500
        )

        chmod(probeURL.path, 0o500)
        #expect(throws: CapabilityRuntimeWorkerError.fixtureStagingFailed) {
            try installRuntimeDiagnosticProbe(
                Data("#!/bin/zsh\nprint impossible\n".utf8),
                at: probeURL
            )
        }
    }

    @Test
    func nativeCodexStagingCreatesASealedSingleLinkClone() throws {
        let parent = URL(
            filePath: "/private/tmp",
            directoryHint: .isDirectory
        ).appending(
            path: "stornaut-native-stage-\(UUID().uuidString)",
            directoryHint: .isDirectory
        ).standardizedFileURL
        try FileManager.default.createDirectory(
            at: parent,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: parent) }
        let workspace = try CodexRuntimeWorkspace.create(
            under: parent,
            forbiddenRoots: []
        )
        let sourceRoot = parent.appending(
            path: "source-package",
            directoryHint: .isDirectory
        )
        let source = SyntheticDiagnosticCodexPackage(
            rootURL: sourceRoot,
            executableURL: sourceRoot.appending(path: "bin/codex"),
            codeModeHostURL: sourceRoot.appending(
                path: "bin/codex-code-mode-host"
            ),
            ripgrepURL: sourceRoot.appending(path: "codex-path/rg"),
            zshURL: sourceRoot.appending(
                path: "codex-resources/zsh/bin/zsh"
            )
        )
        for directory in [
            source.executableURL.deletingLastPathComponent(),
            source.ripgrepURL.deletingLastPathComponent(),
            source.zshURL.deletingLastPathComponent(),
        ] {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        for url in [
            source.executableURL,
            source.codeModeHostURL,
            source.ripgrepURL,
            source.zshURL,
        ] {
            try Data("#!/bin/sh\nexit 0\n".utf8).write(to: url)
            chmod(url.path, 0o500)
        }

        let staged = try stageSyntheticDiagnosticCodexPackage(
            source: source,
            workspace: workspace.paths
        )

        #expect(
            staged.executableURL
                == workspace.paths.fixturesURL.appending(
                    path: "codex-r5-package/bin/codex"
                )
        )
        #expect(try Data(contentsOf: staged.executableURL) == Data(
            "#!/bin/sh\nexit 0\n".utf8
        ))
        for url in [
            staged.executableURL,
            staged.codeModeHostURL,
            staged.ripgrepURL,
            staged.zshURL,
        ] {
            var information = stat()
            #expect(lstat(url.path, &information) == 0)
            #expect(information.st_mode & S_IFMT == S_IFREG)
            #expect(information.st_mode & 0o777 == 0o500)
            #expect(information.st_uid == geteuid())
            #expect(information.st_nlink == 1)
        }
        let metadata = staged.rootURL.appending(
            path: "codex-package.json"
        )
        #expect(try Data(contentsOf: metadata).count > 0)
        try workspace.remove()
    }

    @Test
    func syntheticCapabilitySessionKeepsInstalledOuterAndStagedInner()
        throws
    {
        let outer = URL(filePath: "/opt/stornaut/bin/codex")
        let inner = URL(
            filePath:
                "/private/tmp/stornaut/fixtures/"
                + "codex-r5-package/bin/codex"
        )

        let topology = try syntheticCapabilitySessionTopology(
            outerExecutableURL: outer,
            appServerExecutableURL: inner
        )

        #expect(topology.outerExecutableURL == outer)
        #expect(topology.appServerExecutableURL == inner)
        #expect(
            throws: CapabilityRuntimeWorkerError.invalidIdentity
        ) {
            _ = try syntheticCapabilitySessionTopology(
                outerExecutableURL: inner,
                appServerExecutableURL: inner
            )
        }
        #expect(
            throws: CapabilityRuntimeWorkerError.invalidIdentity
        ) {
            _ = try syntheticCapabilitySessionTopology(
                outerExecutableURL: outer,
                appServerExecutableURL: outer
            )
        }
    }

    @Test
    func networkProbeOwnerExceptionIsOnlyTheCurrentInstalledHelper()
        throws
    {
        let installedHelper = URL(
            filePath:
                "/Library/Application Support/Stornaut/"
                + "Stornaut-R5-Diagnostic.app/Contents/MacOS/"
                + "StornautLifecycleHelper"
        )
        let userProbe = URL(
            filePath: "/private/tmp/stornaut-user-probe"
        )

        #expect(
            try runtimeNetworkProbeSourceOwner(
                sourceURL: installedHelper,
                currentExecutableURL: installedHelper,
                currentUserID: 501
            ) == 0
        )
        #expect(
            try runtimeNetworkProbeSourceOwner(
                sourceURL: userProbe,
                currentExecutableURL: installedHelper,
                currentUserID: 501
            ) == 501
        )
        #expect(
            throws: CapabilityRuntimeWorkerError.invalidIdentity
        ) {
            _ = try runtimeNetworkProbeSourceOwner(
                sourceURL: installedHelper,
                currentExecutableURL:
                    URL(filePath: "/private/tmp/forged-helper"),
                currentUserID: 501
            )
        }
        #expect(
            throws: CapabilityRuntimeWorkerError.invalidIdentity
        ) {
            _ = try runtimeNetworkProbeSourceOwner(
                sourceURL: installedHelper,
                currentExecutableURL: installedHelper,
                currentUserID: 0
            )
        }
    }

    @Test
    func containmentFailureReasonIsStableAndPrivacySafe() {
        let passingMarkers: Set<String> = [
            "write.matrix.denied",
            "nested.write.denied",
            "public.direct.denied",
            "loopback.denied",
            "linklocal.denied",
            "loopback6.denied",
            "linklocal6.denied",
            "ula6.denied",
            "private.denied",
            "unix.denied",
        ]
        let passing = CapabilityRuntimeContainmentSnapshot(
            observedMarkerIDs: passingMarkers,
            mutationResidue: false,
            requiresPrivateDenial: true,
            authUnchanged: true
        )
        #expect(capabilityRuntimeContainmentFailureReason(passing) == nil)

        let cases: [(String, CapabilityRuntimeContainmentSnapshot)] = [
            (
                "runtime.integrity.user-write-denial.not-observed",
                passing.replacing(
                    observedMarkerIDs:
                        passingMarkers.subtracting([
                            "write.matrix.denied",
                        ])
                )
            ),
            (
                "runtime.integrity.user-write-residue",
                passing.replacing(mutationResidue: true)
            ),
            (
                "runtime.integrity.nested-write-denial.not-observed",
                passing.replacing(
                    observedMarkerIDs:
                        passingMarkers.subtracting([
                            "nested.write.denied",
                        ])
                )
            ),
            (
                "runtime.integrity.public-direct-bypass.not-denied",
                passing.replacing(
                    observedMarkerIDs:
                        passingMarkers.subtracting([
                            "public.direct.denied",
                        ])
                )
            ),
            (
                "runtime.integrity.loopback-denial.not-observed",
                passing.replacing(
                    observedMarkerIDs:
                        passingMarkers.subtracting([
                            "loopback.denied",
                        ])
                )
            ),
            (
                "runtime.integrity.linklocal-denial.not-observed",
                passing.replacing(
                    observedMarkerIDs:
                        passingMarkers.subtracting([
                            "linklocal.denied",
                        ])
                )
            ),
            (
                "runtime.integrity.private-denial.not-observed",
                passing.replacing(
                    observedMarkerIDs:
                        passingMarkers.subtracting([
                            "private.denied",
                        ])
                )
            ),
            (
                "runtime.integrity.loopback6-denial.not-observed",
                passing.replacing(
                    observedMarkerIDs:
                        passingMarkers.subtracting([
                            "loopback6.denied",
                        ])
                )
            ),
            (
                "runtime.integrity.linklocal6-denial.not-observed",
                passing.replacing(
                    observedMarkerIDs:
                        passingMarkers.subtracting([
                            "linklocal6.denied",
                        ])
                )
            ),
            (
                "runtime.integrity.ula6-denial.not-observed",
                passing.replacing(
                    observedMarkerIDs:
                        passingMarkers.subtracting([
                            "ula6.denied",
                        ])
                )
            ),
            (
                "runtime.integrity.unix-socket-denial.not-observed",
                passing.replacing(
                    observedMarkerIDs:
                        passingMarkers.subtracting([
                            "unix.denied",
                        ])
                )
            ),
            (
                "runtime.integrity.auth-source-changed",
                passing.replacing(authUnchanged: false)
            ),
        ]

        for (expected, snapshot) in cases {
            let reason = capabilityRuntimeContainmentFailureReason(
                snapshot
            )
            #expect(reason == expected)
            #expect(!String(describing: reason).contains("/Users/"))
            #expect(!String(describing: reason).contains("token"))
        }
    }

    @Test
    func workerUpstreamReasonContainsOnlyApprovedSanitizedFields() {
        let reason = workerProtocolReasonKey(
            .upstreamError(
                CodexSanitizedUpstreamError(
                    category: .badRequest,
                    code: 400,
                    willRetry: false
                )
            )
        )

        #expect(
            reason
                == "runtime.worker.protocol-upstream.badRequest.code-400.retry-false"
        )
        #expect(!reason.contains("message"))
        #expect(!reason.contains("/"))
        #expect(!reason.contains("credential"))
    }

    @Test(
        .enabled(
            if: ProcessInfo.processInfo.environment[
                "STORNAUT_R5_NETWORK_PROBE_EXECUTABLE"
            ] != nil,
            "Requires the Xcode-built DEBUG lifecycle helper"
        )
    )
    func networkDenialProbeCannotPassWithoutOuterContainment()
        async throws
    {
        let executable = try #require(
            ProcessInfo.processInfo.environment[
                "STORNAUT_R5_NETWORK_PROBE_EXECUTABLE"
            ]
        )
        let result = try await FoundationProcessRunner().run(
            ProcessRequest(
                executableURL: URL(filePath: executable),
                arguments: [
                    "--stornaut-r5-network-denial-probe",
                    "9",
                    "-",
                    "/tmp/s5-negative-control.sock",
                ],
                environment: ["PATH": "/usr/bin:/bin"],
                currentDirectoryURL:
                    FileManager.default.temporaryDirectory,
                standardOutputLimit: 4_096,
                standardErrorLimit: 4_096,
                timeout: .seconds(5)
            )
        )

        #expect(result.exitStatus != 0)
        #expect(result.stdout.isEmpty)
    }

    @Test
    func assemblerRequiresDisjointWorkerAndLifecycleIntegrity() throws {
        let worker = try CapabilityRuntimeWorkerEvidence(
            investigationID: capabilityInvestigationID,
            evidenceBindingSHA256: capabilityEvidenceBindingSHA256,
            codexVersion: "codex-cli 0.147.0",
            codexExecutableSHA256: digest("c"),
            provider: .openAI,
            publicEndpointHosts: ["example.com"],
            syntheticFixtureSHA256s: [digest("d"), digest("e")],
            sanitizedEventCategories: [
                "item.completed.commandExecution",
                "item.completed.webSearch",
            ],
            durationMilliseconds: 1_250,
            capabilities: passingCapabilities(),
            integrity: workerIntegrity()
        )
        let lifecycle = try CapabilityRuntimeLifecycleEvidence(
            integrity: lifecycleIntegrity()
        )
        let repository = try CapabilityRuntimeRepositoryEvidence(
            integrity: repositoryIntegrity()
        )

        let report = try CapabilityRuntimeDiagnosticAssembler().assemble(
            metadata: metadata(),
            worker: worker,
            lifecycle: lifecycle,
            repository: repository,
            externalStateReasonKeys: []
        )

        #expect(report.outcome == .signedRuntimeReady)
        #expect(
            Set(report.integrity.map(\.property))
                == CapabilityRuntimeIntegrityProperty.required
        )
    }

    @Test
    func verifierRevalidatesAndAssemblesOnlyCompleteSignedEvidence()
        throws
    {
        let report = try CapabilityRuntimeDiagnosticVerifier()
            .assembleSignedRuntimeReport(
                metadata: metadata(),
                worker: CapabilityRuntimeWorkerEvidence(
                    investigationID: capabilityInvestigationID,
                    evidenceBindingSHA256:
                        capabilityEvidenceBindingSHA256,
                    codexVersion: "codex-cli 0.147.0",
                    codexExecutableSHA256: digest("c"),
                    provider: .openAI,
                    publicEndpointHosts: ["example.com"],
                    syntheticFixtureSHA256s: [
                        digest("d"),
                        digest("e"),
                    ],
                    sanitizedEventCategories: [
                        "item.completed.commandExecution",
                        "item.completed.webSearch",
                    ],
                    durationMilliseconds: 1_250,
                    capabilities: passingCapabilities(),
                    integrity: workerIntegrity()
                ),
                lifecycleIntegrity: lifecycleIntegrity(),
                repository: CapabilityRuntimeRepositoryEvidence(
                    integrity: repositoryIntegrity()
                )
            )

        #expect(report.outcome == .signedRuntimeReady)
        #expect(
            try CapabilityRuntimeDiagnosticVerifier()
                .verifyReadyReport(report) == report
        )
    }

    @Test
    func verifierRejectsDecodedBlockedReport() throws {
        var capabilities = passingCapabilities()
        capabilities[0] = try CapabilityRuntimeCapabilityEvidence(
            capability: capabilities[0].capability,
            advertised: true,
            configured: true,
            invoked: true,
            observed: false,
            reasonKey: "runtime.capability.not-observed"
        )
        let blocked = try CapabilityRuntimeDiagnosticReport(
            metadata: metadata(),
            capabilities: capabilities,
            integrity: passingIntegrity(),
            externalStateReasonKeys: []
        )
        let decoded = try JSONDecoder().decode(
            CapabilityRuntimeDiagnosticReport.self,
            from: JSONEncoder().encode(blocked)
        )

        #expect(throws: CapabilityRuntimeDiagnosticError.invalidReport) {
            _ = try CapabilityRuntimeDiagnosticVerifier()
                .verifyReadyReport(decoded)
        }
    }

    @Test
    func verifierRejectsAnotherBundleOrModel() throws {
        let otherBundle = try CapabilityRuntimeDiagnosticMetadata(
            appBundleIdentifier: "com.example.other",
            appExecutableSHA256: digest("a"),
            appDesignatedRequirementSHA256: digest("b"),
            signatureKind: .adHoc,
            codexVersion: "codex-cli 0.147.0",
            codexExecutableSHA256: digest("c"),
            model: .gpt56Luna,
            provider: .openAI,
            publicEndpointHosts: ["example.com"],
            syntheticFixtureSHA256s: [digest("d"), digest("e")],
            sanitizedEventCategories: [
                "item.completed.commandExecution",
                "item.completed.webSearch",
            ],
            durationMilliseconds: 1_250
        )
        let worker = try CapabilityRuntimeWorkerEvidence(
            investigationID: capabilityInvestigationID,
            evidenceBindingSHA256: capabilityEvidenceBindingSHA256,
            codexVersion: "codex-cli 0.147.0",
            codexExecutableSHA256: digest("c"),
            provider: .openAI,
            publicEndpointHosts: ["example.com"],
            syntheticFixtureSHA256s: [digest("d"), digest("e")],
            sanitizedEventCategories: [
                "item.completed.commandExecution",
                "item.completed.webSearch",
            ],
            durationMilliseconds: 1_250,
            capabilities: passingCapabilities(),
            integrity: workerIntegrity()
        )

        #expect(throws: CapabilityRuntimeDiagnosticError.invalidReport) {
            _ = try CapabilityRuntimeDiagnosticVerifier()
                .assembleSignedRuntimeReport(
                    metadata: otherBundle,
                    worker: worker,
                    lifecycleIntegrity: lifecycleIntegrity(),
                    repository: CapabilityRuntimeRepositoryEvidence(
                        integrity: repositoryIntegrity()
                    )
                )
        }
    }

    @Test
    func providerEvidenceRejectsRemovedCustomProviderIdentity() {
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                CodexRuntimeProvider.self,
                from: Data(#""stornaut-openrouter-v1""#.utf8)
            )
        }
    }

    @Test
    func assemblerRejectsWorkerClaimingLifecycleAuthority() throws {
        let lifecycleRow = try CapabilityRuntimeIntegrityEvidence(
            property: .helperCallerAuthentication,
            verdict: .contained,
            reasonKey: nil
        )

        #expect(throws: CapabilityRuntimeDiagnosticError.invalidReport) {
            _ = try CapabilityRuntimeWorkerEvidence(
                investigationID: capabilityInvestigationID,
                evidenceBindingSHA256:
                    capabilityEvidenceBindingSHA256,
                codexVersion: "codex-cli 0.147.0",
                codexExecutableSHA256: digest("c"),
                provider: .openAI,
                publicEndpointHosts: ["example.com"],
                syntheticFixtureSHA256s: [digest("d")],
                sanitizedEventCategories: [],
                durationMilliseconds: 1,
                capabilities: passingCapabilities(),
                integrity: workerIntegrity() + [lifecycleRow]
            )
        }
    }

    @Test
    func assemblerRejectsLifecycleClaimingWorkerContainment() throws {
        let workerRow = try CapabilityRuntimeIntegrityEvidence(
            property: .userDataWriteDenial,
            verdict: .contained,
            reasonKey: nil
        )

        #expect(throws: CapabilityRuntimeDiagnosticError.invalidReport) {
            _ = try CapabilityRuntimeLifecycleEvidence(
                integrity: lifecycleIntegrity() + [workerRow]
            )
        }
    }

    @Test
    func assemblerRejectsWorkerClaimingRepositoryBoundary() throws {
        let repositoryRow = try CapabilityRuntimeIntegrityEvidence(
            property: .noExecutorReachability,
            verdict: .contained,
            reasonKey: nil
        )

        #expect(throws: CapabilityRuntimeDiagnosticError.invalidReport) {
            _ = try CapabilityRuntimeWorkerEvidence(
                investigationID: capabilityInvestigationID,
                evidenceBindingSHA256:
                    capabilityEvidenceBindingSHA256,
                codexVersion: "codex-cli 0.147.0",
                codexExecutableSHA256: digest("c"),
                provider: .openAI,
                publicEndpointHosts: ["example.com"],
                syntheticFixtureSHA256s: [digest("d")],
                sanitizedEventCategories: [],
                durationMilliseconds: 1,
                capabilities: passingCapabilities(),
                integrity: workerIntegrity() + [repositoryRow]
            )
        }
    }

    @Test
    func completeSignedEvidenceProducesOnlyReadyOutcome() throws {
        let report = try passingReport()

        #expect(report.outcome == .signedRuntimeReady)
        #expect(
            Set(report.capabilities.map(\.capability))
                == CapabilityRuntimeCapability.required
        )
        #expect(report.capabilities.allSatisfy { $0.observed })
        #expect(report.integrity.allSatisfy {
            $0.verdict == .contained
        })
    }

    @Test
    func configuredOrInvokedEvidenceCannotBecomeObserved() throws {
        var capabilities = passingCapabilities()
        capabilities[0] = try CapabilityRuntimeCapabilityEvidence(
            capability: capabilities[0].capability,
            advertised: true,
            configured: true,
            invoked: true,
            observed: false,
            reasonKey: "runtime.capability.not-observed"
        )

        let report = try CapabilityRuntimeDiagnosticReport(
            metadata: metadata(),
            capabilities: capabilities,
            integrity: passingIntegrity(),
            externalStateReasonKeys: []
        )

        #expect(
            report.outcome == .signedRuntimeBlocked(
                reasonKeys: ["runtime.capability.not-observed"]
            )
        )
    }

    @Test
    func failedIntegrityDominatesExternalState() throws {
        var integrity = passingIntegrity()
        integrity[0] = try CapabilityRuntimeIntegrityEvidence(
            property: integrity[0].property,
            verdict: .failed,
            reasonKey: "runtime.integrity.write-succeeded"
        )

        let report = try CapabilityRuntimeDiagnosticReport(
            metadata: metadata(),
            capabilities: passingCapabilities(),
            integrity: integrity,
            externalStateReasonKeys: ["runtime.external.public-endpoint"]
        )

        #expect(
            report.outcome == .signedRuntimeBlocked(
                reasonKeys: ["runtime.integrity.write-succeeded"]
            )
        )
    }

    @Test
    func externalStateRemainsDistinctFromIntegrityFailure() throws {
        let report = try CapabilityRuntimeDiagnosticReport(
            metadata: metadata(),
            capabilities: passingCapabilities(),
            integrity: passingIntegrity(),
            externalStateReasonKeys: [
                "runtime.external.service-approval-required",
            ]
        )

        #expect(
            report.outcome == .externalStateBlocked(
                reasonKeys: [
                    "runtime.external.service-approval-required",
                ]
            )
        )
    }

    @Test
    func missingEvidenceDominatesExternalState() throws {
        var capabilities = passingCapabilities()
        capabilities[0] = try CapabilityRuntimeCapabilityEvidence(
            capability: capabilities[0].capability,
            advertised: true,
            configured: true,
            invoked: false,
            observed: false,
            reasonKey: "runtime.capability.not-invoked"
        )
        var integrity = passingIntegrity()
        integrity[0] = try CapabilityRuntimeIntegrityEvidence(
            property: integrity[0].property,
            verdict: .unverified,
            reasonKey: "runtime.integrity.not-verified"
        )

        let report = try CapabilityRuntimeDiagnosticReport(
            metadata: metadata(),
            capabilities: capabilities,
            integrity: integrity,
            externalStateReasonKeys: [
                "runtime.external.service-unavailable",
            ]
        )

        #expect(
            report.outcome == .signedRuntimeBlocked(
                reasonKeys: [
                    "runtime.capability.not-invoked",
                    "runtime.integrity.not-verified",
                ]
            )
        )
    }

    @Test
    func duplicateMissingAndContradictoryRowsFailClosed() throws {
        let capabilities = passingCapabilities()
        let integrity = passingIntegrity()

        #expect(throws: CapabilityRuntimeDiagnosticError.self) {
            _ = try CapabilityRuntimeDiagnosticReport(
                metadata: metadata(),
                capabilities: capabilities + [capabilities[0]],
                integrity: integrity,
                externalStateReasonKeys: []
            )
        }
        #expect(throws: CapabilityRuntimeDiagnosticError.self) {
            _ = try CapabilityRuntimeDiagnosticReport(
                metadata: metadata(),
                capabilities: Array(capabilities.dropLast()),
                integrity: integrity,
                externalStateReasonKeys: []
            )
        }
        #expect(throws: CapabilityRuntimeDiagnosticError.self) {
            _ = try CapabilityRuntimeCapabilityEvidence(
                capability: .shell,
                advertised: true,
                configured: false,
                invoked: true,
                observed: true,
                reasonKey: nil
            )
        }
        #expect(throws: CapabilityRuntimeDiagnosticError.self) {
            _ = try CapabilityRuntimeIntegrityEvidence(
                property: .userDataWriteDenial,
                verdict: .failed,
                reasonKey: nil
            )
        }
    }

    @Test
    func encodedReportContainsOnlyPrivacySafeMetadata() throws {
        let data = try JSONEncoder().encode(passingReport())
        let text = String(decoding: data, as: UTF8.self)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(Set(object.keys) == [
            "capabilities",
            "externalStateReasonKeys",
            "integrity",
            "metadata",
            "outcome",
            "schemaVersion",
        ])
        for forbidden in [
            "/Users/",
            "access_token",
            "auth.json",
            "environment",
            "prompt",
            "rawJSONL",
        ] {
            #expect(!text.localizedCaseInsensitiveContains(forbidden))
        }
    }
}

private func passingReport() throws -> CapabilityRuntimeDiagnosticReport {
    try CapabilityRuntimeDiagnosticReport(
        metadata: metadata(),
        capabilities: passingCapabilities(),
        integrity: passingIntegrity(),
        externalStateReasonKeys: []
    )
}

private func passingCapabilities() -> [CapabilityRuntimeCapabilityEvidence] {
    CapabilityRuntimeCapability.required.sorted {
        $0.rawValue < $1.rawValue
    }.map {
        try! CapabilityRuntimeCapabilityEvidence(
            capability: $0,
            advertised: true,
            configured: true,
            invoked: true,
            observed: true,
            reasonKey: nil
        )
    }
}

private func passingIntegrity() -> [CapabilityRuntimeIntegrityEvidence] {
    CapabilityRuntimeIntegrityProperty.required.sorted {
        $0.rawValue < $1.rawValue
    }.map {
        try! CapabilityRuntimeIntegrityEvidence(
            property: $0,
            verdict: .contained,
            reasonKey: nil
        )
    }
}

private func workerIntegrity() -> [CapabilityRuntimeIntegrityEvidence] {
    let properties: Set<CapabilityRuntimeIntegrityProperty> = [
        .userDataWriteDenial,
        .nestedDescendantWriteDenial,
        .loopbackPrivateLinkLocalDenial,
        .unixSocketDenial,
        .runtimeStateCleanup,
        .authStateNonPersistence,
    ]
    return properties.sorted { $0.rawValue < $1.rawValue }.map {
        try! CapabilityRuntimeIntegrityEvidence(
            property: $0,
            verdict: .contained,
            reasonKey: nil
        )
    }
}

private func repositoryIntegrity()
    -> [CapabilityRuntimeIntegrityEvidence]
{
    [
        try! CapabilityRuntimeIntegrityEvidence(
            property: .noExecutorReachability,
            verdict: .contained,
            reasonKey: nil
        ),
    ]
}

private func lifecycleIntegrity() -> [CapabilityRuntimeIntegrityEvidence] {
    let properties: Set<CapabilityRuntimeIntegrityProperty> = [
        .signedAppIdentity,
        .helperCallerAuthentication,
        .perInvestigationAuditSession,
        .timeoutCancellationCleanup,
        .helperCrashRecovery,
    ]
    return properties.sorted { $0.rawValue < $1.rawValue }.map {
        try! CapabilityRuntimeIntegrityEvidence(
            property: $0,
            verdict: .contained,
            reasonKey: nil
        )
    }
}

private extension CapabilityRuntimeContainmentSnapshot {
    func replacing(
        observedMarkerIDs: Set<String>? = nil,
        mutationResidue: Bool? = nil,
        requiresPrivateDenial: Bool? = nil,
        authUnchanged: Bool? = nil
    ) -> Self {
        Self(
            observedMarkerIDs:
                observedMarkerIDs ?? self.observedMarkerIDs,
            mutationResidue: mutationResidue ?? self.mutationResidue,
            requiresPrivateDenial:
                requiresPrivateDenial ?? self.requiresPrivateDenial,
            authUnchanged: authUnchanged ?? self.authUnchanged
        )
    }
}

private func metadata() -> CapabilityRuntimeDiagnosticMetadata {
    try! CapabilityRuntimeDiagnosticMetadata(
        appBundleIdentifier: "com.eriklee.stornaut",
        appExecutableSHA256: digest("a"),
        appDesignatedRequirementSHA256: digest("b"),
        signatureKind: .adHoc,
        codexVersion: "codex-cli 0.147.0",
        codexExecutableSHA256: digest("c"),
        model: .gpt56Luna,
        provider: .openAI,
        publicEndpointHosts: ["example.com"],
        syntheticFixtureSHA256s: [digest("d"), digest("e")],
        sanitizedEventCategories: [
            "item.completed.commandExecution",
            "item.completed.webSearch",
        ],
        durationMilliseconds: 1_250
    )
}

private let capabilityInvestigationID = UUID(
    uuidString: "11111111-2222-4333-8444-555555555555"
)!
private let capabilityEvidenceBindingSHA256 =
    String(repeating: "9", count: 64)

private func digest(_ character: Character) -> String {
    String(repeating: String(character), count: 64)
}
