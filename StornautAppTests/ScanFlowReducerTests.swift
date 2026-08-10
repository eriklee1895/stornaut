import Foundation
import StornautCore
import Testing
@testable import StornautApp

@Test
func scanFlowStartsOnlyFromExplicitIntentAndKeepsUnitsSeparate() throws {
    let reducer = ScanFlowReducer()
    let now = OverviewTestProjectionFactory.now
    var state = ScanFlowState.idle

    #expect(state.phase == .idle)
    #expect(state.stageStates.allSatisfy { $0.status == .pending })
    #expect(state.scopeScanned == 0)
    #expect(state.candidatesFound == 0)
    #expect(state.measuredBytes == ByteCount(0))
    #expect(state.elapsed == 0)

    state = reducer.started(previous: state, at: now)
    state = reducer.reduce(
        .stageChanged(.indexVolumes),
        state: state
    )
    state = reducer.reduce(
        .progress(
            QuickScanProgress(
                scopeID: ScanScopeID(rawValue: "scope-scan-flow")!,
                currentRelativePath: PersistedPath(
                    rawValue: "Library/Caches"
                )!,
                counters: ScanProgress(
                    completedEntries: 17,
                    regularFileCount: 10,
                    directoryCount: 6,
                    symlinkCount: 1,
                    errorCount: 0,
                    logicalFileBytes: 2_000,
                    allocatedFileBytes: 1_500
                )
            )
        ),
        state: state
    )
    state = reducer.elapsed(state: state, at: now.addingTimeInterval(12))

    #expect(state.phase == .active)
    #expect(state.currentStage == .indexVolumes)
    #expect(state.currentRelativePath?.rawValue == "Library/Caches")
    #expect(state.scopeScanned == 17)
    #expect(state.candidatesFound == 0)
    #expect(state.measuredBytes == ByteCount(1_500))
    #expect(state.elapsed == 12)
}

@Test
func scanFlowAcceptsOnlyMonotonicAdjacentFiveStageProgress() {
    let reducer = ScanFlowReducer()
    var state = reducer.started(
        previous: .idle,
        at: OverviewTestProjectionFactory.now
    )

    for (index, stage) in QuickScanStage.allCases.enumerated() {
        state = reducer.reduce(.stageChanged(stage), state: state)
        #expect(state.currentStage == stage)
        #expect(
            state.stageStates[index].status == .current
        )
        #expect(
            state.stageStates.prefix(index).allSatisfy {
                $0.status == .complete
            }
        )
        #expect(
            state.stageStates.dropFirst(index + 1).allSatisfy {
                $0.status == .pending
            }
        )
    }

    let finalizing = state
    state = reducer.reduce(
        .stageChanged(.mapProjects),
        state: state
    )
    #expect(state == finalizing)

    var skipped = reducer.started(
        previous: .idle,
        at: OverviewTestProjectionFactory.now
    )
    skipped = reducer.reduce(
        .stageChanged(.classifyArtifacts),
        state: skipped
    )
    #expect(skipped.currentStage == nil)
    #expect(skipped.stageStates.allSatisfy { $0.status == .pending })
}

@Test
func scanFlowAccumulatesProgressiveFactsByStableIdentity() throws {
    let reducer = ScanFlowReducer()
    let projection = try OverviewTestProjectionFactory.projection(
        slug: "scan-progressive"
    )
    let firstClassification = projection.classifications[0]
    let firstSnapshot = try #require(
        projection.snapshots.first {
            $0.id == firstClassification.snapshotID
        }
    )
    let firstEvidence = projection.evidence[0]
    var state = reducer.started(
        previous: .idle,
        at: projection.session.startedAt
    )

    for event in [
        QuickScanProductEvent.classifiedSnapshotObserved(
            firstSnapshot,
            firstClassification
        ),
        .classifiedSnapshotObserved(
            firstSnapshot,
            firstClassification
        ),
        .evidenceObserved(firstEvidence),
        .evidenceObserved(firstEvidence),
        .ledgerUpdated(projection.ledger!),
    ] {
        state = reducer.reduce(event, state: state)
    }

    #expect(state.snapshots == [firstSnapshot])
    #expect(state.classifications == [firstClassification])
    #expect(state.evidence == [firstEvidence])
    #expect(state.ledger == projection.ledger)
    #expect(state.candidatesFound == 1)

    let root = projection.snapshots[0]
    let rootClassification = try Classification(
        id: ClassificationID(
            rawValue: "classification-scan-progressive-root"
        )!,
        snapshotID: root.id,
        ruleID: nil,
        producer: nil,
        category: .unknownLargeConsumers,
        disposition: .unknown,
        risk: .high,
        confidence: .low,
        recovery: nil,
        requiredEvidenceKeys: [],
        missingEvidenceKeys: [],
        catalogVersion: DomainToken(
            rawValue: "scan-progressive-catalog"
        )!,
        classifiedAt: projection.session.finishedAt
    )
    state = reducer.reduce(
        .classifiedSnapshotObserved(root, rootClassification),
        state: state
    )

    #expect(state.candidatesFound == 1)
}

