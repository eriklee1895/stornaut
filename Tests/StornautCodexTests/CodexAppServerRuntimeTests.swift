import Foundation
import Testing
@testable import StornautCodex

@Suite("Closed Codex App Server runtime")
struct CodexAppServerRuntimeTests {
    @Test
    func emitsOnlyTheFixedExternalSandboxSequence() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()

        let initialize = try #require(try runtime.begin().only)
        #expect(try method(in: initialize) == "initialize")
        #expect(try identifier(in: initialize) == 1)
        #expect(try object(in: initialize) == [
            "id": .number(1),
            "method": .string("initialize"),
            "params": .object([
                "capabilities": .object([
                    "experimentalApi": .bool(true),
                        "optOutNotificationMethods": .array([
                            .string("item/agentMessage/delta"),
                            .string("item/commandExecution/terminalInteraction"),
                            .string("item/plan/delta"),
                            .string(
                                "item/reasoning/summaryPartAdded"
                            ),
                            .string(
                                "item/reasoning/summaryTextDelta"
                            ),
                            .string("thread/started"),
                            .string("thread/status/changed"),
                            .string("thread/tokenUsage/updated"),
                            .string("turn/plan/updated"),
                        ]),
                ]),
                "clientInfo": .object([
                    "name": .string("stornaut"),
                    "title": .string("Stornaut"),
                    "version": .string("1"),
                ]),
            ]),
        ])
        let initializeObject = try object(in: initialize)
        #expect(
            !String(reflecting: initializeObject).contains(
                "item/commandExecution/outputDelta"
            )
        )

        let afterInitialize = try runtime.receive(
            line([
                "id": .number(1),
                "result": .object([
                    "codexHome": .string(fixture.workspace.runtimeURL.path),
                    "platformFamily": .string("unix"),
                    "platformOs": .string("macos"),
                    "userAgent": .string("codex_cli_rs/0.147.0"),
                ]),
            ])
        )
        #expect(afterInitialize.count == 2)
        #expect(try method(in: afterInitialize[0]) == "initialized")
        #expect(try object(in: afterInitialize[0]) == [
            "method": .string("initialized"),
        ])
        #expect(try method(in: afterInitialize[1]) == "account/login/start")
        #expect(try identifier(in: afterInitialize[1]) == 2)
        #expect(try object(in: afterInitialize[1]) == [
            "id": .number(2),
            "method": .string("account/login/start"),
            "params": .object([
                "accessToken": .string("header.access.signature"),
                "chatgptAccountId": .string("synthetic-account"),
                "chatgptPlanType": .null,
                "type": .string("chatgptAuthTokens"),
            ]),
        ])

        let threadRequest = try #require(
            try runtime.receive(
                line([
                    "id": .number(2),
                    "result": .object([
                        "type": .string("chatgptAuthTokens"),
                    ]),
                ])
            ).only
        )
        #expect(try method(in: threadRequest) == "thread/start")
        #expect(try object(in: threadRequest) == [
            "id": .number(3),
            "method": .string("thread/start"),
            "params": .object([
                "approvalPolicy": .string("never"),
                "cwd": .string(fixture.workspace.workURL.path),
                "ephemeral": .bool(true),
                "model": .string("gpt-5.6-luna"),
                "modelProvider": .string("openai"),
            ]),
        ])

        let turnRequest = try #require(
            try runtime.receive(
                line([
                    "id": .number(3),
                    "result": .object([
                        "activePermissionProfile": .object([
                            "id": .string("stornaut-outer-v1"),
                        ]),
                        "approvalPolicy": .string("never"),
                        "cwd": .string(fixture.workspace.workURL.path),
                        "instructionSources": .array([]),
                        "model": .string("gpt-5.6-luna"),
                        "modelProvider": .string("openai"),
                        "thread": .object([
                            "id": .string("thread-synthetic"),
                            "modelProvider": .string("openai"),
                        ]),
                    ]),
                ])
            ).only
        )
        #expect(try method(in: turnRequest) == "turn/start")
        #expect(try object(in: turnRequest) == [
            "id": .number(4),
            "method": .string("turn/start"),
            "params": .object([
                "approvalPolicy": .string("never"),
                "cwd": .string(fixture.workspace.workURL.path),
                "input": .array([
                    .object([
                        "text": .string("Inspect only synthetic fixtures."),
                        "textElements": .array([]),
                        "type": .string("text"),
                    ]),
                ]),
                "model": .string("gpt-5.6-luna"),
                "outputSchema": fixture.outputSchema,
                "sandboxPolicy": .object([
                    "networkAccess": .string("enabled"),
                    "type": .string("externalSandbox"),
                ]),
                "threadId": .string("thread-synthetic"),
            ]),
        ])

        #expect(
            try runtime.receive(
                line([
                    "id": .number(4),
                    "result": .object([
                        "turn": .object([
                            "id": .string("turn-synthetic"),
                            "items": .array([]),
                            "status": .string("inProgress"),
                        ]),
                    ]),
                ])
            ).isEmpty
        )
        #expect(runtime.status == .running)

        for notification in [
            line([
                "method": .string("thread/settings/updated"),
                "params": .object([
                    "threadId": .string("thread-synthetic"),
                    "threadSettings": .object([
                        "approvalPolicy": .string("never"),
                        "cwd": .string(fixture.workspace.workURL.path),
                        "model": .string("gpt-5.6-luna"),
                        "modelProvider": .string("openai"),
                        "sandboxPolicy": .object([
                            "networkAccess": .string("enabled"),
                            "type": .string("externalSandbox"),
                        ]),
                    ]),
                ]),
            ]),
            line([
                "method": .string("turn/started"),
                "params": .object([
                    "threadId": .string("thread-synthetic"),
                    "turn": .object([
                        "id": .string("turn-synthetic"),
                        "items": .array([]),
                        "status": .string("inProgress"),
                    ]),
                ]),
            ]),
            line([
                "method": .string("item/completed"),
                "params": .object([
                    "item": .object([
                        "id": .string("message-synthetic"),
                        "text": .string(#"{"verdict":"passed"}"#),
                        "type": .string("agentMessage"),
                    ]),
                    "threadId": .string("thread-synthetic"),
                    "turnId": .string("turn-synthetic"),
                ]),
            ]),
            line([
                "method": .string("turn/completed"),
                "params": .object([
                    "threadId": .string("thread-synthetic"),
                    "turn": .object([
                        "id": .string("turn-synthetic"),
                        "items": .array([]),
                        "status": .string("completed"),
                    ]),
                ]),
            ]),
        ] {
            #expect(try runtime.receive(notification).isEmpty)
        }
        #expect(runtime.status == .completed)
        #expect(runtime.observation.notificationMethods == [
            "item/completed",
            "thread/settings/updated",
            "turn/completed",
            "turn/started",
        ])
        #expect(runtime.observation.itemTypes == ["agentMessage"])
        #expect(
            runtime.observation.finalAgentMessage
                == #"{"verdict":"passed"}"#
        )
        #expect(throws: CodexAppServerRuntimeError.self) {
            _ = try runtime.begin()
        }
    }

    @Test
    func separatesToolProbeFromNoToolStructuredFinalization() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime(
            finalizationPrompt: "Return the validated synthetic envelope."
        )

        let finalizationRequest = try fixture
            .advanceToFinalizationRunning(runtime)
        let finalizationObject = try object(in: finalizationRequest)
        guard
            case let .object(finalizationParams) =
                finalizationObject["params"],
            case let .array(finalizationInput) =
                finalizationParams["input"]
        else {
            Issue.record("Expected finalization turn parameters")
            return
        }

        #expect(try identifier(in: finalizationRequest) == 5)
        #expect(
            finalizationParams["outputSchema"] == fixture.outputSchema
        )
        #expect(finalizationInput == [
            .object([
                "text": .string(
                    "Return the validated synthetic envelope."
                ),
                "textElements": .array([]),
                "type": .string("text"),
            ]),
        ])
        #expect(runtime.observation.finalAgentMessage == nil)

        _ = try runtime.receive(
            fixture.agentMessageCompleted(
                #"{"verdict":"passed"}"#,
                turnID: "turn-finalization"
            )
        )
        #expect(
            try runtime.receive(
                fixture.turnCompleted(turnID: "turn-finalization")
            ).isEmpty
        )

        #expect(runtime.status == .completed)
        #expect(
            runtime.observation.finalAgentMessage
                == #"{"verdict":"passed"}"#
        )
    }

    @Test
    func rejectsToolItemsDuringStructuredFinalization() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime(
            finalizationPrompt: "Return the validated synthetic envelope."
        )
        _ = try fixture.advanceToFinalizationRunning(runtime)

        #expect(
            throws: CodexAppServerRuntimeError.unexpectedItem(
                type: "commandExecution"
            )
        ) {
            _ = try runtime.receive(
                fixture.itemStarted(
                    [
                        "command": .string("cat ./direct-read.txt"),
                        "cwd": .string(fixture.workspace.workURL.path),
                        "id": .string("forbidden-finalization-command"),
                        "source": .string("agent"),
                        "status": .string("inProgress"),
                        "type": .string("commandExecution"),
                    ],
                    turnID: "turn-finalization"
                )
            )
        }
        #expect(runtime.status == .failed)
    }

    @Test
    func permitsOneIdentityBoundExternalAuthRefresh() throws {
        let fixture = AppServerFixture()
        let refresh = RecordingRefreshProvider(
            result: fixture.authProjection(
                accessToken: "header.refreshed.signature"
            )
        )
        let runtime = fixture.makeRuntime(refreshProvider: refresh)
        try fixture.advanceToRunning(runtime)

        let response = try #require(
            try runtime.receive(
                line([
                    "id": .string("refresh-1"),
                    "method": .string(
                        "account/chatgptAuthTokens/refresh"
                    ),
                    "params": .object([
                        "previousAccountId": .string(
                            "synthetic-account"
                        ),
                        "reason": .string("unauthorized"),
                    ]),
                ])
            ).only
        )

        #expect(try object(in: response) == [
            "id": .string("refresh-1"),
            "result": .object([
                "accessToken": .string("header.refreshed.signature"),
                "chatgptAccountId": .string("synthetic-account"),
                "chatgptPlanType": .null,
            ]),
        ])
        #expect(refresh.callCount == 1)
        #expect(throws: CodexAppServerRuntimeError.self) {
            _ = try runtime.receive(
                line([
                    "id": .string("refresh-2"),
                    "method": .string(
                        "account/chatgptAuthTokens/refresh"
                    ),
                    "params": .object([
                        "previousAccountId": .string(
                            "synthetic-account"
                        ),
                        "reason": .string("unauthorized"),
                    ]),
                ])
            )
        }
        #expect(refresh.callCount == 1)
    }

    @Test
    func acceptsOnlyExternalChatGPTAuthUpdateIdentity() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()
        _ = try runtime.begin()
        _ = try runtime.receive(
            line([
                "id": .number(1),
                "result": .object([
                    "codexHome": .string(
                        fixture.workspace.runtimeURL.path
                    ),
                ]),
            ])
        )

        #expect(
            try runtime.receive(
                line([
                    "method": .string("account/updated"),
                    "params": .object([
                        "authMode": .string("chatgptAuthTokens"),
                        "planType": .string("plus"),
                    ]),
                ])
            ).isEmpty
        )
        for authMode in ["chatgpt", "apikey", "headers"] {
            let rejected = fixture.makeRuntime()
            _ = try rejected.begin()
            _ = try rejected.receive(
                line([
                    "id": .number(1),
                    "result": .object([
                        "codexHome": .string(
                            fixture.workspace.runtimeURL.path
                        ),
                    ]),
                ])
            )
            #expect(throws: CodexAppServerRuntimeError.self) {
                _ = try rejected.receive(
                    line([
                        "method": .string("account/updated"),
                        "params": .object([
                            "authMode": .string(authMode),
                            "planType": .null,
                        ]),
                    ])
                )
            }
        }
    }

    @Test
    func rejectsNonOpenAIProviderIdentity() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()
        _ = try runtime.begin()
        _ = try runtime.receive(
            line([
                "id": .number(1),
                "result": .object([
                    "codexHome": .string(
                        fixture.workspace.runtimeURL.path
                    ),
                ]),
            ])
        )
        _ = try runtime.receive(
            line([
                "id": .number(2),
                "result": .object([
                    "type": .string("chatgptAuthTokens"),
                ]),
            ])
        )

        #expect(
            throws: CodexAppServerRuntimeError.identityMismatch(
                reasonKey: "appServer.thread.response"
            )
        ) {
            _ = try runtime.receive(
                fixture.threadResponse(provider: "custom")
            )
        }
    }

    @Test
    func structuredRuntimeSkillIsIncludedInTurnInput() throws {
        let fixture = AppServerFixture()
        let skillURL = fixture.workspace.runtimeURL.appending(
            path: "skills/stornaut-r5-diagnostic/SKILL.md"
        )
        let runtime = try CodexAppServerRuntime(
            request: CodexAppServerRuntimeRequest(
                projectedAuthSourceURL: fixture.authSourceURL,
                runtimeHomeURL: fixture.workspace.runtimeURL,
                workingDirectoryURL: fixture.workspace.workURL,
                prompt: "Inspect only synthetic fixtures.",
                outputSchema: fixture.outputSchema,
                selectedRuntimeSkill:
                    CodexSelectedRuntimeSkill(
                        name: "stornaut-r5-diagnostic",
                        path: skillURL
                    )
            ),
            authProjection: fixture.authProjection(),
            refreshProvider: nil
        )
        _ = try runtime.begin()
        _ = try runtime.receive(
            line([
                "id": .number(1),
                "result": .object([
                    "codexHome": .string(
                        fixture.workspace.runtimeURL.path
                    ),
                ]),
            ])
        )
        _ = try runtime.receive(
            line([
                "id": .number(2),
                "result": .object([
                    "type": .string("chatgptAuthTokens"),
                ]),
            ])
        )
        let turn = try #require(
            try runtime.receive(
                line([
                    "id": .number(3),
                    "result": .object([
                        "activePermissionProfile": .object([
                            "id": .string("stornaut-outer-v1"),
                        ]),
                        "approvalPolicy": .string("never"),
                        "cwd": .string(fixture.workspace.workURL.path),
                        "instructionSources": .array([]),
                        "model": .string("gpt-5.6-luna"),
                        "modelProvider": .string("openai"),
                        "thread": .object([
                            "id": .string("thread-synthetic"),
                            "modelProvider": .string("openai"),
                        ]),
                    ]),
                ])
            ).only
        )
        let object = try object(in: turn)
        guard
            case let .object(params) = object["params"],
            case let .array(input) = params["input"]
        else {
            Issue.record("Expected turn input")
            return
        }
        #expect(input.contains(.object([
            "name": .string("stornaut-r5-diagnostic"),
            "path": .string(skillURL.path),
            "type": .string("skill"),
        ])))
    }

    @Test
    func failsClosedOnUnexpectedRPCWriteOrApprovalSurface() throws {
        for forbidden in [
            line([
                "id": .number(99),
                "method": .string("process/spawn"),
                "params": .object([:]),
            ]),
            line([
                "id": .number(99),
                "method": .string("fs/writeFile"),
                "params": .object([:]),
            ]),
            line([
                "id": .number(99),
                "method": .string(
                    "item/commandExecution/requestApproval"
                ),
                "params": .object([:]),
            ]),
            line([
                "method": .string("item/completed"),
                "params": .object([
                    "item": .object([
                        "id": .string("write-item"),
                        "status": .string("failed"),
                        "type": .string("fileChange"),
                    ]),
                    "threadId": .string("thread-synthetic"),
                    "turnId": .string("turn-synthetic"),
                ]),
            ]),
        ] {
            let fixture = AppServerFixture()
            let runtime = fixture.makeRuntime()
            try fixture.advanceToRunning(runtime)
            #expect(throws: CodexAppServerRuntimeError.self) {
                _ = try runtime.receive(forbidden)
            }
            #expect(runtime.status == .failed)
        }
    }

    @Test
    func acceptsOnlyDisabledRemoteControlAndRejectsWarnings() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()
        _ = try runtime.begin()

        #expect(
            try runtime.receive(
                line([
                    "method": .string("remoteControl/status/changed"),
                    "params": .object([
                        "environmentId": .null,
                        "serverName": .string("Synthetic Mac"),
                        "status": .string("disabled"),
                    ]),
                ])
            ).isEmpty
        )

        for forbidden in [
            line([
                "method": .string("remoteControl/status/changed"),
                "params": .object([
                    "environmentId": .string("remote-environment"),
                    "serverName": .string("Synthetic Mac"),
                    "status": .string("connected"),
                ]),
            ]),
            line([
                "method": .string("configWarning"),
                "params": .object([
                    "summary": .string("synthetic warning"),
                ]),
            ]),
            line([
                "method": .string("warning"),
                "params": .object([
                    "message": .string("synthetic warning"),
                ]),
            ]),
        ] {
            let candidate = fixture.makeRuntime()
            _ = try candidate.begin()
            #expect(throws: CodexAppServerRuntimeError.self) {
                _ = try candidate.receive(forbidden)
            }
            #expect(candidate.status == .failed)
        }
    }

    @Test
    func retainsOnlySanitizedUpstreamErrorCategoryCodeAndRetry() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()
        try fixture.advanceToRunning(runtime)

        #expect(
            throws: CodexAppServerRuntimeError.upstreamError(
                CodexSanitizedUpstreamError(
                    category: .httpConnectionFailed,
                    code: 503,
                    willRetry: true
                )
            )
        ) {
            _ = try runtime.receive(
                line([
                    "method": .string("error"),
                    "params": .object([
                        "error": .object([
                            "additionalDetails": .string(
                                "/Users/private must-not-be-retained"
                            ),
                            "codexErrorInfo": .object([
                                "httpConnectionFailed": .object([
                                    "httpStatusCode": .number(503),
                                ]),
                            ]),
                            "message": .string(
                                "credential must-not-be-retained"
                            ),
                        ]),
                        "threadId": .string("thread-synthetic"),
                        "turnId": .string("turn-synthetic"),
                        "willRetry": .bool(true),
                    ]),
                ])
            )
        }
        #expect(runtime.status == .failed)
        let reflected = String(
            reflecting: CodexAppServerRuntimeError.upstreamError(
                CodexSanitizedUpstreamError(
                    category: .httpConnectionFailed,
                    code: 503,
                    willRetry: true
                )
            )
        )
        #expect(!reflected.contains("must-not-be-retained"))
        #expect(!reflected.contains("/Users/private"))
        #expect(!reflected.contains("credential"))
    }

    @Test
    func permitsExactlyFiveIdentityBoundRetryableStreamDisconnects()
        throws
    {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()
        try fixture.advanceToRunning(runtime)
        let retryable = line([
            "method": .string("error"),
            "params": .object([
                "error": .object([
                    "codexErrorInfo": .object([
                        "responseStreamDisconnected": .object([:]),
                    ]),
                    "message": .string(
                        "raw transport text must-not-be-retained"
                    ),
                ]),
                "threadId": .string("thread-synthetic"),
                "turnId": .string("turn-synthetic"),
                "willRetry": .bool(true),
            ]),
        ])

        for expectedCount in 1...5 {
            #expect(try runtime.receive(retryable).isEmpty)
            #expect(runtime.status == .running)
            #expect(
                runtime.observation.upstreamErrors.count
                    == expectedCount
            )
        }
        #expect(runtime.observation.upstreamErrors.allSatisfy {
            $0 == CodexSanitizedUpstreamError(
                category: .responseStreamDisconnected,
                code: nil,
                willRetry: true
            )
        })

        #expect(
            throws: CodexAppServerRuntimeError.upstreamError(
                CodexSanitizedUpstreamError(
                    category: .responseStreamDisconnected,
                    code: nil,
                    willRetry: true
                )
            )
        ) {
            _ = try runtime.receive(retryable)
        }
        #expect(runtime.status == .failed)
        #expect(
            !String(reflecting: runtime.observation)
                .contains("must-not-be-retained")
        )
    }

    @Test
    func nonretryableStreamDisconnectStillFailsImmediately() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()
        try fixture.advanceToRunning(runtime)

        #expect(
            throws: CodexAppServerRuntimeError.upstreamError(
                CodexSanitizedUpstreamError(
                    category: .responseStreamDisconnected,
                    code: nil,
                    willRetry: false
                )
            )
        ) {
            _ = try runtime.receive(
                line([
                    "method": .string("error"),
                    "params": .object([
                        "error": .object([
                            "codexErrorInfo": .object([
                                "responseStreamDisconnected":
                                    .object([:]),
                            ]),
                            "message": .string("raw"),
                        ]),
                        "threadId": .string("thread-synthetic"),
                        "turnId": .string("turn-synthetic"),
                        "willRetry": .bool(false),
                    ]),
                ])
            )
        }
        #expect(runtime.status == .failed)
    }

    @Test
    func supportsClosedStringUpstreamErrorCategoriesWithoutRawText() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()
        try fixture.advanceToRunning(runtime)

        #expect(
            throws: CodexAppServerRuntimeError.upstreamError(
                CodexSanitizedUpstreamError(
                    category: .unauthorized,
                    code: nil,
                    willRetry: false
                )
            )
        ) {
            _ = try runtime.receive(
                line([
                    "method": .string("error"),
                    "params": .object([
                        "error": .object([
                            "codexErrorInfo": .string("unauthorized"),
                            "message": .string("secret raw message"),
                        ]),
                        "threadId": .string("thread-synthetic"),
                        "turnId": .string("turn-synthetic"),
                        "willRetry": .bool(false),
                    ]),
                ])
            )
        }
    }

    @Test
    func unknownOrMissingUpstreamCategoryDegradesWithoutRawMessage() throws {
        let fixture = AppServerFixture()

        for errorObject: [String: JSONValue] in [
            [
                "codexErrorInfo": .string("futurePrivateCategory"),
                "message": .string("/Users/private raw future error"),
            ],
            [
                "message": .string("raw unclassified upstream error"),
            ],
        ] {
            let runtime = fixture.makeRuntime()
            try fixture.advanceToRunning(runtime)

            #expect(
                throws: CodexAppServerRuntimeError.upstreamError(
                    CodexSanitizedUpstreamError(
                        category: .unclassified,
                        code: nil,
                        willRetry: false
                    )
                )
            ) {
                _ = try runtime.receive(
                    line([
                        "method": .string("error"),
                        "params": .object([
                            "error": .object(errorObject),
                            "threadId": .string("thread-synthetic"),
                            "turnId": .string("turn-synthetic"),
                            "willRetry": .bool(false),
                        ]),
                    ])
                )
            }
        }
    }

    @Test
    func malformedUpstreamErrorMetadataFailsClosed() throws {
        let fixture = AppServerFixture()

        for params: [String: JSONValue] in [
            [
                "error": .object([
                    "codexErrorInfo": .object([
                        "httpConnectionFailed": .object([
                            "httpStatusCode": .number(70_000),
                        ]),
                    ]),
                    "message": .string("raw"),
                ]),
                "threadId": .string("thread-synthetic"),
                "turnId": .string("turn-synthetic"),
                "willRetry": .bool(false),
            ],
            [
                "error": .object([
                    "message": .string("raw"),
                ]),
                "threadId": .string("thread-synthetic"),
                "turnId": .string("turn-synthetic"),
                "willRetry": .string("false"),
            ],
        ] {
            let runtime = fixture.makeRuntime()
            try fixture.advanceToRunning(runtime)
            #expect(throws: CodexAppServerRuntimeError.invalidMessage) {
                _ = try runtime.receive(
                    line([
                        "method": .string("error"),
                        "params": .object(params),
                    ])
                )
            }
            #expect(runtime.status == .failed)
        }
    }

    @Test
    func completionWithoutBoundedFinalMessageFailsClosed() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()
        try fixture.advanceToRunning(runtime)

        #expect(
            throws: CodexAppServerRuntimeError.turnFailed(
                reasonKey: "appServer.turn.single.message"
            )
        ) {
            _ = try runtime.receive(
                line([
                    "method": .string("turn/completed"),
                    "params": .object([
                        "threadId": .string("thread-synthetic"),
                        "turn": .object([
                            "id": .string("turn-synthetic"),
                            "items": .array([]),
                            "status": .string("completed"),
                        ]),
                    ]),
                ])
            )
        }
        #expect(runtime.status == .failed)
    }

    @Test
    func recordsOnlyPrivacySafeCapabilityObservations() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()
        try fixture.advanceToRunning(runtime)

        for item: [String: JSONValue] in [
            [
                "id": .string("shell"),
                "type": .string("commandExecution"),
                "source": .string("agent"),
                "status": .string("completed"),
                "exitCode": .number(0),
                "aggregatedOutput": .string("SHELL-TOKEN"),
                "command": .string("must-not-be-retained"),
                "cwd": .string("/Users/private"),
            ],
            [
                "id": .string("unified"),
                "type": .string("commandExecution"),
                "source": .string("unifiedExecStartup"),
                "status": .string("completed"),
                "exitCode": .number(0),
                "aggregatedOutput": .string("UNIFIED-TOKEN"),
                "command": .string("must-not-be-retained"),
                "cwd": .string("/Users/private"),
            ],
            [
                "id": .string("search"),
                "type": .string("webSearch"),
                "query": .string("must-not-be-retained"),
            ],
            [
                "id": .string("image"),
                "type": .string("imageView"),
                "status": .string("completed"),
                "path": .string("/Users/private/image.png"),
            ],
            [
                "id": .string("agent"),
                "type": .string("collabAgentToolCall"),
                "tool": .string("spawnAgent"),
                "status": .string("completed"),
                "receiverThreadIds": .array([
                    .string("thread-subagent"),
                ]),
                "senderThreadId": .string("thread-synthetic"),
                "prompt": .string("must-not-be-retained"),
            ],
        ] {
            _ = try runtime.receive(
                fixture.itemCompleted(item)
            )
        }
        _ = try runtime.receive(
            fixture.agentMessageCompleted(
                #"{"verdict":"passed"}"#
            )
        )
        _ = try runtime.receive(
            line([
                "method": .string("thread/settings/updated"),
                "params": .object([
                    "threadId": .string("thread-subagent"),
                    "threadSettings": .object([
                        "approvalPolicy": .string("never"),
                        "cwd": .string(fixture.workspace.workURL.path),
                        "model": .string("gpt-5.6-luna"),
                        "modelProvider": .string("openai"),
                        "sandboxPolicy": .object([
                            "networkAccess": .string("enabled"),
                            "type": .string("externalSandbox"),
                        ]),
                    ]),
                ]),
            ])
        )
        _ = try runtime.receive(
            line([
                "method": .string("turn/started"),
                "params": .object([
                    "threadId": .string("thread-subagent"),
                    "turn": .object([
                        "id": .string("turn-subagent"),
                        "items": .array([]),
                        "status": .string("inProgress"),
                    ]),
                ]),
            ])
        )
        _ = try runtime.receive(
            line([
                "method": .string(
                    "item/commandExecution/outputDelta"
                ),
                "params": .object([
                    "delta": .string(
                        "SHELL-TOKEN must-not-become-primary"
                    ),
                    "itemId": .string("subagent-command"),
                    "threadId": .string("thread-subagent"),
                    "turnId": .string("turn-subagent"),
                ]),
            ])
        )
        _ = try runtime.receive(
            line([
                "method": .string("turn/completed"),
                "params": .object([
                    "threadId": .string("thread-subagent"),
                    "turn": .object([
                        "id": .string("turn-subagent"),
                        "items": .array([]),
                        "status": .string("completed"),
                    ]),
                ]),
            ])
        )
        _ = try runtime.receive(fixture.turnCompleted())

        let observations = runtime.observation.capabilityObservations
        #expect(observations.contains(
            .command(
                source: .agent,
                succeeded: true,
                matchedMarkerIDs: ["shell.read"]
            )
        ))
        #expect(observations.contains(
            .command(
                source: .unifiedExecStartup,
                succeeded: true,
                matchedMarkerIDs: ["unified.read"]
            )
        ))
        #expect(observations.contains(.webSearchCompleted))
        #expect(observations.contains(.imageViewCompleted))
        #expect(observations.contains(
            .subagentSpawnCompleted(receiverCount: 1)
        ))
        let reflected = String(reflecting: observations)
        #expect(!reflected.contains("must-not-be-retained"))
        #expect(!reflected.contains("/Users/private"))
    }

    @Test
    func commandOutputDeltasRetainOnlyMarkerProgress() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()
        try fixture.advanceToRunning(runtime)

        _ = try runtime.receive(
            fixture.itemStarted([
                "id": .string("streamed-command"),
                "type": .string("commandExecution"),
                "source": .string("agent"),
                "status": .string("inProgress"),
            ])
        )
        _ = try runtime.receive(
            fixture.commandOutputDelta(
                itemID: "streamed-command",
                delta: "private-output SHELL-"
            )
        )
        _ = try runtime.receive(
            fixture.commandOutputDelta(
                itemID: "streamed-command",
                delta: "TOKEN /Users/private"
            )
        )
        _ = try runtime.receive(
            fixture.itemCompleted([
                "aggregatedOutput": .null,
                "exitCode": .null,
                "id": .string("streamed-command"),
                "source": .string("agent"),
                "status": .string("completed"),
                "type": .string("commandExecution"),
            ])
        )

        #expect(
            runtime.observation.capabilityObservations
                == [
                    .command(
                        source: .agent,
                        succeeded: true,
                        matchedMarkerIDs: ["shell.read"]
                    ),
                ]
        )
        let reflected = String(
            reflecting: runtime.observation.capabilityObservations
        )
        #expect(!reflected.contains("private-output"))
        #expect(!reflected.contains("/Users/private"))
        #expect(!reflected.contains("SHELL-TOKEN"))
    }

    @Test
    func markerRequiresTheExactCommandSourceAndWorkingDirectory() throws {
        let fixture = AppServerFixture()
        let requirements = [
            "shell.read": CodexCommandIdentityRequirement(
                commands: ["./capability-probe.zsh"],
                allowedSources: [
                    .agent,
                    .unifiedExecInteraction,
                    .unifiedExecStartup,
                ]
            ),
            "unified.read": CodexCommandIdentityRequirement(
                commands: ["./unified-probe.zsh"],
                allowedSources: [.unifiedExecStartup]
            ),
        ]
        let runtime = try CodexAppServerRuntime(
            request: fixture.request(
                capabilityCommandRequirements: requirements
            ),
            authProjection: fixture.authProjection(),
            refreshProvider: nil
        )
        try fixture.advanceToRunning(runtime)

        _ = try runtime.receive(
            fixture.itemCompleted([
                "aggregatedOutput": .string("SHELL-TOKEN"),
                "command": .string("printf SHELL-TOKEN"),
                "cwd": .string(fixture.workspace.workURL.path),
                "exitCode": .number(0),
                "id": .string("forged-command"),
                "source": .string("agent"),
                "status": .string("completed"),
                "type": .string("commandExecution"),
            ])
        )
        _ = try runtime.receive(
            fixture.itemCompleted([
                "aggregatedOutput": .string("SHELL-TOKEN"),
                "command": .string("./capability-probe.zsh"),
                "cwd": .string(fixture.workspace.workURL.path),
                "exitCode": .number(0),
                "id": .string("wrong-source"),
                "source": .string("userShell"),
                "status": .string("completed"),
                "type": .string("commandExecution"),
            ])
        )
        _ = try runtime.receive(
            fixture.itemCompleted([
                "aggregatedOutput": .string("SHELL-TOKEN"),
                "command": .string("./capability-probe.zsh"),
                "cwd": .string(fixture.workspace.workURL.path),
                "exitCode": .number(0),
                "id": .string("real-command"),
                "source": .string("agent"),
                "status": .string("completed"),
                "type": .string("commandExecution"),
            ])
        )
        _ = try runtime.receive(
            fixture.itemCompleted([
                "aggregatedOutput": .string("SHELL-TOKEN"),
                "command": .string(
                    "/bin/zsh -lc ./capability-probe.zsh"
                ),
                "cwd": .string(fixture.workspace.workURL.path),
                "exitCode": .number(0),
                "id": .string("wrapped-command"),
                "source": .string("unifiedExecStartup"),
                "status": .string("completed"),
                "type": .string("commandExecution"),
            ])
        )
        _ = try runtime.receive(
            fixture.itemCompleted([
                "aggregatedOutput": .string("SHELL-TOKEN"),
                "command": .string(
                    "/bin/zsh -lc './capability-probe.zsh; true'"
                ),
                "cwd": .string(fixture.workspace.workURL.path),
                "exitCode": .number(0),
                "id": .string("forged-wrapped-command"),
                "source": .string("unifiedExecStartup"),
                "status": .string("completed"),
                "type": .string("commandExecution"),
            ])
        )

        let observations = runtime.observation.capabilityObservations
        #expect(observations.contains(
            .command(
                source: .agent,
                succeeded: true,
                matchedMarkerIDs: []
            )
        ))
        #expect(observations.contains(
            .command(
                source: .userShell,
                succeeded: true,
                matchedMarkerIDs: []
            )
        ))
        #expect(observations.contains(
            .command(
                source: .agent,
                succeeded: true,
                matchedMarkerIDs: ["shell.read"]
            )
        ))
        #expect(observations.contains(
            .command(
                source: .unifiedExecStartup,
                succeeded: true,
                matchedMarkerIDs: ["shell.read"]
            )
        ))
        #expect(
            observations.filter {
                $0 == .command(
                    source: .unifiedExecStartup,
                    succeeded: true,
                    matchedMarkerIDs: ["shell.read"]
                )
            }.count == 1
        )
    }

    @Test
    func upstreamImageViewWithoutStatusRequiresTheExpectedPath() throws {
        let fixture = AppServerFixture()
        let expectedImageURL = fixture.workspace.workURL.appending(
            path: "synthetic.png"
        )
        let runtime = try CodexAppServerRuntime(
            request: fixture.request(
                expectedImageURL: expectedImageURL
            ),
            authProjection: fixture.authProjection(),
            refreshProvider: nil
        )
        try fixture.advanceToRunning(runtime)

        _ = try runtime.receive(
            fixture.itemCompleted([
                "id": .string("wrong-image"),
                "path": .string(
                    fixture.workspace.workURL.appending(
                        path: "other.png"
                    ).path
                ),
                "type": .string("imageView"),
            ])
        )
        #expect(
            !runtime.observation.capabilityObservations.contains(
                .imageViewCompleted
            )
        )

        _ = try runtime.receive(
            fixture.itemCompleted([
                "id": .string("expected-image"),
                "path": .string(expectedImageURL.path),
                "type": .string("imageView"),
            ])
        )
        #expect(
            runtime.observation.capabilityObservations.contains(
                .imageViewCompleted
            )
        )
    }

    @Test
    func companionObservationMergesEvidenceWithoutReplacingPrimaryMessage() {
        let primary = CodexAppServerObservation(
            notificationMethods: ["turn/completed"],
            itemTypes: ["agentMessage"],
            finalAgentMessage: #"{"primary":true}"#,
            capabilityObservations: [.imageViewCompleted]
        )
        let companion = CodexAppServerObservation(
            notificationMethods: [
                "item/completed",
                "turn/completed",
            ],
            itemTypes: ["agentMessage", "webSearch"],
            finalAgentMessage: #"{"companion":true}"#,
            capabilityObservations: [
                .webSearchStarted,
                .webSearchCompleted,
            ]
        )

        let merged = primary.mergingEvidence(from: companion)

        #expect(merged.notificationMethods == [
            "item/completed",
            "turn/completed",
        ])
        #expect(merged.itemTypes == ["agentMessage", "webSearch"])
        #expect(merged.finalAgentMessage == #"{"primary":true}"#)
        #expect(Set(merged.capabilityObservations) == [
            .imageViewCompleted,
            .webSearchStarted,
            .webSearchCompleted,
        ])
        #expect(!String(reflecting: merged).contains("companion"))
    }

    @Test
    func rawWebSearchCompletionPromotesWithoutRetainingContent()
        throws
    {
        let fixture = AppServerFixture()
        let runtime = try CodexAppServerRuntime(
            request: fixture.request(
                verifiesRawWebSearchCompletion: true
            ),
            authProjection: fixture.authProjection(),
            refreshProvider: nil
        )
        _ = try runtime.begin()
        _ = try runtime.receive(
            line([
                "id": .number(1),
                "result": .object([
                    "codexHome": .string(
                        fixture.workspace.runtimeURL.path
                    ),
                ]),
            ])
        )
        let threadRequest = try #require(
            try runtime.receive(
                line([
                    "id": .number(2),
                    "result": .object([
                        "type": .string("chatgptAuthTokens"),
                    ]),
                ])
            ).only
        )
        let threadObject = try object(in: threadRequest)
        guard case let .object(threadParams) = threadObject["params"] else {
            Issue.record("Expected thread/start params")
            return
        }
        #expect(threadParams["experimentalRawEvents"] == .bool(true))
        _ = try runtime.receive(
            line([
                "id": .number(3),
                "result": .object([
                    "activePermissionProfile": .object([
                        "id": .string("stornaut-outer-v1"),
                    ]),
                    "approvalPolicy": .string("never"),
                    "cwd": .string(fixture.workspace.workURL.path),
                    "instructionSources": .array([]),
                    "model": .string("gpt-5.6-luna"),
                    "modelProvider": .string("openai"),
                    "thread": .object([
                        "id": .string("thread-synthetic"),
                        "modelProvider": .string("openai"),
                    ]),
                ]),
            ])
        )
        _ = try runtime.receive(
            line([
                "id": .number(4),
                "result": .object([
                    "turn": .object([
                        "id": .string("turn-synthetic"),
                        "status": .string("inProgress"),
                    ]),
                ]),
            ])
        )
        _ = try runtime.receive(
            line([
                "method": .string("thread/settings/updated"),
                "params": .object([
                    "threadId": .string("thread-synthetic"),
                    "threadSettings": .object([
                        "approvalPolicy": .string("never"),
                        "cwd": .string(fixture.workspace.workURL.path),
                        "model": .string("gpt-5.6-luna"),
                        "modelProvider": .string("openai"),
                        "sandboxPolicy": .object([
                            "networkAccess": .string("enabled"),
                            "type": .string("externalSandbox"),
                        ]),
                    ]),
                ]),
            ])
        )
        _ = try runtime.receive(
            fixture.itemStarted([
                "action": .null,
                "id": .string("web-search"),
                "query": .string("must-not-be-retained"),
                "results": .null,
                "type": .string("webSearch"),
            ])
        )
        _ = try runtime.receive(
            line([
                "method": .string("rawResponseItem/completed"),
                "params": .object([
                    "item": .object([
                        "action": .object([
                            "query": .string(
                                "must-not-be-retained"
                            ),
                            "type": .string("search"),
                        ]),
                        "id": .string("ws-synthetic"),
                        "status": .string("completed"),
                        "type": .string("web_search_call"),
                    ]),
                    "threadId": .string("thread-synthetic"),
                    "turnId": .string("turn-synthetic"),
                ]),
            ])
        )
        _ = try runtime.receive(fixture.rawResponseCompleted())
        _ = try runtime.receive(
            fixture.agentMessageCompleted(
                #"{"verdict":"passed"}"#
            )
        )
        _ = try runtime.receive(fixture.turnCompleted())
        #expect(runtime.status == .completed)
        #expect(
            runtime.observation.capabilityObservations.contains(
                .webSearchCompleted
            )
        )
        let reflected = String(reflecting: runtime.observation)
        #expect(!reflected.contains("must-not-be-retained"))
        #expect(!reflected.contains("/Users/private"))
    }

    @Test
    func rawWebSearchCompletionAcceptsUpstreamOptionalAction() throws {
        let fixture = AppServerFixture()
        let runtime = try CodexAppServerRuntime(
            request: fixture.request(
                verifiesRawWebSearchCompletion: true
            ),
            authProjection: fixture.authProjection(),
            refreshProvider: nil
        )
        try fixture.advanceToRunning(runtime)
        _ = try runtime.receive(fixture.webSearchStarted())

        _ = try runtime.receive(
            line([
                "method": .string("rawResponseItem/completed"),
                "params": .object([
                    "item": .object([
                        "action": .null,
                        "id": .string("ws-synthetic"),
                        "status": .string("completed"),
                        "type": .string("web_search_call"),
                    ]),
                    "threadId": .string("thread-synthetic"),
                    "turnId": .string("turn-synthetic"),
                ]),
            ])
        )

        #expect(
            !runtime.observation.capabilityObservations.contains(
                .webSearchCompleted
            )
        )
        _ = try runtime.receive(fixture.rawResponseCompleted())
        #expect(
            runtime.observation.capabilityObservations.contains(
                .webSearchCompleted
            )
        )
    }

    @Test
    func rawWebSearchCompletionAcceptsClosedOtherAction() throws {
        let fixture = AppServerFixture()
        let runtime = try CodexAppServerRuntime(
            request: fixture.request(
                verifiesRawWebSearchCompletion: true
            ),
            authProjection: fixture.authProjection(),
            refreshProvider: nil
        )
        try fixture.advanceToRunning(runtime)
        _ = try runtime.receive(fixture.webSearchStarted())

        _ = try runtime.receive(
            line([
                "method": .string("rawResponseItem/completed"),
                "params": .object([
                    "item": .object([
                        "action": .object([
                            "type": .string("other"),
                        ]),
                        "id": .string("ws-synthetic"),
                        "status": .string("completed"),
                        "type": .string("web_search_call"),
                    ]),
                    "threadId": .string("thread-synthetic"),
                    "turnId": .string("turn-synthetic"),
                ]),
            ])
        )

        #expect(
            !runtime.observation.capabilityObservations.contains(
                .webSearchCompleted
            )
        )
        _ = try runtime.receive(fixture.rawResponseCompleted())
        #expect(
            runtime.observation.capabilityObservations.contains(
                .webSearchCompleted
            )
        )
    }

    @Test
    func rawSearchItemCannotPromoteWithoutCanonicalStart() throws {
        let fixture = AppServerFixture()
        let runtime = try CodexAppServerRuntime(
            request: fixture.request(
                verifiesRawWebSearchCompletion: true
            ),
            authProjection: fixture.authProjection(),
            refreshProvider: nil
        )
        try fixture.advanceToRunning(runtime)

        _ = try runtime.receive(
            line([
                "method": .string("rawResponseItem/completed"),
                "params": .object([
                    "item": .object([
                        "action": .null,
                        "id": .string("ws-unrelated"),
                        "status": .string("completed"),
                        "type": .string("web_search_call"),
                    ]),
                    "threadId": .string("thread-synthetic"),
                    "turnId": .string("turn-synthetic"),
                ]),
            ])
        )

        #expect(
            !runtime.observation.capabilityObservations.contains(
                .webSearchCompleted
            )
        )
    }

    @Test
    func rawSearchItemMayPrecedeCanonicalStartWithinTheSameTurn()
        throws
    {
        let fixture = AppServerFixture()
        let runtime = try CodexAppServerRuntime(
            request: fixture.request(
                verifiesRawWebSearchCompletion: true
            ),
            authProjection: fixture.authProjection(),
            refreshProvider: nil
        )
        try fixture.advanceToRunning(runtime)

        _ = try runtime.receive(
            line([
                "method": .string("rawResponseItem/completed"),
                "params": .object([
                    "item": .object([
                        "action": .null,
                        "id": .string("ws-synthetic"),
                        "status": .string("completed"),
                        "type": .string("web_search_call"),
                    ]),
                    "threadId": .string("thread-synthetic"),
                    "turnId": .string("turn-synthetic"),
                ]),
            ])
        )
        #expect(
            !runtime.observation.capabilityObservations.contains(
                .webSearchCompleted
            )
        )

        _ = try runtime.receive(fixture.webSearchStarted())

        #expect(
            !runtime.observation.capabilityObservations.contains(
                .webSearchCompleted
            )
        )
        _ = try runtime.receive(fixture.rawResponseCompleted())
        #expect(
            runtime.observation.capabilityObservations.contains(
                .webSearchCompleted
            )
        )
    }

    @Test
    func rawResponseCompletionValidatesIdentityWithoutRetainingPayload()
        throws
    {
        let fixture = AppServerFixture()
        let runtime = try CodexAppServerRuntime(
            request: fixture.request(
                verifiesRawWebSearchCompletion: true
            ),
            authProjection: fixture.authProjection(),
            refreshProvider: nil
        )
        try fixture.advanceToRunning(runtime)

        _ = try runtime.receive(
            line([
                "method": .string("rawResponse/completed"),
                "params": .object([
                    "responseId": .string(
                        "must-not-be-retained-/Users/private"
                    ),
                    "threadId": .string("thread-synthetic"),
                    "turnId": .string("turn-synthetic"),
                    "usage": .object([
                        "inputTokens": .number(12),
                        "outputTokens": .number(3),
                    ]),
                ]),
            ])
        )

        #expect(
            runtime.observation.notificationMethods.contains(
                "rawResponse/completed"
            )
        )
        let reflected = String(reflecting: runtime.observation)
        #expect(!reflected.contains("must-not-be-retained"))
        #expect(!reflected.contains("/Users/private"))
        #expect(!reflected.contains("inputTokens"))
        #expect(
            !runtime.observation.capabilityObservations.contains(
                .webSearchCompleted
            )
        )
    }

    @Test
    func rawResponseCompletionPromotesOnlyAfterCanonicalSearchStart()
        throws
    {
        let fixture = AppServerFixture()
        let runtime = try CodexAppServerRuntime(
            request: fixture.request(
                verifiesRawWebSearchCompletion: true
            ),
            authProjection: fixture.authProjection(),
            refreshProvider: nil
        )
        try fixture.advanceToRunning(runtime)
        _ = try runtime.receive(
            fixture.itemStarted([
                "action": .null,
                "id": .string("web-search"),
                "query": .string("must-not-be-retained"),
                "results": .null,
                "type": .string("webSearch"),
            ])
        )

        _ = try runtime.receive(
            line([
                "method": .string("rawResponse/completed"),
                "params": .object([
                    "responseId": .string(
                        "must-not-be-retained-/Users/private"
                    ),
                    "threadId": .string("thread-synthetic"),
                    "turnId": .string("turn-synthetic"),
                    "usage": .null,
                ]),
            ])
        )

        #expect(
            runtime.observation.capabilityObservations.contains(
                .webSearchCompleted
            )
        )
        let reflected = String(reflecting: runtime.observation)
        #expect(!reflected.contains("must-not-be-retained"))
        #expect(!reflected.contains("/Users/private"))
    }

    @Test
    func rawResponseCompletionMayPrecedeCanonicalSearchStart()
        throws
    {
        let fixture = AppServerFixture()
        let runtime = try CodexAppServerRuntime(
            request: fixture.request(
                verifiesRawWebSearchCompletion: true
            ),
            authProjection: fixture.authProjection(),
            refreshProvider: nil
        )
        try fixture.advanceToRunning(runtime)

        _ = try runtime.receive(
            line([
                "method": .string("rawResponse/completed"),
                "params": .object([
                    "responseId": .string("response-synthetic"),
                    "threadId": .string("thread-synthetic"),
                    "turnId": .string("turn-synthetic"),
                    "usage": .null,
                ]),
            ])
        )
        #expect(
            !runtime.observation.capabilityObservations.contains(
                .webSearchCompleted
            )
        )

        _ = try runtime.receive(fixture.webSearchStarted())

        #expect(
            runtime.observation.capabilityObservations.contains(
                .webSearchCompleted
            )
        )
    }

    @Test
    func rawSearchModeDoesNotAcceptCanonicalCompletionAlone()
        throws
    {
        let fixture = AppServerFixture()
        let runtime = try CodexAppServerRuntime(
            request: fixture.request(
                verifiesRawWebSearchCompletion: true
            ),
            authProjection: fixture.authProjection(),
            refreshProvider: nil
        )
        try fixture.advanceToRunning(runtime)
        _ = try runtime.receive(
            fixture.itemStarted([
                "action": .null,
                "id": .string("web-search"),
                "query": .string("must-not-be-retained"),
                "results": .null,
                "type": .string("webSearch"),
            ])
        )
        _ = try runtime.receive(
            fixture.itemCompleted([
                "action": .null,
                "id": .string("web-search"),
                "query": .string("must-not-be-retained"),
                "results": .array([]),
                "type": .string("webSearch"),
            ])
        )
        _ = try runtime.receive(
            fixture.agentMessageCompleted(
                #"{"verdict":"passed"}"#
            )
        )

        #expect(
            throws: CodexAppServerRuntimeError.turnFailed(
                reasonKey:
                    "appServer.turn.single.rawSearch.raw-response"
            )
        ) {
            _ = try runtime.receive(fixture.turnCompleted())
        }
        #expect(
            !runtime.observation.capabilityObservations.contains(
                .webSearchCompleted
            )
        )
    }

    @Test
    func rawResponseCompletionRejectsMismatchedIdentity() throws {
        let fixture = AppServerFixture()
        let runtime = try CodexAppServerRuntime(
            request: fixture.request(
                verifiesRawWebSearchCompletion: true
            ),
            authProjection: fixture.authProjection(),
            refreshProvider: nil
        )
        try fixture.advanceToRunning(runtime)

        #expect(
            throws: CodexAppServerRuntimeError.identityMismatch(
                reasonKey:
                    "appServer.event.rawResponseCompleted.threadOrTurn"
            )
        ) {
            _ = try runtime.receive(
                line([
                    "method": .string("rawResponse/completed"),
                    "params": .object([
                        "responseId": .string("response-synthetic"),
                        "threadId": .string("thread-other"),
                        "turnId": .string("turn-synthetic"),
                        "usage": .null,
                    ]),
                ])
            )
        }
    }

    @Test
    func rejectsLegacyCollabItemType() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()
        try fixture.advanceToRunning(runtime)

        #expect(
            throws: CodexAppServerRuntimeError.unexpectedItem(
                type: "collabToolCall"
            )
        ) {
            _ = try runtime.receive(
                fixture.itemStarted([
                    "id": .string("legacy-collab"),
                    "type": .string("collabToolCall"),
                ])
            )
        }
    }

    @Test
    func knownSubagentLifecycleCannotPromotePrimaryEvidence() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()
        try fixture.advanceToRunning(runtime)

        _ = try runtime.receive(
            fixture.itemCompleted([
                "id": .string("spawn"),
                "type": .string("collabAgentToolCall"),
                "tool": .string("spawnAgent"),
                "status": .string("completed"),
                "receiverThreadIds": .array([
                    .string("thread-subagent"),
                ]),
                "senderThreadId": .string("thread-synthetic"),
            ])
        )
        _ = try runtime.receive(
            line([
                "method": .string("thread/settings/updated"),
                "params": .object([
                    "threadId": .string("thread-subagent"),
                    "threadSettings": .object([
                        "approvalPolicy": .string("never"),
                        "cwd": .string(fixture.workspace.workURL.path),
                        "model": .string("gpt-5.6-luna"),
                        "modelProvider": .string("openai"),
                        "sandboxPolicy": .object([
                            "networkAccess": .string("enabled"),
                            "type": .string("externalSandbox"),
                        ]),
                    ]),
                ]),
            ])
        )
        _ = try runtime.receive(
            line([
                "method": .string("turn/started"),
                "params": .object([
                    "threadId": .string("thread-subagent"),
                    "turn": .object([
                        "id": .string("turn-subagent"),
                        "items": .array([]),
                        "status": .string("inProgress"),
                    ]),
                ]),
            ])
        )
        _ = try runtime.receive(
            line([
                "method": .string("item/completed"),
                "params": .object([
                    "item": .object([
                        "id": .string("subagent-message"),
                        "text": .string(
                            #"{"must":"not become primary"}"#
                        ),
                        "type": .string("agentMessage"),
                    ]),
                    "threadId": .string("thread-subagent"),
                    "turnId": .string("turn-subagent"),
                ]),
            ])
        )
        _ = try runtime.receive(
            line([
                "method": .string("turn/completed"),
                "params": .object([
                    "threadId": .string("thread-subagent"),
                    "turn": .object([
                        "id": .string("turn-subagent"),
                        "items": .array([]),
                        "status": .string("completed"),
                    ]),
                ]),
            ])
        )

        #expect(runtime.status == .running)
        #expect(runtime.observation.finalAgentMessage == nil)
        #expect(
            runtime.observation.itemTypes
                == ["collabAgentToolCall"]
        )
        #expect(
            runtime.observation.capabilityObservations
                == [.subagentSpawnCompleted(receiverCount: 1)]
        )
        #expect(
            !String(reflecting: runtime.observation)
                .contains("must-not-become-primary")
        )

        _ = try runtime.receive(
            fixture.agentMessageCompleted(
                #"{"verdict":"passed"}"#
            )
        )
        _ = try runtime.receive(fixture.turnCompleted())
        #expect(
            runtime.observation.finalAgentMessage
                == #"{"verdict":"passed"}"#
        )
    }

    @Test
    func subagentResultRequiresARegisteredChildMessageMarker() throws {
        let fixture = AppServerFixture()
        let runtime = try CodexAppServerRuntime(
            request: fixture.request(
                childAgentOutputMarkers: [
                    "subagent.result": "SUBAGENT-FRESH-TOKEN",
                ]
            ),
            authProjection: fixture.authProjection(),
            refreshProvider: nil
        )
        try fixture.advanceToRunning(runtime)
        _ = try runtime.receive(
            fixture.itemCompleted([
                "id": .string("spawn"),
                "receiverThreadIds": .array([
                    .string("thread-subagent"),
                ]),
                "senderThreadId": .string("thread-synthetic"),
                "status": .string("completed"),
                "tool": .string("spawnAgent"),
                "type": .string("collabAgentToolCall"),
            ])
        )
        _ = try runtime.receive(
            line([
                "method": .string("thread/settings/updated"),
                "params": .object([
                    "threadId": .string("thread-subagent"),
                    "threadSettings": .object([
                        "approvalPolicy": .string("never"),
                        "cwd": .string(fixture.workspace.workURL.path),
                        "model": .string("gpt-5.6-luna"),
                        "modelProvider": .string("openai"),
                        "sandboxPolicy": .object([
                            "networkAccess": .string("enabled"),
                            "type": .string("externalSandbox"),
                        ]),
                    ]),
                ]),
            ])
        )
        _ = try runtime.receive(
            line([
                "method": .string("turn/started"),
                "params": .object([
                    "threadId": .string("thread-subagent"),
                    "turn": .object([
                        "id": .string("turn-subagent"),
                        "items": .array([]),
                        "status": .string("inProgress"),
                    ]),
                ]),
            ])
        )
        _ = try runtime.receive(
            fixture.agentMessageCompleted("SUBAGENT-FRESH-TOKEN")
        )
        #expect(
            !runtime.observation.capabilityObservations.contains(
                .subagentResultObserved
            )
        )
        _ = try runtime.receive(
            line([
                "method": .string("item/completed"),
                "params": .object([
                    "item": .object([
                        "id": .string("subagent-message"),
                        "text": .string("SUBAGENT-FRESH-TOKEN"),
                        "type": .string("agentMessage"),
                    ]),
                    "threadId": .string("thread-subagent"),
                    "turnId": .string("turn-subagent"),
                ]),
            ])
        )
        #expect(
            runtime.observation.capabilityObservations.contains(
                .subagentResultObserved
            )
        )
    }

    @Test
    func completedSpawnStateMayBindTheFreshSubagentResult() throws {
        let fixture = AppServerFixture()
        let runtime = try CodexAppServerRuntime(
            request: fixture.request(
                childAgentOutputMarkers: [
                    "subagent.result": "SUBAGENT-FRESH-TOKEN",
                ]
            ),
            authProjection: fixture.authProjection(),
            refreshProvider: nil
        )
        try fixture.advanceToRunning(runtime)

        _ = try runtime.receive(
            fixture.itemCompleted([
                "agentsStates": .object([
                    "thread-subagent": .object([
                        "message": .string(
                            "Result: SUBAGENT-FRESH-TOKEN"
                        ),
                        "status": .string("completed"),
                    ]),
                ]),
                "id": .string("spawn"),
                "receiverThreadIds": .array([
                    .string("thread-subagent"),
                ]),
                "senderThreadId": .string("thread-synthetic"),
                "status": .string("completed"),
                "tool": .string("spawnAgent"),
                "type": .string("collabAgentToolCall"),
            ])
        )

        #expect(
            runtime.observation.capabilityObservations.contains(
                .subagentResultObserved
            )
        )

        let wrongSender = try CodexAppServerRuntime(
            request: fixture.request(
                childAgentOutputMarkers: [
                    "subagent.result": "SUBAGENT-FRESH-TOKEN",
                ]
            ),
            authProjection: fixture.authProjection(),
            refreshProvider: nil
        )
        try fixture.advanceToRunning(wrongSender)
        #expect(
            throws: CodexAppServerRuntimeError.identityMismatch(
                reasonKey: "appServer.subagent.sender"
            )
        ) {
            _ = try wrongSender.receive(
                fixture.itemCompleted([
                    "agentsStates": .object([
                        "thread-subagent": .object([
                            "message": .string(
                                "Result: SUBAGENT-FRESH-TOKEN"
                            ),
                            "status": .string("completed"),
                        ]),
                    ]),
                    "id": .string("spawn"),
                    "receiverThreadIds": .array([
                        .string("thread-subagent"),
                    ]),
                    "senderThreadId": .string("unrelated-parent"),
                    "status": .string("completed"),
                    "tool": .string("spawnAgent"),
                    "type": .string("collabAgentToolCall"),
                ])
            )
        }

        let wrongResult = try CodexAppServerRuntime(
            request: fixture.request(
                childAgentOutputMarkers: [
                    "subagent.result": "SUBAGENT-FRESH-TOKEN",
                ]
            ),
            authProjection: fixture.authProjection(),
            refreshProvider: nil
        )
        try fixture.advanceToRunning(wrongResult)
        _ = try wrongResult.receive(
            fixture.itemCompleted([
                "agentsStates": .object([
                    "thread-subagent": .object([
                        "message": .string("UNRELATED"),
                        "status": .string("completed"),
                    ]),
                ]),
                "id": .string("spawn"),
                "receiverThreadIds": .array([
                    .string("thread-subagent"),
                ]),
                "senderThreadId": .string("thread-synthetic"),
                "status": .string("completed"),
                "tool": .string("spawnAgent"),
                "type": .string("collabAgentToolCall"),
            ])
        )
        #expect(
            !wrongResult.observation.capabilityObservations.contains(
                .subagentResultObserved
            )
        )
    }

    @Test
    func unknownChildThreadLifecycleFailsClosed() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()
        try fixture.advanceToRunning(runtime)

        #expect(throws: CodexAppServerRuntimeError.identityMismatch(
            reasonKey: "appServer.event.turnStarted.thread"
        )) {
            _ = try runtime.receive(
                line([
                    "method": .string("turn/started"),
                    "params": .object([
                        "threadId": .string("unknown-child"),
                        "turn": .object([
                            "id": .string("unknown-turn"),
                            "items": .array([]),
                            "status": .string("inProgress"),
                        ]),
                    ]),
                ])
            )
        }
    }

    @Test
    func failedOrUnknownItemsDoNotProduceSuccessfulEvidence() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()
        try fixture.advanceToRunning(runtime)

        _ = try runtime.receive(
            fixture.itemCompleted([
                "id": .string("failed"),
                "type": .string("commandExecution"),
                "source": .string("agent"),
                "status": .string("failed"),
                "exitCode": .number(1),
                "aggregatedOutput": .string("SHELL-TOKEN"),
            ])
        )

        #expect(
            runtime.observation.capabilityObservations == [
                .command(
                    source: .agent,
                    succeeded: false,
                    matchedMarkerIDs: ["shell.read"]
                ),
            ]
        )

        _ = try runtime.receive(
            fixture.itemCompleted([
                "id": .string("failed-image"),
                "type": .string("imageView"),
                "status": .string("failed"),
                "path": .string("/Users/private/image.png"),
            ])
        )
        #expect(
            !runtime.observation.capabilityObservations.contains(
                .imageViewCompleted
            )
        )
    }

    @Test
    func subagentReceiverCannotReuseParentOrExistingChildIdentity()
        throws
    {
        let fixture = AppServerFixture()
        let parentCollision = fixture.makeRuntime()
        try fixture.advanceToRunning(parentCollision)
        #expect(throws: CodexAppServerRuntimeError.invalidMessage) {
            _ = try parentCollision.receive(
                fixture.itemCompleted([
                    "id": .string("parent-collision"),
                    "type": .string("collabAgentToolCall"),
                    "tool": .string("spawnAgent"),
                    "status": .string("completed"),
                    "receiverThreadIds": .array([
                        .string("thread-synthetic"),
                    ]),
                    "senderThreadId": .string("thread-synthetic"),
                ])
            )
        }

        let duplicateChild = fixture.makeRuntime()
        try fixture.advanceToRunning(duplicateChild)
        _ = try duplicateChild.receive(
            fixture.itemCompleted([
                "id": .string("first-spawn"),
                "type": .string("collabAgentToolCall"),
                "tool": .string("spawnAgent"),
                "status": .string("completed"),
                "receiverThreadIds": .array([
                    .string("thread-subagent"),
                ]),
                "senderThreadId": .string("thread-synthetic"),
            ])
        )
        #expect(throws: CodexAppServerRuntimeError.invalidMessage) {
            _ = try duplicateChild.receive(
                fixture.itemCompleted([
                    "id": .string("duplicate-spawn"),
                    "type": .string("collabAgentToolCall"),
                    "tool": .string("spawnAgent"),
                    "status": .string("completed"),
                    "receiverThreadIds": .array([
                        .string("thread-subagent"),
                    ]),
                    "senderThreadId": .string("thread-synthetic"),
                ])
            )
        }
    }

    @Test
    func childItemsRequireARegisteredNonemptyTurn() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()
        try fixture.advanceToRunning(runtime)
        _ = try runtime.receive(
            fixture.itemCompleted([
                "id": .string("spawn"),
                "type": .string("collabAgentToolCall"),
                "tool": .string("spawnAgent"),
                "status": .string("completed"),
                "receiverThreadIds": .array([
                    .string("thread-subagent"),
                ]),
                "senderThreadId": .string("thread-synthetic"),
            ])
        )

        #expect(throws: CodexAppServerRuntimeError.identityMismatch(
            reasonKey: "appServer.event.childItem.identity"
        )) {
            _ = try runtime.receive(
                line([
                    "method": .string("item/completed"),
                    "params": .object([
                        "item": .object([
                            "id": .string("premature-item"),
                            "type": .string("agentMessage"),
                        ]),
                        "threadId": .string("thread-subagent"),
                    ]),
                ])
            )
        }
    }

    @Test
    func unknownItemRetainsOnlyBoundedType() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()
        try fixture.advanceToRunning(runtime)

        #expect(
            throws: CodexAppServerRuntimeError.unexpectedItem(
                type: "futureToolCall"
            )
        ) {
            _ = try runtime.receive(
                fixture.itemStarted([
                    "arguments": .object([
                        "path": .string(
                            "/Users/private must-not-be-retained"
                        ),
                    ]),
                    "id": .string("future-item"),
                    "type": .string("futureToolCall"),
                ])
            )
        }
        let reflected = String(
            reflecting: CodexAppServerRuntimeError.unexpectedItem(
                type: "futureToolCall"
            )
        )
        #expect(!reflected.contains("must-not-be-retained"))
        #expect(!reflected.contains("/Users/private"))
    }

    @Test
    func rejectsAuthProjectionBoundToAnotherSourcePath() {
        let fixture = AppServerFixture()
        let projection = CodexRuntimeAuthProjection(
            sourceURL: URL(filePath: "/Users/example/.codex/other-auth.json"),
            sourceIdentity: CodexRuntimeAuthSourceIdentity(
                device: 1,
                inode: 2,
                ownerUserID: 501,
                mode: 0o600
            ),
            credentials: .chatGPT(
                accessToken: "header.access.signature",
                accountID: "synthetic-account",
                planType: nil
            )
        )

        #expect(throws: CodexAppServerRuntimeError.invalidRequest) {
            _ = try CodexAppServerRuntime(
                request: CodexAppServerRuntimeRequest(
                    projectedAuthSourceURL: fixture.authSourceURL,
                    runtimeHomeURL: fixture.workspace.runtimeURL,
                    workingDirectoryURL: fixture.workspace.workURL,
                    prompt: "Synthetic",
                    outputSchema: fixture.outputSchema
                ),
                authProjection: projection,
                refreshProvider: nil
            )
        }
    }

    @Test
    func rejectsWrongIdsOrderingIdentityAndUnboundedInput() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()
        _ = try runtime.begin()

        #expect(throws: CodexAppServerRuntimeError.self) {
            _ = try runtime.receive(
                line([
                    "id": .number(2),
                    "result": .object([:]),
                ])
            )
        }
        #expect(runtime.status == .failed)

        #expect(throws: CodexAppServerRuntimeError.self) {
            _ = try CodexAppServerRuntime(
                request: CodexAppServerRuntimeRequest(
                    projectedAuthSourceURL: fixture.authSourceURL,
                    runtimeHomeURL: fixture.workspace.runtimeURL,
                    workingDirectoryURL: fixture.workspace.workURL,
                    prompt: String(repeating: "x", count: 1_025),
                    outputSchema: fixture.outputSchema,
                    maximumPromptBytes: 1_024
                ),
                authProjection: fixture.authProjection(),
                refreshProvider: nil
            )
        }
    }
}

