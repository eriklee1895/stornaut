import Foundation
import Testing
@testable import StornautCore

@Test
func cleanupStoreV3RoundTripsCurrentRecordsAndPages() async throws {
    let store = try EvidenceStore(configuration: .memory)
    #expect(try await store.diagnostics().schemaVersion == 3)

    let plan = try CleanupPersistenceTestSupport.plan()
    let journal = try CleanupPersistenceTestSupport.journal(plan: plan)
    let manifest = try CleanupPersistenceTestSupport.manifest(plan: plan)
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    try await store.saveScanSession(session)
    try await store.saveCleanupPlan(plan)
    let decisions = try plan.items.map {
        try CleanupPersistenceTestSupport.decision(plan: plan, item: $0)
    }
    for decision in decisions {
        try await store.savePolicyDecision(decision)
    }
    try await store.saveCleanupRunJournal(journal)
    try await store.saveCleanupManifest(manifest)
    try await store.saveCleanupPlan(plan)
    try await store.savePolicyDecision(decisions[0])

    #expect(try await store.cleanupPlan(id: plan.id) == plan)
    #expect(
        try await store.policyDecision(id: decisions[0].id) == decisions[0]
    )
    #expect(try await store.cleanupRunJournal(id: journal.id) == journal)
    #expect(try await store.cleanupManifest(id: manifest.id) == manifest)
    #expect(
        try await store.cleanupPlans(
            sessionID: plan.scanSessionID,
            limit: 10,
            offset: 0
        ).records == [plan]
    )
    #expect(
        try await store.policyDecisions(
            planID: plan.id,
            limit: 10,
            offset: 0
        ).records == decisions
    )
    #expect(
        try await store.cleanupRunJournals(limit: 10, offset: 0)
            .records == [journal]
    )
    #expect(
        try await store.cleanupManifests(limit: 10, offset: 0)
            .records == [manifest]
    )
}

@Test
func cleanupStorePagesIsolateCorruptPlanAndPolicyRows() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let plan = try CleanupPersistenceTestSupport.plan()
    let decisions = try plan.items.map {
        try CleanupPersistenceTestSupport.decision(plan: plan, item: $0)
    }
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    try await store.saveScanSession(session)
    try await store.saveCleanupPlan(plan)
    for decision in decisions {
        try await store.savePolicyDecision(decision)
    }
    try await store._testInsertMalformedCleanupPlan(
        id: "plan-corrupt",
        sessionID: session.id,
        payload: "{not-json"
    )
    try await store._testInsertMalformedPolicyDecision(
        id: "decision-corrupt",
        planID: plan.id,
        payload: "{not-json"
    )

    let plans = try await store.cleanupPlans(
        sessionID: session.id,
        limit: 10,
        offset: 0
    )
    let decisionPage = try await store.policyDecisions(
        planID: plan.id,
        limit: 10,
        offset: 0
    )
    #expect(plans.records == [plan])
    #expect(plans.corruptRecordIDs == ["plan-corrupt"])
    #expect(decisionPage.records == decisions)
    #expect(decisionPage.corruptRecordIDs == ["decision-corrupt"])
}

@Test
func cleanupStoreRejectsPlanBoundToUnretainedScope() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let plan = try CleanupPersistenceTestSupport.plan()
    let wrongScopePlan = try CleanupPlan(
        id: CleanupPlanID(rawValue: "plan-wrong-scope")!,
        scanSessionID: plan.scanSessionID,
        scanScopeID: ScanScopeID(rawValue: "scope-not-retained")!,
        primaryRootIdentity: try #require(plan.primaryRootIdentity),
        catalogVersion: try #require(plan.catalogVersion),
        executionProfileVersion: try #require(plan.executionProfileVersion),
        planFingerprint: DomainToken(
            rawValue: "plan.wrong-scope.fingerprint"
        )!,
        createdAt: plan.createdAt,
        expiresAt: plan.expiresAt,
        items: plan.items
    )
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    try await store.saveScanSession(session)

    await #expect(throws: EvidenceStoreError.recordIdentityMismatch) {
        try await store.saveCleanupPlan(wrongScopePlan)
    }
}

