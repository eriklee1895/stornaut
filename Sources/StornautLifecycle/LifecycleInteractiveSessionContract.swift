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

public struct LifecycleInvestigationResidueObservation:
    Codable,
    Sendable,
    Equatable
{
    public static let protocolVersion = 1
    public static let maximumCount = 4_096

    public let investigationID: LifecycleInvestigationID
    public let auditSessionID: Int32
    public let userID: UInt32
    public let observedAt: Date
    public let remainingAuditSessionMemberCount: Int
    public let matchingLeaseCount: Int
    public let leaseRootEntryCount: Int
    public let investigationArtifactCount: Int

    public var provedEmpty: Bool {
        remainingAuditSessionMemberCount == 0
            && matchingLeaseCount == 0
            && leaseRootEntryCount == 0
            && investigationArtifactCount == 0
    }

    public init(
        investigationID: LifecycleInvestigationID,
        auditSessionID: Int32,
        userID: UInt32,
        observedAt: Date,
        remainingAuditSessionMemberCount: Int,
        matchingLeaseCount: Int,
        leaseRootEntryCount: Int,
        investigationArtifactCount: Int
    ) throws {
        guard
            auditSessionID > 0,
            userID > 0,
            observedAt.timeIntervalSince1970.isFinite,
            Self.validCount(remainingAuditSessionMemberCount),
            (0...1).contains(matchingLeaseCount),
            Self.validCount(leaseRootEntryCount),
            (0...1).contains(investigationArtifactCount),
            matchingLeaseCount <= leaseRootEntryCount
        else {
            throw LifecycleInteractiveSessionContractError
                .invalidResponse
        }
        self.investigationID = investigationID
        self.auditSessionID = auditSessionID
        self.userID = userID
        self.observedAt = observedAt
        self.remainingAuditSessionMemberCount =
            remainingAuditSessionMemberCount
        self.matchingLeaseCount = matchingLeaseCount
        self.leaseRootEntryCount = leaseRootEntryCount
        self.investigationArtifactCount = investigationArtifactCount
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(
            decoder: decoder,
            expectedKeys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        guard try container.decode(
            Int.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.protocolVersion.rawValue
            )
        ) == Self.protocolVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.protocolVersion.rawValue
                ),
                in: container,
                debugDescription: "Unsupported residue observation"
            )
        }
        do {
            try self.init(
                investigationID: container.decode(
                    LifecycleInvestigationID.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.investigationID.rawValue
                    )
                ),
                auditSessionID: container.decode(
                    Int32.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.auditSessionID.rawValue
                    )
                ),
                userID: container.decode(
                    UInt32.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.userID.rawValue
                    )
                ),
                observedAt: container.decode(
                    Date.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.observedAt.rawValue
                    )
                ),
                remainingAuditSessionMemberCount: container.decode(
                    Int.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.remainingAuditSessionMemberCount
                            .rawValue
                    )
                ),
                matchingLeaseCount: container.decode(
                    Int.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.matchingLeaseCount.rawValue
                    )
                ),
                leaseRootEntryCount: container.decode(
                    Int.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.leaseRootEntryCount.rawValue
                    )
                ),
                investigationArtifactCount: container.decode(
                    Int.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.investigationArtifactCount.rawValue
                    )
                )
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.investigationID.rawValue
                ),
                in: container,
                debugDescription: "Invalid residue observation"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        guard
            (try? Self(
                investigationID: investigationID,
                auditSessionID: auditSessionID,
                userID: userID,
                observedAt: observedAt,
                remainingAuditSessionMemberCount:
                    remainingAuditSessionMemberCount,
                matchingLeaseCount: matchingLeaseCount,
                leaseRootEntryCount: leaseRootEntryCount,
                investigationArtifactCount: investigationArtifactCount
            )) != nil
        else {
            throw LifecycleInteractiveSessionContractError
                .invalidResponse
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
            investigationID,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.investigationID.rawValue
            )
        )
        try container.encode(
            auditSessionID,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.auditSessionID.rawValue
            )
        )
        try container.encode(
            userID,
            forKey: AnyLifecycleCodingKey(CodingKeys.userID.rawValue)
        )
        try container.encode(
            observedAt,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.observedAt.rawValue
            )
        )
        try container.encode(
            remainingAuditSessionMemberCount,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.remainingAuditSessionMemberCount.rawValue
            )
        )
        try container.encode(
            matchingLeaseCount,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.matchingLeaseCount.rawValue
            )
        )
        try container.encode(
            leaseRootEntryCount,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.leaseRootEntryCount.rawValue
            )
        )
        try container.encode(
            investigationArtifactCount,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.investigationArtifactCount.rawValue
            )
        )
    }

    private static func validCount(_ value: Int) -> Bool {
        (0...maximumCount).contains(value)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case protocolVersion
        case investigationID
        case auditSessionID
        case userID
        case observedAt
        case remainingAuditSessionMemberCount
        case matchingLeaseCount
        case leaseRootEntryCount
        case investigationArtifactCount
    }
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
    public static let protocolVersion = 2
    public static let maximumAllowedLineBytes = 2 * 1_024 * 1_024
    public static let maximumAllowedSessionBytes = 16 * 1_024 * 1_024
    public static let maximumEncodedEnvelopeBytes = 3 * 1_024 * 1_024

    public let kind: LifecycleInteractiveSessionRequestKind
    public let investigationID: LifecycleInvestigationID
    public let operationID: UUID
    public let configurationSHA256: String
    public let validBefore: Date?
    public let maximumLineBytes: Int?
    public let maximumSessionBytes: Int?
    public let line: Data?

    private init(
        kind: LifecycleInteractiveSessionRequestKind,
        investigationID: LifecycleInvestigationID,
        operationID: UUID,
        configurationSHA256: String,
        validBefore: Date?,
        maximumLineBytes: Int?,
        maximumSessionBytes: Int?,
        line: Data?
    ) {
        self.kind = kind
        self.investigationID = investigationID
        self.operationID = operationID
        self.configurationSHA256 = configurationSHA256
        self.validBefore = validBefore
        self.maximumLineBytes = maximumLineBytes
        self.maximumSessionBytes = maximumSessionBytes
        self.line = line
    }

    public static func start(
        investigationID: LifecycleInvestigationID,
        operationID: UUID,
        configurationSHA256: String,
        validBefore: Date,
        maximumLineBytes: Int,
        maximumSessionBytes: Int
    ) throws -> Self {
        let request = Self(
            kind: .start,
            investigationID: investigationID,
            operationID: operationID,
            configurationSHA256: configurationSHA256,
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
        configurationSHA256: String,
        line: Data
    ) throws -> Self {
        let request = Self(
            kind: .write,
            investigationID: investigationID,
            operationID: operationID,
            configurationSHA256: configurationSHA256,
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
        operationID: UUID,
        configurationSHA256: String
    ) throws -> Self {
        let request = Self(
            kind: .read,
            investigationID: investigationID,
            operationID: operationID,
            configurationSHA256: configurationSHA256,
            validBefore: nil,
            maximumLineBytes: nil,
            maximumSessionBytes: nil,
            line: nil
        )
        guard request.isValid else {
            throw LifecycleInteractiveSessionContractError.invalidRequest
        }
        return request
    }

    public static func retire(
        investigationID: LifecycleInvestigationID,
        operationID: UUID,
        configurationSHA256: String
    ) throws -> Self {
        let request = Self(
            kind: .retire,
            investigationID: investigationID,
            operationID: operationID,
            configurationSHA256: configurationSHA256,
            validBefore: nil,
            maximumLineBytes: nil,
            maximumSessionBytes: nil,
            line: nil
        )
        guard request.isValid else {
            throw LifecycleInteractiveSessionContractError.invalidRequest
        }
        return request
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
        configurationSHA256 = try container.decode(
            String.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.configurationSHA256.rawValue
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
            configurationSHA256,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.configurationSHA256.rawValue
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
        guard validInteractiveSHA256(configurationSHA256) else {
            return false
        }
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
        case configurationSHA256
        case validBefore
        case maximumLineBytes
        case maximumSessionBytes
        case line
    }
}

private func validInteractiveSHA256(_ value: String) -> Bool {
    value.count == 64
        && value.unicodeScalars.allSatisfy {
            (0x30...0x39).contains($0.value)
                || (0x61...0x66).contains($0.value)
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

public struct LifecycleInteractiveWorkerRetirementObservation:
    Codable,
    Sendable,
    Equatable
{
    public enum ResourceOwnership: String, Codable, Sendable {
        case none
        case preparedWorkspace
        case owned
    }

    public let resourceOwnership: ResourceOwnership
    public let processGroupTerminated: Bool
    public let standardErrorContained: Bool
    public let workspaceRemoved: Bool

    private init(
        resourceOwnership: ResourceOwnership,
        processGroupTerminated: Bool,
        standardErrorContained: Bool,
        workspaceRemoved: Bool
    ) {
        self.resourceOwnership = resourceOwnership
        self.processGroupTerminated = processGroupTerminated
        self.standardErrorContained = standardErrorContained
        self.workspaceRemoved = workspaceRemoved
    }

    public static let noOwnedResources = Self(
        resourceOwnership: .none,
        processGroupTerminated: false,
        standardErrorContained: false,
        workspaceRemoved: false
    )

    public static let retiredOwnedResources = Self(
        resourceOwnership: .owned,
        processGroupTerminated: true,
        standardErrorContained: true,
        workspaceRemoved: true
    )

    public static let retiredPreparedWorkspace = Self(
        resourceOwnership: .preparedWorkspace,
        processGroupTerminated: false,
        standardErrorContained: false,
        workspaceRemoved: true
    )

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(
            decoder: decoder,
            expectedKeys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        self.init(
            resourceOwnership: try container.decode(
                ResourceOwnership.self,
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.resourceOwnership.rawValue
                )
            ),
            processGroupTerminated: try container.decode(
                Bool.self,
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.processGroupTerminated.rawValue
                )
            ),
            standardErrorContained: try container.decode(
                Bool.self,
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.standardErrorContained.rawValue
                )
            ),
            workspaceRemoved: try container.decode(
                Bool.self,
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.workspaceRemoved.rawValue
                )
            )
        )
        guard isValid else {
            throw DecodingError.dataCorruptedError(
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.resourceOwnership.rawValue
                ),
                in: container,
                debugDescription: "Inconsistent worker retirement facts"
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
            resourceOwnership,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.resourceOwnership.rawValue
            )
        )
        try container.encode(
            processGroupTerminated,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.processGroupTerminated.rawValue
            )
        )
        try container.encode(
            standardErrorContained,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.standardErrorContained.rawValue
            )
        )
        try container.encode(
            workspaceRemoved,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.workspaceRemoved.rawValue
            )
        )
    }

    private var isValid: Bool {
        switch resourceOwnership {
        case .none:
            !processGroupTerminated
                && !standardErrorContained
                && !workspaceRemoved
        case .preparedWorkspace:
            !processGroupTerminated
                && !standardErrorContained
                && workspaceRemoved
        case .owned:
            processGroupTerminated
                && standardErrorContained
                && workspaceRemoved
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case resourceOwnership
        case processGroupTerminated
        case standardErrorContained
        case workspaceRemoved
    }
}

