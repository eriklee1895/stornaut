import Foundation
import StornautCore
import Testing
@testable import StornautApp

@Test
func scanModelGroupsAndOrdersTheSevenLifecyclesDeterministically()
    throws
{
    let projection = try OverviewTestProjectionFactory.projection(
        slug: "scan-model"
    )
    let model = ScanModel(
        flowState: .retained(projection),
        pageState: try .success(
            projection: projection,
            refreshedAt: OverviewTestProjectionFactory.now
        )
    )

    #expect(model.groups.map(\.category) == ArtifactCategory.allCases)
    #expect(model.rows.count == projection.classifications.count)
    #expect(
        model.groups
            .first { $0.category == .packageAndBuildCaches }?
            .rows.map(\.relativePath.rawValue) == [
                "Library/Caches/build",
            ]
    )
    #expect(
        model.groups
            .first { $0.category == .largeRepositoriesAndHistory }?
            .rows.map(\.relativePath.rawValue) == [
                "Projects/archive/.git",
            ]
    )
}

@Test
func scanModelKeepsRecoveryDispositionAndMissingMeasurementsSeparate()
    throws
{
    let projection = try OverviewTestProjectionFactory.projection(
        slug: "scan-model-gap",
        terminalState: .partial,
        permissionGap: true,
        permissionGapIsReady: true
    )
    let model = ScanModel(
        flowState: .retained(projection),
        pageState: AppPageReducer().loaded(
            projection,
            previous: .empty,
            now: OverviewTestProjectionFactory.now
        )
    )
    let gap = try #require(
        model.rows.first { $0.relativePath.rawValue == "Restricted" }
    )

    #expect(gap.recoveryCost == .low)
    #expect(gap.disposition == .readyToReclaim)
    #expect(gap.allocatedBytes == nil)
    #expect(gap.measurementStatus == .permissionDenied)
    #expect(gap.allocatedDisplay == "—")
    #expect(gap.measurementReasonKey == "scan.measurement.permissionDenied")
}

@Test
func scanModelUsesLedgerOwnerSizeNotDirectoryEntrySize() throws {
    let projection = try OverviewTestProjectionFactory.projection(
        slug: "scan-owner-size"
    )
    let pageState = try AppPageState.success(
        projection: projection,
        refreshedAt: OverviewTestProjectionFactory.now
    )
    let model = ScanModel(
        flowState: .retained(projection),
        pageState: pageState
    )
    let build = try #require(
        model.rows.first {
            $0.relativePath.rawValue == "Library/Caches/build"
        }
    )
    let owner = try #require(
        projection.ledger?.owners.first {
            $0.classificationID == build.classificationID
        }
    )
    let snapshot = try #require(
        projection.snapshots.first { $0.id == build.id }
    )

    #expect(build.allocatedBytes == owner.allocatedBytes)
    #expect(build.allocatedBytes == ByteCount(3_000))
    #expect(build.allocatedBytes == snapshot.allocatedByteCount)

    let active = ScanFlowReducer().started(
        previous: .retained(projection),
        at: OverviewTestProjectionFactory.now
    )
    var progressive = active
    progressive = ScanFlowReducer().reduce(
        .classifiedSnapshotObserved(
            snapshot,
            projection.classifications.first {
                $0.id == build.classificationID
            }!
        ),
        state: progressive
    )
    let progressiveModel = ScanModel(
        flowState: progressive,
        pageState: pageState
    )
    let pending = try #require(progressiveModel.rows.first)

    #expect(pending.allocatedBytes == nil)
    #expect(
        pending.measurementReasonKey
            == "scan.measurement.pendingAccounting"
    )
}

@Test
func scanModelFiltersWithoutChangingUnderlyingRows() throws {
    let projection = try OverviewTestProjectionFactory.projection(
        slug: "scan-filter"
    )
    let pageState = try AppPageState.success(
        projection: projection,
        refreshedAt: OverviewTestProjectionFactory.now
    )
    let all = ScanModel(
        flowState: .retained(projection),
        pageState: pageState
    )
    let ready = ScanModel(
        flowState: .retained(projection),
        pageState: pageState,
        filter: .ready
    )
    let unknownSearch = ScanModel(
        flowState: .retained(projection),
        pageState: pageState,
        query: "mystery",
        filter: .unknown
    )

    #expect(all.rows.count == 6)
    #expect(ready.rows.count == 2)
    #expect(ready.rows.allSatisfy {
        $0.disposition == .readyToReclaim
    })
    #expect(unknownSearch.rows.map(\.relativePath.rawValue) == ["Mystery"])
    #expect(all.summary.readyCount == 2)
    #expect(all.summary.reviewCount == 2)
    #expect(all.summary.unknownCount == 1)
    #expect(all.summary.protectedCount == 1)
}