@Test
func scanFlowStopIsIdempotentAndTerminalTruthWins() throws {
    let reducer = ScanFlowReducer()
    var state = reducer.started(
        previous: .idle,
        at: OverviewTestProjectionFactory.now
    )

    state = reducer.stopRequested(state: state)
    #expect(state.phase == .stopping)
    #expect(state.stopWasRequested)
    #expect(reducer.stopRequested(state: state) == state)

    let cancelled = try OverviewTestProjectionFactory.projection(
        slug: "scan-cancelled",
        terminalState: .cancelled
    )
    state = reducer.reduce(.terminal(cancelled), state: state)

    #expect(state.phase == .cancelled)
    #expect(state.projection == cancelled)
    #expect(state.stopWasRequested)
    #expect(state.stageStates.allSatisfy {
        $0.status != .current
    })
}

@Test
func scanFlowMapsCompletedPartialPermissionAndStoreFailureTerminals()
    throws
{
    let reducer = ScanFlowReducer()
    let cases: [(QuickScanProjection, ScanFlowPhase)] = [
        (
            try OverviewTestProjectionFactory.projection(
                slug: "scan-completed"
            ),
            .completed
        ),
        (
            try OverviewTestProjectionFactory.projection(
                slug: "scan-partial",
                terminalState: .partial
            ),
            .partial
        ),
        (
            try OverviewTestProjectionFactory.projection(
                slug: "scan-permission",
                terminalState: .partial,
                permissionGap: true
            ),
            .limitedPermission
        ),
        (
            try OverviewTestProjectionFactory.projection(
                slug: "scan-store-failure",
                terminalState: .failed
            ),
            .failed
        ),
    ]

    for (projection, expectedPhase) in cases {
        let active = reducer.started(
            previous: .idle,
            at: projection.session.startedAt
        )
        let terminal = reducer.reduce(
            .terminal(projection),
            state: active
        )

        #expect(terminal.phase == expectedPhase)
        #expect(terminal.projection == projection)
        #expect(terminal.stageStates.allSatisfy {
            expectedPhase == .completed
                ? $0.status == .complete
                : true
        })
    }
}

@Test
func retainedPartialSnapshotDoesNotInventStageHistory() throws {
    let projection = try OverviewTestProjectionFactory.projection(
        slug: "scan-retained-stage-history",
        terminalState: .partial
    )
    let state = ScanFlowState.retained(projection)

    #expect(state.stageStates.allSatisfy {
        $0.status == .unavailable
    })
}

@Test
func scanFlowFailurePreservesProgressiveAndRetainedResults() throws {
    let reducer = ScanFlowReducer()
    let retained = try OverviewTestProjectionFactory.projection(
        slug: "scan-retained"
    )
    let classification = retained.classifications[0]
    let snapshot = try #require(
        retained.snapshots.first {
            $0.id == classification.snapshotID
        }
    )
    var state = reducer.started(
        previous: ScanFlowState.retained(retained),
        at: retained.session.finishedAt.addingTimeInterval(1)
    )
    state = reducer.reduce(
        .classifiedSnapshotObserved(snapshot, classification),
        state: state
    )
    state = reducer.failed(
        state: state,
        reasonKey: DomainToken(rawValue: "scan.error.stream")!
    )

    #expect(state.phase == .failed)
    #expect(state.projection == retained)
    #expect(state.snapshots == [snapshot])
    #expect(state.reasonKey?.rawValue == "scan.error.stream")

    let pageState = try AppPageState.success(
        projection: retained,
        refreshedAt: OverviewTestProjectionFactory.now
    )
    let model = ScanModel(
        flowState: state,
        pageState: pageState
    )
    #expect(model.rows.map(\.id) == [snapshot.id])
}
