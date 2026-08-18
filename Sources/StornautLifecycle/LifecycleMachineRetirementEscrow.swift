import Darwin
import CryptoKit
import Foundation

public enum LifecycleMachineRetirementEscrowError:
    Error,
    Sendable,
    Equatable
{
    case invalidRecord
    case invalidRequest
    case alreadyRecorded
    case empty
    case consumed
    case unauthorized
    case claimMismatch
    case expired
}

public struct LifecycleMachineProcessIdentityRecord:
    Codable,
    Sendable,
    Equatable
{
    public static let protocolVersion = 1
    public let processID: Int32
    public let processIDVersion: Int32
    public let auditSessionID: Int32
    public let effectiveUserID: UInt32
    public let auditTokenWords: [UInt32]

    public init(
        processID: Int32,
        processIDVersion: Int32,
        auditSessionID: Int32,
        effectiveUserID: UInt32,
        auditTokenWords: [UInt32]
    ) throws {
        guard Self.valid(
            processID: processID,
            processIDVersion: processIDVersion,
            auditSessionID: auditSessionID,
            effectiveUserID: effectiveUserID,
            auditTokenWords: auditTokenWords
        ) else {
            throw LifecycleMachineRetirementEscrowError.invalidRecord
        }
        self.processID = processID
        self.processIDVersion = processIDVersion
        self.auditSessionID = auditSessionID
        self.effectiveUserID = effectiveUserID
        self.auditTokenWords = auditTokenWords
    }

    public init(from decoder: Decoder) throws {
        let container = try machineStrictContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        guard try container.decode(
            Int.self,
            forKey: .init(CodingKeys.protocolVersion.rawValue)
        ) == Self.protocolVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .init(CodingKeys.protocolVersion.rawValue),
                in: container,
                debugDescription: "Unsupported machine identity version"
            )
        }
        do {
            try self.init(
                processID: container.decode(
                    Int32.self,
                    forKey: .init(CodingKeys.processID.rawValue)
                ),
                processIDVersion: container.decode(
                    Int32.self,
                    forKey: .init(CodingKeys.processIDVersion.rawValue)
                ),
                auditSessionID: container.decode(
                    Int32.self,
                    forKey: .init(CodingKeys.auditSessionID.rawValue)
                ),
                effectiveUserID: container.decode(
                    UInt32.self,
                    forKey: .init(CodingKeys.effectiveUserID.rawValue)
                ),
                auditTokenWords: container.decode(
                    [UInt32].self,
                    forKey: .init(CodingKeys.auditTokenWords.rawValue)
                )
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .init(CodingKeys.auditTokenWords.rawValue),
                in: container,
                debugDescription: "Invalid machine process identity"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        guard Self.valid(
            processID: processID,
            processIDVersion: processIDVersion,
            auditSessionID: auditSessionID,
            effectiveUserID: effectiveUserID,
            auditTokenWords: auditTokenWords
        ) else {
            throw LifecycleMachineRetirementEscrowError.invalidRecord
        }
        var container = encoder.container(keyedBy: MachineCodingKey.self)
        try container.encode(
            Self.protocolVersion,
            forKey: .init(CodingKeys.protocolVersion.rawValue)
        )
        try container.encode(processID, forKey: .init(CodingKeys.processID.rawValue))
        try container.encode(processIDVersion, forKey: .init(CodingKeys.processIDVersion.rawValue))
        try container.encode(auditSessionID, forKey: .init(CodingKeys.auditSessionID.rawValue))
        try container.encode(effectiveUserID, forKey: .init(CodingKeys.effectiveUserID.rawValue))
        try container.encode(auditTokenWords, forKey: .init(CodingKeys.auditTokenWords.rawValue))
    }

    private static func valid(
        processID: Int32,
        processIDVersion: Int32,
        auditSessionID: Int32,
        effectiveUserID: UInt32,
        auditTokenWords: [UInt32]
    ) -> Bool {
        guard
            processID > 1,
            processIDVersion > 0,
            auditSessionID > 0,
            auditTokenWords.count == LifecycleAuditToken.wordCount
        else { return false }
        var token = audit_token_t()
        let copied = withUnsafeMutableBytes(of: &token) { destination in
            auditTokenWords.withUnsafeBytes { source in
                guard destination.count == source.count else { return false }
                destination.copyBytes(from: source)
                return true
            }
        }
        return copied
            && audit_token_to_pid(token) == processID
            && audit_token_to_pidversion(token) == processIDVersion
            && audit_token_to_asid(token) == auditSessionID
            && audit_token_to_euid(token) == effectiveUserID
    }

    private enum CodingKeys: String, CaseIterable {
        case protocolVersion
        case processID
        case processIDVersion
        case auditSessionID
        case effectiveUserID
        case auditTokenWords
    }
}