@Test
func scanModelUsesFullDispositionCountsWithBoundedRows() throws {
    let bounded = try OverviewTestProjectionFactory.projection(
        slug: "scan-full-dispositions"
    )
    let fullCounts = try QuickScanDispositionCounts(
        readyToReclaim: 101,
        reviewRecommended: 202,
        protected: 303,
        unknown: 394
    )
    let rootSnapshot = try #require(
        bounded.snapshots.first { $0.relativePath == "." }
    )
    let rootClassification = try Classification(
        id: ClassificationID(
            rawValue: "classification-scan-full-dispositions-root"
        )!,
        snapshotID: rootSnapshot.id,
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
            rawValue: "catalog-scan-full-dispositions"
        )!,
        classifiedAt: bounded.session.finishedAt
    )
    let projection = try QuickScanProjection(
        session: bounded.session,
        snapshots: bounded.snapshots,
        classifications: bounded.classifications + [rootClassification],
        evidence: bounded.evidence,
        ledger: bounded.ledger,
        issues: bounded.issues,
        corruptRecordIDs: bounded.corruptRecordIDs,
        snapshotCount: 10_000,
        classificationCount: fullCounts.total,
        candidateCount: fullCounts.total - 1,
        evidenceCount: bounded.evidenceCount,
        dispositionCounts: fullCounts
    )
    let model = ScanModel(
        flowState: .retained(projection),
        pageState: try .success(
            projection: projection,
            refreshedAt: OverviewTestProjectionFactory.now
        )
    )

    #expect(model.rows.count == bounded.classifications.count)
    #expect(model.summary.readyCount == 101)
    #expect(model.summary.reviewCount == 202)
    #expect(model.summary.protectedCount == 303)
    #expect(model.summary.unknownCount == 393)
    #expect(
        model.summary.readyCount
            + model.summary.reviewCount
            + model.summary.protectedCount
            + model.summary.unknownCount
            == model.metrics.candidatesFound
    )
}

@Test
func scanInspectorIsReadOnlyAndJoinsEvidenceTruth() throws {
    let projection = try OverviewTestProjectionFactory.projection(
        slug: "scan-inspector"
    )
    let model = ScanModel(
        flowState: .retained(projection),
        pageState: try .success(
            projection: projection,
            refreshedAt: OverviewTestProjectionFactory.now
        )
    )
    let row = try #require(
        model.rows.first {
            $0.relativePath.rawValue == "Library/Caches/build"
        }
    )
    let inspector = try #require(model.inspector(for: row.id))

    #expect(
        inspector.exactPath.rawValue
            == "/tmp/stornaut-scan-inspector/Library/Caches/build"
    )
    #expect(inspector.relativePath.rawValue == "Library/Caches/build")
    #expect(inspector.producer?.rawValue == "Build cache")
    #expect(inspector.category == .packageAndBuildCaches)
    #expect(inspector.disposition == .readyToReclaim)
    #expect(inspector.supportingEvidence.map(\.kind) == [.activity])
    #expect(inspector.missingEvidence.isEmpty)
    #expect(inspector.availableActions == [.close])

    let updater = try #require(
        model.rows.first {
            $0.relativePath.rawValue == "Library/Caches/updater"
        }
    )
    #expect(
        model.inspector(for: updater.id)?.missingEvidence.map(\.rawValue)
            == ["activity.process.inactive"]
    )
}

@Test
func scanModelPresentsHonestProgressAndAllTerminalStates() throws {
    let reducer = ScanFlowReducer()
    let now = OverviewTestProjectionFactory.now
    var active = reducer.started(previous: .idle, at: now)
    active = reducer.reduce(
        .stageChanged(.indexVolumes),
        state: active
    )
    active = reducer.elapsed(
        state: active,
        at: now.addingTimeInterval(9)
    )
    let activeModel = ScanModel(flowState: active, pageState: .empty)

    #expect(activeModel.presentation == .active)
    #expect(activeModel.metrics.scopeScanned == 0)
    #expect(activeModel.metrics.candidatesFound == 0)
    #expect(activeModel.metrics.measuredBytes == ByteCount(0))
    #expect(activeModel.metrics.elapsed == 9)
    #expect(activeModel.primaryAction == .stop)

    for (terminalState, presentation) in [
        (ScanTerminalState.completed, ScanPresentation.completed),
        (.partial, .partial),
        (.cancelled, .cancelled),
        (.failed, .failed),
    ] {
        let projection = try OverviewTestProjectionFactory.projection(
            slug: "scan-presentation-\(terminalState.rawValue)",
            terminalState: terminalState
        )
        let terminal = reducer.reduce(
            .terminal(projection),
            state: active
        )
        let model = ScanModel(
            flowState: terminal,
            pageState: AppPageReducer().loaded(
                projection,
                previous: .empty,
                now: now
            )
        )
        #expect(model.presentation == presentation)
        #expect(model.primaryAction == .start)
    }
}

@Test
func scanLocalizationKeysResolveInBothLanguages() throws {
    let bundle = try #require(Bundle(identifier: "com.eriklee.stornaut"))

    for language in ["en", "zh-Hans"] {
        let path = try #require(
            bundle.path(forResource: language, ofType: "lproj")
        )
        let localized = try #require(Bundle(path: path))

        for key in ScanLocalizationKeys.all {
            #expect(
                localized.localizedString(
                    forKey: key,
                    value: nil,
                    table: nil
                ) != key
            )
        }
    }
}

private enum ScanLocalizationKeys {
    static let all = [
        "scan.title",
        "scan.action.run",
        "scan.action.stop",
        "scan.stop.retainsPartial",
        "scan.metric.scope",
        "scan.metric.candidates",
        "scan.metric.measured",
        "scan.metric.elapsed",
        "scan.stage.indexVolumes",
        "scan.stage.mapProjects",
        "scan.stage.classifyArtifacts",
        "scan.stage.checkActivity",
        "scan.stage.finalizeSnapshot",
        "scan.stage.complete",
        "scan.stage.current",
        "scan.stage.pending",
        "scan.results.item",
        "scan.results.lastActive",
        "scan.results.producer",
        "scan.results.recovery",
        "scan.results.allocated",
        "scan.results.disposition",
        "scan.inspector.title",
        "scan.inspector.exactPath",
        "scan.inspector.supportingEvidence",
        "scan.inspector.missingEvidence",
        "scan.deepDive.implementationUnavailable",
        "scan.review.action",
        "scan.review.action.help",
    ]
}
