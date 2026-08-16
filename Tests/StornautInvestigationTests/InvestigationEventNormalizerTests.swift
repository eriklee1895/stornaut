import Foundation
import Testing
import StornautCore
@testable import StornautInvestigation

@Suite("Investigation runtime event normalizer")
struct InvestigationEventNormalizerTests {
    @Test
    func selectedToolSchemaBuildsVerifiedChildLineage() throws {
        let fixture = try InvestigationEventFixture(
            schema: .collabToolCallV1
        )
        var normalizer = fixture.normalizer()

        try fixture.acceptRoot(on: &normalizer)
        _ = try normalizer.reserveTurnStart(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            contextByteCount: 128
        )
        try normalizer.acceptTurnStarted(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-turn")
        )
        let spawn = try normalizer.acceptItemCompleted(
            InvestigationRuntimeItemEventV1(
                threadID: fixture.root.id,
                turnID: fixture.rootTurnID,
                itemID: fixture.spawnItemID,
                type: "collabToolCall",
                tool: "spawn_agent",
                senderThreadID: fixture.root.id,
                childThreadIDs: [fixture.childID],
                mcpReadOnly: nil,
                payload: fixture.payload("spawn-child")
            )
        )
        #expect(spawn.admittedChildThreadIDs == [fixture.childID])

        try normalizer.verifyChild(
            InvestigationRuntimeThreadMetadataV1(
                id: fixture.childID,
                parentThreadID: fixture.root.id,
                sessionID: fixture.root.id
            )
        )
        _ = try normalizer.reserveTurnStart(
            threadID: fixture.childID,
            turnID: fixture.childTurnID,
            contextByteCount: 128
        )
        try normalizer.acceptTurnStarted(
            threadID: fixture.childID,
            turnID: fixture.childTurnID,
            payload: fixture.payload("child-turn")
        )

        let observation = try normalizer.acceptItemStarted(
            InvestigationRuntimeItemEventV1(
                threadID: fixture.childID,
                turnID: fixture.childTurnID,
                itemID: DomainToken(rawValue: "item-child-command")!,
                type: "commandExecution",
                tool: nil,
                senderThreadID: nil,
                childThreadIDs: [],
                mcpReadOnly: nil,
                payload: fixture.payload("child-command")
            )
        )
        #expect(observation.directToolObservation != nil)
        #expect(observation.observedDirectToolStarts == 1)
    }

    @Test
    func nonSelectedCollaborationSchemaAndWriteCapableItemsBlock() throws {
        let fixture = try InvestigationEventFixture(
            schema: .collabToolCallV1
        )
        var normalizer = fixture.normalizer()
        try fixture.acceptRoot(on: &normalizer)
        _ = try normalizer.reserveTurnStart(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            contextByteCount: 128
        )
        try normalizer.acceptTurnStarted(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-turn")
        )

        #expect(throws: InvestigationEventError.nonSelectedSchema) {
            _ = try normalizer.acceptItemStarted(
                InvestigationRuntimeItemEventV1(
                    threadID: fixture.root.id,
                    turnID: fixture.rootTurnID,
                    itemID: fixture.spawnItemID,
                    type: "collabAgentToolCall",
                    tool: "spawnAgent",
                    senderThreadID: fixture.root.id,
                    childThreadIDs: [fixture.childID],
                    mcpReadOnly: nil,
                    payload: fixture.payload("wrong-schema")
                )
            )
        }

