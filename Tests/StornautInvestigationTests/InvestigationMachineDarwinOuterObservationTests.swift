import Darwin
import Foundation
import Testing

@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationInstalledL2
@testable import StornautInvestigationMachineDriverSupport

@Suite("Investigation machine Darwin outer observation", .serialized)
struct InvestigationMachineDarwinOuterObservationTests {
    @Test(arguments: [OriginalIdentityAbsenceKind.esrch, .identityReused])
    fileprivate func originalIdentityReaderAcceptsOnlyConclusiveAbsence(
        _ kind: OriginalIdentityAbsenceKind
    ) throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let expected = fixture.appChild.identity
        let reader = InvestigationMachineDarwinOriginalIdentityReader { processID in
            #expect(processID == expected.processID)
            switch kind {
            case .esrch:
                return .failure(.init(errno: ESRCH))
            case .identityReused:
                return .success(reusedNarrowIdentity(from: expected))
            case .helperInitiallyPresentThenAbsent:
                Issue.record("polling-only scenario reached direct reader test")
                return .failure(.init(errno: EIO))
            }
        }

        #expect(
            try reader.observeAbsence(of: expected) == .originalAbsent
        )
        #expect(!(InvestigationMachineDarwinOriginalIdentityObservation.self
            is any Codable.Type))
    }

    @Test
    func originalIdentityReaderKeepsTheExactIdentityPresent() throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let expected = fixture.appChild.identity
        let reader = InvestigationMachineDarwinOriginalIdentityReader { _ in
            .success(outerNarrowIdentity(from: expected))
        }

        #expect(
            try reader.observeAbsence(of: expected) == .originalPresent
        )
    }

    @Test(arguments: OriginalIdentitySameVersionDrift.allCases)
    fileprivate func originalIdentityReaderRejectsSameVersionIdentityDrift(
        _ drift: OriginalIdentitySameVersionDrift
    ) throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let expected = fixture.appChild.identity
        let reader = InvestigationMachineDarwinOriginalIdentityReader { _ in
            .success(drift.apply(to: expected))
        }

        #expect(throws:
            InvestigationMachineDarwinAppIdentityObservationError
                .observationUnavailable
        ) {
            _ = try reader.observeAbsence(of: expected)
        }
    }

    @Test(arguments: OriginalIdentityUnavailableKind.allCases)
    fileprivate func originalIdentityReaderRejectsAmbiguousOrMalformedReads(
        _ kind: OriginalIdentityUnavailableKind
    ) throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let expected = fixture.appChild.identity
        let reader = InvestigationMachineDarwinOriginalIdentityReader { _ in
            kind.result(for: expected)
        }

        #expect(throws:
            InvestigationMachineDarwinAppIdentityObservationError
                .observationUnavailable
        ) {
            _ = try reader.observeAbsence(of: expected)
        }
    }

    @Test
    func physicalAppObservationRevalidatesExactIdentityAndTopology() throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let system = OuterObservationAppIdentitySystem(
            identity: fixture.appChild.identity,
            parentProcessID: fixture.driverChild.processID,
            processGroupID: fixture.driverChild.processGroupID,
            projection: fixture.selection.projection
        )

        let observed = try InvestigationMachineDarwinAppIdentityObserver(
            system: system
        ).observePhysicalApp(
            identity: fixture.appChild.identity,
            projection: fixture.selection.projection,
            expectedParentProcessID: fixture.driverChild.processID,
            expectedProcessGroupID: fixture.driverChild.processGroupID
        )

        #expect(observed == fixture.appChild)
        #expect(system.observedProcessIDs == Array(
            repeating: fixture.appChild.identity.processID, count: 7
        ))
    }

    @Test
    func ownershipObserverAcceptsOnlyTheExactPhysicalOwnership() async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let harness = try OuterObservationHarness(fixture: fixture)
        let initial = try await harness.observer.observeInitialDriver(
            selection: fixture.selection
        )
        let ownership = try await harness.observer.observeOwnership(
            request: fixture.request, record: fixture.ownershipRecord,
            sessionDriverChild: fixture.driverChild
        )

        let expectedDigest = try driverObservationDigest(
            harness.initialObservation
        )
        #expect(initial == expectedDigest)
        #expect(ownership.driverChild == fixture.driverChild)
        #expect(ownership.appChild == fixture.appChild)
        #expect(harness.driverObserver.calls == [
            .init(
                processID: fixture.driverChild.processID,
                expectedParentProcessID: fixture.outerProcessID
            ),
        ])
        #expect(!(InvestigationMachineDarwinOuterOwnershipObservation.self
            is any Codable.Type))
    }

    @Test(arguments: OuterOwnershipMismatch.allCases)
    fileprivate func ownershipObserverRejectsDriverAppSessionAndClaimMismatch(
        _ mismatch: OuterOwnershipMismatch
    ) async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let driftedDriver = try fixture.driverChild(
            processID: fixture.driverChild.processID + 20,
            processIDVersion: fixture.driverChild.processIDVersion + 1
        )
        let harness = try OuterObservationHarness(
            fixture: fixture,
            observedDriver: mismatch == .driver ? driftedDriver : nil,
            observedAppIdentity: mismatch == .app
                ? reusedProcessIdentity(from: fixture.appChild.identity) : nil
        )
        _ = try await harness.observer.observeInitialDriver(
            selection: fixture.selection
        )

        await #expect(throws:
            InvestigationMachineDarwinOuterObservationError.ownershipInvalid
        ) {
            _ = try await harness.observer.observeOwnership(
                request: fixture.request,
                record: mismatch == .claimRequestBindingZero
                    ? try ownershipWithZeroClaimRequestBinding(fixture)
                    : fixture.ownershipRecord,
                sessionDriverChild: mismatch == .session
                    ? driftedDriver : fixture.driverChild
            )
        }
        await #expect(throws:
            InvestigationMachineDarwinOuterObservationError.alreadyConsumed
        ) {
            _ = try await harness.observer.observeOwnership(
                request: fixture.request, record: fixture.ownershipRecord,
                sessionDriverChild: fixture.driverChild
            )
        }
    }

    @Test(arguments: [
        OriginalIdentityAbsenceKind.esrch, .identityReused,
        .helperInitiallyPresentThenAbsent,
    ])
    fileprivate func terminalObserverRequiresEqualCompleteDriverAndExactAbsence(
        _ absence: OriginalIdentityAbsenceKind
    ) async throws {
        let scenario: InvestigationHandoffScenario =
            absence == .helperInitiallyPresentThenAbsent
                ? .lifecycleRecovery : .success
        let fixture = try OuterInnerFixture(scenario: scenario)
        let harness = try OuterObservationHarness(
            fixture: fixture, identityAbsence: absence
        )
        let initial = try await harness.prepareOwnership()
        let terminal = try await harness.observer.observeTerminal(
            selection: fixture.selection,
            ownership: fixture.ownershipRecord,
            retirement: try await makeOuterRetirementOutcome(
                scenario: scenario
            ),
            deadlineNanoseconds: fixture.request.epochDeadlineNanoseconds
        )

        #expect(initial == terminal.finalDriverObservationSHA256)
        #expect(terminal == (try InvestigationMachineDarwinOuterTerminalObservation(
            appAbsence: .observed, helperAbsence: .observed,
            l1ResidueAbsence: .observed,
            finalDriverObservationSHA256: initial,
            observedAtNanoseconds: terminal.observedAtNanoseconds
        )))
        let expectedObservedAt = absence == .helperInitiallyPresentThenAbsent
            ? fixture.request.epochDeadlineNanoseconds - 10_000_000
            : fixture.observedAt + 1
        #expect(terminal.observedAtNanoseconds == expectedObservedAt)
        var expectedProcessIDs = [
            fixture.appChild.identity.processID,
            fixture.physicalOwnership.helperIdentity.processID,
        ]
        if absence == .helperInitiallyPresentThenAbsent {
            expectedProcessIDs.append(
                fixture.physicalOwnership.helperIdentity.processID
            )
        }
        #expect(harness.identityReads.processIDs == expectedProcessIDs)
        #expect(!(InvestigationMachineDarwinOuterTerminalObservation.self
            is any Codable.Type))
        #expect(!(InvestigationMachineDarwinOuterObserver.self
            is any Codable.Type))
        await #expect(throws:
            InvestigationMachineDarwinOuterObservationError.alreadyConsumed
        ) {
            _ = try await harness.observer.observeTerminal(
                selection: fixture.selection,
                ownership: fixture.ownershipRecord,
                retirement: try await makeOuterRetirementOutcome(
                    scenario: scenario
                ),
                deadlineNanoseconds: fixture.request.epochDeadlineNanoseconds
            )
        }
    }

    @Test(arguments: OuterTerminalFailure.allCases)
    fileprivate func terminalObserverFailsClosedForDriftPresenceUnavailableAndDeadline(
        _ failure: OuterTerminalFailure
    ) async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let harness = try OuterObservationHarness(
            fixture: fixture, terminalFailure: failure
        )
        _ = try await harness.prepareOwnership()

        await #expect(throws: failure.expectedError) {
            _ = try await harness.observer.observeTerminal(
                selection: fixture.selection,
                ownership: fixture.ownershipRecord,
                retirement: try await makeOuterRetirementOutcome(),
                deadlineNanoseconds: fixture.request.epochDeadlineNanoseconds
            )
        }
    }

    @Test
    func cancellationConsumesTerminalObservationWithoutMintingEvidence() async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let harness = try OuterObservationHarness(fixture: fixture)
        _ = try await harness.prepareOwnership()
        let retirement = try await makeOuterRetirementOutcome()
        let operation = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await harness.observer.observeTerminal(
                selection: fixture.selection,
                ownership: fixture.ownershipRecord, retirement: retirement,
                deadlineNanoseconds: fixture.request.epochDeadlineNanoseconds
            )
        }

        await #expect(throws: CancellationError.self) {
            _ = try await operation.value
        }
        await #expect(throws:
            InvestigationMachineDarwinOuterObservationError.alreadyConsumed
        ) {
            _ = try await harness.observer.observeTerminal(
                selection: fixture.selection,
                ownership: fixture.ownershipRecord, retirement: retirement,
                deadlineNanoseconds: fixture.request.epochDeadlineNanoseconds
            )
        }
        #expect(harness.identityReads.processIDs.isEmpty)
    }

    @Test
    func finalObservationDeadlineAndLateCancellationCannotMintEvidence() async throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let deadlineClock = SequenceOuterObservationClock(values: [
            fixture.observedAt + 1, fixture.observedAt + 1,
            fixture.request.epochDeadlineNanoseconds,
        ])
        let expired = try OuterObservationHarness(
            fixture: fixture, clock: deadlineClock
        )
        _ = try await expired.prepareOwnership()
        await #expect(throws:
            InvestigationMachineDarwinOuterObservationError.deadlineExceeded
        ) {
            _ = try await expired.observer.observeTerminal(
                selection: fixture.selection,
                ownership: fixture.ownershipRecord,
                retirement: try await makeOuterRetirementOutcome(),
                deadlineNanoseconds: fixture.request.epochDeadlineNanoseconds
            )
        }

        let cancellingClock = CancellingSequenceOuterObservationClock(
            values: [
                fixture.observedAt + 1, fixture.observedAt + 1,
                fixture.observedAt + 2,
            ],
            cancellationCall: 3
        )
        let cancelled = try OuterObservationHarness(
            fixture: fixture, clock: cancellingClock
        )
        _ = try await cancelled.prepareOwnership()
        let operation = Task {
            try await cancelled.observer.observeTerminal(
                selection: fixture.selection,
                ownership: fixture.ownershipRecord,
                retirement: try await makeOuterRetirementOutcome(),
                deadlineNanoseconds: fixture.request.epochDeadlineNanoseconds
            )
        }
        await #expect(throws: CancellationError.self) {
            _ = try await operation.value
        }
        await #expect(throws:
            InvestigationMachineDarwinOuterObservationError.alreadyConsumed
        ) {
            _ = try await cancelled.observer.observeTerminal(
                selection: fixture.selection,
                ownership: fixture.ownershipRecord,
                retirement: try await makeOuterRetirementOutcome(),
                deadlineNanoseconds: fixture.request.epochDeadlineNanoseconds
            )
        }
    }

    @Test(arguments: [false, true])
    func suspendedTerminalObservationIsFailStopForReplayAndCancellation(
        _ cancelFirst: Bool
    ) async throws {
        let fixture = try OuterInnerFixture(scenario: .lifecycleRecovery)
        let waiter = SuspendingOuterObservationWaiter()
        let clock = SequenceOuterObservationClock(values: [
            fixture.observedAt + 1, fixture.observedAt + 1,
            fixture.observedAt + 100_000_001,
        ])
        let harness = try OuterObservationHarness(
            fixture: fixture,
            identityAbsence: .helperInitiallyPresentThenAbsent,
            clock: clock, waiter: waiter
        )
        _ = try await harness.prepareOwnership()
        let retirement = try await makeOuterRetirementOutcome(
            scenario: .lifecycleRecovery
        )
        let first = Task {
            try await harness.observer.observeTerminal(
                selection: fixture.selection,
                ownership: fixture.ownershipRecord, retirement: retirement,
                deadlineNanoseconds: fixture.request.epochDeadlineNanoseconds
            )
        }
        let entered = await waiter.waitUntilEntered()
        #expect(entered)
        guard entered else {
            first.cancel(); await waiter.open()
            _ = try? await first.value
            return
        }
        if cancelFirst { first.cancel() }
        await #expect(throws:
            InvestigationMachineDarwinOuterObservationError.alreadyConsumed
        ) {
            _ = try await harness.observer.observeTerminal(
                selection: fixture.selection,
                ownership: fixture.ownershipRecord, retirement: retirement,
                deadlineNanoseconds: fixture.request.epochDeadlineNanoseconds
            )
        }
        await waiter.open()
        if cancelFirst {
            await #expect(throws: CancellationError.self) {
                _ = try await first.value
            }
        } else {
            await #expect(throws:
                InvestigationMachineDarwinOuterObservationError.alreadyConsumed
            ) {
                _ = try await first.value
            }
        }
    }

    @Test
    func productionFactoryConstructsTheReviewedOuterComposition() throws {
        let fixture = try OuterInnerFixture(scenario: .success)
        let dependencies = InvestigationMachineDarwinOuterInnerExecutionFactory
            .productionDependencies(for: fixture.selection)
        #expect(dependencies.usesOneConcreteOuterObserver)
        let components = try InvestigationMachineDarwinOuterInnerExecutionFactory()
            .components(for: fixture.selection, mode: .normal)

        #expect(components.composer is InvestigationMachineDarwinOuterInnerComposition)
        #expect(components.prover is InvestigationMachineDarwinOuterAdmission)
    }
}

