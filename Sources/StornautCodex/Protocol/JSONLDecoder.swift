import Foundation

public enum JSONLDecoderError: Error, Sendable, Equatable {
    case invalidLimit
    case lineByteLimitExceeded(limit: Int)
    case sessionByteLimitExceeded(limit: Int)
    case malformedJSON(lineNumber: Int)
    case invalidEvent(lineNumber: Int)
    case truncatedFinalLine
}

public struct JSONLDecoder: Sendable {
    private let lineByteLimit: Int
    private let sessionByteLimit: Int
    private let unknownMetadataByteLimit: Int
    private var buffer = Data()
    private var receivedByteCount = 0
    private var lineNumber = 0
    private var failed = false

    public init(
        lineByteLimit: Int,
        sessionByteLimit: Int,
        unknownMetadataByteLimit: Int
    ) {
        self.lineByteLimit = lineByteLimit
        self.sessionByteLimit = sessionByteLimit
        self.unknownMetadataByteLimit = unknownMetadataByteLimit
    }

    public mutating func append(_ data: Data) throws -> [CodexEvent] {
        guard
            !failed,
            lineByteLimit > 0,
            sessionByteLimit > 0,
            unknownMetadataByteLimit >= 0
        else {
            throw JSONLDecoderError.invalidLimit
        }

        let nextSessionByteCount = receivedByteCount.addingReportingOverflow(data.count)
        guard
            !nextSessionByteCount.overflow,
            nextSessionByteCount.partialValue <= sessionByteLimit
        else {
            failed = true
            throw JSONLDecoderError.sessionByteLimitExceeded(limit: sessionByteLimit)
        }
        receivedByteCount = nextSessionByteCount.partialValue
        buffer.append(data)

        var events: [CodexEvent] = []
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let line = buffer[..<newlineIndex]
            buffer.removeSubrange(...newlineIndex)
            lineNumber += 1

            guard line.count <= lineByteLimit else {
                failed = true
                throw JSONLDecoderError.lineByteLimitExceeded(limit: lineByteLimit)
            }
            if line.isEmpty {
                continue
            }

            do {
                events.append(try decodeLine(Data(line), lineNumber: lineNumber))
            } catch {
                failed = true
                throw error
            }
        }

        guard buffer.count <= lineByteLimit else {
            failed = true
            throw JSONLDecoderError.lineByteLimitExceeded(limit: lineByteLimit)
        }
        return events
    }

    public mutating func finish() throws -> [CodexEvent] {
        guard !failed else {
            throw JSONLDecoderError.invalidLimit
        }
        guard buffer.isEmpty else {
            failed = true
            throw JSONLDecoderError.truncatedFinalLine
        }
        return []
    }

    private func decodeLine(_ line: Data, lineNumber: Int) throws -> CodexEvent {
        let object: [String: Any]
        do {
            guard let decoded = try JSONSerialization.jsonObject(with: line) as? [String: Any] else {
                throw JSONLDecoderError.invalidEvent(lineNumber: lineNumber)
            }
            object = decoded
        } catch let error as JSONLDecoderError {
            throw error
        } catch {
            throw JSONLDecoderError.malformedJSON(lineNumber: lineNumber)
        }

        guard let type = object["type"] as? String, !type.isEmpty else {
            throw JSONLDecoderError.invalidEvent(lineNumber: lineNumber)
        }

        switch type {
        case "thread.started":
            guard object["thread_id"] is String else {
                throw JSONLDecoderError.invalidEvent(lineNumber: lineNumber)
            }
            return .threadStarted
        case "turn.started":
            return .turnStarted
        case "turn.completed":
            guard let usage = decodeUsage(object["usage"]) else {
                throw JSONLDecoderError.invalidEvent(lineNumber: lineNumber)
            }
            return .turnCompleted(usage)
        case "turn.failed":
            return .turnFailed
        case "item.started":
            guard let item = decodeItem(object["item"]) else {
                throw JSONLDecoderError.invalidEvent(lineNumber: lineNumber)
            }
            return .itemStarted(item)
        case "item.completed":
            guard let item = decodeItem(object["item"]) else {
                throw JSONLDecoderError.invalidEvent(lineNumber: lineNumber)
            }
            return .itemCompleted(item)
        case "error":
            return .error
        default:
            guard type.utf8.count <= unknownMetadataByteLimit else {
                throw JSONLDecoderError.invalidEvent(lineNumber: lineNumber)
            }
            return .unknown(
                UnknownCodexEvent(
                    type: type,
                    metadata: boundedMetadata(
                        from: object,
                        excluding: "type",
                        initialByteCount: type.utf8.count
                    )
                )
            )
        }
    }

    private func decodeUsage(_ value: Any?) -> CodexUsage? {
        guard let usage = value as? [String: Any] else {
            return nil
        }
        guard
            let inputTokens = integer(usage["input_tokens"]),
            let cachedInputTokens = integer(usage["cached_input_tokens"]),
            let outputTokens = integer(usage["output_tokens"]),
            let reasoningOutputTokens = integer(usage["reasoning_output_tokens"])
        else {
            return nil
        }
        let cacheWriteInputTokens = integer(usage["cache_write_input_tokens"]) ?? 0
        return CodexUsage(
            inputTokens: inputTokens,
            cachedInputTokens: cachedInputTokens,
            cacheWriteInputTokens: cacheWriteInputTokens,
            outputTokens: outputTokens,
            reasoningOutputTokens: reasoningOutputTokens
        )
    }

    private func decodeItem(_ value: Any?) -> CodexItem? {
        guard
            let item = value as? [String: Any],
            let id = item["id"] as? String,
            let type = item["type"] as? String
        else {
            return nil
        }
        let text = type == "agent_message" ? item["text"] as? String : nil
        return CodexItem(id: id, type: type, agentMessageText: text)
    }

    private func boundedMetadata(
        from object: [String: Any],
        excluding excludedKey: String,
        initialByteCount: Int
    ) -> [String: String] {
        let allowedKeys: Set<String> = [
            "enabled",
            "kind",
            "phase",
            "sequence",
            "status",
        ]
        var metadata: [String: String] = [:]
        var usedBytes = initialByteCount

        for key in object.keys.sorted()
        where key != excludedKey && allowedKeys.contains(key) {
            guard let value = scalarString(object[key]) else {
                continue
            }
            let bytes = key.utf8.count + value.utf8.count
            guard usedBytes + bytes <= unknownMetadataByteLimit else {
                continue
            }
            metadata[key] = value
            usedBytes += bytes
        }
        return metadata
    }

    private func scalarString(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            value
        case let value as Bool:
            value ? "true" : "false"
        case let value as NSNumber:
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                value.boolValue ? "true" : "false"
            } else {
                value.stringValue
            }
        default:
            nil
        }
    }

    private func integer(_ value: Any?) -> Int64? {
        guard let number = value as? NSNumber else {
            return nil
        }
        let doubleValue = number.doubleValue
        guard
            doubleValue.isFinite,
            doubleValue.rounded(.towardZero) == doubleValue,
            doubleValue >= Double(Int64.min),
            doubleValue <= Double(Int64.max)
        else {
            return nil
        }
        return number.int64Value
    }
}
