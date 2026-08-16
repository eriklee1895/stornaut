import Darwin
import Foundation

public struct LifecycleInvestigationID:
    RawRepresentable,
    Codable,
    Sendable,
    Hashable
{
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let identifier = UUID(uuidString: value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid lifecycle investigation identifier"
            )
        }
        rawValue = identifier
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue.uuidString.lowercased())
    }
}

public enum LifecycleSupervisorRequest:
    Codable,
    Sendable,
    Equatable
{
    case start(
        LifecycleInvestigationID,
        evidenceBindingSHA256: String
    )
    case cancel(LifecycleInvestigationID)

    private enum CodingKeys: String {
        case protocolVersion
        case type
        case investigationID
        case evidenceBindingSHA256
    }

    private enum RequestType: String, Codable {
        case start
        case cancel
    }

    public var investigationID: LifecycleInvestigationID {
        switch self {
        case let .start(investigationID, _),
             let .cancel(investigationID):
            investigationID
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(
            decoder: decoder,
            expectedKeys: Set([
                CodingKeys.protocolVersion.rawValue,
                CodingKeys.type.rawValue,
                CodingKeys.investigationID.rawValue,
                CodingKeys.evidenceBindingSHA256.rawValue,
            ])
        )
        guard
            try container.decode(
                Int.self,
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.protocolVersion.rawValue
                )
            ) == 2
        else {
            throw DecodingError.dataCorruptedError(
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.protocolVersion.rawValue
                ),
                in: container,
                debugDescription: "Unsupported lifecycle protocol version"
            )
        }
        let type = try container.decode(
            RequestType.self,
            forKey: AnyLifecycleCodingKey(CodingKeys.type.rawValue)
        )
        let investigationID = try container.decode(
            LifecycleInvestigationID.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.investigationID.rawValue
            )
        )
        let evidenceBindingSHA256 = try container.decodeIfPresent(
            String.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.evidenceBindingSHA256.rawValue
            )
        )
        switch type {
        case .start:
            guard
                let evidenceBindingSHA256,
                validLifecycleSHA256(evidenceBindingSHA256)
            else {
                throw DecodingError.dataCorruptedError(
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.evidenceBindingSHA256.rawValue
                    ),
                    in: container,
                    debugDescription:
                        "Invalid lifecycle evidence binding"
                )
            }
            self = .start(
                investigationID,
                evidenceBindingSHA256: evidenceBindingSHA256
            )
        case .cancel:
            guard evidenceBindingSHA256 == nil else {
                throw DecodingError.dataCorruptedError(
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.evidenceBindingSHA256.rawValue
                    ),
                    in: container,
                    debugDescription:
                        "Unexpected lifecycle evidence binding"
                )
            }
            self = .cancel(investigationID)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: AnyLifecycleCodingKey.self
        )
        try container.encode(
            2,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.protocolVersion.rawValue
            )
        )
        switch self {
        case let .start(investigationID, evidenceBindingSHA256):
            try container.encode(
                RequestType.start,
                forKey: AnyLifecycleCodingKey(CodingKeys.type.rawValue)
            )
            try container.encode(
                investigationID,
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.investigationID.rawValue
                )
            )
            try container.encode(
                evidenceBindingSHA256,
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.evidenceBindingSHA256.rawValue
                )
            )
        case let .cancel(investigationID):
            try container.encode(
                RequestType.cancel,
                forKey: AnyLifecycleCodingKey(CodingKeys.type.rawValue)
            )
            try container.encode(
                investigationID,
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.investigationID.rawValue
                )
            )
            try container.encodeNil(
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.evidenceBindingSHA256.rawValue
                )
            )
        }
    }
}

public struct LifecycleCallerIdentity: Sendable, Equatable {
    public let processID: pid_t
    public let effectiveUserID: uid_t
    public let signingIdentifier: String

    public init(
        processID: pid_t,
        effectiveUserID: uid_t,
        signingIdentifier: String
    ) {
        self.processID = processID
        self.effectiveUserID = effectiveUserID
        self.signingIdentifier = signingIdentifier
    }
}

public protocol LifecycleCallerAuthorizing: Sendable {
    func authorize(_ caller: LifecycleCallerIdentity) -> Bool
}

public enum LifecycleSupervisorOperation: Sendable, Equatable {
    case start(
        LifecycleInvestigationID,
        evidenceBindingSHA256: String,
        requestingUserID: uid_t
    )
    case cancel(
        LifecycleInvestigationID,
        requestingUserID: uid_t
    )
}

public enum LifecycleSupervisorResponse: Sendable, Equatable {
    case accepted
}

public protocol LifecycleOperationDispatching: Sendable {
    func dispatch(
        _ operation: LifecycleSupervisorOperation
    ) throws -> LifecycleSupervisorResponse
}

public enum LifecycleSupervisorContractError:
    Error,
    Sendable,
    Equatable
{
    case invalidCallerIdentity
    case unauthorizedCaller
}

public struct LifecycleSupervisorContract: Sendable {
    private let authorizer: any LifecycleCallerAuthorizing
    private let dispatcher: any LifecycleOperationDispatching

    public init(
        authorizer: any LifecycleCallerAuthorizing,
        dispatcher: any LifecycleOperationDispatching
    ) {
        self.authorizer = authorizer
        self.dispatcher = dispatcher
    }

    public func handle(
        _ request: LifecycleSupervisorRequest,
        caller: LifecycleCallerIdentity
    ) throws -> LifecycleSupervisorResponse {
        guard
            caller.processID > 1,
            caller.effectiveUserID > 0,
            !caller.signingIdentifier.isEmpty,
            caller.signingIdentifier.utf8.count <= 256,
            caller.signingIdentifier.unicodeScalars.allSatisfy({
                $0.value >= 0x20 && $0.value != 0x7F
            })
        else {
            throw LifecycleSupervisorContractError.invalidCallerIdentity
        }
        guard authorizer.authorize(caller) else {
            throw LifecycleSupervisorContractError.unauthorizedCaller
        }
        switch request {
        case let .start(investigationID, evidenceBindingSHA256):
            return try dispatcher.dispatch(
                .start(
                    investigationID,
                    evidenceBindingSHA256:
                        evidenceBindingSHA256,
                    requestingUserID: caller.effectiveUserID
                )
            )
        case let .cancel(investigationID):
            return try dispatcher.dispatch(
                .cancel(
                    investigationID,
                    requestingUserID: caller.effectiveUserID
                )
            )
        }
    }
}

private func validLifecycleSHA256(_ value: String) -> Bool {
    value.count == 64
        && value.unicodeScalars.allSatisfy {
            (0x30...0x39).contains($0.value)
                || (0x61...0x66).contains($0.value)
        }
}

struct AnyLifecycleCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int? = nil

    init(_ value: String) {
        stringValue = value
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

func strictContainer(
    decoder: Decoder,
    expectedKeys: Set<String>
) throws -> KeyedDecodingContainer<AnyLifecycleCodingKey> {
    let container = try decoder.container(
        keyedBy: AnyLifecycleCodingKey.self
    )
    let observedKeys = Set(container.allKeys.map(\.stringValue))
    guard observedKeys == expectedKeys else {
        let key = AnyLifecycleCodingKey(
            observedKeys.subtracting(expectedKeys).sorted().first
                ?? "missing"
        )
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: container,
            debugDescription: "Unexpected lifecycle contract fields"
        )
    }
    return container
}
