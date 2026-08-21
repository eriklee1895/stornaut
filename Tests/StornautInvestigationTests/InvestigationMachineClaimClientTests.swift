import Foundation
import Testing
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachineDriverSupport
@testable import StornautInvestigationMachineClaimServer
@testable import StornautLifecycle

@Suite("Investigation machine claim client")
struct InvestigationMachineClaimClientTests {
    @Test
    func freshClaimRetainsSessionAndReleaseRequiresSleepBeforeAbsence() async throws {
        let fixture = try ClaimClientFixture()
        let session = ClaimClientSessionDouble()
        let transport = ClaimClientTransportDouble(session: session)
        let staticReader = ClaimClientStaticIdentityReaderDouble(
            fixture.staticIdentityObservations
        )
        let dynamicReader = ClaimClientDynamicIdentityReaderDouble(
            fixture.dynamicIdentityObservation
        )
        let clock = ClaimClientClockDouble(fixture.successClockObservations)
        let epochObserver = ClaimClientHelperEpochObserverDouble(
            [.originalHelperPresent, .originalHelperAbsent],
            absenceRequiresSleepFrom: clock
        )
        let client = fixture.client(
            session: session, clock: clock, transport: transport,
            staticReader: staticReader, dynamicReader: dynamicReader,
            epochObserver: epochObserver
        )
        await fixture.configure(session)

        let evidence = try await fixture.claim(
            client, previousHelperIdentity: fixture.freshPreviousHelperIdentity
        )
        let released = try await client.release()

        #expect(transport.serviceNames == [fixture.serviceName])
        #expect(transport.codeSigningRequirements == [fixture.signingRequirement])
        #expect(await session.claimDeadlines == [fixture.sharedDeadlineValue])
        #expect(await session.releaseDeadlines == [fixture.releaseDeadline])
        #expect(await session.invalidatedCount == 1)
        #expect(staticReader.readCount == 2)
        #expect(dynamicReader.auditTokenWords == [fixture.helperIdentity.auditTokenWords])
        #expect(clock.sleepDeadlines == [2_300_000_000])
        #expect(await epochObserver.observations == [
            fixture.helperIdentity, fixture.helperIdentity,
        ])
        #expect(await epochObserver.serviceNames == [fixture.serviceName, fixture.serviceName])
        #expect(evidence == fixture.evidence)
        #expect(released == fixture.released)
    }

    @Test(arguments: ClaimClientIdentityDrift.allCases)
    func claimRejectsIdentityDrift(_ drift: ClaimClientIdentityDrift) async throws {
        let fixture = try ClaimClientFixture()
        let session = ClaimClientSessionDouble()
        let staticReader = ClaimClientStaticIdentityReaderDouble(
            fixture.staticIdentityObservations(for: drift)
        )
        let dynamicReader = ClaimClientDynamicIdentityReaderDouble(
            fixture.dynamicIdentityObservation(for: drift)
        )
        let client = fixture.client(
            session: session, clock: ClaimClientClockDouble([
                fixture.claimClockObservation, fixture.claimReplyClockObservation,
                fixture.clockObservation(1_200_000_000),
                fixture.clockObservation(1_300_000_000),
            ]), staticReader: staticReader, dynamicReader: dynamicReader,
            helperEpochs: [.originalHelperAbsent]
        )
        await fixture.configure(
            session, connectionIdentity: fixture.connectionIdentity(for: drift)
        )

        await #expect(throws: drift.expectedError) {
            _ = try await fixture.claim(client)
        }
        #expect(await session.claimRequests.count == (drift.isPreDispatch ? 0 : 1))
        #expect(await session.invalidatedCount == (drift.isPreDispatch ? 0 : 1))
        #expect(dynamicReader.auditTokenWords == (
            drift.reachesDynamicIdentity ? [fixture.helperIdentity.auditTokenWords] : []
        ))
    }

    @Test(arguments: ClaimClientClaimContender.allCases)
    func claimRejectsConcurrentClaimOrRelease(
        _ contender: ClaimClientClaimContender
    ) async throws {
        let fixture = try ClaimClientFixture()
        let gate = ClaimClientAsyncGate()
        let session = ClaimClientSessionDouble(claimGate: gate)
        let client = fixture.client(
            session: session, clock: ClaimClientClockDouble([
                fixture.claimClockObservation, fixture.claimReplyClockObservation,
                fixture.clockObservation(1_200_000_000),
                fixture.clockObservation(1_300_000_000),
            ]), helperEpochs: [.originalHelperAbsent]
        )
        await fixture.configure(session)
        let firstClaim = Task { try await fixture.claim(client) }
        await gate.waitUntilEntered()

        switch contender {
        case .claim:
            await #expect(throws: InvestigationMachineClaimClientError.concurrentOperation) {
                _ = try await fixture.claim(client)
            }
        case .release:
            await #expect(throws: InvestigationMachineClaimClientError.concurrentOperation) {
                _ = try await client.release()
            }
        }
        gate.open()
        _ = try await firstClaim.value
        #expect(await session.claimRequests.count == 1)
    }

    @Test(arguments: ClaimClientConcurrentReleaseOperation.allCases)
    func releaseRejectsConcurrentReleaseOrClaim(
        _ contender: ClaimClientConcurrentReleaseOperation
    ) async throws {
        let fixture = try ClaimClientFixture()
        let gate = ClaimClientAsyncGate()
        let session = ClaimClientSessionDouble(releaseGate: gate)
        let client = fixture.client(
            session: session, clock: ClaimClientClockDouble(
                fixture.immediateReleaseClockObservations
            ), helperEpochs: [.originalHelperAbsent]
        )
        await fixture.configure(session)
        _ = try await fixture.claim(client)
        let firstRelease = Task { try await client.release() }
        await gate.waitUntilEntered()

        switch contender {
        case .release:
            await #expect(throws: InvestigationMachineClaimClientError.concurrentOperation) {
                _ = try await client.release()
            }
        case .claim:
            await #expect(throws: InvestigationMachineClaimClientError.concurrentOperation) {
                _ = try await fixture.claim(client)
            }
        }
        gate.open()
        _ = try await firstRelease.value
        #expect(await session.releaseRequests.count == 1)
    }

    @Test(arguments: ClaimClientClaimDeadlineBoundary.allCases)
    func claimRejectsDeadlineBoundary(
        _ boundary: ClaimClientClaimDeadlineBoundary
    ) async throws {
        let fixture = try ClaimClientFixture()
        let session = ClaimClientSessionDouble()
        let transport = ClaimClientTransportDouble(session: session)
        let input = try fixture.claimDeadlineInput(boundary)
        let client = fixture.client(
            session: session, clock: ClaimClientClockDouble([input.clock]),
            transport: transport
        )

        await #expect(throws: InvestigationMachineClaimClientError.invalidDeadline) {
            _ = try await client.claimOrProveTerminal(
                handle: input.handle, appIdentity: fixture.appIdentity,
                sharedDeadline: input.deadline, previousHelperIdentity: nil
            )
        }
        #expect(transport.connectCount == 0)
        #expect(await session.claimRequests.isEmpty)
    }

    @Test(arguments: ClaimClientReplyDeadlineBoundary.allCases)
    func claimRejectsReplyDeadlineBoundary(
        _ boundary: ClaimClientReplyDeadlineBoundary
    ) async throws {
        let fixture = try ClaimClientFixture()
        let session = ClaimClientSessionDouble()
        let input = try fixture.claimReplyDeadlineInput(boundary)
        let client = fixture.client(
            session: session, clock: ClaimClientClockDouble([
                fixture.claimClockObservation, fixture.claimReplyClockObservation,
                fixture.clockObservation(1_200_000_000),
                fixture.clockObservation(1_300_000_000),
            ]), helperEpochs: [.originalHelperAbsent]
        )
        await fixture.configure(session) { data in
            let request = try InvestigationMachineRetirementClaimRequest.decode(data)
            return (try fixture.claimReply(
                for: request, releaseDeadline: input.releaseDeadline
            ), nil)
        }

        await #expect(throws: InvestigationMachineClaimClientError.outcomeUnknown) {
            _ = try await fixture.claim(client, sharedDeadline: input.sharedDeadline)
        }
        #expect(await session.invalidatedCount == 1)
    }

    @Test(arguments: ClaimClientFailureScenario.allCases)
    func clientFailsClosedForReplyOrTransportFailure(
        _ scenario: ClaimClientFailureScenario
    ) async throws {
        let fixture = try ClaimClientFixture()
        let session = ClaimClientSessionDouble()
        let clock = scenario.isRelease
            ? fixture.claimAndReleaseFailureClockObservations
            : [fixture.claimClockObservation]
        let client = fixture.client(
            session: session, clock: ClaimClientClockDouble(clock),
            helperEpochs: [.originalHelperAbsent]
        )
        await fixture.configure(
            session, claimHandler: { data in
                switch scenario {
                case .claimTransport: throw ClaimClientInjectedFailure()
                case .claimReason:
                    return (nil, InvestigationMachineClaimXPCReason.invalidRequest.rawValue)
                case .wrongRequestBinding:
                    let request = try InvestigationMachineRetirementClaimRequest.decode(data)
                    let reply = try fixture.claimReply(
                        for: request, requestBinding: fixture.wrongRequestBinding
                    )
                    #expect(
                        try InvestigationMachineClaimEvidence.decode(reply)
                            .requestBindingSHA256 != request.bindingSHA256()
                    )
                    return (reply, nil)
                default:
                    let request = try InvestigationMachineRetirementClaimRequest.decode(data)
                    return (try fixture.claimReply(for: request), nil)
                }
            }, releaseHandler: { data in
                switch scenario {
                case .releaseTransport: throw ClaimClientInjectedFailure()
                case .releaseReason:
                    return (nil, InvestigationMachineClaimXPCReason.invalidRequest.rawValue)
                case .releaseTamper:
                    let release = try InvestigationMachineClaimRelease.decode(data)
                    return (try fixture.tamperedReleaseReply(for: release), nil)
                default: throw ClaimClientInjectedFailure()
                }
            }
        )
        if scenario.isRelease { _ = try await fixture.claim(client) }

        await #expect(throws: scenario.expectedError) {
            if scenario.isRelease { _ = try await client.release() }
            else { _ = try await fixture.claim(client) }
        }
        #expect(await session.invalidatedCount == 1)
    }

    @Test
    func abortBeforeClaimIsRejectedWithoutTransportActivity() async throws {
        let fixture = try ClaimClientFixture()
        let session = ClaimClientSessionDouble()
        let transport = ClaimClientTransportDouble(session: session)
        let client = fixture.client(
            session: session, clock: ClaimClientClockDouble([]),
            transport: transport
        )

        await #expect(
            throws: InvestigationMachineClaimClientError.oneShotConsumed
        ) {
            try await client.abortAfterClaimAndProveTerminal()
        }
        #expect(transport.connectCount == 0)
    }
    @Test(arguments: ClaimClientAmbiguousClaimScenario.allCases)
    func ambiguousAcceptedClaimWithoutTrustedHelperIsUncertain(
        _ scenario: ClaimClientAmbiguousClaimScenario
    ) async throws {
        let fixture = try ClaimClientFixture()
        let trace = ClaimClientCallTrace()
        let gate = scenario == .cancelledAfterDispatch
            ? ClaimClientAsyncGate() : nil
        let session = ClaimClientSessionDouble(
            claimGate: gate, sessionID: "primary", trace: trace
        )
        let transport = ClaimClientTransportDouble(
            session: session, trace: trace
        )
        let observer = ClaimClientHelperEpochObserverDouble(
            [.originalHelperAbsent], trace: trace
        )
        let client = fixture.client(
            session: session, clock: ClaimClientClockDouble([
                fixture.claimClockObservation,
            ]), transport: transport, epochObserver: observer
        )
        await fixture.configure(session) { data in
            _ = try fixture.acceptedClaimReply(for: data)
            await trace.record("server-accepted:primary")
            switch scenario {
            case .replyLost:
                throw ClaimClientInjectedFailure()
            case .malformedReply:
                return (Data([0x00]), nil)
            case .unknownReason:
                return (nil, "runtime.lifecycle.machine-claim.future")
            case .cancelledAfterDispatch:
                try Task.checkCancellation()
                throw ClaimClientInjectedFailure()
            }
        }
        if let gate {
            let task = Task { try await fixture.claim(client) }
            await gate.waitUntilEntered()
            task.cancel()
            gate.open()
            await #expect(
                throws: InvestigationMachineClaimClientError
                    .terminalResidueUncertain
            ) {
                _ = try await task.value
            }
        } else {
            await #expect(
                throws: InvestigationMachineClaimClientError
                    .terminalResidueUncertain
            ) {
                _ = try await fixture.claim(client)
            }
        }
        #expect(await trace.events == [
            "connect:primary", "claim:primary",
            "server-accepted:primary", "invalidate:primary",
        ])
    }
    @Test(arguments: [true, false])
    func trustedHelperPostValidationFailureUsesTerminalProof(
        _ proofSucceeds: Bool
    ) async throws {
        let fixture = try ClaimClientFixture()
        let trace = ClaimClientCallTrace()
        let session = ClaimClientSessionDouble(
            sessionID: "primary", trace: trace
        )
        let observer = ClaimClientHelperEpochObserverDouble(
            [.originalHelperAbsent],
            failureAtObservation: proofSucceeds ? nil : 0, trace: trace
        )
        let client = fixture.client(
            session: session, clock: ClaimClientClockDouble([
                fixture.claimClockObservation, fixture.claimReplyClockObservation,
                fixture.clockObservation(1_200_000_000),
                fixture.clockObservation(1_300_000_000),
            ]), transport: .init(session: session, trace: trace),
            epochObserver: observer
        )
        await fixture.configure(session) { data in
            let request = try InvestigationMachineRetirementClaimRequest.decode(data)
            return (try fixture.claimReply(
                for: request, releaseDeadline: fixture.sharedDeadlineValue + 1
            ), nil)
        }
        let expected: InvestigationMachineClaimClientError = proofSucceeds
            ? .outcomeUnknown : .terminalResidueUncertain
        await #expect(throws: expected) {
            _ = try await fixture.claim(client)
        }
        #expect(await trace.events.prefix(3) == [
            "connect:primary", "claim:primary", "invalidate:primary",
        ])
    }
    @Test
    func abortInvalidatesClaimConnectionBeforeProvingExactHelperAbsent() async throws {
        let fixture = try ClaimClientFixture()
        let trace = ClaimClientCallTrace()
        let session = ClaimClientSessionDouble(
            sessionID: "primary", trace: trace
        )
        let observer = ClaimClientHelperEpochObserverDouble(
            [.originalHelperPresent, .originalHelperAbsent], trace: trace
        )
        let clock = ClaimClientClockDouble([
            fixture.claimClockObservation, fixture.claimReplyClockObservation,
            fixture.clockObservation(2_100_000_000),
            fixture.clockObservation(2_200_000_000),
            fixture.clockObservation(2_300_000_000),
            fixture.clockObservation(2_400_000_000),
        ], trace: trace)
        let client = fixture.client(
            session: session, clock: clock,
            transport: .init(session: session, trace: trace),
            epochObserver: observer
        )
        await fixture.configure(session)
        _ = try await fixture.claim(client)
        try await client.abortAfterClaimAndProveTerminal()
        #expect(await trace.events == [
            "connect:primary", "claim:primary", "invalidate:primary",
            "observe:702:present", "sleep:2300000000",
            "observe:702:absent",
        ])
        await #expect(
            throws: InvestigationMachineClaimClientError.oneShotConsumed
        ) {
            _ = try await client.release()
        }
    }
    @Test
    func callerCancellationDoesNotCancelAbortTerminalProof() async throws {
        let fixture = try ClaimClientFixture(), start = ClaimClientAsyncGate()
        let trace = ClaimClientCallTrace()
        let session = ClaimClientSessionDouble(trace: trace)
        let client = fixture.client(
            session: session, clock: ClaimClientClockDouble([
                fixture.claimClockObservation, fixture.claimReplyClockObservation,
                fixture.clockObservation(2_100_000_000),
                fixture.clockObservation(2_200_000_000),
            ]), transport: .init(session: session, trace: trace), epochObserver: .init([.originalHelperAbsent], trace: trace)
        )
        await fixture.configure(session)
        _ = try await fixture.claim(client)
        let task = Task { await start.waitUntilOpen(); try await client.abortAfterClaimAndProveTerminal() }
        task.cancel()
        start.open()
        try await task.value
        #expect(await trace.events == ["connect:primary", "claim:primary", "invalidate:primary", "observe:702:absent"])
    }
    @Test(arguments: ClaimClientAbortFailureScenario.allCases)
    func abortNeverUpgradesUncertainTerminalStateToSuccess(
        _ scenario: ClaimClientAbortFailureScenario
    ) async throws {
        let fixture = try ClaimClientFixture()
        let session = ClaimClientSessionDouble()
        let observer = ClaimClientHelperEpochObserverDouble(
            scenario.helperEpochs, failureAtObservation: scenario.failureAtObservation
        )
        let client = fixture.client(
            session: session,
            clock: ClaimClientClockDouble(scenario.clocks(fixture)),
            epochObserver: observer
        )
        await fixture.configure(session)
        _ = try await fixture.claim(client)
        await #expect(
            throws: InvestigationMachineClaimClientError.terminalResidueUncertain
        ) {
            try await client.abortAfterClaimAndProveTerminal()
        }
    }
    @Test
    func concurrentAbortExcludesReleaseAndRemainsOneShot() async throws {
        let fixture = try ClaimClientFixture()
        let gate = ClaimClientAsyncGate()
        let session = ClaimClientSessionDouble()
        let observer = ClaimClientHelperEpochObserverDouble(
            [.originalHelperAbsent], gate: gate
        )
        let client = fixture.client(
            session: session, clock: ClaimClientClockDouble([
                fixture.claimClockObservation, fixture.claimReplyClockObservation,
                fixture.clockObservation(2_100_000_000),
                fixture.clockObservation(2_200_000_000),
            ]), epochObserver: observer
        )
        await fixture.configure(session)
        _ = try await fixture.claim(client)
        let abort = Task { try await client.abortAfterClaimAndProveTerminal() }
        await gate.waitUntilEntered()
        await #expect(
            throws: InvestigationMachineClaimClientError.concurrentOperation
        ) {
            _ = try await client.release()
        }
        gate.open()
        try await abort.value
        await #expect(
            throws: InvestigationMachineClaimClientError.oneShotConsumed
        ) {
            try await client.abortAfterClaimAndProveTerminal()
        }
    }
    @Test
    func inFlightReleaseExcludesAbort() async throws {
        let fixture = try ClaimClientFixture()
        let gate = ClaimClientAsyncGate()
        let session = ClaimClientSessionDouble(releaseGate: gate)
        let client = fixture.client(
            session: session,
            clock: ClaimClientClockDouble(
                fixture.immediateReleaseClockObservations
            ), helperEpochs: [.originalHelperAbsent]
        )
        await fixture.configure(session)
        _ = try await fixture.claim(client)
        let release = Task { try await client.release() }
        await gate.waitUntilEntered()
        await #expect(
            throws: InvestigationMachineClaimClientError.concurrentOperation
        ) {
            try await client.abortAfterClaimAndProveTerminal()
        }
        gate.open()
        _ = try await release.value
    }
    @Test
    func nextEpochRejectsReusedHelperIdentity() async throws {
        let fixture = try ClaimClientFixture()
        let session = ClaimClientSessionDouble()
        let client = fixture.client(
            session: session, clock: ClaimClientClockDouble([
                fixture.claimClockObservation, fixture.claimReplyClockObservation,
                fixture.clockObservation(1_200_000_000),
                fixture.clockObservation(1_300_000_000),
            ]), helperEpochs: [.originalHelperAbsent]
        )
        await fixture.configure(session)
        await #expect(throws: InvestigationMachineClaimClientError.outcomeUnknown) {
            _ = try await fixture.claim(
                client, previousHelperIdentity: fixture.helperIdentity
            )
        }
    }

    @Test(arguments: ClaimClientReleaseBoundary.allCases)
    func releaseRejectsDeadlineOrPersistentHelper(
        _ boundary: ClaimClientReleaseBoundary
    ) async throws {
        let fixture = try ClaimClientFixture()
        let session = ClaimClientSessionDouble()
        let client = fixture.client(
            session: session,
            clock: ClaimClientClockDouble(fixture.releaseBoundaryClocks(boundary)),
            helperEpochs: boundary.helperEpochs
        )
        await fixture.configure(session)
        _ = try await fixture.claim(client)
        await #expect(throws: InvestigationMachineClaimClientError.outcomeUnknown) {
            _ = try await client.release()
        }
    }

    @Test(arguments: ClaimClientEpochTerminalScenario.allCases)
    func connectionEpochClassifiesBoundaryAndReplyOnce(
        _ scenario: ClaimClientEpochTerminalScenario
    ) async {
        let epoch = InvestigationMachineClaimClientConnectionEpoch()
        let resolver = InvestigationMachineClaimClientReplyResolver()
        #expect(epoch.register(resolver))
        if scenario.afterDispatch { #expect(epoch.beginDispatch(resolver)) }
        let first = Data([0x31])
        switch scenario {
        case .cancelBeforeDispatch, .cancelAfterDispatch:
            epoch.cancel(resolver)
        case .failBeforeDispatch, .failAfterDispatch:
            epoch.fail(resolver)
        case .replyAfterDispatch:
            epoch.resolve(resolver, value: (first, nil))
        }
        epoch.resolve(resolver, value: (Data([0x32]), "late"))
        epoch.cancel(resolver)
        epoch.fail(resolver)
        let result = await claimClientResolverResult(resolver)
        #expect(result.data == (scenario.isReply ? first : nil))
        #expect(result.error == scenario.expectedError)
        #expect(epoch.isValid == scenario.isReply)
    }

    @Test(arguments: ClaimClientCancellationPhase.allCases)
    func connectionEpochClassifiesRealTaskCancellation(
        _ phase: ClaimClientCancellationPhase
    ) async {
        let epoch = InvestigationMachineClaimClientConnectionEpoch()
        let start = ClaimClientAsyncGate()
        let entered = ClaimClientAsyncGate()
        let task = Task {
            if phase == .beforeDispatch { await start.waitUntilOpen() }
            return try await epoch.exchange(deadlineNanoseconds: UInt64.max) { resolver in
                #expect(epoch.beginDispatch(resolver))
                entered.arrive()
            }
        }
        if phase == .beforeDispatch {
            task.cancel()
            start.open()
        } else {
            await entered.waitUntilEntered()
            task.cancel()
        }
        await #expect(throws: phase.expectedError) { _ = try await task.value }
        #expect(entered.hasEntered == (phase == .afterDispatch))
        #expect(epoch.isValid == (phase == .beforeDispatch))
    }
}

