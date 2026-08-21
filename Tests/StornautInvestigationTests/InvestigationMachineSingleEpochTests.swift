import Foundation
import Testing
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachineDriverSupport
@Suite("Investigation machine single epoch")
struct InvestigationMachineSingleEpochTests {
    @Test(arguments: InvestigationHandoffScenario.allCases)
    func successForEveryAdmittedRowUsesExactTypedInputs(
        _ scenario: InvestigationHandoffScenario) async throws {
        let fixture = try SingleEpochFixture(scenario: scenario)
        let runtime = fixture.runtime()
        let composer = fixture.composer(runtime: runtime)
        let expectedBootstrap = try fixture.bootstrap
        let expectedOutgoing = try fixture.expectedOutgoing
        let expectedClaimCall = try fixture.expectedClaimCall
        #expect(try await composer.run() == .completedNonAdmitting)
        #expect(runtime.trace.events == SingleEpochEvent.successOrder)
        #expect(runtime.sessionFactory.bootstraps == [expectedBootstrap])
        #expect(runtime.session.receivedFrames == fixture.incoming)
        #expect(runtime.session.sentFrames == expectedOutgoing)
        #expect(runtime.claim.calls == [expectedClaimCall])
        #expect(runtime.l2.calls == [fixture.expectedL2Call])
        #expect(!(InvestigationMachineSingleEpochResult.self is any Codable.Type))
        #expect(!(InvestigationMachineSingleEpochRetirementProof.self is any Codable.Type))
        #expect(!(InvestigationMachineSingleEpochTerminalStartProof.self is any Codable.Type))
        #expect(!(InvestigationMachineSingleEpochInstalledL2Proof.self is any Codable.Type))
        #expect(!(InvestigationMachineSingleEpochAppObservation.self is any Codable.Type))
    }
    @Test(arguments: SingleEpochProtocolMutation.allCases)
    fileprivate func protocolOrCommitmentDriftFailsBeforeClaim(
        _ mutation: SingleEpochProtocolMutation) async throws {
        let fixture = try SingleEpochFixture(mutation: mutation)
        let runtime = fixture.runtime()
        await #expect(throws: mutation.expectedError) {
            _ = try await fixture.composer(runtime: runtime).run()
        }
        #expect(!runtime.trace.events.contains(.claim))
        #expect(runtime.trace.events.last == .retire)
        if mutation == .acknowledgement {
            #expect(!runtime.trace.events.contains(.receive(.hello)))
        }
    }
    @Test(arguments: SingleEpochAfterClaimFailure.allCases)
    fileprivate func everyPreReleaseFailureAbortsBeforeRetirement(
        _ failure: SingleEpochAfterClaimFailure) async throws {
        let fixture = try SingleEpochFixture()
        let runtime = fixture.runtime(afterClaimFailure: failure)
        await #expect(throws: failure.expectedError) {
            _ = try await fixture.composer(runtime: runtime).run()
        }
        let claim = try #require(runtime.trace.events.firstIndex(of: .claim))
        let abort = try #require(runtime.trace.events.firstIndex(of: .abort))
        let retire = try #require(runtime.trace.events.firstIndex(of: .retire))
        #expect(claim < abort && abort < retire)
        #expect(!runtime.trace.events.contains(.claimRelease))
        #expect(!runtime.trace.events.contains(.send(.exit)))
    }
    @Test(arguments: SingleEpochClaimFailure.allCases)
    fileprivate func claimFailureDoesNotRetryAbortOrRelease(
        _ failure: SingleEpochClaimFailure) async throws {
        let fixture = try SingleEpochFixture()
        let runtime = fixture.runtime(claimFailure: failure)
        await #expect(throws: failure.expectedError) {
            _ = try await fixture.composer(runtime: runtime).run()
        }
        #expect(runtime.trace.events.filter { $0 == .makeClaim }.count == 1)
        #expect(runtime.trace.events.filter { $0 == .claim }.count == 1)
        #expect(!runtime.trace.events.contains(.abort))
        #expect(!runtime.trace.events.contains(.claimRelease))
        #expect(runtime.trace.events.last == .retire)
    }
    @Test
    func releaseFailureIsTerminalAndRetiresWithoutAbortOrExit() async throws {
        let fixture = try SingleEpochFixture()
        let runtime = fixture.runtime(releaseFails: true)
        await #expect(
            throws: InvestigationMachineSingleEpochError.releaseTerminalUncertain
        ) {
            _ = try await fixture.composer(runtime: runtime).run()
        }
        #expect(runtime.trace.events.suffix(2) == [.claimRelease, .retire])
        #expect(!runtime.trace.events.contains(.abort))
        #expect(!runtime.trace.events.contains(.send(.exit)))
    }
    @Test(arguments: SingleEpochTerminalPriority.allCases)
    fileprivate func terminalFailurePriorityOverridesOriginalFailure(
        _ priority: SingleEpochTerminalPriority) async throws {
        let fixture = try SingleEpochFixture()
        let runtime = fixture.runtime(
            afterClaimFailure: .installedL2,
            abortFails: true,
            retirementFails: priority == .retirement
        )
        await #expect(throws: priority.expectedError) {
            _ = try await fixture.composer(runtime: runtime).run()
        }
        #expect(runtime.trace.events.suffix(2) == [.abort, .retire])
    }
    @Test(arguments: SingleEpochAsyncSeam.allCases)
    fileprivate func cancellationAtEverySuspensionFailsClosed(
        _ seam: SingleEpochAsyncSeam) async throws {
        let fixture = try SingleEpochFixture()
        let runtime = fixture.runtime(
            afterClaimFailure: seam == .abort ? .installedL2 : nil,
            cancellation: seam
        )
        let composer = fixture.composer(runtime: runtime)
        let operation = Task { try await composer.run() }
        await runtime.cancellation.waitUntilEntered()
        operation.cancel()
        runtime.cancellation.resume()
        do {
            _ = try await operation.value
            Issue.record("cancelled epoch unexpectedly completed")
        } catch {
            #expect(error as? InvestigationMachineSingleEpochError == seam.expectedError)
        }
        #expect(runtime.trace.events.filter { $0 == .retire }.count == 1)
        #expect(runtime.trace.events.contains(.abort) == seam.requiresAbort)
        #expect(runtime.trace.events.contains(.claimRelease) == seam.reachesRelease)
        #expect(runtime.trace.events.contains(.makeClaim) == seam.reachesClaimFactory)
        #expect(runtime.trace.events.contains(.send(.exit)) == seam.reachesExit)
        #expect(runtime.trace.events.filter { $0 == .observeDriver }.count == 1)
    }
    @Test
    func terminalStartProofNeedsNoComposerRetirement() async throws {
        let fixture = try SingleEpochFixture()
        let runtime = fixture.runtime(startTerminal: true)
        await #expect(throws: InvestigationMachineSingleEpochError.protocolViolation) {
            _ = try await fixture.composer(runtime: runtime).run()
        }
        #expect(!runtime.trace.events.contains(.retire))
    }
    @Test(arguments: SingleEpochFinalObservationFailure.allCases)
    fileprivate func finalObservationFailsAfterSuccessfulRetirement(
        _ failure: SingleEpochFinalObservationFailure) async throws {
        let fixture = try SingleEpochFixture()
        let runtime = fixture.runtime(finalObservationFailure: failure)
        await #expect(
            throws: InvestigationMachineSingleEpochError.finalObservationMismatch
        ) { _ = try await fixture.composer(runtime: runtime).run() }
        #expect(runtime.trace.events.suffix(2) == [.retire, .observeDriver])
    }
    @Test
    func outgoingFramesUseOneSnapshottedDriverClaim() async throws {
        let fixture = try SingleEpochFixture()
        let driftingClaim = try SingleEpochFixture.claim(
            pid: 85, version: 9, uid: 0, asid: 11)
        let runtime = fixture.runtime(driverClaims: [fixture.driverClaim, driftingClaim])
        let expectedOutgoing = try fixture.expectedOutgoing
        #expect(try await fixture.composer(runtime: runtime).run()
            == .completedNonAdmitting)
        #expect(runtime.session.driverClaimReadCount == 1)
        #expect(runtime.session.sentFrames == expectedOutgoing)
    }
    @Test
    func concurrentAndRepeatedRunHaveOneWinner() async throws {
        let fixture = try SingleEpochFixture()
        let startGate = SingleEpochGate()
        let runtime = fixture.runtime(startGate: startGate)
        let composer = fixture.composer(runtime: runtime)
        let first = Task { try await composer.run() }
        await startGate.waitUntilEntered()
        await #expect(throws: InvestigationMachineSingleEpochError.alreadyConsumed) {
            _ = try await composer.run()
        }
        startGate.open()
        #expect(try await first.value == .completedNonAdmitting)
        await #expect(throws: InvestigationMachineSingleEpochError.alreadyConsumed) {
            _ = try await composer.run()
        }
        #expect(runtime.trace.events.filter { $0 == .start }.count == 1)
    }
}
private enum SingleEpochProtocolMutation: CaseIterable {
    case preDropKind, duplicatePreDrop, dropContinuity, acknowledgement
    case handle, aliveSender, aliveEpoch, aliveDeadline
    var expectedError: InvestigationMachineSingleEpochError {
        switch self {
        case .dropContinuity: .identityMismatch
        case .acknowledgement, .handle: .commitmentMismatch
        default: .protocolViolation
        }
    }
}
private enum SingleEpochAfterClaimFailure: CaseIterable {
    case installedL2, repeatedAppIdentity
    var expectedError: InvestigationMachineSingleEpochError { self == .installedL2 ? .installedL2Failed : .identityMismatch }
}
private enum SingleEpochClaimFailure: CaseIterable {
    case rejected, terminalUncertain
    var expectedError: InvestigationMachineSingleEpochError { self == .rejected ? .claimFailed : .claimTerminalUncertain }
}
private enum SingleEpochTerminalPriority: CaseIterable {
    case abort, retirement
    var expectedError: InvestigationMachineSingleEpochError {
        self == .retirement ? .retirementUncertain : .abortTerminalUncertain
    }
}
private enum SingleEpochFinalObservationFailure: CaseIterable {
    case read, mismatch
}
private enum SingleEpochAsyncSeam: CaseIterable, Sendable {
    case start, receivePreDrop, sendDropRelease, receiveDropEvidence
    case observeAppInitial, sendConfiguration, receiveConfigurationAcknowledgement
    case receiveHello, receiveHandle, sendAcknowledgement, sendRelease, receiveAlive
    case peerWriteEOF, claim, installedL2, observeAppRepeated, claimRelease
    case sendExit, retire, abort
    var expectedError: InvestigationMachineSingleEpochError {
        self == .abort ? .installedL2Failed : .cancelled
    }
    var requiresAbort: Bool {
        switch self {
        case .claim, .installedL2, .observeAppRepeated, .abort: true
        default: false
        }
    }
    var reachesRelease: Bool {
        switch self {
        case .claimRelease, .sendExit, .retire: true
        default: false
        }
    }
    var reachesClaimFactory: Bool {
        switch self {
        case .claim, .installedL2, .observeAppRepeated, .claimRelease, .sendExit, .retire, .abort: true
        default: false
        }
    }
    var reachesExit: Bool { self == .sendExit || self == .retire }
}
private enum SingleEpochEvent: Sendable, Equatable {
    case observeDriver, clock, start
    case receive(InvestigationHandoffFrameKind), send(InvestigationHandoffFrameKind)
    case observeApp, eof, makeClaim, claim, installedL2, claimRelease, abort, retire
    static let successOrder: [Self] = [
        .observeDriver, .clock, .start, .receive(.preDropReady),
        .send(.dropRelease), .receive(.dropEvidence), .observeApp,
        .send(.configuration), .receive(.configurationAcknowledgement),
        .receive(.hello), .receive(.handle), .send(.acknowledgement),
        .send(.release), .receive(.alive), .eof, .makeClaim, .claim,
        .installedL2, .observeApp, .claimRelease, .send(.exit), .retire,
        .observeDriver,
    ]
}
private struct SingleEpochClaimCall: Sendable, Equatable {
    let handle: InvestigationHandoffRetirementHandle; let appIdentity: InvestigationMachineProcessIdentity
    let sharedDeadline: InvestigationMachineClaimClientSharedDeadline
}
private struct SingleEpochL2Call: Sendable, Equatable {
    let appIdentity: InvestigationMachineProcessIdentity; let evidence: InvestigationMachineClaimEvidence
    let epochUUID: UUID; let deadlineNanoseconds: UInt64
}
private final class SingleEpochTrace: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [SingleEpochEvent] = []
    var events: [SingleEpochEvent] { lock.withLock { stored } }
    func record(_ event: SingleEpochEvent) { lock.withLock { stored.append(event) } }
}
private final class SingleEpochCancellationProbe: @unchecked Sendable {
    let target: SingleEpochAsyncSeam?
    private let gate = SingleEpochGate()
    init(_ target: SingleEpochAsyncSeam?) { self.target = target }
    func hit(_ seam: SingleEpochAsyncSeam) async {
        guard seam == target else { return }
        gate.enter(); await gate.waitUntilOpen()
    }
    func waitUntilEntered() async { await gate.waitUntilEntered() }
    func resume() { gate.open() }
}
private struct SingleEpochFixture {
    static let now: UInt64 = 1_000_000_000, deadline: UInt64 = 141_000_000_000
    let epoch: InvestigationCohortEpoch; let driverClaim: InvestigationHandoffProcessClaim
    let appIdentity, helperIdentity: InvestigationMachineProcessIdentity
    let claimEvidence: InvestigationMachineClaimEvidence
    let installedObservation: InvestigationMachineSingleEpochDriverObservation
    let handle: InvestigationHandoffRetirementHandle; let incoming: [InvestigationHandoffFrame]
    init(
        mutation: SingleEpochProtocolMutation? = nil,
        scenario: InvestigationHandoffScenario = .success
    ) throws {
        let epochUUID = try Self.uuid(0x11)
        let configuration = Data("opaque-configuration".utf8)
        epoch = try InvestigationCohortEpoch(
            ordinal: scenario.rawValue - 1, epochUUID: epochUUID, scenario: scenario,
            configurationNonce: Self.uuid(0x12), configuration: configuration,
            configurationSHA256: .hashing(configuration),
            signedRuntimeBindingSHA256: Self.digest(0x13)
        )
        driverClaim = try Self.claim(pid: 84, version: 8, uid: 0, asid: 10)
        let preDrop = try Self.claim(pid: 42, version: 7, uid: 0, asid: 9)
        let postDrop = try Self.claim(
            pid: mutation == .dropContinuity ? 43 : 42,
            version: 7, uid: 501, asid: 9
        )
        let dropEvidence = try Self.dropEvidence(pid: postDrop.processID)
        appIdentity = try Self.identity(
            role: .app, pid: postDrop.processID, version: 7, uid: 501, asid: 9,
            words: dropEvidence.auditTokenWords
        )
        helperIdentity = try Self.identity(
            role: .helper, pid: 702, version: 12, uid: 0, asid: 33_001,
            words: [9, 0, 8, 7, 6, 702, 33_001, 12]
        )
        let acknowledgement = try InvestigationHandoffConfigurationAcknowledgement(
            epochUUID: epochUUID, ordinal: epoch.ordinal,
            configurationNonce: mutation == .acknowledgement
                ? Self.uuid(0x21) : epoch.configurationNonce,
            scenario: scenario, configurationSHA256: epoch.configurationSHA256,
            signedRuntimeBindingSHA256: epoch.signedRuntimeBindingSHA256
        )
        handle = try InvestigationHandoffRetirementHandle(
            token: Self.uuid(0x31), investigationUUID: epoch.configurationNonce,
            retireOperationUUID: Self.uuid(0x32),
            configurationSHA256: mutation == .handle
                ? Self.digest(0xee) : epoch.configurationSHA256,
            validBefore: .init(rawValue: 2_000_000_030_000_000)
        )
        let aliveSender = mutation == .aliveSender
            ? try Self.claim(pid: 44, version: 7, uid: 501, asid: 9) : postDrop
        func frame(
            _ kind: InvestigationHandoffFrameKind,
            sender: InvestigationHandoffProcessClaim,
            payload: InvestigationHandoffFramePayload = .empty,
            epochUUID overrideEpoch: UUID? = nil,
            deadline overrideDeadline: UInt64? = nil
        ) throws -> InvestigationHandoffFrame {
            try .init(
                kind: kind, epochUUID: overrideEpoch ?? epochUUID,
                epochDeadlineNanoseconds: overrideDeadline ?? Self.deadline,
                sender: sender, payload: payload
            )
        }
        var frames = [
            try frame(mutation == .preDropKind ? .dropRelease : .preDropReady,
                      sender: preDrop),
            try frame(.dropEvidence, sender: postDrop,
                      payload: .dropEvidence(dropEvidence)),
            try frame(.configurationAcknowledgement, sender: postDrop,
                      payload: .configurationAcknowledgement(acknowledgement)),
            try frame(.hello, sender: postDrop),
            try frame(.handle, sender: postDrop, payload: .retirementHandle(handle)),
            try frame(
                .alive, sender: aliveSender,
                epochUUID: mutation == .aliveEpoch ? Self.uuid(0x22) : nil,
                deadline: mutation == .aliveDeadline ? Self.deadline + 1 : nil
            ),
        ]
        if mutation == .duplicatePreDrop { frames[1] = frames[0] }
        incoming = frames
        claimEvidence = try InvestigationMachineClaimEvidence(
            requestBindingSHA256: Self.digest(0x41),
            originalClaimChallenge: Self.uuid(0x42),
            claimConnectionEpoch: Self.uuid(0x43),
            appIdentity: appIdentity, helperIdentity: helperIdentity, appUserID: 501,
            recordedAt: .init(rawValue: 2_000_000_000_500_000),
            claimedAt: .init(rawValue: 2_000_000_002_000_000),
            ownerRetirement: .init(),
            l1Residue: .init(
                investigationUUID: handle.investigationUUID, auditSessionID: 33_001,
                userID: 501, observedAt: .init(rawValue: 2_000_000_000_250_000),
                remainingAuditSessionMembers: 0, matchingLeases: 0,
                leaseRootEntries: 0, investigationArtifacts: 0
            ), releaseDeadlineNanoseconds: 140_000_000_000
        )
        installedObservation = .init(.singleEpochFixture())
    }
    var bootstrap: InvestigationHandoffEpochBootstrap {
        get throws {
            try .init(
                epochUUID: epoch.epochUUID,
                epochDeadlineNanoseconds: Self.deadline
            )
        }
    }
    var expectedOutgoing: [InvestigationHandoffFrame] {
        get throws {
            let acknowledgement = InvestigationHandoffRetirementHandleAcknowledgement(
                handleSHA256: .hashing(try handle.encoded())
            )
            func frame(
                _ kind: InvestigationHandoffFrameKind,
                _ payload: InvestigationHandoffFramePayload = .empty
            ) throws -> InvestigationHandoffFrame {
                try .init(
                    kind: kind, epochUUID: epoch.epochUUID,
                    epochDeadlineNanoseconds: Self.deadline,
                    sender: driverClaim, payload: payload
                )
            }
            return [
                try frame(.dropRelease),
                try frame(.configuration, .configuration(epoch.configuration)),
                try frame(
                    .acknowledgement,
                    .retirementHandleAcknowledgement(acknowledgement)
                ),
                try frame(.release),
                try frame(.exit),
            ]
        }
    }
    var expectedClaimCall: SingleEpochClaimCall {
        get throws {
            .init(
                handle: handle, appIdentity: appIdentity,
                sharedDeadline: try .init(epochDeadlineNanoseconds: Self.deadline)
            )
        }
    }
    var expectedL2Call: SingleEpochL2Call {
        .init(
            appIdentity: appIdentity, evidence: claimEvidence,
            epochUUID: epoch.epochUUID, deadlineNanoseconds: Self.deadline
        )
    }
    func runtime(
        afterClaimFailure: SingleEpochAfterClaimFailure? = nil,
        claimFailure: SingleEpochClaimFailure? = nil,
        abortFails: Bool = false,
        releaseFails: Bool = false,
        retirementFails: Bool = false,
        startGate: SingleEpochGate? = nil,
        startTerminal: Bool = false,
        finalObservationFailure: SingleEpochFinalObservationFailure? = nil,
        cancellation: SingleEpochAsyncSeam? = nil,
        driverClaims: [InvestigationHandoffProcessClaim]? = nil
    ) -> SingleEpochRuntime {
        let trace = SingleEpochTrace()
        let cancellationProbe = SingleEpochCancellationProbe(cancellation)
        let session = ScriptedSingleEpochSession(
            trace: trace, cancellation: cancellationProbe,
            driverClaims: driverClaims ?? [driverClaim], incoming: incoming,
            identities: [
                appIdentity,
                afterClaimFailure == .repeatedAppIdentity
                    ? helperIdentity : appIdentity,
            ], retirementFails: retirementFails
        )
        let claim = ScriptedSingleEpochClaim(
            trace: trace, cancellation: cancellationProbe, evidence: claimEvidence,
            claimFailure: claimFailure, abortFails: abortFails,
            releaseFails: releaseFails
        )
        var observations = [installedObservation, installedObservation]
        if finalObservationFailure == .read { observations.removeLast() }
        if finalObservationFailure == .mismatch {
            observations[1] = .init(.singleEpochFixture(shaCharacter: "d"))
        }
        return SingleEpochRuntime(
            trace: trace, cancellation: cancellationProbe, session: session, claim: claim,
            observer: .init(trace: trace, observations: observations),
            clock: .init(trace: trace, now: Self.now),
            sessionFactory: .init(
                trace: trace, cancellation: cancellationProbe,
                session: session, startGate: startGate, terminal: startTerminal
            ),
            claimFactory: .init(trace: trace, claim: claim),
            l2: .init(
                trace: trace, cancellation: cancellationProbe,
                fails: afterClaimFailure == .installedL2
            )
        )
    }
    func composer(runtime: SingleEpochRuntime)
        -> InvestigationMachineSingleEpochComposer {
        .init(
            commitment: .init(epoch: epoch), observer: runtime.observer,
            clock: runtime.clock, sessionFactory: runtime.sessionFactory,
            claimClientFactory: runtime.claimFactory, installedL2: runtime.l2
        )
    }
    fileprivate static func claim(
        pid: UInt32, version: UInt32, uid: UInt32, asid: UInt32
    ) throws -> InvestigationHandoffProcessClaim {
        try .init(
            processID: pid, processIDVersion: version,
            effectiveUserID: uid, auditSessionID: asid
        )
    }
    private static func uuid(_ byte: UInt8) throws -> UUID {
        try #require(UUID(uuidString: String(
            format: "00000000-0000-4000-8000-0000000000%02x", byte
        )))
    }
    private static func digest(_ byte: UInt8) throws -> InvestigationHandoffSHA256 {
        try .init(rawBytes: Data(repeating: byte, count: 32))
    }
    private static func identity(
        role: InvestigationMachineProcessRole, pid: UInt32, version: UInt32,
        uid: UInt32, asid: UInt32, words: [UInt32]
    ) throws -> InvestigationMachineProcessIdentity {
        try .init(
            role: role, processID: pid, processIDVersion: version,
            auditSessionID: asid, effectiveUserID: uid, auditTokenWords: words
        )
    }
    private static func dropEvidence(pid: UInt32) throws
        -> InvestigationHandoffDropEvidence {
        try .init(
            realUserID: 501, effectiveUserID: 501, savedUserID: 501,
            realGroupID: 20, effectiveGroupID: 20, savedGroupID: 20,
            supplementaryGroups: Array(UInt32(1)...UInt32(15)) + [20],
            auditTokenWords: [501, 501, 20, 501, 20, pid, 9, 7],
            setuidRootErrno: 1, seteuidRootErrno: 1, setgidRootErrno: 1
        )
    }
}
private struct SingleEpochRuntime {
    let trace: SingleEpochTrace; let cancellation: SingleEpochCancellationProbe
    let session: ScriptedSingleEpochSession; let claim: ScriptedSingleEpochClaim
    let observer: ScriptedSingleEpochDriverObserver; let clock: ScriptedSingleEpochClock
    let sessionFactory: ScriptedSingleEpochSessionFactory
    let claimFactory: ScriptedSingleEpochClaimFactory; let l2: ScriptedSingleEpochL2
}
private final class ScriptedSingleEpochDriverObserver:
    InvestigationMachineSingleEpochInstalledDriverObserving, @unchecked Sendable {
    let trace: SingleEpochTrace; private let lock = NSLock()
    private var observations: [InvestigationMachineSingleEpochDriverObservation]
    init(
        trace: SingleEpochTrace,
        observations: [InvestigationMachineSingleEpochDriverObservation]
    ) { self.trace = trace; self.observations = observations }
    func observeDriver() throws -> InvestigationMachineSingleEpochDriverObservation {
        trace.record(.observeDriver)
        return try lock.withLock {
            guard !observations.isEmpty else { throw SingleEpochInjectedFailure() }
            return observations.removeFirst()
        }
    }
}
private struct ScriptedSingleEpochClock: InvestigationMachineSingleEpochClocking {
    let trace: SingleEpochTrace; let now: UInt64
    func continuousNanoseconds() throws -> UInt64 { trace.record(.clock); return now }
}
private final class ScriptedSingleEpochSessionFactory:
    InvestigationMachineSingleEpochSessionFactory, @unchecked Sendable {
    let trace: SingleEpochTrace; let cancellation: SingleEpochCancellationProbe
    let session: ScriptedSingleEpochSession; let startGate: SingleEpochGate?
    let terminal: Bool; private let lock = NSLock()
    private var storedBootstraps: [InvestigationHandoffEpochBootstrap] = []
    var bootstraps: [InvestigationHandoffEpochBootstrap] {
        lock.withLock { storedBootstraps }
    }
    init(
        trace: SingleEpochTrace, cancellation: SingleEpochCancellationProbe,
        session: ScriptedSingleEpochSession, startGate: SingleEpochGate?, terminal: Bool
    ) {
        self.trace = trace; self.cancellation = cancellation
        self.session = session; self.startGate = startGate; self.terminal = terminal
    }
    func start(bootstrap: InvestigationHandoffEpochBootstrap) async
        -> InvestigationMachineSingleEpochStartOutcome {
        lock.withLock { storedBootstraps.append(bootstrap) }
        trace.record(.start)
        if let startGate { startGate.enter(); await startGate.waitUntilOpen() }
        await cancellation.hit(.start)
        return terminal ? .terminal(.init()) : .started(session)
    }
}
private final class ScriptedSingleEpochSession:
    InvestigationMachineSingleEpochSession, @unchecked Sendable {
    let trace: SingleEpochTrace; let cancellation: SingleEpochCancellationProbe
    private let lock = NSLock()
    private var driverClaims: [InvestigationHandoffProcessClaim]
    private var claimReads = 0; private var incoming: [InvestigationHandoffFrame]
    private var identities: [InvestigationMachineProcessIdentity]
    private var storedReceived: [InvestigationHandoffFrame] = [], storedSent: [InvestigationHandoffFrame] = []
    private let retirementFails: Bool
    var driverClaim: InvestigationHandoffProcessClaim {
        lock.withLock {
            let value = driverClaims[min(claimReads, driverClaims.count - 1)]
            claimReads += 1
            return value
        }
    }
    var driverClaimReadCount: Int { lock.withLock { claimReads } }
    var receivedFrames: [InvestigationHandoffFrame] { lock.withLock { storedReceived } }
    var sentFrames: [InvestigationHandoffFrame] { lock.withLock { storedSent } }
    init(
        trace: SingleEpochTrace, cancellation: SingleEpochCancellationProbe,
        driverClaims: [InvestigationHandoffProcessClaim],
        incoming: [InvestigationHandoffFrame],
        identities: [InvestigationMachineProcessIdentity], retirementFails: Bool
    ) {
        self.trace = trace; self.cancellation = cancellation
        self.driverClaims = driverClaims; self.incoming = incoming
        self.identities = identities; self.retirementFails = retirementFails
    }
    func receive() async throws -> InvestigationHandoffFrame {
        let value = try lock.withLock {
            try #require(!incoming.isEmpty)
            let value = incoming.removeFirst(); storedReceived.append(value)
            return value
        }
        trace.record(.receive(value.kind))
        await cancellation.hit(Self.receiveSeam(value.kind))
        return value
    }
    func send(_ frame: InvestigationHandoffFrame) async throws {
        lock.withLock { storedSent.append(frame) }
        trace.record(.send(frame.kind))
        await cancellation.hit(Self.sendSeam(frame.kind))
    }
    func provePeerWriteEOF() async throws {
        trace.record(.eof); await cancellation.hit(.peerWriteEOF)
    }
    func observeCompletePostDropAppIdentity() async throws
        -> InvestigationMachineSingleEpochAppObservation {
        let (identity, seam) = try lock.withLock {
            try #require(!identities.isEmpty)
            let seam: SingleEpochAsyncSeam = identities.count == 2
                ? .observeAppInitial : .observeAppRepeated
            return (identities.removeFirst(), seam)
        }
        trace.record(.observeApp); await cancellation.hit(seam)
        return .init(identity: identity)
    }
    func retireAndReap() async throws -> InvestigationMachineSingleEpochRetirementProof {
        trace.record(.retire); await cancellation.hit(.retire)
        if retirementFails { throw SingleEpochInjectedFailure() }
        return .init()
    }
    private static func receiveSeam(
        _ kind: InvestigationHandoffFrameKind
    ) -> SingleEpochAsyncSeam {
        switch kind {
        case .preDropReady: .receivePreDrop
        case .dropEvidence: .receiveDropEvidence
        case .configurationAcknowledgement: .receiveConfigurationAcknowledgement
        case .hello: .receiveHello
        case .handle: .receiveHandle
        case .alive: .receiveAlive
        default: .receivePreDrop
        }
    }
    private static func sendSeam(
        _ kind: InvestigationHandoffFrameKind
    ) -> SingleEpochAsyncSeam {
        switch kind {
        case .dropRelease: .sendDropRelease
        case .configuration: .sendConfiguration
        case .acknowledgement: .sendAcknowledgement
        case .release: .sendRelease
        case .exit: .sendExit
        default: .sendDropRelease
        }
    }
}
private final class ScriptedSingleEpochClaimFactory:
    InvestigationMachineSingleEpochClaimClientFactory, @unchecked Sendable {
    let trace: SingleEpochTrace
    let claim: ScriptedSingleEpochClaim
    init(trace: SingleEpochTrace, claim: ScriptedSingleEpochClaim) {
        self.trace = trace; self.claim = claim
    }
    func make() -> any InvestigationMachineSingleEpochClaiming {
        trace.record(.makeClaim); return claim
    }
}
private final class ScriptedSingleEpochClaim:
    InvestigationMachineSingleEpochClaiming, @unchecked Sendable {
    let trace: SingleEpochTrace; let cancellation: SingleEpochCancellationProbe
    let evidence: InvestigationMachineClaimEvidence
    let claimFailure: SingleEpochClaimFailure?; let abortFails, releaseFails: Bool
    private let lock = NSLock()
    private var storedCalls: [SingleEpochClaimCall] = []
    var calls: [SingleEpochClaimCall] { lock.withLock { storedCalls } }
    init(
        trace: SingleEpochTrace, cancellation: SingleEpochCancellationProbe,
        evidence: InvestigationMachineClaimEvidence,
        claimFailure: SingleEpochClaimFailure?,
        abortFails: Bool, releaseFails: Bool
    ) {
        self.trace = trace; self.cancellation = cancellation
        self.evidence = evidence; self.claimFailure = claimFailure
        self.abortFails = abortFails; self.releaseFails = releaseFails
    }
    func claim(
        handle: InvestigationHandoffRetirementHandle,
        appIdentity: InvestigationMachineProcessIdentity,
        sharedDeadline: InvestigationMachineClaimClientSharedDeadline
    ) async throws -> InvestigationMachineClaimEvidence {
        lock.withLock {
            storedCalls.append(.init(
                handle: handle, appIdentity: appIdentity,
                sharedDeadline: sharedDeadline
            ))
        }
        trace.record(.claim); await cancellation.hit(.claim)
        if claimFailure == .terminalUncertain {
            throw InvestigationMachineSingleEpochClaimingError.terminalUncertain
        }
        if claimFailure == .rejected { throw SingleEpochInjectedFailure() }
        return evidence
    }
    func abortAfterClaimAndProveTerminal() async throws {
        trace.record(.abort); await cancellation.hit(.abort)
        if abortFails { throw SingleEpochInjectedFailure() }
    }
    func releaseAndAwaitTerminal() async throws {
        trace.record(.claimRelease); await cancellation.hit(.claimRelease)
        if releaseFails { throw SingleEpochInjectedFailure() }
    }
}
private final class ScriptedSingleEpochL2:
    InvestigationMachineSingleEpochInstalledL2Observing, @unchecked Sendable {
    let trace: SingleEpochTrace; let cancellation: SingleEpochCancellationProbe
    let fails: Bool; private let lock = NSLock()
    private var storedCalls: [SingleEpochL2Call] = []
    var calls: [SingleEpochL2Call] { lock.withLock { storedCalls } }
    init(
        trace: SingleEpochTrace, cancellation: SingleEpochCancellationProbe,
        fails: Bool
    ) { self.trace = trace; self.cancellation = cancellation; self.fails = fails }
    func observe(
        appIdentity: InvestigationMachineProcessIdentity,
        claimEvidence: InvestigationMachineClaimEvidence,
        epochUUID: UUID, deadlineNanoseconds: UInt64
    ) async throws -> InvestigationMachineSingleEpochInstalledL2Proof {
        lock.withLock {
            storedCalls.append(.init(
                appIdentity: appIdentity, evidence: claimEvidence,
                epochUUID: epochUUID, deadlineNanoseconds: deadlineNanoseconds
            ))
        }
        trace.record(.installedL2); await cancellation.hit(.installedL2)
        if fails { throw SingleEpochInjectedFailure() }
        return .init()
    }
}
private final class SingleEpochGate: @unchecked Sendable {
    private let lock = NSLock()
    private var entered = false, opened = false
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = [], openWaiters: [CheckedContinuation<Void, Never>] = []
    func enter() {
        let values = lock.withLock {
            entered = true; defer { enteredWaiters.removeAll() }; return enteredWaiters
        }
        values.forEach { $0.resume() }
    }
    func open() {
        let values = lock.withLock {
            opened = true; defer { openWaiters.removeAll() }; return openWaiters
        }
        values.forEach { $0.resume() }
    }
    func waitUntilEntered() async { await wait(open: false) }
    func waitUntilOpen() async { await wait(open: true) }
    private func wait(open: Bool) async {
        await withCheckedContinuation { continuation in
            let ready = lock.withLock {
                if open ? opened : entered { return true }
                if open { openWaiters.append(continuation) }
                else { enteredWaiters.append(continuation) }
                return false
            }
            if ready { continuation.resume() }
        }
    }
}
private struct SingleEpochInjectedFailure: Error {}
private extension InvestigationMachineInstalledDriverObservation {
    static func singleEpochFixture(shaCharacter: Character = "c") -> Self {
        let node = InvestigationMachineInstalledDriverNodeIdentity(
            deviceID: 1, inode: 2, generation: 3, isRegularFile: true,
            ownerUserID: 0, ownerGroupID: 0, mode: 0o755, linkCount: 1,
            size: 65_536, flags: 0, modificationSeconds: 4,
            modificationNanoseconds: 5, statusChangeSeconds: 6,
            statusChangeNanoseconds: 7
        )
        let signing = InvestigationMachineInstalledDriverSigningIdentity(
            signingIdentifier: fixedSigningIdentifier,
            designatedRequirementSHA256: String(repeating: "a", count: 64),
            codeDirectoryHash: String(repeating: "b", count: 40), isAdHoc: true
        )
        let manifest = InvestigationMachineInstalledManifestIdentity(
            path: fixedLaunchDaemonManifestPath, node: node,
            sha256: fixedLaunchDaemonManifestSHA256, label: fixedLifecycleLabel,
            program: fixedLifecycleProgram,
            primaryServiceIdentifier: fixedLifecycleLabel,
            machineClaimServiceIdentifier: fixedMachineClaimServiceIdentifier
        )
        return .init(
            executablePath: fixedExecutablePath, node: node,
            executableSHA256: String(repeating: shaCharacter, count: 64),
            signing: signing, manifest: manifest
        )
    }
}
