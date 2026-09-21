import Foundation
import Testing
@testable import StornautCore

@Test
func cleanupV1FixturesProjectConservativelyToV2() throws {
    let plan = try EvidenceStoreTestSupport.fixture(
        CleanupPlan.self,
        name: "cleanup-plan-v1"
    )
    let decision = try EvidenceStoreTestSupport.fixture(
        PolicyDecision.self,
        name: "policy-decision-v1"
    )
    let manifest = try EvidenceStoreTestSupport.fixture(
        CleanupManifest.self,
        name: "cleanup-manifest-v1"
    )

    #expect(plan.schemaVersion == .v2)
    #expect(plan.compatibility == .legacyV1)
    #expect(plan.scanScopeID == nil)
    #expect(plan.primaryRootIdentity == nil)
    #expect(plan.items.allSatisfy { $0.expectedIdentity == nil })
    #expect(decision.schemaVersion == .v2)
    #expect(decision.compatibility == .legacyV1)
    #expect(decision.selectionGeneration == nil)
    #expect(manifest.schemaVersion == .v2)
    #expect(manifest.compatibility == .legacyV1)
    #expect(manifest.records[0].recovery == .movedToTrash)
    #expect(
        manifest.summary.movedToTrashLogicalBytes
            == manifest.records[0].measures.movedToTrashLogicalBytes
    )

    let encoded = String(
        decoding: try DomainJSON.encode(manifest),
        as: UTF8.self
    ).lowercased()
    #expect(!encoded.contains("originalurl"))
    #expect(!encoded.contains("trashurl"))
    #expect(!encoded.contains("authorization"))
    #expect(!encoded.contains("capability"))
}

@Test
func nonCleanupDomainTypesRejectSchemaV2() throws {
    for fixture in [
        "scan-session-v1",
        "classification-v1",
        "evidence-v1",
        "accounting-v1",
    ] {
        let data = try EvidenceStoreTestSupport.fixtureData(name: fixture)
        var object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object["schemaVersion"] = 2
        let mutated = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        #expect(throws: (any Error).self) {
            switch fixture {
            case "scan-session-v1":
                _ = try DomainJSON.decode(ScanSession.self, from: mutated)
            case "classification-v1":
                _ = try DomainJSON.decode(Classification.self, from: mutated)
            case "evidence-v1":
                _ = try DomainJSON.decode(EvidenceRecord.self, from: mutated)
            default:
                _ = try DomainJSON.decode(SpaceAccounting.self, from: mutated)
            }
        }
    }
}

@Test
func currentCleanupPlanBindsOneScopeCatalogProfileAndIdentity() throws {
    let plan = try CleanupPersistenceTestSupport.plan()

    #expect(plan.schemaVersion == .v2)
    #expect(plan.compatibility == .current)
    #expect(plan.scanScopeID != nil)
    #expect(plan.primaryRootIdentity != nil)
    #expect(plan.catalogVersion?.rawValue == "catalog.phase-c-v1")
    #expect(plan.executionProfileVersion?.rawValue == "profile.phase-c-v1")
    #expect(plan.items.count == 2)
    #expect(plan.items.allSatisfy { $0.expectedIdentity != nil })
    #expect(plan.items.allSatisfy { $0.proposedAction == .moveToTrash })
}

