import Darwin
import Foundation
import StornautInvestigationHandoffContract

package enum InvestigationMachineDarwinOuterInnerCompositionError:
    Error, Sendable, Equatable
{
    case alreadyConsumed
    case invalidSelection
    case deadlineInvalid
    case protocolInvalid
    case terminalUncertain
    case cancelled
}

protocol InvestigationMachineDarwinOuterInnerCompositionClocking:
    Sendable
{
    func continuousNanoseconds() throws -> UInt64
}

protocol InvestigationMachineDarwinOuterInnerCompositionSession:
    Sendable
{
    var driverChildIdentity: InvestigationMachineDarwinDriverChildIdentity { get }

    func sendControl(
        _ payload: Data, deadlineNanoseconds: UInt64
    ) async throws
    func receiveControl(deadlineNanoseconds: UInt64) async throws -> Data
    func receiveResult(deadlineNanoseconds: UInt64) async throws -> Data?
    func proveControlEOF(deadlineNanoseconds: UInt64) async throws
    func proveResultEOF(deadlineNanoseconds: UInt64) async throws
    func retireOwnedProcessGroupWithOutcome() async throws
        -> InvestigationMachineDarwinOuterRetirementOutcome
}

protocol InvestigationMachineDarwinOuterInnerCompositionSessionStarting:
    Sendable
{
    func startSession(deadlineNanoseconds: UInt64) async throws
        -> any InvestigationMachineDarwinOuterInnerCompositionSession
}

struct InvestigationMachineDarwinOuterOwnershipObservation:
    Sendable, Equatable
{
    let driverChild: InvestigationMachineDarwinDriverChildIdentity
    let appChild: InvestigationMachineDarwinAppChildIdentity

    init(
        driverChild: InvestigationMachineDarwinDriverChildIdentity,
        appChild: InvestigationMachineDarwinAppChildIdentity
    ) {
        self.driverChild = driverChild
        self.appChild = appChild
    }
}

protocol InvestigationMachineDarwinOuterOwnershipObserving: Sendable {
    func observeOwnership(
        request: InvestigationMachineDarwinEpochRequest,
        record: InvestigationMachineDarwinEpochOwnershipRecord,
        sessionDriverChild: InvestigationMachineDarwinDriverChildIdentity
    ) async throws -> InvestigationMachineDarwinOuterOwnershipObservation
}

struct InvestigationMachineDarwinOuterTerminalObservation:
    Sendable, Equatable
{
    enum AbsenceProof: Sendable, Equatable {
        case observed
    }

    fileprivate let appAbsence: AbsenceProof
    fileprivate let helperAbsence: AbsenceProof
    fileprivate let l1ResidueAbsence: AbsenceProof
    let finalDriverObservationSHA256: InvestigationHandoffSHA256
    let observedAtNanoseconds: UInt64

    init(
        appAbsence: AbsenceProof, helperAbsence: AbsenceProof,
        l1ResidueAbsence: AbsenceProof,
        finalDriverObservationSHA256: InvestigationHandoffSHA256,
        observedAtNanoseconds: UInt64
    ) throws {
        guard
            finalDriverObservationSHA256.rawBytes.contains(where: { $0 != 0 }),
            observedAtNanoseconds > 0
        else {
            throw InvestigationMachineDarwinOuterInnerCompositionError
                .terminalUncertain
        }
        self.appAbsence = appAbsence
        self.helperAbsence = helperAbsence
        self.l1ResidueAbsence = l1ResidueAbsence
        self.finalDriverObservationSHA256 = finalDriverObservationSHA256
        self.observedAtNanoseconds = observedAtNanoseconds
    }
}

protocol InvestigationMachineDarwinOuterTerminalObserving: Sendable {
    func observeInitialDriver(
        selection: InvestigationMachineFixedEpochSelection
    ) async throws -> InvestigationHandoffSHA256

