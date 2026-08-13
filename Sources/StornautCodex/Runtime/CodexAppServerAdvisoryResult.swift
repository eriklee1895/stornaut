import Foundation

enum CodexAppServerAdvisoryResultError: Error, Sendable, Equatable {
    case missingFinalMessage
    case invalidEnvelope
    case schemaUnavailable
}

struct CodexAppServerAdvisoryResultDecoder: Sendable {
    func decode(
        _ result: CodexAppServerSessionResult,
        context: InvestigationProtocolContext
    ) throws -> InvestigationAdvisoryReport {
        guard let finalMessage = result.observation.finalAgentMessage else {
            throw CodexAppServerAdvisoryResultError.missingFinalMessage
        }
        let envelope: InvestigationEnvelopeV2
        do {
            envelope = try InvestigationEnvelopeV2.decodeValidated(
                from: Data(finalMessage.utf8),
                context: context
            )
        } catch {
            throw CodexAppServerAdvisoryResultError.invalidEnvelope
        }
        return InvestigationAdvisoryNormalizer().normalize(envelope)
    }
}

enum InvestigationEnvelopeV2Schema {
    static func loadJSONValue(
        bundle: Bundle = .module
    ) throws -> JSONValue {
        guard
            let url = bundle.url(
                forResource: "investigation-envelope-v2.schema",
                withExtension: "json",
                subdirectory: "Schemas"
            ),
            let data = try? Data(contentsOf: url),
            let value = try? JSONDecoder().decode(
                JSONValue.self,
                from: data
            )
        else {
            throw CodexAppServerAdvisoryResultError.schemaUnavailable
        }
        return value
    }

    static func loadStructuredOutputJSONValue(
        bundle: Bundle = .module
    ) throws -> JSONValue {
        try structuredOutputProjection(
            loadJSONValue(bundle: bundle),
            isRoot: true
        )
    }

    private static func structuredOutputProjection(
        _ value: JSONValue,
        isRoot: Bool = false
    ) throws -> JSONValue {
        switch value {
        case let .object(object):
            var projected: [String: JSONValue] = [:]
            for (key, child) in object {
                if isRoot, key == "$schema" || key == "title" {
                    continue
                }
                switch key {
                case "maxItems", "maxLength", "minItems",
                     "minLength", "pattern", "uniqueItems":
                    continue
                case "const":
                    projected["enum"] = .array([
                        try structuredOutputProjection(child),
                    ])
                default:
                    projected[key] = try structuredOutputProjection(
                        child
                    )
                }
            }
            return .object(projected)
        case let .array(array):
            return .array(
                try array.map {
                    try structuredOutputProjection($0)
                }
            )
        case .string, .number, .bool, .null:
            return value
        }
    }
}
