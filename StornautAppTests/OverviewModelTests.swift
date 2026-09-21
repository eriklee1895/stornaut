import Foundation
import StornautCore
import Testing
@testable import StornautApp

@Test
func overviewMapsEveryRequiredPresentationWithoutInventingData() throws {
    let projection = try OverviewTestProjectionFactory.projection()
    let now = OverviewTestProjectionFactory.now
    let success = try AppPageState.success(
        projection: projection,
        refreshedAt: now
    )
    let limitedProjection = try OverviewTestProjectionFactory.projection(
        slug: "overview-limited",
        terminalState: .partial,
        permissionGap: true
    )
    let limited = try AppPageState(
        phase: .limitedPermission,
        projection: limitedProjection,
        reasonKey: DomainToken(rawValue: "app.state.permission-limited"),
        recoveryIntent: .reviewPermissions,
        refreshedAt: now
    )
    let stale = AppPageReducer().markStale(
        previous: success,
        reasonKey: DomainToken(rawValue: "app.state.snapshot-stale")!,
        now: now
    )
    let retainedError = AppPageReducer().failed(
        reasonKey: DomainToken(rawValue: "app.state.store-unavailable")!,
        previous: success,
        now: now
    )
    let partialProjection = try OverviewTestProjectionFactory.projection(
        slug: "overview-partial",
        terminalState: .partial
    )
    let cancelledProjection = try OverviewTestProjectionFactory.projection(
        slug: "overview-cancelled",
        terminalState: .cancelled
    )

    #expect(OverviewModel(pageState: .empty).presentation == .empty)
    #expect(
        OverviewModel(
            pageState: AppPageReducer().beginRefresh(previous: .empty)
        ).presentation == .loading
    )
    #expect(OverviewModel(pageState: success).presentation == .current)
    let retainedLoading = OverviewModel(
        pageState: AppPageReducer().beginRefresh(previous: success)
    )
    #expect(retainedLoading.presentation == .loading)
    #expect(retainedLoading.primaryAction == nil)
    #expect(
        OverviewModel(
            pageState: success,
            scanActivity: .active
        ).presentation == .scanInProgress
    )
    #expect(OverviewModel(pageState: limited).presentation == .limitedPermission)
    #expect(OverviewModel(pageState: stale).presentation == .stale)
    #expect(OverviewModel(pageState: retainedError).presentation == .error)
    #expect(
        OverviewModel(
            pageState: AppPageReducer().loaded(
                partialProjection,
                previous: .empty,
                now: now
            )
        ).presentation == .partial
    )
    #expect(
        OverviewModel(
            pageState: AppPageReducer().loaded(
                cancelledProjection,
                previous: .empty,
                now: now
            )
        ).presentation == .cancelled
    )
    #expect(
        OverviewModel(pageState: retainedError).snapshot
            == OverviewModel(pageState: success).snapshot
    )
}

@Test
func overviewKeepsFreeExplainedAndReadyMetricsDistinct() throws {
    let model = try currentOverview()
    let metrics = try #require(model.metrics)

    #expect(metrics.free.bytes == ByteCount(8_000))
    #expect(metrics.explained.bytes == ByteCount(8_000))
    #expect(metrics.readyToReclaim.bytes == ByteCount(5_000))
    #expect(metrics.explained.fraction == 8_000.0 / 12_000.0)
    #expect(metrics.free.bytes != metrics.readyToReclaim.bytes)
}

@Test
func overviewFailsExplainedRatioClosedForInconsistentLedger() throws {
    let projection = try OverviewTestProjectionFactory.projection(
        slug: "overview-inconsistent",
        totalCapacity: 10_000
    )
    let model = OverviewModel(
        pageState: try .success(
            projection: projection,
            refreshedAt: OverviewTestProjectionFactory.now
        )
    )

    #expect(projection.ledger?.status == .inconsistent)
    #expect(model.presentation == .inconsistent)
    #expect(model.metrics?.explained.fraction == nil)
    #expect(model.metrics?.explained.bytes == ByteCount(8_000))
}