    func observeTerminal(
        selection: InvestigationMachineFixedEpochSelection,
        ownership: InvestigationMachineDarwinEpochOwnershipRecord,
        retirement: InvestigationMachineDarwinOuterRetirementOutcome,
        deadlineNanoseconds: UInt64
    ) async throws -> InvestigationMachineDarwinOuterTerminalObservation
}

protocol InvestigationMachineDarwinInnerRoleValidating: Sendable {
    func validate() throws -> InvestigationMachineDarwinInnerRoleObservation
}

extension InvestigationMachineDarwinInnerRoleValidator:
    InvestigationMachineDarwinInnerRoleValidating {}

protocol InvestigationMachineDarwinInnerChanneling: Sendable {
    func receiveControl(deadlineNanoseconds: UInt64) async throws -> Data
    func sendControl(
        _ payload: Data, deadlineNanoseconds: UInt64
    ) async throws
    func sendResult(
        _ payload: Data, deadlineNanoseconds: UInt64
    ) async throws
}

package struct InvestigationMachineDarwinFixedInnerChannel:
    InvestigationMachineDarwinInnerChanneling, Sendable
{
    private let messageSystem: InvestigationMachineDarwinBoundedMessageSystem

    package init() {
        messageSystem = .system
    }

    init(messageSystem: InvestigationMachineDarwinBoundedMessageSystem) {
        self.messageSystem = messageSystem
    }

    package func receiveControl(
        deadlineNanoseconds: UInt64
    ) async throws -> Data {
        try await InvestigationMachineDarwinBoundedMessageIO.read(
            descriptor: 8, maximumByteCount: 128 * 1_024,
            deadlineNanoseconds: deadlineNanoseconds, system: messageSystem
        )
    }

    package func sendControl(
        _ payload: Data, deadlineNanoseconds: UInt64
    ) async throws {
        try await InvestigationMachineDarwinBoundedMessageIO.write(
            payload, descriptor: 8, maximumByteCount: 128 * 1_024,
            deadlineNanoseconds: deadlineNanoseconds, system: messageSystem
        )
    }

    package func sendResult(
        _ payload: Data, deadlineNanoseconds: UInt64
    ) async throws {
        try await InvestigationMachineDarwinBoundedMessageIO.write(
            payload, descriptor: 9, maximumByteCount: 16 * 1_024,
            deadlineNanoseconds: deadlineNanoseconds, system: messageSystem
        )
    }
}

package enum InvestigationMachineDarwinInnerPhysicalOutcome: Sendable {
    case normal(InvestigationMachineSingleEpochPhysicalResult)
    case parentCrash
}

protocol InvestigationMachineDarwinInnerPhysicalRunning: Sendable {
    func run(
        request: InvestigationMachineDarwinEpochRequest,
        ownershipExchange: InvestigationMachineDarwinInnerOwnershipExchange
    ) async throws -> InvestigationMachineDarwinInnerPhysicalOutcome
}

protocol InvestigationMachineDarwinInnerPhysicalComposerMaking:
    Sendable
{
    func makeComposer(
        selection: InvestigationMachineFixedEpochSelection,
        ownershipSuspender:
            any InvestigationMachineSingleEpochOwnershipSuspending
    ) throws -> any InvestigationMachinePhysicalSingleEpochComposing
}