private struct AppServerFixture {
    let workspace = CodexRuntimeWorkspacePaths(
        rootURL: URL(filePath: "/private/tmp/stornaut"),
        homeURL: URL(filePath: "/private/tmp/stornaut/home"),
        runtimeURL: URL(filePath: "/private/tmp/stornaut/runtime"),
        workURL: URL(filePath: "/private/tmp/stornaut/work"),
        schemaURL: URL(filePath: "/private/tmp/stornaut/schema"),
        fixturesURL: URL(filePath: "/private/tmp/stornaut/fixtures")
    )
    let authSourceURL = URL(filePath: "/Users/example/.codex/auth.json")
    let sourceIdentity = CodexRuntimeAuthSourceIdentity(
        device: 1,
        inode: 2,
        ownerUserID: 501,
        mode: 0o600
    )
    let outputSchema: JSONValue = .object([
        "additionalProperties": .bool(false),
        "properties": .object([
            "verdict": .object([
                "type": .string("string"),
            ]),
        ]),
        "required": .array([
            .string("verdict"),
        ]),
        "type": .string("object"),
    ])

    func makeRuntime(
        refreshProvider: (any CodexRuntimeAuthRefreshProviding)? = nil,
        finalizationPrompt: String? = nil
    ) -> CodexAppServerRuntime {
        try! CodexAppServerRuntime(
            request: request(finalizationPrompt: finalizationPrompt),
            authProjection: authProjection(),
            refreshProvider: refreshProvider
        )
    }

