import Foundation
import Testing
@testable import StornautCore

@Test
func retentionExpiresEvidenceAtSevenDaysAndManifestAtNinety() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    let manifest: CleanupManifest = try EvidenceStoreTestSupport.fixture(
        CleanupManifest.self,
        name: "cleanup-manifest-v1"
    )
    try await store.saveScanSession(session)
    try await store.saveCleanupManifest(manifest)

    try await store.expireRecords(
        now: session.finishedAt.addingTimeInterval(7 * 86_400 - 1)
    )
    #expect(try await store.scanSession(id: session.id) != nil)
    #expect(try await store.cleanupManifest(id: manifest.id) != nil)

    try await store.expireRecords(
        now: session.finishedAt.addingTimeInterval(7 * 86_400 + 1)
    )
    #expect(try await store.scanSession(id: session.id) == nil)
    #expect(try await store.cleanupManifest(id: manifest.id) != nil)

    try await store.expireRecords(now: manifest.expiresAt.addingTimeInterval(1))
    #expect(try await store.cleanupManifest(id: manifest.id) == nil)
}

@Test
func clearEvidenceAndManifestsAreSeparateAndNeverClearKnowledge() async throws {
    let evidence = try EvidenceStore(configuration: .memory)
    let knowledge = try LocalKnowledgeStore(configuration: .memory)
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    let manifest: CleanupManifest = try EvidenceStoreTestSupport.fixture(
        CleanupManifest.self,
        name: "cleanup-manifest-v1"
    )
    let fact = try LocalKnowledgeFact(
        id: LocalKnowledgeID(validating: "knowledge-fixture"),
        payload: .producerMapping(
            ProducerMappingKnowledge(
                producer: DomainLabel(validating: "Fixture producer")
            )
        ),
        binding: localKnowledgeBinding(scope: "fixture-root/projects"),
        provenance: .userConfirmed,
        observedAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1)
    )
    try await evidence.saveScanSession(session)
    try await evidence.saveCleanupManifest(manifest)
    try await knowledge.save(fact)
    #expect(try await knowledge.facts(limit: 10, offset: 0).records == [fact])

    try await evidence.clearEvidence()
    #expect(try await evidence.scanSession(id: session.id) == nil)
    #expect(try await evidence.cleanupManifest(id: manifest.id) != nil)
    #expect(try await knowledge.fact(id: fact.id) == fact)

    try await evidence.clearManifests()
    #expect(try await evidence.cleanupManifest(id: manifest.id) == nil)
    #expect(try await knowledge.fact(id: fact.id) == fact)
}

@Test
func malformedLocalKnowledgeRecordDoesNotHideHealthyFacts() async throws {
    let knowledge = try LocalKnowledgeStore(configuration: .memory)
    let fact = try LocalKnowledgeFact(
        id: LocalKnowledgeID(validating: "knowledge-healthy"),
        payload: .recoveryMethod(
            VerifiedRecoveryKnowledge(
                methodKey: DomainToken(
                    validating: "recovery.fixture.rebuild"
                ),
                cost: .low
            )
        ),
        binding: localKnowledgeBinding(scope: "fixture-root/recovery"),
        provenance: .userConfirmed,
        observedAt: Date(timeIntervalSince1970: 3),
        updatedAt: Date(timeIntervalSince1970: 3)
    )
    try await knowledge.save(fact)
    try await knowledge._testInsertMalformedFact(
        id: "knowledge-malformed",
        payload: "{not-json"
    )

    await #expect(throws: EvidenceStoreError.invalidPage) {
        _ = try await knowledge.facts(limit: 101, offset: 0)
    }
    let page = try await knowledge.facts(limit: 10, offset: 0)
    #expect(page.records == [fact])
    #expect(page.corruptRecordIDs == ["knowledge-malformed"])
}

@Test
func localStorageEnforcesModesSymlinksAndBackupRoles() async throws {
    let root = try EvidenceStoreTestSupport.temporaryDirectory("paths")
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: root
    )
    _ = try EvidenceStore(configuration: configuration)
    _ = try LocalKnowledgeStore(configuration: configuration)

    let supportMode = try fileMode(configuration.supportDirectoryURL)
    let evidenceMode = try fileMode(configuration.evidenceDatabaseURL)
    let knowledgeMode = try fileMode(configuration.localKnowledgeDatabaseURL)
    #expect(supportMode == 0o700)
    #expect(evidenceMode == 0o600)
    #expect(knowledgeMode == 0o600)
    #expect(
        try configuration.evidenceDatabaseURL.resourceValues(
            forKeys: [.isExcludedFromBackupKey]
        ).isExcludedFromBackup == true
    )
    #expect(
        try configuration.localKnowledgeDatabaseURL.resourceValues(
            forKeys: [.isExcludedFromBackupKey]
        ).isExcludedFromBackup != true
    )

    let symlinkRoot = try EvidenceStoreTestSupport.temporaryDirectory("symlink")
    defer { try? FileManager.default.removeItem(at: symlinkRoot) }
    let symlinkConfiguration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: symlinkRoot
    )
    try FileManager.default.createDirectory(
        at: try #require(
            symlinkConfiguration.applicationSupportBaseURL
        ),
        withIntermediateDirectories: true
    )
    try FileManager.default.createSymbolicLink(
        at: symlinkConfiguration.supportDirectoryURL,
        withDestinationURL: root
    )
    #expect(throws: EvidenceStoreError.unsafeStoragePath) {
        _ = try EvidenceStore(configuration: symlinkConfiguration)
    }
}