private typealias ClaimClientHandler =
    @Sendable (Data) async throws -> (Data?, String?)
private struct ClaimClientInjectedFailure: Error {}
enum ClaimClientClaimContender: CaseIterable { case claim, release }
enum ClaimClientConcurrentReleaseOperation: CaseIterable { case release, claim }
enum ClaimClientClaimDeadlineBoundary: CaseIterable {
    case atSharedDeadline, submicrosecondRemaining, expiredHandle
}
enum ClaimClientReplyDeadlineBoundary: CaseIterable {
    case atReply, afterMaximumWindow, afterSharedDeadline
}
enum ClaimClientFailureScenario: CaseIterable {
    case claimTransport, claimReason, wrongRequestBinding
    case releaseTransport, releaseReason, releaseTamper
    var isRelease: Bool {
        [.releaseTransport, .releaseReason, .releaseTamper].contains(self)
    }
    var expectedError: InvestigationMachineClaimClientError {
        switch self {
        case .claimReason, .releaseReason: .protocolViolation
        case .claimTransport, .wrongRequestBinding: .terminalResidueUncertain
        default: .outcomeUnknown
        }
    }
}
enum ClaimClientAmbiguousClaimScenario: CaseIterable {
    case replyLost, malformedReply, unknownReason, cancelledAfterDispatch
}
enum ClaimClientAbortFailureScenario: CaseIterable {
    case persistentHelper, observerFailure, clockFailure
    var helperEpochs: [InvestigationMachineClaimClientHelperEpoch] {
        self == .persistentHelper ? [.originalHelperPresent] : [.originalHelperAbsent]
    }
    var failureAtObservation: Int? { self == .observerFailure ? 0 : nil }
    fileprivate func clocks(
        _ fixture: ClaimClientFixture
    ) -> [InvestigationMachineClaimClientClockObservation] {
        var values = [
            fixture.claimClockObservation, fixture.claimReplyClockObservation,
        ]
        switch self {
        case .persistentHelper:
            values += [fixture.clockObservation(3_800_000_000),
                       fixture.clockObservation(3_900_000_000)]
        case .observerFailure:
            values += [fixture.clockObservation(2_100_000_000)]
        case .clockFailure:
            break
        }
        return values
    }
}
enum ClaimClientCancellationPhase: CaseIterable {
    case beforeDispatch, afterDispatch
    var expectedError: InvestigationMachineClaimClientError {
        self == .beforeDispatch ? .unavailable : .outcomeUnknown
    }
}
enum ClaimClientIdentityDrift: CaseIterable {
    case initialPath, initialSigning, initialAdHoc
    case initialRequirement, initialCodeDirectoryHash
    case connectionService, connectionPID, connectionASID, connectionEUID
    case dynamicPID, dynamicPIDVersion, dynamicASID, dynamicEUID
    case dynamicPath, dynamicAdHoc, dynamicSigning, dynamicRequirement
    case dynamicCodeDirectoryHash, finalStatic
    var isPreDispatch: Bool {
        [.initialPath, .initialSigning, .initialAdHoc, .initialRequirement,
         .initialCodeDirectoryHash].contains(self)
    }
    var reachesDynamicIdentity: Bool {
        !isPreDispatch
            && ![.connectionService, .connectionPID, .connectionASID, .connectionEUID]
                .contains(self)
    }
    var expectedError: InvestigationMachineClaimClientError {
        isPreDispatch ? .signingIdentityMismatch : .terminalResidueUncertain
    }
}
enum ClaimClientReleaseBoundary: CaseIterable {
    case replyAtDeadline, replyAfterDeadline, absenceAtDeadline, helperNeverAbsent
    var helperEpochs: [InvestigationMachineClaimClientHelperEpoch] {
        self == .helperNeverAbsent
            ? [.originalHelperPresent, .originalHelperPresent]
            : [.originalHelperAbsent]
    }
}
enum ClaimClientEpochTerminalScenario: CaseIterable {
    case cancelBeforeDispatch, failBeforeDispatch, cancelAfterDispatch
    case failAfterDispatch, replyAfterDispatch
    var afterDispatch: Bool {
        self != .cancelBeforeDispatch && self != .failBeforeDispatch
    }
    var isReply: Bool { self == .replyAfterDispatch }
    var expectedError: InvestigationMachineClaimClientError? {
        isReply ? nil : (afterDispatch ? .outcomeUnknown : .unavailable)
    }
}