package struct InvestigationMachineDarwinInnerPhysicalRunner:
    InvestigationMachineDarwinInnerPhysicalRunning, Sendable
{
    private let factory:
        any InvestigationMachineDarwinInnerPhysicalComposerMaking

    init(
        factory: any InvestigationMachineDarwinInnerPhysicalComposerMaking
    ) {
        self.factory = factory
    }

    package func run(
        request: InvestigationMachineDarwinEpochRequest,
        ownershipExchange: InvestigationMachineDarwinInnerOwnershipExchange
    ) async throws -> InvestigationMachineDarwinInnerPhysicalOutcome {
        let composer = try factory.makeComposer(
            selection: request.invocation.selection,
            ownershipSuspender: ownershipExchange
        )
        guard composer.isBound(to: request.invocation.selection) else {
            throw InvestigationMachineDarwinOuterInnerCompositionError
                .invalidSelection
        }
        let result = try await composer.run(
            invocation: request.invocation,
            epochDeadlineNanoseconds: request.epochDeadlineNanoseconds
        )
        switch result {
        case let .localCompletion(completion) where request.mode == .normal:
            return .normal(try .init(projecting: .localCompletion(completion)))
        case .ownershipTransferred where request.mode == .parentCrash:
            return .parentCrash
        case .localCompletion, .ownershipTransferred, .admittedPhysical:
            throw InvestigationMachineDarwinOuterInnerCompositionError
                .protocolInvalid
        }
    }
}

struct InvestigationMachineDarwinCompositionClock:
    InvestigationMachineDarwinOuterInnerCompositionClocking,
    InvestigationMachineSingleEpochClocking, Sendable
{
    func continuousNanoseconds() throws -> UInt64 {
        var timebase = mach_timebase_info_data_t()
        guard mach_timebase_info(&timebase) == KERN_SUCCESS, timebase.denom > 0
        else {
            throw InvestigationMachineDarwinOuterInnerCompositionError
                .deadlineInvalid
        }
        let product = mach_continuous_time()
            .multipliedFullWidth(by: UInt64(timebase.numer))
        guard product.high < UInt64(timebase.denom) else {
            throw InvestigationMachineDarwinOuterInnerCompositionError
                .deadlineInvalid
        }
        return UInt64(timebase.denom).dividingFullWidth(product).quotient
    }
}

struct InvestigationMachineDarwinClaimClientFactory:
    InvestigationMachineSingleEpochClaimClientFactory, Sendable
{
    func make() -> any InvestigationMachineSingleEpochClaiming {
        InvestigationMachineClaimClient()
    }
}

struct InvestigationMachineDarwinInnerPhysicalComposerFactory:
    InvestigationMachineDarwinInnerPhysicalComposerMaking, Sendable
{
    func makeComposer(
        selection: InvestigationMachineFixedEpochSelection,
        ownershipSuspender:
            any InvestigationMachineSingleEpochOwnershipSuspending
    ) throws -> any InvestigationMachinePhysicalSingleEpochComposing {
        let retirementOwner = InvestigationMachineDarwinEpochRetirementOwner()
        return InvestigationMachineSingleEpochComposer(
            commitment: try .init(selection: selection),
            observer: InvestigationMachineInstalledDriverObserver(
                realUserID: Darwin.getuid, effectiveUserID: Darwin.geteuid,
                realGroupID: Darwin.getgid, effectiveGroupID: Darwin.getegid,
                argumentCount: { Int32(CommandLine.argc) },
                source: InvestigationMachineInstalledDriverSystemSource(
                    system: DarwinInvestigationMachineInstalledDriverSystem()
                )
            ),
            clock: InvestigationMachineDarwinCompositionClock(),
            sessionFactory: InvestigationMachineDarwinEpochSessionFactory(
                projection: selection.projection,
                identityObserver: InvestigationMachineDarwinAppIdentityObserver(),
                retirementOwner: retirementOwner, system: .system,
                topologyPolicy: .inheritedInnerProcessGroup
            ),
            claimClientFactory: InvestigationMachineDarwinClaimClientFactory(),
            ownershipSuspender: ownershipSuspender
        )
    }
}

protocol InvestigationMachineDarwinInnerCrashing: Sendable {
    func crashNow() throws -> Never
}

struct InvestigationMachineDarwinInnerCrash:
    InvestigationMachineDarwinInnerCrashing, Sendable
{
    static let deliberateExitStatus =
        InvestigationMachineDarwinDirectChildExitClassification
            .deliberateParentCrashExitStatus

    func crashNow() -> Never {
        Darwin._exit(Self.deliberateExitStatus)
    }
}

