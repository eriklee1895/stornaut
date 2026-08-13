import Foundation
import StornautCore
import Testing
@testable import StornautApp

@Test
func reviewWorkspaceRouteStaysUnderScanAndReservesCleanupResult() {
    #expect(ScanWorkspaceRoute.allCases == [
        .results,
        .review,
        .cleanupResult,
    ])
    #expect(
        ReviewRouteReducer().openReview(from: .results) == .review
    )
    #expect(
        ReviewRouteReducer().closeReview(from: .review) == .results
    )
    #expect(
        ReviewRouteReducer().openCleanupResult(from: .review)
            == .review
    )
    #expect(!AppDestination.allCases.map(\.rawValue).contains("review"))
}

@Test
func reviewSnapshotDefaultsOnlyExecutableReadyItems() throws {
    let fixture = try ReviewAppFixture()

    let snapshot = try ReviewSnapshot(
        plan: fixture.plan,
        projection: fixture.projection,
        generation: 1,
        executionAvailability: .writeDisabled
    )

    #expect(snapshot.selectedItemIDs == [fixture.readyItem.id])
    #expect(snapshot.selectedCount == 1)
    #expect(snapshot.selectedAllocatedBytes == fixture.readyItem.allocatedBytes)
    #expect(snapshot.selectedReviewCount == 0)
    #expect(snapshot.focusedClassificationID == nil)
    #expect(snapshot.reviewSelection?.items == [
        ReviewSelectionItem(
            itemID: fixture.readyItem.id,
            origin: .defaultReady
        ),
    ])
    #expect(!snapshot.canExecute)
}

@Test
func reviewSelectionRequiresExplicitReviewAndKeepsFocusIndependent()
    throws
{
    let fixture = try ReviewAppFixture()
    let initial = try ReviewSnapshot(
        plan: fixture.plan,
        projection: fixture.projection,
        generation: 7,
        executionAvailability: .debugFake
    )

    let focused = initial.focusing(fixture.reviewRow.classificationID)
    #expect(focused.selectedItemIDs == initial.selectedItemIDs)
    #expect(
        focused.focusedClassificationID
            == fixture.reviewRow.classificationID
    )

    let selected = try focused.settingSelection(
        classificationID: fixture.reviewRow.classificationID,
        isSelected: true
    )
    #expect(selected.generation == 8)
    #expect(selected.selectedItemIDs == [
        fixture.readyItem.id,
        fixture.reviewItem.id,
    ])
    #expect(selected.selectedReviewCount == 1)
    #expect(selected.reviewSelection?.items == [
        ReviewSelectionItem(
            itemID: fixture.readyItem.id,
            origin: .defaultReady
        ),
        ReviewSelectionItem(
            itemID: fixture.reviewItem.id,
            origin: .explicitUser
        ),
    ])
    #expect(selected.canExecute)
}

@Test
func reviewSnapshotRejectsDisabledRowsAndAllowsEmptyUISelection()
    throws
{
    let fixture = try ReviewAppFixture()
    let initial = try ReviewSnapshot(
        plan: fixture.plan,
        projection: fixture.projection,
        generation: 3,
        executionAvailability: .debugFake
    )

    #expect(throws: ReviewAppContractError.nonSelectableRow) {
        _ = try initial.settingSelection(
            classificationID: fixture.noProfileRow.classificationID,
            isSelected: true
        )
    }
    #expect(throws: ReviewAppContractError.nonSelectableRow) {
        _ = try initial.settingSelection(
            classificationID: fixture.protectedRow.classificationID,
            isSelected: true
        )
    }

    let empty = try initial.settingSelection(
        classificationID: fixture.readyRow.classificationID,
        isSelected: false
    )
    #expect(empty.selectedItemIDs.isEmpty)
    #expect(empty.reviewSelection == nil)
    #expect(empty.selectedAllocatedBytes == ByteCount(0))
    #expect(!empty.canPreflight)
    #expect(!empty.canExecute)
}