@Test
func currentCleanupPlanRejectsOverlapDuplicateIdentityAndRegisteredAction()
    throws
{
    let parent = try CleanupPersistenceTestSupport.planItem(
        slug: "parent",
        relativePath: "Library/Caches",
        inode: 21
    )
    let child = try CleanupPersistenceTestSupport.planItem(
        slug: "child",
        relativePath: "Library/Caches/pip",
        inode: 22
    )
    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try CleanupPersistenceTestSupport.plan(items: [parent, child])
    }

    let first = try CleanupPersistenceTestSupport.planItem(
        slug: "first",
        relativePath: ".npm/_cacache",
        inode: 30
    )
    let duplicateIdentity = try CleanupPlanItem(
        id: CleanupPlanItemID(rawValue: "plan-item-second")!,
        snapshotID: SnapshotID(rawValue: "snapshot-second")!,
        classificationID: ClassificationID(
            rawValue: "classification-second"
        )!,
        ruleID: DomainToken(rawValue: "cache.second")!,
        executionProfileID: DomainToken(rawValue: "profile.phase-c.second")!,
        proposedAction: .moveToTrash,
        expectedRelativePath: PersistedPath(
            rawValue: "Library/Caches/pip"
        )!,
        expectedIdentity: first.expectedIdentity!,
        logicalBytes: first.logicalBytes!,
        allocatedBytes: first.allocatedBytes!,
        evidenceFingerprint: DomainToken(
            rawValue: "evidence.second.fingerprint"
        )!,
        activityFingerprint: DomainToken(
            rawValue: "activity.second.fingerprint"
        )!
    )
    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try CleanupPersistenceTestSupport.plan(
            items: [first, duplicateIdentity]
        )
    }

    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try CleanupPlanItem(
            id: CleanupPlanItemID(rawValue: "plan-item-registered")!,
            snapshotID: SnapshotID(rawValue: "snapshot-registered")!,
            classificationID: ClassificationID(
                rawValue: "classification-registered"
            )!,
            ruleID: DomainToken(rawValue: "cache.registered")!,
            executionProfileID: DomainToken(
                rawValue: "profile.phase-c.registered"
            )!,
            proposedAction: .registeredAction(
                id: DomainToken(rawValue: "fixture.unavailable-action")!
            ),
            expectedRelativePath: PersistedPath(
                rawValue: "Library/Caches/registered"
            )!,
            expectedIdentity: try CleanupPersistenceTestSupport.identity(
                inode: 31
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

    let differentDeviceRoot = try FileIdentity(
        device: 202,
        inode: 1,
        mode: UInt16(S_IFDIR | 0o700),
        ownerUserID: 501,
        ownerGroupID: 20,
        size: 4_096,
        allocatedBytes: 8_192,
        modificationSeconds: 1_786_499_900,
        modificationNanoseconds: 123
    )
    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try CleanupPlan(
            id: CleanupPlanID(rawValue: "plan-wrong-device")!,
            scanSessionID: ScanSessionID(
                rawValue: "scan-fixture-cancelled"
            )!,
            scanScopeID: ScanScopeID(rawValue: "scope-fixture-caches")!,
            primaryRootIdentity: differentDeviceRoot,
            catalogVersion: DomainToken(rawValue: "catalog.phase-c-v1")!,
            executionProfileVersion: DomainToken(
                rawValue: "profile.phase-c-v1"
            )!,
            planFingerprint: DomainToken(
                rawValue: "plan.wrong-device.fingerprint"
            )!,
            createdAt: CleanupPersistenceTestSupport.createdAt,
            expiresAt: CleanupPersistenceTestSupport.createdAt
                .addingTimeInterval(7 * 86_400),
            items: [first]
        )
    }
}

@Test
func currentPolicyBindsSelectionAndRequiresExplicitReview() throws {
    let plan = try CleanupPersistenceTestSupport.plan()
    let item = plan.items[0]
    let ready = try CleanupPersistenceTestSupport.decision(
        plan: plan,
        item: item
    )
    #expect(ready.compatibility == .current)
    #expect(ready.selectionGeneration == 3)
    #expect(ready.selectionOrigin == .defaultReady)

    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try CleanupPersistenceTestSupport.decision(
            plan: plan,
            item: item,
            disposition: .reviewRecommended,
            selectionOrigin: .defaultReady
        )
    }
    let explicit = try CleanupPersistenceTestSupport.decision(
        plan: plan,
        item: item,
        disposition: .reviewRecommended,
        selectionOrigin: .explicitUser
    )
    #expect(explicit.outcome == .allowed)
}

@Test
func currentManifestSeparatesTrashPermanentAndSystemObservation() throws {
    let manifest = try CleanupPersistenceTestSupport.manifest()
    let record = try #require(manifest.records.first)

    #expect(manifest.compatibility == .current)
    #expect(record.recovery == .movedToTrash)
    #expect(record.measures.permanentlyReleasedLogicalBytes == ByteCount(0))
    #expect(
        manifest.summary.movedToTrashLogicalBytes
            == record.measures.movedToTrashLogicalBytes
    )
    #expect(manifest.summary.permanentlyReleasedLogicalBytes == ByteCount(0))

    let json = String(
        decoding: try DomainJSON.encode(manifest),
        as: UTF8.self
    ).lowercased()
    #expect(!json.contains("originalurl"))
    #expect(!json.contains("trashurl"))
    #expect(!json.contains("targeturl"))
    #expect(!json.contains("authorization"))
    #expect(!json.contains("capability"))
}

