import CryptoKit
import Foundation
import StornautInvestigationHandoffContract
import StornautLifecycle

public final class InvestigationMachineClaimServer: @unchecked Sendable {
    private struct ActiveRuntime {
        let adapter: InvestigationMachineClaimServerAdapter
        let state: LifecycleMachineRetirementEscrowDeadlineState
    }

    private let retirementEscrow: LifecycleMachineRetirementEscrow
    private let runtime: InvestigationMachineClaimServerRuntime
    private let lock = NSLock()
    private var activationAttempted = false
    private var activationInProgress = false
    private var activeRuntime: ActiveRuntime?
    private var activeSession: InvestigationMachineClaimServerSession?
    private var cancellationRequested = false

    public init(
        retirementEscrow: LifecycleMachineRetirementEscrow,
        clock: any InvestigationMachineClaimServerClock,
        scheduler: any InvestigationMachineClaimServerScheduling,
        terminal: any InvestigationMachineClaimServerTerminalHandling
    ) {
        self.retirementEscrow = retirementEscrow
        runtime = InvestigationMachineClaimServerRuntime(
            clock: clock, scheduler: scheduler, terminal: terminal
        )
    }

    public func activate() throws {
        guard lock.withLock({
            guard !activationAttempted else { return false }
            activationAttempted = true
            activationInProgress = true
            return true
        }) else {
            throw InvestigationMachineClaimServerError.unavailable
        }

        do {
            let transfer = try retirementEscrow.transferReservation()
            let state = LifecycleMachineRetirementEscrowDeadlineState()
            let executor = InvestigationMachineClaimServerEffectExecutor(
                clock: runtime.clock,
                scheduler: runtime.scheduler,
                terminal: runtime.terminal
            )
            let adapter = try InvestigationMachineClaimServerAdapter(
                transfer: transfer,
                clock: runtime.clock,
                state: state,
                executor: executor
            )
            let didPublish = lock.withLock {
                activationInProgress = false
                guard !cancellationRequested else { return false }
                activeRuntime = ActiveRuntime(adapter: adapter, state: state)
                return true
            }
            guard didPublish else {
                adapter.cancel()
                throw InvestigationMachineClaimServerError.unavailable
            }
        } catch {
            lock.withLock { activationInProgress = false }
            runtime.terminalGate.handle(.cancelled)
            throw error
        }
    }

    public func makeSession() throws
        -> InvestigationMachineClaimServerSession
    {
        try lock.withLock {
            guard !cancellationRequested else {
                throw InvestigationMachineClaimServerError.unavailable
            }
            guard activeSession == nil else {
                throw InvestigationMachineClaimServerError.duplicateOrReplay
            }
            guard let activeRuntime else {
                throw InvestigationMachineClaimServerError.unavailable
            }
            if case .terminal = activeRuntime.state.phase {
                throw InvestigationMachineClaimServerError.unavailable
            }
            let session = InvestigationMachineClaimServerSession(
                adapter: activeRuntime.adapter
            )
            activeSession = session
            return session
        }
    }

    public func isPending() -> Bool {
        let snapshot = lock.withLock {
            (activationAttempted, activationInProgress, activeRuntime?.state)
        }
        if snapshot.1 { return true }
        if let state = snapshot.2 {
            let phase = state.phase
            if case .terminal = phase { return false }
            return phase != .empty
        }
        if !snapshot.0 {
            return retirementEscrow.isAwaitingClaim
        }
        return false
    }

    public func cancel() {
        let adapter: InvestigationMachineClaimServerAdapter? = lock.withLock {
            activationAttempted = true
            cancellationRequested = true
            return activeRuntime?.adapter
        }
        if let adapter {
            adapter.cancel()
        } else {
            runtime.terminalGate.handle(.cancelled)
        }
    }
}