private struct ClaimClientFixture {
    let appIdentity: InvestigationMachineProcessIdentity
    let helperIdentity: InvestigationMachineProcessIdentity
    let handle: InvestigationHandoffRetirementHandle
    let evidence: InvestigationMachineClaimEvidence
    let released: InvestigationMachineClaimReleased
    let staticIdentityObservation: InvestigationMachineClaimClientStaticIdentityObservation
    let dynamicIdentityObservation: InvestigationMachineClaimClientDynamicIdentityObservation
    let connectionIdentity: InvestigationMachineClaimClientConnectionIdentity
    let claimClockObservation: InvestigationMachineClaimClientClockObservation
    let claimReplyClockObservation: InvestigationMachineClaimClientClockObservation
    let releaseClockObservation: InvestigationMachineClaimClientClockObservation
    let sharedDeadline: InvestigationMachineClaimClientSharedDeadline
    private let uuids: [UUID]
    private let releaseChallenge: UUID
    private let nextIndex = ClaimClientLockedIndex()

    init() throws {
        appIdentity = try .init(
            role: .app, processID: 701, processIDVersion: 11,
            auditSessionID: 44_001, effectiveUserID: 501,
            auditTokenWords: [1, 501, 2, 3, 4, 701, 44_001, 11]
        )
        helperIdentity = try .init(
            role: .helper, processID: 702, processIDVersion: 12,
            auditSessionID: 33_001, effectiveUserID: 0,
            auditTokenWords: [9, 0, 8, 7, 6, 702, 33_001, 12]
        )
        handle = try .init(
            token: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!,
            investigationUUID: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
            retireOperationUUID: UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!,
            configurationSHA256: .init(lowercaseHex: String(repeating: "a", count: 64)),
            validBefore: .init(rawValue: 2_000_000_030_000_000)
        )
        let claimChallenge = UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-dddddddddddd")!
        let claimEpoch = UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee")!
        releaseChallenge = UUID(uuidString: "ffffffff-ffff-4fff-8fff-ffffffffffff")!
        uuids = [claimChallenge, claimEpoch, releaseChallenge]
        sharedDeadline = try .init(epochDeadlineNanoseconds: 4_000_000_000)
        let request = try InvestigationMachineRetirementClaimRequest(
            handle: handle, claimChallenge: claimChallenge,
            issuedAt: .init(rawValue: 2_000_000_001_000_000),
            requestValidBefore: .init(rawValue: 2_000_000_004_000_000),
            claimConnectionEpoch: claimEpoch, epochDeadlineNanoseconds: 4_000_000_000
        )
        evidence = try Self.makeEvidence(
            request: request, appIdentity: appIdentity, helperIdentity: helperIdentity,
            requestBinding: request.bindingSHA256(), releaseDeadline: 3_000_000_000
        )
        released = try .init(
            requestBindingSHA256: evidence.requestBindingSHA256,
            releaseChallenge: releaseChallenge,
            claimedHelperIdentitySHA256: helperIdentity.helperIdentitySHA256(),
            claimConnectionEpoch: claimEpoch, exitScheduled: true,
            postReplyExitDeadlineNanoseconds: 3_500_000_000
        )
        staticIdentityObservation = .init(
            executablePath: InvestigationMachineClaimClient.Constants.helperExecutablePath,
            signingIdentifier: InvestigationMachineClaimClient.Constants.helperSigningIdentifier,
            designatedRequirementSHA256: String(repeating: "1", count: 64),
            codeDirectoryHash: String(repeating: "2", count: 40), isAdHoc: true
        )
        dynamicIdentityObservation = .init(
            processID: 702, processIDVersion: 12, auditSessionID: 33_001,
            effectiveUserID: 0, executablePath: staticIdentityObservation.executablePath,
            signingIdentifier: staticIdentityObservation.signingIdentifier,
            designatedRequirementSHA256: staticIdentityObservation.designatedRequirementSHA256,
            codeDirectoryHash: staticIdentityObservation.codeDirectoryHash, isAdHoc: true
        )
        connectionIdentity = .init(
            serviceName: InvestigationMachineClaimClient.Constants.machineClaimServiceIdentifier,
            processID: 702, auditSessionID: 33_001, effectiveUserID: 0
        )
        claimClockObservation = try Self.clock(
            1_000_000_000, wall: 2_000_000_001_000_000
        )
        claimReplyClockObservation = try Self.clock(
            1_100_000_000, wall: 2_000_000_001_100_000
        )
        releaseClockObservation = try Self.clock(
            2_100_000_000, wall: 2_000_000_003_000_000
        )
    }