public struct LifecycleMachineRetirementHandle:
    Codable,
    Sendable,
    Equatable
{
    public static let protocolVersion = 2
    public let token: UUID
    public let investigationID: LifecycleInvestigationID
    public let retireOperationID: UUID
    public let configurationSHA256: String
    public let validBefore: Date

    public init(
        token: UUID,
        investigationID: LifecycleInvestigationID,
        retireOperationID: UUID,
        configurationSHA256: String,
        validBefore: Date
    ) throws {
        guard
            !token.machineIsZero,
            !retireOperationID.machineIsZero,
            machineValidSHA256(configurationSHA256),
            validBefore.timeIntervalSince1970.isFinite
        else { throw LifecycleMachineRetirementEscrowError.invalidRequest }
        self.token = token
        self.investigationID = investigationID
        self.retireOperationID = retireOperationID
        self.configurationSHA256 = configurationSHA256
        self.validBefore = validBefore
    }

    public init(from decoder: Decoder) throws {
        let container = try machineStrictContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        guard try container.decode(
            Int.self,
            forKey: .init(CodingKeys.protocolVersion.rawValue)
        ) == Self.protocolVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .init(CodingKeys.protocolVersion.rawValue),
                in: container,
                debugDescription: "Unsupported retirement handle version"
            )
        }
        do {
            try self.init(
                token: container.decode(UUID.self, forKey: .init(CodingKeys.token.rawValue)),
                investigationID: container.decode(LifecycleInvestigationID.self, forKey: .init(CodingKeys.investigationID.rawValue)),
                retireOperationID: container.decode(UUID.self, forKey: .init(CodingKeys.retireOperationID.rawValue)),
                configurationSHA256: container.decode(
                    String.self,
                    forKey: .init(CodingKeys.configurationSHA256.rawValue)
                ),
                validBefore: container.decode(Date.self, forKey: .init(CodingKeys.validBefore.rawValue))
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .init(CodingKeys.token.rawValue),
                in: container,
                debugDescription: "Invalid retirement handle"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: MachineCodingKey.self)
        try container.encode(
            Self.protocolVersion,
            forKey: .init(CodingKeys.protocolVersion.rawValue)
        )
        try container.encode(token, forKey: .init(CodingKeys.token.rawValue))
        try container.encode(investigationID, forKey: .init(CodingKeys.investigationID.rawValue))
        try container.encode(retireOperationID, forKey: .init(CodingKeys.retireOperationID.rawValue))
        try container.encode(
            configurationSHA256,
            forKey: .init(CodingKeys.configurationSHA256.rawValue)
        )
        try container.encode(validBefore, forKey: .init(CodingKeys.validBefore.rawValue))
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case protocolVersion
        case token
        case investigationID
        case retireOperationID
        case configurationSHA256
        case validBefore
    }
}

