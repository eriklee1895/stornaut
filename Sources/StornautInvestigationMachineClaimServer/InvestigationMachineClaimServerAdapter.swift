import CryptoKit
import Foundation
import StornautInvestigationHandoffContract
import StornautLifecycle

package enum InvestigationMachineClaimServerError:
    Error,
    Sendable,
    Equatable
{
    case invalidRequest
    case bindingMismatch
    case duplicateOrReplay
    case expired
    case unavailable
}

private struct InvestigationMachineClaimServerProjection: Sendable {
    let tokenSHA256: Data
    let investigationUUID: UUID
    let retireOperationUUID: UUID
    let configurationSHA256: Data
    let handleValidBeforeUTCMicroseconds: Int64
    let appIdentity: InvestigationMachineProcessIdentity
    let helperIdentity: InvestigationMachineProcessIdentity
    let helperIdentitySHA256: InvestigationHandoffSHA256
    let appUserID: UInt32
    let recordedAt: InvestigationHandoffUTCMicroseconds
    let ownerRetirement: InvestigationMachineOwnerRetirement
    let l1Residue: InvestigationMachineL1Residue

    init(
        transfer: LifecycleMachineRetirementReservationTransfer
    ) throws {
        let configuration: InvestigationHandoffSHA256
        let validBefore: InvestigationHandoffUTCMicroseconds
        let recordedAt: InvestigationHandoffUTCMicroseconds
        let residueObservedAt: InvestigationHandoffUTCMicroseconds
        let appIdentity: InvestigationMachineProcessIdentity
        let helperIdentity: InvestigationMachineProcessIdentity
        let helperIdentitySHA256: InvestigationHandoffSHA256
        let ownerRetirement: InvestigationMachineOwnerRetirement
        let l1Residue: InvestigationMachineL1Residue
        do {
            configuration = try InvestigationHandoffSHA256(
                lowercaseHex: transfer.configurationSHA256
            )
            validBefore = try InvestigationHandoffUTCMicroseconds(
                timeIntervalSince1970:
                    transfer.validBefore.timeIntervalSince1970
            )
            recordedAt = try InvestigationHandoffUTCMicroseconds(
                timeIntervalSince1970:
                    transfer.recordedAt.timeIntervalSince1970
            )
            residueObservedAt = try InvestigationHandoffUTCMicroseconds(
                timeIntervalSince1970:
                    transfer.residueObservation.observedAt
                        .timeIntervalSince1970
            )
            appIdentity = try handoffIdentity(
                transfer.appIdentity, role: .app
            )
            helperIdentity = try handoffIdentity(
                transfer.helperIdentity, role: .helper
            )
            helperIdentitySHA256 = try helperIdentity.helperIdentitySHA256()
            ownerRetirement = try handoffOwnerRetirement(
                transfer.ownerRetirementObservation
            )
            l1Residue = try handoffL1Residue(
                transfer.residueObservation,
                observedAt: residueObservedAt
            )
        } catch {
            throw InvestigationMachineClaimServerError.invalidRequest
        }
        let residueAge = recordedAt.rawValue.subtractingReportingOverflow(
            residueObservedAt.rawValue
        )
        guard
            transfer.tokenSHA256.count == 32,
            !transfer.investigationID.rawValue.claimServerIsZero,
            !transfer.retireOperationID.claimServerIsZero,
            transfer.appIdentity.effectiveUserID == transfer.userID,
            transfer.helperIdentity.effectiveUserID == 0,
            transfer.appIdentity.processID != transfer.helperIdentity.processID,
            transfer.userID == 501,
            transfer.ownerRetirementObservation == .retiredOwnedResources,
            transfer.residueObservation.provedEmpty,
            transfer.residueObservation.investigationID
                == transfer.investigationID,
            transfer.residueObservation.auditSessionID
                == transfer.helperIdentity.auditSessionID,
            transfer.residueObservation.userID == transfer.userID,
            !residueAge.overflow,
            (0...60_000_000).contains(residueAge.partialValue),
            recordedAt < validBefore
        else {
            throw InvestigationMachineClaimServerError.invalidRequest
        }
        tokenSHA256 = transfer.tokenSHA256
        investigationUUID = transfer.investigationID.rawValue
        retireOperationUUID = transfer.retireOperationID
        configurationSHA256 = configuration.rawBytes
        handleValidBeforeUTCMicroseconds = validBefore.rawValue
        self.appIdentity = appIdentity
        self.helperIdentity = helperIdentity
        self.helperIdentitySHA256 = helperIdentitySHA256
        appUserID = transfer.userID
        self.recordedAt = recordedAt
        self.ownerRetirement = ownerRetirement
        self.l1Residue = l1Residue
    }
}