@Test
func reviewSnapshotRejectsSelectedByteOverflowInsteadOfReportingZero()
    throws
{
    let first = try reviewPlanItem(
        slug: "max-a",
        path: "Library/Caches/max-a",
        identity: reviewIdentity(
            inode: 201,
            bytes: Int64.max
        )
    )
    let second = try reviewPlanItem(
        slug: "max-b",
        path: "Library/Caches/max-b",
        identity: reviewIdentity(
            inode: 202,
            bytes: Int64.max
        )
    )
    let plan = try CleanupPlan(
        id: CleanupPlanID(rawValue: "plan-review-overflow")!,
        scanSessionID: ScanSessionID(
            rawValue: "scan-review-overflow"
        )!,
        scanScopeID: ScanScopeID(
            rawValue: "scope-review-overflow"
        )!,
        primaryRootIdentity: reviewIdentity(inode: 200, bytes: 0),
        catalogVersion: DomainToken(
            rawValue: "catalog-review-overflow"
        )!,
        executionProfileVersion: DomainToken(
            rawValue: "profiles-review-overflow"
        )!,
        planFingerprint: DomainToken(
            rawValue: "plan.review-overflow.fingerprint"
        )!,
        createdAt: Date(timeIntervalSince1970: 1_786_320_000),
        expiresAt: Date(timeIntervalSince1970: 1_786_320_600),
        items: [first, second]
    )
    let rows = [first, second].map {
        reviewProjectionRow(
            item: $0,
            disposition: .readyToReclaim,
            eligibility: .executable,
            suggestedDefault: true
        )
    }
    let projection = try ReviewProjection(
        sessionID: plan.scanSessionID,
        planID: plan.id,
        rows: rows,
        totalRowCount: rows.count,
        counts: ReviewProjectionCounts(
            executableReady: 2,
            executableReview: 0,
            noExecutionProfile: 0,
            persistedDispositionBlocked: 0,
            currentEvidenceBlocked: 0
        )
    )

    #expect(throws: ReviewAppContractError.byteOverflow) {
        _ = try ReviewSnapshot(
            plan: plan,
            projection: projection,
            generation: 1,
            executionAvailability: .debugFake
        )
    }
}

@Test
func reviewReducerMapsCoreBuildAndPolicyOutcomesWithoutAuthority()
    throws
{
    let fixture = try ReviewAppFixture()
    let reducer = ReviewReducer()
    let loading = reducer.beginLoading(previous: .idle)
    let ready = reducer.loaded(
        .planReady(fixture.plan, fixture.projection),
        previous: loading,
        executionAvailability: .writeDisabled
    )
    let snapshot = try #require(ready.snapshot)
    let selection = try #require(snapshot.reviewSelection)
    let preflighting = reducer.beginPreflight(state: ready)
    let blockedEvaluation = try ReviewConfirmationFixture.evaluate(
        plan: fixture.plan,
        selection: selection,
        activityFacts: .active
    )
    let blocked = try #require(blockedEvaluation.blocked)
    let stale = blocked.stale

    #expect(preflighting.phase == .preflighting)
    #expect(
        reducer.preflightCompleted(
            blockedEvaluation,
            state: preflighting
        ) == .stale(snapshot, stale)
    )

    let allowedEvaluation = try ReviewConfirmationFixture.evaluate(
        plan: fixture.plan,
        selection: selection,
        activityFacts: .inactive
    )
    let confirmation = try #require(
        allowedEvaluation.allowed?.confirmation
    )
    #expect(
        reducer.preflightCompleted(
            allowedEvaluation,
            state: preflighting
        ) == .confirming(snapshot, confirmation)
    )
    let mismatchedSelection = try ReviewSelection(
        plan: fixture.plan,
        generation: selection.generation &+ 1,
        items: selection.items,
        dispositions: [
            fixture.readyItem.id: .readyToReclaim,
            fixture.reviewItem.id: .reviewRecommended,
        ]
    )
    let mismatchedEvaluation = try ReviewConfirmationFixture.evaluate(
        plan: fixture.plan,
        selection: mismatchedSelection,
        activityFacts: .inactive
    )
    #expect(
        reducer.preflightCompleted(
            mismatchedEvaluation,
            state: preflighting
        ) == .unavailable([
            DomainToken(
                rawValue: "review.unavailable.invalid-confirmation"
            )!,
        ])
    )
    #expect(
        reducer.confirmExecution(
            state: .confirming(snapshot, confirmation)
        ) == .executionBlocked(
            snapshot,
            .writeDisabled
        )
    )
}

struct ReviewAppFixture {
    let readyItem: CleanupPlanItem
    let reviewItem: CleanupPlanItem
    let readyRow: ReviewProjectionRow
    let reviewRow: ReviewProjectionRow
    let noProfileRow: ReviewProjectionRow
    let protectedRow: ReviewProjectionRow
    let unknownRow: ReviewProjectionRow
    let plan: CleanupPlan
    let projection: ReviewProjection

