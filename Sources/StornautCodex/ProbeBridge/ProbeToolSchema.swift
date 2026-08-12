import Foundation
import StornautCodex
import StornautCore

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