package final class InvestigationMachineClaimServerAdapter:
    @unchecked Sendable
{
    private let projection: InvestigationMachineClaimServerProjection
    private let reservationID: UUID
    private let clock: any InvestigationMachineClaimServerClock
    private let state: LifecycleMachineRetirementEscrowDeadlineState
    private let executor: InvestigationMachineClaimServerEffectExecutor
    private let evidenceLock = NSLock()
    private var evidence: InvestigationMachineClaimEvidence?

    package init(
        transfer: LifecycleMachineRetirementReservationTransfer,
        reservationID: UUID,
        clock: any InvestigationMachineClaimServerClock,
        state: LifecycleMachineRetirementEscrowDeadlineState,
        executor: InvestigationMachineClaimServerEffectExecutor
    ) throws {
        guard !reservationID.claimServerIsZero else {
            throw InvestigationMachineClaimServerError.invalidRequest
        }
        projection = try InvestigationMachineClaimServerProjection(
            transfer: transfer
        )
        self.reservationID = reservationID
        self.clock = clock
        self.state = state
        self.executor = executor
        let observation: LifecycleMachineRetirementDeadlineObservation
        do {
            observation = try clock.observation()
        } catch {
            throw InvestigationMachineClaimServerError.unavailable
        }
        let reservation = try LifecycleMachineRetirementDeadlineReservation(
            reservationID: reservationID,
            handleValidBeforeUTCMicroseconds:
                projection.handleValidBeforeUTCMicroseconds,
            observation: observation
        )
        try apply(state.reserve(reservation))
        guard state.phase == .awaitingClaim else {
            throw InvestigationMachineClaimServerError.unavailable
        }
    }

    package func claim(_ requestData: Data) throws -> Data {
        let request: InvestigationMachineRetirementClaimRequest
        do {
            try InvestigationMachineClaimXPCRequest.validateClaim(requestData)
            request = try InvestigationMachineRetirementClaimRequest.decode(
                requestData
            )
        } catch {
            throw InvestigationMachineClaimServerError.invalidRequest
        }
        guard claimMatchesProjection(request) else {
            rejectBinding()
            throw InvestigationMachineClaimServerError.bindingMismatch
        }
        let observation = try nextObservation()
        let claimedAt = try InvestigationHandoffUTCMicroseconds(
            rawValue: observation.wallUTCMicroseconds
        )
        let requestDigest = try request.bindingSHA256()
        let semantic = try LifecycleMachineRetirementDeadlineClaim(
            reservationID: reservationID,
            requestBindingSHA256: LifecycleMachineRetirementDeadlineDigest(
                rawBytes: requestDigest.rawBytes
            ),
            helperIdentitySHA256: LifecycleMachineRetirementDeadlineDigest(
                rawBytes: projection.helperIdentitySHA256.rawBytes
            ),
            claimChallenge: request.claimChallenge,
            connectionEpoch: request.claimConnectionEpoch,
            requestIssuedAtUTCMicroseconds: request.issuedAt.rawValue,
            requestValidBeforeUTCMicroseconds:
                request.requestValidBefore.rawValue,
            epochDeadlineNanoseconds: request.epochDeadlineNanoseconds,
            observation: observation
        )
        let transition = state.claim(semantic)
        try apply(transition)
        try requireApplied(transition)
        let releaseDeadline = try requireValue(
            transition.releaseDeadlineNanoseconds
        )
        let value = try InvestigationMachineClaimEvidence(
            requestBindingSHA256: requestDigest,
            originalClaimChallenge: request.claimChallenge,
            claimConnectionEpoch: request.claimConnectionEpoch,
            appIdentity: projection.appIdentity,
            helperIdentity: projection.helperIdentity,
            appUserID: projection.appUserID,
            recordedAt: projection.recordedAt,
            claimedAt: claimedAt,
            ownerRetirement: projection.ownerRetirement,
            l1Residue: projection.l1Residue,
            releaseDeadlineNanoseconds: releaseDeadline
        )
        let encoded = try value.encoded()
        evidenceLock.withLock { evidence = value }
        let committed = state.commitClaimResponse(
            reservationID: reservationID,
            connectionEpoch: request.claimConnectionEpoch
        )
        try? executor.apply(committed, to: state)
        do {
            try requireApplied(committed)
        } catch {
            evidenceLock.withLock {
                if evidence == value { evidence = nil }
            }
            throw error
        }
        return encoded
    }

    package func release(_ releaseData: Data) throws -> Data {
        let release: InvestigationMachineClaimRelease
        do {
            try InvestigationMachineClaimXPCRequest.validateRelease(releaseData)
            release = try InvestigationMachineClaimRelease.decode(releaseData)
        } catch {
            rejectBinding()
            throw InvestigationMachineClaimServerError.bindingMismatch
        }
        guard let evidence = evidenceLock.withLock({ evidence }) else {
            rejectBinding()
            throw InvestigationMachineClaimServerError.bindingMismatch
        }
        let expectedHelperDigest = try evidence.helperIdentity
            .helperIdentitySHA256()
        guard
            constantTimeEqual(
                release.requestBindingSHA256.rawBytes,
                evidence.requestBindingSHA256.rawBytes
            ),
            constantTimeEqual(
                release.claimedHelperIdentitySHA256.rawBytes,
                expectedHelperDigest.rawBytes
            ),
            release.claimConnectionEpoch == evidence.claimConnectionEpoch,
            release.releaseDeadlineNanoseconds
                == evidence.releaseDeadlineNanoseconds
        else {
            rejectBinding()
            throw InvestigationMachineClaimServerError.bindingMismatch
        }
        let observation = try nextObservation()
        let semantic = try LifecycleMachineRetirementDeadlineRelease(
            reservationID: reservationID,
            requestBindingSHA256: LifecycleMachineRetirementDeadlineDigest(
                rawBytes: release.requestBindingSHA256.rawBytes
            ),
            helperIdentitySHA256: LifecycleMachineRetirementDeadlineDigest(
                rawBytes: release.claimedHelperIdentitySHA256.rawBytes
            ),
            connectionEpoch: release.claimConnectionEpoch,
            releaseChallenge: release.releaseChallenge,
            releaseDeadlineNanoseconds:
                release.releaseDeadlineNanoseconds,
            observation: observation
        )
        let transition = state.release(semantic)
        try apply(transition)
        try requireApplied(transition)
        let postReplyDeadline = try requireValue(
            transition.postReplyExitDeadlineNanoseconds
        )
        let encoded = try InvestigationMachineClaimReleased(
            requestBindingSHA256: release.requestBindingSHA256,
            releaseChallenge: release.releaseChallenge,
            claimedHelperIdentitySHA256:
                release.claimedHelperIdentitySHA256,
            claimConnectionEpoch: release.claimConnectionEpoch,
            exitScheduled: true,
            postReplyExitDeadlineNanoseconds: postReplyDeadline
        ).encoded()
        let committed = state.commitReleaseResponse(
            reservationID: reservationID,
            connectionEpoch: release.claimConnectionEpoch,
            releaseChallenge: release.releaseChallenge
        )
        try? executor.apply(committed, to: state)
        try requireApplied(committed)
        return encoded
    }

    package func replyDidDispatch() throws {
        guard let evidence = evidenceLock.withLock({ evidence }) else {
            rejectBinding()
            throw InvestigationMachineClaimServerError.bindingMismatch
        }
        let observation = try nextObservation()
        let transition = state.replyDidDispatch(
            reservationID: reservationID,
            connectionEpoch: evidence.claimConnectionEpoch,
            observation: observation
        )
        try apply(transition)
        try requireApplied(transition)
    }

    private func claimMatchesProjection(
        _ request: InvestigationMachineRetirementClaimRequest
    ) -> Bool {
        request.handle.investigationUUID == projection.investigationUUID
            && request.handle.retireOperationUUID
                == projection.retireOperationUUID
            && constantTimeEqual(
                request.handle.configurationSHA256.rawBytes,
                projection.configurationSHA256
            )
            && request.handle.validBefore.rawValue
                == projection.handleValidBeforeUTCMicroseconds
            && constantTimeEqual(
                claimServerTokenDigest(request.handle.token),
                projection.tokenSHA256
            )
            && projection.recordedAt.rawValue <= request.issuedAt.rawValue
    }

    private func nextObservation() throws
        -> LifecycleMachineRetirementDeadlineObservation
    {
        do {
            return try clock.observation()
        } catch {
            let transition = state.rejectOperationObservation(
                reservationID: reservationID
            )
            try? executor.apply(transition, to: state)
            throw InvestigationMachineClaimServerError.unavailable
        }
    }

    private func rejectBinding() {
        let transition = state.rejectBinding(reservationID: reservationID)
        try? executor.apply(transition, to: state)
    }

    private func apply(
        _ transition: LifecycleMachineRetirementDeadlineTransition
    ) throws {
        do {
            try executor.apply(transition, to: state)
        } catch {
            throw InvestigationMachineClaimServerError.unavailable
        }
    }

    private func requireApplied(
        _ transition: LifecycleMachineRetirementDeadlineTransition
    ) throws {
        switch transition.disposition {
        case .applied:
            return
        case .stale:
            throw InvestigationMachineClaimServerError.unavailable
        case let .terminal(reason):
            switch reason {
            case .bindingMismatch:
                throw InvestigationMachineClaimServerError.bindingMismatch
            case .duplicateOrReplay:
                throw InvestigationMachineClaimServerError.duplicateOrReplay
            case .claimDeadlineExpired, .releaseDeadlineExpired,
                 .postReplyDeadlineExpiredBeforeDispatch:
                throw InvestigationMachineClaimServerError.expired
            default:
                throw InvestigationMachineClaimServerError.unavailable
            }
        }
    }
}