package struct InvestigationMachineDarwinInnerOwnershipExchange:
    InvestigationMachineSingleEpochOwnershipSuspending, Sendable
{
    package let observedAtNanoseconds: UInt64
    private let request: InvestigationMachineDarwinEpochRequest
    private let driverChild: InvestigationMachineDarwinDriverChildIdentity
    private let state: InvestigationMachineDarwinInnerProtocolState
    private let channel: any InvestigationMachineDarwinInnerChanneling

    init(
        request: InvestigationMachineDarwinEpochRequest,
        driverChild: InvestigationMachineDarwinDriverChildIdentity,
        state: InvestigationMachineDarwinInnerProtocolState,
        channel: any InvestigationMachineDarwinInnerChanneling,
        observedAtNanoseconds: UInt64
    ) {
        self.request = request
        self.driverChild = driverChild
        self.state = state
        self.channel = channel
        self.observedAtNanoseconds = observedAtNanoseconds
    }

    package func suspend(
        _ candidate: InvestigationMachineSingleEpochOwnershipCandidate
    ) async -> InvestigationMachineSingleEpochOwnershipResolution {
        do {
            let resolution = try await exchange(
                .init(projecting: candidate), candidate: candidate
            )
            guard !Task.isCancelled else { return .terminalUncertain }
            return resolution
        } catch {
            return .terminalUncertain
        }
    }

    func exchange(
        _ physicalOwnership: InvestigationMachineSingleEpochPhysicalOwnership
    ) async throws -> InvestigationMachineOuterContainmentMode {
        let decision = try await exchangeDecision(physicalOwnership)
        return decision.kind == .continue ? .normal : .parentCrash
    }

    private func exchangeDecision(
        _ physicalOwnership: InvestigationMachineSingleEpochPhysicalOwnership
    ) async throws -> InvestigationMachineDarwinEpochDecision {
        try Task.checkCancellation()
        let appChild = try InvestigationMachineDarwinAppChildIdentity(
            identity: physicalOwnership.appIdentity,
            parentProcessID: driverChild.processID,
            processGroupID: driverChild.processGroupID
        )
        let record = try InvestigationMachineDarwinEpochOwnershipRecord(
            request: request, driverChild: driverChild, appChild: appChild,
            physicalOwnership: physicalOwnership
        )
        _ = try await state.emit(record)
        try await channel.sendControl(
            record.encoded(),
            deadlineNanoseconds: request.epochDeadlineNanoseconds
        )
        try Task.checkCancellation()
        let acknowledgement = try InvestigationMachineDarwinEpochAcknowledgement
            .decode(try await channel.receiveControl(
                deadlineNanoseconds: request.epochDeadlineNanoseconds
            ))
        try await state.accept(acknowledgement)
        try Task.checkCancellation()
        let decision = try InvestigationMachineDarwinEpochDecision.decode(
            try await channel.receiveControl(
                deadlineNanoseconds: request.epochDeadlineNanoseconds
            )
        )
        try await state.accept(decision)
        try Task.checkCancellation()
        return decision
    }

    private func exchange(
        _ physicalOwnership: InvestigationMachineSingleEpochPhysicalOwnership,
        candidate: InvestigationMachineSingleEpochOwnershipCandidate
    ) async throws -> InvestigationMachineSingleEpochOwnershipResolution {
        let decision = try await exchangeDecision(physicalOwnership)
        switch decision.kind {
        case .continue:
            return .resumeLocal(candidate)
        case .crashNow:
            return .outerOwnsTerminal(candidate)
        }
    }
}

package enum InvestigationMachineDarwinInnerCompletion: Sendable, Equatable {
    case normal
}

struct InvestigationMachineDarwinOuterExecutionDependencies: Sendable {
    let outerProcessID: UInt32
    let sessionFactory:
        any InvestigationMachineDarwinOuterInnerCompositionSessionStarting
    let ownershipObserver: any InvestigationMachineDarwinOuterOwnershipObserving
    let terminalObserver: any InvestigationMachineDarwinOuterTerminalObserving
    let clock: any InvestigationMachineDarwinOuterInnerCompositionClocking
}

