import Foundation
import Testing
@testable import StornautCodex

@Test
func fragmentedAndMultipleJSONLLinesDecodeIncrementally() throws {
    let fixture = try codexProtocolFixture(named: "success.jsonl")
    let split = fixture.index(fixture.startIndex, offsetBy: 37)
    var decoder = JSONLDecoder(
        lineByteLimit: 4_096,
        sessionByteLimit: 16_384,
        unknownMetadataByteLimit: 256
    )

    let firstEvents = try decoder.append(Data(fixture[..<split].utf8))
    let secondEvents = try decoder.append(Data(fixture[split...].utf8))
    let finalEvents = try decoder.finish()
    let events = firstEvents + secondEvents + finalEvents

    #expect(events.count == 5)
    #expect(events[0] == .threadStarted)
    #expect(events[1] == .turnStarted)
    #expect(events[4] == .turnCompleted(
        CodexUsage(
            inputTokens: 12,
            cachedInputTokens: 3,
            cacheWriteInputTokens: 0,
            outputTokens: 8,
            reasoningOutputTokens: 2
        )
    ))
}

@Test
func utf8ScalarSplitAcrossChunksIsReassembled() throws {
    let line = """
    {"type":"item.completed","item":{"id":"message-utf8","type":"agent_message","text":"磁盘调查"}}

    """
    let bytes = Array(line.utf8)
    let scalarStart = try #require(bytes.firstIndex(of: 0xE7))
    var decoder = JSONLDecoder(
        lineByteLimit: 1_024,
        sessionByteLimit: 2_048,
        unknownMetadataByteLimit: 128
    )

    #expect(try decoder.append(Data(bytes[..<(scalarStart + 1)])).isEmpty)
    let events = try decoder.append(Data(bytes[(scalarStart + 1)...]))
    #expect(try decoder.finish().isEmpty)

    let event = try #require(events.first)
    guard case let .itemCompleted(item) = event else {
        Issue.record("Expected an item.completed event")
        return
    }
    #expect(item.id == "message-utf8")
    #expect(item.agentMessageText == "磁盘调查")
}

@Test
func unknownEventPreservesOnlyBoundedScalarMetadata() throws {
    let line = """
    {"type":"future.event","phase":"fixture","sequence":7,"enabled":true,"nested":{"raw":"not retained"}}

    """
    var decoder = JSONLDecoder(
        lineByteLimit: 1_024,
        sessionByteLimit: 2_048,
        unknownMetadataByteLimit: 64
    )

    let events = try decoder.append(Data(line.utf8))
    let event = try #require(events.first)
    guard case let .unknown(unknown) = event else {
        Issue.record("Expected an unknown event")
        return
    }

    #expect(unknown.type == "future.event")
    #expect(unknown.metadata["phase"] == "fixture")
    #expect(unknown.metadata["sequence"] == "7")
    #expect(unknown.metadata["enabled"] == "true")
    #expect(unknown.metadata["nested"] == nil)
    #expect(unknown.metadata.utf8ByteCount <= 64)
}

@Test
func malformedJSONLFailsWithoutReturningRawContent() throws {
    var decoder = JSONLDecoder(
        lineByteLimit: 1_024,
        sessionByteLimit: 2_048,
        unknownMetadataByteLimit: 64
    )
    let malformed = try codexProtocolFixture(named: "malformed.jsonl")

    #expect(throws: JSONLDecoderError.malformedJSON(lineNumber: 2)) {
        _ = try decoder.append(Data(malformed.utf8))
    }
}

@Test
func unfinishedFinalLineFailsClosed() throws {
    var decoder = JSONLDecoder(
        lineByteLimit: 1_024,
        sessionByteLimit: 2_048,
        unknownMetadataByteLimit: 64
    )
    _ = try decoder.append(Data(#"{"type":"turn.started"}"#.utf8))

    #expect(throws: JSONLDecoderError.truncatedFinalLine) {
        _ = try decoder.finish()
    }
}

@Test
func lineAndSessionByteLimitsAreIndependent() throws {
    var lineLimited = JSONLDecoder(
        lineByteLimit: 16,
        sessionByteLimit: 1_024,
        unknownMetadataByteLimit: 32
    )
    #expect(throws: JSONLDecoderError.lineByteLimitExceeded(limit: 16)) {
        _ = try lineLimited.append(Data(repeating: 0x61, count: 17))
    }

    var sessionLimited = JSONLDecoder(
        lineByteLimit: 128,
        sessionByteLimit: 30,
        unknownMetadataByteLimit: 32
    )
    _ = try sessionLimited.append(Data("{\"type\":\"turn.started\"}\n".utf8))
    #expect(throws: JSONLDecoderError.sessionByteLimitExceeded(limit: 30)) {
        _ = try sessionLimited.append(Data("{\"type\":\"turn.started\"}\n".utf8))
    }
}

@Test
func finalAgentMessageDecodesToValidatedEnvelope() throws {
    let fixture = try codexProtocolFixture(named: "success.jsonl")
    var decoder = JSONLDecoder(
        lineByteLimit: 4_096,
        sessionByteLimit: 16_384,
        unknownMetadataByteLimit: 256
    )
    let events = try decoder.append(Data(fixture.utf8)) + decoder.finish()
    let message = try #require(events.compactMap(\.agentMessageText).last)

    let envelope = try InvestigationEnvelope.decodeValidated(
        from: Data(message.utf8)
    )

    #expect(envelope.summary == "Static fixture result")
    #expect(envelope.findings == [
        InvestigationFinding(
            targetID: "target-1",
            summary: "No cleanup action was evaluated"
        ),
    ])
    #expect(envelope.unresolvedTargetIDs.isEmpty)
}