private enum OriginalIdentitySameVersionDrift:
    CaseIterable, CustomTestStringConvertible
{
    case auditSession
    case effectiveUser
    case auditToken

    var testDescription: String { String(describing: self) }

    func apply(
        to identity: InvestigationMachineProcessIdentity
    ) -> InvestigationMachineDarwinAppNarrowIdentity {
        var words = identity.auditTokenWords
        let auditSessionID: UInt32
        let userID: UInt32
        switch self {
        case .auditSession:
            auditSessionID = identity.auditSessionID + 1
            userID = identity.effectiveUserID
            words[6] = auditSessionID
        case .effectiveUser:
            auditSessionID = identity.auditSessionID
            userID = identity.effectiveUserID == 501 ? 0 : 501
            words[1] = userID
        case .auditToken:
            auditSessionID = identity.auditSessionID
            userID = identity.effectiveUserID
            words[0] &+= 1
        }
        return .init(
            processID: identity.processID,
            processIDVersion: identity.processIDVersion,
            auditSessionID: auditSessionID, effectiveUserID: userID,
            auditTokenWords: words
        )
    }
}

private enum OriginalIdentityAbsenceKind: CaseIterable, CustomTestStringConvertible {
    case esrch
    case identityReused
    case helperInitiallyPresentThenAbsent