    init() throws {
        let readyIdentity = try reviewIdentity(inode: 101, bytes: 4_096)
        let reviewItemIdentity = try reviewIdentity(
            inode: 102,
            bytes: 8_192
        )
        readyItem = try reviewPlanItem(
            slug: "ready",
            path: "Library/Caches/npm",
            identity: readyIdentity
        )
        reviewItem = try reviewPlanItem(
            slug: "review",
            path: "Library/Caches/go-build",
            identity: reviewItemIdentity
        )
        plan = try CleanupPlan(
            id: CleanupPlanID(rawValue: "plan-review-app")!,
            scanSessionID: ScanSessionID(
                rawValue: "scan-review-app"
            )!,
            scanScopeID: ScanScopeID(rawValue: "scope-review-app")!,
            primaryRootIdentity: try reviewIdentity(
                inode: 100,
                bytes: 0
            ),
            catalogVersion: DomainToken(
                rawValue: "catalog-review-app"
            )!,
            executionProfileVersion: DomainToken(
                rawValue: "profiles-review-app"
            )!,
            planFingerprint: DomainToken(
                rawValue: "plan.review-app.fingerprint"
            )!,
            createdAt: Date(timeIntervalSince1970: 1_786_320_000),
            expiresAt: Date(timeIntervalSince1970: 1_786_320_600),
            items: [readyItem, reviewItem]
        )
        readyRow = reviewProjectionRow(
            item: readyItem,
            disposition: .readyToReclaim,
            eligibility: .executable,
            suggestedDefault: true
        )
        reviewRow = reviewProjectionRow(
            item: reviewItem,
            disposition: .reviewRecommended,
            eligibility: .executable,
            suggestedDefault: false
        )
        noProfileRow = ReviewProjectionRow(
            snapshotID: SnapshotID(rawValue: "snapshot-review-uv")!,
            classificationID: ClassificationID(
                rawValue: "classification-review-uv"
            )!,
            relativePath: "Library/Caches/uv",
            ruleID: DomainToken(rawValue: "cache.uv")!,
            persistedDisposition: .reviewRecommended,
            currentDisposition: .reviewRecommended,
            eligibility: .noExecutionProfile,
            suggestedDefault: false,
            reasonKeys: [
                DomainToken(
                    rawValue: "review.non-executable.no-profile"
                )!,
            ]
        )
        protectedRow = ReviewProjectionRow(
            snapshotID: SnapshotID(
                rawValue: "snapshot-review-protected"
            )!,
            classificationID: ClassificationID(
                rawValue: "classification-review-protected"
            )!,
            relativePath: ".ssh",
            ruleID: nil,
            persistedDisposition: .protected,
            currentDisposition: .protected,
            eligibility: .persistedDispositionBlocked,
            suggestedDefault: false,
            reasonKeys: [
                DomainToken(
                    rawValue: "review.non-executable.persisted-disposition"
                )!,
            ]
        )
        unknownRow = ReviewProjectionRow(
            snapshotID: SnapshotID(
                rawValue: "snapshot-review-unknown"
            )!,
            classificationID: ClassificationID(
                rawValue: "classification-review-unknown"
            )!,
            relativePath: "Library/Caches/unknown-tool",
            ruleID: nil,
            persistedDisposition: .unknown,
            currentDisposition: .unknown,
            eligibility: .persistedDispositionBlocked,
            suggestedDefault: false,
            reasonKeys: [
                DomainToken(
                    rawValue: "review.non-executable.persisted-disposition"
                )!,
            ]
        )
        projection = try ReviewProjection(
            sessionID: plan.scanSessionID,
            planID: plan.id,
            rows: [
                protectedRow,
                readyRow,
                reviewRow,
                noProfileRow,
                unknownRow,
            ].sorted {
                $0.relativePath < $1.relativePath
            },
            totalRowCount: 5,
            counts: ReviewProjectionCounts(
                executableReady: 1,
                executableReview: 1,
                noExecutionProfile: 1,
                persistedDispositionBlocked: 2,
                currentEvidenceBlocked: 0
            )
        )
    }
}