@Test
func cleanupStoreRejectsLegacyWritesAndManifestMutation() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let legacyPlan: CleanupPlan = try EvidenceStoreTestSupport.fixture(
        CleanupPlan.self,
        name: "cleanup-plan-v1"
    )
    let legacyDecision: PolicyDecision = try EvidenceStoreTestSupport.fixture(
        PolicyDecision.self,
        name: "policy-decision-v1"
    )
    let legacyManifest: CleanupManifest = try EvidenceStoreTestSupport.fixture(
        CleanupManifest.self,
        name: "cleanup-manifest-v1"
    )
    await #expect(throws: EvidenceStoreError.legacyCleanupRecord) {
        try await store.saveCleanupPlan(legacyPlan)
    }
    await #expect(throws: EvidenceStoreError.legacyCleanupRecord) {
        try await store.savePolicyDecision(legacyDecision)
    }
    await #expect(throws: EvidenceStoreError.legacyCleanupRecord) {
        try await store.saveCleanupManifest(legacyManifest)
    }

    let plan = try CleanupPersistenceTestSupport.plan()
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    try await store.saveScanSession(session)
    let manifest = try CleanupPersistenceTestSupport.manifest(plan: plan)
    try await store.saveCleanupManifest(manifest)
    try await store.saveCleanupManifest(manifest)

    let changed = try CleanupManifest(
        id: manifest.id,
        planID: manifest.planID,
        createdAt: manifest.createdAt,
        expiresAt: manifest.expiresAt.addingTimeInterval(-1),
        records: manifest.records,
        summary: manifest.summary,
        systemObservation: manifest.systemObservation
    )
    await #expect(throws: EvidenceStoreError.immutableRecordConflict) {
        try await store.saveCleanupManifest(changed)
    }
    #expect(try await store.cleanupManifest(id: manifest.id) == manifest)
}

@Test
func cleanupStoreRejectsJournalRegressionAndIsolatesCorruptPages() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let plan = try CleanupPersistenceTestSupport.plan()
    let decisions = try plan.items.map {
        try CleanupPersistenceTestSupport.decision(plan: plan, item: $0)
    }
    let prepared = try CleanupPersistenceTestSupport.journal(plan: plan)
    let started = try CleanupPersistenceTestSupport.journal(
        plan: plan,
        stage: .actionStarted,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                state: .started
            ),
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[1]
            ),
        ]
    )
    await #expect(throws: EvidenceStoreError.invalidJournalTransition) {
        try await store.saveCleanupRunJournal(started)
    }
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    try await store.saveScanSession(session)
    try await store.saveCleanupPlan(plan)
    for decision in decisions {
        try await store.savePolicyDecision(decision)
    }
    try await store.saveCleanupRunJournal(prepared)
    try await store.saveCleanupRunJournal(started)
    await #expect(throws: EvidenceStoreError.invalidJournalTransition) {
        try await store.saveCleanupRunJournal(prepared)
    }

    try await store._testInsertMalformedCleanupJournal(
        id: "run-corrupt",
        payload: "{not-json"
    )
    try await store._testInsertMalformedCleanupManifest(
        id: "manifest-corrupt",
        payload: "{not-json"
    )
    let journals = try await store.cleanupRunJournals(limit: 10, offset: 0)
    let manifests = try await store.cleanupManifests(limit: 10, offset: 0)
    #expect(journals.records == [started])
    #expect(journals.corruptRecordIDs == ["run-corrupt"])
    #expect(manifests.corruptRecordIDs == ["manifest-corrupt"])
}

@Test
func cleanupStoreRejectsPreparedJournalBoundToDeniedPolicy() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let plan = try CleanupPersistenceTestSupport.plan()
    let denied = try CleanupPersistenceTestSupport.decision(
        plan: plan,
        item: plan.items[0],
        outcome: .denied
    )
    let allowed = try CleanupPersistenceTestSupport.decision(
        plan: plan,
        item: plan.items[1]
    )
    let journal = try CleanupPersistenceTestSupport.journal(
        plan: plan,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                decision: denied
            ),
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[1],
                decision: allowed
            ),
        ]
    )
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    try await store.saveScanSession(session)
    try await store.saveCleanupPlan(plan)
    try await store.savePolicyDecision(denied)
    try await store.savePolicyDecision(allowed)

    await #expect(throws: EvidenceStoreError.invalidJournalTransition) {
        try await store.saveCleanupRunJournal(journal)
    }
}

