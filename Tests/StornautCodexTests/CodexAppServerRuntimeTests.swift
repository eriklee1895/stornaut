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
                ]),
                "clientInfo": .object([
                    "name": .string("stornaut"),
                    "title": .string("Stornaut"),
                    "version": .string("1"),
                ]),
            ]),
        ])

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
                        "thread": .object([
                            "id": .string("thread-synthetic"),
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
    func completionWithoutBoundedFinalMessageFailsClosed() throws {
        let fixture = AppServerFixture()
        let runtime = fixture.makeRuntime()
        try fixture.advanceToRunning(runtime)

        #expect(throws: CodexAppServerRuntimeError.turnFailed) {
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
            credentials: CodexRuntimeAuthCredentials(
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
        refreshProvider: (any CodexRuntimeAuthRefreshProviding)? = nil
    ) -> CodexAppServerRuntime {
        try! CodexAppServerRuntime(
            request: CodexAppServerRuntimeRequest(
                projectedAuthSourceURL: authSourceURL,
                runtimeHomeURL: workspace.runtimeURL,
                workingDirectoryURL: workspace.workURL,
                prompt: "Inspect only synthetic fixtures.",
                outputSchema: outputSchema
            ),
            authProjection: authProjection(),
            refreshProvider: refreshProvider
        )
    }

    func authProjection(
        accessToken: String = "header.access.signature"
    ) -> CodexRuntimeAuthProjection {
        CodexRuntimeAuthProjection(
            sourceURL: authSourceURL,
            sourceIdentity: CodexRuntimeAuthSourceIdentity(
                device: 1,
                inode: 2,
                ownerUserID: 501,
                mode: 0o600
            ),
            credentials: CodexRuntimeAuthCredentials(
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
        _ = try runtime.receive(
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
                    "thread": .object([
                        "id": .string("thread-synthetic"),
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
                        "cwd": .string(workspace.workURL.path),
                        "model": .string("gpt-5.6-luna"),
                        "sandboxPolicy": .object([
                            "networkAccess": .string("enabled"),
                            "type": .string("externalSandbox"),
                        ]),
                    ]),
                ]),
            ])
        )
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