public struct LifecycleInteractiveSessionResponse:
    Codable,
    Sendable,
    Equatable
{
    public static let protocolVersion = 4

    public let kind: LifecycleInteractiveSessionResponseKind
    public let investigationID: LifecycleInvestigationID
    public let operationID: UUID
    public let line: Data?
    public let drained: Bool?
    public let ownerRetirementObservation:
        LifecycleInteractiveWorkerRetirementObservation?
    public let machineRetirementHandle:
        LifecycleMachineRetirementHandle?
    public let residueObservation:
        LifecycleInvestigationResidueObservation?

    private init(
        kind: LifecycleInteractiveSessionResponseKind,
        investigationID: LifecycleInvestigationID,
        operationID: UUID,
        line: Data?,
        drained: Bool?,
        ownerRetirementObservation:
            LifecycleInteractiveWorkerRetirementObservation?,
        machineRetirementHandle: LifecycleMachineRetirementHandle?,
        residueObservation: LifecycleInvestigationResidueObservation?
    ) {
        self.kind = kind
        self.investigationID = investigationID
        self.operationID = operationID
        self.line = line
        self.drained = drained
        self.ownerRetirementObservation = ownerRetirementObservation
        self.machineRetirementHandle = machineRetirementHandle
        self.residueObservation = residueObservation
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
            drained: nil,
            ownerRetirementObservation: nil,
            machineRetirementHandle: nil,
            residueObservation: nil
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
            drained: nil,
            ownerRetirementObservation: nil,
            machineRetirementHandle: nil,
            residueObservation: nil
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
            drained: nil,
            ownerRetirementObservation: nil,
            machineRetirementHandle: nil,
            residueObservation: nil
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
            drained: nil,
            ownerRetirementObservation: nil,
            machineRetirementHandle: nil,
            residueObservation: nil
        )
    }

    public static func retired(
        investigationID: LifecycleInvestigationID,
        operationID: UUID,
        drained: Bool,
        ownerRetirementObservation:
            LifecycleInteractiveWorkerRetirementObservation,
        machineRetirementHandle:
            LifecycleMachineRetirementHandle? = nil,
        residueObservation:
            LifecycleInvestigationResidueObservation? = nil
    ) -> Self {
        Self(
            kind: .retired,
            investigationID: investigationID,
            operationID: operationID,
            line: nil,
            drained: drained,
            ownerRetirementObservation: ownerRetirementObservation,
            machineRetirementHandle: machineRetirementHandle,
            residueObservation: residueObservation
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
        ownerRetirementObservation = try container.decodeIfPresent(
            LifecycleInteractiveWorkerRetirementObservation.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.ownerRetirementObservation.rawValue
            )
        )
        machineRetirementHandle = try container.decodeIfPresent(
            LifecycleMachineRetirementHandle.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.machineRetirementHandle.rawValue
            )
        )
        residueObservation = try container.decodeIfPresent(
            LifecycleInvestigationResidueObservation.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.residueObservation.rawValue
            )
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
        try container.encode(
            ownerRetirementObservation,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.ownerRetirementObservation.rawValue
            )
        )
        try container.encode(
            machineRetirementHandle,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.machineRetirementHandle.rawValue
            )
        )
        try container.encode(
            residueObservation,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.residueObservation.rawValue
            )
        )
    }

    public func validated(
        for request: LifecycleInteractiveSessionRequest
    ) throws -> Self {
        try validateIdentity(for: request)
        guard
            ownerRetirementObservation != .retiredOwnedResources
                || machineRetirementHandle != nil
        else {
            throw LifecycleInteractiveSessionContractError
                .identityMismatch
        }
        return self
    }

    private func validateIdentity(
        for request: LifecycleInteractiveSessionRequest
    ) throws {
        guard
            investigationID == request.investigationID,
            operationID == request.operationID,
            responseKindMatches(request.kind),
            machineRetirementHandle.map({ handle in
                request.kind == .retire
                    && handle.investigationID == request.investigationID
                    && handle.retireOperationID == request.operationID
                    && handle.configurationSHA256
                        == request.configurationSHA256
            }) ?? true
        else {
            throw LifecycleInteractiveSessionContractError
                .identityMismatch
        }
    }

    private var isValid: Bool {
        switch kind {
        case .started, .writeAccepted, .endOfStream:
            return line == nil && drained == nil
                && ownerRetirementObservation == nil
                && machineRetirementHandle == nil
                && residueObservation == nil
        case .line:
            return line.map(validLine) == true && drained == nil
                && ownerRetirementObservation == nil
                && machineRetirementHandle == nil
                && residueObservation == nil
        case .retired:
            return line == nil
                && drained == true
                && ownerRetirementObservation != nil
                && (machineRetirementHandle == nil
                    || ownerRetirementObservation
                        == .retiredOwnedResources)
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
        case ownerRetirementObservation
        case machineRetirementHandle
        case residueObservation
    }
}

