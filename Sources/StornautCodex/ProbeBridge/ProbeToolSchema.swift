import Foundation
import StornautCore

public enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Int)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported JSON value"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

public struct ProbeToolDefinition: Codable, Sendable, Equatable {
    public let name: String
    public let capability: ProbeCapability
    public let description: String
    public let inputSchema: [String: JSONValue]
    public let isReadOnly: Bool
}

public enum ProbeToolSchema {
    public static let definitions: [ProbeToolDefinition] = [
        definition(
            name: "stornaut.diskSnapshot",
            capability: .diskSnapshot,
            optionalProperties: [:]
        ),
        definition(
            name: "stornaut.directorySummary",
            capability: .directorySummary,
            optionalProperties: ["limit": .object(["type": .string("integer")])]
        ),
        definition(
            name: "stornaut.largestChildren",
            capability: .largestChildren,
            optionalProperties: ["limit": .object(["type": .string("integer")])]
        ),
        definition(
            name: "stornaut.safeTextSnippet",
            capability: .safeTextSnippet,
            optionalProperties: [
                "byteLimit": .object(["type": .string("integer")]),
            ]
        ),
    ]

    static let capabilityByName = Dictionary(
        uniqueKeysWithValues: definitions.map { ($0.name, $0.capability) }
    )

    private static func definition(
        name: String,
        capability: ProbeCapability,
        optionalProperties: [String: JSONValue]
    ) -> ProbeToolDefinition {
        var properties = optionalProperties
        properties["targetPath"] = .object(["type": .string("string")])
        return ProbeToolDefinition(
            name: name,
            capability: capability,
            description: "Bounded Stornaut read-only probe.",
            inputSchema: [
                "type": .string("object"),
                "properties": .object(properties),
                "required": .array([.string("targetPath")]),
                "additionalProperties": .bool(false),
            ],
            isReadOnly: true
        )
    }
}
