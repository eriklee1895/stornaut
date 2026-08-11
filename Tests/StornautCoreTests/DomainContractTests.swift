import Foundation
import Testing
@testable import StornautCore

@Test
func domainFixturesRoundTripWithExplicitSchemaVersion() throws {
    let session: ScanSession = try loadDomainFixture("scan-session-v1")
    let classification: Classification = try loadDomainFixture(
        "classification-v1"
    )
    let evidence: EvidenceRecord = try loadDomainFixture("evidence-v1")
    let plan: CleanupPlan = try loadDomainFixture("cleanup-plan-v1")
    let decision: PolicyDecision = try loadDomainFixture(
        "policy-decision-v1"
    )
    let manifest: CleanupManifest = try loadDomainFixture(
        "cleanup-manifest-v1"
    )
    let accounting: SpaceAccounting = try loadDomainFixture("accounting-v1")

    try expectStableRoundTrip(session)
    try expectStableRoundTrip(classification)
    try expectStableRoundTrip(evidence)
    try expectStableRoundTrip(plan)
    try expectStableRoundTrip(decision)
    try expectStableRoundTrip(manifest)
    try expectStableRoundTrip(accounting)

    #expect(session.schemaVersion == .v1)
    #expect(classification.schemaVersion == .v1)
    #expect(evidence.schemaVersion == .v1)
    #expect(plan.schemaVersion == .v1)
    #expect(decision.schemaVersion == .v1)
    #expect(manifest.schemaVersion == .v1)
    #expect(accounting.schemaVersion == .v1)
}

@Test
func reclaimDispositionHasExactlyTheApprovedValues() {
    #expect(
        ReclaimDisposition.allCases.map(\.rawValue) == [
            "readyToReclaim",
            "reviewRecommended",
            "protected",
            "unknown",
        ]
    )
}

@Test
func riskConfidenceAndDispositionRemainIndependent() throws {
    let classification: Classification = try loadDomainFixture(
        "classification-v1"
    )

    #expect(classification.disposition == .reviewRecommended)
    #expect(classification.risk == .high)
    #expect(classification.confidence == .low)
}

@Test
func cancelledSessionRetainsCompletedAndUnfinishedScopes() throws {
    let session: ScanSession = try loadDomainFixture("scan-session-v1")

    #expect(session.terminalState == .cancelled)
    #expect(session.completedScopes.count == 2)
    #expect(session.unfinishedScopes.count == 1)
    #expect(session.unfinishedScopes[0].reason == .cancelled)
}

@Test
func unmeasurableAccountingCanHaveNoByteEstimate() throws {
    let accounting: SpaceAccounting = try loadDomainFixture("accounting-v1")

    #expect(accounting.unmeasurable.status == .unmeasurable)
    #expect(accounting.unmeasurable.bytes == nil)
    #expect(accounting.free.status == .measured)
    #expect(accounting.free.bytes != nil)
}

@Test
func cleanupPlanContainsOnlyNonExecutableProposals() throws {
    let plan: CleanupPlan = try loadDomainFixture("cleanup-plan-v1")
    let encoded = try DomainJSON.encode(plan)
    let json = String(decoding: encoded, as: UTF8.self)

    #expect(plan.items.count == 2)
    #expect(plan.items[0].proposedAction == .moveToTrash)
    #expect(
        plan.items[1].proposedAction
            == .registeredAction(
                id: try DomainToken(validating: "fixture.unavailable-action")
            )
    )
    #expect(!json.contains("targetURL"))
    #expect(!json.contains("executable"))
    #expect(!json.contains("arguments"))
    #expect(!json.contains("shell"))
}