@Test
func cleanupStoreAcceptsOrderedSelectionSubsetAndRejectsReorderedSubset()
    async throws
{
    let store = try EvidenceStore(configuration: .memory)
    let plan = try CleanupPersistenceTestSupport.plan()
    let selectedItem = plan.items[1]
    let selectedDecision = try CleanupPersistenceTestSupport.decision(
        plan: plan,
        item: selectedItem
    )
    let selectedEntry = try CleanupPersistenceTestSupport.journalEntry(
        item: selectedItem,
        decision: selectedDecision
    )
    let subset = try CleanupRunJournal(
        id: CleanupRunID(rawValue: "run-selection-subset")!,
        planID: plan.id,
        manifestID: CleanupManifestID(
            rawValue: "manifest-selection-subset"
        )!,
        selectionGeneration: 3,
        selectionFingerprint: DomainToken(
            rawValue: "selection.subset.fingerprint"
        )!,
        stage: .prepared,
        retentionClass: .evidenceLinked,
        stopAfterCurrentRequested: false,
        entries: [selectedEntry],
        createdAt: CleanupPersistenceTestSupport.createdAt,
        updatedAt: CleanupPersistenceTestSupport.updatedAt,
        expiresAt: CleanupPersistenceTestSupport.createdAt
            .addingTimeInterval(7 * 86_400)
    )
    let decisions = try plan.items.map {
        try CleanupPersistenceTestSupport.decision(plan: plan, item: $0)
    }
    let reversed = try CleanupRunJournal(
        id: CleanupRunID(rawValue: "run-selection-reversed")!,
        planID: plan.id,
        manifestID: CleanupManifestID(
            rawValue: "manifest-selection-reversed"
        )!,
        selectionGeneration: 3,
        selectionFingerprint: DomainToken(
            rawValue: "selection.reversed.fingerprint"
        )!,
        stage: .prepared,
        retentionClass: .evidenceLinked,
        stopAfterCurrentRequested: false,
        entries: try plan.items.reversed().map {
            try CleanupPersistenceTestSupport.journalEntry(item: $0)
        },
        createdAt: CleanupPersistenceTestSupport.createdAt,
        updatedAt: CleanupPersistenceTestSupport.updatedAt,
        expiresAt: CleanupPersistenceTestSupport.createdAt
            .addingTimeInterval(7 * 86_400)
    )
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    try await store.saveScanSession(session)
    try await store.saveCleanupPlan(plan)
    for decision in decisions {
        try await store.savePolicyDecision(decision)
    }

    try await store.saveCleanupRunJournal(subset)
    await #expect(throws: EvidenceStoreError.invalidJournalTransition) {
        try await store.saveCleanupRunJournal(reversed)
    }
}

