import Foundation
import Testing
import StornautCore
@testable import StornautCodex

@Test
func probeToolSchemaExposesExactlyFourReadOnlyTools() {
    let definitions = ProbeToolSchema.definitions

    #expect(definitions.map(\.name) == [
        "stornaut.diskSnapshot",
        "stornaut.directorySummary",
        "stornaut.largestChildren",
        "stornaut.safeTextSnippet",
    ])
    #expect(Set(definitions.map(\.capability)) == Set(ProbeCapability.allCases))
    #expect(definitions.allSatisfy { $0.isReadOnly })
    #expect(definitions.allSatisfy { definition in
        definition.inputSchema["additionalProperties"] == .bool(false)
    })
    #expect(!definitions.map(\.name).contains("shell"))
    #expect(!definitions.map(\.name).contains("writeFile"))
    #expect(!definitions.map(\.name).contains("cleanup"))
}

@Test
func fakeCodexRequestTraversesTypedBridgeAndReturnsBoundedResult() async throws {
    let fixture = try ProbeBridgeFixture()
    defer { fixture.remove() }
    let bridge = ProbeBridge(
        broker: ProbeBroker(),
        context: fixture.context,
        requestByteLimit: 4_096,
        responseByteLimit: 8_192
    )
    let fakeCodex = FakeCodexBridgeClient(bridge: bridge)

    let response = try await fakeCodex.call(
        id: "call-1",
        tool: "stornaut.directorySummary",
        arguments: [
            "targetPath": .string(fixture.rootURL.path),
            "limit": .number(10),
        ]
    )

    #expect(response.id == "call-1")
    #expect(response.error == nil)
    guard case let .success(result)? = response.result,
          case let .directorySummary(summary) = result.payload
    else {
        Issue.record("Expected a typed directory summary response")
        return
    }
    #expect(summary.entryCount == 1)
    #expect(try JSONEncoder().encode(response).count <= 8_192)
}

@Test(arguments: [
    "shell",
    "filesystem.read",
    "writeFile",
    "cleanup",
    "moveToTrash",
    "runRegisteredAction",
])
func probeBridgeRejectsUnregisteredShellFilesystemWriteAndCleanupTools(
    _ tool: String
) async throws {
    let fixture = try ProbeBridgeFixture()
    defer { fixture.remove() }
    let fakeCodex = FakeCodexBridgeClient(
        bridge: ProbeBridge(broker: ProbeBroker(), context: fixture.context)
    )

    let response = try await fakeCodex.call(
        id: "rejected",
        tool: tool,
        arguments: ["targetPath": .string(fixture.rootURL.path)]
    )

    #expect(response.result == nil)
    #expect(response.error == .toolNotAllowed)
}

@Test
func probeBridgeRejectsMalformedAndUnexpectedArguments() async throws {
    let fixture = try ProbeBridgeFixture()
    defer { fixture.remove() }
    let bridge = ProbeBridge(broker: ProbeBroker(), context: fixture.context)

    let malformed = await bridge.handle(Data("{not-json".utf8))
    #expect(try ProbeBridgeResponse.decode(from: malformed).error == .malformedRequest)

    let extraArgument = try JSONSerialization.data(withJSONObject: [
        "id": "extra",
        "tool": "stornaut.directorySummary",
        "arguments": [
            "targetPath": fixture.rootURL.path,
            "write": true,
        ],
    ])
    let extraResponse = await bridge.handle(extraArgument)
    #expect(try ProbeBridgeResponse.decode(from: extraResponse).error == .invalidArguments)

    let extraEnvelopeField = try JSONSerialization.data(withJSONObject: [
        "id": "extra-envelope",
        "tool": "stornaut.directorySummary",
        "arguments": ["targetPath": fixture.rootURL.path],
        "command": "rm -rf /",
    ])
    let extraEnvelopeResponse = await bridge.handle(extraEnvelopeField)
    #expect(
        try ProbeBridgeResponse.decode(from: extraEnvelopeResponse).error
            == .malformedRequest
    )

    let missingTarget = try JSONSerialization.data(withJSONObject: [
        "id": "missing",
        "tool": "stornaut.directorySummary",
        "arguments": [:],
    ])
    let missingResponse = await bridge.handle(missingTarget)
    #expect(try ProbeBridgeResponse.decode(from: missingResponse).error == .invalidArguments)
}

@Test
func probeBridgeEnforcesRequestAndResponseBounds() async throws {
    let fixture = try ProbeBridgeFixture()
    defer { fixture.remove() }
    let requestLimitedBridge = ProbeBridge(
        broker: ProbeBroker(),
        context: fixture.context,
        requestByteLimit: 32,
        responseByteLimit: 8_192
    )
    let oversizedRequest = Data(repeating: 0x61, count: 33)
    let requestResponse = await requestLimitedBridge.handle(oversizedRequest)
    #expect(try ProbeBridgeResponse.decode(from: requestResponse).error == .requestTooLarge)

    let responseLimitedBridge = ProbeBridge(
        broker: ProbeBroker(),
        context: fixture.context,
        requestByteLimit: 4_096,
        responseByteLimit: 128
    )
    let fakeCodex = FakeCodexBridgeClient(bridge: responseLimitedBridge)
    let response = try await fakeCodex.call(
        id: String(repeating: "x", count: 1_024),
        tool: "stornaut.directorySummary",
        arguments: ["targetPath": .string(fixture.rootURL.path)]
    )
    #expect(response.result == nil)
    #expect(response.error == .responseTooLarge)
}

private struct FakeCodexBridgeClient {
    let bridge: ProbeBridge

    func call(
        id: String,
        tool: String,
        arguments: [String: JSONValue]
    ) async throws -> ProbeBridgeResponse {
        let request = ProbeBridgeRequest(
            id: id,
            tool: tool,
            arguments: arguments
        )
        let requestData = try JSONEncoder().encode(request)
        let responseData = await bridge.handle(requestData)
        return try ProbeBridgeResponse.decode(from: responseData)
    }
}

private struct ProbeBridgeFixture {
    let parentURL: URL
    let rootURL: URL
    let context: ProbeContext

    init() throws {
        parentURL = FileManager.default.temporaryDirectory
            .appending(path: "stornaut-probe-bridge-\(UUID().uuidString)")
        rootURL = parentURL.appending(path: "allowed")
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        try Data("fixture".utf8).write(
            to: rootURL.appending(path: "README.md")
        )
        context = ProbeContext(
            allowedRoots: [rootURL],
            maximumReadLevel: .level1,
            perCallTimeout: .seconds(1),
            perCallOutputByteLimit: 64 * 1_024,
            session: ProbeSessionBudget(limits: .generousForTesting),
            auditRecorder: ProbeAuditRecorder()
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: parentURL)
    }
}