public struct LifecycleMachineRetirementClaimRequest:
    Codable,
    Sendable,
    Equatable
{
    public static let protocolVersion = 2
    public static let maximumWindow: TimeInterval = 15
    public let handle: LifecycleMachineRetirementHandle
    public let challengeNonce: UUID
    public let issuedAt: Date
    public let validBefore: Date

    public init(
        handle: LifecycleMachineRetirementHandle,
        challengeNonce: UUID,
        issuedAt: Date,
        validBefore: Date
    ) throws {
        let duration = validBefore.timeIntervalSince(issuedAt)
        guard
            !challengeNonce.machineIsZero,
            issuedAt.timeIntervalSince1970.isFinite,
            validBefore.timeIntervalSince1970.isFinite,
            duration > 0,
            duration <= Self.maximumWindow,
            validBefore <= handle.validBefore
        else { throw LifecycleMachineRetirementEscrowError.invalidRequest }
        self.handle = handle
        self.challengeNonce = challengeNonce
        self.issuedAt = issuedAt
        self.validBefore = validBefore
    }

    public init(from decoder: Decoder) throws {
        let container = try machineStrictContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        guard try container.decode(
            Int.self,
            forKey: .init(CodingKeys.protocolVersion.rawValue)
        ) == Self.protocolVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .init(CodingKeys.protocolVersion.rawValue),
                in: container,
                debugDescription: "Unsupported retirement request version"
            )
        }
        do {
            try self.init(
                handle: container.decode(LifecycleMachineRetirementHandle.self, forKey: .init(CodingKeys.handle.rawValue)),
                challengeNonce: container.decode(UUID.self, forKey: .init(CodingKeys.challengeNonce.rawValue)),
                issuedAt: container.decode(Date.self, forKey: .init(CodingKeys.issuedAt.rawValue)),
                validBefore: container.decode(Date.self, forKey: .init(CodingKeys.validBefore.rawValue))
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .init(CodingKeys.challengeNonce.rawValue),
                in: container,
                debugDescription: "Invalid retirement claim request"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: MachineCodingKey.self)
        try container.encode(
            Self.protocolVersion,
            forKey: .init(CodingKeys.protocolVersion.rawValue)
        )
        try container.encode(handle, forKey: .init(CodingKeys.handle.rawValue))
        try container.encode(challengeNonce, forKey: .init(CodingKeys.challengeNonce.rawValue))
        try container.encode(issuedAt, forKey: .init(CodingKeys.issuedAt.rawValue))
        try container.encode(validBefore, forKey: .init(CodingKeys.validBefore.rawValue))
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case protocolVersion
        case handle
        case challengeNonce
        case issuedAt
        case validBefore
    }
}

