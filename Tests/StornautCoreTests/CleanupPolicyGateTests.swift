import Foundation
import Testing
@testable import StornautCore

@Test
func reviewSelectionOrdersByPlanAndRejectsInvalidOriginsAndCounts() throws {
    let fixture = try CleanupPolicyTestFixture()
    let selection = try ReviewSelection(
        plan: fixture.plan,
        generation: 7,
        items: [
            ReviewSelectionItem(
                itemID: fixture.reviewItem.id,
                origin: .explicitUser
            ),
            ReviewSelectionItem(
                itemID: fixture.readyItem.id,
                origin: .defaultReady
            ),
        ],
        dispositions: fixture.dispositions
    )

    #expect(selection.planID == fixture.plan.id)
    #expect(selection.generation == 7)
    #expect(selection.items.map(\.itemID) == fixture.plan.items.map(\.id))
    #expect(selection.fingerprint.rawValue.hasPrefix("selection."))

    #expect(throws: ReviewSelectionError.reviewRequiresExplicitSelection) {
        _ = try ReviewSelection(
            plan: fixture.plan,
            generation: 8,
            items: [
                ReviewSelectionItem(
                    itemID: fixture.reviewItem.id,
                    origin: .defaultReady
                ),
            ],
            dispositions: fixture.dispositions
        )
    }
    #expect(throws: ReviewSelectionError.duplicateItem) {
        _ = try ReviewSelection(
            plan: fixture.plan,
            generation: 8,
            items: [
                ReviewSelectionItem(
                    itemID: fixture.readyItem.id,
                    origin: .defaultReady
                ),
                ReviewSelectionItem(
                    itemID: fixture.readyItem.id,
                    origin: .explicitUser
                ),
            ],
            dispositions: fixture.dispositions
        )
    }
    #expect(throws: ReviewSelectionError.unknownItem) {
        _ = try ReviewSelection(
            plan: fixture.plan,
            generation: 8,
            items: [
                ReviewSelectionItem(
                    itemID: CleanupPlanItemID(
                        rawValue: "plan-item-unknown"
                    )!,
                    origin: .explicitUser
                ),
            ],
            dispositions: fixture.dispositions
        )
    }
    #expect(throws: ReviewSelectionError.emptySelection) {
        _ = try ReviewSelection(
            plan: fixture.plan,
            generation: 8,
            items: [],
            dispositions: fixture.dispositions
        )
    }
    #expect(throws: ReviewSelectionError.nonExecutableDisposition) {
        _ = try ReviewSelection(
            plan: fixture.plan,
            generation: 8,
            items: [
                ReviewSelectionItem(
                    itemID: fixture.readyItem.id,
                    origin: .explicitUser
                ),
            ],
            dispositions: [
                fixture.readyItem.id: .protected,
                fixture.reviewItem.id: .reviewRecommended,
            ]
        )
    }
    #expect(throws: ReviewSelectionError.nonExecutableDisposition) {
        _ = try ReviewSelection(
            plan: fixture.plan,
            generation: 8,
            items: [
                ReviewSelectionItem(
                    itemID: fixture.readyItem.id,
                    origin: .explicitUser
                ),
            ],
            dispositions: [
                fixture.readyItem.id: .unknown,
                fixture.reviewItem.id: .reviewRecommended,
            ]
        )
    }
}

