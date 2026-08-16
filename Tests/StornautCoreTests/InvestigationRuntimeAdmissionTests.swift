import Foundation
import Testing
@testable import StornautCore

@Suite("Investigation runtime admission transaction")
struct InvestigationRuntimeAdmissionTests {
    @Test
    func matchingAdmissionStartsInsidePinnedTransaction() async throws {
        let fixture = try InvestigationStoreV4Fixture()
        let store = try EvidenceStore(configuration: .memory)
        try await fixture.seed(store)
        let planned = try await store.createInvestigation(
            fixture.command(
                investigationID: "investigation-runtime-admission",
                runID: "investigation-run-runtime-admission"
            )
        )
        let ready = try await makeReady(planned, store: store)
        let observation = RuntimeAdmissionObservation()

        let running = try await store.withInvestigationRuntimeAdmission(
            request(for: ready)
        ) { context in
            observation.record(context)
            return .started(
                rootSessionID: DomainToken(rawValue: "thread-root")!
            )
        }

        #expect(running.state == .running)
        #expect(running.stage == .prioritize)
        #expect(observation.plan == ready.plan)
        #expect(observation.targetIDs == ready.plan.targets.map(\.id))
    }

    @Test
    func sourceDriftRejectsBeforeRuntimeClosure() async throws {
        let fixture = try InvestigationStoreV4Fixture()
        let store = try EvidenceStore(configuration: .memory)
        try await fixture.seed(store)
        let planned = try await store.createInvestigation(
            fixture.command(
                investigationID: "investigation-runtime-stale",
                runID: "investigation-run-runtime-stale"
            )
        )
        let ready = try await makeReady(planned, store: store)
        try await store._testReplaceClassificationPayload(
            id: fixture.classification.id,
            payload: String(
                decoding: try DomainJSON.encode(
                    fixture.changedClassification()
                ),
                as: UTF8.self
            )
        )
        let observation = RuntimeAdmissionObservation()

        await #expect(throws: InvestigationPersistenceError.sourceStale) {
            _ = try await store.withInvestigationRuntimeAdmission(
                request(for: ready)
            ) { context in
                observation.record(context)
                return .started(
                    rootSessionID: DomainToken(rawValue: "thread-root")!
                )
            }
        }
        #expect(observation.plan == nil)
        #expect(try await store.investigation(id: ready.id)?.state == .ready)
    }

    @Test
    func failedRuntimeStartRollsBackReadyState() async throws {
        let fixture = try InvestigationStoreV4Fixture()
        let store = try EvidenceStore(configuration: .memory)
        try await fixture.seed(store)
        let planned = try await store.createInvestigation(
            fixture.command(
                investigationID: "investigation-runtime-rollback",
                runID: "investigation-run-runtime-rollback"
            )
        )
        let ready = try await makeReady(planned, store: store)

        await #expect(throws: RuntimeAdmissionTestError.startFailed) {
            _ = try await store.withInvestigationRuntimeAdmission(
                request(for: ready)
            ) { _ in
                throw RuntimeAdmissionTestError.startFailed
            }
        }
        #expect(try await store.investigation(id: ready.id)?.state == .ready)
    }

    private func request(
        for session: InvestigationStoredSession
    ) -> InvestigationRuntimeAdmissionRequestV1 {
        InvestigationRuntimeAdmissionRequestV1(
            admissionID: DomainToken(
                rawValue: "admission-task38-core"
            )!,
            investigationID: session.id,
            runID: session.runID,
            sourceFingerprint: session.plan.sourceFingerprint,
            planFingerprint: session.plan.fingerprint,
            targetSetFingerprint: session.plan.targetSetFingerprint,
            runtimeReceiptID: DomainToken(rawValue: "receipt-task38")!,
            runtimeReceiptSchema: DomainToken(
                rawValue: "collab-tool-call-v1"
            )!,
            disclosureReceiptID: DomainToken(
                rawValue: "disclosure-task38-core"
            )!,
            workflowReservationID: DomainToken(
                rawValue: "workflow-task38-core"
            )!,
            finalAdmissionID: DomainToken(
                rawValue: "final-gate-task38-core"
            )!,
            startedAt: session.updatedAt.addingTimeInterval(1)
        )
    }

    private func makeReady(
        _ session: InvestigationStoredSession,
        store: EvidenceStore
    ) async throws -> InvestigationStoredSession {
        try await store.transitionInvestigationRun(
            InvestigationRunTransitionCommand(
                investigationID: session.id,
                runID: session.runID,
                expectedRunState: .planned,
                runState: .ready,
                sessionState: .ready,
                stage: .prioritize,
                updatedAt: session.updatedAt.addingTimeInterval(1)
            )
        )
    }
}

private enum RuntimeAdmissionTestError: Error, Equatable {
    case startFailed
}

private final class RuntimeAdmissionObservation: @unchecked Sendable {
    private let lock = NSLock()
    private var storedPlan: InvestigationPlan?
    private var storedTargetIDs: [InvestigationTargetID] = []

    var plan: InvestigationPlan? {
        lock.withLock { storedPlan }
    }

    var targetIDs: [InvestigationTargetID] {
        lock.withLock { storedTargetIDs }
    }

    func record(_ context: InvestigationRuntimeAdmissionContextV1) {
        lock.withLock {
            storedPlan = context.plan
            storedTargetIDs = context.targetIDs
        }
    }
}