    var testDescription: String { String(describing: self) }
}

private enum OriginalIdentityUnavailableKind:
    CaseIterable, CustomTestStringConvertible
{
    case permissionDenied
    case inputOutput
    case mismatchedProcessID
    case malformedToken

    var testDescription: String { String(describing: self) }

    func result(
        for expected: InvestigationMachineProcessIdentity
    ) -> InvestigationMachineDarwinOriginalIdentityReader.RawResult {
        switch self {
        case .permissionDenied:
            .failure(.init(errno: EPERM))
        case .inputOutput:
            .failure(.init(errno: EIO))
        case .mismatchedProcessID:
            .success(.init(
                processID: expected.processID + 1,
                processIDVersion: expected.processIDVersion,
                auditSessionID: expected.auditSessionID,
                effectiveUserID: expected.effectiveUserID,
                auditTokenWords: expected.auditTokenWords
            ))
        case .malformedToken:
            .success(.init(
                processID: expected.processID,
                processIDVersion: expected.processIDVersion,
                auditSessionID: expected.auditSessionID,
                effectiveUserID: expected.effectiveUserID,
                auditTokenWords: Array(expected.auditTokenWords.dropLast())
            ))
        }
    }
}

private enum OuterOwnershipMismatch: CaseIterable, CustomTestStringConvertible {
    case driver
    case app
    case session
    case claimRequestBindingZero

