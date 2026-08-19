import Darwin
import Foundation

public enum LifecycleSupervisorXPCError:
    Error,
    Sendable,
    Equatable
{
    case invalidPeer
    case connectionFailed
    case invalidResponse
    case remoteRejected(reasonKey: String)
}

@objc public protocol LifecycleSupervisorXPCWire {
    func attestHelper(
        _ request: Data,
        withReply reply: @escaping (Data?, String?) -> Void
    )

    func handle(
        _ request: Data,
        withReply reply: @escaping (Data?, String?) -> Void
    )
}

@objc public protocol LifecycleInteractiveSessionXPCWire:
    LifecycleSupervisorXPCWire
{
    func handleInteractive(
        _ request: Data,
        withReply reply: @escaping (Data?, String?) -> Void
    )
}

public enum LifecycleInteractiveSessionXPCError:
    Error,
    Sendable,
    Equatable
{
    case invalidPeer
    case connectionFailed
    case timedOut
    case cancelled
    case invalidResponse
    case remoteRejected(reasonKey: String)
}

public protocol LifecycleInteractiveSessionSending: Sendable {
    func send(
        _ request: LifecycleInteractiveSessionRequest
    ) async throws -> LifecycleInteractiveSessionResponse
}

package protocol LifecycleHelperPeerAttesting: Sendable {
    func freshAttestedHelperPeer() async throws
        -> LifecycleConnectedHelperPeer
}

package protocol LifecycleInteractiveSessionEvidenceSending:
    LifecycleInteractiveSessionSending,
    LifecycleHelperPeerAttesting
{
    func takeRetirementHelperPeer(
        operationID: UUID
    ) async -> LifecycleConnectedHelperPeer?
}

public enum LifecycleHelperPeerAttestationError:
    Error,
    Sendable,
    Equatable
{
    case invalidRequest
    case invalidResponse
    case challengeMismatch
    case observationOutsideWindow
    case connectionIdentityMismatch
    case signingIdentityMismatch
}

public struct LifecycleHelperPeerAttestationRequest:
    Codable,
    Sendable,
    Equatable
{
    public static let protocolVersion = 1
    public static let maximumDuration: TimeInterval = 15
    public static let maximumEncodedBytes = 4 * 1_024

    public let nonce: UUID
    public let issuedAt: Date
    public let validBefore: Date

    public init(
        nonce: UUID,
        issuedAt: Date,
        validBefore: Date
    ) throws {
        let duration = validBefore.timeIntervalSince(issuedAt)
        guard
            nonce != UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
            issuedAt.timeIntervalSinceReferenceDate.isFinite,
            validBefore.timeIntervalSinceReferenceDate.isFinite,
            duration > 0,
            duration <= Self.maximumDuration
        else {
            throw LifecycleHelperPeerAttestationError.invalidRequest
        }
        self.nonce = nonce
        self.issuedAt = issuedAt
        self.validBefore = validBefore
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
                debugDescription: "Unsupported helper attestation request"
            )
        }
        do {
            try self.init(
                nonce: container.decode(
                    UUID.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.nonce.rawValue
                    )
                ),
                issuedAt: container.decode(
                    Date.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.issuedAt.rawValue
                    )
                ),
                validBefore: container.decode(
                    Date.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.validBefore.rawValue
                    )
                )
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: AnyLifecycleCodingKey(CodingKeys.nonce.rawValue),
                in: container,
                debugDescription: "Invalid helper attestation request"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        guard (try? Self(
            nonce: nonce,
            issuedAt: issuedAt,
            validBefore: validBefore
        )) != nil else {
            throw LifecycleHelperPeerAttestationError.invalidRequest
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
            nonce,
            forKey: AnyLifecycleCodingKey(CodingKeys.nonce.rawValue)
        )
        try container.encode(
            issuedAt,
            forKey: AnyLifecycleCodingKey(CodingKeys.issuedAt.rawValue)
        )
        try container.encode(
            validBefore,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.validBefore.rawValue
            )
        )
    }

    fileprivate func contains(_ date: Date) -> Bool {
        date >= issuedAt && date <= validBefore
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case protocolVersion
        case nonce
        case issuedAt
        case validBefore
    }
}

