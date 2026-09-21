import Foundation
import Testing
import StornautCore
@testable import StornautInvestigation

@Suite("Investigation terminal barrier")
struct InvestigationTerminalBarrierTests {
    @Test
    func exactDeadlinesUseOneImmutableT0() throws {
        let barrier = InvestigationTerminalBarrier(
            t0Nanoseconds: 10_000_000_000
        )

        #expect(
            barrier.phase(atNanoseconds: 24_999_999_999)
                == .awaitingTerminalEvents
        )
        #expect(
            barrier.phase(atNanoseconds: 25_000_000_000)
                == .drainingLifecycle
        )
        #expect(
            barrier.phase(atNanoseconds: 55_000_000_000)
                == .terminalPersistence
        )
        #expect(
            barrier.phase(atNanoseconds: 145_000_000_000)
                == .rollbackCleanup
        )
        #expect(
            barrier.phase(atNanoseconds: 150_000_000_000)
                == .rollbackUnconfirmed
        )
        #expect(barrier.t0Nanoseconds == 10_000_000_000)
    }

    @Test
    func closingInterruptsEachActiveTurnAtMostOnce() throws {
        let identity = try InvestigationCoordinatorFixture()
        let root = DomainToken(rawValue: "thread-terminal-root")!
        let child = DomainToken(rawValue: "thread-terminal-child")!
        let rootTurn = InvestigationRuntimeTurnIdentityV1(
            investigationID: identity.session.id,
            runID: identity.session.runID,
            threadID: root,
            turnID: DomainToken(rawValue: "turn-terminal-root")!
        )
        let childTurn = InvestigationRuntimeTurnIdentityV1(
            investigationID: identity.session.id,
            runID: identity.session.runID,
            threadID: child,
            turnID: DomainToken(rawValue: "turn-terminal-child")!
        )
        var barrier = InvestigationTerminalBarrier(
            t0Nanoseconds: 1_000_000_000
        )

        let first = barrier.interruptsNeeded(for: [rootTurn, childTurn])
        let replay = barrier.interruptsNeeded(for: [rootTurn, childTurn])

        #expect(Set(first) == Set([rootTurn, childTurn]))
        #expect(replay.isEmpty)
    }

    @Test
    func classificationRequiresDrainArtifactsAndStoreCommit() throws {
        #expect(
            InvestigationTerminalSettlement.classify(
                cause: .userCancelled,
                allTurnsTerminal: true,
                lifecycleProvedEmpty: true,
                artifactsRetired: true,
                storeCommitted: true
            ) == .partial(.userCancelled)
        )
        #expect(
            InvestigationTerminalSettlement.classify(
                cause: .userStopped,
                allTurnsTerminal: false,
                lifecycleProvedEmpty: true,
                artifactsRetired: true,
                storeCommitted: true
            ) == .blocked(.runtimeTerminalUnobserved)
        )
        #expect(
            InvestigationTerminalSettlement.classify(
                cause: .coverageReached,
                allTurnsTerminal: true,
                lifecycleProvedEmpty: false,
                artifactsRetired: true,
                storeCommitted: false
            ) == .blocked(.lifecycleDrainUnconfirmed)
        )
        #expect(
            InvestigationTerminalSettlement.classify(
                cause: .coverageReached,
                allTurnsTerminal: true,
                lifecycleProvedEmpty: true,
                artifactsRetired: false,
                storeCommitted: false
            ) == .failed(.terminalPersistenceFailed)
        )
    }
}
