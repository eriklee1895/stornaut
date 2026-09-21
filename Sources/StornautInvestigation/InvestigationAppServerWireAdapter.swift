import Foundation
import StornautCodex
import StornautCore

package enum InvestigationAppServerWireError:
    Error,
    Sendable,
    Equatable
{
    case invalidLine
    case inputLimitExceeded
    case unknownMethod
    case invalidIdentity
    case invalidPayload
    case nonSelectedSchema
}

package enum InvestigationAppServerWireEventV1:
    Sendable,
    Equatable
{
    case rootStarted(
        root: InvestigationRuntimeRootV1,
        payload: Data
    )
    case turnStarted(
        threadID: DomainToken,
        turnID: DomainToken,
        payload: Data
    )
    case itemStarted(InvestigationRuntimeItemEventV1)
    case itemCompleted(InvestigationRuntimeItemEventV1)
    case tokenUsage(InvestigationRuntimeTokenUsageEventV1)
    case agentMessage(
        threadID: DomainToken,
        turnID: DomainToken,
        data: Data
    )
    case turnTerminal(
        threadID: DomainToken,
        turnID: DomainToken,
        payload: Data
    )
}

package struct InvestigationAppServerWireAdapter: Sendable {
    package static let maximumLineBytes = 2 * 1_024 * 1_024

    private let receipt: InvestigationRuntimeReceiptV1
    private let root: InvestigationRuntimeRootV1

    package init(
        receipt: InvestigationRuntimeReceiptV1,
        root: InvestigationRuntimeRootV1
    ) {
        self.receipt = receipt
        self.root = root
    }

    package func decode(
        _ line: Data
    ) throws -> InvestigationAppServerWireEventV1 {
        let object = try decodeLine(line)
        guard let method = string(object["method"]),
              let params = dictionary(object["params"])
        else {
            throw InvestigationAppServerWireError.invalidPayload
        }
        switch method {
        case "thread/started":
            let thread = try requiredDictionary(params["thread"])
            guard let threadID = token(thread["id"]),
                  threadID == root.id,
                  root.id == root.sessionID
            else {
                throw InvestigationAppServerWireError.invalidIdentity
            }
            return .rootStarted(root: root, payload: line)
        case "turn/started":
            let identity = try turnIdentity(params)
            let turn = try requiredDictionary(params["turn"])
            guard string(turn["status"]) == "inProgress" else {
                throw InvestigationAppServerWireError.invalidPayload
            }
            return .turnStarted(
                threadID: identity.threadID,
                turnID: identity.turnID,
                payload: line
            )
        case "item/started", "item/completed":
            let identity = try explicitTurnIdentity(params)
            let item = try requiredDictionary(params["item"])
            guard let itemID = token(item["id"]),
                  let type = string(item["type"]),
                  !type.isEmpty
            else {
                throw InvestigationAppServerWireError.invalidPayload
            }
            try requireSelectedCollaborationSchema(type)
            if method == "item/completed",
               type == "agentMessage",
               let text = string(item["text"])
            {
                return .agentMessage(
                    threadID: identity.threadID,
                    turnID: identity.turnID,
                    data: Data(text.utf8)
                )
            }
            let event = InvestigationRuntimeItemEventV1(
                threadID: identity.threadID,
                turnID: identity.turnID,
                itemID: itemID,
                type: type,
                tool: string(item["tool"]),
                senderThreadID: token(item["senderThreadId"]),
                childThreadIDs: try childThreadIDs(
                    item: item,
                    type: type,
                    completed: method == "item/completed"
                ),
                mcpReadOnly: bool(item["readOnly"]),
                payload: line
            )
            return method == "item/started"
                ? .itemStarted(event)
                : .itemCompleted(event)
        case "thread/tokenUsage/updated":
            let identity = try explicitTurnIdentity(params)
            let usage = try requiredDictionary(params["tokenUsage"])
            return .tokenUsage(
                InvestigationRuntimeTokenUsageEventV1(
                    threadID: identity.threadID,
                    turnID: identity.turnID,
                    total: try tokenUsage(usage["total"]),
                    last: try tokenUsage(usage["last"]),
                    payload: line
                )
            )
        case "turn/completed":
            let identity = try turnIdentity(params)
            let turn = try requiredDictionary(params["turn"])
            guard string(turn["status"]) == "completed" else {
                throw InvestigationAppServerWireError.invalidPayload
            }
            return .turnTerminal(
                threadID: identity.threadID,
                turnID: identity.turnID,
                payload: line
            )
        default:
            throw InvestigationAppServerWireError.unknownMethod
        }
    }

    package func decodeThreadMetadata(
        _ line: Data
    ) throws -> InvestigationRuntimeThreadMetadataV1 {
        let object = try decodeLine(line)
        guard let result = dictionary(object["result"]),
              let thread = dictionary(result["thread"]),
              let id = token(thread["id"]),
              let sessionID = token(thread["sessionId"])
        else {
            throw InvestigationAppServerWireError.invalidPayload
        }
        return InvestigationRuntimeThreadMetadataV1(
            id: id,
            parentThreadID: token(thread["parentThreadId"]),
            sessionID: sessionID
        )
    }

    private func decodeLine(
        _ line: Data
    ) throws -> [String: JSONValue] {
        guard !line.isEmpty, line.count <= Self.maximumLineBytes else {
            throw InvestigationAppServerWireError.inputLimitExceeded
        }
        guard line.last == 0x0A,
              line.dropLast().firstIndex(of: 0x0A) == nil
        else {
            throw InvestigationAppServerWireError.invalidLine
        }
        do {
            let value = try JSONDecoder().decode(
                JSONValue.self,
                from: line.dropLast()
            )
            guard case let .object(object) = value else {
                throw InvestigationAppServerWireError.invalidLine
            }
            return object
        } catch let error as InvestigationAppServerWireError {
            throw error
        } catch {
            throw InvestigationAppServerWireError.invalidLine
        }
    }

    private func turnIdentity(
        _ params: [String: JSONValue]
    ) throws -> (threadID: DomainToken, turnID: DomainToken) {
        let turn = try requiredDictionary(params["turn"])
        guard let threadID = token(params["threadId"]),
              let turnID = token(turn["id"])
        else {
            throw InvestigationAppServerWireError.invalidIdentity
        }
        return (threadID, turnID)
    }

    private func explicitTurnIdentity(
        _ params: [String: JSONValue]
    ) throws -> (threadID: DomainToken, turnID: DomainToken) {
        guard let threadID = token(params["threadId"]),
              let turnID = token(params["turnId"])
        else {
            throw InvestigationAppServerWireError.invalidIdentity
        }
        return (threadID, turnID)
    }

    private func tokenUsage(
        _ value: JSONValue?
    ) throws -> InvestigationTokenUsage {
        let object = try requiredDictionary(value)
        guard let totalTokens = unsigned(object["totalTokens"]),
              let inputTokens = unsigned(object["inputTokens"]),
              let cachedInputTokens = unsigned(
                  object["cachedInputTokens"]
              ),
              let outputTokens = unsigned(object["outputTokens"]),
              cachedInputTokens <= inputTokens,
              inputTokens <= totalTokens,
              outputTokens <= totalTokens
        else {
            throw InvestigationAppServerWireError.invalidPayload
        }
        return InvestigationTokenUsage(
            totalTokens: totalTokens,
            inputTokens: inputTokens,
            cachedInputTokens: cachedInputTokens,
            outputTokens: outputTokens
        )
    }

    private func childThreadIDs(
        item: [String: JSONValue],
        type: String,
        completed: Bool
    ) throws -> [DomainToken] {
        guard type == receipt.schema.itemType else {
            return []
        }
        guard completed else {
            return []
        }
        switch receipt.schema {
        case .collabToolCallV1:
            guard let child = token(
                item["newThreadId"] ?? item["receiverThreadId"]
            ) else {
                throw InvestigationAppServerWireError.invalidPayload
            }
            return [child]
        case .collabAgentToolCallV1:
            guard case let .array(values)? = item["receiverThreadIds"] else {
                throw InvestigationAppServerWireError.invalidPayload
            }
            let children = values.compactMap(token)
            guard !children.isEmpty, children.count == values.count else {
                throw InvestigationAppServerWireError.invalidPayload
            }
            return children
        }
    }

    private func requireSelectedCollaborationSchema(
        _ type: String
    ) throws {
        let collaborationTypes = [
            InvestigationCollaborationSchemaV1.collabToolCallV1.itemType,
            InvestigationCollaborationSchemaV1
                .collabAgentToolCallV1.itemType,
        ]
        if collaborationTypes.contains(type),
           type != receipt.schema.itemType
        {
            throw InvestigationAppServerWireError.nonSelectedSchema
        }
    }
}

private func requiredDictionary(
    _ value: JSONValue?
) throws -> [String: JSONValue] {
    guard let result = dictionary(value) else {
        throw InvestigationAppServerWireError.invalidPayload
    }
    return result
}

private func dictionary(
    _ value: JSONValue?
) -> [String: JSONValue]? {
    guard case let .object(object)? = value else {
        return nil
    }
    return object
}

private func string(_ value: JSONValue?) -> String? {
    guard case let .string(text)? = value else {
        return nil
    }
    return text
}

private func bool(_ value: JSONValue?) -> Bool? {
    guard case let .bool(flag)? = value else {
        return nil
    }
    return flag
}

private func token(_ value: JSONValue) -> DomainToken? {
    token(Optional(value))
}

private func token(_ value: JSONValue?) -> DomainToken? {
    string(value).flatMap(DomainToken.init(rawValue:))
}

private func unsigned(_ value: JSONValue?) -> UInt64? {
    guard case let .number(number)? = value, number >= 0 else {
        return nil
    }
    return UInt64(number)
}
