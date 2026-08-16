import Foundation
import Testing
import StornautCore
@testable import StornautInvestigation

@Suite("InvestigationCoordinator start admission")
struct InvestigationCoordinatorTests {
    @Test
    func freshOneShotAdmissionStartsExactlyOneEphemeralRoot() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        let coordinator = fixture.coordinator()
        let admission = fixture.admission()

        let result = try await coordinator.start(admission)

        #expect(result.investigationID == fixture.session.id)
        #expect(result.runID == fixture.session.runID)
        #expect(result.rootSessionID == fixture.root.id)
        #expect(fixture.runtime.startRequests.count == 1)
        #expect(fixture.store.admissionCount == 1)
        #expect(fixture.runtime.startRequests[0].ephemeral)
        #expect(
            fixture.runtime.startRequests[0].context.promptText
                .contains("read-only investigator")
        )
        #expect(
            fixture.runtime.startRequests[0].context.promptText
                .contains("Envelope v2")
        )
        #expect(
            fixture.runtime.startRequests[0].context.targetIDs
                == fixture.plan.targets.map(\.id)
        )
    }

    @Test
    func consumedAdmissionCannotStartAgainEvenAfterRuntimeFailure() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        fixture.runtime.startError = InvestigationRuntimeError.startFailed
        let coordinator = fixture.coordinator()
        let admission = fixture.admission()

        await #expect(throws: InvestigationRuntimeError.startFailed) {
            _ = try await coordinator.start(admission)
        }
        await #expect(throws: InvestigationCoordinatorError.admissionConsumed) {
            _ = try await coordinator.start(admission)
        }
        #expect(fixture.runtime.startRequests.count == 1)
    }

    @Test
    func foreignRootSessionIdentityFailsClosed() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        fixture.runtime.root = InvestigationRuntimeRootV1(
            id: fixture.root.id,
            sessionID: DomainToken(rawValue: "thread-foreign")!
        )

        await #expect(
            throws: InvestigationCoordinatorError.runtimeIdentityLost
        ) {
            _ = try await fixture.coordinator().start(fixture.admission())
        }
        #expect(fixture.lifecycle.drainedRuns == [fixture.session.runID])
        #expect(fixture.runtime.retiredRuns == [fixture.session.runID])
    }

    @Test
    func storeFailureAfterThreadStartDrainsAndRetiresBeforeReturning()
        async throws
    {
        let fixture = try InvestigationCoordinatorFixture()
        fixture.store.failureAfterOperation =
            InvestigationPersistenceError.conflictingReplay

        await #expect(
            throws: InvestigationPersistenceError.conflictingReplay
        ) {
            _ = try await fixture.coordinator().start(fixture.admission())
        }
        #expect(fixture.runtime.startRequests.count == 1)
        #expect(fixture.lifecycle.drainedRuns == [fixture.session.runID])
        #expect(fixture.runtime.retiredRuns == [fixture.session.runID])
    }

    @Test
    func unprovedCleanupReplacesUnderlyingStartFailure() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        fixture.runtime.startError = InvestigationRuntimeError.startFailed
        fixture.lifecycle.result = InvestigationLifecycleDrainResultV1(
            auditSessionEmpty: false,
            managedProxyOwnerEmpty: true
        )

        await #expect(
            throws: InvestigationCoordinatorError.runtimeCleanupUnconfirmed
        ) {
            _ = try await fixture.coordinator().start(fixture.admission())
        }
        #expect(fixture.lifecycle.drainedRuns == [fixture.session.runID])
        #expect(fixture.runtime.retiredRuns.isEmpty)
    }

    @Test
    func turnAndContextAreReservedBeforeRuntimeRequest() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await coordinator.acceptRootStartedNotification(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            root: fixture.root,
            payload: fixture.payload("root-started")
        )
        fixture.runtime.onTurnStart = { request in
            #expect(request.contextBytes == fixture.initialContextBytes)
            #expect(request.reservedTurnCount == 1)
            #expect(
                request.reservedContextBytes
                    == UInt64(fixture.initialContextBytes.count)
            )
        }

        try await coordinator.startTurn(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            threadID: fixture.root.id,
            turnID: fixture.rootTurnID,
            contextBytes: fixture.initialContextBytes
        )

        #expect(fixture.runtime.turnStartRequests.count == 1)
        #expect(
            fixture.runtime.operationLog == [
                "runtime.start",
                "runtime.turn.start",
            ]
        )
    }

    @Test
    func failedTurnSendKeepsReservationAndLaterTurnCanUseRemainder()
        async throws
    {
        let fixture = try InvestigationCoordinatorFixture()
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await coordinator.acceptRootStartedNotification(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            root: fixture.root,
            payload: fixture.payload("root-started")
        )
        fixture.runtime.turnStartErrors = [
            InvestigationRuntimeError.turnStartFailed,
        ]

        await #expect(throws: InvestigationRuntimeError.turnStartFailed) {
            try await coordinator.startTurn(
                investigationID: fixture.session.id,
                runID: fixture.session.runID,
                threadID: fixture.root.id,
                turnID: fixture.rootTurnID,
                contextBytes: fixture.initialContextBytes
            )
        }
        try await coordinator.startTurn(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            threadID: fixture.root.id,
            turnID: fixture.secondRootTurnID,
            contextBytes: fixture.initialContextBytes
        )

        #expect(
            fixture.runtime.turnStartRequests.map(\.reservedTurnCount)
                == [1, 2]
        )
        #expect(
            fixture.runtime.turnStartRequests.map(\.reservedContextBytes)
                == [
                    UInt64(fixture.initialContextBytes.count),
                    UInt64(fixture.initialContextBytes.count * 2),
                ]
        )
    }

    @Test
    func closingRejectsLaterTurnBeforeRuntimeRequest() async throws {
        let fixture = try InvestigationCoordinatorFixture()
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        try await coordinator.acceptRootStartedNotification(
            investigationID: fixture.session.id,
            runID: fixture.session.runID,
            root: fixture.root,
            payload: fixture.payload("root-started")
        )
        _ = try await coordinator.requestStop(
            investigationID: fixture.session.id,
            runID: fixture.session.runID
        )

        await #expect(
            throws: InvestigationCoordinatorError.scientificAdmissionClosed
        ) {
            try await coordinator.startTurn(
                investigationID: fixture.session.id,
                runID: fixture.session.runID,
                threadID: fixture.root.id,
                turnID: fixture.rootTurnID,
                contextBytes: fixture.initialContextBytes
            )
        }
        #expect(fixture.runtime.turnStartRequests.isEmpty)
    }

    @Test
    func activeCoordinatorRejectsAnotherStartBeforeConsumingAdmission()
        async throws
    {
        let fixture = try InvestigationCoordinatorFixture()
        let coordinator = fixture.coordinator()
        _ = try await coordinator.start(fixture.admission())
        let secondAdmission = fixture.admission()

        await #expect(throws: InvestigationCoordinatorError.runAlreadyActive) {
            _ = try await coordinator.start(secondAdmission)
        }
        #expect(fixture.runtime.startRequests.count == 1)
        #expect(fixture.store.admissionCount == 1)
    }
}
