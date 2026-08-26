import Darwin
import Foundation
import StornautInvestigationHandoffContract
import StornautInvestigationInstalledL2

enum InvestigationMachineDarwinOuterObservationError:
    Error, Sendable, Equatable
{
    case alreadyConsumed
    case invalidSelection
    case ownershipInvalid
    case originalIdentityStillPresent
    case driverObservationMismatch
    case deadlineExceeded
    case identityUnavailable
}

protocol InvestigationMachineDarwinOuterObservationWaiting: Sendable {
    func sleep(nanoseconds: UInt64) async throws
}

private struct InvestigationMachineDarwinOuterObservationWaiter:
    InvestigationMachineDarwinOuterObservationWaiting
{
    func sleep(nanoseconds: UInt64) async throws {
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

package actor InvestigationMachineDarwinOuterObserver:
    InvestigationMachineDarwinOuterOwnershipObserving,
    InvestigationMachineDarwinOuterTerminalObserving
{
    private struct InitialState: Sendable {
        let selection: InvestigationMachineFixedEpochSelection
        let driver: InvestigationMachineInstalledDriverObservation
        let driverSHA256: InvestigationHandoffSHA256
    }

    private struct OwnedState: Sendable {
        let selection: InvestigationMachineFixedEpochSelection
        let ownership: InvestigationMachineDarwinEpochOwnershipRecord
        let physical: InvestigationMachineSingleEpochPhysicalOwnership
        let driver: InvestigationMachineInstalledDriverObservation
        let driverSHA256: InvestigationHandoffSHA256
    }

    private enum State: Sendable {
        case ready
        case initial(InitialState)
        case owned(OwnedState)
        case terminalizing
        case terminal
    }

    private let outerProcessID: UInt32
    private let installedDriverObserver:
        InvestigationMachineInstalledDriverObserver
    private let driverChildObserver:
        any InvestigationMachineDarwinDriverChildObserving
    private let appIdentityObserver:
        InvestigationMachineDarwinAppIdentityObserver
    private let originalIdentityReader:
        InvestigationMachineDarwinOriginalIdentityReader
    private let clock:
        any InvestigationMachineDarwinOuterInnerCompositionClocking
    private let waiter: any InvestigationMachineDarwinOuterObservationWaiting
    private var state = State.ready

    package init() {
        self.init(
            clock: InvestigationMachineDarwinCompositionClock(),
            outerProcessID: UInt32(getpid())
        )
    }

    init(
        clock: any InvestigationMachineDarwinOuterInnerCompositionClocking,
        outerProcessID: UInt32
    ) {
        self.outerProcessID = outerProcessID
        installedDriverObserver = InvestigationMachineInstalledDriverObserver(
            realUserID: Darwin.getuid,
            effectiveUserID: Darwin.geteuid,
            realGroupID: Darwin.getgid,
            effectiveGroupID: Darwin.getegid,
            argumentCount: { Int32(CommandLine.argc) },
            source: InvestigationMachineInstalledDriverSystemSource(
                system: DarwinInvestigationMachineInstalledDriverSystem()
            )
        )
        driverChildObserver = InvestigationMachineDarwinDriverChildObserver()
        appIdentityObserver = InvestigationMachineDarwinAppIdentityObserver()
        originalIdentityReader =
            InvestigationMachineDarwinOriginalIdentityReader()
        self.clock = clock
        waiter = InvestigationMachineDarwinOuterObservationWaiter()
    }

    init(
        installedDriverObserver: InvestigationMachineInstalledDriverObserver,
        driverChildObserver:
            any InvestigationMachineDarwinDriverChildObserving,
        appIdentityObserver: InvestigationMachineDarwinAppIdentityObserver,
        originalIdentityReader:
            InvestigationMachineDarwinOriginalIdentityReader,
        clock: any InvestigationMachineDarwinOuterInnerCompositionClocking,
        waiter: any InvestigationMachineDarwinOuterObservationWaiting =
            InvestigationMachineDarwinOuterObservationWaiter(),
        outerProcessID: UInt32
    ) {
        self.outerProcessID = outerProcessID
        self.installedDriverObserver = installedDriverObserver
        self.driverChildObserver = driverChildObserver
        self.appIdentityObserver = appIdentityObserver
        self.originalIdentityReader = originalIdentityReader
        self.clock = clock
        self.waiter = waiter
    }

    func observeInitialDriver(
        selection: InvestigationMachineFixedEpochSelection
    ) async throws -> InvestigationHandoffSHA256 {
        try ensureNotCancelled()
        guard case .ready = state, outerProcessID > 1 else {
            return try fail(.alreadyConsumed)
        }

        let observation: InvestigationMachineInstalledDriverObservation
        do {
            observation = try installedDriverObserver.observe()
        } catch {
            return try fail(.identityUnavailable)
        }
        guard outerDriverMatchesProjection(observation, selection: selection)
        else {
            return try fail(.driverObservationMismatch)
        }

        let digest: InvestigationHandoffSHA256
        do {
            digest = try singleEpochDriverObservationSHA256(
                .init(observation)
            )
        } catch {
            return try fail(.identityUnavailable)
        }
        try ensureNotCancelled()
        state = .initial(.init(
            selection: selection, driver: observation, driverSHA256: digest
        ))
        return digest
    }

    func observeOwnership(
        request: InvestigationMachineDarwinEpochRequest,
        record: InvestigationMachineDarwinEpochOwnershipRecord,
        sessionDriverChild: InvestigationMachineDarwinDriverChildIdentity
    ) async throws -> InvestigationMachineDarwinOuterOwnershipObservation {
        try ensureNotCancelled()
        guard case let .initial(initial) = state else {
            return try fail(.alreadyConsumed)
        }
        let requestSHA256: InvestigationHandoffSHA256
        do {
            requestSHA256 = InvestigationHandoffSHA256.hashing(
                try request.encoded()
            )
        } catch {
            return try fail(.ownershipInvalid)
        }
        guard
            request.invocation.selection == initial.selection,
            request.mode == outerMode(
                for: initial.selection.epoch.scenario
            ),
            request.epochDeadlineNanoseconds > 0,
            record.requestSHA256 == requestSHA256,
            record.driverChild == sessionDriverChild,
            sessionDriverChild.parentProcessID == outerProcessID,
            sessionDriverChild.processID == sessionDriverChild.processGroupID
        else {
            return try fail(.ownershipInvalid)
        }

        let physical: InvestigationMachineSingleEpochPhysicalOwnership
        do {
            physical = try record.physicalOwnership(
                expectedSelection: initial.selection
            )
        } catch {
            return try fail(.ownershipInvalid)
        }
        guard
            outerPhysicalOwnershipIsBound(
                physical, selection: initial.selection, request: request
            ),
            record.appChild.identity == physical.appIdentity,
            record.appChild.parentProcessID == sessionDriverChild.processID,
            record.appChild.processGroupID == sessionDriverChild.processGroupID
        else {
            return try fail(.ownershipInvalid)
        }

        let observedDriver: InvestigationMachineDarwinDriverChildIdentity
        do {
            try ensureNotCancelled()
            observedDriver = try driverChildObserver.observe(
                processID: sessionDriverChild.processID,
                expectedParentProcessID: outerProcessID
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as InvestigationMachineDarwinDriverChildObservationError {
            return try fail(
                error == .identityInvalid
                    ? .ownershipInvalid : .identityUnavailable
            )
        } catch {
            return try fail(.identityUnavailable)
        }
        guard
            observedDriver == sessionDriverChild,
            observedDriver == record.driverChild
        else {
            return try fail(.ownershipInvalid)
        }

        let observedApp: InvestigationMachineDarwinAppChildIdentity
        do {
            try ensureNotCancelled()
            observedApp = try appIdentityObserver.observePhysicalApp(
                identity: physical.appIdentity,
                projection: initial.selection.projection,
                expectedParentProcessID: observedDriver.processID,
                expectedProcessGroupID: observedDriver.processGroupID
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as InvestigationMachineDarwinAppIdentityObservationError {
            return try fail(
                error == .observationUnavailable
                    ? .identityUnavailable : .ownershipInvalid
            )
        } catch {
            return try fail(.identityUnavailable)
        }
        guard observedApp == record.appChild else {
            return try fail(.ownershipInvalid)
        }

        try ensureNotCancelled()
        state = .owned(.init(
            selection: initial.selection, ownership: record, physical: physical,
            driver: initial.driver, driverSHA256: initial.driverSHA256
        ))
        return .init(driverChild: observedDriver, appChild: observedApp)
    }

    func observeTerminal(
        selection: InvestigationMachineFixedEpochSelection,
        ownership: InvestigationMachineDarwinEpochOwnershipRecord,
        retirement: InvestigationMachineDarwinOuterRetirementOutcome,
        deadlineNanoseconds: UInt64
    ) async throws -> InvestigationMachineDarwinOuterTerminalObservation {
        try ensureNotCancelled()
        guard case let .owned(owned) = state else {
            return try fail(.alreadyConsumed)
        }
        guard
            selection == owned.selection,
            ownership == owned.ownership,
            deadlineNanoseconds == owned.physical.epochDeadlineNanoseconds,
            owned.physical.releaseDeadlineNanoseconds <= deadlineNanoseconds,
            outerExitMatches(
                retirement.directChildExit, mode: owned.physical.mode
            ),
            outerPhysicalOwnershipIsBound(
                owned.physical, selection: owned.selection,
                deadlineNanoseconds: deadlineNanoseconds
            )
        else {
            return try fail(.ownershipInvalid)
        }
        state = .terminalizing

        let absenceObservedAt = try await observeOriginalIdentitiesAbsent(
            physical: owned.physical, deadlineNanoseconds: deadlineNanoseconds
        )
        try ensureTerminalizing()

        let finalDriver: InvestigationMachineInstalledDriverObservation
        do {
            try ensureNotCancelled()
            finalDriver = try installedDriverObserver.observe()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return try fail(.identityUnavailable)
        }
        try ensureTerminalizing()
        guard
            finalDriver == owned.driver,
            outerDriverMatchesProjection(finalDriver, selection: selection)
        else {
            return try fail(.driverObservationMismatch)
        }
        let finalDigest: InvestigationHandoffSHA256
        do {
            finalDigest = try singleEpochDriverObservationSHA256(
                .init(finalDriver)
            )
        } catch {
            return try fail(.identityUnavailable)
        }
        guard finalDigest == owned.driverSHA256 else {
            return try fail(.driverObservationMismatch)
        }

        let finalObservedAt: UInt64
        do {
            try ensureNotCancelled()
            finalObservedAt = try clock.continuousNanoseconds()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return try fail(.identityUnavailable)
        }
        try ensureTerminalizing()
        guard
            finalObservedAt >= absenceObservedAt,
            finalObservedAt > 0,
            finalObservedAt < deadlineNanoseconds
        else {
            return try fail(.deadlineExceeded)
        }
        try ensureNotCancelled()
        state = .terminal
        return try .init(
            appAbsence: .observed, helperAbsence: .observed,
            l1ResidueAbsence: .observed,
            finalDriverObservationSHA256: finalDigest,
            observedAtNanoseconds: finalObservedAt
        )
    }

    private func ensureNotCancelled() throws {
        do {
            try Task.checkCancellation()
        } catch {
            state = .terminal
            throw error
        }
    }

    private func ensureTerminalizing() throws {
        guard case .terminalizing = state else {
            throw InvestigationMachineDarwinOuterObservationError
                .alreadyConsumed
        }
    }

    private func observeOriginalIdentitiesAbsent(
        physical: InvestigationMachineSingleEpochPhysicalOwnership,
        deadlineNanoseconds: UInt64
    ) async throws -> UInt64 {
        var current: UInt64
        var appAbsent = false
        var helperAbsent = false
        do {
            current = try clock.continuousNanoseconds()
        } catch {
            return try fail(.identityUnavailable)
        }
        while current < deadlineNanoseconds {
            try ensureNotCancelled()
            do {
                if !appAbsent {
                    appAbsent = try originalIdentityReader.observeAbsence(
                        of: physical.appIdentity
                    ) == .originalAbsent
                }
                try ensureNotCancelled()
                if !helperAbsent {
                    helperAbsent = try originalIdentityReader.observeAbsence(
                        of: physical.helperIdentity
                    ) == .originalAbsent
                }
            } catch is CancellationError {
                state = .terminal
                throw CancellationError()
            } catch {
                return try fail(.identityUnavailable)
            }
            try ensureNotCancelled()
            let observedAt: UInt64
            do {
                observedAt = try clock.continuousNanoseconds()
            } catch {
                return try fail(.identityUnavailable)
            }
            guard
                observedAt >= current, observedAt < deadlineNanoseconds
            else {
                return try fail(.deadlineExceeded)
            }
            if appAbsent, helperAbsent {
                return observedAt
            }
            let remaining = deadlineNanoseconds - observedAt
            let delay = min(100_000_000, max(1, remaining / 2))
            let nextSample = observedAt.addingReportingOverflow(delay)
            guard !nextSample.overflow,
                  nextSample.partialValue < deadlineNanoseconds else {
                return try fail(.originalIdentityStillPresent)
            }
            do {
                try await waiter.sleep(
                    nanoseconds: delay
                )
                try ensureTerminalizing()
                try ensureNotCancelled()
                let sampledAt = try clock.continuousNanoseconds()
                guard sampledAt >= nextSample.partialValue else {
                    return try fail(.deadlineExceeded)
                }
                guard sampledAt < deadlineNanoseconds else {
                    return try fail(.originalIdentityStillPresent)
                }
                current = sampledAt
            } catch is CancellationError {
                state = .terminal
                throw CancellationError()
            } catch let error as InvestigationMachineDarwinOuterObservationError {
                throw error
            } catch {
                return try fail(.identityUnavailable)
            }
        }
        return try fail(.deadlineExceeded)
    }

    private func fail<Value>(
        _ error: InvestigationMachineDarwinOuterObservationError
    ) throws -> Value {
        state = .terminal
        throw error
    }
}

private func outerPhysicalOwnershipIsBound(
    _ physical: InvestigationMachineSingleEpochPhysicalOwnership,
    selection: InvestigationMachineFixedEpochSelection,
    request: InvestigationMachineDarwinEpochRequest
) -> Bool {
    physical.mode == request.mode
        && physical.epochDeadlineNanoseconds
            == request.epochDeadlineNanoseconds
        && outerPhysicalOwnershipIsBound(
            physical, selection: selection,
            deadlineNanoseconds: request.epochDeadlineNanoseconds
        )
}

private func outerPhysicalOwnershipIsBound(
    _ physical: InvestigationMachineSingleEpochPhysicalOwnership,
    selection: InvestigationMachineFixedEpochSelection,
    deadlineNanoseconds: UInt64
) -> Bool {
    let evidence = physical.claimEvidence
    guard let evidenceBytes = try? evidence.encoded() else { return false }
    return physical.isBound(to: selection)
        && physical.epochDeadlineNanoseconds == deadlineNanoseconds
        && physical.releaseDeadlineNanoseconds > 0
        && physical.releaseDeadlineNanoseconds <= deadlineNanoseconds
        && physical.claimEvidenceSHA256
            == InvestigationHandoffSHA256.hashing(evidenceBytes)
        && evidence.requestBindingSHA256.rawBytes.contains { $0 != 0 }
        && evidence.appIdentity == physical.appIdentity
        && evidence.helperIdentity == physical.helperIdentity
        && evidence.l1Residue.investigationUUID
            == selection.epoch.configurationNonce
        && evidence.l1Residue.auditSessionID
            == physical.helperIdentity.auditSessionID
        && evidence.l1Residue.userID == physical.appIdentity.effectiveUserID
        && evidence.l1Residue.remainingAuditSessionMembers == 0
        && evidence.l1Residue.matchingLeases == 0
        && evidence.l1Residue.leaseRootEntries == 0
        && evidence.l1Residue.investigationArtifacts == 0
        && evidence.releaseDeadlineNanoseconds
            == physical.releaseDeadlineNanoseconds
}

private func outerMode(
    for scenario: InvestigationHandoffScenario
) -> InvestigationMachineOuterContainmentMode {
    scenario == .lifecycleRecovery ? .parentCrash : .normal
}

private func outerExitMatches(
    _ exit: InvestigationMachineDarwinDirectChildExitClassification,
    mode: InvestigationMachineOuterContainmentMode
) -> Bool {
    switch (mode, exit) {
    case (.normal, .ordinaryZero),
         (.parentCrash, .deliberateParentCrash):
        true
    default:
        false
    }
}

private func outerDriverMatchesProjection(
    _ observation: InvestigationMachineInstalledDriverObservation,
    selection: InvestigationMachineFixedEpochSelection
) -> Bool {
    let projection = selection.projection
    return observation.executableSHA256
            == projection.machineDriverExecutableSHA256.lowercaseHex
        && observation.signing.signingIdentifier
            == projection.machineDriverSigningIdentifier
        && observation.signing.designatedRequirementSHA256
            == projection.machineDriverDesignatedRequirementSHA256.lowercaseHex
        && observation.signing.codeDirectoryHash
            == projection.machineDriverCodeDirectoryHash
                .map { String(format: "%02x", $0) }.joined()
        && observation.manifest.primaryServiceIdentifier
            == projection.helperServiceIdentifier
        && observation.manifest.machineClaimServiceIdentifier
            == projection.machineClaimServiceIdentifier
}