struct InvestigationMachineDarwinOuterExecutionComponents: Sendable {
    let composer: any InvestigationMachineSingleEpochComposing
    let prover: any InvestigationMachineOuterContainmentProving
}

package struct InvestigationMachineDarwinOuterInnerExecutionFactory:
    InvestigationMachineEightEpochExecutionFactory, Sendable
{
    typealias Dependencies = InvestigationMachineDarwinOuterExecutionDependencies
    typealias MakeDependencies = @Sendable (
        InvestigationMachineFixedEpochSelection
    ) throws -> Dependencies

    private let makeDependencies: MakeDependencies

    init(makeDependencies: @escaping MakeDependencies) {
        self.makeDependencies = makeDependencies
    }

    package func makeExecution(
        for selection: InvestigationMachineFixedEpochSelection,
        mode: InvestigationMachineOuterContainmentMode
    ) async throws -> InvestigationMachineEightEpochExecution {
        let components = try components(for: selection, mode: mode)
        return InvestigationMachineEightEpochExecution(
            selection: selection, mode: mode,
            composer: components.composer, prover: components.prover
        )
    }

    func components(
        for selection: InvestigationMachineFixedEpochSelection,
        mode: InvestigationMachineOuterContainmentMode
    ) throws -> InvestigationMachineDarwinOuterExecutionComponents {
        let expected: InvestigationMachineOuterContainmentMode =
            selection.epoch.scenario == .lifecycleRecovery
                ? .parentCrash : .normal
        guard mode == expected else {
            throw InvestigationMachineDarwinOuterInnerCompositionError
                .invalidSelection
        }
        let dependencies = try makeDependencies(selection)
        guard dependencies.outerProcessID > 1 else {
            throw InvestigationMachineDarwinOuterInnerCompositionError
                .invalidSelection
        }
        let admission = InvestigationMachineDarwinOuterAdmission(
            selection: selection, outerProcessID: dependencies.outerProcessID
        )
        let composition = InvestigationMachineDarwinOuterInnerComposition(
            selection: selection, admission: admission,
            sessionFactory: dependencies.sessionFactory,
            ownershipObserver: dependencies.ownershipObserver,
            terminalObserver: dependencies.terminalObserver,
            clock: dependencies.clock
        )
        return .init(composer: composition, prover: admission)
    }
}