@Test
func completedToolItemsExposeOnlyClosedSuccessEvidence() throws {
    var decoder = JSONLDecoder(
        lineByteLimit: 8_192,
        sessionByteLimit: 32_768,
        unknownMetadataByteLimit: 256
    )
    let jsonl = """
    {"type":"item.completed","item":{"id":"command-1","type":"command_execution","command":"cat private.txt","aggregated_output":"secret output","exit_code":0,"status":"completed"}}
    {"type":"item.completed","item":{"id":"search-1","type":"web_search","query":"private query","action":{"type":"search"}}}

    """

    let events = try decoder.append(Data(jsonl.utf8))
    _ = try decoder.finish()

    #expect(events.count == 2)
    guard
        case let .itemCompleted(command) = events[0],
        case let .itemCompleted(search) = events[1]
    else {
        Issue.record("Expected two completed tool items")
        return
    }
    #expect(command.type == "command_execution")
    #expect(command.succeeded == true)
    #expect(command.agentMessageText == nil)
    #expect(search.type == "web_search")
    #expect(search.succeeded == true)
    #expect(search.agentMessageText == nil)
}

@Test
func startedToolItemsNeverExposeSuccessEvidence() throws {
    var decoder = JSONLDecoder(
        lineByteLimit: 8_192,
        sessionByteLimit: 32_768,
        unknownMetadataByteLimit: 256
    )
    let jsonl = """
    {"type":"item.started","item":{"id":"search-started","type":"web_search","query":"public query","action":{"type":"search"}}}

    """

    let events = try decoder.append(Data(jsonl.utf8))
    _ = try decoder.finish()

    guard case let .itemStarted(item) = try #require(events.first) else {
        Issue.record("Expected a started tool item")
        return
    }
    #expect(item.type == "web_search")
    #expect(item.succeeded == nil)
}

@Test
func commandSuccessRejectsBooleanAndMissingExitCodes() throws {
    var decoder = JSONLDecoder(
        lineByteLimit: 8_192,
        sessionByteLimit: 32_768,
        unknownMetadataByteLimit: 256
    )
    let jsonl = """
    {"type":"item.completed","item":{"id":"boolean-exit","type":"command_execution","exit_code":false,"status":"completed"}}
    {"type":"item.completed","item":{"id":"missing-exit","type":"command_execution","status":"completed"}}

    """

    let events = try decoder.append(Data(jsonl.utf8))
    _ = try decoder.finish()

    #expect(events.count == 2)
    guard
        case let .itemCompleted(booleanExit) = events[0],
        case let .itemCompleted(missingExit) = events[1]
    else {
        Issue.record("Expected two completed command items")
        return
    }
    #expect(booleanExit.succeeded == false)
    #expect(missingExit.succeeded == false)
}

@Test
func envelopeRejectsMissingExtraAndOversizedFields() {
    let missing = Data(#"{"summary":"Incomplete"}"#.utf8)
    #expect(throws: InvestigationEnvelopeError.invalidStructure) {
        _ = try InvestigationEnvelope.decodeValidated(from: missing)
    }

    let executableCommand = Data("""
    {"summary":"Unsafe","findings":[],"unresolvedTargetIDs":[],"executableCommand":"rm -rf /"}
    """.utf8)
    #expect(throws: InvestigationEnvelopeError.unexpectedField("executableCommand")) {
        _ = try InvestigationEnvelope.decodeValidated(from: executableCommand)
    }

    let nestedExtra = Data("""
    {"summary":"Unsafe","findings":[{"targetID":"target-1","summary":"Finding","command":"rm"}],"unresolvedTargetIDs":[]}
    """.utf8)
    #expect(throws: InvestigationEnvelopeError.invalidFinding) {
        _ = try InvestigationEnvelope.decodeValidated(from: nestedExtra)
    }

    let oversizedSummary = String(repeating: "a", count: 4_097)
    let oversized = Data("""
    {"summary":"\(oversizedSummary)","findings":[],"unresolvedTargetIDs":[]}
    """.utf8)
    #expect(throws: InvestigationEnvelopeError.summaryByteLimitExceeded(limit: 4_096)) {
        _ = try InvestigationEnvelope.decodeValidated(from: oversized)
    }
}

@Test
func checkedInEnvelopeSchemaIsStrictAndContainsNoCommandField() throws {
    let schemaURL = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Sources/StornautCodex/Schemas/investigation-envelope.schema.json")
    let data = try Data(contentsOf: schemaURL)
    let object = try #require(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    let properties = try #require(object["properties"] as? [String: Any])

    #expect(object["additionalProperties"] as? Bool == false)
    #expect(Set(properties.keys) == [
        "summary",
        "findings",
        "unresolvedTargetIDs",
    ])
    #expect(properties["executableCommand"] == nil)
}

private extension CodexEvent {
    var agentMessageText: String? {
        guard case let .itemCompleted(item) = self else {
            return nil
        }
        return item.agentMessageText
    }
}

private extension Dictionary where Key == String, Value == String {
    var utf8ByteCount: Int {
        reduce(0) { partial, entry in
            partial + entry.key.utf8.count + entry.value.utf8.count
        }
    }
}

private func codexProtocolFixture(named name: String) throws -> String {
    let fixtureURL = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Fixtures/Codex")
        .appending(path: name)
    return try String(contentsOf: fixtureURL, encoding: .utf8)
}
