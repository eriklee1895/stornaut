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
}