    var testDescription: String { String(describing: self) }
}

private enum OuterTerminalFailure: CaseIterable, CustomTestStringConvertible {
    case driverDrift
    case originalIdentityAlive
    case identityUnavailable
    case deadlineExpired

    var testDescription: String { String(describing: self) }

    var expectedError: InvestigationMachineDarwinOuterObservationError {
        switch self {
        case .driverDrift: .driverObservationMismatch
        case .originalIdentityAlive: .originalIdentityStillPresent
        case .identityUnavailable: .identityUnavailable
        case .deadlineExpired: .deadlineExceeded
        }
    }
}

private final class OuterObservationHarness: @unchecked Sendable {
    let fixture: OuterInnerFixture
    let initialObservation: InvestigationMachineInstalledDriverObservation
    let driverObserver: RecordingOuterDriverChildObserver
    let identityReads: RecordingOriginalIdentityReads
    let observer: InvestigationMachineDarwinOuterObserver

    init(
        fixture: OuterInnerFixture,
        observedDriver: InvestigationMachineDarwinDriverChildIdentity? = nil,
        observedAppIdentity: InvestigationMachineProcessIdentity? = nil,
        identityAbsence: OriginalIdentityAbsenceKind = .esrch,
        terminalFailure: OuterTerminalFailure? = nil,
        clock selectedClock:
            (any InvestigationMachineDarwinOuterInnerCompositionClocking)? = nil,
        waiter selectedWaiter:
            (any InvestigationMachineDarwinOuterObservationWaiting)? = nil
    ) throws {
        self.fixture = fixture
        let initialCandidate = validDriverCandidate(
            projection: fixture.selection.projection
        )
        let finalCandidate = terminalFailure == .driverDrift
            ? validDriverCandidate(
                projection: fixture.selection.projection, observationRevision: 2
            )
            : initialCandidate
        let installedSource = RecordingOuterInstalledDriverSource(
            candidates: [initialCandidate, finalCandidate]
        )
        let installedObserver = rootInstalledDriverObserver(source: installedSource)
        initialObservation = try rootInstalledDriverObserver(
            source: RecordingOuterInstalledDriverSource(
                candidates: [initialCandidate]
            )
        ).observe()
        driverObserver = RecordingOuterDriverChildObserver(
            result: .success(observedDriver ?? fixture.driverChild)
        )
        let appIdentity = observedAppIdentity ?? fixture.appChild.identity
        let appObserver = InvestigationMachineDarwinAppIdentityObserver(
            system: OuterObservationAppIdentitySystem(
                identity: appIdentity,
                parentProcessID: fixture.driverChild.processID,
                processGroupID: fixture.driverChild.processGroupID,
                projection: fixture.selection.projection
            )
        )
        identityReads = RecordingOriginalIdentityReads(
            results: Self.identityResults(
                fixture: fixture, absence: identityAbsence, failure: terminalFailure
            )
        )
        let identityReader = InvestigationMachineDarwinOriginalIdentityReader(
            readIdentity: identityReads.read
        )
        let now: UInt64
        let clock: any InvestigationMachineDarwinOuterInnerCompositionClocking
        switch terminalFailure {
        case .deadlineExpired:
            now = fixture.request.epochDeadlineNanoseconds
            clock = FixedOuterObservationClock(now: now)
        case .originalIdentityAlive:
            now = fixture.observedAt + 1
            clock = SequenceOuterObservationClock(values: [
                now, now, fixture.request.epochDeadlineNanoseconds,
            ])
        default:
            now = fixture.observedAt + 1
            clock = identityAbsence == .helperInitiallyPresentThenAbsent
                ? SequenceOuterObservationClock(values: [
                    fixture.request.epochDeadlineNanoseconds - 50_000_000,
                    fixture.request.epochDeadlineNanoseconds - 50_000_000,
                    fixture.request.epochDeadlineNanoseconds - 25_000_000,
                    fixture.request.epochDeadlineNanoseconds - 25_000_000,
                    fixture.request.epochDeadlineNanoseconds - 10_000_000,
                ])
                : FixedOuterObservationClock(now: now)
        }
        observer = InvestigationMachineDarwinOuterObserver(
            installedDriverObserver: installedObserver,
            driverChildObserver: driverObserver,
            appIdentityObserver: appObserver,
            originalIdentityReader: identityReader,
            clock: selectedClock ?? clock,
            waiter: selectedWaiter ?? ImmediateOuterObservationWaiter(),
            outerProcessID: fixture.outerProcessID
        )
    }

