import Foundation
import StornautInvestigationHandoffContract
import StornautInvestigationInstalledL2
package enum InvestigationMachineSingleEpochError: Error, Sendable, Equatable {
    case alreadyConsumed, invalidCommitment, deadlineInvalid
    case driverObservationFailed, protocolViolation, identityMismatch
    case commitmentMismatch, claimFailed, claimTerminalUncertain
    case installedL2Failed, releaseTerminalUncertain, cancelled
    case abortTerminalUncertain, retirementUncertain, finalObservationMismatch
}
package enum InvestigationMachineSingleEpochResult: Sendable, Equatable { case completedNonAdmitting }
package struct InvestigationMachineSingleEpochRetirementProof: Sendable, Equatable { package init() {} }
package struct InvestigationMachineSingleEpochTerminalStartProof: Sendable, Equatable { package init() {} }
package struct InvestigationMachineSingleEpochAppObservation: Sendable, Equatable {
    fileprivate let identity: InvestigationMachineProcessIdentity
    init(identity: InvestigationMachineProcessIdentity) { self.identity = identity }
}
package struct InvestigationMachineSingleEpochDriverObservation: Sendable, Equatable {
    private let value: InvestigationMachineInstalledDriverObservation
    init(_ value: InvestigationMachineInstalledDriverObservation) { self.value = value }
}
package struct InvestigationMachineSingleEpochCommitment: Sendable {
    fileprivate let epoch: InvestigationCohortEpoch
    fileprivate let projection: InvestigationInstalledL2IdentityProjection

    package init(
        epoch: InvestigationCohortEpoch,
        projection: InvestigationInstalledL2IdentityProjection
    ) throws {
        guard
            projection.epochUUID == epoch.epochUUID,
            projection.configurationNonce == epoch.configurationNonce,
            projection.configurationSHA256 == epoch.configurationSHA256,
            projection.signedRuntimeBindingSHA256
                == epoch.signedRuntimeBindingSHA256
        else {
            throw InvestigationMachineSingleEpochError.invalidCommitment
        }
        self.epoch = epoch
        self.projection = projection
    }
}
package enum InvestigationMachineSingleEpochClaimingError: Error, Sendable { case terminalUncertain }
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
}
package protocol InvestigationMachineSingleEpochClaiming: Sendable {
    func claim(
        handle: InvestigationHandoffRetirementHandle,
        appIdentity: InvestigationMachineProcessIdentity,
        sharedDeadline: InvestigationMachineClaimClientSharedDeadline
    ) async throws -> InvestigationMachineClaimEvidence
    func abortAfterClaimAndProveTerminal() async throws
    func releaseAndAwaitTerminal() async throws
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
        sharedDeadline: InvestigationMachineClaimClientSharedDeadline
    ) async throws -> InvestigationMachineClaimEvidence {
        do {
            return try await claimOrProveTerminal(
                handle: handle, appIdentity: appIdentity,
                sharedDeadline: sharedDeadline, previousHelperIdentity: nil
            )
        } catch let error as InvestigationMachineClaimClientError {
            guard error == .terminalResidueUncertain else { throw error }
            throw InvestigationMachineSingleEpochClaimingError.terminalUncertain
        }
    }
    package func releaseAndAwaitTerminal() async throws { _ = try await release() }
}
package actor InvestigationMachineSingleEpochComposer {
    private static let maximumEpochWindowNanoseconds: UInt64 = 140_000_000_000
    private let commitment: InvestigationMachineSingleEpochCommitment
    private let observer: any InvestigationMachineSingleEpochInstalledDriverObserving
    private let clock: any InvestigationMachineSingleEpochClocking
    private let sessionFactory: any InvestigationMachineSingleEpochSessionFactory
    private let claimClientFactory: any InvestigationMachineSingleEpochClaimClientFactory
    private let installedL2: any InvestigationMachineSingleEpochInstalledL2Observing
    private var consumed = false
    package init(
        commitment: InvestigationMachineSingleEpochCommitment,
        observer: any InvestigationMachineSingleEpochInstalledDriverObserving,
        clock: any InvestigationMachineSingleEpochClocking,
        sessionFactory: any InvestigationMachineSingleEpochSessionFactory,
        claimClientFactory: any InvestigationMachineSingleEpochClaimClientFactory
    ) {
        self.init(
            commitment: commitment, observer: observer, clock: clock,
            sessionFactory: sessionFactory,
            claimClientFactory: claimClientFactory,
            installedL2: InvestigationMachineSingleEpochInstalledL2Join()
        )
    }

    init(
        commitment: InvestigationMachineSingleEpochCommitment,
        observer: any InvestigationMachineSingleEpochInstalledDriverObserving,
        clock: any InvestigationMachineSingleEpochClocking,
        sessionFactory: any InvestigationMachineSingleEpochSessionFactory,
        claimClientFactory: any InvestigationMachineSingleEpochClaimClientFactory,
        installedL2: any InvestigationMachineSingleEpochInstalledL2Observing
    ) {
        self.commitment = commitment; self.observer = observer; self.clock = clock
        self.sessionFactory = sessionFactory; self.claimClientFactory = claimClientFactory
        self.installedL2 = installedL2
    }
    package func run() async throws -> InvestigationMachineSingleEpochResult {
        guard !consumed else {
            throw InvestigationMachineSingleEpochError.alreadyConsumed
        }
        consumed = true
        return try await execute()
    }
    private func execute() async throws -> InvestigationMachineSingleEpochResult {
        let epoch = commitment.epoch
        guard epoch.scenario.rawValue == epoch.ordinal + 1 else {
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
        }
        let driverClaim = session.driverClaim
        var claimClient: (any InvestigationMachineSingleEpochClaiming)?
        var claimSucceeded = false
        var claimReleaseAttempted = false
        var retirementAttempted = false
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
                    sharedDeadline: sharedDeadline
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
            do {
                _ = try InvestigationMachineSingleEpochInstalledL2Join.prove(
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
            try Task.checkCancellation()
            claimReleaseAttempted = true
            do {
                try await createdClaimClient.releaseAndAwaitTerminal()
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
            do { _ = try await session.retireAndReap() }
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
            return .completedNonAdmitting
        } catch {
            var terminalError = normalized(error)
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