@Test
func cleanupJournalCanAdvanceToTheNextStartedAction() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let plan = try CleanupPersistenceTestSupport.plan()
    let decisions = try plan.items.map {
        try CleanupPersistenceTestSupport.decision(plan: plan, item: $0)
    }
    let prepared = try CleanupPersistenceTestSupport.journal(plan: plan)
    let firstStarted = try CleanupPersistenceTestSupport.journal(
        plan: plan,
        stage: .actionStarted,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                state: .started
            ),
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[1]
            ),
        ]
    )
    let firstOutcome = try CleanupPersistenceTestSupport.journal(
        plan: plan,
        stage: .actionOutcomeRecorded,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                state: .outcomeRecorded
            ),
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[1]
            ),
        ]
    )
    let secondStarted = try CleanupRunJournal(
        id: firstOutcome.id,
        planID: firstOutcome.planID,
        manifestID: firstOutcome.manifestID,
        selectionGeneration: firstOutcome.selectionGeneration,
        selectionFingerprint: firstOutcome.selectionFingerprint,
        stage: .actionStarted,
        retentionClass: .audit,
        stopAfterCurrentRequested: false,
        entries: [
            firstOutcome.entries[0],
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[1],
                state: .started
            ),
        ],
        createdAt: firstOutcome.createdAt,
        updatedAt: firstOutcome.updatedAt.addingTimeInterval(1),
        expiresAt: firstOutcome.expiresAt
    )
    let combinedStarted = try CleanupRunJournal(
        id: firstStarted.id,
        planID: firstStarted.planID,
        manifestID: firstStarted.manifestID,
        selectionGeneration: firstStarted.selectionGeneration,
        selectionFingerprint: firstStarted.selectionFingerprint,
        stage: .actionStarted,
        retentionClass: .audit,
        stopAfterCurrentRequested: false,
        entries: secondStarted.entries,
        createdAt: firstStarted.createdAt,
        updatedAt: secondStarted.updatedAt,
        expiresAt: firstStarted.expiresAt
    )

    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    try await store.saveScanSession(session)
    try await store.saveCleanupPlan(plan)
    for decision in decisions {
        try await store.savePolicyDecision(decision)
    }
    try await store.saveCleanupRunJournal(prepared)
    try await store.saveCleanupRunJournal(firstStarted)
    await #expect(throws: EvidenceStoreError.invalidJournalTransition) {
        try await store.saveCleanupRunJournal(combinedStarted)
    }
    try await store.saveCleanupRunJournal(firstOutcome)
    try await store.saveCleanupRunJournal(secondStarted)
    #expect(
        try await store.cleanupRunJournal(id: secondStarted.id)
            == secondStarted
    )

    let finalOutcome = try CleanupRunJournal(
        id: secondStarted.id,
        planID: secondStarted.planID,
        manifestID: secondStarted.manifestID,
        selectionGeneration: secondStarted.selectionGeneration,
        selectionFingerprint: secondStarted.selectionFingerprint,
        stage: .actionOutcomeRecorded,
        retentionClass: .audit,
        stopAfterCurrentRequested: false,
        entries: [
            secondStarted.entries[0],
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[1],
                state: .outcomeRecorded
            ),
        ],
        createdAt: secondStarted.createdAt,
        updatedAt: secondStarted.updatedAt.addingTimeInterval(1),
        expiresAt: secondStarted.expiresAt
    )
    try await store.saveCleanupRunJournal(finalOutcome)
    #expect(
        try await store.cleanupRunJournal(id: finalOutcome.id)
            == finalOutcome
    )
}

@Test
func cleanupStoreClearAndRetentionSeparateEvidenceFromAudit() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let plan = try CleanupPersistenceTestSupport.plan()
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    let prepared = try CleanupPersistenceTestSupport.journal(plan: plan)
    let started = try CleanupPersistenceTestSupport.journal(
        plan: plan,
        stage: .actionStarted,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                state: .started
            ),
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[1]
            ),
        ]
    )
    let audit = try CleanupRunJournal(
        id: CleanupRunID(rawValue: "run-audit")!,
        planID: started.planID,
        manifestID: CleanupManifestID(rawValue: "manifest-audit")!,
        selectionGeneration: started.selectionGeneration,
        selectionFingerprint: started.selectionFingerprint,
        stage: started.stage,
        retentionClass: started.retentionClass,
        stopAfterCurrentRequested: started.stopAfterCurrentRequested,
        entries: started.entries,
        createdAt: started.createdAt,
        updatedAt: started.updatedAt,
        expiresAt: started.expiresAt
    )
    let auditPrepared = try CleanupRunJournal(
        id: audit.id,
        planID: audit.planID,
        manifestID: audit.manifestID,
        selectionGeneration: audit.selectionGeneration,
        selectionFingerprint: audit.selectionFingerprint,
        stage: .prepared,
        retentionClass: .evidenceLinked,
        stopAfterCurrentRequested: false,
        entries: try plan.items.map {
            try CleanupPersistenceTestSupport.journalEntry(item: $0)
        },
        createdAt: audit.createdAt,
        updatedAt: CleanupPersistenceTestSupport.updatedAt,
        expiresAt: audit.createdAt.addingTimeInterval(7 * 86_400)
    )
    let manifest = try CleanupPersistenceTestSupport.manifest(plan: plan)
    try await store.saveScanSession(session)
    try await store.saveCleanupPlan(plan)
    for item in plan.items {
        try await store.savePolicyDecision(
            CleanupPersistenceTestSupport.decision(plan: plan, item: item)
        )
    }
    try await store.saveCleanupRunJournal(prepared)
    try await store.saveCleanupRunJournal(auditPrepared)
    try await store.saveCleanupRunJournal(audit)
    try await store.saveCleanupManifest(manifest)

    try await store.clearEvidence()
    #expect(try await store.cleanupPlan(id: plan.id) == nil)
    #expect(try await store.cleanupRunJournal(id: prepared.id) == nil)
    #expect(try await store.cleanupRunJournal(id: audit.id) == audit)
    #expect(try await store.cleanupManifest(id: manifest.id) == manifest)

    try await store.clearManifests()
    #expect(try await store.cleanupRunJournal(id: audit.id) == nil)
    #expect(try await store.cleanupManifest(id: manifest.id) == nil)
}