    func request(
        capabilityCommandRequirements:
            [String: CodexCommandIdentityRequirement] = [:],
        expectedImageURL: URL? = nil,
        childAgentOutputMarkers: [String: String] = [:],
        verifiesRawWebSearchCompletion: Bool = false,
        finalizationPrompt: String? = nil
    ) -> CodexAppServerRuntimeRequest {
        CodexAppServerRuntimeRequest(
            projectedAuthSourceURL: authSourceURL,
            runtimeHomeURL: workspace.runtimeURL,
            workingDirectoryURL: workspace.workURL,
            prompt: "Inspect only synthetic fixtures.",
            outputSchema: outputSchema,
            capabilityOutputMarkers: [
                "shell.read": "SHELL-TOKEN",
                "unified.read": "UNIFIED-TOKEN",
            ],
            capabilityCommandRequirements:
                capabilityCommandRequirements,
            expectedImageURL: expectedImageURL,
            childAgentOutputMarkers: childAgentOutputMarkers,
            verifiesRawWebSearchCompletion:
                verifiesRawWebSearchCompletion,
            finalizationPrompt: finalizationPrompt
        )
    }

    func authProjection(
        accessToken: String = "header.access.signature"
    ) -> CodexRuntimeAuthProjection {
        CodexRuntimeAuthProjection(
            sourceURL: authSourceURL,
            sourceIdentity: sourceIdentity,
            credentials: .chatGPT(
                accessToken: accessToken,
                accountID: "synthetic-account",
                planType: nil
            )
        )
    }

