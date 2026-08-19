import Darwin
import Foundation
import StornautInvestigation
import StornautLifecycle

enum InvestigationMachineRetirementClaimError:
    Error,
    Sendable,
    Equatable
{
    case rootAuthorityRequired
    case invalidWindow
    case sourceFailed
    case outcomeUnknown
    case responseMismatch
    case identityMismatch
    case helperPeerMismatch
    case signingIdentityMismatch
    case configurationMismatch
    case staleClaim
    case consumed
    case empty
}

enum InvestigationMachineRetirementClaimSourceError:
    Error,
    Sendable,
    Equatable
{
    case outcomeUnknown
}

protocol InvestigationMachineRetirementClaimSource: Sendable {
    func fetch(
        request: LifecycleMachineRetirementClaimRequest
    ) async throws -> (
        LifecycleMachineRetirementClaimResponse,
        LifecycleProcessIdentity,
        Date
    )
}

protocol InvestigationMachineRetirementHelperSigningVerifying: Sendable {
    func verifies(
        helperIdentity: LifecycleProcessIdentity
    ) -> Bool
}

struct InvestigationMachineRetirementClaim:
    Sendable,
    Equatable
{
    private let reservation =
        InvestigationMachineRetirementClaimReservation()
    let request: LifecycleMachineRetirementClaimRequest
    let appIdentity: LifecycleMachineProcessIdentityRecord
    let helperIdentity: LifecycleMachineProcessIdentityRecord
    let helperPeerIdentity: LifecycleProcessIdentity
    let helperPeerAttestedAt: Date
    let configurationSHA256: String
    let userID: UInt32
    let recordedAt: Date
    let claimedAt: Date
    let ownerRetirementObservation:
        LifecycleInteractiveWorkerRetirementObservation
    let residueObservation: LifecycleInvestigationResidueObservation

    init(
        response: LifecycleMachineRetirementClaimResponse,
        helperPeerIdentity: LifecycleProcessIdentity,
        helperPeerAttestedAt: Date
    ) {
        request = response.request
        appIdentity = response.appIdentity
        helperIdentity = response.helperIdentity
        self.helperPeerIdentity = helperPeerIdentity
        self.helperPeerAttestedAt = helperPeerAttestedAt
        configurationSHA256 =
            response.request.handle.configurationSHA256
        userID = response.userID
        recordedAt = response.recordedAt
        claimedAt = response.claimedAt
        ownerRetirementObservation =
            response.ownerRetirementObservation
        residueObservation = response.residueObservation
    }

    fileprivate func reserveOnce() -> Bool {
        reservation.reserveOnce()
    }
}

private final class InvestigationMachineRetirementClaimReservation:
    @unchecked Sendable,
    Equatable
{
    private let lock = NSLock()
    private var reserved = false

    func reserveOnce() -> Bool {
        lock.withLock {
            guard !reserved else { return false }
            reserved = true
            return true
        }
    }

    static func == (
        lhs: InvestigationMachineRetirementClaimReservation,
        rhs: InvestigationMachineRetirementClaimReservation
    ) -> Bool {
        lhs === rhs
    }
}

struct InvestigationMachineRetirementClaimant: Sendable {
    static let maximumClaimWindow: TimeInterval = 15

    private let source: any InvestigationMachineRetirementClaimSource
    private let signingVerifier:
        any InvestigationMachineRetirementHelperSigningVerifying
    private let effectiveUserID: @Sendable () -> uid_t
    private let now: @Sendable () -> Date
    private let challenge: @Sendable () -> UUID
    private let claimWindow: TimeInterval
    private let expectedAppIdentity:
        LifecycleMachineProcessIdentityRecord
    private let expectedUserID: UInt32
    private let expectedInvestigationID: LifecycleInvestigationID
    private let expectedConfigurationSHA256: String

