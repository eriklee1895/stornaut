import Foundation
import Testing
@testable import StornautCore

@Test
func localKnowledgeAcceptsOnlyClosedUserConfirmedPayloads() throws {
    let binding = try makeKnowledgeBinding()
    let facts = [
        try LocalKnowledgeFact(
            id: LocalKnowledgeID(validating: "knowledge-producer"),
            payload: .producerMapping(
                try ProducerMappingKnowledge(
                    producer: DomainLabel(validating: "Fixture Builder")
                )
            ),
            binding: binding,
            provenance: .userConfirmed,
            observedAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 11)
        ),
        try LocalKnowledgeFact(
            id: LocalKnowledgeID(validating: "knowledge-exclusion"),
            payload: .pathPreference(.exclude),
            binding: binding,
            provenance: .userConfirmed,
            observedAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 11)
        ),
        try LocalKnowledgeFact(
            id: LocalKnowledgeID(validating: "knowledge-keep"),
            payload: .keepDecision,
            binding: binding,
            provenance: .userConfirmed,
            observedAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 11)
        ),
        try LocalKnowledgeFact(
            id: LocalKnowledgeID(validating: "knowledge-recovery"),
            payload: .recoveryMethod(
                VerifiedRecoveryKnowledge(
                    methodKey: DomainToken(
                        validating: "recovery.fixture.rebuild"
                    ),
                    cost: .medium
                )
            ),
            binding: binding,
            provenance: .userConfirmed,
            observedAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 11)
        ),
    ]

    for fact in facts {
        let data = try DomainJSON.encode(fact)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(object["disposition"] == nil)
        #expect(
            String(decoding: data, as: UTF8.self)
                .contains("readyToReclaim") == false
        )
        #expect(
            try DomainJSON.decode(
                LocalKnowledgeFact.self,
                from: data
            ) == fact
        )
    }
}

@Test
func localKnowledgeRejectsAgentProvenanceAndInvalidTimeline() throws {
    let valid = try LocalKnowledgeFact(
        id: LocalKnowledgeID(validating: "knowledge-confirmed"),
        payload: .keepDecision,
        binding: makeKnowledgeBinding(),
        provenance: .userConfirmed,
        observedAt: Date(timeIntervalSince1970: 10),
        updatedAt: Date(timeIntervalSince1970: 11)
    )
    var object = try #require(
        JSONSerialization.jsonObject(
            with: DomainJSON.encode(valid)
        ) as? [String: Any]
    )
    object["provenance"] = "agentInferred"
    let inferred = try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys]
    )

    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            LocalKnowledgeFact.self,
            from: inferred
        )
    }
    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try LocalKnowledgeFact(
            id: LocalKnowledgeID(validating: "knowledge-invalid-time"),
            payload: .keepDecision,
            binding: makeKnowledgeBinding(),
            provenance: .userConfirmed,
            observedAt: Date(timeIntervalSince1970: 12),
            updatedAt: Date(timeIntervalSince1970: 11)
        )
    }
}