@Test
func minimalManifestExcludesEvidenceAndContentPayloads() throws {
    let data = try fixtureData(
        directory: "Domain",
        name: "cleanup-manifest-v1"
    )
    let manifest = try DomainJSON.decode(CleanupManifest.self, from: data)
    let json = String(decoding: try DomainJSON.encode(manifest), as: UTF8.self)
        .lowercased()

    #expect(manifest.records.count == 1)
    #expect(
        manifest.systemObservation?.source.rawValue
            == "fixture.volume.available"
    )
    #expect(
        manifest.systemObservation?.freeBytesBefore.value == 8_589_934_592
    )
    #expect(
        manifest.systemObservation?.freeBytesAfter.value == 8_589_938_688
    )
    #expect(manifest.records[0].logicalBytesBefore.value == 8_388_608)
    #expect(manifest.records[0].logicalBytesAfter?.value == 0)
    #expect(!json.contains("evidence"))
    #expect(!json.contains("probe"))
    #expect(!json.contains("snippet"))
    #expect(!json.contains("rawcontent"))
    #expect(!json.contains("canonicalpath"))
}

@Test
func byteCountsRejectNegativeAndOverflowingJSON() {
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            ByteCount.self,
            from: Data("-1".utf8)
        )
    }
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            ByteCount.self,
            from: Data("9223372036854775808".utf8)
        )
    }
}

@Test
func identifiersRejectInvalidPrefixUnicodeAndLength() {
    for value in [
        "wrong-fixture",
        "scan-",
        "scan-含义",
        "scan-\(String(repeating: "a", count: 130))",
    ] {
        #expect(throws: (any Error).self) {
            _ = try DomainJSON.decode(
                ScanSessionID.self,
                from: try JSONEncoder().encode(value)
            )
        }
    }
}

@Test
func domainTokensRejectPathsControlsAndUnboundedValues() {
    for value in [
        "/absolute/path",
        "relative/path",
        "line\nbreak",
        "contains space",
        String(repeating: "a", count: 129),
    ] {
        #expect(throws: (any Error).self) {
            _ = try DomainJSON.decode(
                DomainToken.self,
                from: try JSONEncoder().encode(value)
            )
        }
    }
}

@Test
func domainLabelsRejectControlsAndUnboundedValues() {
    for value in [
        "",
        "line\nbreak",
        String(repeating: "a", count: 257),
    ] {
        #expect(throws: (any Error).self) {
            _ = try DomainJSON.decode(
                DomainLabel.self,
                from: try JSONEncoder().encode(value)
            )
        }
    }
}

@Test
func persistedPathsRejectControlsAndUnboundedValues() {
    for value in [
        "",
        "nul\0path",
        String(repeating: "a", count: 16_385),
    ] {
        #expect(throws: (any Error).self) {
            _ = try DomainJSON.decode(
                PersistedPath.self,
                from: try JSONEncoder().encode(value)
            )
        }
    }
    #expect(PersistedPath(rawValue: "legal\nmacOS-name") != nil)
}

@Test
func scanSessionDecodeRejectsInvalidTimelineAndCompletedGaps() throws {
    let valid = try fixtureData(
        directory: "Domain",
        name: "scan-session-v1"
    )
    try expectMutatedJSONFails(ScanSession.self, data: valid) { object in
        object["finishedAt"] = 1
    }
    try expectMutatedJSONFails(ScanSession.self, data: valid) { object in
        object["terminalState"] = "completed"
    }
}

@Test
func scanAggregateCountsRejectOverflow() {
    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try ScanEntryCounts(
            total: Int.max,
            regularFiles: Int.max,
            directories: Int.max,
            symbolicLinks: 0,
            inaccessible: 0,
            other: 0
        )
    }
    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try ScanIssueCounts(
            permissionDenied: Int.max,
            mountBoundary: Int.max,
            userExcluded: 0,
            metadataUnavailable: 0,
            directoryReadFailed: 0
        )
    }
    #expect(throws: DomainContractError.invalidMeasurement) {
        _ = try QuickScanDispositionCounts(
            readyToReclaim: Int.max,
            reviewRecommended: Int.max,
            protected: 0,
            unknown: 0
        )
    }
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            ScanEntryCounts.self,
            from: Data(
                """
                {"total":1,"regularFiles":1,"directories":1,\
                "symbolicLinks":0,"inaccessible":0,"other":0}
                """.utf8
            )
        )
    }
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            ScanIssueCounts.self,
            from: Data(
                """
                {"permissionDenied":-1,"mountBoundary":0,\
                "userExcluded":0,"metadataUnavailable":0,\
                "directoryReadFailed":0}
                """.utf8
            )
        )
    }
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            QuickScanDispositionCounts.self,
            from: Data(
                """
                {"readyToReclaim":-1,"reviewRecommended":1,\
                "protected":0,"unknown":0}
                """.utf8
            )
        )
    }
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            ScanAggregate.self,
            from: Data(
                """
                {"entries":{"total":1,"regularFiles":1,"directories":0,\
                "symbolicLinks":0,"inaccessible":0,"other":0},\
                "issues":{"permissionDenied":1,"mountBoundary":1,\
                "userExcluded":0,"metadataUnavailable":0,\
                "directoryReadFailed":0},"logicalFileBytes":0,\
                "allocatedFileBytes":0}
                """.utf8
            )
        )
    }
}