@Test
func databaseCorruptionIsIsolatedByStoreRole() async throws {
    let root = try EvidenceStoreTestSupport.temporaryDirectory("role-corruption")
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: root
    )
    _ = try EvidenceStore(configuration: configuration)
    let knowledge = try LocalKnowledgeStore(configuration: configuration)
    let fact = try LocalKnowledgeFact(
        id: LocalKnowledgeID(validating: "knowledge-role-isolation"),
        payload: .keepDecision,
        binding: localKnowledgeBinding(scope: "fixture-root/keep"),
        provenance: .userConfirmed,
        observedAt: Date(timeIntervalSince1970: 2),
        updatedAt: Date(timeIntervalSince1970: 2)
    )
    try await knowledge.save(fact)
    try Data("corrupt-evidence".utf8).write(
        to: configuration.evidenceDatabaseURL
    )
    #expect(throws: EvidenceStoreError.integrityCheckFailed) {
        _ = try EvidenceStore(configuration: configuration)
    }
    #expect(try await knowledge.fact(id: fact.id) == fact)

    try Data("corrupt-knowledge".utf8).write(
        to: configuration.localKnowledgeDatabaseURL
    )
    #expect(throws: (any Error).self) {
        _ = try LocalKnowledgeStore(configuration: configuration)
    }
    #expect(throws: EvidenceStoreError.integrityCheckFailed) {
        _ = try EvidenceStore(configuration: configuration)
    }
}

@Test
func backupRejectsSymlinkDestination() async throws {
    let root = try EvidenceStoreTestSupport.temporaryDirectory("backup-symlink")
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = try EvidenceStoreTestSupport.makeFileConfiguration(
        root: root
    )
    let store = try EvidenceStore(configuration: configuration)
    let exportDirectory = root.appending(path: "export")
    try FileManager.default.createDirectory(
        at: exportDirectory,
        withIntermediateDirectories: true
    )
    let target = exportDirectory.appending(path: "target.sqlite")
    try Data().write(to: target)
    let symlink = exportDirectory.appending(path: "export.sqlite")
    try FileManager.default.createSymbolicLink(
        at: symlink,
        withDestinationURL: target
    )

    await #expect(throws: EvidenceStoreError.unsafeStoragePath) {
        try await store.exportBackup(to: symlink)
    }
}

@Test
func fixedRetentionCapsRejectLongerPayloadExpiry() async throws {
    let store = try EvidenceStore(configuration: .memory)
    let session: ScanSession = try EvidenceStoreTestSupport.fixture(
        ScanSession.self,
        name: "scan-session-v1"
    )
    let fixturePlan: CleanupPlan = try EvidenceStoreTestSupport.fixture(
        CleanupPlan.self,
        name: "cleanup-plan-v1"
    )
    let fixtureManifest: CleanupManifest = try EvidenceStoreTestSupport.fixture(
        CleanupManifest.self,
        name: "cleanup-manifest-v1"
    )
    let plan = try CleanupPlan(
        id: fixturePlan.id,
        scanSessionID: fixturePlan.scanSessionID,
        createdAt: fixturePlan.createdAt,
        expiresAt: fixturePlan.createdAt.addingTimeInterval(365 * 86_400),
        items: fixturePlan.items
    )
    let manifest = try CleanupManifest(
        id: fixtureManifest.id,
        planID: fixtureManifest.planID,
        createdAt: fixtureManifest.createdAt,
        expiresAt: fixtureManifest.createdAt.addingTimeInterval(365 * 86_400),
        records: fixtureManifest.records,
        systemObservation: fixtureManifest.systemObservation
    )
    try await store.saveScanSession(session)
    await #expect(throws: EvidenceStoreError.retentionLimitExceeded) {
        try await store.saveCleanupPlan(plan)
    }
    await #expect(throws: EvidenceStoreError.retentionLimitExceeded) {
        try await store.saveCleanupManifest(manifest)
    }
    #expect(try await store.cleanupPlan(id: plan.id) == nil)
    #expect(try await store.cleanupManifest(id: manifest.id) == nil)

    try await store.saveCleanupPlan(fixturePlan)
    try await store._testChangeCleanupPlanExpiry(
        id: fixturePlan.id,
        milliseconds: .max
    )
    await #expect(throws: EvidenceStoreError.recordIdentityMismatch) {
        _ = try await store.cleanupPlan(id: fixturePlan.id)
    }
    try await store.expireRecords(
        now: fixturePlan.createdAt.addingTimeInterval(7 * 86_400 + 1)
    )
    #expect(try await store.cleanupPlan(id: fixturePlan.id) == nil)
}

private func fileMode(_ url: URL) throws -> mode_t {
    var information = stat()
    guard lstat(url.path, &information) == 0 else {
        throw CocoaError(.fileReadUnknown)
    }
    return information.st_mode & 0o777
}

private func localKnowledgeBinding(
    scope: String
) throws -> LocalKnowledgeBinding {
    LocalKnowledgeBinding(
        scope: try PersistedPath(validating: scope),
        fileIdentity: try FileIdentity(
            device: 1,
            inode: 2,
            mode: 0o040755,
            ownerUserID: 501,
            ownerGroupID: 20,
            size: 128,
            allocatedBytes: 512,
            modificationSeconds: 1,
            modificationNanoseconds: 0
        ),
        activityFingerprint: try DomainToken(
            validating: "activity.retention-fixture"
        ),
        catalogVersion: try DomainToken(validating: "catalog-fixture-v1")
    )
}