public struct LifecycleHelperPeerAttestationResponse:
    Codable,
    Sendable,
    Equatable
{
    public static let protocolVersion = 1

    public let nonce: UUID
    public let issuedAt: Date
    public let validBefore: Date
    public let processID: pid_t
    public let processIDVersion: Int32
    public let auditSessionID: Int32
    public let effectiveUserID: uid_t
    public let auditTokenWords: [UInt32]
    public let observedAt: Date

    public init(
        request: LifecycleHelperPeerAttestationRequest,
        identity: LifecycleProcessIdentity,
        observedAt: Date
    ) throws {
        guard
            request.contains(observedAt),
            lifecycleIdentityMatchesAuditToken(identity),
            identity.processID > 1,
            identity.processIDVersion > 0,
            identity.auditSessionID > 0,
            identity.effectiveUserID == 0
        else {
            throw LifecycleHelperPeerAttestationError.invalidResponse
        }
        nonce = request.nonce
        issuedAt = request.issuedAt
        validBefore = request.validBefore
        processID = identity.processID
        processIDVersion = identity.processIDVersion
        auditSessionID = identity.auditSessionID
        effectiveUserID = identity.effectiveUserID
        auditTokenWords = identity.auditToken.words
        self.observedAt = observedAt
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
                debugDescription: "Unsupported helper attestation response"
            )
        }
        do {
            let request = try LifecycleHelperPeerAttestationRequest(
                nonce: container.decode(
                    UUID.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.nonce.rawValue
                    )
                ),
                issuedAt: container.decode(
                    Date.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.issuedAt.rawValue
                    )
                ),
                validBefore: container.decode(
                    Date.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.validBefore.rawValue
                    )
                )
            )
            let identity = LifecycleProcessIdentity(
                processID: try container.decode(
                    pid_t.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.processID.rawValue
                    )
                ),
                processIDVersion: try container.decode(
                    Int32.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.processIDVersion.rawValue
                    )
                ),
                auditSessionID: try container.decode(
                    Int32.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.auditSessionID.rawValue
                    )
                ),
                effectiveUserID: try container.decode(
                    uid_t.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.effectiveUserID.rawValue
                    )
                ),
                auditToken: try LifecycleAuditToken(
                    words: container.decode(
                        [UInt32].self,
                        forKey: AnyLifecycleCodingKey(
                            CodingKeys.auditTokenWords.rawValue
                        )
                    )
                )
            )
            try self.init(
                request: request,
                identity: identity,
                observedAt: container.decode(
                    Date.self,
                    forKey: AnyLifecycleCodingKey(
                        CodingKeys.observedAt.rawValue
                    )
                )
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: AnyLifecycleCodingKey(CodingKeys.nonce.rawValue),
                in: container,
                debugDescription: "Invalid helper attestation response"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        let request = try LifecycleHelperPeerAttestationRequest(
            nonce: nonce,
            issuedAt: issuedAt,
            validBefore: validBefore
        )
        let identity = try lifecycleIdentity
        guard (try? Self(
            request: request,
            identity: identity,
            observedAt: observedAt
        )) != nil else {
            throw LifecycleHelperPeerAttestationError.invalidResponse
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
            nonce,
            forKey: AnyLifecycleCodingKey(CodingKeys.nonce.rawValue)
        )
        try container.encode(
            issuedAt,
            forKey: AnyLifecycleCodingKey(CodingKeys.issuedAt.rawValue)
        )
        try container.encode(
            validBefore,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.validBefore.rawValue
            )
        )
        try container.encode(
            processID,
            forKey: AnyLifecycleCodingKey(CodingKeys.processID.rawValue)
        )
        try container.encode(
            processIDVersion,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.processIDVersion.rawValue
            )
        )
        try container.encode(
            auditSessionID,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.auditSessionID.rawValue
            )
        )
        try container.encode(
            effectiveUserID,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.effectiveUserID.rawValue
            )
        )
        try container.encode(
            auditTokenWords,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.auditTokenWords.rawValue
            )
        )
        try container.encode(
            observedAt,
            forKey: AnyLifecycleCodingKey(
                CodingKeys.observedAt.rawValue
            )
        )
    }

    fileprivate var lifecycleIdentity: LifecycleProcessIdentity {
        get throws {
            LifecycleProcessIdentity(
                processID: processID,
                processIDVersion: processIDVersion,
                auditSessionID: auditSessionID,
                effectiveUserID: effectiveUserID,
                auditToken: try LifecycleAuditToken(
                    words: auditTokenWords
                )
            )
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case protocolVersion
        case nonce
        case issuedAt
        case validBefore
        case processID
        case processIDVersion
        case auditSessionID
        case effectiveUserID
        case auditTokenWords
        case observedAt
    }
}

package struct LifecycleConnectedHelperPeer: Sendable, Equatable {
    package let identity: LifecycleProcessIdentity
    package let attestedAt: Date

    init(
        identity: LifecycleProcessIdentity,
        attestedAt: Date
    ) {
        self.identity = identity
        self.attestedAt = attestedAt
    }
}