@Test
func planManifestAndAccountingDecodeEnforceInvariants() throws {
    try expectMutatedJSONFails(
        CleanupPlan.self,
        data: fixtureData(directory: "Domain", name: "cleanup-plan-v1")
    ) { object in
        var items = try #require(object["items"] as? [[String: Any]])
        items[0]["allocatedBytes"] = NSNull()
        object["items"] = items
    }
    try expectMutatedJSONFails(
        CleanupPlan.self,
        data: fixtureData(directory: "Domain", name: "cleanup-plan-v1")
    ) { object in
        object["expiresAt"] = 1
    }
    try expectMutatedJSONFails(
        CleanupManifest.self,
        data: fixtureData(
            directory: "Domain",
            name: "cleanup-manifest-v1"
        )
    ) { object in
        object["expiresAt"] = 1
    }
    try expectMutatedJSONFails(
        CleanupManifest.self,
        data: fixtureData(
            directory: "Domain",
            name: "cleanup-manifest-v1"
        )
    ) { object in
        var records = try #require(object["records"] as? [[String: Any]])
        records[0]["policyDisposition"] = "protected"
        object["records"] = records
    }
    try expectMutatedJSONFails(
        CleanupManifest.self,
        data: fixtureData(
            directory: "Domain",
            name: "cleanup-manifest-v1"
        )
    ) { object in
        var observation = try #require(
            object["systemObservation"] as? [String: Any]
        )
        observation["sampledAfterAt"] = 1
        object["systemObservation"] = observation
    }
    try expectMutatedJSONFails(
        CleanupManifest.self,
        data: fixtureData(
            directory: "Domain",
            name: "cleanup-manifest-v1"
        )
    ) { object in
        var observation = try #require(
            object["systemObservation"] as? [String: Any]
        )
        observation["freeSpaceDelta"] = ["value": 1]
        object["systemObservation"] = observation
    }
    try expectMutatedJSONFails(
        CleanupManifest.self,
        data: fixtureData(
            directory: "Domain",
            name: "cleanup-manifest-v1"
        )
    ) { object in
        var records = try #require(object["records"] as? [[String: Any]])
        records[0]["errorCode"] = "unexpected.error"
        object["records"] = records
    }
    try expectMutatedJSONFails(
        CleanupManifest.self,
        data: fixtureData(
            directory: "Domain",
            name: "cleanup-manifest-v1"
        )
    ) { object in
        var records = try #require(object["records"] as? [[String: Any]])
        records[0]["logicalBytesAfter"] = NSNull()
        object["records"] = records
    }
    try expectMutatedJSONFails(
        SpaceAccounting.self,
        data: fixtureData(directory: "Domain", name: "accounting-v1")
    ) { object in
        var free = try #require(object["free"] as? [String: Any])
        free["bytes"] = NSNull()
        object["free"] = free
    }
    try expectMutatedJSONFails(
        SpaceAccounting.self,
        data: fixtureData(directory: "Domain", name: "accounting-v1")
    ) { object in
        var unknown = try #require(object["unknown"] as? [String: Any])
        unknown["status"] = "unknown"
        object["unknown"] = unknown
    }
}