public final class InvestigationMachineClaimServerSession:
    NSObject,
    InvestigationMachineClaimXPCWire,
    @unchecked Sendable
{
    private let adapter: InvestigationMachineClaimServerAdapter
    private let lock = NSLock()
    private var invalidated = false
    private var operationInProgress = false
    private var invalidationDeferred = false

    fileprivate init(adapter: InvestigationMachineClaimServerAdapter) {
        self.adapter = adapter
    }

    public func claimMachineRetirement(
        _ request: Data,
        withReply reply: @escaping (Data?, String?) -> Void
    ) {
        guard beginOperation() else {
            reply(
                nil,
                machineClaimServerReasonKey(
                    InvestigationMachineClaimServerError.unavailable
                )
            )
            return
        }
        do {
            reply(try adapter.claim(request), nil)
        } catch {
            reply(nil, machineClaimServerReasonKey(error))
        }
        finishOperation()
    }

    public func releaseMachineRetirement(
        _ request: Data,
        withReply reply: @escaping (Data?, String?) -> Void
    ) {
        guard beginOperation() else {
            reply(
                nil,
                machineClaimServerReasonKey(
                    InvestigationMachineClaimServerError.unavailable
                )
            )
            return
        }
        let data: Data
        do {
            data = try adapter.release(request)
        } catch {
            reply(nil, machineClaimServerReasonKey(error))
            finishOperation()
            return
        }
        reply(data, nil)
        try? adapter.replyDidDispatch()
        finishOperation()
    }

    public func invalidate() {
        let shouldInvalidateNow = lock.withLock {
            guard !invalidated else { return false }
            invalidated = true
            if operationInProgress {
                invalidationDeferred = true
                return false
            }
            return true
        }
        if shouldInvalidateNow { adapter.invalidate() }
    }

    private func beginOperation() -> Bool {
        lock.withLock {
            guard !invalidated, !operationInProgress else { return false }
            operationInProgress = true
            return true
        }
    }

    private func finishOperation() {
        let shouldInvalidate = lock.withLock {
            operationInProgress = false
            guard invalidationDeferred else { return false }
            invalidationDeferred = false
            return true
        }
        if shouldInvalidate { adapter.invalidate() }
    }
}

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
                rawValue: transfer.validBeforeUTCMicroseconds
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
    private let clock: any InvestigationMachineClaimServerCoreClock
    private let state: LifecycleMachineRetirementEscrowDeadlineState
    private let executor: InvestigationMachineClaimServerEffectExecutor
    private let evidenceLock = NSLock()
    private var evidence: InvestigationMachineClaimEvidence?

    package init(
        transfer: LifecycleMachineRetirementReservationTransfer,
        clock: any InvestigationMachineClaimServerCoreClock,
        state: LifecycleMachineRetirementEscrowDeadlineState,
        executor: InvestigationMachineClaimServerEffectExecutor
    ) throws {
        guard !transfer.reservationID.claimServerIsZero else {
            throw InvestigationMachineClaimServerError.invalidRequest
        }
        projection = try InvestigationMachineClaimServerProjection(
            transfer: transfer
        )
        reservationID = transfer.reservationID
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

    package var hasBoundConnection: Bool {
        evidenceLock.withLock { evidence != nil }
    }

    package func cancel() {
        try? executor.apply(
            state.cancel(reservationID: reservationID),
            to: state
        )
    }

    package func invalidate() {
        guard let evidence = evidenceLock.withLock({ evidence }) else {
            cancel()
            return
        }
        try? executor.apply(
            state.invalidate(
                reservationID: reservationID,
                connectionEpoch: evidence.claimConnectionEpoch
            ),
            to: state
        )
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

private func machineClaimServerReasonKey(_ error: Error) -> String {
    guard let error = error as? InvestigationMachineClaimServerError else {
        return "runtime.lifecycle.machine-claim.unavailable"
    }
    return switch error {
    case .invalidRequest:
        "runtime.lifecycle.machine-claim.invalid-request"
    case .bindingMismatch:
        "runtime.lifecycle.machine-claim.mismatch"
    case .duplicateOrReplay:
        "runtime.lifecycle.machine-claim.consumed"
    case .expired:
        "runtime.lifecycle.machine-claim.expired"
    case .unavailable:
        "runtime.lifecycle.machine-claim.unavailable"
    }
}