    var serviceName: String {
        InvestigationMachineClaimClient.Constants.machineClaimServiceIdentifier
    }
    var signingRequirement: String {
        "identifier \"com.eriklee.stornaut.lifecycle.helper\" and cdhash H\""
            + String(repeating: "2", count: 40) + "\""
    }
    var sharedDeadlineValue: UInt64 { sharedDeadline.epochDeadlineNanoseconds }
    var releaseDeadline: UInt64 { evidence.releaseDeadlineNanoseconds }
    var wrongRequestBinding: InvestigationHandoffSHA256 {
        get throws { try .init(lowercaseHex: String(repeating: "b", count: 64)) }
    }
    var staticIdentityObservations: [InvestigationMachineClaimClientStaticIdentityObservation] {
        [staticIdentityObservation, staticIdentityObservation]
    }
    var successClockObservations: [InvestigationMachineClaimClientClockObservation] {
        [claimClockObservation, claimReplyClockObservation, releaseClockObservation,
         releaseClockObservation, clock(2_200_000_000), clock(2_300_000_000),
         clock(2_400_000_000)]
    }
    var immediateReleaseClockObservations: [InvestigationMachineClaimClientClockObservation] {
        [claimClockObservation, claimReplyClockObservation, releaseClockObservation,
         releaseClockObservation, clock(2_200_000_000)]
    }
    var claimAndReleaseFailureClockObservations: [InvestigationMachineClaimClientClockObservation] {
        [claimClockObservation, claimReplyClockObservation, releaseClockObservation]
    }
    var freshPreviousHelperIdentity: InvestigationMachineProcessIdentity {
        get throws {
            try .init(
                role: .helper, processID: 704, processIDVersion: 13,
                auditSessionID: 33_002, effectiveUserID: 0,
                auditTokenWords: [9, 0, 8, 7, 6, 704, 33_002, 13]
            )
        }
    }