    init(
        source: any InvestigationMachineRetirementClaimSource,
        signingVerifier:
            any InvestigationMachineRetirementHelperSigningVerifying,
        effectiveUserID: @escaping @Sendable () -> uid_t = geteuid,
        now: @escaping @Sendable () -> Date = Date.init,
        challenge: @escaping @Sendable () -> UUID = UUID.init,
        claimWindow: TimeInterval = Self.maximumClaimWindow,
        configuration:
            SignedInvestigationRuntimeDiagnosticConfiguration,
        expectedAppIdentity: LifecycleMachineProcessIdentityRecord,
        expectedUserID: UInt32
    ) throws {
        self.source = source
        self.signingVerifier = signingVerifier
        self.effectiveUserID = effectiveUserID
        self.now = now
        self.challenge = challenge
        self.claimWindow = claimWindow
        self.expectedAppIdentity = expectedAppIdentity
        self.expectedUserID = expectedUserID
        expectedInvestigationID = LifecycleInvestigationID(
            rawValue: configuration.nonce
        )
        expectedConfigurationSHA256 =
            try configuration.machineConfigurationSHA256()
    }

    func claim(
        handle: LifecycleMachineRetirementHandle
    ) async throws -> InvestigationMachineRetirementClaim {
        try Task.checkCancellation()
        guard effectiveUserID() == 0 else {
            throw InvestigationMachineRetirementClaimError
                .rootAuthorityRequired
        }
        guard
            handle.investigationID == expectedInvestigationID,
            handle.configurationSHA256
                == expectedConfigurationSHA256
        else {
            throw InvestigationMachineRetirementClaimError
                .configurationMismatch
        }
        guard
            claimWindow > 0,
            claimWindow <= Self.maximumClaimWindow,
            claimWindow.isFinite
        else {
            throw InvestigationMachineRetirementClaimError.invalidWindow
        }

        let issuedAt = now()
        let validBefore = min(
            issuedAt.addingTimeInterval(claimWindow),
            handle.validBefore
        )
        guard
            issuedAt.timeIntervalSince1970.isFinite,
            validBefore.timeIntervalSince1970.isFinite,
            validBefore > issuedAt
        else {
            throw InvestigationMachineRetirementClaimError.invalidWindow
        }
        let request: LifecycleMachineRetirementClaimRequest
        do {
            request = try LifecycleMachineRetirementClaimRequest(
                handle: handle,
                challengeNonce: challenge(),
                issuedAt: issuedAt,
                validBefore: validBefore
            )
        } catch {
            throw InvestigationMachineRetirementClaimError.invalidWindow
        }

        let response: LifecycleMachineRetirementClaimResponse
        let helperPeerIdentity: LifecycleProcessIdentity
        let helperPeerAttestedAt: Date
        do {
            (response, helperPeerIdentity, helperPeerAttestedAt) =
                try await source.fetch(request: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch InvestigationMachineRetirementClaimSourceError.outcomeUnknown {
            throw InvestigationMachineRetirementClaimError.outcomeUnknown
        } catch {
            try Task.checkCancellation()
            throw InvestigationMachineRetirementClaimError.sourceFailed
        }
        try Task.checkCancellation()

        try validate(
            response: response,
            request: request,
            helperPeerIdentity: helperPeerIdentity,
            helperPeerAttestedAt: helperPeerAttestedAt,
            at: now()
        )
        return InvestigationMachineRetirementClaim(
            response: response,
            helperPeerIdentity: helperPeerIdentity,
            helperPeerAttestedAt: helperPeerAttestedAt
        )
    }

    private func validate(
        response: LifecycleMachineRetirementClaimResponse,
        request: LifecycleMachineRetirementClaimRequest,
        helperPeerIdentity: LifecycleProcessIdentity,
        helperPeerAttestedAt: Date,
        at now: Date
    ) throws {
        guard response.request == request else {
            throw InvestigationMachineRetirementClaimError.responseMismatch
        }
        guard
            request.validBefore > request.issuedAt,
            request.validBefore.timeIntervalSince1970.isFinite,
            now >= request.issuedAt,
            now <= request.validBefore,
            response.claimedAt >= request.issuedAt,
            response.claimedAt <= request.validBefore,
            response.recordedAt.timeIntervalSince1970.isFinite,
            response.recordedAt <= request.issuedAt,
            helperPeerAttestedAt >= request.issuedAt,
            helperPeerAttestedAt <= now,
            helperPeerAttestedAt <= request.validBefore,
            response.claimedAt.timeIntervalSince1970.isFinite
        else {
            throw InvestigationMachineRetirementClaimError.staleClaim
        }
        guard
            validAppIdentity(response.appIdentity),
            response.appIdentity == expectedAppIdentity,
            response.userID == response.appIdentity.effectiveUserID,
            response.userID > 0,
            response.userID == expectedUserID,
            validHelperIdentity(response.helperIdentity),
            response.request.handle.investigationID
                == response.residueObservation.investigationID,
            response.request.handle.investigationID
                == expectedInvestigationID,
            response.request.handle.configurationSHA256
                == expectedConfigurationSHA256,
            response.residueObservation.userID == response.userID,
            response.residueObservation.auditSessionID
                == response.helperIdentity.auditSessionID,
            response.ownerRetirementObservation
                == .retiredOwnedResources,
            response.residueObservation.provedEmpty
        else {
            throw InvestigationMachineRetirementClaimError.identityMismatch
        }
        guard
            processIdentityRecord(
                response.helperIdentity,
                matches: helperPeerIdentity
            ),
            helperPeerIdentity.effectiveUserID == 0,
            signingVerifier.verifies(
                helperIdentity: helperPeerIdentity
            )
        else {
            if processIdentityRecord(
                response.helperIdentity,
                matches: helperPeerIdentity
            ) {
                throw InvestigationMachineRetirementClaimError
                    .signingIdentityMismatch
            }
            throw InvestigationMachineRetirementClaimError.helperPeerMismatch
        }
    }

    private func validAppIdentity(
        _ identity: LifecycleMachineProcessIdentityRecord
    ) -> Bool {
        identity.processID > 1
            && identity.processIDVersion > 0
            && identity.auditSessionID > 0
            && identity.effectiveUserID > 0
            && identity.auditTokenWords.count == LifecycleAuditToken.wordCount
    }

    private func validHelperIdentity(
        _ identity: LifecycleMachineProcessIdentityRecord
    ) -> Bool {
        identity.processID > 1
            && identity.processIDVersion > 0
            && identity.auditSessionID > 0
            && identity.effectiveUserID == 0
            && identity.auditTokenWords.count == LifecycleAuditToken.wordCount
    }

    private func processIdentityRecord(
        _ record: LifecycleMachineProcessIdentityRecord,
        matches identity: LifecycleProcessIdentity
    ) -> Bool {
        record.processID == identity.processID
            && record.processIDVersion == identity.processIDVersion
            && record.auditSessionID == identity.auditSessionID
            && record.effectiveUserID == identity.effectiveUserID
            && record.auditTokenWords == identity.auditToken.words
    }
}

actor InvestigationMachineRetirementClaimStore {
    private enum State {
        case empty
        case recorded(InvestigationMachineRetirementClaim)
        case consumed
    }

    private var state = State.empty

    var isAwaitingClaim: Bool {
        if case .recorded = state { return true }
        return false
    }

    func record(
        _ claim: InvestigationMachineRetirementClaim
    ) throws {
        guard case .empty = state else {
            state = .consumed
            throw InvestigationMachineRetirementClaimError.consumed
        }
        guard claim.reserveOnce() else {
            state = .consumed
            throw InvestigationMachineRetirementClaimError.consumed
        }
        state = .recorded(claim)
    }

    func consume() throws -> InvestigationMachineRetirementClaim {
        guard case let .recorded(claim) = state else {
            let error = stateError()
            state = .consumed
            throw error
        }
        state = .consumed
        return claim
    }

    func invalidate() {
        state = .consumed
    }

    private func stateError() -> InvestigationMachineRetirementClaimError {
        switch state {
        case .empty:
            return .empty
        case .recorded, .consumed:
            return .consumed
        }
    }
}
