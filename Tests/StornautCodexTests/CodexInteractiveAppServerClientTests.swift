import Foundation
import Testing
@testable import StornautCodex

@Suite("Codex interactive App Server client")
struct CodexInteractiveAppServerClientTests {
    @Test
    func drivesClosedMultiTurnProtocolWithServerOwnedIdentities()
        async throws
    {
        let fixture = InteractiveAppServerFixture()
        let transport = FakeInteractiveAppServerTransport(lines: [
            fixture.initializeResponse(),
            fixture.loginResponse(),
            fixture.threadStartResponse(),
            fixture.rootStartedNotification(),
            fixture.turnStartResponse(),
            fixture.turnStartedNotification(),
            fixture.threadReadResponse(),
            fixture.interruptResponse(),
        ])
        let client = try fixture.client(transport: transport)

        let root = try await client.prepareRoot()
        #expect(root.id == fixture.rootThreadID)
        #expect(root.sessionID == fixture.rootThreadID)
        #expect(
            try decodedObject(
                await client.nextValidatedNotification()
            ) == decodedObject(fixture.rootStartedNotification())
        )

        let turn = try await client.startTurn(
            threadID: fixture.rootThreadID,
            inputTexts: [
                "canonical prompt",
                "canonical context",
                "bounded turn context",
            ]
        )
        #expect(turn.threadID == fixture.rootThreadID)
        #expect(turn.turnID == fixture.turnID)
        #expect(
            try decodedObject(
                await client.nextValidatedNotification()
            ) == decodedObject(fixture.turnStartedNotification())
        )

        let metadata = try await client.readThread(
            threadID: fixture.childThreadID
        )
        #expect(metadata.id == fixture.childThreadID)
        #expect(metadata.parentThreadID == fixture.rootThreadID)
        #expect(metadata.sessionID == fixture.rootThreadID)

        try await client.interrupt(turn)
        try await client.retire()

        #expect(transport.retireCount == 1)
        #expect(
            try transport.recordedMethods() == [
                "initialize",
                "initialized",
                "account/login/start",
                "thread/start",
                "turn/start",
                "thread/read",
                "turn/interrupt",
            ]
        )
        let turnRequest = try #require(
            transport.recordedObjects().first {
                string($0["method"]) == "turn/start"
            }
        )
        let params = try #require(object(turnRequest["params"]))
        let input = try #require(array(params["input"]))
        #expect(
            input.compactMap {
                object($0).flatMap { string($0["text"]) }
            } == [
                "canonical prompt",
                "canonical context",
                "bounded turn context",
            ]
        )
        #expect(params["outputSchema"] == fixture.outputSchema)
        #expect(string(params["model"]) == "gpt-5.6-luna")
        #expect(string(params["approvalPolicy"]) == "never")
        #expect(
            object(params["sandboxPolicy"]) == [
                "networkAccess": .string("enabled"),
                "type": .string("externalSandbox"),
            ]
        )
    }

    @Test
    func rejectsThreadNotificationBeforeAuthoritativeResponse()
        async throws
    {
        let fixture = InteractiveAppServerFixture()
        let transport = FakeInteractiveAppServerTransport(lines: [
            fixture.initializeResponse(),
            fixture.loginResponse(),
            fixture.rootStartedNotification(),
            fixture.threadStartResponse(),
        ])
        let client = try fixture.client(transport: transport)

        await #expect(
            throws: CodexInteractiveAppServerError
                .unexpectedNotification(
                    reasonKey: "thread-start-before-response"
                )
        ) {
            _ = try await client.prepareRoot()
        }
        try await client.retire()
        #expect(transport.retireCount == 1)
    }

    @Test
    func rejectsRootWhoseSessionIdentityDiffersFromThread()
        async throws
    {
        let fixture = InteractiveAppServerFixture()
        let transport = FakeInteractiveAppServerTransport(lines: [
            fixture.initializeResponse(),
            fixture.loginResponse(),
            fixture.threadStartResponse(
                sessionID: "session-foreign"
            ),
        ])
        let client = try fixture.client(transport: transport)

        await #expect(
            throws: CodexInteractiveAppServerError.identityMismatch(
                reasonKey: "thread-start-root-identity"
            )
        ) {
            _ = try await client.prepareRoot()
        }
        try await client.retire()
    }

    @Test
    func retirementIsOneShotAndClosesFurtherRequests() async throws {
        let fixture = InteractiveAppServerFixture()
        let transport = FakeInteractiveAppServerTransport(lines: [])
        let client = try fixture.client(transport: transport)

        try await client.retire()
        await #expect(
            throws: CodexInteractiveAppServerError.invalidState
        ) {
            _ = try await client.prepareRoot()
        }
        await #expect(
            throws: CodexInteractiveAppServerError.invalidState
        ) {
            try await client.retire()
        }
        #expect(transport.retireCount == 1)
    }
}

private struct InteractiveAppServerFixture {
    let runtimeHomeURL = URL(filePath: "/tmp/stornaut-interactive/runtime")
    let workingDirectoryURL = URL(
        filePath: "/tmp/stornaut-interactive/work"
    )
    let authSourceURL = URL(
        filePath: "/Users/example/.codex/auth.json"
    )
    let rootThreadID = "thread-interactive-root"
    let childThreadID = "thread-interactive-child"
    let turnID = "turn-interactive-root"
    let outputSchema: JSONValue = .object([
        "additionalProperties": .bool(false),
        "properties": .object([
            "verdict": .object([
                "type": .string("string"),
            ]),
        ]),
        "required": .array([.string("verdict")]),
        "type": .string("object"),
    ])