@Test
func policyAllowsOnlyReadyOrExplicitReviewDisposition() throws {
    let token = try DomainToken(validating: "policy.userConfirmedReview")
    let ready = try PolicyDecision(
        id: try PolicyDecisionID(validating: "decision-ready"),
        planID: try CleanupPlanID(validating: "plan-fixture"),
        itemID: try CleanupPlanItemID(validating: "plan-item-ready"),
        outcome: .allowed,
        disposition: .readyToReclaim,
        reasonKeys: [token],
        evaluatedAt: Date(timeIntervalSince1970: 1)
    )
    let review = try PolicyDecision(
        id: try PolicyDecisionID(validating: "decision-review"),
        planID: try CleanupPlanID(validating: "plan-fixture"),
        itemID: try CleanupPlanItemID(validating: "plan-item-review"),
        outcome: .allowed,
        disposition: .reviewRecommended,
        reasonKeys: [token],
        evaluatedAt: Date(timeIntervalSince1970: 1)
    )

    #expect(ready.outcome == .allowed)
    #expect(review.outcome == .allowed)
    #expect(throws: (any Error).self) {
        _ = try PolicyDecision(
            id: try PolicyDecisionID(validating: "decision-protected"),
            planID: try CleanupPlanID(validating: "plan-fixture"),
            itemID: try CleanupPlanItemID(validating: "plan-item-protected"),
            outcome: .allowed,
            disposition: .protected,
            reasonKeys: [token],
            evaluatedAt: Date(timeIntervalSince1970: 1)
        )
    }
    #expect(throws: (any Error).self) {
        _ = try PolicyDecision(
            id: try PolicyDecisionID(validating: "decision-denied"),
            planID: try CleanupPlanID(validating: "plan-fixture"),
            itemID: try CleanupPlanItemID(validating: "plan-item-denied"),
            outcome: .denied,
            disposition: .unknown,
            reasonKeys: [],
            evaluatedAt: Date(timeIntervalSince1970: 1)
        )
    }
}

@Test
func classificationDecodeRejectsMissingEvidenceOutsideRequirements() throws {
    let data = try fixtureData(
        directory: "Domain",
        name: "classification-v1"
    )
    try expectMutatedJSONFails(Classification.self, data: data) { object in
        object["missingEvidenceKeys"] = ["evidence.not-required"]
    }
    try expectMutatedJSONFails(Classification.self, data: data) { object in
        object["producer"] = "invalid\nproducer"
    }
}

@Test
func activityProtectionPreservesTheOriginalArtifactCategory() throws {
    let classification = try Classification(
        id: ClassificationID(validating: "classification-active-cache"),
        snapshotID: SnapshotID(validating: "snapshot-active-cache"),
        ruleID: DomainToken(validating: "cache.fixture"),
        producer: DomainLabel(validating: "Fixture cache"),
        category: .packageAndBuildCaches,
        disposition: .protected,
        risk: .high,
        confidence: .high,
        recovery: RecoveryGuidance(
            methodKey: DomainToken(validating: "recovery.fixture.cache"),
            cost: .low
        ),
        requiredEvidenceKeys: [
            DomainToken(validating: "activity.process.inactive"),
        ],
        missingEvidenceKeys: [],
        catalogVersion: DomainToken(validating: "catalog-fixture-v1"),
        classifiedAt: Date(timeIntervalSince1970: 1)
    )

    #expect(classification.category == .packageAndBuildCaches)
    #expect(classification.disposition == .protected)
}

@Test
func persistedSnapshotExcludesTransportProgress() throws {
    let data = try fixtureData(
        directory: "QuickScan",
        name: "anonymous-developer-tree"
    )
    let object = try #require(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    let snapshots = try #require(object["snapshots"] as? [[String: Any]])

    #expect(snapshots.allSatisfy { $0["progress"] == nil })
}

@Test
func snapshotDecodeRejectsPathKindAndByteContradictions() throws {
    let data = try fixtureData(
        directory: "QuickScan",
        name: "anonymous-developer-tree"
    )
    let fixture = try DomainJSON.decode(
        AnonymousDeveloperTreeFixture.self,
        from: data
    )
    let snapshot = try #require(fixture.snapshots.first)
    let encoded = try DomainJSON.encode(snapshot)

    try expectMutatedJSONFails(PathSnapshot.self, data: encoded) { object in
        object["relativePath"] = "../escape"
    }
    try expectMutatedJSONFails(PathSnapshot.self, data: encoded) { object in
        object["kind"] = "regularFile"
    }
    try expectMutatedJSONFails(PathSnapshot.self, data: encoded) { object in
        object["logicalByteCount"] = 1
    }
    try expectMutatedJSONFails(PathSnapshot.self, data: encoded) { object in
        object["modifiedAt"] = 1
    }
    try expectMutatedJSONFails(PathSnapshot.self, data: encoded) { object in
        var identity = try #require(object["fileIdentity"] as? [String: Any])
        identity["modificationNanoseconds"] = 1_000_000_000
        object["fileIdentity"] = identity
    }
}