        #expect(throws: InvestigationEventError.writeCapableItem) {
            _ = try normalizer.acceptItemStarted(
                InvestigationRuntimeItemEventV1(
                    threadID: fixture.root.id,
                    turnID: fixture.rootTurnID,
                    itemID: DomainToken(rawValue: "item-file-change")!,
                    type: "fileChange",
                    tool: nil,
                    senderThreadID: nil,
                    childThreadIDs: [],
                    mcpReadOnly: nil,
                    payload: fixture.payload("file-change")
                )
            )
        }
    }

    @Test
    func completedWriteCapableAndUnknownItemsAlsoBlock() throws {
        let fixture = try InvestigationEventFixture(
            schema: .collabToolCallV1
        )
        var normalizer = fixture.normalizer()
        try fixture.acceptRoot(on: &normalizer)
        _ = try normalizer.reserveTurnStart(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            contextByteCount: 128
        )
        try normalizer.acceptTurnStarted(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-turn")
        )

        for event in [
            InvestigationRuntimeItemEventV1(
                threadID: fixture.root.id,
                turnID: fixture.rootTurnID,
                itemID: DomainToken(rawValue: "completed-file-change")!,
                type: "fileChange",
                tool: nil,
                senderThreadID: nil,
                childThreadIDs: [],
                mcpReadOnly: nil,
                payload: fixture.payload("completed-file-change")
            ),
            InvestigationRuntimeItemEventV1(
                threadID: fixture.root.id,
                turnID: fixture.rootTurnID,
                itemID: DomainToken(rawValue: "completed-write-mcp")!,
                type: "mcpToolCall",
                tool: nil,
                senderThreadID: nil,
                childThreadIDs: [],
                mcpReadOnly: false,
                payload: fixture.payload("completed-write-mcp")
            ),
        ] {
            #expect(throws: InvestigationEventError.writeCapableItem) {
                _ = try normalizer.acceptItemCompleted(event)
            }
        }

        #expect(throws: InvestigationEventError.unknownToolItem) {
            _ = try normalizer.acceptItemCompleted(
                InvestigationRuntimeItemEventV1(
                    threadID: fixture.root.id,
                    turnID: fixture.rootTurnID,
                    itemID: DomainToken(
                        rawValue: "completed-unknown-tool"
                    )!,
                    type: "futureToolExecution",
                    tool: "future_tool",
                    senderThreadID: nil,
                    childThreadIDs: [],
                    mcpReadOnly: nil,
                    payload: fixture.payload("completed-unknown-tool")
                )
            )
        }
    }

    @Test
    func modelProseItemsAreIgnoredWhileUnknownItemsBlock() throws {
        let fixture = try InvestigationEventFixture(
            schema: .collabToolCallV1
        )
        var normalizer = fixture.normalizer()
        try fixture.acceptRoot(on: &normalizer)
        _ = try normalizer.reserveTurnStart(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            contextByteCount: 128
        )
        try normalizer.acceptTurnStarted(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-turn")
        )

        let proseTypes = [
            "agentMessage",
            "reasoning",
            "plan",
            "sleep",
            "userMessage",
        ]
        for type in proseTypes {
            let result = try normalizer.acceptItemStarted(
                InvestigationRuntimeItemEventV1(
                    threadID: fixture.root.id,
                    turnID: fixture.rootTurnID,
                    itemID: DomainToken(rawValue: "item-\(type)")!,
                    type: type,
                    tool: nil,
                    senderThreadID: nil,
                    childThreadIDs: [],
                    mcpReadOnly: nil,
                    payload: fixture.payload(type)
                )
            )
            #expect(result.directToolObservation == nil)
            #expect(result.observedDirectToolStarts == 0)
        }

        let replayedProse = InvestigationRuntimeItemEventV1(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            itemID: DomainToken(rawValue: "item-agentMessage")!,
            type: "agentMessage",
            tool: nil,
            senderThreadID: nil,
            childThreadIDs: [],
            mcpReadOnly: nil,
            payload: fixture.payload("agentMessage")
        )
        _ = try normalizer.acceptItemStarted(replayedProse)
        #expect(throws: InvestigationEventError.conflictingReplay) {
            _ = try normalizer.acceptItemStarted(
                InvestigationRuntimeItemEventV1(
                    threadID: fixture.root.id,
                    turnID: fixture.rootTurnID,
                    itemID: replayedProse.itemID,
                    type: "commandExecution",
                    tool: nil,
                    senderThreadID: nil,
                    childThreadIDs: [],
                    mcpReadOnly: nil,
                    payload: fixture.payload("retyped-command")
                )
            )
        }

        #expect(throws: InvestigationEventError.unknownToolItem) {
            _ = try normalizer.acceptItemStarted(
                InvestigationRuntimeItemEventV1(
                    threadID: fixture.root.id,
                    turnID: fixture.rootTurnID,
                    itemID: DomainToken(rawValue: "item-unknown-tool")!,
                    type: "futureToolExecution",
                    tool: "future_tool",
                    senderThreadID: nil,
                    childThreadIDs: [],
                    mcpReadOnly: nil,
                    payload: fixture.payload("unknown-tool")
                )
            )
        }
    }

    @Test
    func replayAndPerThreadCumulativeUsageDoNotDoubleCount() throws {
        let fixture = try InvestigationEventFixture(
            schema: .collabAgentToolCallV1
        )
        var normalizer = fixture.normalizer()
        try fixture.acceptRoot(on: &normalizer)
        _ = try normalizer.reserveTurnStart(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            contextByteCount: 128
        )
        try normalizer.acceptTurnStarted(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-turn")
        )

        let event = InvestigationRuntimeItemEventV1(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            itemID: DomainToken(rawValue: "item-root-command")!,
            type: "commandExecution",
            tool: nil,
            senderThreadID: nil,
            childThreadIDs: [],
            mcpReadOnly: nil,
            payload: fixture.payload("root-command")
        )
        let first = try normalizer.acceptItemStarted(event)
        let replay = try normalizer.acceptItemStarted(event)
        #expect(first.observedDirectToolStarts == 1)
        #expect(replay.observedDirectToolStarts == 1)
        #expect(replay.directToolObservation == nil)

        let firstUsage = try normalizer.acceptTokenUsage(
            fixture.usage(total: 100, payload: "usage-100")
        )
        let secondUsage = try normalizer.acceptTokenUsage(
            fixture.usage(total: 140, payload: "usage-140")
        )
        #expect(firstUsage.totalTokens == 100)
        #expect(secondUsage.totalTokens == 140)
        #expect(secondUsage.quality == .observed)

        #expect(throws: InvestigationEventError.counterDecreased) {
            _ = try normalizer.acceptTokenUsage(
                fixture.usage(total: 139, payload: "usage-139")
            )
        }
    }

    @Test
    func equalTokenReplayDoesNotConsumeCoordinatorOrdinal() throws {
        let fixture = try InvestigationEventFixture(
            schema: .collabToolCallV1
        )
        var normalizer = fixture.normalizer()
        try fixture.acceptRoot(on: &normalizer)
        _ = try normalizer.reserveTurnStart(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            contextByteCount: 128
        )
        try normalizer.acceptTurnStarted(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-turn")
        )
        let usage = fixture.usage(total: 100, payload: "usage-100")

        _ = try normalizer.acceptTokenUsage(usage)
        _ = try normalizer.acceptTokenUsage(usage)
        let observation = try normalizer.acceptItemStarted(
            InvestigationRuntimeItemEventV1(
                threadID: fixture.root.id,
                turnID: fixture.rootTurnID,
                itemID: DomainToken(rawValue: "item-after-replay")!,
                type: "commandExecution",
                tool: nil,
                senderThreadID: nil,
                childThreadIDs: [],
                mcpReadOnly: nil,
                payload: fixture.payload("command-after-replay")
            )
        )

        #expect(
            observation.directToolObservation?.coordinatorOrdinal == 3
        )
    }

    @Test
    func terminalTurnRejectsLaterItemsAndFinalizesCompleteTree() throws {
        let fixture = try InvestigationEventFixture(
            schema: .collabAgentToolCallV1
        )
        var normalizer = fixture.normalizer()
        try fixture.acceptRoot(on: &normalizer)
        _ = try normalizer.reserveTurnStart(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            contextByteCount: 128
        )
        try normalizer.acceptTurnStarted(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-turn")
        )
        _ = try normalizer.acceptTokenUsage(
            fixture.usage(total: 120, payload: "usage-120")
        )

        try normalizer.acceptTurnTerminal(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-turn-completed")
        )
        let finalization = try normalizer.finalizeTree()

        #expect(finalization.allTurnsTerminal)
        #expect(finalization.usageUnavailableThreadIDs.isEmpty)
        #expect(finalization.totalTokens == 120)
        #expect(throws: InvestigationEventError.postTerminalEvent) {
            _ = try normalizer.acceptItemStarted(
                InvestigationRuntimeItemEventV1(
                    threadID: fixture.root.id,
                    turnID: fixture.rootTurnID,
                    itemID: DomainToken(rawValue: "item-too-late")!,
                    type: "commandExecution",
                    tool: nil,
                    senderThreadID: nil,
                    childThreadIDs: [],
                    mcpReadOnly: nil,
                    payload: fixture.payload("late-command")
                )
            )
        }
    }

    @Test
    func finalizationRejectsLiveOrUnclassifiedDescendants() throws {
        let fixture = try InvestigationEventFixture(
            schema: .collabToolCallV1
        )
        var pending = fixture.normalizer()
        try fixture.acceptRoot(on: &pending)
        _ = try pending.reserveTurnStart(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            contextByteCount: 128
        )
        try pending.acceptTurnStarted(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-turn")
        )
        _ = try pending.acceptItemCompleted(
            fixture.spawnEvent(payload: "spawn-pending-child")
        )
        try pending.acceptTurnTerminal(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-terminal")
        )
        #expect(throws: InvestigationEventError.unclassifiedDescendant) {
            _ = try pending.finalizeTree()
        }

        var live = fixture.normalizer()
        try fixture.acceptRoot(on: &live)
        _ = try live.reserveTurnStart(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            contextByteCount: 128
        )
        try live.acceptTurnStarted(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-turn")
        )
        _ = try live.acceptItemCompleted(
            fixture.spawnEvent(payload: "spawn-live-child")
        )
        try live.verifyChild(fixture.childMetadata)
        _ = try live.reserveTurnStart(
            threadID: fixture.childID,
            turnID: fixture.childTurnID,
            contextByteCount: 128
        )
        try live.acceptTurnStarted(
            threadID: fixture.childID,
            turnID: fixture.childTurnID,
            payload: fixture.payload("child-turn")
        )
        try live.acceptTurnTerminal(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-terminal")
        )
        #expect(throws: InvestigationEventError.liveDescendant) {
            _ = try live.finalizeTree()
        }
    }

    @Test
    func terminalTreeClassifiesMissingUsageWithoutEstimatingTokens()
        throws
    {
        let fixture = try InvestigationEventFixture(
            schema: .collabToolCallV1
        )
        var normalizer = fixture.normalizer()
        try fixture.acceptRoot(on: &normalizer)
        _ = try normalizer.reserveTurnStart(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            contextByteCount: 128
        )
        try normalizer.acceptTurnStarted(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-turn")
        )
        try normalizer.acceptTurnTerminal(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-terminal")
        )

        let finalization = try normalizer.finalizeTree()

        #expect(finalization.totalTokens == nil)
        #expect(
            finalization.usageUnavailableThreadIDs == [fixture.root.id]
        )
    }

    @Test
    func finalEnvelopeIsUnavailableUntilItsSourceTurnIsTerminal() throws {
        let fixture = try InvestigationEventFixture(
            schema: .collabToolCallV1
        )
        var normalizer = fixture.normalizer()
        try fixture.acceptRoot(on: &normalizer)
        _ = try normalizer.reserveTurnStart(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            contextByteCount: 128
        )
        try normalizer.acceptTurnStarted(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-turn")
        )
        let envelope = fixture.payload("strict-envelope")

        try normalizer.retainFinalEnvelope(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            data: envelope
        )
        #expect(normalizer.terminalEnvelopeData == nil)

        try normalizer.acceptTurnTerminal(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-terminal")
        )
        #expect(normalizer.terminalEnvelopeData == envelope)
    }

    @Test
    func latestTerminalRootMessageWinsAndChildMessageCannotReplaceIt()
        throws
    {
        let fixture = try InvestigationEventFixture(
            schema: .collabToolCallV1
        )
        var normalizer = fixture.normalizer()
        try fixture.acceptRoot(on: &normalizer)
        _ = try normalizer.reserveTurnStart(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            contextByteCount: 128
        )
        try normalizer.acceptTurnStarted(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-turn")
        )
        let earlyRootMessage = fixture.payload("early-root-message")
        try normalizer.retainFinalEnvelope(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            data: earlyRootMessage
        )
        _ = try normalizer.acceptItemCompleted(
            fixture.spawnEvent(payload: "spawn-child")
        )
        try normalizer.verifyChild(fixture.childMetadata)
        try normalizer.acceptTurnTerminal(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-terminal")
        )

        _ = try normalizer.reserveTurnStart(
            threadID: fixture.childID,
            turnID: fixture.childTurnID,
            contextByteCount: 128
        )
        try normalizer.acceptTurnStarted(
            threadID: fixture.childID,
            turnID: fixture.childTurnID,
            payload: fixture.payload("child-turn")
        )
        try normalizer.retainFinalEnvelope(
            threadID: fixture.childID,
            turnID: fixture.childTurnID,
            data: fixture.payload("child-message")
        )
        try normalizer.acceptTurnTerminal(
            threadID: fixture.childID,
            turnID: fixture.childTurnID,
            payload: fixture.payload("child-terminal")
        )
        #expect(normalizer.terminalEnvelopeData == earlyRootMessage)

        _ = try normalizer.reserveTurnStart(
            threadID: fixture.root.id,
            turnID: DomainToken(rawValue: "turn-root-final")!,
            contextByteCount: 128
        )
        try normalizer.acceptTurnStarted(
            threadID: fixture.root.id,
            turnID: DomainToken(rawValue: "turn-root-final")!,
            payload: fixture.payload("root-final-turn")
        )
        let finalEnvelope = fixture.payload("strict-final-envelope")
        try normalizer.retainFinalEnvelope(
            threadID: fixture.root.id,
            turnID: DomainToken(rawValue: "turn-root-final")!,
            data: finalEnvelope
        )
        try normalizer.acceptTurnTerminal(
            threadID: fixture.root.id,
            turnID: DomainToken(rawValue: "turn-root-final")!,
            payload: fixture.payload("root-final-terminal")
        )

        #expect(normalizer.terminalEnvelopeData == finalEnvelope)
    }

    @Test
    func laterRootTurnInvalidatesEarlierTerminalEnvelope() throws {
        let fixture = try InvestigationEventFixture(
            schema: .collabToolCallV1
        )
        var normalizer = fixture.normalizer()
        try fixture.acceptRoot(on: &normalizer)
        _ = try normalizer.reserveTurnStart(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            contextByteCount: 128
        )
        try normalizer.acceptTurnStarted(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-turn")
        )
        try normalizer.retainFinalEnvelope(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            data: fixture.payload("stale-envelope")
        )
        try normalizer.acceptTurnTerminal(
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            payload: fixture.payload("root-terminal")
        )
        #expect(normalizer.terminalEnvelopeData != nil)

        _ = try normalizer.reserveTurnStart(
            threadID: fixture.root.id,
            turnID: fixture.childTurnID,
            contextByteCount: 128
        )

        #expect(normalizer.terminalEnvelopeData == nil)
    }
}