@Test
func overviewNeverCollapsesUnknownAndUnmeasurable() throws {
    let projection = try OverviewTestProjectionFactory.projection(
        slug: "overview-gap",
        terminalState: .partial,
        permissionGap: true
    )
    let state = try AppPageState(
        phase: .limitedPermission,
        projection: projection,
        reasonKey: DomainToken(rawValue: "app.state.permission-limited"),
        recoveryIntent: .reviewPermissions,
        refreshedAt: OverviewTestProjectionFactory.now
    )
    let model = OverviewModel(pageState: state)
    let unknown = try #require(
        model.ledgerRows.first { $0.kind == .unknown }
    )
    let unmeasurable = try #require(
        model.ledgerRows.first { $0.kind == .unmeasurable }
    )

    #expect(unknown.bytes == ByteCount(4_000))
    #expect(unmeasurable.bytes == nil)
    #expect(unmeasurable.status == .unmeasurable)
    #expect(unmeasurable.coverageGapCount == 1)
    #expect(unknown.includesUnmeasurable)
    #expect(model.coverage?.state == .limited)
    #expect(
        model.orbitSegments
            .filter { $0.kind == .unknown }
            .map(\.bytes) == [ByteCount(4_000)!]
    )
    #expect(
        model.orbitSegments.filter {
            $0.kind == .unknown
        }.count == 1
    )
}

@Test
func overviewOpportunitiesAreRealStableAndLimitedToThree() throws {
    let model = try currentOverview()

    #expect(model.opportunities.count == 3)
    #expect(model.opportunities.map(\.relativePath.rawValue) == [
        "Library/Caches/build",
        "Projects/App/DerivedData",
        "Library/Caches/updater",
    ])
    #expect(model.opportunities.map(\.allocatedBytes.value) == [
        3_000,
        2_000,
        1_500,
    ])
    #expect(model.opportunities.map(\.disposition) == [
        .readyToReclaim,
        .readyToReclaim,
        .reviewRecommended,
    ])
    #expect(model.opportunities.map(\.activity) == [
        .checked,
        .checked,
        .unavailable,
    ])
    #expect(
        model.opportunities.contains {
            $0.disposition == .protected || $0.disposition == .unknown
        } == false
    )
}

@Test
func overviewRejectsOwnerClassificationConflictsFromMetricsAndOpportunities()
    throws
{
    let projection = try OverviewTestProjectionFactory.projection(
        slug: "overview-conflict"
    )
    var classifications = projection.classifications
    let readyIndex = try #require(
        classifications.firstIndex {
            $0.disposition == .readyToReclaim
        }
    )
    let ready = classifications[readyIndex]
    classifications[readyIndex] = try Classification(
        id: ready.id,
        snapshotID: ready.snapshotID,
        ruleID: ready.ruleID,
        producer: ready.producer,
        category: ready.category,
        disposition: .reviewRecommended,
        risk: ready.risk,
        confidence: ready.confidence,
        recovery: ready.recovery,
        requiredEvidenceKeys: ready.requiredEvidenceKeys,
        missingEvidenceKeys: ready.missingEvidenceKeys,
        catalogVersion: ready.catalogVersion,
        classifiedAt: ready.classifiedAt
    )
    let conflicted = try QuickScanProjection(
        session: projection.session,
        snapshots: projection.snapshots,
        classifications: classifications,
        evidence: projection.evidence,
        ledger: projection.ledger,
        issues: projection.issues,
        corruptRecordIDs: projection.corruptRecordIDs
    )
    let model = OverviewModel(
        pageState: try .success(
            projection: conflicted,
            refreshedAt: OverviewTestProjectionFactory.now
        )
    )

    #expect(model.metrics?.readyToReclaim.bytes == nil)
    #expect(
        model.opportunities.contains {
            $0.classificationID == ready.id
        } == false
    )
}

@Test
func overviewNeverTurnsUnmeasuredReadyOwnerIntoZero() throws {
    let projection = try OverviewTestProjectionFactory.projection(
        slug: "overview-ready-gap",
        terminalState: .partial,
        permissionGap: true,
        permissionGapIsReady: true
    )
    let state = try AppPageState(
        phase: .limitedPermission,
        projection: projection,
        reasonKey: DomainToken(rawValue: "app.state.permission-limited"),
        recoveryIntent: .reviewPermissions,
        refreshedAt: OverviewTestProjectionFactory.now
    )
    let model = OverviewModel(pageState: state)

    #expect(
        projection.ledger?.owners.contains {
            $0.disposition == .readyToReclaim
                && $0.allocatedBytes == nil
        } == true
    )
    #expect(model.metrics?.readyToReclaim.bytes == nil)
}

