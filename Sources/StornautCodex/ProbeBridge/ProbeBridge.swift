import Foundation
import StornautCodex
import StornautCore

public struct ProbeBridgeRequest: Codable, Sendable, Equatable {
    public let id: String
    public let tool: String
    public let arguments: [String: JSONValue]

    public init(
        id: String,
        tool: String,
        arguments: [String: JSONValue]
    ) {
        self.id = id
        self.tool = tool
        self.arguments = arguments
    }
}

public enum ProbeBridgeError: String, Codable, Sendable, Equatable {
    case malformedRequest
    case requestTooLarge
    case responseTooLarge
    case toolNotAllowed
    case invalidArguments
}

public struct ProbeBridgeResponse: Codable, Sendable, Equatable {
    public let id: String?
    public let result: ProbeResult?
    public let error: ProbeBridgeError?

    public init(
        id: String?,
        result: ProbeResult? = nil,
        error: ProbeBridgeError? = nil
    ) {
        self.id = id
        self.result = result
        self.error = error
    }

    public static func decode(from data: Data) throws -> ProbeBridgeResponse {
        try JSONDecoder().decode(Self.self, from: data)
    }
}

public struct ProbeBridge: Sendable {
    private let broker: ProbeBroker
    private let context: ProbeContext
    private let requestByteLimit: Int
    private let responseByteLimit: Int

    public init(
        broker: ProbeBroker,
        context: ProbeContext,
        requestByteLimit: Int = 16 * 1_024,
        responseByteLimit: Int = 64 * 1_024
    ) {
        self.broker = broker
        self.context = context
        self.requestByteLimit = max(1, requestByteLimit)
        self.responseByteLimit = max(128, responseByteLimit)
    }

    public func handle(_ data: Data) async -> Data {
        guard data.count <= requestByteLimit else {
            return encodeFallback(
                ProbeBridgeResponse(id: nil, error: .requestTooLarge)
            )
        }
        let request: ProbeBridgeRequest
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard let dictionary = object as? [String: Any],
                  Set(dictionary.keys) == ["id", "tool", "arguments"]
            else {
                throw ProbeBridgeDecodingError.invalidEnvelope
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            request = try decoder.decode(ProbeBridgeRequest.self, from: data)
        } catch {
            return encodeFallback(
                ProbeBridgeResponse(id: nil, error: .malformedRequest)
            )
        }
        guard let capability = ProbeToolSchema.capabilityByName[request.tool] else {
            return boundedResponse(
                ProbeBridgeResponse(id: request.id, error: .toolNotAllowed)
            )
        }
        guard let probeRequest = makeProbeRequest(
            capability: capability,
            arguments: request.arguments
        ) else {
            return boundedResponse(
                ProbeBridgeResponse(id: request.id, error: .invalidArguments)
            )
        }

        let result = await broker.execute(probeRequest, in: context)
        return boundedResponse(
            ProbeBridgeResponse(id: request.id, result: result)
        )
    }

    private func boundedResponse(_ response: ProbeBridgeResponse) -> Data {
        let data = encodeFallback(response)
        guard data.count <= responseByteLimit else {
            return encodeFallback(
                ProbeBridgeResponse(id: nil, error: .responseTooLarge)
            )
        }
        return data
    }

    private func encodeFallback(_ response: ProbeBridgeResponse) -> Data {
        (try? JSONEncoder().encode(response))
            ?? Data(#"{"id":null,"result":null,"error":"malformedRequest"}"#.utf8)
    }
}

private enum ProbeBridgeDecodingError: Error {
    case invalidEnvelope
}

private func makeProbeRequest(
    capability: ProbeCapability,
    arguments: [String: JSONValue]
) -> ProbeRequest? {
    let allowedKeys: Set<String>
    switch capability {
    case .diskSnapshot:
        allowedKeys = ["targetPath"]
    case .directorySummary, .largestChildren:
        allowedKeys = ["targetPath", "limit"]
    case .safeTextSnippet:
        allowedKeys = ["targetPath", "byteLimit"]
    }
    guard Set(arguments.keys).isSubset(of: allowedKeys),
          case let .string(path)? = arguments["targetPath"],
          path.hasPrefix("/")
    else {
        return nil
    }

    let limit: Int?
    if let value = arguments["limit"] {
        guard case let .number(number) = value else {
            return nil
        }
        limit = number
    } else {
        limit = nil
    }
    let byteLimit: Int?
    if let value = arguments["byteLimit"] {
        guard case let .number(number) = value else {
            return nil
        }
        byteLimit = number
    } else {
        byteLimit = nil
    }

    return ProbeRequest(
        capability: capability,
        targetURL: URL(filePath: path),
        limit: limit,
        byteLimit: byteLimit
    )
}