@Test
func cleanupPolicyGateAllowsReadyAndExplicitReviewWithStableDecisions() throws {
    let fixture = try CleanupPolicyTestFixture()
    let selection = try fixture.selection()
    let context = try fixture.context()
    let gate = CleanupPolicyGate()

    let first = try gate.evaluate(
        plan: fixture.plan,
        selection: selection,
        context: context,
        evaluatedAt: fixture.now
    )
    let second = try gate.evaluate(
        plan: fixture.plan,
        selection: selection,
        context: context,
        evaluatedAt: fixture.now
    )
    let allowed = try #require(first.allowed)

    #expect(allowed.decisions.map(\.outcome) == [.allowed, .allowed])
    #expect(allowed.decisions.map(\.selectionOrigin) == [
        .defaultReady,
        .explicitUser,
    ])
    #expect(allowed.confirmation.itemCount == 2)
    #expect(allowed.confirmation.reviewItemCount == 1)
    #expect(allowed.confirmation.logicalBytes == ByteCount(30))
    #expect(allowed.confirmation.allocatedBytes == ByteCount(48))
    #expect(allowed.confirmation == second.allowed?.confirmation)
    #expect(
        allowed.decisions.map(\.decisionFingerprint)
            == second.allowed?.decisions.map(\.decisionFingerprint)
    )
}

@Test
func cleanupPolicyGateBlocksExpiredPlanAndFreshContextDrift() throws {
    let fixture = try CleanupPolicyTestFixture()
    let selection = try fixture.selection()
    let gate = CleanupPolicyGate()
    let context = try fixture.context(
        itemMutations: [
            fixture.readyItem.id: { item in
                item.with(
                    currentIdentity: try fixture.identity(
                        inode: 100,
                        size: 11,
                        allocatedBytes: 16
                    )
                )
            },
        ]
    )

    let evaluation = try gate.evaluate(
        plan: fixture.plan,
        selection: selection,
        context: context,
        evaluatedAt: fixture.plan.expiresAt.addingTimeInterval(1)
    )
    let blocked = try #require(evaluation.blocked)

    #expect(blocked.decisions.allSatisfy { $0.outcome == .denied })
    #expect(blocked.stale.affectedItemIDs == Set(fixture.plan.items.map(\.id)))
    #expect(blocked.stale.reasonGroups.contains(.plan))
    #expect(blocked.stale.reasonGroups.contains(.identity))
    #expect(blocked.stale.availableActions == [.refreshAffectedItems, .cancel])
    #expect(
        blocked.decisions.flatMap(\.reasonKeys).map(\.rawValue).contains(
            "policy.plan.expired"
        )
    )
    #expect(
        blocked.decisions.flatMap(\.reasonKeys).map(\.rawValue).contains(
            "policy.identity.changed"
        )
    )
}

@Test
func cleanupPolicyGateBlocksActivityEvidenceCatalogPathAndWorkflowFailures()
    throws
{
    let fixture = try CleanupPolicyTestFixture()
    let selection = try fixture.selection()
    let gate = CleanupPolicyGate()
    let context = try fixture.context(
        catalogVersion: DomainToken(rawValue: "catalog.changed")!,
        workflow: CleanupWorkflowAvailabilitySnapshot(
            rootLeaseAvailable: true,
            activeConflicts: [.quickScan]
        ),
        itemMutations: [
            fixture.readyItem.id: { item in
                item.with(
                    pathFacts: CleanupPathPolicyFacts(
                        isRoot: false,
                        isHome: false,
                        isMountRoot: false,
                        isSymbolicLink: true,
                        isSensitive: false,
                        isInsideRoot: true,
                        ownerMatches: true,
                        volumeMatches: true
                    ),
                    evidenceFacts: .missing,
                    activityFacts: .active
                )
            },
            fixture.reviewItem.id: { item in
                item.with(
                    evidenceFacts: .expired,
                    activityFacts: .unavailable
                )
            },
        ]
    )

    let evaluation = try gate.evaluate(
        plan: fixture.plan,
        selection: selection,
        context: context,
        evaluatedAt: fixture.now
    )
    let blocked = try #require(evaluation.blocked)
    let reasons = Set(
        blocked.decisions.flatMap(\.reasonKeys).map(\.rawValue)
    )

    #expect(reasons.contains("policy.catalog.changed"))
    #expect(reasons.contains("policy.workflow.quick-scan-active"))
    #expect(reasons.contains("policy.path.symbolic-link"))
    #expect(reasons.contains("policy.evidence.missing"))
    #expect(reasons.contains("policy.evidence.expired"))
    #expect(reasons.contains("policy.activity.active"))
    #expect(reasons.contains("policy.activity.unavailable"))
    #expect(blocked.stale.reasonGroups == Set([
        .activity,
        .catalog,
        .evidence,
        .path,
        .workflow,
    ]))
}

