import Foundation
import Testing
@testable import StornautCore

@Test
func cleanupJournalPreparedStateIsBoundedAndPathFree() throws {
    let journal = try CleanupPersistenceTestSupport.journal()
    #expect(journal.schemaVersion == .v2)
    #expect(journal.stage == .prepared)
    #expect(journal.retentionClass == .evidenceLinked)
    #expect(journal.entries.count == 2)
    #expect(journal.entries.allSatisfy { $0.state == .prepared })

    let json = String(
        decoding: try DomainJSON.encode(journal),
        as: UTF8.self
    ).lowercased()
    #expect(!json.contains("path"))
    #expect(!json.contains("url"))
    #expect(!json.contains("authorization"))
    #expect(!json.contains("capability"))
    #expect(!json.contains("stdout"))
    #expect(!json.contains("stderr"))
}

@Test
func cleanupJournalRejectsInvalidStartedPrefixAndRetention() throws {
    let plan = try CleanupPersistenceTestSupport.plan()
    let prepared = try CleanupPersistenceTestSupport.journalEntry(
        item: plan.items[0]
    )
    let started = try CleanupPersistenceTestSupport.journalEntry(
        item: plan.items[1],
        state: .started
    )
    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try CleanupRunJournal(
            id: CleanupRunID(rawValue: "run-invalid-prefix")!,
            planID: plan.id,
            manifestID: CleanupManifestID(
                rawValue: "manifest-invalid-prefix"
            )!,
            selectionGeneration: 1,
            selectionFingerprint: DomainToken(
                rawValue: "selection.invalid-prefix"
            )!,
            stage: .actionStarted,
            retentionClass: .audit,
            stopAfterCurrentRequested: false,
            entries: [prepared, started],
            createdAt: CleanupPersistenceTestSupport.createdAt,
            updatedAt: CleanupPersistenceTestSupport.updatedAt,
            expiresAt: CleanupPersistenceTestSupport.createdAt
                .addingTimeInterval(90 * 86_400)
        )
    }

    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try CleanupRunJournal(
            id: CleanupRunID(rawValue: "run-wrong-retention")!,
            planID: plan.id,
            manifestID: CleanupManifestID(
                rawValue: "manifest-wrong-retention"
            )!,
            selectionGeneration: 1,
            selectionFingerprint: DomainToken(
                rawValue: "selection.wrong-retention"
            )!,
            stage: .actionStarted,
            retentionClass: .evidenceLinked,
            stopAfterCurrentRequested: false,
            entries: [
                try CleanupPersistenceTestSupport.journalEntry(
                    item: plan.items[0],
                    state: .started
                ),
                try CleanupPersistenceTestSupport.journalEntry(
                    item: plan.items[1]
                ),
            ],
            createdAt: CleanupPersistenceTestSupport.createdAt,
            updatedAt: CleanupPersistenceTestSupport.updatedAt,
            expiresAt: CleanupPersistenceTestSupport.createdAt
                .addingTimeInterval(7 * 86_400)
        )
    }
}

@Test
func cleanupJournalTransitionIsMonotonicAndIdentityBound() throws {
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
    #expect(prepared.canTransition(to: started))
    #expect(!started.canTransition(to: prepared))

    let differentRun = try CleanupRunJournal(
        id: CleanupRunID(rawValue: "run-different")!,
        planID: started.planID,
        manifestID: started.manifestID,
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
    #expect(!started.canTransition(to: differentRun))
}

@Test
func cleanupJournalStrictDecoderRejectsPathAndAuthorizationInjection()
    throws
{
    let journal = try CleanupPersistenceTestSupport.journal()
    var object = try #require(
        JSONSerialization.jsonObject(
            with: DomainJSON.encode(journal)
        ) as? [String: Any]
    )
    object["originalPath"] = "/Users/fixture/.npm/_cacache"
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            CleanupRunJournal.self,
            from: try JSONSerialization.data(withJSONObject: object)
        )
    }
    object.removeValue(forKey: "originalPath")
    object["authorization"] = "replayable"
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            CleanupRunJournal.self,
            from: try JSONSerialization.data(withJSONObject: object)
        )
    }
}