enum ReviewConfirmationFixture {
    static func evaluate(
        plan: CleanupPlan,
        selection: ReviewSelection,
        activityFacts: CleanupActivityPolicyFacts
    ) throws -> CleanupPolicyEvaluation {
        let context = try CleanupPolicyContext(
            capturedAt: plan.createdAt,
            planID: plan.id,
            scanSessionID: plan.scanSessionID,
            scanScopeID: plan.scanScopeID!,
            scanIsTerminal: true,
            planFingerprint: plan.planFingerprint!,
            selectionGeneration: selection.generation,
            selectionFingerprint: selection.fingerprint,
            rootIdentity: plan.primaryRootIdentity,
            catalogVersion: plan.catalogVersion,
            executionProfileVersion: plan.executionProfileVersion,
            workflow: .available,
            items: try selection.items.map { selected in
                let item = plan.items.first {
                    $0.id == selected.itemID
                }!
                return try CleanupPolicyItemContext(
                    itemID: item.id,
                    snapshotID: item.snapshotID,
                    classificationID: item.classificationID,
                    ruleID: item.ruleID!,
                    executionProfileID: item.executionProfileID!,
                    proposedAction: item.proposedAction,
                    persistedDisposition:
                        selected.origin == .defaultReady
                            ? .readyToReclaim
                            : .reviewRecommended,
                    currentDisposition:
                        selected.origin == .defaultReady
                            ? .readyToReclaim
                            : .reviewRecommended,
                    expectedRelativePath: item.expectedRelativePath!,
                    currentRelativePath: item.expectedRelativePath!,
                    expectedIdentity: item.expectedIdentity!,
                    currentIdentity: item.expectedIdentity,
                    evidenceFingerprint: item.evidenceFingerprint!,
                    currentEvidenceFingerprint: item.evidenceFingerprint!,
                    activityFingerprint: item.activityFingerprint!,
                    currentActivityFingerprint: item.activityFingerprint!,
                    pathFacts: .allowed,
                    evidenceFacts: .current,
                    activityFacts: activityFacts
                )
            }
        )
        return try CleanupPolicyGate().evaluate(
            plan: plan,
            selection: selection,
            context: context,
            evaluatedAt: plan.createdAt
        )
    }
}

private func reviewProjectionRow(
    item: CleanupPlanItem,
    disposition: ReclaimDisposition,
    eligibility: ReviewEligibility,
    suggestedDefault: Bool
) -> ReviewProjectionRow {
    ReviewProjectionRow(
        snapshotID: item.snapshotID,
        classificationID: item.classificationID,
        relativePath: item.expectedRelativePath!.rawValue,
        ruleID: item.ruleID,
        persistedDisposition: disposition,
        currentDisposition: disposition,
        eligibility: eligibility,
        suggestedDefault: suggestedDefault,
        reasonKeys: [DomainToken(rawValue: "review.current.executable")!]
    )
}

private func reviewPlanItem(
    slug: String,
    path: String,
    identity: FileIdentity
) throws -> CleanupPlanItem {
    try CleanupPlanItem(
        id: CleanupPlanItemID(rawValue: "plan-item-review-\(slug)")!,
        snapshotID: SnapshotID(rawValue: "snapshot-review-\(slug)")!,
        classificationID: ClassificationID(
            rawValue: "classification-review-\(slug)"
        )!,
        ruleID: DomainToken(rawValue: "rule.review-\(slug)")!,
        executionProfileID: DomainToken(
            rawValue: "profile.review-\(slug)"
        )!,
        proposedAction: .moveToTrash,
        expectedRelativePath: PersistedPath(rawValue: path)!,
        expectedIdentity: identity,
        logicalBytes: ByteCount(exactly: identity.size)!,
        allocatedBytes: ByteCount(exactly: identity.allocatedBytes)!,
        evidenceFingerprint: DomainToken(
            rawValue: "evidence.review-\(slug)"
        )!,
        activityFingerprint: DomainToken(
            rawValue: "activity.review-\(slug)"
        )!
    )
}

private func reviewIdentity(
    inode: UInt64,
    bytes: Int64
) throws -> FileIdentity {
    try FileIdentity(
        device: 1,
        inode: inode,
        mode: UInt16(S_IFDIR | 0o755),
        ownerUserID: 501,
        ownerGroupID: 20,
        linkCount: 1,
        size: bytes,
        allocatedBytes: bytes,
        modificationSeconds: 1_786_320_000,
        modificationNanoseconds: 0
    )
}