    func advanceToRunning(
        _ runtime: CodexAppServerRuntime
    ) throws {
        _ = try runtime.begin()
        _ = try runtime.receive(
            line([
                "id": .number(1),
                "result": .object([
                    "codexHome": .string(workspace.runtimeURL.path),
                ]),
            ])
        )
        _ = try runtime.receive(
            line([
                "id": .number(2),
                "result": .object([
                    "type": .string("chatgptAuthTokens"),
                ]),
            ])
        )
        _ = try runtime.receive(threadResponse())
        _ = try runtime.receive(
            line([
                "id": .number(4),
                "result": .object([
                    "turn": .object([
                        "id": .string("turn-synthetic"),
                        "status": .string("inProgress"),
                    ]),
                ]),
            ])
        )
        _ = try runtime.receive(
            line([
                "method": .string("thread/settings/updated"),
                "params": .object([
                    "threadId": .string("thread-synthetic"),
                    "threadSettings": .object([
                        "approvalPolicy": .string("never"),
                        "cwd": .string(workspace.workURL.path),
                        "model": .string("gpt-5.6-luna"),
                        "modelProvider": .string("openai"),
                        "sandboxPolicy": .object([
                            "networkAccess": .string("enabled"),
                            "type": .string("externalSandbox"),
                        ]),
                    ]),
                ]),
            ])
        )
    }