struct LifecycleConnectedHelperPeerAttestor: Sendable {
    private let expectedSigningIdentity: LifecycleSigningIdentity
    private let signingVerifier: any LifecycleCodeSigningVerifying

    init(
        expectedSigningIdentity: LifecycleSigningIdentity,
        signingVerifier: any LifecycleCodeSigningVerifying
            = SecurityLifecycleCodeSigningVerifier()
    ) {
        self.expectedSigningIdentity = expectedSigningIdentity
        self.signingVerifier = signingVerifier
    }

    func attest(
        _ response: LifecycleHelperPeerAttestationResponse,
        for request: LifecycleHelperPeerAttestationRequest,
        connectedProcessID: pid_t,
        connectedEffectiveUserID: uid_t,
        connectedAuditSessionID: Int32,
        receivedAt: Date
    ) throws -> LifecycleConnectedHelperPeer {
        guard
            response.nonce == request.nonce,
            response.issuedAt == request.issuedAt,
            response.validBefore == request.validBefore
        else {
            throw LifecycleHelperPeerAttestationError
                .challengeMismatch
        }
        guard
            request.contains(response.observedAt),
            request.contains(receivedAt),
            response.observedAt <= receivedAt
        else {
            throw LifecycleHelperPeerAttestationError
                .observationOutsideWindow
        }
        let identity = try response.lifecycleIdentity
        guard
            lifecycleIdentityMatchesAuditToken(identity),
            connectedProcessID > 1,
            connectedEffectiveUserID == 0,
            connectedAuditSessionID > 0,
            identity.processID == connectedProcessID,
            identity.effectiveUserID == connectedEffectiveUserID,
            identity.auditSessionID == connectedAuditSessionID,
            identity.processIDVersion > 0
        else {
            throw LifecycleHelperPeerAttestationError
                .connectionIdentityMismatch
        }
        guard case let .verified(
            verifiedProcessID,
            verifiedEffectiveUserID,
            signingIdentifier,
            designatedRequirementSHA256,
            codeDirectoryHash
        ) = signingVerifier.verify(auditToken: identity.auditToken),
            verifiedProcessID == identity.processID,
            verifiedEffectiveUserID == identity.effectiveUserID,
            signingIdentifier
                == expectedSigningIdentity.signingIdentifier,
            designatedRequirementSHA256
                == expectedSigningIdentity.designatedRequirementSHA256,
            codeDirectoryHash
                == expectedSigningIdentity.codeDirectoryHash
        else {
            throw LifecycleHelperPeerAttestationError
                .signingIdentityMismatch
        }
        return LifecycleConnectedHelperPeer(
            identity: identity,
            attestedAt: receivedAt
        )
    }
}