@Test
func overviewActivityBadgeRejectsStaleAndProviderFailureEvidence()
    throws
{
    for (slug, freshness, summary) in [
        (
            "overview-stale-activity",
            EvidenceFreshness.stale,
            "activity.process.inactive"
        ),
        (
            "overview-failed-activity",
            EvidenceFreshness.current,
            "quick-scan.activity.provider-failure"
        ),
    ] {
        let projection = try OverviewTestProjectionFactory.projection(
            slug: slug,
            firstEvidenceFreshness: freshness,
            firstEvidenceSummary: summary
        )
        let model = OverviewModel(
            pageState: try .success(
                projection: projection,
                refreshedAt: OverviewTestProjectionFactory.now
            )
        )
        let firstReady = try #require(
            model.opportunities.first {
                $0.relativePath.rawValue == "Library/Caches/build"
            }
        )

        #expect(
            firstReady.activity == (
                summary == "quick-scan.activity.provider-failure"
                    ? .unavailable
                    : .unknown
            )
        )
    }
}

@Test
func overviewLedgerCarriesExactSourceTimeAndCoverageMetadata() throws {
    let model = try currentOverview()
    let free = try #require(
        model.ledgerRows.first { $0.kind == .free }
    )

    #expect(free.status == .measured)
    #expect(free.sources.map(\.kind) == [.volumeResourceValues])
    #expect(free.sources.map(\.identifier.rawValue) == ["fixture-volume"])
    #expect(free.sources.map(\.sampledAt) == [OverviewTestProjectionFactory.now])
    #expect(free.coverageGapCount == 0)
    #expect(model.snapshot?.sampledAt == OverviewTestProjectionFactory.now)
    #expect(model.snapshot?.scopePath.rawValue == "/tmp/stornaut-overview")
    #expect(model.coverage?.state == .complete)
}

@Test
func overviewActionsStayInsideTaskTwentyTwoSafetyBoundary() throws {
    let current = try currentOverview()
    let loading = OverviewModel(
        pageState: AppPageReducer().beginRefresh(previous: .empty)
    )
    let activeScan = OverviewModel(
        pageState: .empty,
        scanActivity: .active
    )
    let error = OverviewModel(
        pageState: AppPageReducer().failed(
            reasonKey: DomainToken(rawValue: "app.state.store-unavailable")!,
            previous: .empty,
            now: OverviewTestProjectionFactory.now
        )
    )

    #expect(OverviewModel(pageState: .empty).primaryAction == .openScan)
    #expect(current.primaryAction == .openScan)
    #expect(loading.primaryAction == nil)
    #expect(activeScan.primaryAction == .openScan)
    #expect(error.primaryAction == .retryLatestSnapshot)
    #expect(current.deepDive == .implementationUnavailable)
}

@Test
func overviewLocalizationKeysResolveInBothLanguages() throws {
    let bundle = try #require(Bundle(identifier: "com.eriklee.stornaut"))

    for language in ["en", "zh-Hans"] {
        let path = try #require(
            bundle.path(forResource: language, ofType: "lproj")
        )
        let localized = try #require(Bundle(path: path))

        for key in OverviewLocalizationKeys.all {
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

private func currentOverview() throws -> OverviewModel {
    let projection = try OverviewTestProjectionFactory.projection()
    return OverviewModel(
        pageState: try .success(
            projection: projection,
            refreshedAt: OverviewTestProjectionFactory.now
        )
    )
}

private enum OverviewLocalizationKeys {
    static let all = [
        "overview.title",
        "overview.metric.free",
        "overview.metric.explained",
        "overview.metric.ready",
        "overview.ledger.title",
        "overview.ledger.known",
        "overview.ledger.unknown",
        "overview.ledger.unmeasurable",
        "overview.ledger.free",
        "overview.action.quickScan",
        "overview.deepDive.title",
        "overview.deepDive.implementationUnavailable",
        "overview.opportunities.title",
        "overview.activity.checked",
        "overview.activity.unavailable",
        "overview.activity.unknown",
    ]
}