    func client(
        transport: FakeInteractiveAppServerTransport
    ) throws -> CodexInteractiveAppServerClient {
        try CodexInteractiveAppServerClient(
            configuration: CodexInteractiveAppServerConfiguration(
                runtimeHomeURL: runtimeHomeURL,
                workingDirectoryURL: workingDirectoryURL,
                projectedAuthSourceURL: authSourceURL,
                outputSchema: outputSchema
            ),
            transport: transport,
            authProjection: CodexRuntimeAuthProjection(
                sourceURL: authSourceURL,
                sourceIdentity: CodexRuntimeAuthSourceIdentity(
                    device: 1,
                    inode: 2,
                    ownerUserID: geteuid(),
                    mode: 0o600
                ),
                credentials: .chatGPT(
                    accessToken: "header.synthetic.signature",
                    accountID: "synthetic-account",
                    planType: nil
                )
            ),
            refreshProvider: nil
        )
    }

    func initializeResponse() -> Data {
        line([
            "id": .number(1),
            "result": .object([
                "codexHome": .string(runtimeHomeURL.path),
            ]),
        ])
    }

    func loginResponse() -> Data {
        line([
            "id": .number(2),
            "result": .object([
                "type": .string("chatgptAuthTokens"),
            ]),
        ])
    }

    func threadStartResponse(
        sessionID: String? = nil
    ) -> Data {
        line([
            "id": .number(3),
            "result": .object([
                "activePermissionProfile": .object([
                    "id": .string("stornaut-outer-v1"),
                ]),
                "approvalPolicy": .string("never"),
                "cwd": .string(workingDirectoryURL.path),
                "instructionSources": .array([]),
                "model": .string("gpt-5.6-luna"),
                "modelProvider": .string("openai"),
                "thread": .object([
                    "ephemeral": .bool(true),
                    "id": .string(rootThreadID),
                    "modelProvider": .string("openai"),
                    "sessionId": .string(sessionID ?? rootThreadID),
                ]),
            ]),
        ])
    }

    func rootStartedNotification() -> Data {
        line([
            "method": .string("thread/started"),
            "params": .object([
                "thread": .object([
                    "id": .string(rootThreadID),
                ]),
            ]),
        ])
    }

    func turnStartResponse() -> Data {
        line([
            "id": .number(4),
            "result": .object([
                "turn": .object([
                    "id": .string(turnID),
                    "items": .array([]),
                    "status": .string("inProgress"),
                ]),
            ]),
        ])
    }

    func turnStartedNotification() -> Data {
        line([
            "method": .string("turn/started"),
            "params": .object([
                "threadId": .string(rootThreadID),
                "turn": .object([
                    "id": .string(turnID),
                    "items": .array([]),
                    "status": .string("inProgress"),
                ]),
            ]),
        ])
    }

    func threadReadResponse() -> Data {
        line([
            "id": .number(5),
            "result": .object([
                "thread": .object([
                    "id": .string(childThreadID),
                    "parentThreadId": .string(rootThreadID),
                    "sessionId": .string(rootThreadID),
                ]),
            ]),
        ])
    }

    func interruptResponse() -> Data {
        line([
            "id": .number(6),
            "result": .object([:]),
        ])
    }

    private func line(_ object: [String: JSONValue]) -> Data {
        var data = try! JSONEncoder().encode(JSONValue.object(object))
        data.append(0x0A)
        return data
    }
}

private final class FakeInteractiveAppServerTransport:
    CodexInteractiveAppServerTransport,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var lines: [Data]
    private var writes: [Data] = []
    private(set) var retireCount = 0

    init(lines: [Data]) {
        self.lines = lines
    }

    func writeLine(_ line: Data) async throws {
        lock.withLock {
            writes.append(line)
        }
    }

    func readLine() async throws -> Data {
        try lock.withLock {
            guard !lines.isEmpty else {
                throw CodexInteractiveAppServerError.unexpectedEOF
            }
            return lines.removeFirst()
        }
    }

    func retire() async throws {
        lock.withLock {
            retireCount += 1
        }
    }

    func recordedMethods() throws -> [String] {
        try recordedObjects().compactMap {
            string($0["method"])
        }
    }

    func recordedObjects() throws -> [[String: JSONValue]] {
        try lock.withLock {
            try writes.map { data in
                guard
                    data.last == 0x0A,
                    case let .object(object) = try JSONDecoder().decode(
                        JSONValue.self,
                        from: data.dropLast()
                    )
                else {
                    throw CodexInteractiveAppServerError.invalidLine
                }
                return object
            }
        }
    }
}

private func object(
    _ value: JSONValue?
) -> [String: JSONValue]? {
    guard case let .object(value)? = value else {
        return nil
    }
    return value
}

private func array(_ value: JSONValue?) -> [JSONValue]? {
    guard case let .array(value)? = value else {
        return nil
    }
    return value
}

private func string(_ value: JSONValue?) -> String? {
    guard case let .string(value)? = value else {
        return nil
    }
    return value
}

private func decodedObject(
    _ data: Data
) throws -> [String: JSONValue] {
    guard
        data.last == 0x0A,
        case let .object(object) = try JSONDecoder().decode(
            JSONValue.self,
            from: data.dropLast()
        )
    else {
        throw CodexInteractiveAppServerError.invalidLine
    }
    return object
}