public struct LifecycleSupervisorXPCResponse:
    Codable,
    Sendable,
    Equatable
{
    private enum CodingKeys: String, CodingKey {
        case protocolVersion
        case status
        case callerAuthenticated
        case freshAuditSession
        case workerEvidenceReady
        case drained
        case staleRecoveryObserved
        case workerEvidence
    }

    public let protocolVersion: Int
    public let status: String
    public let callerAuthenticated: Bool
    public let freshAuditSession: Bool
    public let workerEvidenceReady: Bool
    public let drained: Bool
    public let staleRecoveryObserved: Bool
    public let workerEvidence: Data?

    public init(
        callerAuthenticated: Bool,
        freshAuditSession: Bool,
        workerEvidence: Data? = nil,
        drained: Bool = false,
        staleRecoveryObserved: Bool = false
    ) {
        protocolVersion = 1
        status = "accepted"
        self.callerAuthenticated = callerAuthenticated
        self.freshAuditSession = freshAuditSession
        workerEvidenceReady = workerEvidence != nil
        self.drained = drained
        self.staleRecoveryObserved = staleRecoveryObserved
        self.workerEvidence = workerEvidence
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(protocolVersion, forKey: .protocolVersion)
        try container.encode(status, forKey: .status)
        try container.encode(
            callerAuthenticated,
            forKey: .callerAuthenticated
        )
        try container.encode(
            freshAuditSession,
            forKey: .freshAuditSession
        )
        try container.encode(
            workerEvidenceReady,
            forKey: .workerEvidenceReady
        )
        try container.encode(drained, forKey: .drained)
        try container.encode(
            staleRecoveryObserved,
            forKey: .staleRecoveryObserved
        )
        if let workerEvidence {
            try container.encode(
                workerEvidence,
                forKey: .workerEvidence
            )
        } else {
            try container.encodeNil(forKey: .workerEvidence)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(
            decoder: decoder,
            expectedKeys: [
                "callerAuthenticated",
                "drained",
                "freshAuditSession",
                "protocolVersion",
                "staleRecoveryObserved",
                "status",
                "workerEvidence",
                "workerEvidenceReady",
            ]
        )
        let workerEvidence = try container.decodeIfPresent(
            Data.self,
            forKey: AnyLifecycleCodingKey("workerEvidence")
        )
        guard
            try container.decode(
                Int.self,
                forKey: AnyLifecycleCodingKey("protocolVersion")
            ) == 1,
            try container.decode(
                String.self,
                forKey: AnyLifecycleCodingKey("status")
            ) == "accepted",
            try container.decode(
                Bool.self,
                forKey: AnyLifecycleCodingKey(
                    "callerAuthenticated"
                )
            ),
            try container.decode(
                Bool.self,
                forKey: AnyLifecycleCodingKey(
                    "freshAuditSession"
                )
            ),
            let workerEvidenceReady = try? container.decode(
                Bool.self,
                forKey: AnyLifecycleCodingKey(
                    "workerEvidenceReady"
                )
            ),
            let drained = try? container.decode(
                Bool.self,
                forKey: AnyLifecycleCodingKey("drained")
            ),
            let staleRecoveryObserved = try? container.decode(
                Bool.self,
                forKey: AnyLifecycleCodingKey(
                    "staleRecoveryObserved"
                )
            ),
            workerEvidence.map({ $0.count <= 1_024 * 1_024 }) ?? true,
            workerEvidenceReady == (workerEvidence != nil)
        else {
            throw DecodingError.dataCorruptedError(
                forKey: AnyLifecycleCodingKey("status"),
                in: container,
                debugDescription: "Invalid lifecycle XPC response"
            )
        }
        protocolVersion = 1
        status = "accepted"
        callerAuthenticated = true
        freshAuditSession = true
        self.workerEvidenceReady = workerEvidenceReady
        self.drained = drained
        self.staleRecoveryObserved = staleRecoveryObserved
        self.workerEvidence = workerEvidence
    }
}

public actor LifecycleSupervisorXPCClient {
    public static let serviceName =
        "com.eriklee.stornaut.lifecycle"

    private let helperBundleURL: URL
    private let identityReader: LifecycleBundleSigningIdentityReader
    private var connection: NSXPCConnection?

    public init(
        helperBundleURL: URL,
        identityReader: LifecycleBundleSigningIdentityReader = .init()
    ) {
        self.helperBundleURL = helperBundleURL
        self.identityReader = identityReader
    }

    public func send(
        _ request: LifecycleSupervisorRequest
    ) async throws -> LifecycleSupervisorXPCResponse {
        let connection = try activeConnection()
        let data = try JSONEncoder().encode(request)
        return try await withCheckedThrowingContinuation {
            continuation in
            let resolver = LifecycleSupervisorXPCReplyResolver(
                continuation
            )
            let proxy = connection.remoteObjectProxyWithErrorHandler {
                _ in
                resolver.failConnection()
            }
            guard let wire = proxy as? LifecycleSupervisorXPCWire else {
                resolver.failConnection()
                return
            }
            wire.handle(data) { response, reasonKey in
                resolver.resolve(
                    response: response,
                    reasonKey: reasonKey
                )
            }
        }
    }

    public func invalidate() {
        connection?.invalidate()
        connection = nil
    }

    private func activeConnection() throws -> NSXPCConnection {
        if let connection {
            return connection
        }
        let identity: LifecycleSigningIdentity
        do {
            identity = try identityReader.read(
                bundleURL: helperBundleURL
            )
        } catch {
            throw LifecycleSupervisorXPCError.invalidPeer
        }
        let connection = NSXPCConnection(
            machServiceName: Self.serviceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(
            with: LifecycleSupervisorXPCWire.self
        )
        connection.setCodeSigningRequirement(
            LifecyclePeerCodeSigningRequirement.exact(
                identity: identity
            )
        )
        connection.resume()
        self.connection = connection
        return connection
    }
}

public actor LifecycleInteractiveSessionXPCClient:
    LifecycleInteractiveSessionEvidenceSending,
    LifecycleHelperPeerAttesting
{
    private let helperBundleURL: URL
    private let identityReader: LifecycleBundleSigningIdentityReader
    private let now: @Sendable () -> Date
    private let nonce: @Sendable () -> UUID
    private var connection: NSXPCConnection?
    private var connectionEpoch: LifecycleXPCConnectionEpoch?
    private var helperPeer: LifecycleConnectedHelperPeer?
    private var connectionGeneration: UInt64 = 0
    private var retirementHelperPeers: [
        UUID: LifecycleConnectedHelperPeer
    ] = [:]
    private var attestationInProgress = false
    private var connectionPermanentlyInvalidated = false

    public init(
        helperBundleURL: URL,
        identityReader: LifecycleBundleSigningIdentityReader = .init(),
        now: @escaping @Sendable () -> Date = Date.init,
        nonce: @escaping @Sendable () -> UUID = UUID.init
    ) {
        self.helperBundleURL = helperBundleURL
        self.identityReader = identityReader
        self.now = now
        self.nonce = nonce
    }

    package func freshAttestedHelperPeer() async throws
        -> LifecycleConnectedHelperPeer
    {
        guard !attestationInProgress else {
            throw LifecycleInteractiveSessionXPCError.invalidPeer
        }
        attestationInProgress = true
        defer { attestationInProgress = false }

        let connection = try activeConnection()
        guard let epoch = connectionEpoch, epoch.isValid else {
            throw LifecycleInteractiveSessionXPCError.invalidPeer
        }
        let generation = connectionGeneration
        let expectedSigningIdentity: LifecycleSigningIdentity
        do {
            expectedSigningIdentity = try identityReader.read(
                bundleURL: helperBundleURL
            )
        } catch {
            invalidate()
            throw LifecycleInteractiveSessionXPCError.invalidPeer
        }
        let issuedAt = now()
        let request: LifecycleHelperPeerAttestationRequest
        do {
            request = try LifecycleHelperPeerAttestationRequest(
                nonce: nonce(),
                issuedAt: issuedAt,
                validBefore: issuedAt.addingTimeInterval(15)
            )
        } catch {
            invalidate()
            throw LifecycleInteractiveSessionXPCError.invalidPeer
        }
        let data: Data
        do {
            data = try JSONEncoder().encode(request)
            guard data.count <= LifecycleHelperPeerAttestationRequest
                .maximumEncodedBytes else {
                throw LifecycleInteractiveSessionXPCError.invalidPeer
            }
        } catch {
            invalidate()
            throw LifecycleInteractiveSessionXPCError.invalidPeer
        }
        let response: LifecycleHelperPeerAttestationResponse
        do {
            response = try await sendHelperAttestation(
                data,
                connection: connection
            )
        } catch {
            invalidate()
            throw error
        }
        let connectedProcessID = connection.processIdentifier
        let connectedEffectiveUserID =
            connection.effectiveUserIdentifier
        let connectedAuditSessionID =
            Int32(connection.auditSessionIdentifier)
        guard
            epoch.isValid,
            self.connection === connection,
            connectionEpoch === epoch,
            connectionGeneration == generation
        else {
            throw LifecycleInteractiveSessionXPCError.invalidPeer
        }
        let peer: LifecycleConnectedHelperPeer
        do {
            peer = try LifecycleConnectedHelperPeerAttestor(
                expectedSigningIdentity: expectedSigningIdentity
            ).attest(
                response,
                for: request,
                connectedProcessID: connectedProcessID,
                connectedEffectiveUserID: connectedEffectiveUserID,
                connectedAuditSessionID: connectedAuditSessionID,
                receivedAt: now()
            )
        } catch {
            invalidate()
            throw LifecycleInteractiveSessionXPCError.invalidPeer
        }
        if let helperPeer, helperPeer.identity != peer.identity {
            invalidate()
            throw LifecycleInteractiveSessionXPCError.invalidPeer
        }
        helperPeer = peer
        return peer
    }

    public func send(
        _ request: LifecycleInteractiveSessionRequest
    ) async throws -> LifecycleInteractiveSessionResponse {
        if request.kind != .retire {
            try Task.checkCancellation()
        }
        let retirePeer: LifecycleConnectedHelperPeer?
        if request.kind == .retire {
            retirePeer = try await freshAttestedHelperPeer()
        } else {
            if helperPeer == nil {
                _ = try await freshAttestedHelperPeer()
            }
            retirePeer = nil
        }
        if request.kind != .retire {
            try Task.checkCancellation()
        }
        let connection = try activeConnection()
        guard let epoch = connectionEpoch, epoch.isValid else {
            throw LifecycleInteractiveSessionXPCError.invalidPeer
        }
        let generation = connectionGeneration
        let data: Data
        do {
            data = try JSONEncoder().encode(request)
            guard
                data.count <= LifecycleInteractiveSessionRequest
                    .maximumEncodedEnvelopeBytes
            else {
                throw LifecycleInteractiveSessionXPCError
                    .invalidResponse
            }
        } catch {
            if let error = error as? LifecycleInteractiveSessionXPCError {
                throw error
            }
            throw LifecycleInteractiveSessionXPCError.invalidResponse
        }
        let resolver = LifecycleInteractiveSessionXPCReplyResolver(
            request: request
        )
        let response = try await withTaskCancellationHandler {
            if request.kind != .retire {
                try Task.checkCancellation()
            }
            return try await withCheckedThrowingContinuation {
                continuation in
                guard resolver.install(continuation) else {
                    return
                }
                resolver.scheduleTimeout(
                    seconds: request.kind == .retire ? 45 : 15
                )
                let proxy = connection.remoteObjectProxyWithErrorHandler {
                    _ in
                    resolver.failConnection()
                }
                guard
                    let wire =
                        proxy as? LifecycleInteractiveSessionXPCWire
                else {
                    resolver.failConnection()
                    return
                }
                guard resolver.beginDispatch() else {
                    return
                }
                wire.handleInteractive(data) { response, reasonKey in
                    resolver.resolve(
                        response: response,
                        reasonKey: reasonKey
                    )
                }
            }
        } onCancel: {
            if request.kind != .retire {
                resolver.failCancellation()
            }
        }
        guard
            epoch.isValid,
            self.connection === connection,
            connectionEpoch === epoch,
            connectionGeneration == generation
        else {
            throw LifecycleInteractiveSessionXPCError.invalidPeer
        }
        if let retirePeer {
            retirementHelperPeers[request.operationID] = retirePeer
        }
        return response
    }

    package func takeRetirementHelperPeer(
        operationID: UUID
    ) -> LifecycleConnectedHelperPeer? {
        retirementHelperPeers.removeValue(forKey: operationID)
    }

    public func invalidate() {
        connectionPermanentlyInvalidated = true
        connectionGeneration &+= 1
        connectionEpoch?.invalidate()
        connection?.invalidate()
        connection = nil
        connectionEpoch = nil
        helperPeer = nil
        attestationInProgress = false
        retirementHelperPeers.removeAll()
    }

    private func sendHelperAttestation(
        _ request: Data,
        connection: NSXPCConnection
    ) async throws -> LifecycleHelperPeerAttestationResponse {
        try await withCheckedThrowingContinuation { continuation in
            let resolver = LifecycleHelperPeerAttestationReplyResolver(
                continuation
            )
            let proxy = connection.remoteObjectProxyWithErrorHandler { _ in
                resolver.failConnection()
            }
            guard let wire = proxy as? LifecycleSupervisorXPCWire else {
                resolver.failConnection()
                return
            }
            wire.attestHelper(request) { response, reasonKey in
                resolver.resolve(
                    response: response,
                    reasonKey: reasonKey
                )
            }
        }
    }

    private func activeConnection() throws -> NSXPCConnection {
        guard !connectionPermanentlyInvalidated else {
            throw LifecycleInteractiveSessionXPCError.invalidPeer
        }
        if let connection, let connectionEpoch, connectionEpoch.isValid {
            return connection
        }
        guard connection == nil, connectionEpoch == nil else {
            throw LifecycleInteractiveSessionXPCError.invalidPeer
        }
        let identity: LifecycleSigningIdentity
        do {
            identity = try identityReader.read(
                bundleURL: helperBundleURL
            )
        } catch {
            throw LifecycleInteractiveSessionXPCError.invalidPeer
        }
        let connection = NSXPCConnection(
            machServiceName: LifecycleSupervisorXPCClient.serviceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(
            with: LifecycleInteractiveSessionXPCWire.self
        )
        connection.setCodeSigningRequirement(
            LifecyclePeerCodeSigningRequirement.exact(
                identity: identity
            )
        )
        connectionGeneration &+= 1
        let epoch = LifecycleXPCConnectionEpoch()
        self.connection = connection
        connectionEpoch = epoch
        connection.invalidationHandler = { [weak connection] in
            epoch.invalidate()
            connection?.invalidate()
        }
        connection.interruptionHandler = { [weak connection] in
            epoch.invalidate()
            connection?.invalidate()
        }
        connection.resume()
        return connection
    }
}

final class LifecycleXPCConnectionEpoch: @unchecked Sendable {
    private let lock = NSLock()
    private var valid = true

    var isValid: Bool {
        lock.withLock { valid }
    }

    func invalidate() {
        lock.withLock { valid = false }
    }
}

final class LifecycleSupervisorXPCReplyResolver:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var continuation:
        CheckedContinuation<LifecycleSupervisorXPCResponse, any Error>?

    init(
        _ continuation:
            CheckedContinuation<
                LifecycleSupervisorXPCResponse,
                any Error
            >
    ) {
        self.continuation = continuation
    }

    var hasPendingContinuation: Bool {
        lock.withLock { continuation != nil }
    }

    func failConnection() {
        finish(
            .failure(
                LifecycleSupervisorXPCError.connectionFailed
            )
        )
    }

    func resolve(
        response: Data?,
        reasonKey: String?
    ) {
        if let reasonKey {
            finish(
                .failure(
                    LifecycleSupervisorXPCError.remoteRejected(
                        reasonKey: reasonKey
                    )
                )
            )
            return
        }
        guard
            let response,
            let decoded = try? JSONDecoder().decode(
                LifecycleSupervisorXPCResponse.self,
                from: response
            )
        else {
            finish(
                .failure(
                    LifecycleSupervisorXPCError.invalidResponse
                )
            )
            return
        }
        finish(.success(decoded))
    }

    private func finish(
        _ result: Result<
            LifecycleSupervisorXPCResponse,
            any Error
        >
    ) {
        let continuation = lock.withLock {
            let value = self.continuation
            self.continuation = nil
            return value
        }
        continuation?.resume(with: result)
    }
}

final class LifecycleHelperPeerAttestationReplyResolver:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var continuation:
        CheckedContinuation<
            LifecycleHelperPeerAttestationResponse,
            any Error
        >?
    private var timeoutTask: Task<Void, Never>?

    init(
        _ continuation: CheckedContinuation<
            LifecycleHelperPeerAttestationResponse,
            any Error
        >
    ) {
        self.continuation = continuation
        timeoutTask = Task.detached(priority: nil) { [weak self] in
            do {
                try await Task.sleep(for: .seconds(15))
            } catch {
                return
            }
            self?.failConnection()
        }
    }

    func failConnection() {
        finish(
            .failure(
                LifecycleInteractiveSessionXPCError.connectionFailed
            )
        )
    }

    func resolve(response: Data?, reasonKey: String?) {
        guard reasonKey == nil else {
            finish(
                .failure(
                    LifecycleInteractiveSessionXPCError.invalidPeer
                )
            )
            return
        }
        guard
            let response,
            response.count <= LifecycleHelperPeerAttestationRequest
                .maximumEncodedBytes,
            let decoded = try? JSONDecoder().decode(
                LifecycleHelperPeerAttestationResponse.self,
                from: response
            )
        else {
            finish(
                .failure(
                    LifecycleInteractiveSessionXPCError.invalidPeer
                )
            )
            return
        }
        finish(.success(decoded))
    }

    private func finish(
        _ result: Result<
            LifecycleHelperPeerAttestationResponse,
            any Error
        >
    ) {
        let continuation = lock.withLock {
            let value = self.continuation
            self.continuation = nil
            let timeoutTask = self.timeoutTask
            self.timeoutTask = nil
            return (value, timeoutTask)
        }
        continuation.1?.cancel()
        continuation.0?.resume(with: result)
    }
}

final class LifecycleInteractiveSessionXPCReplyResolver:
    @unchecked Sendable
{
    private let lock = NSLock()
    private let request: LifecycleInteractiveSessionRequest
    private var finished = false
    private var continuation:
        CheckedContinuation<
            LifecycleInteractiveSessionResponse,
            any Error
        >?
    private var pendingResult:
        Result<LifecycleInteractiveSessionResponse, any Error>?
    private var timeoutTask: Task<Void, Never>?
    private var dispatchBegan = false

    init(request: LifecycleInteractiveSessionRequest) {
        self.request = request
    }

    convenience init(
        request: LifecycleInteractiveSessionRequest,
        continuation:
            CheckedContinuation<
                LifecycleInteractiveSessionResponse,
                any Error
            >
    ) {
        self.init(request: request)
        _ = install(continuation)
    }

    func install(
        _ continuation:
            CheckedContinuation<
                LifecycleInteractiveSessionResponse,
                any Error
            >
    ) -> Bool {
        let pending = lock.withLock {
            if finished {
                return pendingResult
            }
            self.continuation = continuation
            return nil
        }
        if let pending {
            continuation.resume(with: pending)
            return false
        }
        return true
    }

    func scheduleTimeout(seconds: Int) {
        guard seconds > 0 else {
            failTimeout()
            return
        }
        let task = Task.detached(priority: nil) { [self] in
            do {
                try await Task.sleep(for: .seconds(seconds))
            } catch {
                return
            }
            failTimeout()
        }
        let cancel = lock.withLock {
            guard !finished else {
                return true
            }
            timeoutTask = task
            return false
        }
        if cancel {
            task.cancel()
        }
    }

    func beginDispatch() -> Bool {
        lock.withLock {
            guard !finished, !dispatchBegan else {
                return false
            }
            dispatchBegan = true
            return true
        }
    }

    func failConnection() {
        finish(
            .failure(
                LifecycleInteractiveSessionXPCError.connectionFailed
            )
        )
    }

    func failTimeout() {
        finish(
            .failure(
                LifecycleInteractiveSessionXPCError.timedOut
            )
        )
    }

    func failCancellation() {
        guard request.kind != .retire else {
            return
        }
        finish(
            .failure(
                LifecycleInteractiveSessionXPCError.cancelled
            ),
            onlyBeforeDispatch: true
        )
    }

    func resolve(
        response: Data?,
        reasonKey: String?
    ) {
        if let reasonKey {
            finish(
                .failure(
                    LifecycleInteractiveSessionXPCError.remoteRejected(
                        reasonKey:
                            sanitizedLifecycleInteractiveReasonKey(
                                reasonKey
                            )
                    )
                )
            )
            return
        }
        guard
            let response,
            response.count <= LifecycleInteractiveSessionRequest
                .maximumEncodedEnvelopeBytes,
            let decoded = try? JSONDecoder().decode(
                LifecycleInteractiveSessionResponse.self,
                from: response
            ),
            let validated = try? decoded.validated(for: request)
        else {
            finish(
                .failure(
                    LifecycleInteractiveSessionXPCError.invalidResponse
                )
            )
            return
        }
        finish(.success(validated))
    }

    private func finish(
        _ result: Result<
            LifecycleInteractiveSessionResponse,
            any Error
        >,
        onlyBeforeDispatch: Bool = false
    ) {
        let completion = lock.withLock {
            guard
                !finished,
                !onlyBeforeDispatch || !dispatchBegan
            else {
                return (
                    nil as CheckedContinuation<
                        LifecycleInteractiveSessionResponse,
                        any Error
                    >?,
                    nil as Task<Void, Never>?
                )
            }
            finished = true
            let value = self.continuation
            self.continuation = nil
            if value == nil {
                pendingResult = result
            }
            let timeout = timeoutTask
            timeoutTask = nil
            return (value, timeout)
        }
        completion.1?.cancel()
        completion.0?.resume(with: result)
    }
}

private func sanitizedLifecycleInteractiveReasonKey(
    _ value: String
) -> String {
    let allowed = Set([
        "runtime.lifecycle.interactive.invalid-request",
        "runtime.lifecycle.interactive.session-unavailable",
        "runtime.lifecycle.interactive.session-mismatch",
        "runtime.lifecycle.interactive.session-expired",
        "runtime.lifecycle.interactive.line-limit-exceeded",
        "runtime.lifecycle.interactive.session-limit-exceeded",
        "runtime.lifecycle.interactive.start-failed",
        "runtime.lifecycle.interactive.write-failed",
        "runtime.lifecycle.interactive.read-failed",
        "runtime.lifecycle.interactive.retire-failed",
        "runtime.lifecycle.interactive.remote-rejected",
    ])
    return allowed.contains(value)
        ? value
        : "runtime.lifecycle.interactive.remote-rejected"
}

private func lifecycleIdentityMatchesAuditToken(
    _ identity: LifecycleProcessIdentity
) -> Bool {
    guard identity.auditToken.words.count == LifecycleAuditToken.wordCount
    else {
        return false
    }
    var token = audit_token_t()
    let copied = withUnsafeMutableBytes(of: &token) { destination in
        identity.auditToken.words.withUnsafeBytes { source in
            guard destination.count == source.count else {
                return false
            }
            destination.copyBytes(from: source)
            return true
        }
    }
    return copied
        && audit_token_to_pid(token) == identity.processID
        && audit_token_to_pidversion(token)
            == identity.processIDVersion
        && audit_token_to_asid(token) == identity.auditSessionID
        && audit_token_to_euid(token) == identity.effectiveUserID
}

public func lifecycleContainingAppURL(
    helperExecutableURL: URL
) -> URL? {
    guard
        helperExecutableURL.isFileURL,
        helperExecutableURL.lastPathComponent
            == "StornautLifecycleHelper",
        helperExecutableURL.deletingLastPathComponent()
            .lastPathComponent == "MacOS"
    else {
        return nil
    }
    let contents = helperExecutableURL
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let app = contents.deletingLastPathComponent()
    guard
        contents.lastPathComponent == "Contents",
        app.pathExtension == "app"
    else {
        return nil
    }
    return app.standardizedFileURL
}
