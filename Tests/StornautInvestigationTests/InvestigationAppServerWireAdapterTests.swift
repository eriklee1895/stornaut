import Foundation
import Testing
import StornautCore
@testable import StornautInvestigation

@Suite("Investigation App Server wire adapter")
struct InvestigationAppServerWireAdapterTests {
    @Test
    func receiptSelectedToolSchemaDecodesRootTurnAndSpawn() throws {
        let fixture = try InvestigationCoordinatorFixture()
        let adapter = InvestigationAppServerWireAdapter(
            receipt: fixture.receipt,
            root: fixture.root
        )

        #expect(
            try adapter.decode(
                line([
                    "method": "thread/started",
                    "params": [
                        "thread": [
                            "id": fixture.root.id.rawValue,
                        ],
                    ],
                ])
            ) == .rootStarted(
                root: fixture.root,
                payload: line([
                    "method": "thread/started",
                    "params": [
                        "thread": [
                            "id": fixture.root.id.rawValue,
                        ],
                    ],
                ])
            )
        )

        let turn = try adapter.decode(
            line([
                "method": "turn/started",
                "params": [
                    "threadId": fixture.root.id.rawValue,
                    "turn": [
                        "id": fixture.rootTurnID.rawValue,
                        "status": "inProgress",
                    ],
                ],
            ])
        )
        guard case let .turnStarted(threadID, turnID, _) = turn else {
            Issue.record("Expected turnStarted")
            return
        }
        #expect(threadID == fixture.root.id)
        #expect(turnID == fixture.rootTurnID)

