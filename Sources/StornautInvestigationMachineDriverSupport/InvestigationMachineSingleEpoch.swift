import Foundation
import StornautInvestigationHandoffContract
import StornautInvestigationInstalledL2
package enum InvestigationMachineSingleEpochError: Error, Sendable, Equatable {
    case alreadyConsumed, invalidCommitment, deadlineInvalid
    case driverObservationFailed, protocolViolation, identityMismatch
    case commitmentMismatch, claimFailed, claimTerminalUncertain
    case installedL2Failed, releaseTerminalUncertain, cancelled
    case abortTerminalUncertain, retirementUncertain, finalObservationMismatch
    case ownershipTerminalUncertain
}
package enum InvestigationMachineSingleEpochResult: Sendable, Equatable {
    case localCompletion(
        InvestigationMachineSingleEpochLocalCompletionCandidate
    )
    case ownershipTransferred(
        InvestigationMachineSingleEpochOwnershipCandidate
    )
}
package struct InvestigationMachineSingleEpochRetirementProof: Sendable, Equatable { init() {} }
package struct InvestigationMachineSingleEpochTerminalStartProof: Sendable, Equatable { package init() {} }
package struct InvestigationMachineSingleEpochAppObservation: Sendable, Equatable {
    fileprivate let identity: InvestigationMachineProcessIdentity
    init(identity: InvestigationMachineProcessIdentity) { self.identity = identity }
}
package struct InvestigationMachineSingleEpochDriverObservation: Sendable, Equatable {
    let value: InvestigationMachineInstalledDriverObservation
    init(_ value: InvestigationMachineInstalledDriverObservation) { self.value = value }
}
package struct InvestigationMachineSingleEpochCommitment: Sendable {
    let outerAttemptUUID: UUID
    let wholeCapsuleSHA256: InvestigationHandoffSHA256
    let wholeInputSHA256: InvestigationHandoffSHA256
    let epoch: InvestigationCohortEpoch
    let projection: InvestigationInstalledL2IdentityProjection

    package init(
        selection: InvestigationMachineFixedEpochSelection
    ) throws {
        try self.init(
            outerAttemptUUID: selection.outerAttemptUUID,
            wholeCapsuleSHA256: selection.wholeCapsuleSHA256,
            wholeInputSHA256: selection.wholeInputSHA256,
            epoch: selection.epoch, projection: selection.projection
        )
    }

    private init(
        outerAttemptUUID: UUID,
        wholeCapsuleSHA256: InvestigationHandoffSHA256,
        wholeInputSHA256: InvestigationHandoffSHA256,
        epoch: InvestigationCohortEpoch,
        projection: InvestigationInstalledL2IdentityProjection
    ) throws {
        guard
            outerAttemptUUID != UUID(
                uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
            ),
            wholeCapsuleSHA256.rawBytes.contains(where: { $0 != 0 }),
            wholeInputSHA256.rawBytes.contains(where: { $0 != 0 }),
            projection.epochUUID == epoch.epochUUID,
            projection.configurationNonce == epoch.configurationNonce,
            projection.configurationSHA256 == epoch.configurationSHA256,
            projection.signedRuntimeBindingSHA256
                == epoch.signedRuntimeBindingSHA256
        else {
            throw InvestigationMachineSingleEpochError.invalidCommitment
        }
        self.outerAttemptUUID = outerAttemptUUID
        self.wholeCapsuleSHA256 = wholeCapsuleSHA256
        self.wholeInputSHA256 = wholeInputSHA256
        self.epoch = epoch
        self.projection = projection
    }
}
package enum InvestigationMachineSingleEpochClaimingError: Error, Sendable { case terminalUncertain }
package enum InvestigationMachineSingleEpochSessionError: Error, Sendable {
    case identityMismatch
}
package protocol InvestigationMachineSingleEpochInstalledDriverObserving: Sendable {
    func observeDriver() throws -> InvestigationMachineSingleEpochDriverObservation
}
package protocol InvestigationMachineSingleEpochClocking: Sendable {
    func continuousNanoseconds() throws -> UInt64
}
package protocol InvestigationMachineSingleEpochSession: Sendable {
    var driverClaim: InvestigationHandoffProcessClaim { get }
    func receive() async throws -> InvestigationHandoffFrame
    func send(_ frame: InvestigationHandoffFrame) async throws
    func provePeerWriteEOF() async throws
    func observeCompletePostDropAppIdentity() async throws -> InvestigationMachineSingleEpochAppObservation
    func retireAndReap() async throws -> InvestigationMachineSingleEpochRetirementProof
}
package protocol InvestigationMachineSingleEpochSessionFactory: Sendable {
    func start(bootstrap: InvestigationHandoffEpochBootstrap) async -> InvestigationMachineSingleEpochStartOutcome
}
package enum InvestigationMachineSingleEpochStartOutcome: Sendable {
    case started(any InvestigationMachineSingleEpochSession)
    case terminal(InvestigationMachineSingleEpochTerminalStartProof)
    case terminalUncertain
}
package protocol InvestigationMachineSingleEpochClaiming: Sendable {
    func claim(
        handle: InvestigationHandoffRetirementHandle,
        appIdentity: InvestigationMachineProcessIdentity,
        sharedDeadline: InvestigationMachineClaimClientSharedDeadline,
        previousHelperIdentity: InvestigationMachineProcessIdentity?
    ) async throws -> InvestigationMachineClaimEvidence
    func abortAfterClaimAndProveTerminal() async throws
    func releaseAndAwaitTerminal() async throws
        -> InvestigationMachineClaimReleased
}
package protocol InvestigationMachineSingleEpochClaimClientFactory: Sendable {
    func make() -> any InvestigationMachineSingleEpochClaiming
}
extension InvestigationMachineInstalledDriverObserver:
    InvestigationMachineSingleEpochInstalledDriverObserving {
    func observeDriver() throws -> InvestigationMachineSingleEpochDriverObservation {
        .init(try observe())
    }
}
extension InvestigationMachineClaimClient: InvestigationMachineSingleEpochClaiming {
    package func claim(
        handle: InvestigationHandoffRetirementHandle,
        appIdentity: InvestigationMachineProcessIdentity,
        sharedDeadline: InvestigationMachineClaimClientSharedDeadline,
        previousHelperIdentity: InvestigationMachineProcessIdentity?
    ) async throws -> InvestigationMachineClaimEvidence {
        do {
            return try await claimOrProveTerminal(
                handle: handle, appIdentity: appIdentity,
                sharedDeadline: sharedDeadline,
                previousHelperIdentity: previousHelperIdentity
            )
        } catch let error as InvestigationMachineClaimClientError {
            guard error == .terminalResidueUncertain else { throw error }
            throw InvestigationMachineSingleEpochClaimingError.terminalUncertain
        }
    }
    package func releaseAndAwaitTerminal() async throws
        -> InvestigationMachineClaimReleased
    {
        try await release()
    }
}
package actor InvestigationMachineSingleEpochComposer {
    private static let maximumEpochWindowNanoseconds: UInt64 = 140_000_000_000
    private let commitment: InvestigationMachineSingleEpochCommitment
    private let observer: any InvestigationMachineSingleEpochInstalledDriverObserving
    private let clock: any InvestigationMachineSingleEpochClocking
    private let sessionFactory: any InvestigationMachineSingleEpochSessionFactory
    private let claimClientFactory: any InvestigationMachineSingleEpochClaimClientFactory
    private let installedL2: any InvestigationMachineSingleEpochInstalledL2Observing
    private let ownershipSuspender:
        any InvestigationMachineSingleEpochOwnershipSuspending
    private var consumed = false
    package init(
        commitment: InvestigationMachineSingleEpochCommitment,
        observer: any InvestigationMachineSingleEpochInstalledDriverObserving,
        clock: any InvestigationMachineSingleEpochClocking,
        sessionFactory: any InvestigationMachineSingleEpochSessionFactory,
        claimClientFactory: any InvestigationMachineSingleEpochClaimClientFactory,
        ownershipSuspender:
            any InvestigationMachineSingleEpochOwnershipSuspending
    ) {
        self.init(
            commitment: commitment, observer: observer, clock: clock,
            sessionFactory: sessionFactory,
            claimClientFactory: claimClientFactory,
            installedL2: InvestigationMachineSingleEpochInstalledL2Join(),
            ownershipSuspender: ownershipSuspender
        )
    }

    init(
        commitment: InvestigationMachineSingleEpochCommitment,
        observer: any InvestigationMachineSingleEpochInstalledDriverObserving,
        clock: any InvestigationMachineSingleEpochClocking,
        sessionFactory: any InvestigationMachineSingleEpochSessionFactory,
        claimClientFactory: any InvestigationMachineSingleEpochClaimClientFactory,
        installedL2: any InvestigationMachineSingleEpochInstalledL2Observing,
        ownershipSuspender:
            any InvestigationMachineSingleEpochOwnershipSuspending
    ) {
        self.commitment = commitment; self.observer = observer; self.clock = clock
        self.sessionFactory = sessionFactory; self.claimClientFactory = claimClientFactory
        self.installedL2 = installedL2
        self.ownershipSuspender = ownershipSuspender
    }
    package nonisolated func isBound(
        to selection: InvestigationMachineFixedEpochSelection
    ) -> Bool {
        commitment.epoch == selection.epoch
            && commitment.projection == selection.projection
            && commitment.outerAttemptUUID == selection.outerAttemptUUID
            && commitment.wholeCapsuleSHA256
                == selection.wholeCapsuleSHA256
            && commitment.wholeInputSHA256 == selection.wholeInputSHA256
    }
    func run(
        previousHelperIdentity: InvestigationMachineProcessIdentity?
    ) async throws -> InvestigationMachineSingleEpochResult {
        guard !consumed else {
            throw InvestigationMachineSingleEpochError.alreadyConsumed
        }
        consumed = true
        return try await execute(
            previousHelperIdentity: previousHelperIdentity
        )
    }
    private func execute(
        previousHelperIdentity: InvestigationMachineProcessIdentity?
    ) async throws -> InvestigationMachineSingleEpochResult {
        let epoch = commitment.epoch
        guard epoch.scenario.rawValue == epoch.ordinal + 1 else {
            throw InvestigationMachineSingleEpochError.invalidCommitment
        }
        guard (epoch.ordinal == 0) == (previousHelperIdentity == nil) else {
            throw InvestigationMachineSingleEpochError.invalidCommitment
        }
        let initialObservation: InvestigationMachineSingleEpochDriverObservation
        do { initialObservation = try observer.observeDriver() }
        catch { throw InvestigationMachineSingleEpochError.driverObservationFailed }
        let now: UInt64
        do { now = try clock.continuousNanoseconds() }
        catch { throw InvestigationMachineSingleEpochError.deadlineInvalid }
        let deadline = now.addingReportingOverflow(
            Self.maximumEpochWindowNanoseconds
        )
        guard !deadline.overflow, deadline.partialValue > now else {
            throw InvestigationMachineSingleEpochError.deadlineInvalid
        }
        let bootstrap: InvestigationHandoffEpochBootstrap
        let sharedDeadline: InvestigationMachineClaimClientSharedDeadline
        do {
            bootstrap = try InvestigationHandoffEpochBootstrap(
                epochUUID: epoch.epochUUID,
                epochDeadlineNanoseconds: deadline.partialValue
            )
            sharedDeadline = try InvestigationMachineClaimClientSharedDeadline(
                epochDeadlineNanoseconds: deadline.partialValue
            )
        } catch {
            throw InvestigationMachineSingleEpochError.deadlineInvalid
        }
        let session: any InvestigationMachineSingleEpochSession
        try Task.checkCancellation()
        switch await sessionFactory.start(bootstrap: bootstrap) {
        case let .started(value): session = value
        case .terminal:
            throw Task.isCancelled ? InvestigationMachineSingleEpochError.cancelled
                : InvestigationMachineSingleEpochError.protocolViolation
        case .terminalUncertain:
            throw InvestigationMachineSingleEpochError.retirementUncertain
        }
        let driverClaim = session.driverClaim
        var claimClient: (any InvestigationMachineSingleEpochClaiming)?
        var claimSucceeded = false
        var claimReleaseAttempted = false
        var retirementAttempted = false
        var localTeardownAuthority = true
        do {
            try Task.checkCancellation()
            let preDrop = try await receive(
                session, kind: .preDropReady, bootstrap: bootstrap
            )
            try requireEmpty(preDrop)
            try await send(
                session, kind: .dropRelease, bootstrap: bootstrap,
                sender: driverClaim, payload: .empty
            )
            let drop = try await receive(
                session, kind: .dropEvidence, bootstrap: bootstrap
            )
            guard
                case let .dropEvidence(dropEvidence) = drop.payload,
                drop.sender.processID == preDrop.sender.processID,
                drop.sender.processIDVersion == preDrop.sender.processIDVersion,
                drop.sender.auditSessionID == preDrop.sender.auditSessionID,
                drop.sender.effectiveUserID == 501
            else {
                throw InvestigationMachineSingleEpochError.identityMismatch
            }
            let appIdentity = try await observeAppIdentity(session)
            guard appIdentityMatches(
                appIdentity, claim: drop.sender, evidence: dropEvidence
            ) else {
                throw InvestigationMachineSingleEpochError.identityMismatch
            }
            try await send(
                session, kind: .configuration, bootstrap: bootstrap,
                sender: driverClaim, payload: .configuration(epoch.configuration)
            )
            let acknowledgementFrame = try await receive(
                session, kind: .configurationAcknowledgement,
                bootstrap: bootstrap, sender: drop.sender
            )
            guard case let .configurationAcknowledgement(acknowledgement) =
                acknowledgementFrame.payload
            else {
                throw InvestigationMachineSingleEpochError.protocolViolation
            }
            guard
                acknowledgement.epochUUID == epoch.epochUUID,
                acknowledgement.ordinal == epoch.ordinal,
                acknowledgement.configurationNonce == epoch.configurationNonce,
                acknowledgement.scenario == epoch.scenario,
                acknowledgement.configurationSHA256 == epoch.configurationSHA256,
                acknowledgement.signedRuntimeBindingSHA256
                    == epoch.signedRuntimeBindingSHA256
            else { throw InvestigationMachineSingleEpochError.commitmentMismatch }
            let hello = try await receive(
                session, kind: .hello, bootstrap: bootstrap, sender: drop.sender
            )
            try requireEmpty(hello)
            let handleFrame = try await receive(
                session, kind: .handle, bootstrap: bootstrap, sender: drop.sender
            )
            guard case let .retirementHandle(handle) = handleFrame.payload else {
                throw InvestigationMachineSingleEpochError.protocolViolation
            }
            do {
                try epoch.validate(
                    configurationAcknowledgement: acknowledgement,
                    retirementHandle: handle
                )
            } catch {
                throw InvestigationMachineSingleEpochError.commitmentMismatch
            }
            let handleAcknowledgement =
                InvestigationHandoffRetirementHandleAcknowledgement(
                    handleSHA256: .hashing(try handle.encoded())
                )
            try await send(
                session, kind: .acknowledgement, bootstrap: bootstrap,
                sender: driverClaim,
                payload: .retirementHandleAcknowledgement(handleAcknowledgement)
            )
            try await send(
                session, kind: .release, bootstrap: bootstrap,
                sender: driverClaim, payload: .empty
            )
            let alive = try await receive(
                session, kind: .alive, bootstrap: bootstrap, sender: drop.sender
            )
            try requireEmpty(alive)
            do {
                try Task.checkCancellation()
                try await session.provePeerWriteEOF()
                try Task.checkCancellation()
            }
            catch is CancellationError { throw InvestigationMachineSingleEpochError.cancelled }
            catch { throw InvestigationMachineSingleEpochError.protocolViolation }
            let createdClaimClient = claimClientFactory.make()
            claimClient = createdClaimClient
            let evidence: InvestigationMachineClaimEvidence
            do {
                try Task.checkCancellation()
                evidence = try await createdClaimClient.claim(
                    handle: handle, appIdentity: appIdentity,
                    sharedDeadline: sharedDeadline,
                    previousHelperIdentity: previousHelperIdentity
                )
                claimSucceeded = true
                try Task.checkCancellation()
            } catch is CancellationError {
                throw InvestigationMachineSingleEpochError.cancelled
            } catch InvestigationMachineSingleEpochClaimingError
                .terminalUncertain {
                throw InvestigationMachineSingleEpochError
                    .claimTerminalUncertain
            } catch {
                throw InvestigationMachineSingleEpochError.claimFailed
            }
            guard evidence.appIdentity == appIdentity else {
                throw InvestigationMachineSingleEpochError.identityMismatch
            }
            guard
                previousHelperIdentity == nil
                    || previousHelperIdentity != evidence.helperIdentity
            else {
                throw InvestigationMachineSingleEpochError.claimFailed
            }
            let semanticObservation: InvestigationInstalledL2SemanticObservation
            do {
                try Task.checkCancellation()
                semanticObservation = try await installedL2.observe(
                    projection: commitment.projection,
                    appIdentity: appIdentity, claimEvidence: evidence,
                    epochUUID: epoch.epochUUID,
                    deadlineNanoseconds: deadline.partialValue
                )
                try Task.checkCancellation()
            } catch is CancellationError {
                throw InvestigationMachineSingleEpochError.cancelled
            } catch {
                throw InvestigationMachineSingleEpochError.installedL2Failed
            }
            let repeatedIdentity = try await observeAppIdentity(session)
            guard repeatedIdentity == appIdentity else {
                throw InvestigationMachineSingleEpochError.identityMismatch
            }
            let installedL2Proof:
                InvestigationMachineSingleEpochInstalledL2Proof
            do {
                installedL2Proof = try
                    InvestigationMachineSingleEpochInstalledL2Join.prove(
                    projection: commitment.projection,
                    claimEvidence: evidence,
                    semanticObservation: semanticObservation,
                    repeatedAppIdentity: repeatedIdentity,
                    epochUUID: epoch.epochUUID,
                    deadlineNanoseconds: deadline.partialValue
                )
            } catch {
                throw InvestigationMachineSingleEpochError.installedL2Failed
            }
            let ownership: InvestigationMachineSingleEpochOwnershipCandidate
            do {
                ownership = try .init(
                    commitment: commitment,
                    appIdentity: appIdentity, claimEvidence: evidence,
                    semanticObservation: semanticObservation,
                    repeatedAppIdentity: repeatedIdentity,
                    installedL2Proof: installedL2Proof,
                    epochDeadlineNanoseconds: deadline.partialValue
                )
            } catch {
                throw InvestigationMachineSingleEpochError.installedL2Failed
            }
            let suspender = ownershipSuspender
            let ownershipResolution = await Task.detached {
                await suspender.suspend(ownership)
            }.value
            switch ownershipResolution {
            case let .resumeLocal(candidate):
                guard
                    candidate == ownership,
                    epoch.scenario != .lifecycleRecovery
                else {
                    throw InvestigationMachineSingleEpochError
                        .ownershipTerminalUncertain
                }
                try Task.checkCancellation()
            case let .outerOwnsTerminal(candidate):
                guard
                    candidate == ownership,
                    epoch.scenario == .lifecycleRecovery
                else {
                    localTeardownAuthority = false
                    throw InvestigationMachineSingleEpochError
                        .ownershipTerminalUncertain
                }
                localTeardownAuthority = false
                return .ownershipTransferred(ownership)
            case .terminalUncertain:
                localTeardownAuthority = false
                throw InvestigationMachineSingleEpochError
                    .ownershipTerminalUncertain
            }
            try Task.checkCancellation()
            claimReleaseAttempted = true
            let claimRelease: InvestigationMachineClaimReleased
            do {
                claimRelease = try await
                    createdClaimClient.releaseAndAwaitTerminal()
            } catch {
                throw InvestigationMachineSingleEpochError
                    .releaseTerminalUncertain
            }
            try Task.checkCancellation()
            try await send(
                session, kind: .exit, bootstrap: bootstrap,
                sender: driverClaim, payload: .empty
            )
            retirementAttempted = true
            let retirement: InvestigationMachineSingleEpochRetirementProof
            do { retirement = try await session.retireAndReap() }
            catch { throw InvestigationMachineSingleEpochError.retirementUncertain }
            try Task.checkCancellation()
            let finalObservation: InvestigationMachineSingleEpochDriverObservation
            do { finalObservation = try observer.observeDriver() }
            catch {
                throw InvestigationMachineSingleEpochError.finalObservationMismatch
            }
            guard finalObservation == initialObservation else {
                throw InvestigationMachineSingleEpochError.finalObservationMismatch
            }
            do {
                return .localCompletion(try .init(
                    ownership: ownership, claimRelease: claimRelease,
                    retirement: retirement,
                    initialDriverObservation: initialObservation,
                    finalDriverObservation: finalObservation
                ))
            } catch {
                throw InvestigationMachineSingleEpochError
                    .releaseTerminalUncertain
            }
        } catch {
            var terminalError = normalized(error)
            guard localTeardownAuthority else { throw terminalError }
            if claimSucceeded, !claimReleaseAttempted, let claimClient {
                do { try await claimClient.abortAfterClaimAndProveTerminal() }
                catch { terminalError = .abortTerminalUncertain }
            }
            if !retirementAttempted {
                retirementAttempted = true
                do { _ = try await session.retireAndReap() }
                catch { terminalError = .retirementUncertain }
            }
            throw terminalError
        }
    }
    private func receive(
        _ session: any InvestigationMachineSingleEpochSession,
        kind: InvestigationHandoffFrameKind,
        bootstrap: InvestigationHandoffEpochBootstrap,
        sender: InvestigationHandoffProcessClaim? = nil
    ) async throws -> InvestigationHandoffFrame {
        let frame: InvestigationHandoffFrame
        do {
            try Task.checkCancellation()
            frame = try await session.receive()
            try Task.checkCancellation()
        }
        catch is CancellationError { throw InvestigationMachineSingleEpochError.cancelled }
        catch InvestigationMachineSingleEpochSessionError.identityMismatch {
            throw InvestigationMachineSingleEpochError.identityMismatch
        }
        catch { throw InvestigationMachineSingleEpochError.protocolViolation }
        guard
            frame.kind == kind,
            frame.epochUUID == bootstrap.epochUUID,
            frame.epochDeadlineNanoseconds
                == bootstrap.epochDeadlineNanoseconds,
            sender == nil || frame.sender == sender
        else {
            throw InvestigationMachineSingleEpochError.protocolViolation
        }
        return frame
    }
    private func send(
        _ session: any InvestigationMachineSingleEpochSession,
        kind: InvestigationHandoffFrameKind,
        bootstrap: InvestigationHandoffEpochBootstrap,
        sender: InvestigationHandoffProcessClaim,
        payload: InvestigationHandoffFramePayload
    ) async throws {
        do {
            try Task.checkCancellation()
            try await session.send(try InvestigationHandoffFrame(
                kind: kind, epochUUID: bootstrap.epochUUID,
                epochDeadlineNanoseconds: bootstrap.epochDeadlineNanoseconds,
                sender: sender, payload: payload
            ))
            try Task.checkCancellation()
        } catch is CancellationError { throw InvestigationMachineSingleEpochError.cancelled }
        catch let error as InvestigationMachineSingleEpochError { throw error }
        catch { throw InvestigationMachineSingleEpochError.protocolViolation }
    }
    private func observeAppIdentity(
        _ session: any InvestigationMachineSingleEpochSession
    ) async throws -> InvestigationMachineProcessIdentity {
        do {
            try Task.checkCancellation()
            let observation = try await session.observeCompletePostDropAppIdentity()
            try Task.checkCancellation()
            return observation.identity
        }
        catch is CancellationError { throw InvestigationMachineSingleEpochError.cancelled }
        catch { throw InvestigationMachineSingleEpochError.identityMismatch }
    }
    private func requireEmpty(_ frame: InvestigationHandoffFrame) throws {
        guard frame.payload == .empty else {
            throw InvestigationMachineSingleEpochError.protocolViolation
        }
    }
    private func appIdentityMatches(
        _ identity: InvestigationMachineProcessIdentity,
        claim: InvestigationHandoffProcessClaim,
        evidence: InvestigationHandoffDropEvidence
    ) -> Bool {
        identity.role == .app
            && identity.processID == claim.processID
            && identity.processIDVersion == claim.processIDVersion
            && identity.effectiveUserID == claim.effectiveUserID
            && identity.auditSessionID == claim.auditSessionID
            && identity.auditTokenWords == evidence.auditTokenWords
    }
    private func normalized(_ error: any Error)
        -> InvestigationMachineSingleEpochError {
        if let error = error as? InvestigationMachineSingleEpochError {
            return error
        }
        if error is CancellationError { return .cancelled }
        return .protocolViolation
    }
}

extension InvestigationMachineSingleEpochComposer:
    InvestigationMachineSingleEpochComposing {}