    func advanceToFinalizationRunning(
        _ runtime: CodexAppServerRuntime
    ) throws -> Data {
        try advanceToRunning(runtime)
        _ = try runtime.receive(
            agentMessageCompleted(
                "Untrusted probe-turn prose must be discarded."
            )
        )
        let finalizationRequest = try #require(
            try runtime.receive(turnCompleted()).only
        )
        #expect(runtime.observation.finalAgentMessage == nil)

        _ = try runtime.receive(
            line([
                "id": .number(5),
                "result": .object([
                    "turn": .object([
                        "id": .string("turn-finalization"),
                        "status": .string("inProgress"),
                    ]),
                ]),
            ])
        )
        return finalizationRequest
    }

    func threadResponse(
        provider: String = "openai"
    ) -> Data {
        line([
            "id": .number(3),
            "result": .object([
                "activePermissionProfile": .object([
                    "id": .string("stornaut-outer-v1"),
                ]),
                "approvalPolicy": .string("never"),
                "cwd": .string(workspace.workURL.path),
                "instructionSources": .array([]),
                "model": .string("gpt-5.6-luna"),
                "modelProvider": .string(provider),
                "thread": .object([
                    "id": .string("thread-synthetic"),
                    "modelProvider": .string(provider),
                ]),
            ]),
        ])
    }

    func itemCompleted(
        _ item: [String: JSONValue],
        turnID: String = "turn-synthetic"
    ) -> Data {
        line([
            "method": .string("item/completed"),
            "params": .object([
                "item": .object(item),
                "threadId": .string("thread-synthetic"),
                "turnId": .string(turnID),
            ]),
        ])
    }

    func itemStarted(
        _ item: [String: JSONValue],
        turnID: String = "turn-synthetic"
    ) -> Data {
        line([
            "method": .string("item/started"),
            "params": .object([
                "item": .object(item),
                "threadId": .string("thread-synthetic"),
                "turnId": .string(turnID),
            ]),
        ])
    }

    func webSearchStarted() -> Data {
        itemStarted([
            "action": .null,
            "id": .string("web-search"),
            "query": .string("must-not-be-retained"),
            "results": .null,
            "type": .string("webSearch"),
        ])
    }

    func agentMessageCompleted(
        _ text: String,
        turnID: String = "turn-synthetic"
    ) -> Data {
        itemCompleted(
            [
                "id": .string("agent-message"),
                "text": .string(text),
                "type": .string("agentMessage"),
            ],
            turnID: turnID
        )
    }

    func commandOutputDelta(
        itemID: String,
        delta: String
    ) -> Data {
        line([
            "method": .string(
                "item/commandExecution/outputDelta"
            ),
            "params": .object([
                "delta": .string(delta),
                "itemId": .string(itemID),
                "threadId": .string("thread-synthetic"),
                "turnId": .string("turn-synthetic"),
            ]),
        ])
    }

    func rawResponseCompleted(
        turnID: String = "turn-synthetic"
    ) -> Data {
        line([
            "method": .string("rawResponse/completed"),
            "params": .object([
                "responseId": .string("response-synthetic"),
                "threadId": .string("thread-synthetic"),
                "turnId": .string(turnID),
                "usage": .null,
            ]),
        ])
    }

    func turnCompleted(
        turnID: String = "turn-synthetic"
    ) -> Data {
        line([
            "method": .string("turn/completed"),
            "params": .object([
                "threadId": .string("thread-synthetic"),
                "turn": .object([
                    "id": .string(turnID),
                    "items": .array([]),
                    "status": .string("completed"),
                ]),
            ]),
        ])
    }
}