    func client(
        session: ClaimClientSessionDouble,
        clock: ClaimClientClockDouble,
        transport: ClaimClientTransportDouble? = nil,
        staticReader: ClaimClientStaticIdentityReaderDouble? = nil,
        dynamicReader: ClaimClientDynamicIdentityReaderDouble? = nil,
        epochObserver: ClaimClientHelperEpochObserverDouble? = nil,
        helperEpochs: [InvestigationMachineClaimClientHelperEpoch] = []
    ) -> InvestigationMachineClaimClient {
        .init(
            transport: transport ?? .init(session: session),
            staticHelperIdentityReader: staticReader ?? .init(staticIdentityObservations),
            dynamicHelperIdentityReader: dynamicReader ?? .init(dynamicIdentityObservation),
            helperEpochObserver: epochObserver ?? .init(helperEpochs),
            clock: clock, uuid: nextUUID
        )
    }

    func configure(
        _ session: ClaimClientSessionDouble,
        connectionIdentity: InvestigationMachineClaimClientConnectionIdentity? = nil,
        claimHandler: ClaimClientHandler? = nil,
        releaseHandler: ClaimClientHandler? = nil
    ) async {
        let claim = claimHandler ?? { data in
            let request = try InvestigationMachineRetirementClaimRequest.decode(data)
            return (try claimReply(for: request), nil)
        }
        let release = releaseHandler ?? { data in
            let value = try InvestigationMachineClaimRelease.decode(data)
            return (try releaseReply(for: value), nil)
        }
        await session.configure(
            connectionIdentity: connectionIdentity ?? self.connectionIdentity,
            claimHandler: claim, releaseHandler: release
        )
    }

    func claim(
        _ client: InvestigationMachineClaimClient,
        sharedDeadline: InvestigationMachineClaimClientSharedDeadline? = nil,
        previousHelperIdentity: InvestigationMachineProcessIdentity? = nil
    ) async throws -> InvestigationMachineClaimEvidence {
        try await client.claimOrProveTerminal(
            handle: handle, appIdentity: appIdentity,
            sharedDeadline: sharedDeadline ?? self.sharedDeadline,
            previousHelperIdentity: previousHelperIdentity
        )
    }
    func clockObservation(
        _ monotonic: UInt64
    ) -> InvestigationMachineClaimClientClockObservation {
        clock(monotonic)
    }