@Test
func cleanupPolicyGateRejectsContextOlderThanAdmissionWindow() throws {
    let fixture = try CleanupPolicyTestFixture()
    let selection = try fixture.selection()
    let gate = CleanupPolicyGate()
    let context = try fixture.context(
        capturedAt: fixture.now.addingTimeInterval(-31)
    )

    let evaluation = try gate.evaluate(
        plan: fixture.plan,
        selection: selection,
        context: context,
        evaluatedAt: fixture.now
    )
    let blocked = try #require(evaluation.blocked)

    #expect(blocked.decisions.allSatisfy { $0.outcome == .denied })
    #expect(
        blocked.decisions.flatMap(\.reasonKeys).map(\.rawValue).contains(
            "policy.context.expired"
        )
    )
}

@Test
func cleanupPolicyGateRejectsASelectionGenerationChangedAfterCollection()
    throws
{
    let fixture = try CleanupPolicyTestFixture()
    let staleSelection = try fixture.selection(generation: 8)
    let context = try fixture.context()

    let evaluation = try CleanupPolicyGate().evaluate(
        plan: fixture.plan,
        selection: staleSelection,
        context: context,
        evaluatedAt: fixture.now
    )
    let blocked = try #require(evaluation.blocked)

    #expect(blocked.decisions.allSatisfy { $0.outcome == .denied })
    #expect(
        blocked.decisions.flatMap(\.reasonKeys).map(\.rawValue).contains(
            "policy.selection.generation-changed"
        )
    )
    #expect(blocked.stale.reasonGroups.contains(.selection))
}

@Test
func cleanupPolicyDecisionsUseDistinctAuditIdentityAcrossEvaluations() throws {
    let fixture = try CleanupPolicyTestFixture()
    let selection = try fixture.selection()
    let context = try fixture.context()
    let gate = CleanupPolicyGate()

    let first = try #require(
        try gate.evaluate(
            plan: fixture.plan,
            selection: selection,
            context: context,
            evaluatedAt: fixture.now
        ).allowed
    )
    let second = try #require(
        try gate.evaluate(
            plan: fixture.plan,
            selection: selection,
            context: context,
            evaluatedAt: fixture.now.addingTimeInterval(1)
        ).allowed
    )

    #expect(first.decisions.map(\.id) != second.decisions.map(\.id))
    #expect(
        first.decisions.map(\.decisionFingerprint)
            != second.decisions.map(\.decisionFingerprint)
    )
}