package actor InvestigationMachineDarwinOuterInnerComposition:
    InvestigationMachineSingleEpochComposing
{
    static let maximumEpochWindowNanoseconds: UInt64 = 140_000_000_000

    private enum State {
        case ready
        case running
        case terminal
    }

    nonisolated private let selection: InvestigationMachineFixedEpochSelection?
    private let admission: InvestigationMachineDarwinOuterAdmission?
    private let sessionFactory:
        (any InvestigationMachineDarwinOuterInnerCompositionSessionStarting)?
    private let ownershipObserver:
        (any InvestigationMachineDarwinOuterOwnershipObserving)?
    private let terminalObserver:
        (any InvestigationMachineDarwinOuterTerminalObserving)?
    private let clock: any InvestigationMachineDarwinOuterInnerCompositionClocking
    private let innerRoleValidator:
        (any InvestigationMachineDarwinInnerRoleValidating)?
    private let innerChannel: (any InvestigationMachineDarwinInnerChanneling)?
    private let innerPhysicalRunner:
        (any InvestigationMachineDarwinInnerPhysicalRunning)?
    private let innerCrash: (any InvestigationMachineDarwinInnerCrashing)?
    private var state = State.ready

    fileprivate init(
        selection: InvestigationMachineFixedEpochSelection,
        admission: InvestigationMachineDarwinOuterAdmission,
        sessionFactory:
            any InvestigationMachineDarwinOuterInnerCompositionSessionStarting,
        ownershipObserver: any InvestigationMachineDarwinOuterOwnershipObserving,
        terminalObserver: any InvestigationMachineDarwinOuterTerminalObserving,
        clock: any InvestigationMachineDarwinOuterInnerCompositionClocking
    ) {
        self.selection = selection
        self.admission = admission
        self.sessionFactory = sessionFactory
        self.ownershipObserver = ownershipObserver
        self.terminalObserver = terminalObserver
        self.clock = clock
        innerRoleValidator = nil
        innerChannel = nil
        innerPhysicalRunner = nil
        innerCrash = nil
    }

    init(
        innerRoleValidator:
            any InvestigationMachineDarwinInnerRoleValidating,
        innerChannel: any InvestigationMachineDarwinInnerChanneling,
        innerPhysicalRunner: any InvestigationMachineDarwinInnerPhysicalRunning,
        innerCrash: any InvestigationMachineDarwinInnerCrashing,
        clock: any InvestigationMachineDarwinOuterInnerCompositionClocking
    ) {
        selection = nil
        admission = nil
        sessionFactory = nil
        ownershipObserver = nil
        terminalObserver = nil
        self.clock = clock
        self.innerRoleValidator = innerRoleValidator
        self.innerChannel = innerChannel
        self.innerPhysicalRunner = innerPhysicalRunner
        self.innerCrash = innerCrash
    }

    package init() {
        selection = nil
        admission = nil
        sessionFactory = nil
        ownershipObserver = nil
        terminalObserver = nil
        clock = InvestigationMachineDarwinCompositionClock()
        innerRoleValidator = InvestigationMachineDarwinInnerRoleValidator()
        innerChannel = InvestigationMachineDarwinFixedInnerChannel()
        innerPhysicalRunner = InvestigationMachineDarwinInnerPhysicalRunner(
            factory: InvestigationMachineDarwinInnerPhysicalComposerFactory()
        )
        innerCrash = InvestigationMachineDarwinInnerCrash()
    }

    nonisolated func isBound(
        to value: InvestigationMachineFixedEpochSelection
    ) -> Bool {
        value == selection
    }

    func run(
        previousHelperIdentity: InvestigationMachineProcessIdentity?
    ) async throws -> InvestigationMachineSingleEpochResult {
        _ = previousHelperIdentity
        try beginRun()
        defer { state = .terminal }
        throw InvestigationMachineDarwinOuterInnerCompositionError
            .invalidSelection
    }

    func run(
        invocation: InvestigationMachineSingleEpochInvocation
    ) async throws -> InvestigationMachineSingleEpochResult {
        try beginRun()
        defer { state = .terminal }
        guard
            let selection, let admission, let sessionFactory,
            let ownershipObserver, let terminalObserver,
            invocation.selection == selection
        else {
            throw InvestigationMachineDarwinOuterInnerCompositionError
                .invalidSelection
        }

        var session:
            (any InvestigationMachineDarwinOuterInnerCompositionSession)?
        var retired = false
        do {
            try checkCancellation()
            let initialDriverObservationSHA256 = try await terminalObserver
                .observeInitialDriver(selection: selection)
            try checkCancellation()
            let now = try clock.continuousNanoseconds()
            let maximum = now.addingReportingOverflow(
                Self.maximumEpochWindowNanoseconds
            )
            guard !maximum.overflow else {
                throw InvestigationMachineDarwinOuterInnerCompositionError
                    .deadlineInvalid
            }
            let deadline = maximum.partialValue
            let request = try InvestigationMachineDarwinEpochRequest(
                invocation: invocation, epochDeadlineNanoseconds: deadline
            )

            try await admission.accept(request)
            try checkCancellation()
            let started = try await sessionFactory.startSession(
                deadlineNanoseconds: deadline
            )
            session = started
            try checkCancellation()
            try await started.sendControl(
                request.encoded(), deadlineNanoseconds: deadline
            )
            try checkCancellation()
            let ownership = try InvestigationMachineDarwinEpochOwnershipRecord
                .decode(try await started.receiveControl(
                    deadlineNanoseconds: deadline
                ))
            try checkCancellation()
            let topology = try await ownershipObserver.observeOwnership(
                request: request, record: ownership,
                sessionDriverChild: started.driverChildIdentity
            )
            guard topology.driverChild == started.driverChildIdentity else {
                throw InvestigationMachineDarwinOuterInnerCompositionError
                    .protocolInvalid
            }
            let acknowledgement = try await admission.acceptOwnership(
                ownership, observedDriverChild: topology.driverChild,
                observedAppChild: topology.appChild
            )
            try checkCancellation()
            try await started.sendControl(
                acknowledgement.encoded(), deadlineNanoseconds: deadline
            )
            let decision = try await admission.issueDecision(acknowledgement)
            try checkCancellation()
            try await started.sendControl(
                decision.encoded(), deadlineNanoseconds: deadline
            )
            try checkCancellation()

            let resultBytes: Data
            switch request.mode {
            case .normal:
                guard let bytes = try await started.receiveResult(
                    deadlineNanoseconds: deadline
                ), !bytes.isEmpty else {
                    throw InvestigationMachineDarwinOuterInnerCompositionError
                        .protocolInvalid
                }
                _ = try InvestigationMachineDarwinEpochNormalResult.decode(
                    bytes, expectedSelection: selection
                )
                resultBytes = bytes
            case .parentCrash:
                guard try await started.receiveResult(
                    deadlineNanoseconds: deadline
                ) == nil else {
                    throw InvestigationMachineDarwinOuterInnerCompositionError
                        .protocolInvalid
                }
                resultBytes = Data()
            }
            try checkCancellation()
            try await started.proveResultEOF(deadlineNanoseconds: deadline)
            try checkCancellation()
            try await started.proveControlEOF(deadlineNanoseconds: deadline)
            try checkCancellation()

            let retirement = try await started
                .retireOwnedProcessGroupWithOutcome()
            retired = true
            guard Self.exitMatches(
                retirement.directChildExit, mode: request.mode
            ) else {
                throw InvestigationMachineDarwinOuterInnerCompositionError
                    .terminalUncertain
            }
            try checkCancellation()
        let terminal = try await terminalObserver.observeTerminal(
                selection: selection, ownership: ownership,
                retirement: retirement, deadlineNanoseconds: deadline
            )
            let physicalOwnership = try ownership.physicalOwnership(
                expectedSelection: selection
            )
            let evidence = try InvestigationMachineDarwinEpochTerminalEvidence(
                controlEOFObserved: true, resultEOFObserved: true,
                driverChild: topology.driverChild, appChild: topology.appChild,
                helperIdentity: physicalOwnership.helperIdentity,
                innerExitedSuccessfully:
                    retirement.directChildExit == .ordinaryZero,
                appAbsent: terminal.appAbsence == .observed,
                groupLeaderReapedLast: true, postReapGroupEmpty: true,
                helperAbsent: terminal.helperAbsence == .observed,
                l1ResidueAbsent: terminal.l1ResidueAbsence == .observed,
                initialDriverObservationSHA256:
                    initialDriverObservationSHA256,
                finalDriverObservationSHA256:
                    terminal.finalDriverObservationSHA256,
                observedAtNanoseconds: terminal.observedAtNanoseconds
            )
            try checkCancellation()
            let admitted = try await admission.admit(
                resultBytes: resultBytes, terminalEvidence: evidence
            )
            try checkCancellation()
            return admitted
        } catch {
            let cancellationRequested = Task.isCancelled
            if let session, !retired {
                let cleaned = await Task.detached {
                    try? await session.retireOwnedProcessGroupWithOutcome()
                }.value
                guard cleaned != nil else {
                    throw InvestigationMachineDarwinOuterInnerCompositionError
                        .terminalUncertain
                }
            }
            if cancellationRequested {
                throw InvestigationMachineDarwinOuterInnerCompositionError
                    .cancelled
            }
            throw Self.normalized(error)
        }
    }

    package func runInner() async throws
        -> InvestigationMachineDarwinInnerCompletion
    {
        try beginRun()
        defer { state = .terminal }
        guard
            selection == nil, let innerRoleValidator, let innerChannel,
            let innerPhysicalRunner, let innerCrash
        else {
            throw InvestigationMachineDarwinOuterInnerCompositionError
                .invalidSelection
        }
        try checkCancellation()
        let role = try innerRoleValidator.validate()
        let readStartedAt = try clock.continuousNanoseconds()
        let maximum = readStartedAt.addingReportingOverflow(
            Self.maximumEpochWindowNanoseconds
        )
        guard !maximum.overflow else {
            throw InvestigationMachineDarwinOuterInnerCompositionError
                .deadlineInvalid
        }
        let request = try InvestigationMachineDarwinEpochRequest.decodeUntrusted(
            try await innerChannel.receiveControl(
                deadlineNanoseconds: maximum.partialValue
            )
        )
        try checkCancellation()
        let observedAt = try clock.continuousNanoseconds()
        guard
            observedAt >= readStartedAt,
            request.epochDeadlineNanoseconds > observedAt,
            request.epochDeadlineNanoseconds <= maximum.partialValue
        else {
            throw InvestigationMachineDarwinOuterInnerCompositionError
                .deadlineInvalid
        }
        let innerState = InvestigationMachineDarwinInnerProtocolState(
            selection: request.invocation.selection
        )
        let exchange = InvestigationMachineDarwinInnerOwnershipExchange(
            request: request, driverChild: role.driverChildIdentity,
            state: innerState, channel: innerChannel,
            observedAtNanoseconds: observedAt
        )
        try await innerState.accept(
            request, observedAtNanoseconds: observedAt
        )
        let outcome = try await innerPhysicalRunner.run(
            request: request, ownershipExchange: exchange
        )
        try checkCancellation()
        switch outcome {
        case let .normal(physicalResult):
            guard request.mode == .normal else {
                throw InvestigationMachineDarwinOuterInnerCompositionError
                    .protocolInvalid
            }
            let result = try await innerState.finish(physicalResult)
            try await innerChannel.sendResult(
                result.encoded(),
                deadlineNanoseconds: request.epochDeadlineNanoseconds
            )
            try checkCancellation()
            return .normal
        case .parentCrash:
            guard request.mode == .parentCrash else {
                throw InvestigationMachineDarwinOuterInnerCompositionError
                    .protocolInvalid
            }
            try innerCrash.crashNow()
        }
    }

    private func beginRun() throws {
        guard case .ready = state else {
            throw InvestigationMachineDarwinOuterInnerCompositionError
                .alreadyConsumed
        }
        state = .running
    }

    private func checkCancellation() throws {
        guard !Task.isCancelled else {
            throw InvestigationMachineDarwinOuterInnerCompositionError.cancelled
        }
    }

    private static func exitMatches(
        _ exit: InvestigationMachineDarwinDirectChildExitClassification,
        mode: InvestigationMachineOuterContainmentMode
    ) -> Bool {
        switch (mode, exit) {
        case (.normal, .ordinaryZero),
             (.parentCrash, .deliberateParentCrash):
            true
        default: false
        }
    }

    private static func normalized(
        _ error: any Error
    ) -> InvestigationMachineDarwinOuterInnerCompositionError {
        if let error = error as?
            InvestigationMachineDarwinOuterInnerCompositionError
        {
            return error
        }
        if error is CancellationError { return .cancelled }
        if error is InvestigationMachineDarwinOuterInnerProtocolError {
            return .protocolInvalid
        }
        return .terminalUncertain
    }
}
