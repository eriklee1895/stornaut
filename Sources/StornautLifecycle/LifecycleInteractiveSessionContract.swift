import Foundation

public enum LifecycleInteractiveSessionContractError:
    Error,
    Sendable,
    Equatable
{
    case invalidRequest
    case invalidResponse
    case identityMismatch
}

public enum LifecycleInteractiveSessionRequestKind:
    String,
    Codable,
    Sendable
{
    case start
    case write
    case read
    case retire
}

public struct LifecycleInteractiveSessionRequest:
    Codable,
    Sendable,
    Equatable
{
    public static let protocolVersion = 1
    public static let maximumAllowedLineBytes = 2 * 1_024 * 1_024
    public static let maximumAllowedSessionBytes = 16 * 1_024 * 1_024
    public static let maximumEncodedEnvelopeBytes = 3 * 1_024 * 1_024

    public let kind: LifecycleInteractiveSessionRequestKind
    public let investigationID: LifecycleInvestigationID
    public let operationID: UUID
    public let validBefore: Date?
    public let maximumLineBytes: Int?
    public let maximumSessionBytes: Int?
    public let line: Data?

    private init(
        kind: LifecycleInteractiveSessionRequestKind,
        investigationID: LifecycleInvestigationID,
        operationID: UUID,
        validBefore: Date?,
        maximumLineBytes: Int?,
        maximumSessionBytes: Int?,
        line: Data?
    ) {
        self.kind = kind
        self.investigationID = investigationID
        self.operationID = operationID
        self.validBefore = validBefore
        self.maximumLineBytes = maximumLineBytes
        self.maximumSessionBytes = maximumSessionBytes
        self.line = line
    }

    public static func start(
        investigationID: LifecycleInvestigationID,
        operationID: UUID,
        validBefore: Date,
        maximumLineBytes: Int,
        maximumSessionBytes: Int
    ) throws -> Self {
        let request = Self(
            kind: .start,
            investigationID: investigationID,
            operationID: operationID,
            validBefore: validBefore,
            maximumLineBytes: maximumLineBytes,
            maximumSessionBytes: maximumSessionBytes,
            line: nil
        )
        guard request.isValid else {
            throw LifecycleInteractiveSessionContractError.invalidRequest
        }
        return request
    }

    public static func write(
        investigationID: LifecycleInvestigationID,
        operationID: UUID,
        line: Data
    ) throws -> Self {
        let request = Self(
            kind: .write,
            investigationID: investigationID,
            operationID: operationID,
            validBefore: nil,
            maximumLineBytes: nil,
            maximumSessionBytes: nil,
            line: line
        )
        guard request.isValid else {
            throw LifecycleInteractiveSessionContractError.invalidRequest
        }
        return request
    }

    public static func read(
        investigationID: LifecycleInvestigationID,
        operationID: UUID
    ) -> Self {
        Self(
            kind: .read,
            investigationID: investigationID,
            operationID: operationID,
            validBefore: nil,
            maximumLineBytes: nil,
            maximumSessionBytes: nil,
            line: nil
        )
    }

    public static func retire(
        investigationID: LifecycleInvestigationID,
        operationID: UUID
    ) -> Self {
        Self(
            kind: .retire,
            investigationID: investigationID,
            operationID: operationID,
            validBefore: nil,
            maximumLineBytes: nil,
            maximumSessionBytes: nil,
            line: nil
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(
            decoder: decoder,
            expectedKeys: Set(
                CodingKeys.allCases.map(\.rawValue)
            )
        )
        guard
            try container.decode(
                Int.self,
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.protocolVersion.rawValue
                )
            ) == Self.protocolVersion
        else {
            throw DecodingError.dataCorruptedError(
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.protocolVersion.rawValue
                ),
                in: container,
                debugDescription:
                    "Unsupported interactive session protocol"
            )
        }
        kind = try container.decode(
            LifecycleInteractiveSessionRequestKind.self,
            forKey: AnyLifecycleCodingKey(CodingKeys.kind.rawValue)
        )
        investigationID = try container.decode(
            LifecycleInvestigationID.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.investigationID.rawValue
            )
        )
        operationID = try container.decode(
            UUID.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.operationID.rawValue
            )
        )
        validBefore = try container.decodeIfPresent(
            Date.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.validBefore.rawValue
            )
        )
        maximumLineBytes = try container.decodeIfPresent(
            Int.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.maximumLineBytes.rawValue
            )
        )
        maximumSessionBytes = try container.decodeIfPresent(
            Int.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.maximumSessionBytes.rawValue
            )
        )
        line = try container.decodeIfPresent(
            Data.self,
            forKey: AnyLifecycleCodingKey(CodingKeys.line.rawValue)
        )
        guard isValid else {
            throw DecodingError.dataCorruptedError(
                forKey: AnyLifecycleCodingKey(CodingKeys.kind.rawValue),
                in: container,
                debugDescription: "Invalid interactive session request"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        guard isValid else {
            throw LifecycleInteractiveSessionContractError.invalidRequest
        }
        var container = encoder.container(
            keyedBy: AnyLifecycleCodingKey.self
        )
        try container.encode(
            Self.protocolVersion,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.protocolVersion.rawValue
            )
        )
        try container.encode(
            kind,
            forKey: AnyLifecycleCodingKey(CodingKeys.kind.rawValue)
        )
        try container.encode(
            investigationID,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.investigationID.rawValue
            )
        )
        try container.encode(
            operationID,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.operationID.rawValue
            )
        )
        try container.encode(
            validBefore,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.validBefore.rawValue
            )
        )
        try container.encode(
            maximumLineBytes,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.maximumLineBytes.rawValue
            )
        )
        try container.encode(
            maximumSessionBytes,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.maximumSessionBytes.rawValue
            )
        )
        try container.encode(
            line,
            forKey: AnyLifecycleCodingKey(CodingKeys.line.rawValue)
        )
    }

    fileprivate var isValid: Bool {
        switch kind {
        case .start:
            guard
                line == nil,
                let validBefore,
                validBefore.timeIntervalSince1970.isFinite,
                let maximumLineBytes,
                (1...Self.maximumAllowedLineBytes).contains(
                    maximumLineBytes
                ),
                let maximumSessionBytes,
                (maximumLineBytes...Self.maximumAllowedSessionBytes)
                    .contains(maximumSessionBytes)
            else {
                return false
            }
            return true
        case .write:
            return validBefore == nil
                && maximumLineBytes == nil
                && maximumSessionBytes == nil
                && line.map(validLine) == true
        case .read, .retire:
            return validBefore == nil
                && maximumLineBytes == nil
                && maximumSessionBytes == nil
                && line == nil
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case protocolVersion
        case kind
        case investigationID
        case operationID
        case validBefore
        case maximumLineBytes
        case maximumSessionBytes
        case line
    }
}