@Test
func cleanupPlanAndSelectionRejectOverOneHundredOrRegisteredActions() throws {
    let fixture = try CleanupPolicyTestFixture()
    var items: [CleanupPlanItem] = []
    for index in 0...100 {
        items.append(
            try CleanupPolicyTestFixture.makeItem(
                slug: "bulk-\(index)",
                relativePath: "Library/Caches/bulk-\(index)",
                inode: UInt64(1_000 + index),
                size: 1,
                allocatedBytes: 1
            )
        )
    }
    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try CleanupPlan(
            id: CleanupPlanID(rawValue: "plan-over-limit")!,
            scanSessionID: fixture.plan.scanSessionID,
            scanScopeID: fixture.plan.scanScopeID!,
            primaryRootIdentity: fixture.rootIdentity,
            catalogVersion: fixture.plan.catalogVersion!,
            executionProfileVersion:
                fixture.plan.executionProfileVersion!,
            planFingerprint: DomainToken(
                rawValue: "plan.over-limit.fingerprint"
            )!,
            createdAt: fixture.plan.createdAt,
            expiresAt: fixture.plan.expiresAt,
            items: items
        )
    }
    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try CleanupPlanItem(
            id: CleanupPlanItemID(rawValue: "plan-item-registered")!,
            snapshotID: SnapshotID(rawValue: "snapshot-registered")!,
            classificationID: ClassificationID(
                rawValue: "classification-registered"
            )!,
            ruleID: DomainToken(rawValue: "rule-registered")!,
            executionProfileID: DomainToken(
                rawValue: "profile-registered"
            )!,
            proposedAction: .registeredAction(
                id: DomainToken(rawValue: "action-registered")!
            ),
            expectedRelativePath: PersistedPath(
                rawValue: "Library/Caches/registered"
            )!,
            expectedIdentity: try fixture.identity(
                inode: 2_000,
                size: 1,
                allocatedBytes: 1
            ),
            logicalBytes: ByteCount(1)!,
            allocatedBytes: ByteCount(1)!,
            evidenceFingerprint: DomainToken(
                rawValue: "evidence.registered.fingerprint"
            )!,
            activityFingerprint: DomainToken(
                rawValue: "activity.registered.fingerprint"
            )!
        )
    }
}

private struct CleanupPolicyTestFixture {
    let now = Date(timeIntervalSince1970: 1_786_640_000)
    let rootIdentity: FileIdentity
    let readyItem: CleanupPlanItem
    let reviewItem: CleanupPlanItem
    let plan: CleanupPlan
    let dispositions: [CleanupPlanItemID: ReclaimDisposition]

    init() throws {
        rootIdentity = try Self.makeIdentity(
            inode: 1,
            size: 4_096,
            allocatedBytes: 8_192
        )
        readyItem = try Self.makeItem(
            slug: "ready",
            relativePath: ".npm/_cacache",
            inode: 10,
            size: 10,
            allocatedBytes: 16
        )
        reviewItem = try Self.makeItem(
            slug: "review",
            relativePath: "Library/Caches/go-build",
            inode: 20,
            size: 20,
            allocatedBytes: 32
        )
        plan = try CleanupPlan(
            id: CleanupPlanID(rawValue: "plan-task30")!,
            scanSessionID: ScanSessionID(rawValue: "scan-task30")!,
            scanScopeID: ScanScopeID(rawValue: "scope-task30")!,
            primaryRootIdentity: rootIdentity,
            catalogVersion: DomainToken(
                rawValue: "builtin-runtime-tool-residue-v2"
            )!,
            executionProfileVersion: DomainToken(
                rawValue: "safe-execution-v1"
            )!,
            planFingerprint: DomainToken(
                rawValue: "plan.task30.fingerprint"
            )!,
            createdAt: now.addingTimeInterval(-60),
            expiresAt: now.addingTimeInterval(60),
            items: [readyItem, reviewItem]
        )
        dispositions = [
            readyItem.id: .readyToReclaim,
            reviewItem.id: .reviewRecommended,
        ]
    }

    func selection(generation: UInt64 = 7) throws -> ReviewSelection {
        try ReviewSelection(
            plan: plan,
            generation: generation,
            items: [
                ReviewSelectionItem(
                    itemID: reviewItem.id,
                    origin: .explicitUser
                ),
                ReviewSelectionItem(
                    itemID: readyItem.id,
                    origin: .defaultReady
                ),
            ],
            dispositions: dispositions
        )
    }