@Test
func currentManifestRejectsMixedBytesMissingErrorAndWrongSummary() throws {
    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try CleanupPersistenceTestSupport.measures(permanent: 1)
    }

    let plan = try CleanupPersistenceTestSupport.plan()
    let item = plan.items[0]
    let decision = try CleanupPersistenceTestSupport.decision(
        plan: plan,
        item: item
    )
    let incompleteSuccessMeasures = try CleanupManifestMeasures(
        candidateLogicalBytes: item.logicalBytes!,
        candidateAllocatedBytes: item.allocatedBytes!,
        processedLogicalBytes: ByteCount(1)!,
        processedAllocatedBytes: ByteCount(1)!,
        movedToTrashLogicalBytes: ByteCount(1)!,
        movedToTrashAllocatedBytes: ByteCount(1)!,
        permanentlyReleasedLogicalBytes: ByteCount(0)!,
        permanentlyReleasedAllocatedBytes: ByteCount(0)!
    )
    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try CleanupManifestRecord(
            actionID: CleanupActionID(rawValue: "action-incomplete-success")!,
            planItemID: item.id,
            policyDecisionID: decision.id,
            policyDisposition: decision.disposition,
            policyReasonKeys: decision.reasonKeys,
            action: .moveToTrash,
            result: .succeeded,
            recovery: .movedToTrash,
            measures: incompleteSuccessMeasures,
            startedAt: CleanupPersistenceTestSupport.updatedAt,
            finishedAt: CleanupPersistenceTestSupport.updatedAt,
            error: nil
        )
    }
    let failedMeasures = try CleanupManifestMeasures(
        candidateLogicalBytes: ByteCount(10)!,
        candidateAllocatedBytes: ByteCount(10)!,
        processedLogicalBytes: ByteCount(0)!,
        processedAllocatedBytes: ByteCount(0)!,
        movedToTrashLogicalBytes: ByteCount(0)!,
        movedToTrashAllocatedBytes: ByteCount(0)!,
        permanentlyReleasedLogicalBytes: ByteCount(0)!,
        permanentlyReleasedAllocatedBytes: ByteCount(0)!
    )
    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try CleanupManifestRecord(
            actionID: CleanupActionID(rawValue: "action-failed")!,
            planItemID: item.id,
            policyDecisionID: decision.id,
            policyDisposition: decision.disposition,
            policyReasonKeys: decision.reasonKeys,
            action: .moveToTrash,
            result: .failed,
            recovery: .originalConfirmed,
            measures: failedMeasures,
            startedAt: CleanupPersistenceTestSupport.updatedAt,
            finishedAt: CleanupPersistenceTestSupport.updatedAt,
            error: nil
        )
    }

    let manifest = try CleanupPersistenceTestSupport.manifest(plan: plan)
    let wrongSummary = try CleanupManifestSummary(
        selectedLogicalBytes: ByteCount(1)!,
        selectedAllocatedBytes: ByteCount(1)!,
        processedLogicalBytes: ByteCount(0)!,
        processedAllocatedBytes: ByteCount(0)!,
        movedToTrashLogicalBytes: ByteCount(0)!,
        movedToTrashAllocatedBytes: ByteCount(0)!,
        permanentlyReleasedLogicalBytes: ByteCount(0)!,
        permanentlyReleasedAllocatedBytes: ByteCount(0)!,
        succeededCount: 0,
        failedCount: 0,
        cancelledCount: 0,
        unknownCount: 0
    )
    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try CleanupManifest(
            id: manifest.id,
            planID: manifest.planID,
            createdAt: manifest.createdAt,
            expiresAt: manifest.expiresAt,
            records: manifest.records,
            summary: wrongSummary,
            systemObservation: nil
        )
    }
}

@Test
func cleanupV2StrictDecodersRejectFutureAndNestedAuthorityFields() throws {
    let plan = try CleanupPersistenceTestSupport.plan()
    var futurePlan = try #require(
        JSONSerialization.jsonObject(
            with: DomainJSON.encode(plan)
        ) as? [String: Any]
    )
    futurePlan["schemaVersion"] = 3
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            CleanupPlan.self,
            from: try JSONSerialization.data(withJSONObject: futurePlan)
        )
    }

    let journal = try CleanupPersistenceTestSupport.journal(plan: plan)
    var injectedJournal = try #require(
        JSONSerialization.jsonObject(
            with: DomainJSON.encode(journal)
        ) as? [String: Any]
    )
    var entries = try #require(
        injectedJournal["entries"] as? [[String: Any]]
    )
    entries[0]["authorization"] = "replayable"
    injectedJournal["entries"] = entries
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            CleanupRunJournal.self,
            from: try JSONSerialization.data(withJSONObject: injectedJournal)
        )
    }
}