public struct LifecycleInteractiveWorkerReply:
    Codable,
    Sendable,
    Equatable
{
    public let operationID: UUID
    public let response: LifecycleInteractiveSessionResponse?
    public let reasonKey: String?

    public init(
        operationID: UUID,
        response: LifecycleInteractiveSessionResponse
    ) {
        self.operationID = operationID
        self.response = response
        reasonKey = nil
    }

    public init(operationID: UUID, reasonKey: String) throws {
        guard validInteractiveWorkerReasonKey(reasonKey) else {
            throw LifecycleInteractiveSessionContractError
                .invalidResponse
        }
        self.operationID = operationID
        response = nil
        self.reasonKey = reasonKey
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(
            decoder: decoder,
            expectedKeys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        operationID = try container.decode(
            UUID.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.operationID.rawValue
            )
        )
        response = try container.decodeIfPresent(
            LifecycleInteractiveSessionResponse.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.response.rawValue
            )
        )
        reasonKey = try container.decodeIfPresent(
            String.self,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.reasonKey.rawValue
            )
        )
        guard isValid else {
            throw DecodingError.dataCorruptedError(
                forKey: AnyLifecycleCodingKey(
                    CodingKeys.operationID.rawValue
                ),
                in: container,
                debugDescription: "Invalid interactive worker reply"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        guard isValid else {
            throw LifecycleInteractiveSessionContractError
                .invalidResponse
        }
        var container = encoder.container(
            keyedBy: AnyLifecycleCodingKey.self
        )
        try container.encode(
            operationID,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.operationID.rawValue
            )
        )
        try container.encode(
            response,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.response.rawValue
            )
        )
        try container.encode(
            reasonKey,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.reasonKey.rawValue
            )
        )
    }

    private var isValid: Bool {
        (response != nil) != (reasonKey != nil)
            && reasonKey.map(validInteractiveWorkerReasonKey) != false
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case operationID
        case response
        case reasonKey
    }
}

private func validLine(_ data: Data) -> Bool {
    (2...LifecycleInteractiveSessionRequest.maximumAllowedLineBytes)
        .contains(data.count)
        && data.last == 0x0A
        && !data.dropLast().contains(0x00)
}

private func validInteractiveWorkerReasonKey(_ value: String) -> Bool {
    !value.isEmpty
        && value.utf8.count <= 160
        && value.hasPrefix("runtime.lifecycle.interactive.")
        && value.unicodeScalars.allSatisfy { scalar in
            ("a"..."z").contains(Character(String(scalar)))
                || ("0"..."9").contains(Character(String(scalar)))
                || scalar == "."
                || scalar == "-"
        }
}