    func context(
        capturedAt: Date? = nil,
        catalogVersion: DomainToken? = nil,
        workflow: CleanupWorkflowAvailabilitySnapshot = .available,
        itemMutations: [
            CleanupPlanItemID: (CleanupPolicyItemContext) throws
                -> CleanupPolicyItemContext
        ] = [:]
    ) throws -> CleanupPolicyContext {
        var items: [CleanupPolicyItemContext] = []
        for item in plan.items {
            var context = try itemContext(item)
            if let mutation = itemMutations[item.id] {
                context = try mutation(context)
            }
            items.append(context)
        }
        return try CleanupPolicyContext(
            capturedAt: capturedAt ?? now,
            planID: plan.id,
            scanSessionID: plan.scanSessionID,
            scanScopeID: plan.scanScopeID!,
            scanIsTerminal: true,
            planFingerprint: plan.planFingerprint!,
            selectionGeneration: 7,
            selectionFingerprint: try selection().fingerprint,
            rootIdentity: rootIdentity,
            catalogVersion: catalogVersion ?? plan.catalogVersion!,
            executionProfileVersion: plan.executionProfileVersion!,
            workflow: workflow,
            items: items
        )
    }

    func identity(
        inode: UInt64,
        size: Int64,
        allocatedBytes: Int64
    ) throws -> FileIdentity {
        try Self.makeIdentity(
            inode: inode,
            size: size,
            allocatedBytes: allocatedBytes
        )
    }

    private func itemContext(
        _ item: CleanupPlanItem
    ) throws -> CleanupPolicyItemContext {
        try CleanupPolicyItemContext(
            itemID: item.id,
            snapshotID: item.snapshotID,
            classificationID: item.classificationID,
            ruleID: item.ruleID!,
            executionProfileID: item.executionProfileID!,
            proposedAction: item.proposedAction,
            persistedDisposition: dispositions[item.id]!,
            currentDisposition: dispositions[item.id]!,
            expectedRelativePath: item.expectedRelativePath!,
            currentRelativePath: item.expectedRelativePath!,
            expectedIdentity: item.expectedIdentity!,
            currentIdentity: item.expectedIdentity!,
            evidenceFingerprint: item.evidenceFingerprint!,
            currentEvidenceFingerprint: item.evidenceFingerprint!,
            activityFingerprint: item.activityFingerprint!,
            currentActivityFingerprint: item.activityFingerprint!,
            pathFacts: .allowed,
            evidenceFacts: .current,
            activityFacts: .inactive
        )
    }

    fileprivate static func makeItem(
        slug: String,
        relativePath: String,
        inode: UInt64,
        size: Int64,
        allocatedBytes: Int64
    ) throws -> CleanupPlanItem {
        let identity = try makeIdentity(
            inode: inode,
            size: size,
            allocatedBytes: allocatedBytes
        )
        return try CleanupPlanItem(
            id: CleanupPlanItemID(rawValue: "plan-item-\(slug)")!,
            snapshotID: SnapshotID(rawValue: "snapshot-\(slug)")!,
            classificationID: ClassificationID(
                rawValue: "classification-\(slug)"
            )!,
            ruleID: DomainToken(rawValue: "rule-\(slug)")!,
            executionProfileID: DomainToken(rawValue: "profile-\(slug)")!,
            proposedAction: .moveToTrash,
            expectedRelativePath: PersistedPath(rawValue: relativePath)!,
            expectedIdentity: identity,
            logicalBytes: ByteCount(UInt64(size))!,
            allocatedBytes: ByteCount(UInt64(allocatedBytes))!,
            evidenceFingerprint: DomainToken(
                rawValue: "evidence.\(slug).fingerprint"
            )!,
            activityFingerprint: DomainToken(
                rawValue: "activity.\(slug).fingerprint"
            )!
        )
    }

    private static func makeIdentity(
        inode: UInt64,
        size: Int64,
        allocatedBytes: Int64
    ) throws -> FileIdentity {
        try FileIdentity(
            device: 100,
            inode: inode,
            mode: UInt16(S_IFDIR | 0o700),
            ownerUserID: 501,
            ownerGroupID: 20,
            linkCount: 1,
            size: size,
            allocatedBytes: allocatedBytes,
            modificationSeconds: 1_786_639_900,
            modificationNanoseconds: 123
        )
    }
}