    func claimReply(
        for request: InvestigationMachineRetirementClaimRequest,
        requestBinding: InvestigationHandoffSHA256? = nil,
        releaseDeadline: UInt64 = 3_000_000_000
    ) throws -> Data {
        let binding = try requestBinding ?? request.bindingSHA256()
        let value = try Self.makeEvidence(
            request: request, appIdentity: appIdentity, helperIdentity: helperIdentity,
            requestBinding: binding, releaseDeadline: releaseDeadline
        )
        #expect(request.handle == handle)
        #expect(value.requestBindingSHA256 == binding)
        #expect(value.originalClaimChallenge == request.claimChallenge)
        #expect(value.claimConnectionEpoch == request.claimConnectionEpoch)
        #expect(value.appIdentity == appIdentity)
        #expect(value.helperIdentity == helperIdentity)
        #expect(value.l1Residue.investigationUUID == request.handle.investigationUUID)
        return try value.encoded()
    }
    func acceptedClaimReply(for request: Data) throws -> Data {
        let escrow = LifecycleMachineRetirementEscrow(
            now: { Date(timeIntervalSince1970: 2_000_000_000.5) }, token: { handle.token },
            reservationID: { UUID(uuidString: "abababab-abab-4bab-8bab-abababababab")! }
        )
        let helper = try lifecycleIdentity(helperIdentity)
        _ = try escrow.record(
            investigationID: .init(rawValue: handle.investigationUUID),
            retireOperationID: handle.retireOperationUUID,
            configurationSHA256: String(repeating: "a", count: 64),
            validBefore: Date(timeIntervalSince1970: 2_000_000_030),
            appIdentity: try lifecycleIdentity(appIdentity), helperIdentity: helper,
            userID: 501,
            ownerRetirementObservation: .retiredOwnedResources,
            residueObservation: try .init(
                investigationID: .init(rawValue: handle.investigationUUID),
                auditSessionID: helper.auditSessionID, userID: 501,
                observedAt: Date(timeIntervalSince1970: 2_000_000_000.25),
                remainingAuditSessionMemberCount: 0, matchingLeaseCount: 0,
                leaseRootEntryCount: 0, investigationArtifactCount: 0)
        )
        let effects = ClaimClientServerEffects([
            try .init(monotonicNanoseconds: 500_000_000, wallUTCMicroseconds: 2_000_000_000_500_000),
            try .init(monotonicNanoseconds: 1_100_000_000, wallUTCMicroseconds: 2_000_000_002_000_000),
        ])
        let executor = InvestigationMachineClaimServerEffectExecutor(
            clock: effects, scheduler: effects, terminal: effects
        )
        let state = LifecycleMachineRetirementEscrowDeadlineState()
        let adapter = try InvestigationMachineClaimServerAdapter(
            transfer: escrow.transferReservation(), clock: effects, state: state,
            executor: executor)
        let reply = try adapter.claim(request)
        #expect(state.phase == .claimedAwaitingRelease)
        return reply
    }
    private func lifecycleIdentity(_ value: InvestigationMachineProcessIdentity) throws
        -> LifecycleMachineProcessIdentityRecord {
        try .init(
            processID: Int32(value.processID),
            processIDVersion: Int32(value.processIDVersion),
            auditSessionID: Int32(value.auditSessionID), effectiveUserID: value.effectiveUserID,
            auditTokenWords: value.auditTokenWords
        )
    }

    func releaseReply(for release: InvestigationMachineClaimRelease) throws -> Data {
        try assertRelease(release)
        return try released.encoded()
    }
    func tamperedReleaseReply(
        for release: InvestigationMachineClaimRelease
    ) throws -> Data {
        try assertRelease(release)
        return try InvestigationMachineClaimReleased(
            requestBindingSHA256: released.requestBindingSHA256,
            releaseChallenge: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            claimedHelperIdentitySHA256: released.claimedHelperIdentitySHA256,
            claimConnectionEpoch: released.claimConnectionEpoch, exitScheduled: true,
            postReplyExitDeadlineNanoseconds: released.postReplyExitDeadlineNanoseconds
        ).encoded()
    }
    private func assertRelease(_ release: InvestigationMachineClaimRelease) throws {
        #expect(release.requestBindingSHA256 == evidence.requestBindingSHA256)
        #expect(release.releaseChallenge == releaseChallenge)
        #expect(release.claimedHelperIdentitySHA256 == (
            try helperIdentity.helperIdentitySHA256()
        ))
        #expect(release.claimConnectionEpoch == evidence.claimConnectionEpoch)
        #expect(release.releaseDeadlineNanoseconds == evidence.releaseDeadlineNanoseconds)
    }

    func connectionIdentity(
        for drift: ClaimClientIdentityDrift
    ) -> InvestigationMachineClaimClientConnectionIdentity {
        .init(
            serviceName: drift == .connectionService ? "wrong.service" : serviceName,
            processID: drift == .connectionPID ? 703 : helperIdentity.processID,
            auditSessionID: drift == .connectionASID ? 33_002 : helperIdentity.auditSessionID,
            effectiveUserID: drift == .connectionEUID ? 1 : helperIdentity.effectiveUserID
        )
    }
    func dynamicIdentityObservation(
        for drift: ClaimClientIdentityDrift
    ) -> InvestigationMachineClaimClientDynamicIdentityObservation {
        .init(
            processID: drift == .dynamicPID ? 703 : helperIdentity.processID,
            processIDVersion: drift == .dynamicPIDVersion ? 13 : helperIdentity.processIDVersion,
            auditSessionID: drift == .dynamicASID ? 33_002 : helperIdentity.auditSessionID,
            effectiveUserID: drift == .dynamicEUID ? 1 : helperIdentity.effectiveUserID,
            executablePath: drift == .dynamicPath ? "/wrong/helper" : staticIdentityObservation.executablePath,
            signingIdentifier: drift == .dynamicSigning ? "wrong.signing" : staticIdentityObservation.signingIdentifier,
            designatedRequirementSHA256: drift == .dynamicRequirement
                ? String(repeating: "3", count: 64)
                : staticIdentityObservation.designatedRequirementSHA256,
            codeDirectoryHash: drift == .dynamicCodeDirectoryHash
                ? String(repeating: "4", count: 40)
                : staticIdentityObservation.codeDirectoryHash,
            isAdHoc: drift != .dynamicAdHoc
        )
    }
    func staticIdentityObservations(
        for drift: ClaimClientIdentityDrift
    ) -> [InvestigationMachineClaimClientStaticIdentityObservation] {
        var initial = staticIdentityObservation
        switch drift {
        case .initialPath: initial = staticObservation(path: "/wrong/helper")
        case .initialSigning: initial = staticObservation(signing: "wrong.signing")
        case .initialAdHoc: initial = staticObservation(adHoc: false)
        case .initialRequirement: initial = staticObservation(requirement: "not-hex")
        case .initialCodeDirectoryHash: initial = staticObservation(cdhash: "not-hex")
        default: break
        }
        let final = drift == .finalStatic
            ? staticObservation(requirement: String(repeating: "5", count: 64))
            : initial
        return [initial, final]
    }
    private func staticObservation(
        path: String? = nil, signing: String? = nil,
        requirement: String? = nil, cdhash: String? = nil, adHoc: Bool? = nil
    ) -> InvestigationMachineClaimClientStaticIdentityObservation {
        .init(
            executablePath: path ?? staticIdentityObservation.executablePath,
            signingIdentifier: signing ?? staticIdentityObservation.signingIdentifier,
            designatedRequirementSHA256: requirement
                ?? staticIdentityObservation.designatedRequirementSHA256,
            codeDirectoryHash: cdhash ?? staticIdentityObservation.codeDirectoryHash,
            isAdHoc: adHoc ?? staticIdentityObservation.isAdHoc
        )
    }

    func claimDeadlineInput(
        _ boundary: ClaimClientClaimDeadlineBoundary
    ) throws -> (handle: InvestigationHandoffRetirementHandle,
                 deadline: InvestigationMachineClaimClientSharedDeadline,
                 clock: InvestigationMachineClaimClientClockObservation) {
        switch boundary {
        case .atSharedDeadline:
            return (handle, sharedDeadline, clock(4_000_000_000))
        case .submicrosecondRemaining:
            return (handle, sharedDeadline, clock(3_999_999_500))
        case .expiredHandle:
            let expired = try InvestigationHandoffRetirementHandle(
                token: handle.token, investigationUUID: handle.investigationUUID,
                retireOperationUUID: handle.retireOperationUUID,
                configurationSHA256: handle.configurationSHA256,
                validBefore: claimClockObservation.wallUTCMicroseconds
            )
            return (expired, sharedDeadline, claimClockObservation)
        }
    }
    func claimReplyDeadlineInput(
        _ boundary: ClaimClientReplyDeadlineBoundary
    ) throws -> (sharedDeadline: InvestigationMachineClaimClientSharedDeadline,
                 releaseDeadline: UInt64) {
        switch boundary {
        case .atReply:
            return (sharedDeadline, claimReplyClockObservation.continuousNanoseconds)
        case .afterMaximumWindow:
            return (try .init(epochDeadlineNanoseconds: 7_000_000_000), 6_100_000_001)
        case .afterSharedDeadline:
            return (sharedDeadline, sharedDeadlineValue + 1)
        }
    }
    func releaseBoundaryClocks(
        _ boundary: ClaimClientReleaseBoundary
    ) -> [InvestigationMachineClaimClientClockObservation] {
        let reply: UInt64 = boundary == .absenceAtDeadline
            || boundary == .helperNeverAbsent ? 2_100_000_000
            : (boundary == .replyAfterDeadline ? releaseDeadline + 1 : releaseDeadline)
        let helper: UInt64 = boundary == .absenceAtDeadline
            || boundary == .helperNeverAbsent ? 3_500_000_000 : 2_200_000_000
        return [claimClockObservation, claimReplyClockObservation,
                releaseClockObservation, clock(reply), clock(helper)]
    }

    private func nextUUID() -> UUID { uuids[nextIndex.next()] }
    private func clock(_ monotonic: UInt64) -> InvestigationMachineClaimClientClockObservation {
        .init(
            continuousNanoseconds: monotonic,
            wallUTCMicroseconds: releaseClockObservation.wallUTCMicroseconds
        )
    }
    private static func clock(
        _ monotonic: UInt64, wall: Int64
    ) throws -> InvestigationMachineClaimClientClockObservation {
        .init(
            continuousNanoseconds: monotonic,
            wallUTCMicroseconds: try .init(rawValue: wall)
        )
    }
    private static func makeEvidence(
        request: InvestigationMachineRetirementClaimRequest,
        appIdentity: InvestigationMachineProcessIdentity,
        helperIdentity: InvestigationMachineProcessIdentity,
        requestBinding: InvestigationHandoffSHA256, releaseDeadline: UInt64
    ) throws -> InvestigationMachineClaimEvidence {
        try .init(
            requestBindingSHA256: requestBinding,
            originalClaimChallenge: request.claimChallenge,
            claimConnectionEpoch: request.claimConnectionEpoch,
            appIdentity: appIdentity, helperIdentity: helperIdentity, appUserID: 501,
            recordedAt: .init(rawValue: 2_000_000_000_500_000),
            claimedAt: .init(rawValue: 2_000_000_002_000_000),
            ownerRetirement: .init(),
            l1Residue: .init(
                investigationUUID: request.handle.investigationUUID,
                auditSessionID: helperIdentity.auditSessionID, userID: 501,
                observedAt: .init(rawValue: 2_000_000_000_250_000),
                remainingAuditSessionMembers: 0, matchingLeases: 0,
                leaseRootEntries: 0, investigationArtifacts: 0
            ),
            releaseDeadlineNanoseconds: releaseDeadline
        )
    }
}