    func prepareOwnership() async throws -> InvestigationHandoffSHA256 {
        let initial = try await observer.observeInitialDriver(
            selection: fixture.selection
        )
        _ = try await observer.observeOwnership(
            request: fixture.request, record: fixture.ownershipRecord,
            sessionDriverChild: fixture.driverChild
        )
        return initial
    }

    private static func identityResults(
        fixture: OuterInnerFixture, absence: OriginalIdentityAbsenceKind,
        failure: OuterTerminalFailure?
    ) -> [InvestigationMachineDarwinOriginalIdentityReader.RawResult] {
        if failure == .originalIdentityAlive {
            return [
                .success(outerNarrowIdentity(from: fixture.appChild.identity)),
                .failure(.init(errno: ESRCH)),
            ]
        }
        if failure == .identityUnavailable {
            return [
                .failure(.init(errno: EPERM)),
                .failure(.init(errno: ESRCH)),
            ]
        }
        if absence == .helperInitiallyPresentThenAbsent {
            return [
                .failure(.init(errno: ESRCH)),
                .success(outerNarrowIdentity(
                    from: fixture.physicalOwnership.helperIdentity
                )),
                .failure(.init(errno: ESRCH)),
            ]
        }
        let identities = [
            fixture.appChild.identity, fixture.physicalOwnership.helperIdentity,
        ]
        return identities.map { identity in
            switch absence {
            case .esrch: .failure(.init(errno: ESRCH))
            case .identityReused: .success(reusedNarrowIdentity(from: identity))
            case .helperInitiallyPresentThenAbsent:
                .failure(.init(errno: EIO))
            }
        }
    }
}

private struct OuterDriverObservationCall: Equatable {
    let processID: UInt32
    let expectedParentProcessID: UInt32
}

private final class RecordingOuterDriverChildObserver:
    InvestigationMachineDarwinDriverChildObserving, @unchecked Sendable
{
    private let lock = NSLock()
    private let result: Result<
        InvestigationMachineDarwinDriverChildIdentity,
        InvestigationMachineDarwinDriverChildObservationError
    >
    private var recordedCalls: [OuterDriverObservationCall] = []

    init(result: Result<
        InvestigationMachineDarwinDriverChildIdentity,
        InvestigationMachineDarwinDriverChildObservationError
    >) {
        self.result = result
    }

    var calls: [OuterDriverObservationCall] { lock.withLock { recordedCalls } }

    func observe(
        processID: UInt32, expectedParentProcessID: UInt32
    ) throws -> InvestigationMachineDarwinDriverChildIdentity {
        lock.withLock {
            recordedCalls.append(.init(
                processID: processID,
                expectedParentProcessID: expectedParentProcessID
            ))
        }
        return try result.get()
    }
}

private final class RecordingOriginalIdentityReads: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [InvestigationMachineDarwinOriginalIdentityReader.RawResult]
    private var recordedProcessIDs: [UInt32] = []

    init(results: [InvestigationMachineDarwinOriginalIdentityReader.RawResult]) {
        self.results = results
    }

    var processIDs: [UInt32] { lock.withLock { recordedProcessIDs } }

    func read(_ processID: UInt32)
        -> InvestigationMachineDarwinOriginalIdentityReader.RawResult
    {
        lock.withLock {
            recordedProcessIDs.append(processID)
            guard !results.isEmpty else {
                return .failure(.init(errno: EIO))
            }
            return results.removeFirst()
        }
    }
}