@Test
func deletingOneScanRemovesOnlyItsPreparedJournal() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let plan = try CleanupPersistenceTestSupport.plan()
    let prepared = try CleanupPersistenceTestSupport.journal(plan: plan)
    let started = try CleanupPersistenceTestSupport.journal(
        plan: plan,
        stage: .actionStarted,
        entries: [
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[0],
                state: .started
            ),
            try CleanupPersistenceTestSupport.journalEntry(
                item: plan.items[1]
            ),
        ]
    )
    let auditPrepared = try CleanupRunJournal(
        id: CleanupRunID(rawValue: "run-delete-audit")!,
        planID: plan.id,
        manifestID: CleanupManifestID(
            rawValue: "manifest-delete-audit"
        )!,
        selectionGeneration: started.selectionGeneration,
        selectionFingerprint: DomainToken(
            rawValue: "selection.delete-audit.fingerprint"
        )!,
        stage: .prepared,
        retentionClass: .evidenceLinked,
        stopAfterCurrentRequested: false,
        entries: prepared.entries,
        createdAt: prepared.createdAt,
        updatedAt: prepared.updatedAt,
        expiresAt: prepared.expiresAt
    )
    let audit = try CleanupRunJournal(
        id: auditPrepared.id,
        planID: auditPrepared.planID,
        manifestID: auditPrepared.manifestID,
        selectionGeneration: auditPrepared.selectionGeneration,
        selectionFingerprint: auditPrepared.selectionFingerprint,
        stage: started.stage,
        retentionClass: started.retentionClass,
        stopAfterCurrentRequested: false,
        entries: started.entries,
        createdAt: started.createdAt,
        updatedAt: started.updatedAt,
        expiresAt: started.expiresAt
    )
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    try await store.saveScanSession(session)
    try await store.saveCleanupPlan(plan)
    for item in plan.items {
        try await store.savePolicyDecision(
            CleanupPersistenceTestSupport.decision(plan: plan, item: item)
        )
    }
    try await store.saveCleanupRunJournal(prepared)
    try await store.saveCleanupRunJournal(auditPrepared)
    try await store.saveCleanupRunJournal(audit)

    try await store.deleteScanSession(id: session.id)
    #expect(try await store.cleanupRunJournal(id: prepared.id) == nil)
    #expect(try await store.cleanupRunJournal(id: audit.id) == audit)
}

@Test
func cleanupImmutableWritesAreIdempotentAcrossStoreConnections() async throws {
    let root = try EvidenceStoreTestSupport.temporaryDirectory(
        "cleanup-multi-connection"
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: root
    )
    let first = try EvidenceStore(configuration: configuration)
    let second = try EvidenceStore(configuration: configuration)
    let plan = try CleanupPersistenceTestSupport.plan()
    let decisions = try plan.items.map {
        try CleanupPersistenceTestSupport.decision(plan: plan, item: $0)
    }
    let journal = try CleanupPersistenceTestSupport.journal(plan: plan)
    let manifest = try CleanupPersistenceTestSupport.manifest(plan: plan)
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    try await first.saveScanSession(session)
    try await first.saveCleanupPlan(plan)
    for decision in decisions {
        try await first.savePolicyDecision(decision)
    }
    try await first.saveCleanupRunJournal(journal)
    try await first.saveCleanupManifest(manifest)

    try await second.saveCleanupPlan(plan)
    for decision in decisions {
        try await second.savePolicyDecision(decision)
    }
    try await second.saveCleanupRunJournal(journal)
    try await second.saveCleanupManifest(manifest)

    #expect(try await second.cleanupPlan(id: plan.id) == plan)
    #expect(try await second.cleanupRunJournal(id: journal.id) == journal)
    #expect(try await second.cleanupManifest(id: manifest.id) == manifest)
}