private func handoffOwnerRetirement(
    _ observation: LifecycleInteractiveWorkerRetirementObservation
) throws -> InvestigationMachineOwnerRetirement {
    guard
        observation.resourceOwnership == .owned,
        observation.processGroupTerminated,
        observation.standardErrorContained,
        observation.workspaceRemoved
    else {
        throw InvestigationMachineClaimServerError.invalidRequest
    }
    return InvestigationMachineOwnerRetirement()
}

private func handoffL1Residue(
    _ observation: LifecycleInvestigationResidueObservation,
    observedAt: InvestigationHandoffUTCMicroseconds
) throws -> InvestigationMachineL1Residue {
    guard
        let auditSessionID = UInt32(exactly: observation.auditSessionID),
        let remainingMembers = UInt32(
            exactly: observation.remainingAuditSessionMemberCount
        ),
        let matchingLeases = UInt32(exactly: observation.matchingLeaseCount),
        let leaseRootEntries = UInt32(
            exactly: observation.leaseRootEntryCount
        ),
        let investigationArtifacts = UInt32(
            exactly: observation.investigationArtifactCount
        )
    else {
        throw InvestigationMachineClaimServerError.invalidRequest
    }
    return try InvestigationMachineL1Residue(
        investigationUUID: observation.investigationID.rawValue,
        auditSessionID: auditSessionID,
        userID: observation.userID,
        observedAt: observedAt,
        remainingAuditSessionMembers: remainingMembers,
        matchingLeases: matchingLeases,
        leaseRootEntries: leaseRootEntries,
        investigationArtifacts: investigationArtifacts
    )
}

private func handoffIdentity(
    _ value: LifecycleMachineProcessIdentityRecord,
    role: InvestigationMachineProcessRole
) throws -> InvestigationMachineProcessIdentity {
    try InvestigationMachineProcessIdentity(
        role: role,
        processID: UInt32(value.processID),
        processIDVersion: UInt32(value.processIDVersion),
        auditSessionID: UInt32(value.auditSessionID),
        effectiveUserID: value.effectiveUserID,
        auditTokenWords: value.auditTokenWords
    )
}

private func claimServerTokenDigest(_ token: UUID) -> Data {
    var raw = token.uuid
    return withUnsafeBytes(of: &raw) { Data(SHA256.hash(data: Data($0))) }
}

private func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
    guard lhs.count == rhs.count else { return false }
    var difference: UInt8 = 0
    for index in lhs.indices { difference |= lhs[index] ^ rhs[index] }
    return difference == 0
}

private extension UUID {
    var claimServerIsZero: Bool {
        uuidString == "00000000-0000-0000-0000-000000000000"
    }
}

private func requireValue<T>(_ value: T?) throws -> T {
    guard let value else {
        throw InvestigationMachineClaimServerError.unavailable
    }
    return value
}