@Test
func localKnowledgeMarksEachChangedBindingStaleIndependently() throws {
    let binding = try makeKnowledgeBinding()
    let fact = try LocalKnowledgeFact(
        id: LocalKnowledgeID(validating: "knowledge-staleness"),
        payload: .keepDecision,
        binding: binding,
        provenance: .userConfirmed,
        observedAt: Date(timeIntervalSince1970: 10),
        updatedAt: Date(timeIntervalSince1970: 11)
    )
    let current = LocalKnowledgeContext(
        scope: binding.scope,
        fileIdentity: binding.fileIdentity,
        activityFingerprint: binding.activityFingerprint,
        catalogVersion: binding.catalogVersion
    )

    #expect(
        LocalKnowledgeApplicability.evaluate(
            fact,
            in: current
        ).staleReasons.isEmpty
    )

    let changedScope = LocalKnowledgeContext(
        scope: PersistedPath(rawValue: "/tmp/fixture/other")!,
        fileIdentity: current.fileIdentity,
        activityFingerprint: current.activityFingerprint,
        catalogVersion: current.catalogVersion
    )
    let changedIdentity = LocalKnowledgeContext(
        scope: current.scope,
        fileIdentity: try fixtureIdentity(inode: 9),
        activityFingerprint: current.activityFingerprint,
        catalogVersion: current.catalogVersion
    )
    let changedActivity = LocalKnowledgeContext(
        scope: current.scope,
        fileIdentity: current.fileIdentity,
        activityFingerprint: DomainToken(rawValue: "activity.changed")!,
        catalogVersion: current.catalogVersion
    )
    let changedCatalog = LocalKnowledgeContext(
        scope: current.scope,
        fileIdentity: current.fileIdentity,
        activityFingerprint: current.activityFingerprint,
        catalogVersion: DomainToken(rawValue: "catalog-v2")!
    )

    #expect(
        LocalKnowledgeApplicability.evaluate(
            fact,
            in: changedScope
        ).staleReasons == [.scopeChanged]
    )
    #expect(
        LocalKnowledgeApplicability.evaluate(
            fact,
            in: changedIdentity
        ).staleReasons == [.fileIdentityChanged]
    )
    #expect(
        LocalKnowledgeApplicability.evaluate(
            fact,
            in: changedActivity
        ).staleReasons == [.activityChanged]
    )
    #expect(
        LocalKnowledgeApplicability.evaluate(
            fact,
            in: changedCatalog
        ).staleReasons == [.catalogVersionChanged]
    )
}

@Test
func localKnowledgeStoreRetainsStaleFactAndReturnsAssessment() async throws {
    let store = try LocalKnowledgeStore(configuration: .memory)
    let binding = try makeKnowledgeBinding()
    let fact = try LocalKnowledgeFact(
        id: LocalKnowledgeID(validating: "knowledge-retained"),
        payload: .recoveryMethod(
            VerifiedRecoveryKnowledge(
                methodKey: DomainToken(
                    validating: "recovery.fixture.rebuild"
                ),
                cost: .low
            )
        ),
        binding: binding,
        provenance: .userConfirmed,
        observedAt: Date(timeIntervalSince1970: 10),
        updatedAt: Date(timeIntervalSince1970: 11)
    )
    try await store.save(fact)

    let assessment = try await store.assessment(
        id: fact.id,
        context: LocalKnowledgeContext(
            scope: binding.scope,
            fileIdentity: binding.fileIdentity,
            activityFingerprint: DomainToken(
                rawValue: "activity.changed"
            )!,
            catalogVersion: binding.catalogVersion
        )
    )

    #expect(assessment?.fact == fact)
    #expect(assessment?.staleReasons == [.activityChanged])
    #expect(try await store.fact(id: fact.id) == fact)
    #expect(
        try await store.facts(limit: 10, offset: 0).records == [fact]
    )
}

@Test
func localKnowledgeRejectsPayloadLargerThanStructuredLimits() throws {
    #expect(throws: DomainContractError.invalidToken) {
        _ = try ProducerMappingKnowledge(
            producer: DomainLabel(
                validating: String(repeating: "p", count: 257)
            )
        )
    }
}

private func makeKnowledgeBinding() throws -> LocalKnowledgeBinding {
    LocalKnowledgeBinding(
        scope: try PersistedPath(validating: "/tmp/fixture/cache"),
        fileIdentity: try fixtureIdentity(inode: 7),
        activityFingerprint: try DomainToken(
            validating: "activity.fixture-v1"
        ),
        catalogVersion: try DomainToken(
            validating: "builtin-runtime-tool-residue-v1"
        )
    )
}

private func fixtureIdentity(inode: UInt64) throws -> FileIdentity {
    try FileIdentity(
        device: 1,
        inode: inode,
        mode: 0o040755,
        ownerUserID: 501,
        ownerGroupID: 20,
        size: 128,
        allocatedBytes: 512,
        modificationSeconds: 1_786_310_000,
        modificationNanoseconds: 0
    )
}