private final class OuterObservationAppIdentitySystem:
    InvestigationMachineDarwinAppIdentitySystem, @unchecked Sendable
{
    private let lock = NSLock()
    private let identity: InvestigationMachineProcessIdentity
    private let parentProcessID: UInt32
    private let processGroupID: UInt32
    private let projection: InvestigationInstalledL2IdentityProjection
    private var processIDs: [UInt32] = []

    init(
        identity: InvestigationMachineProcessIdentity,
        parentProcessID: UInt32, processGroupID: UInt32,
        projection: InvestigationInstalledL2IdentityProjection
    ) {
        self.identity = identity
        self.parentProcessID = parentProcessID
        self.processGroupID = processGroupID
        self.projection = projection
    }

    var observedProcessIDs: [UInt32] { lock.withLock { processIDs } }

    func currentProcessID() -> UInt32 { parentProcessID }

    func resolvedAppIdentity()
        -> InvestigationMachineDarwinAppResolvedIdentityResult
    {
        .observed(.init(
            username: "app-user", userID: 501, groupID: 20,
            supplementaryGroups: physicalAppGroups
        ))
    }

    func narrowIdentity(processID: UInt32)
        -> Result<
            InvestigationMachineDarwinAppNarrowIdentity,
            InvestigationMachineDarwinAppIdentityObservationError
        >
    {
        record(processID)
        return .success(outerNarrowIdentity(from: identity))
    }

    func snapshot(processID: UInt32)
        -> Result<
            InvestigationMachineDarwinAppProcessSnapshot,
            InvestigationMachineDarwinAppIdentityObservationError
        >
    {
        record(processID)
        return .success(.init(
            processID: identity.processID, parentProcessID: parentProcessID,
            processGroupID: processGroupID, realUserID: 501,
            effectiveUserID: 501, savedUserID: 501, realGroupID: 20,
            effectiveGroupID: 20, savedGroupID: 20,
            auditUserID: identity.auditTokenWords[0],
            auditSessionID: identity.auditSessionID,
            startTimeSeconds: 100, startTimeMicroseconds: 200,
            supplementaryGroups: physicalAppGroups
        ))
    }

    func executableURL(processID: UInt32)
        -> Result<URL, InvestigationMachineDarwinAppIdentityObservationError>
    {
        record(processID)
        return .success(InvestigationInstalledL2FixedPaths().appExecutable)
    }

    func executableObservation(
        expectedSHA256: InvestigationHandoffSHA256
    ) -> InvestigationInstalledL2ArtifactObservation {
        expectedSHA256 == projection.appExecutableSHA256
            ? .presentValid : .invalid
    }

    func staticSigning() -> InvestigationInstalledL2StaticSigningResult {
        .observed(appSigningIdentity(projection: projection))
    }

    func liveSigning(processID: UInt32)
        -> InvestigationMachineDarwinAppLiveSigningResult
    {
        record(processID)
        return .observed(.init(
            processID: identity.processID,
            identity: appSigningIdentity(projection: projection)
        ))
    }

    private func record(_ processID: UInt32) {
        lock.withLock { processIDs.append(processID) }
    }
}

private let physicalAppGroups: [UInt32] = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 20,
]

private func appSigningIdentity(
    projection: InvestigationInstalledL2IdentityProjection
) -> InvestigationInstalledL2SigningIdentity {
    try! .init(
        signingIdentifier: projection.appBundleIdentifier,
        designatedRequirementSHA256: try! outerDigest(0xa1),
        codeDirectoryHash: Data(repeating: 0xa2, count: 20),
        isAdHoc: true
    )
}

private final class RecordingOuterInstalledDriverSource:
    InvestigationMachineInstalledDriverObservationSource, @unchecked Sendable
{
    private let lock = NSLock()
    private var candidates: [InvestigationMachineInstalledDriverCandidate]

    init(candidates: [InvestigationMachineInstalledDriverCandidate]) {
        self.candidates = candidates
    }

    func readCandidate() throws -> InvestigationMachineInstalledDriverCandidate {
        try lock.withLock {
            guard !candidates.isEmpty else {
                throw InvestigationMachineInstalledDriverObservationError
                    .sourceUnavailable
            }
            return candidates.removeFirst()
        }
    }
}

private struct FixedOuterObservationClock:
    InvestigationMachineDarwinOuterInnerCompositionClocking
{
    let now: UInt64
    func continuousNanoseconds() throws -> UInt64 { now }
}

private final class SequenceOuterObservationClock:
    InvestigationMachineDarwinOuterInnerCompositionClocking, @unchecked Sendable
{
    private let lock = NSLock()
    private var values: [UInt64]

    init(values: [UInt64]) { self.values = values }

    func continuousNanoseconds() throws -> UInt64 {
        try lock.withLock {
            guard !values.isEmpty else {
                throw InvestigationMachineDarwinOuterObservationError
                    .identityUnavailable
            }
            return values.removeFirst()
        }
    }
}