public enum LifecycleInteractiveSessionResponseKind:
    String,
    Codable,
    Sendable
{
    case started
    case writeAccepted
    case line
    case endOfStream
    case retired
}

public struct LifecycleInteractiveSessionResponse:
    Codable,
    Sendable,
    Equatable
{
    public static let protocolVersion = 1

    public let kind: LifecycleInteractiveSessionResponseKind
    public let investigationID: LifecycleInvestigationID
    public let operationID: UUID
    public let line: Data?
    public let drained: Bool?

    private init(
        kind: LifecycleInteractiveSessionResponseKind,
        investigationID: LifecycleInvestigationID,
        operationID: UUID,
        line: Data?,
        drained: Bool?
    ) {
        self.kind = kind
        self.investigationID = investigationID
        self.operationID = operationID
        self.line = line
        self.drained = drained
    }

    public static func started(
        investigationID: LifecycleInvestigationID,
        operationID: UUID
    ) -> Self {
        Self(
            kind: .started,
            investigationID: investigationID,
            operationID: operationID,
            line: nil,
            drained: nil
        )
    }

    public static func writeAccepted(
        investigationID: LifecycleInvestigationID,
        operationID: UUID
    ) -> Self {
        Self(
            kind: .writeAccepted,
            investigationID: investigationID,
            operationID: operationID,
            line: nil,
            drained: nil
        )
    }

    public static func line(
        investigationID: LifecycleInvestigationID,
        operationID: UUID,
        line: Data
    ) throws -> Self {
        let response = Self(
            kind: .line,
            investigationID: investigationID,
            operationID: operationID,
            line: line,
            drained: nil
        )
        guard response.isValid else {
            throw LifecycleInteractiveSessionContractError.invalidResponse
        }
        return response
    }

    public static func endOfStream(
        investigationID: LifecycleInvestigationID,
        operationID: UUID
    ) -> Self {
        Self(
            kind: .endOfStream,
            investigationID: investigationID,
            operationID: operationID,
            line: nil,
            drained: nil
        )
    }

    public static func retired(
        investigationID: LifecycleInvestigationID,
        operationID: UUID,
        drained: Bool
    ) -> Self {
        Self(
            kind: .retired,
            investigationID: investigationID,
            operationID: operationID,
            line: nil,
            drained: drained
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(
            decoder: decoder,
            expectedKeys: Set(
                CodingKeys.allCases.map(\.rawValue)
            )
        )
        guard
            try container.decode(
                Int.self,
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.protocolVersion.rawValue
                )
            ) == Self.protocolVersion
        else {
            throw DecodingError.dataCorruptedError(
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.protocolVersion.rawValue
                ),
                in: container,
                debugDescription:
                    "Unsupported interactive session protocol"
            )
        }
        kind = try container.decode(
            LifecycleInteractiveSessionResponseKind.self,
            forKey: AnyLifecycleCodingKey(CodingKeys.kind.rawValue)
        )
        investigationID = try container.decode(
            LifecycleInvestigationID.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.investigationID.rawValue
            )
        )
        operationID = try container.decode(
            UUID.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.operationID.rawValue
            )
        )
        line = try container.decodeIfPresent(
            Data.self,
            forKey: AnyLifecycleCodingKey(CodingKeys.line.rawValue)
        )
        drained = try container.decodeIfPresent(
            Bool.self,
            forKey: AnyLifecycleCodingKey(CodingKeys.drained.rawValue)
        )
        guard isValid else {
            throw DecodingError.dataCorruptedError(
                forKey: AnyLifecycleCodingKey(CodingKeys.kind.rawValue),
                in: container,
                debugDescription: "Invalid interactive session response"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        guard isValid else {
            throw LifecycleInteractiveSessionContractError.invalidResponse
        }
        var container = encoder.container(
            keyedBy: AnyLifecycleCodingKey.self
        )
        try container.encode(
            Self.protocolVersion,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.protocolVersion.rawValue
            )
        )
        try container.encode(
            kind,
            forKey: AnyLifecycleCodingKey(CodingKeys.kind.rawValue)
        )
        try container.encode(
            investigationID,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.investigationID.rawValue
            )
        )
        try container.encode(
            operationID,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.operationID.rawValue
            )
        )
        try container.encode(
            line,
            forKey: AnyLifecycleCodingKey(CodingKeys.line.rawValue)
        )
        try container.encode(
            drained,
            forKey: AnyLifecycleCodingKey(CodingKeys.drained.rawValue)
        )
    }

    public func validated(
        for request: LifecycleInteractiveSessionRequest
    ) throws -> Self {
        guard
            investigationID == request.investigationID,
            operationID == request.operationID,
            responseKindMatches(request.kind)
        else {
            throw LifecycleInteractiveSessionContractError
                .identityMismatch
        }
        return self
    }

    private var isValid: Bool {
        switch kind {
        case .started, .writeAccepted, .endOfStream:
            return line == nil && drained == nil
        case .line:
            return line.map(validLine) == true && drained == nil
        case .retired:
            return line == nil && drained != nil
        }
    }

    private func responseKindMatches(
        _ request: LifecycleInteractiveSessionRequestKind
    ) -> Bool {
        switch (request, kind) {
        case (.start, .started),
             (.write, .writeAccepted),
             (.read, .line),
             (.read, .endOfStream),
             (.retire, .retired):
            true
        default:
            false
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case protocolVersion
        case kind
        case investigationID
        case operationID
        case line
        case drained
    }
}

private func validLine(_ data: Data) -> Bool {
    (2...LifecycleInteractiveSessionRequest.maximumAllowedLineBytes)
        .contains(data.count)
        && data.last == 0x0A
        && !data.dropLast().contains(0x00)
}