        let spawn = try adapter.decode(
            itemLine(
                method: "item/completed",
                threadID: fixture.root.id.rawValue,
                turnID: fixture.rootTurnID.rawValue,
                item: [
                    "id": "item-spawn",
                    "type": "collabToolCall",
                    "tool": "spawn_agent",
                    "senderThreadId": fixture.root.id.rawValue,
                    "newThreadId": "thread-child",
                ]
            )
        )
        guard case let .itemCompleted(event) = spawn else {
            Issue.record("Expected itemCompleted")
            return
        }
        #expect(event.type == "collabToolCall")
        #expect(event.tool == "spawn_agent")
        #expect(
            event.childThreadIDs
                == [DomainToken(rawValue: "thread-child")!]
        )
    }

    @Test
    func agentToolSchemaDecodesReceiversAndRejectsMixedSchema() throws {
        let fixture = try InvestigationCoordinatorFixture()
        let receipt = InvestigationRuntimeReceiptV1(
            id: fixture.receipt.id,
            schema: .collabAgentToolCallV1,
            capabilityTokens: fixture.receipt.capabilityTokens
        )
        let adapter = InvestigationAppServerWireAdapter(
            receipt: receipt,
            root: fixture.root
        )

        let accepted = try adapter.decode(
            itemLine(
                method: "item/completed",
                threadID: fixture.root.id.rawValue,
                turnID: fixture.rootTurnID.rawValue,
                item: [
                    "id": "item-agent-spawn",
                    "type": "collabAgentToolCall",
                    "tool": "spawnAgent",
                    "senderThreadId": fixture.root.id.rawValue,
                    "receiverThreadIds": [
                        "thread-child-a",
                        "thread-child-b",
                    ],
                ]
            )
        )
        guard case let .itemCompleted(event) = accepted else {
            Issue.record("Expected itemCompleted")
            return
        }
        #expect(
            event.childThreadIDs.map(\.rawValue)
                == ["thread-child-a", "thread-child-b"]
        )

        #expect(
            throws: InvestigationAppServerWireError.nonSelectedSchema
        ) {
            _ = try adapter.decode(
                itemLine(
                    method: "item/started",
                    threadID: fixture.root.id.rawValue,
                    turnID: fixture.rootTurnID.rawValue,
                    item: [
                        "id": "item-wrong-spawn",
                        "type": "collabToolCall",
                        "tool": "spawn_agent",
                    ]
                )
            )
        }
    }

    @Test
    func collaborationStartDoesNotRequireCompletedChildIdentity() throws {
        let fixture = try InvestigationCoordinatorFixture()
        let receipt = InvestigationRuntimeReceiptV1(
            id: fixture.receipt.id,
            schema: .collabAgentToolCallV1,
            capabilityTokens: fixture.receipt.capabilityTokens
        )
        let adapter = InvestigationAppServerWireAdapter(
            receipt: receipt,
            root: fixture.root
        )

        let started = try adapter.decode(
            itemLine(
                method: "item/started",
                threadID: fixture.root.id.rawValue,
                turnID: fixture.rootTurnID.rawValue,
                item: [
                    "id": "item-agent-spawn",
                    "type": "collabAgentToolCall",
                    "tool": "spawnAgent",
                ]
            )
        )

        guard case let .itemStarted(event) = started else {
            Issue.record("Expected itemStarted")
            return
        }
        #expect(event.tool == "spawnAgent")
        #expect(event.childThreadIDs.isEmpty)
    }

    @Test
    func tokenUsageTurnTerminalAndEnvelopeAreTyped() throws {
        let fixture = try InvestigationCoordinatorFixture()
        let adapter = InvestigationAppServerWireAdapter(
            receipt: fixture.receipt,
            root: fixture.root
        )

        let usage = try adapter.decode(
            line([
                "method": "thread/tokenUsage/updated",
                "params": [
                    "threadId": fixture.root.id.rawValue,
                    "turnId": fixture.rootTurnID.rawValue,
                    "tokenUsage": [
                        "total": [
                            "totalTokens": 120,
                            "inputTokens": 80,
                            "cachedInputTokens": 20,
                            "outputTokens": 40,
                        ],
                        "last": [
                            "totalTokens": 20,
                            "inputTokens": 10,
                            "cachedInputTokens": 2,
                            "outputTokens": 10,
                        ],
                    ],
                ],
            ])
        )
        guard case let .tokenUsage(event) = usage else {
            Issue.record("Expected tokenUsage")
            return
        }
        #expect(event.total.totalTokens == 120)
        #expect(event.last.cachedInputTokens == 2)

        let envelope = Data(#"{"schemaVersion":2}"#.utf8)
        let message = try adapter.decode(
            itemLine(
                method: "item/completed",
                threadID: fixture.root.id.rawValue,
                turnID: fixture.rootTurnID.rawValue,
                item: [
                    "id": "item-final",
                    "type": "agentMessage",
                    "text": String(decoding: envelope, as: UTF8.self),
                ]
            )
        )
        #expect(
            message == .agentMessage(
                threadID: fixture.root.id,
                turnID: fixture.rootTurnID,
                data: envelope
            )
        )

        let terminal = try adapter.decode(
            line([
                "method": "turn/completed",
                "params": [
                    "threadId": fixture.root.id.rawValue,
                    "turn": [
                        "id": fixture.rootTurnID.rawValue,
                        "status": "completed",
                    ],
                ],
            ])
        )
        guard case let .turnTerminal(threadID, turnID, _) = terminal else {
            Issue.record("Expected turnTerminal")
            return
        }
        #expect(threadID == fixture.root.id)
        #expect(turnID == fixture.rootTurnID)
    }

    @Test
    func threadReadMetadataAndMalformedLinesFailClosed() throws {
        let fixture = try InvestigationCoordinatorFixture()
        let adapter = InvestigationAppServerWireAdapter(
            receipt: fixture.receipt,
            root: fixture.root
        )
        let child = try adapter.decodeThreadMetadata(
            line([
                "result": [
                    "thread": [
                        "id": "thread-child",
                        "parentThreadId": fixture.root.id.rawValue,
                        "sessionId": fixture.root.id.rawValue,
                    ],
                ],
            ])
        )
        #expect(child.id.rawValue == "thread-child")
        #expect(child.parentThreadID == fixture.root.id)
        #expect(child.sessionID == fixture.root.id)

        #expect(throws: InvestigationAppServerWireError.invalidLine) {
            _ = try adapter.decode(Data(#"{"method":"turn/started"}"#.utf8))
        }
        #expect(throws: InvestigationAppServerWireError.unknownMethod) {
            _ = try adapter.decode(
                line([
                    "method": "thread/resumed",
                    "params": [:],
                ])
            )
        }
    }

    @Test
    func tokenUsageRejectsFractionalOverflowAndInvalidBreakdown() throws {
        let fixture = try InvestigationCoordinatorFixture()
        let adapter = InvestigationAppServerWireAdapter(
            receipt: fixture.receipt,
            root: fixture.root
        )

        for total in [120.5, 18_446_744_073_709_551_616.0] {
            #expect(throws: InvestigationAppServerWireError.invalidLine) {
                _ = try adapter.decode(
                    tokenUsageLine(
                        fixture: fixture,
                        total: total,
                        input: 80,
                        cachedInput: 20,
                        output: 40
                    )
                )
            }
        }
        #expect(throws: InvestigationAppServerWireError.invalidPayload) {
            _ = try adapter.decode(
                tokenUsageLine(
                    fixture: fixture,
                    total: 120,
                    input: 80,
                    cachedInput: 81,
                    output: 40
                )
            )
        }
    }
}

private func itemLine(
    method: String,
    threadID: String,
    turnID: String,
    item: [String: Any]
) -> Data {
    line([
        "method": method,
        "params": [
            "threadId": threadID,
            "turnId": turnID,
            "item": item,
        ],
    ])
}

private func line(_ object: [String: Any]) -> Data {
    var data = try! JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys]
    )
    data.append(0x0A)
    return data
}

private func tokenUsageLine(
    fixture: InvestigationCoordinatorFixture,
    total: Any,
    input: Any,
    cachedInput: Any,
    output: Any
) -> Data {
    line([
        "method": "thread/tokenUsage/updated",
        "params": [
            "threadId": fixture.root.id.rawValue,
            "turnId": fixture.rootTurnID.rawValue,
            "tokenUsage": [
                "total": [
                    "totalTokens": total,
                    "inputTokens": input,
                    "cachedInputTokens": cachedInput,
                    "outputTokens": output,
                ],
                "last": [
                    "totalTokens": 10,
                    "inputTokens": 5,
                    "cachedInputTokens": 2,
                    "outputTokens": 5,
                ],
            ],
        ],
    ])
}