@Test
func aggregateIdentifiersHaveDistinctTypesAndPrefixes() throws {
    let session: ScanSession = try loadDomainFixture("scan-session-v1")
    let classification: Classification = try loadDomainFixture(
        "classification-v1"
    )

    #expect(session.id.rawValue.hasPrefix("scan-"))
    #expect(classification.id.rawValue.hasPrefix("classification-"))
    #expect(
        String(reflecting: type(of: session.id))
            != String(reflecting: type(of: classification.id))
    )
}

@Test
func anonymousDeveloperTreeCoversRequiredSafetyShapes() throws {
    let data = try fixtureData(
        directory: "QuickScan",
        name: "anonymous-developer-tree"
    )
    let fixture = try DomainJSON.decode(
        AnonymousDeveloperTreeFixture.self,
        from: data
    )

    #expect(fixture.fixtureVersion == 1)
    #expect(fixture.session.terminalState == .partial)
    #expect(fixture.session.unfinishedScopes.count == 1)
    #expect(
        Set(fixture.shapes) == [
            .nestedProjectArtifacts,
            .packageCache,
            .dirtyActiveProject,
            .unknownLargeConsumer,
            .protectedSensitivePath,
            .permissionLimitedSubtree,
            .overlappingCandidates,
            .partialCancelledSession,
        ]
    )
    #expect(fixture.snapshots.count == 8)
    #expect(
        fixture.classifications.contains {
            $0.disposition == .protected
        }
    )
    #expect(
        fixture.classifications.contains {
            $0.disposition == .unknown
        }
    )
    #expect(
        fixture.accounting.unmeasurable.bytes == nil
    )

    let serialized = String(decoding: data, as: UTF8.self)
    #expect(!serialized.contains("/Users/"))
    #expect(!serialized.lowercased().contains("secret"))
    #expect(!serialized.contains("erik"))
}

private func expectStableRoundTrip<T>(
    _ value: T
) throws where T: Codable & Equatable {
    let first = try DomainJSON.encode(value)
    let decoded = try DomainJSON.decode(T.self, from: first)
    let second = try DomainJSON.encode(decoded)
    #expect(decoded == value)
    #expect(first == second)
}

private func loadDomainFixture<T: Decodable>(
    _ name: String
) throws -> T {
    try DomainJSON.decode(
        T.self,
        from: fixtureData(directory: "Domain", name: name)
    )
}

private func fixtureData(
    directory: String,
    name: String
) throws -> Data {
    let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try Data(
        contentsOf: repositoryRoot
            .appending(path: "Tests/Fixtures/\(directory)/\(name).json")
    )
}

private func expectMutatedJSONFails<T: Decodable>(
    _ type: T.Type,
    data: Data,
    mutate: (inout [String: Any]) throws -> Void
) throws {
    var object = try #require(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    try mutate(&object)
    let mutated = try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys]
    )
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(type, from: mutated)
    }
}

private struct AnonymousDeveloperTreeFixture: Codable, Equatable {
    let fixtureVersion: Int
    let shapes: [AnonymousFixtureShape]
    let session: ScanSession
    let snapshots: [PathSnapshot]
    let classifications: [Classification]
    let evidence: [EvidenceRecord]
    let accounting: SpaceAccounting
}

private enum AnonymousFixtureShape: String, Codable, Hashable {
    case nestedProjectArtifacts
    case packageCache
    case dirtyActiveProject
    case unknownLargeConsumer
    case protectedSensitivePath
    case permissionLimitedSubtree
    case overlappingCandidates
    case partialCancelledSession
}