private final class RecordingRefreshProvider:
    CodexRuntimeAuthRefreshProviding,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let result: CodexRuntimeAuthProjection
    private var calls = 0

    init(result: CodexRuntimeAuthProjection) {
        self.result = result
    }

    var callCount: Int {
        lock.withLock { calls }
    }

    func refresh() throws -> CodexRuntimeAuthProjection {
        lock.withLock { calls += 1 }
        return result
    }
}

private extension Array {
    var only: Element? {
        count == 1 ? self[0] : nil
    }
}

private func line(_ object: [String: JSONValue]) -> Data {
    var data = try! JSONEncoder().encode(JSONValue.object(object))
    data.append(0x0A)
    return data
}

private func object(in line: Data) throws -> [String: JSONValue] {
    guard
        case let .object(object) = try JSONDecoder().decode(
            JSONValue.self,
            from: line
        )
    else {
        throw AppServerTestError.invalidLine
    }
    return object
}

private func method(in line: Data) throws -> String {
    guard case let .string(method) = try object(in: line)["method"] else {
        throw AppServerTestError.invalidLine
    }
    return method
}

private func identifier(in line: Data) throws -> Int {
    guard case let .number(identifier) = try object(in: line)["id"] else {
        throw AppServerTestError.invalidLine
    }
    return identifier
}

private enum AppServerTestError: Error {
    case invalidLine
}