private final class ClaimClientLockedIndex: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int {
        lock.withLock { defer { value += 1 }; return value }
    }
}
private final class ClaimClientTransportDouble:
    InvestigationMachineClaimClientTransporting, @unchecked Sendable
{
    let session: ClaimClientSessionDouble
    private(set) var connectCount = 0
    private(set) var serviceNames: [String] = []
    private(set) var codeSigningRequirements: [String] = []
    private let trace: ClaimClientCallTrace?
    init(
        session: ClaimClientSessionDouble, trace: ClaimClientCallTrace? = nil
    ) {
        self.session = session
        self.trace = trace
    }
    func connect(
        serviceName: String, codeSigningRequirement: String
    ) async throws -> any InvestigationMachineClaimClientSession {
        connectCount += 1
        serviceNames.append(serviceName)
        codeSigningRequirements.append(codeSigningRequirement)
        await trace?.record("connect:\(session.sessionID)")
        return session
    }
}
private actor ClaimClientSessionDouble: InvestigationMachineClaimClientSession {
    nonisolated let sessionID: String
    var connectionIdentity = InvestigationMachineClaimClientConnectionIdentity(
        serviceName: "", processID: 0, auditSessionID: 0, effectiveUserID: 0
    )
    var claimRequests: [Data] = []
    var releaseRequests: [Data] = []
    var claimDeadlines: [UInt64] = []
    var releaseDeadlines: [UInt64] = []
    var invalidatedCount = 0
    private var invalidated = false
    private let claimGate: ClaimClientAsyncGate?
    private let releaseGate: ClaimClientAsyncGate?
    private let trace: ClaimClientCallTrace?
    private var claimHandler: ClaimClientHandler?
    private var releaseHandler: ClaimClientHandler?
    init(
        claimGate: ClaimClientAsyncGate? = nil,
        releaseGate: ClaimClientAsyncGate? = nil,
        sessionID: String = "primary",
        trace: ClaimClientCallTrace? = nil
    ) {
        self.claimGate = claimGate
        self.releaseGate = releaseGate
        self.sessionID = sessionID
        self.trace = trace
    }
    func configure(
        connectionIdentity: InvestigationMachineClaimClientConnectionIdentity,
        claimHandler: @escaping ClaimClientHandler,
        releaseHandler: @escaping ClaimClientHandler
    ) {
        self.connectionIdentity = connectionIdentity
        self.claimHandler = claimHandler
        self.releaseHandler = releaseHandler
    }
    func currentConnectionIdentity() async throws
        -> InvestigationMachineClaimClientConnectionIdentity {
        guard !invalidated else { throw ClaimClientInjectedFailure() }
        return connectionIdentity
    }
    func claim(
        _ request: Data, deadlineNanoseconds: UInt64
    ) async throws -> (Data?, String?) {
        guard !invalidated else { throw ClaimClientInjectedFailure() }
        claimRequests.append(request)
        claimDeadlines.append(deadlineNanoseconds)
        await trace?.record("claim:\(sessionID)")
        if let claimGate { claimGate.arrive(); await claimGate.waitUntilOpen() }
        let handler = try #require(claimHandler)
        return try await handler(request)
    }
    func release(
        _ request: Data, deadlineNanoseconds: UInt64
    ) async throws -> (Data?, String?) {
        guard !invalidated else { throw ClaimClientInjectedFailure() }
        releaseRequests.append(request)
        releaseDeadlines.append(deadlineNanoseconds)
        await trace?.record("release:\(sessionID)")
        if let releaseGate { releaseGate.arrive(); await releaseGate.waitUntilOpen() }
        let handler = try #require(releaseHandler)
        return try await handler(request)
    }
    func invalidate() async {
        invalidatedCount += 1
        invalidated = true
        await trace?.record("invalidate:\(sessionID)")
    }
}
private final class ClaimClientStaticIdentityReaderDouble:
    InvestigationMachineClaimClientStaticIdentityReading, @unchecked Sendable
{
    private let lock = NSLock()
    private var observations: [InvestigationMachineClaimClientStaticIdentityObservation]
    private(set) var readCount = 0
    init(_ observations: [InvestigationMachineClaimClientStaticIdentityObservation]) {
        self.observations = observations
    }
    func readHelperIdentity() throws
        -> InvestigationMachineClaimClientStaticIdentityObservation {
        try lock.withLock {
            guard !observations.isEmpty else { throw ClaimClientInjectedFailure() }
            readCount += 1
            return observations.removeFirst()
        }
    }
}
private final class ClaimClientDynamicIdentityReaderDouble:
    InvestigationMachineClaimClientDynamicIdentityReading, @unchecked Sendable
{
    let observation: InvestigationMachineClaimClientDynamicIdentityObservation
    private(set) var auditTokenWords: [[UInt32]] = []
    init(_ observation: InvestigationMachineClaimClientDynamicIdentityObservation) {
        self.observation = observation
    }
    func readHelperIdentity(
        auditTokenWords: [UInt32]
    ) throws -> InvestigationMachineClaimClientDynamicIdentityObservation {
        self.auditTokenWords.append(auditTokenWords)
        return observation
    }
}
private actor ClaimClientHelperEpochObserverDouble:
    InvestigationMachineClaimClientHelperEpochObserving
{
    private let epochs: [InvestigationMachineClaimClientHelperEpoch]
    private let absenceRequiresSleepFrom: ClaimClientClockDouble?
    private let failureAtObservation: Int?
    private let trace: ClaimClientCallTrace?
    private let gate: ClaimClientAsyncGate?
    private var index = 0
    private(set) var observations: [InvestigationMachineProcessIdentity] = []
    private(set) var serviceNames: [String] = []
    init(
        _ epochs: [InvestigationMachineClaimClientHelperEpoch],
        absenceRequiresSleepFrom: ClaimClientClockDouble? = nil,
        failureAtObservation: Int? = nil,
        trace: ClaimClientCallTrace? = nil,
        gate: ClaimClientAsyncGate? = nil
    ) {
        self.epochs = epochs
        self.absenceRequiresSleepFrom = absenceRequiresSleepFrom
        self.failureAtObservation = failureAtObservation
        self.trace = trace
        self.gate = gate
    }
    func observe(
        serviceName: String, claimedHelperIdentity: InvestigationMachineProcessIdentity
    ) async throws -> InvestigationMachineClaimClientHelperEpoch {
        observations.append(claimedHelperIdentity)
        serviceNames.append(serviceName)
        if let gate { gate.arrive(); await gate.waitUntilOpen() }
        if failureAtObservation == index {
            await trace?.record("observe:\(claimedHelperIdentity.processID):failure")
            index += 1
            throw ClaimClientInjectedFailure()
        }
        let value = index < epochs.count ? epochs[index] : .originalHelperPresent
        index += 1
        let label = value == .originalHelperAbsent ? "absent" : "present"
        await trace?.record("observe:\(claimedHelperIdentity.processID):\(label)")
        if value == .originalHelperAbsent, let clock = absenceRequiresSleepFrom {
            #expect(clock.sleepDeadlines == [2_300_000_000])
        }
        return value
    }
}
private final class ClaimClientClockDouble:
    InvestigationMachineClaimClientClocking, @unchecked Sendable
{
    private let lock = NSLock()
    private var observations: [InvestigationMachineClaimClientClockObservation]
    private(set) var sleepDeadlines: [UInt64] = []
    private let trace: ClaimClientCallTrace?
    init(
        _ observations: [InvestigationMachineClaimClientClockObservation],
        trace: ClaimClientCallTrace? = nil
    ) {
        self.observations = observations
        self.trace = trace
    }
    func observe() throws -> InvestigationMachineClaimClientClockObservation {
        try lock.withLock {
            guard !observations.isEmpty else { throw ClaimClientInjectedFailure() }
            return observations.removeFirst()
        }
    }
    func sleep(untilNanoseconds deadlineNanoseconds: UInt64) async {
        lock.withLock { sleepDeadlines.append(deadlineNanoseconds) }
        await trace?.record("sleep:\(deadlineNanoseconds)")
    }
}
private actor ClaimClientCallTrace {
    private(set) var events: [String] = []
    func record(_ event: String) { events.append(event) }
}
private final class ClaimClientServerEffects: InvestigationMachineClaimServerCoreClock,
    InvestigationMachineClaimServerCoreScheduling,
    InvestigationMachineClaimServerCoreTerminalHandling,
    InvestigationMachineClaimServerCoreScheduledHandle, @unchecked Sendable
{
    private let lock = NSLock()
    private var values: [LifecycleMachineRetirementDeadlineObservation]
    init(_ values: [LifecycleMachineRetirementDeadlineObservation]) { self.values = values }
    func observation() throws -> LifecycleMachineRetirementDeadlineObservation {
        try lock.withLock {
            guard !values.isEmpty else { throw ClaimClientInjectedFailure() }
            return values.removeFirst()
        }
    }
    func schedule(ticket _: LifecycleMachineRetirementDeadlineTicket,
        callback _: @escaping @Sendable () -> Void
    ) throws -> any InvestigationMachineClaimServerCoreScheduledHandle {
        self
    }
    func cancel() {}
    func handle(_ reason: LifecycleMachineRetirementDeadlineTerminalReason) {}
}
private final class ClaimClientAsyncGate: @unchecked Sendable {
    private let lock = NSLock()
    private var entered = false
    private var openState = false
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var openWaiters: [CheckedContinuation<Void, Never>] = []
    var hasEntered: Bool { lock.withLock { entered } }
    func arrive() {
        let waiters = lock.withLock {
            entered = true
            defer { enteredWaiters.removeAll() }
            return enteredWaiters
        }
        waiters.forEach { $0.resume() }
    }
    func open() {
        let waiters = lock.withLock {
            openState = true
            defer { openWaiters.removeAll() }
            return openWaiters
        }
        waiters.forEach { $0.resume() }
    }
    func waitUntilEntered() async { await wait(forOpen: false) }
    func waitUntilOpen() async { await wait(forOpen: true) }
    private func wait(forOpen: Bool) async {
        await withCheckedContinuation { continuation in
            let resume = lock.withLock {
                if forOpen ? openState : entered { return true }
                if forOpen { openWaiters.append(continuation) }
                else { enteredWaiters.append(continuation) }
                return false
            }
            if resume { continuation.resume() }
        }
    }
}
private func claimClientResolverResult(
    _ resolver: InvestigationMachineClaimClientReplyResolver
) async -> (data: Data?, error: InvestigationMachineClaimClientError?) {
    do {
        let value = try await withCheckedThrowingContinuation { continuation in
            _ = resolver.install(continuation)
        }
        return (value.0, nil)
    } catch {
        return (nil, error as? InvestigationMachineClaimClientError)
    }
}