private final class CancellingSequenceOuterObservationClock:
    InvestigationMachineDarwinOuterInnerCompositionClocking, @unchecked Sendable
{
    private let lock = NSLock()
    private var values: [UInt64]
    private let cancellationCall: Int
    private var calls = 0

    init(values: [UInt64], cancellationCall: Int) {
        self.values = values
        self.cancellationCall = cancellationCall
    }

    func continuousNanoseconds() throws -> UInt64 {
        let result = try lock.withLock { () -> (UInt64, Bool) in
            guard !values.isEmpty else {
                throw InvestigationMachineDarwinOuterObservationError
                    .identityUnavailable
            }
            calls += 1
            return (values.removeFirst(), calls == cancellationCall)
        }
        if result.1 { withUnsafeCurrentTask { $0?.cancel() } }
        return result.0
    }
}

private struct ImmediateOuterObservationWaiter:
    InvestigationMachineDarwinOuterObservationWaiting
{
    func sleep(nanoseconds: UInt64) async throws {
        _ = nanoseconds
    }
}

private actor SuspendingOuterObservationWaiter:
    InvestigationMachineDarwinOuterObservationWaiting
{
    private var entered = false
    private var isOpen = false
    private var openWaiters: [CheckedContinuation<Void, Never>] = []
    func sleep(nanoseconds: UInt64) async throws {
        #expect(nanoseconds == 100_000_000)
        entered = true
        guard !isOpen else {
            try Task.checkCancellation()
            return
        }
        await withCheckedContinuation { openWaiters.append($0) }
        try Task.checkCancellation()
    }

    func waitUntilEntered() async -> Bool {
        for _ in 0..<2_000 {
            if entered { return true }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        return entered
    }

    func open() {
        isOpen = true
        openWaiters.forEach { $0.resume() }
        openWaiters.removeAll()
    }
}

private func rootInstalledDriverObserver(
    source: any InvestigationMachineInstalledDriverObservationSource
) -> InvestigationMachineInstalledDriverObserver {
    .init(
        realUserID: { 0 }, effectiveUserID: { 0 },
        realGroupID: { 0 }, effectiveGroupID: { 0 },
        argumentCount: { 1 }, source: source
    )
}

private func validDriverCandidate(
    projection: InvestigationInstalledL2IdentityProjection,
    observationRevision: Int64 = 1
) -> InvestigationMachineInstalledDriverCandidate {
    let node = InvestigationMachineInstalledDriverNodeIdentity(
        deviceID: 11, inode: 12, generation: 13, isRegularFile: true,
        ownerUserID: 0, ownerGroupID: 0, mode: 0o755, linkCount: 1,
        size: 64 * 1_024, flags: 0, modificationSeconds: observationRevision,
        modificationNanoseconds: 14, statusChangeSeconds: 15,
        statusChangeNanoseconds: 16
    )
    let signing = InvestigationMachineInstalledDriverSigningIdentity(
        signingIdentifier: projection.machineDriverSigningIdentifier,
        designatedRequirementSHA256:
            projection.machineDriverDesignatedRequirementSHA256.lowercaseHex,
        codeDirectoryHash: projection.machineDriverCodeDirectoryHash
            .map { String(format: "%02x", $0) }.joined(),
        isAdHoc: true
    )
    let manifestNode = InvestigationMachineInstalledDriverNodeIdentity(
        deviceID: 21, inode: 22, generation: 23, isRegularFile: true,
        ownerUserID: 0, ownerGroupID: 0, mode: 0o644, linkCount: 1,
        size: 1_024, flags: 0, modificationSeconds: 24,
        modificationNanoseconds: 25, statusChangeSeconds: 26,
        statusChangeNanoseconds: 27
    )
    let manifest = InvestigationMachineInstalledManifestIdentity(
        path: InvestigationMachineInstalledDriverObservation
            .fixedLaunchDaemonManifestPath,
        node: manifestNode,
        sha256: InvestigationMachineInstalledDriverObservation
            .fixedLaunchDaemonManifestSHA256,
        label: InvestigationMachineInstalledDriverObservation.fixedLifecycleLabel,
        program: InvestigationMachineInstalledDriverObservation
            .fixedLifecycleProgram,
        primaryServiceIdentifier:
            InvestigationMachineInstalledDriverObservation.fixedLifecycleLabel,
        machineClaimServiceIdentifier:
            InvestigationMachineInstalledDriverObservation
                .fixedMachineClaimServiceIdentifier
    )
    return .init(
        executablePath:
            InvestigationMachineInstalledDriverObservation.fixedExecutablePath,
        finalExecutablePath:
            InvestigationMachineInstalledDriverObservation.fixedExecutablePath,
        hasTrustedAncestorChain: true, finalHasTrustedAncestorChain: true,
        initialNode: node, descriptorNode: node, finalDescriptorNode: node,
        finalNode: node, hasExtendedACL: false, finalHasExtendedACL: false,
        hasUnexpectedExtendedAttributes: false,
        finalHasUnexpectedExtendedAttributes: false,
        executableSHA256: projection.machineDriverExecutableSHA256.lowercaseHex,
        staticSigning: signing, liveSigning: signing, manifest: manifest,
        finalManifest: manifest
    )
}

private func outerNarrowIdentity(
    from identity: InvestigationMachineProcessIdentity
) -> InvestigationMachineDarwinAppNarrowIdentity {
    .init(
        processID: identity.processID,
        processIDVersion: identity.processIDVersion,
        auditSessionID: identity.auditSessionID,
        effectiveUserID: identity.effectiveUserID,
        auditTokenWords: identity.auditTokenWords
    )
}

private func reusedNarrowIdentity(
    from identity: InvestigationMachineProcessIdentity
) -> InvestigationMachineDarwinAppNarrowIdentity {
    let version = identity.processIDVersion + 1
    var words = identity.auditTokenWords
    words[7] = version
    return .init(
        processID: identity.processID, processIDVersion: version,
        auditSessionID: identity.auditSessionID,
        effectiveUserID: identity.effectiveUserID, auditTokenWords: words
    )
}

private func reusedProcessIdentity(
    from identity: InvestigationMachineProcessIdentity
) -> InvestigationMachineProcessIdentity {
    let version = identity.processIDVersion + 1
    var words = identity.auditTokenWords
    words[7] = version
    return try! .init(
        role: identity.role, processID: identity.processID,
        processIDVersion: version, auditSessionID: identity.auditSessionID,
        effectiveUserID: identity.effectiveUserID, auditTokenWords: words
    )
}

private func driverObservationDigest(
    _ value: InvestigationMachineInstalledDriverObservation
) throws -> InvestigationHandoffSHA256 {
    try singleEpochDriverObservationSHA256(.init(value))
}

private func outerDigest(_ byte: UInt8) throws -> InvestigationHandoffSHA256 {
    try .init(rawBytes: Data(repeating: byte, count: 32))
}

private func ownershipWithZeroClaimRequestBinding(
    _ fixture: OuterInnerFixture
) throws -> InvestigationMachineDarwinEpochOwnershipRecord {
    let source = fixture.claimEvidence
    let evidence = try InvestigationMachineClaimEvidence(
        requestBindingSHA256: outerDigest(0x00),
        originalClaimChallenge: source.originalClaimChallenge,
        claimConnectionEpoch: source.claimConnectionEpoch,
        appIdentity: source.appIdentity, helperIdentity: source.helperIdentity,
        appUserID: source.appUserID, recordedAt: source.recordedAt,
        claimedAt: source.claimedAt, ownerRetirement: source.ownerRetirement,
        l1Residue: source.l1Residue,
        releaseDeadlineNanoseconds: source.releaseDeadlineNanoseconds
    )
    let physical = try InvestigationMachineSingleEpochPhysicalOwnership(
        selection: fixture.selection, claimEvidence: evidence,
        installedL2ProofSHA256: outerDigest(0x52),
        epochDeadlineNanoseconds: fixture.request.epochDeadlineNanoseconds
    )
    return try .init(
        request: fixture.request, driverChild: fixture.driverChild,
        appChild: fixture.appChild, physicalOwnership: physical
    )
}

private final class OuterObservationRetirementSystem: @unchecked Sendable {
    private let lock = NSLock()
    private var inventoryCount = 0
    private var now: UInt64 = 1
    private let rawStatus: Int32

    init(rawStatus: Int32 = 0) { self.rawStatus = rawStatus }

    func system() -> InvestigationMachineDarwinEpochRetirementSystem {
        .init(
            currentProcessGroup: { 88 },
            continuousNanoseconds: {
                self.lock.withLock {
                    defer { self.now += 1 }
                    return self.now
                }
            },
            closeDescriptor: { _ in },
            processGroupInventory: { _, processID, _ in
                self.lock.withLock {
                    defer { self.inventoryCount += 1 }
                    guard self.inventoryCount == 0 else { return Data() }
                    var value = processID
                    return withUnsafeBytes(of: &value) { Data($0) }
                }
            },
            waitID: { processID, _ in processID },
            sendSignal: { _, _ in },
            waitPID: { processID, _ in processID },
            waitPIDStatus: { processID, _ in
                .init(processID: processID, rawStatus: self.rawStatus)
            },
            pauseNanoseconds: { _ in }
        )
    }
}

private func makeOuterRetirementOutcome(
    scenario: InvestigationHandoffScenario = .success
) async throws
    -> InvestigationMachineDarwinOuterRetirementOutcome
{
    let rawStatus: Int32 = scenario == .lifecycleRecovery
        ? InvestigationMachineDarwinDirectChildExitClassification
            .deliberateParentCrashExitStatus << 8
        : 0
    return try await InvestigationMachineDarwinEpochRetirementOwner(
        system: OuterObservationRetirementSystem(rawStatus: rawStatus).system()
    ).retireOwnedProcessGroupWithOutcome(.init(
        processID: 901, processGroupID: 901, descriptors: []
    ))
}