public struct LifecycleMachineRetirementClaimResponse:
    Codable,
    Sendable,
    Equatable
{
    public static let protocolVersion = 2
    public let request: LifecycleMachineRetirementClaimRequest
    public let appIdentity: LifecycleMachineProcessIdentityRecord
    public let helperIdentity: LifecycleMachineProcessIdentityRecord
    public let userID: UInt32
    public let recordedAt: Date
    public let claimedAt: Date
    public let ownerRetirementObservation:
        LifecycleInteractiveWorkerRetirementObservation
    public let residueObservation: LifecycleInvestigationResidueObservation

    public init(
        request: LifecycleMachineRetirementClaimRequest,
        appIdentity: LifecycleMachineProcessIdentityRecord,
        helperIdentity: LifecycleMachineProcessIdentityRecord,
        userID: UInt32,
        recordedAt: Date,
        claimedAt: Date,
        ownerRetirementObservation:
            LifecycleInteractiveWorkerRetirementObservation,
        residueObservation: LifecycleInvestigationResidueObservation
    ) throws {
        self.request = request
        self.appIdentity = appIdentity
        self.helperIdentity = helperIdentity
        self.userID = userID
        self.recordedAt = recordedAt
        self.claimedAt = claimedAt
        self.ownerRetirementObservation = ownerRetirementObservation
        self.residueObservation = residueObservation
        guard Self.valid(self) else {
            throw LifecycleMachineRetirementEscrowError.invalidRecord
        }
    }

    fileprivate init(
        request: LifecycleMachineRetirementClaimRequest,
        entry: LifecycleMachineRetirementEscrow.Entry,
        claimedAt: Date
    ) throws {
        try self.init(
            request: request,
            appIdentity: entry.appIdentity,
            helperIdentity: entry.helperIdentity,
            userID: entry.userID,
            recordedAt: entry.recordedAt,
            claimedAt: claimedAt,
            ownerRetirementObservation:
                entry.ownerRetirementObservation,
            residueObservation: entry.residueObservation
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try machineStrictContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        guard try container.decode(
            Int.self,
            forKey: .init(CodingKeys.protocolVersion.rawValue)
        ) == Self.protocolVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .init(CodingKeys.protocolVersion.rawValue),
                in: container,
                debugDescription: "Unsupported retirement response version"
            )
        }
        request = try container.decode(LifecycleMachineRetirementClaimRequest.self, forKey: .init(CodingKeys.request.rawValue))
        appIdentity = try container.decode(LifecycleMachineProcessIdentityRecord.self, forKey: .init(CodingKeys.appIdentity.rawValue))
        helperIdentity = try container.decode(LifecycleMachineProcessIdentityRecord.self, forKey: .init(CodingKeys.helperIdentity.rawValue))
        userID = try container.decode(UInt32.self, forKey: .init(CodingKeys.userID.rawValue))
        recordedAt = try container.decode(Date.self, forKey: .init(CodingKeys.recordedAt.rawValue))
        claimedAt = try container.decode(Date.self, forKey: .init(CodingKeys.claimedAt.rawValue))
        ownerRetirementObservation = try container.decode(LifecycleInteractiveWorkerRetirementObservation.self, forKey: .init(CodingKeys.ownerRetirementObservation.rawValue))
        residueObservation = try container.decode(LifecycleInvestigationResidueObservation.self, forKey: .init(CodingKeys.residueObservation.rawValue))
        guard Self.valid(self) else {
            throw DecodingError.dataCorruptedError(
                forKey: .init(CodingKeys.request.rawValue),
                in: container,
                debugDescription: "Invalid retirement claim response"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        guard Self.valid(self) else {
            throw LifecycleMachineRetirementEscrowError.invalidRecord
        }
        var container = encoder.container(keyedBy: MachineCodingKey.self)
        try container.encode(
            Self.protocolVersion,
            forKey: .init(CodingKeys.protocolVersion.rawValue)
        )
        try container.encode(request, forKey: .init(CodingKeys.request.rawValue))
        try container.encode(appIdentity, forKey: .init(CodingKeys.appIdentity.rawValue))
        try container.encode(helperIdentity, forKey: .init(CodingKeys.helperIdentity.rawValue))
        try container.encode(userID, forKey: .init(CodingKeys.userID.rawValue))
        try container.encode(recordedAt, forKey: .init(CodingKeys.recordedAt.rawValue))
        try container.encode(claimedAt, forKey: .init(CodingKeys.claimedAt.rawValue))
        try container.encode(ownerRetirementObservation, forKey: .init(CodingKeys.ownerRetirementObservation.rawValue))
        try container.encode(residueObservation, forKey: .init(CodingKeys.residueObservation.rawValue))
    }

    private static func valid(_ value: Self) -> Bool {
        value.userID > 0
            && value.appIdentity.effectiveUserID == value.userID
            && value.helperIdentity.effectiveUserID == 0
            && value.appIdentity.processID != value.helperIdentity.processID
            && value.ownerRetirementObservation == .retiredOwnedResources
            && value.residueObservation.provedEmpty
            && value.residueObservation.investigationID == value.request.handle.investigationID
            && value.residueObservation.userID == value.userID
            && value.residueObservation.auditSessionID == value.helperIdentity.auditSessionID
            && value.residueObservation.observedAt <= value.recordedAt
            && value.recordedAt.timeIntervalSince(
                value.residueObservation.observedAt
            ) <= 60
            && value.recordedAt <= value.request.issuedAt
            && value.claimedAt >= value.request.issuedAt
            && value.claimedAt <= value.request.validBefore
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case protocolVersion
        case request
        case appIdentity
        case helperIdentity
        case userID
        case recordedAt
        case claimedAt
        case ownerRetirementObservation
        case residueObservation
    }
}

public final class LifecycleMachineRetirementEscrow: @unchecked Sendable {
    fileprivate struct Entry {
        let tokenSHA256: Data
        let investigationID: LifecycleInvestigationID
        let retireOperationID: UUID
        let configurationSHA256: String
        let validBefore: Date
        let appIdentity: LifecycleMachineProcessIdentityRecord
        let helperIdentity: LifecycleMachineProcessIdentityRecord
        let userID: UInt32
        let recordedAt: Date
        let ownerRetirementObservation:
            LifecycleInteractiveWorkerRetirementObservation
        let residueObservation: LifecycleInvestigationResidueObservation
    }

    private enum State {
        case empty
        case recorded(Entry)
        case consumed
    }

    private let lock = NSLock()
    private let now: @Sendable () -> Date
    private let token: @Sendable () -> UUID
    private var state = State.empty

    public convenience init() {
        self.init(now: Date.init, token: UUID.init)
    }

    init(
        now: @escaping @Sendable () -> Date,
        token: @escaping @Sendable () -> UUID
    ) {
        self.now = now
        self.token = token
    }

    public var isAwaitingClaim: Bool {
        lock.withLock {
            guard case .recorded = state else { return false }
            return true
        }
    }

    public func expire() {
        lock.withLock {
            state = .consumed
        }
    }

    public func record(
        investigationID: LifecycleInvestigationID,
        retireOperationID: UUID,
        configurationSHA256: String,
        validBefore: Date,
        appIdentity: LifecycleMachineProcessIdentityRecord,
        helperIdentity: LifecycleMachineProcessIdentityRecord,
        userID: UInt32,
        ownerRetirementObservation:
            LifecycleInteractiveWorkerRetirementObservation,
        residueObservation: LifecycleInvestigationResidueObservation
    ) throws -> LifecycleMachineRetirementHandle {
        try lock.withLock {
            guard case .empty = state else {
                throw LifecycleMachineRetirementEscrowError.alreadyRecorded
            }
            let recordedAt = now()
            guard
                recordedAt.timeIntervalSince1970.isFinite,
                validBefore > recordedAt,
                validBefore.timeIntervalSince(recordedAt) <= 60,
                machineValidSHA256(configurationSHA256),
                userID > 0,
                appIdentity.effectiveUserID == userID,
                helperIdentity.effectiveUserID == 0,
                appIdentity.processID != helperIdentity.processID,
                ownerRetirementObservation == .retiredOwnedResources,
                residueObservation.provedEmpty,
                residueObservation.investigationID == investigationID,
                residueObservation.userID == userID,
                residueObservation.auditSessionID == helperIdentity.auditSessionID,
                residueObservation.observedAt <= recordedAt,
                recordedAt.timeIntervalSince(residueObservation.observedAt) <= 60
            else { throw LifecycleMachineRetirementEscrowError.invalidRecord }
            let handle = try LifecycleMachineRetirementHandle(
                token: token(),
                investigationID: investigationID,
                retireOperationID: retireOperationID,
                configurationSHA256: configurationSHA256,
                validBefore: validBefore
            )
            state = .recorded(Entry(
                tokenSHA256: machineTokenSHA256(handle.token),
                investigationID: investigationID,
                retireOperationID: retireOperationID,
                configurationSHA256: configurationSHA256,
                validBefore: validBefore,
                appIdentity: appIdentity,
                helperIdentity: helperIdentity,
                userID: userID,
                recordedAt: recordedAt,
                ownerRetirementObservation: ownerRetirementObservation,
                residueObservation: residueObservation
            ))
            return handle
        }
    }

    func claim(
        _ request: LifecycleMachineRetirementClaimRequest,
        authorized: Bool
    ) throws -> LifecycleMachineRetirementClaimResponse {
        try lock.withLock {
            try claimLocked(request, authorized: authorized)
        }
    }

    public func claim(
        _ request: LifecycleMachineRetirementClaimRequest,
        machineDriverIdentity: LifecycleProcessIdentity
    ) throws -> LifecycleMachineRetirementClaimResponse {
        try claim(
            request,
            machineDriverIdentity: machineDriverIdentity,
            admission: LifecycleMachineDriverAdmissionPolicy()
        )
    }

    func claim(
        _ request: LifecycleMachineRetirementClaimRequest,
        machineDriverIdentity: LifecycleProcessIdentity,
        admission: any LifecycleMachineDriverClaimAdmitting
    ) throws -> LifecycleMachineRetirementClaimResponse {
        try lock.withLock {
            try claimLocked(
                request,
                authorized: admission.authorize(
                    machineDriverIdentity
                )
            )
        }
    }

    private func claimLocked(
        _ request: LifecycleMachineRetirementClaimRequest,
        authorized: Bool
    ) throws -> LifecycleMachineRetirementClaimResponse {
        guard authorized else {
            throw LifecycleMachineRetirementEscrowError.unauthorized
        }
        let entry: Entry
        switch state {
        case .empty:
            throw LifecycleMachineRetirementEscrowError.empty
        case .consumed:
            throw LifecycleMachineRetirementEscrowError.consumed
        case let .recorded(value):
            entry = value
            state = .consumed
        }
        let claimedAt = now()
        guard
            claimedAt.timeIntervalSince1970.isFinite,
            claimedAt <= entry.validBefore,
            claimedAt >= request.issuedAt,
            claimedAt <= request.validBefore
        else { throw LifecycleMachineRetirementEscrowError.expired }
        guard
            request.handle.investigationID == entry.investigationID,
            request.handle.retireOperationID == entry.retireOperationID,
            request.handle.configurationSHA256
                == entry.configurationSHA256,
            request.handle.validBefore == entry.validBefore,
            machineTokenSHA256(request.handle.token)
                == entry.tokenSHA256
        else {
            throw LifecycleMachineRetirementEscrowError.claimMismatch
        }
        return try LifecycleMachineRetirementClaimResponse(
            request: request,
            entry: entry,
            claimedAt: claimedAt
        )
    }
}

private func machineTokenSHA256(_ token: UUID) -> Data {
    var value = token.uuid
    return withUnsafeBytes(of: &value) {
        Data(SHA256.hash(data: Data($0)))
    }
}

private func machineValidSHA256(_ value: String) -> Bool {
    value.count == 64
        && value.unicodeScalars.allSatisfy {
            (0x30...0x39).contains($0.value)
                || (0x61...0x66).contains($0.value)
        }
}

private struct MachineCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int? = nil
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private func machineStrictContainer(
    _ decoder: Decoder,
    keys: Set<String>
) throws -> KeyedDecodingContainer<MachineCodingKey> {
    let container = try decoder.container(keyedBy: MachineCodingKey.self)
    let observed = Set(container.allKeys.map(\.stringValue))
    guard observed == keys else {
        throw DecodingError.dataCorruptedError(
            forKey: .init(observed.subtracting(keys).sorted().first ?? "missing"),
            in: container,
            debugDescription: "Unexpected machine retirement fields"
        )
    }
    return container
}

private extension UUID {
    var machineIsZero: Bool { uuidString == "00000000-0000-0000-0000-000000000000" }
}
