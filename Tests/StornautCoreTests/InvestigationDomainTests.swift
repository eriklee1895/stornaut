import CryptoKit
import Foundation
import Testing
@testable import StornautCore

@Test
func investigationIdentifiersUseClosedPrefixesAndStrictTokens() throws {
    let investigation = try InvestigationID(
        validating: "investigation-fixture"
    )
    let run = try InvestigationRunID(
        validating: "investigation-run-fixture"
    )
    let report = try InvestigationReportID(
        validating: "investigation-report-fixture"
    )

    #expect(investigation.rawValue == "investigation-fixture")
    #expect(run.rawValue == "investigation-run-fixture")
    #expect(report.rawValue == "investigation-report-fixture")

    for value in [
        "wrong-fixture",
        "investigation-",
        "investigation-含义",
        "investigation-\(String(repeating: "a", count: 129))",
    ] {
        #expect(throws: DomainContractError.self) {
            _ = try InvestigationID(validating: value)
        }
    }
}

@Test
func legacyInvestigationTargetV1IsExplicitlyNamedAndStrictlyDecoded() throws {
    let fixture = Data(
        """
        {
          "schemaVersion": 1,
          "id": "target-legacy",
          "snapshotID": "snapshot-legacy",
          "expectedBytes": null,
          "reasonKey": "reason.legacy",
          "createdAt": 1722470400000
        }
        """.utf8
    )

    let target = try DomainJSON.decode(
        LegacyInvestigationTargetV1.self,
        from: fixture
    )

    #expect(target.schemaVersion == .v1)
    #expect(target.id.rawValue == "target-legacy")
    #expect(target.snapshotID.rawValue == "snapshot-legacy")
    #expect(target.expectedBytes == nil)
    #expect(target.reasonKey.rawValue == "reason.legacy")

    let unknownKeyFixture = Data(
        """
        {
          "schemaVersion": 1,
          "id": "target-legacy",
          "snapshotID": "snapshot-legacy",
          "expectedBytes": null,
          "reasonKey": "reason.legacy",
          "createdAt": 1722470400000,
          "authority": "none"
        }
        """.utf8
    )
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            LegacyInvestigationTargetV1.self,
            from: unknownKeyFixture
        )
    }
}

@Test
func investigationFingerprintRequiresAllSHA256Bytes() throws {
    let bytes = Data(0..<32)
    let fingerprint = try InvestigationFingerprint(validating: bytes)

    #expect(fingerprint.bytes == bytes)
    #expect(
        fingerprint.hex
            == "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
    )
    #expect(throws: InvestigationDomainError.invalidFingerprint) {
        _ = try InvestigationFingerprint(validating: Data(repeating: 0, count: 31))
    }
    #expect(throws: InvestigationDomainError.invalidFingerprint) {
        _ = try InvestigationFingerprint(validating: Data(repeating: 0, count: 33))
    }
}

@Test
func investigationTargetIdentityAndPriorityMatchNormativeVector() throws {
    let target = try fixtureInvestigationTarget()
    let identity = try InvestigationCanonicalCodec.targetIdentityBytes(
        scanSessionID: target.scanSessionID,
        scanScopeID: target.scanScopeID,
        kind: target.kind,
        sourceBinding: target.sourceBinding
    )

    #expect(identity.count == 303)
    #expect(
        identity.hexString
            == """
            53544f524e4155542d494e562d43414e4f4e2d310020000000000000002073746f\
            726e6175742e696e7665737469676174696f6e2e7461726765742e763240000000\
            000000000500010000000000000009100000000000000002000200000000000000\
            1520000000000000000c7363616e2d666978747572650003000000000000001620\
            000000000000000d73636f70652d66697874757265000400000000000000222000\
            00000000000019756e6b6e6f776e2d6c617267652d636f6e73756d65722d763100\
            050000000000000060400000000000000004000100000000000000142000000000\
            0000000b736e617073686f742d7631000200000000000000192000000000000000\
            10736e617073686f742d6669787475726500030000000000000001000004000000\
            000000000100
            """
    )
    #expect(
        target.id.rawValue
            == "target-69d186b12fa1322c34f07da86e4ab6be9e370d7f777f0e12ea7d41049f46b384"
    )
    try InvestigationCanonicalCodec.validateTargetIdentityBytes(identity)
    #expect(target.priority == .init(tier: .measured, score: 2_764_800))
    #expect(target.schemaVersion == .v2)
    #expect(target.reasonKeys.map(\.rawValue) == [
        "reason.rule-miss",
        "reason.unknown-producer",
    ])
}

@Test
func investigationTargetDistinguishesMeasuredZeroFromUnknown() throws {
    let measured = try InvestigationTarget(
        scanSessionID: ScanSessionID(rawValue: "scan-measured")!,
        scanScopeID: ScanScopeID(rawValue: "scope-measured")!,
        sourceBinding: .snapshot(
            SnapshotID(rawValue: "snapshot-measured")!
        ),
        kind: .staleOrInsufficientEvidence,
        reasonKeys: [DomainToken(rawValue: "reason.measured")!],
        expectedAllocatedBytes: ByteCount(0),
        uncertaintyPermille: 700,
        relevancePermille: 700,
        investigationCostPermille: 300,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
    let unknown = try InvestigationTarget(
        scanSessionID: ScanSessionID(rawValue: "scan-unknown")!,
        scanScopeID: ScanScopeID(rawValue: "scope-unknown")!,
        sourceBinding: .spaceLedger(.unknownResidual),
        kind: .unexplainedSpaceGap,
        reasonKeys: [DomainToken(rawValue: "reason.unknown")!],
        expectedAllocatedBytes: nil,
        uncertaintyPermille: 1_000,
        relevancePermille: 700,
        investigationCostPermille: 800,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )

    #expect(measured.expectedAllocatedBytes == ByteCount(0))
    #expect(measured.priority == .init(tier: .measured, score: 0))
    #expect(unknown.expectedAllocatedBytes == nil)
    #expect(unknown.priority == .init(tier: .unmeasurable, score: 875))
}

@Test
func investigationTargetRejectsNonCanonicalReasonsAndInvalidFactors() throws {
    let sessionID = ScanSessionID(rawValue: "scan-invalid")!
    let scopeID = ScanScopeID(rawValue: "scope-invalid")!
    let binding = InvestigationSourceBinding.classification(
        classificationID: ClassificationID(
            rawValue: "classification-invalid"
        )!,
        snapshotID: SnapshotID(rawValue: "snapshot-invalid")!
    )
    let createdAt = Date(timeIntervalSince1970: 1_800_000_000)

    for reasons in [
        ["reason.longer", "a"],
        ["reason.same", "reason.same"],
        [],
    ] {
        #expect(throws: InvestigationDomainError.invalidCanonicalSet) {
            _ = try InvestigationTarget(
                scanSessionID: sessionID,
                scanScopeID: scopeID,
                sourceBinding: binding,
                kind: .unknownProducer,
                reasonKeys: reasons.map { DomainToken(rawValue: $0)! },
                expectedAllocatedBytes: ByteCount(1),
                uncertaintyPermille: 850,
                relevancePermille: 700,
                investigationCostPermille: 400,
                createdAt: createdAt
            )
        }
    }

    for invalidFactor in [UInt64(0), 1_001] {
        #expect(throws: InvestigationDomainError.invalidFactor) {
            _ = try InvestigationTarget(
                scanSessionID: sessionID,
                scanScopeID: scopeID,
                sourceBinding: binding,
                kind: .unknownProducer,
                reasonKeys: [DomainToken(rawValue: "reason.valid")!],
                expectedAllocatedBytes: ByteCount(1),
                uncertaintyPermille: invalidFactor,
                relevancePermille: 700,
                investigationCostPermille: 400,
                createdAt: createdAt
            )
        }
    }
}

@Test
func investigationDomainRejectsNonFiniteAndOutOfRangeDates() throws {
    let sessionID = ScanSessionID(rawValue: "scan-invalid-date")!
    let scopeID = ScanScopeID(rawValue: "scope-invalid-date")!
    let binding = InvestigationSourceBinding.classification(
        classificationID: ClassificationID(
            rawValue: "classification-invalid-date"
        )!,
        snapshotID: SnapshotID(rawValue: "snapshot-invalid-date")!
    )
    let validDate = Date(timeIntervalSince1970: 1_800_000_000)
    let invalidDates = [
        Date(timeIntervalSince1970: .nan),
        Date(timeIntervalSince1970: .infinity),
        Date(timeIntervalSince1970: -.infinity),
        Date(timeIntervalSince1970: 9_223_372_036_855),
        Date(timeIntervalSince1970: -9_223_372_036_855),
    ]

    for invalidDate in invalidDates {
        #expect(throws: InvestigationDomainError.invalidPlan) {
            _ = try InvestigationTarget(
                scanSessionID: sessionID,
                scanScopeID: scopeID,
                sourceBinding: binding,
                kind: .unknownProducer,
                reasonKeys: [DomainToken(rawValue: "reason.invalid-date")!],
                expectedAllocatedBytes: ByteCount(1),
                uncertaintyPermille: 850,
                relevancePermille: 700,
                investigationCostPermille: 400,
                createdAt: invalidDate
            )
        }
    }

    let target = try InvestigationTarget(
        scanSessionID: sessionID,
        scanScopeID: scopeID,
        sourceBinding: binding,
        kind: .unknownProducer,
        reasonKeys: [DomainToken(rawValue: "reason.valid-date")!],
        expectedAllocatedBytes: ByteCount(1),
        uncertaintyPermille: 850,
        relevancePermille: 700,
        investigationCostPermille: 400,
        createdAt: validDate
    )
    let fingerprint = try InvestigationFingerprint(
        validating: Data(repeating: 7, count: 32)
    )
    for (createdAt, expiresAt) in [
        (Date(timeIntervalSince1970: .nan), validDate),
        (validDate, Date(timeIntervalSince1970: .infinity)),
        (Date(timeIntervalSince1970: 9_223_372_036_855), validDate),
    ] {
        #expect(throws: InvestigationDomainError.invalidPlan) {
            _ = try InvestigationPlan(
                id: InvestigationID(rawValue: "investigation-invalid-date")!,
                scanSessionID: sessionID,
                scanScopeID: scopeID,
                sourceFingerprint: fingerprint,
                budgetPreset: .focused,
                targets: [target],
                createdAt: createdAt,
                expiresAt: expiresAt,
                requestedCoveragePermille: 900,
                remainingUnknownByteThreshold: ByteCount(1_073_741_824),
                requiredCapabilities: InvestigationCapability.required
            )
        }
    }
}

@Test
func investigationPlanMatchesNormativeTargetSetAndPlanVectors() throws {
    let target = try fixtureInvestigationTarget()
    let sourceFingerprint = try InvestigationFingerprint(
        validatingHex:
            "318e1e01fb438c631a72056fa167fe0c94fffe8426adb6b25358e4cd3cfcd9df"
    )
    let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
    let plan = try InvestigationPlan(
        id: InvestigationID(rawValue: "investigation-fixture")!,
        scanSessionID: ScanSessionID(rawValue: "scan-fixture")!,
        scanScopeID: ScanScopeID(rawValue: "scope-fixture")!,
        sourceFingerprint: sourceFingerprint,
        budgetPreset: .focused,
        targets: [target],
        createdAt: createdAt,
        expiresAt: createdAt.addingTimeInterval(600),
        requestedCoveragePermille: 900,
        remainingUnknownByteThreshold: ByteCount(1_073_741_824),
        requiredCapabilities: InvestigationCapability.required
    )

    let targetSetBytes = try InvestigationCanonicalCodec.targetSetBytes(
        targets: plan.targets
    )
    #expect(targetSetBytes.count == 201)
    #expect(
        targetSetBytes.hexString
            == normalizedHex(
                """
                53544f524e4155542d494e562d43414e4f4e2d310020000000000000002473746f726e6175742e696e76657374696761
                74696f6e2e7461726765742d7365742e7631400000000000000002000100000000000000091000000000000000010002
                000000000000006130000000000000000100000000000000502000000000000000477461726765742d36396431383662
                313266613133323263333466303764613836653461623662653965333730643766373737663065313265613764343130
                343966343662333834
                """
            )
    )
    #expect(
        plan.targetSetFingerprint.hex
            == "67d25b16ccba49e35619fbfdd2d55f9eeba27aaf121a695c9bb877c9b779aacd"
    )
    #expect(
        Data(SHA256.hash(data: targetSetBytes)).hexString
            == "67d25b16ccba49e35619fbfdd2d55f9eeba27aaf121a695c9bb877c9b779aacd"
    )
    #expect(
        try InvestigationCanonicalCodec.decodeTargetSetBytes(targetSetBytes)
            == [target.id]
    )

    let planBytes = try InvestigationCanonicalCodec.planBytes(plan)
    #expect(planBytes.count == 1_553)
    #expect(
        planBytes.hexString
            == normalizedHex(
                """
                53544f524e4155542d494e562d43414e4f4e2d310020000000000000001e73746f726e6175742e696e76657374696761
                74696f6e2e706c616e2e763140000000000000000e000100000000000000091000000000000000010002000000000000
                001e200000000000000015696e7665737469676174696f6e2d6669787475726500030000000000000015200000000000
                00000c7363616e2d666978747572650004000000000000001620000000000000000d73636f70652d6669787475726500
                050000000000000029210000000000000020318e1e01fb438c631a72056fa167fe0c94fffe8426adb6b25358e4cd3cfc
                d9df0006000000000000001320000000000000000a666f63757365642d7631000700000000000000da40000000000000
                000b00010000000000000009100000008bb2c97000000200000000000000091000000000000000040003000000000000
                000910000000000000001000040000000000000009100000000000800000000500000000000000091000000000002000
                000006000000000000000910000000000010000000070000000000000009100000000000000002000800000000000000
                0910000000000000000200090000000000000009100000000000000020000a00000000000000091000000000000186a0
                000b00000000000000091000000000000400000008000000000000025b300000000000000001000000000000024a4000
                0000000000000d0001000000000000000910000000000000000200020000000000000050200000000000000047746172
                6765742d3639643138366231326661313332326333346630376461383665346162366265396533373064376637373766
                30653132656137643431303439663436623338340003000000000000001520000000000000000c7363616e2d66697874
                7572650004000000000000001620000000000000000d73636f70652d6669787475726500050000000000000022200000
                000000000019756e6b6e6f776e2d6c617267652d636f6e73756d65722d76310006000000000000006040000000000000
                00040001000000000000001420000000000000000b736e617073686f742d763100020000000000000019200000000000
                000010736e617073686f742d666978747572650003000000000000000100000400000000000000010000070000000000
                0000523000000000000000020000000000000019200000000000000010726561736f6e2e72756c652d6d697373000000
                0000000020200000000000000017726561736f6e2e756e6b6e6f776e2d70726f64756365720008000000000000000910
                0000000040000000000900000000000000091000000000000002ee000a0000000000000009100000000000000384000b
                00000000000000091000000000000000fa000c000000000000003a400000000000000002000100000000000000142000
                0000000000000b6d656173757265642d7631000200000000000000091000000000002a3000000d000000000000000911
                00066517289880000009000000000000002921000000000000002067d25b16ccba49e35619fbfdd2d55f9eeba27aaf12
                1a695c9bb877c9b779aacd000a0000000000000009110006651728988000000b000000000000000911000665174c5bc6
                00000c0000000000000009100000000000000384000d0000000000000009100000000040000000000e00000000000001
                3030000000000000000900000000000000112000000000000000087368656c6c2d763100000000000000122000000000
                00000009736b696c6c732d7631000000000000001520000000000000000c7375626167656e74732d7631000000000000
                001720000000000000000e6469726563742d726561642d7631000000000000001720000000000000000e6c6976652d73
                65617263682d7631000000000000001820000000000000000f756e69666965642d657865632d7631000000000000001c
                200000000000000013696d6167652d696e7370656374696f6e2d76310000000000000022200000000000000019707562
                6c69632d636f6d6d616e642d6e6574776f726b2d7631000000000000002320000000000000001a62726f777365722d6f
                722d6469726563742d66657463682d7631
                """
            )
    )
    #expect(
        plan.fingerprint.hex
            == "7a929cf4c865c5ccb9f2fd9b314a99c189fcef28267aaf844db8a4efabe9c01b"
    )
    #expect(
        Data(SHA256.hash(data: planBytes)).hexString
            == "7a929cf4c865c5ccb9f2fd9b314a99c189fcef28267aaf844db8a4efabe9c01b"
    )
    #expect(try InvestigationCanonicalCodec.decodePlanBytes(planBytes) == plan)

    let json = String(
        decoding: try DomainJSON.encode(plan),
        as: UTF8.self
    ).lowercased()
    for forbidden in [
        "executable",
        "arguments",
        "authorization",
        "policy",
        "trash",
        "disposition",
        "action",
    ] {
        #expect(!json.contains(forbidden))
    }
}

@Test
func investigationPlanRejectsCrossSourceDuplicatesExpiryAndTargetOverflow()
    throws
{
    let target = try fixtureInvestigationTarget()
    let sourceFingerprint = try InvestigationFingerprint(
        validating: Data(repeating: 7, count: 32)
    )
    let createdAt = Date(timeIntervalSince1970: 1_800_000_000)

    #expect(throws: InvestigationDomainError.invalidPlan) {
        _ = try InvestigationPlan(
            id: InvestigationID(rawValue: "investigation-duplicate")!,
            scanSessionID: target.scanSessionID,
            scanScopeID: target.scanScopeID,
            sourceFingerprint: sourceFingerprint,
            budgetPreset: .focused,
            targets: [target, target],
            createdAt: createdAt,
            expiresAt: createdAt.addingTimeInterval(600),
            requestedCoveragePermille: 900,
            remainingUnknownByteThreshold: ByteCount(1),
            requiredCapabilities: InvestigationCapability.required
        )
    }
    #expect(throws: InvestigationDomainError.invalidPlan) {
        _ = try InvestigationPlan(
            id: InvestigationID(rawValue: "investigation-expired")!,
            scanSessionID: target.scanSessionID,
            scanScopeID: target.scanScopeID,
            sourceFingerprint: sourceFingerprint,
            budgetPreset: .focused,
            targets: [target],
            createdAt: createdAt,
            expiresAt: createdAt,
            requestedCoveragePermille: 900,
            remainingUnknownByteThreshold: ByteCount(1),
            requiredCapabilities: InvestigationCapability.required
        )
    }
    #expect(throws: InvestigationDomainError.invalidPlan) {
        _ = try InvestigationPlan(
            id: InvestigationID(rawValue: "investigation-overflow")!,
            scanSessionID: target.scanSessionID,
            scanScopeID: target.scanScopeID,
            sourceFingerprint: sourceFingerprint,
            budgetPreset: .focused,
            targets: Array(repeating: target, count: 513),
            createdAt: createdAt,
            expiresAt: createdAt.addingTimeInterval(600),
            requestedCoveragePermille: 900,
            remainingUnknownByteThreshold: ByteCount(1),
            requiredCapabilities: InvestigationCapability.required
        )
    }
}

@Test
func investigationPlanRejectsTargetsOutsideExactPlannerOrder() throws {
    let measured = try fixtureInvestigationTarget()
    let unmeasurable = try InvestigationTarget(
        scanSessionID: measured.scanSessionID,
        scanScopeID: measured.scanScopeID,
        sourceBinding: .spaceLedger(.unknownResidual),
        kind: .unexplainedSpaceGap,
        reasonKeys: [DomainToken(rawValue: "reason.space-gap")!],
        expectedAllocatedBytes: nil,
        uncertaintyPermille: 1_000,
        relevancePermille: 700,
        investigationCostPermille: 800,
        createdAt: measured.createdAt
    )
    let sourceFingerprint = try InvestigationFingerprint(
        validating: Data(repeating: 7, count: 32)
    )
    let createdAt = Date(timeIntervalSince1970: 1_800_000_000)

    _ = try InvestigationPlan(
        id: InvestigationID(rawValue: "investigation-ordered")!,
        scanSessionID: measured.scanSessionID,
        scanScopeID: measured.scanScopeID,
        sourceFingerprint: sourceFingerprint,
        budgetPreset: .focused,
        targets: [measured, unmeasurable],
        createdAt: createdAt,
        expiresAt: createdAt.addingTimeInterval(600),
        requestedCoveragePermille: 900,
        remainingUnknownByteThreshold: ByteCount(1_073_741_824),
        requiredCapabilities: InvestigationCapability.required
    )
    #expect(throws: InvestigationDomainError.invalidPlan) {
        _ = try InvestigationPlan(
            id: InvestigationID(rawValue: "investigation-reordered")!,
            scanSessionID: measured.scanSessionID,
            scanScopeID: measured.scanScopeID,
            sourceFingerprint: sourceFingerprint,
            budgetPreset: .focused,
            targets: [unmeasurable, measured],
            createdAt: createdAt,
            expiresAt: createdAt.addingTimeInterval(600),
            requestedCoveragePermille: 900,
            remainingUnknownByteThreshold: ByteCount(1_073_741_824),
            requiredCapabilities: InvestigationCapability.required
        )
    }
}

@Test
func investigationPlanRejectsCallerSelectedPolicyThresholds() throws {
    let target = try fixtureInvestigationTarget()
    let sourceFingerprint = try InvestigationFingerprint(
        validating: Data(repeating: 7, count: 32)
    )
    let createdAt = Date(timeIntervalSince1970: 1_800_000_000)

    #expect(throws: InvestigationDomainError.invalidPlan) {
        _ = try InvestigationPlan(
            id: InvestigationID(rawValue: "investigation-policy-drift")!,
            scanSessionID: target.scanSessionID,
            scanScopeID: target.scanScopeID,
            sourceFingerprint: sourceFingerprint,
            budgetPreset: .focused,
            targets: [target],
            createdAt: createdAt,
            expiresAt: createdAt.addingTimeInterval(600),
            requestedCoveragePermille: 899,
            remainingUnknownByteThreshold: ByteCount(1_073_741_824),
            requiredCapabilities: InvestigationCapability.required
        )
    }
    #expect(throws: InvestigationDomainError.invalidPlan) {
        _ = try InvestigationPlan(
            id: InvestigationID(rawValue: "investigation-threshold-drift")!,
            scanSessionID: target.scanSessionID,
            scanScopeID: target.scanScopeID,
            sourceFingerprint: sourceFingerprint,
            budgetPreset: .focused,
            targets: [target],
            createdAt: createdAt,
            expiresAt: createdAt.addingTimeInterval(600),
            requestedCoveragePermille: 900,
            remainingUnknownByteThreshold: ByteCount(1),
            requiredCapabilities: InvestigationCapability.required
        )
    }
}

@Test
func investigationDomainJSONRejectsDuplicateAndUnknownNestedKeys() throws {
    let plan = try fixtureInvestigationPlan()
    let encoded = String(decoding: try DomainJSON.encode(plan), as: UTF8.self)
    let duplicateID = encoded.replacingOccurrences(
        of: #""id":"investigation-fixture""#,
        with:
            #""id":"investigation-fixture","id":"investigation-fixture""#
    )
    let unknownPriorityKey = encoded.replacingOccurrences(
        of: #""priority":{"score":2764800,"tier":"measured-v1"}"#,
        with:
            #""priority":{"authority":"caller","score":2764800,"tier":"measured-v1"}"#
    )

    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            InvestigationPlan.self,
            from: Data(duplicateID.utf8)
        )
    }
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            InvestigationPlan.self,
            from: Data(unknownPriorityKey.utf8)
        )
    }
}

@Test
func investigationDomainJSONAuditorNormalizesEscapedKeysAndValidatesUTF8()
    throws
{
    struct StringEnvelope: Codable, Equatable {
        let value: String
    }

    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            StringEnvelope.self,
            from: Data(#"{"value":"first","\u0076alue":"second"}"#.utf8)
        )
    }
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            StringEnvelope.self,
            from: Data([
                0x7B, 0x22, 0x76, 0x61, 0x6C, 0x75, 0x65, 0x22,
                0x3A, 0x22, 0xC0, 0xAF, 0x22, 0x7D,
            ])
        )
    }
    #expect(
        try DomainJSON.decode(
            StringEnvelope.self,
            from: Data(#"{"value":"路径-\uD83D\uDE80"}"#.utf8)
        ) == StringEnvelope(value: "路径-🚀")
    )
}

@Test
func investigationDomainJSONRejectsNonRoundTrippableMicroseconds() throws {
    let plan = try fixtureInvestigationPlan()
    let encoded = String(decoding: try DomainJSON.encode(plan), as: UTF8.self)
    let nonRoundTrippable = encoded
        .replacingOccurrences(
            of: #""createdAtMicros":1800000000000000"#,
            with: #""createdAtMicros":9007199254740993"#
        )
        .replacingOccurrences(
            of: #""expiresAtMicros":1800000600000000"#,
            with: #""expiresAtMicros":9007199854740993"#
        )

    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            InvestigationPlan.self,
            from: Data(nonRoundTrippable.utf8)
        )
    }
}

@Test
func investigationDomainJSONParsesExactIntegerLexemeBoundaries() throws {
    for value in [
        UInt64(9_007_199_254_740_991),
        UInt64(9_007_199_254_740_992),
        UInt64(9_007_199_254_740_993),
        UInt64(Int64.max),
        UInt64(Int64.max) + 1,
        UInt64.max,
    ] {
        let decoded = try DomainJSON.decode(
            StrictUnsignedIntegerEnvelope.self,
            from: Data(#"{"value":\#(value)}"#.utf8)
        )
        #expect(decoded.value == value)
    }

    for value in [Int64.min, Int64.max] {
        let decoded = try DomainJSON.decode(
            StrictSignedIntegerEnvelope.self,
            from: Data(#"{"value":\#(value)}"#.utf8)
        )
        #expect(decoded.value == value)
    }
}

@Test
func investigationDomainJSONRejectsNonIntegerAndOutOfRangeLexemes() {
    for lexeme in [
        "-1",
        "900.0",
        "9e2",
        "18446744073709551616",
        "999999999999999999999999999999999999999999999999999999999999",
    ] {
        #expect(throws: (any Error).self) {
            _ = try DomainJSON.decode(
                StrictUnsignedIntegerEnvelope.self,
                from: Data(#"{"value":\#(lexeme)}"#.utf8)
            )
        }
    }

    for lexeme in [
        "-9223372036854775809",
        "9223372036854775808",
        "1.0",
        "1e0",
    ] {
        #expect(throws: (any Error).self) {
            _ = try DomainJSON.decode(
                StrictSignedIntegerEnvelope.self,
                from: Data(#"{"value":\#(lexeme)}"#.utf8)
            )
        }
    }
}

@Test
func investigationPlanJSONRejectsFloatingPointIntegerSpellings() throws {
    let encoded = String(
        decoding: try DomainJSON.encode(fixtureInvestigationPlan()),
        as: UTF8.self
    )

    for lexeme in ["900.0", "9e2"] {
        let mutated = encoded.replacingOccurrences(
            of: #""requestedCoveragePermille":900"#,
            with: #""requestedCoveragePermille":\#(lexeme)"#
        )
        #expect(mutated != encoded)
        #expect(throws: (any Error).self) {
            _ = try DomainJSON.decode(
                InvestigationPlan.self,
                from: Data(mutated.utf8)
            )
        }
    }
}

@Test
func investigationByteCountV1AcceptsMaxAndRejectsMaxPlusOneInBinaryAndJSON()
    throws
{
    let target = try InvestigationTarget(
        scanSessionID: ScanSessionID(rawValue: "scan-byte-count")!,
        scanScopeID: ScanScopeID(rawValue: "scope-byte-count")!,
        sourceBinding: .snapshot(
            SnapshotID(rawValue: "snapshot-byte-count")!
        ),
        kind: .unknownLargeConsumer,
        reasonKeys: [DomainToken(rawValue: "reason.byte-count")!],
        expectedAllocatedBytes: ByteCount(UInt64(Int64.max)),
        uncertaintyPermille: 750,
        relevancePermille: 900,
        investigationCostPermille: 250,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
    let plan = try InvestigationPlan(
        id: InvestigationID(rawValue: "investigation-byte-count")!,
        scanSessionID: target.scanSessionID,
        scanScopeID: target.scanScopeID,
        sourceFingerprint: try InvestigationFingerprint(
            validating: Data(repeating: 0xBC, count: 32)
        ),
        budgetPreset: .focused,
        targets: [target],
        createdAt: Date(timeIntervalSince1970: 1_800_000_000),
        expiresAt: Date(timeIntervalSince1970: 1_800_000_600),
        requestedCoveragePermille: 900,
        remainingUnknownByteThreshold: ByteCount(1_073_741_824),
        requiredCapabilities: InvestigationCapability.required
    )

    let validBinary = try InvestigationCanonicalCodec.planBytes(plan)
    #expect(
        try InvestigationCanonicalCodec.decodePlanBytes(validBinary) == plan
    )
    #expect(
        try DomainJSON.decode(
            InvestigationPlan.self,
            from: DomainJSON.encode(plan)
        ) == plan
    )

    let root = try StornautInvestigationCanonicalV1.decode(
        validBinary,
        expectedDomain: "stornaut.investigation.plan.v1",
        maximumInputBytes: InvestigationPlan.maximumCanonicalBytes
    )
    let invalidBinary = try StornautInvestigationCanonicalV1.encode(
        domain: "stornaut.investigation.plan.v1",
        root: replacingTargetByteCount(
            in: root,
            with: UInt64(Int64.max) + 1
        )
    )
    #expect(throws: InvestigationDomainError.invalidPlan) {
        _ = try InvestigationCanonicalCodec.decodePlanBytes(invalidBinary)
    }

    let validJSON = String(
        decoding: try DomainJSON.encode(plan),
        as: UTF8.self
    )
    let invalidJSON = validJSON.replacingOccurrences(
        of: #""expectedAllocatedBytes":9223372036854775807"#,
        with: #""expectedAllocatedBytes":9223372036854775808"#
    )
    #expect(invalidJSON != validJSON)
    #expect(throws: (any Error).self) {
        _ = try DomainJSON.decode(
            InvestigationPlan.self,
            from: Data(invalidJSON.utf8)
        )
    }
}

@Test
func investigationBinarySchemasRejectMissingWrongAndDuplicateValues() throws {
    let target = try fixtureInvestigationTarget()
    let identity = try InvestigationCanonicalCodec.targetIdentityBytes(
        scanSessionID: target.scanSessionID,
        scanScopeID: target.scanScopeID,
        kind: target.kind,
        sourceBinding: target.sourceBinding
    )
    let identityRoot = try StornautInvestigationCanonicalV1.decode(
        identity,
        expectedDomain: "stornaut.investigation.target.v2",
        maximumInputBytes: 4_096
    )
    guard case let .record(identityFields) = identityRoot else {
        throw InvestigationDomainError.invalidPlan
    }
    let missingBinding = try StornautInvestigationCanonicalV1.encode(
        domain: "stornaut.investigation.target.v2",
        root: .record(identityFields.filter { $0.tag != 5 })
    )
    #expect(throws: InvestigationDomainError.invalidPlan) {
        try InvestigationCanonicalCodec.validateTargetIdentityBytes(
            missingBinding
        )
    }

    let targetSet = try InvestigationCanonicalCodec.targetSetBytes(
        targets: [target]
    )
    let targetSetRoot = try StornautInvestigationCanonicalV1.decode(
        targetSet,
        expectedDomain: "stornaut.investigation.target-set.v1",
        maximumInputBytes: 65_536
    )
    guard case let .record(targetSetFields) = targetSetRoot else {
        throw InvestigationDomainError.invalidPlan
    }
    let duplicateTargetSet = try StornautInvestigationCanonicalV1.encode(
        domain: "stornaut.investigation.target-set.v1",
        root: .record(
            targetSetFields.map { field in
                field.tag == 2
                    ? InvestigationCanonicalField(
                        tag: 2,
                        value: .array([
                            .text(target.id.rawValue),
                            .text(target.id.rawValue),
                        ])
                    )
                    : field
            }
        )
    )
    #expect(throws: InvestigationDomainError.invalidPlan) {
        _ = try InvestigationCanonicalCodec.decodeTargetSetBytes(
            duplicateTargetSet
        )
    }

    let plan = try fixtureInvestigationPlan()
    let planBytes = try InvestigationCanonicalCodec.planBytes(plan)
    let planRoot = try StornautInvestigationCanonicalV1.decode(
        planBytes,
        expectedDomain: "stornaut.investigation.plan.v1",
        maximumInputBytes: InvestigationPlan.maximumCanonicalBytes
    )
    let wrongCoverageType = try replacingCanonicalField(
        tag: 12,
        in: planRoot,
        with: .signed(900)
    )
    let wrongCoverageBytes = try StornautInvestigationCanonicalV1.encode(
        domain: "stornaut.investigation.plan.v1",
        root: wrongCoverageType
    )
    #expect(throws: InvestigationDomainError.invalidPlan) {
        _ = try InvestigationCanonicalCodec.decodePlanBytes(
            wrongCoverageBytes
        )
    }
}

@Test
func investigationStrictJSONRequiresExplicitOptionalsVersionsAndValidIDs()
    throws
{
    let target = try InvestigationTarget(
        scanSessionID: ScanSessionID(rawValue: "scan-null-optionals")!,
        scanScopeID: ScanScopeID(rawValue: "scope-null-optionals")!,
        sourceBinding: .spaceLedger(.unknownResidual),
        kind: .unexplainedSpaceGap,
        reasonKeys: [DomainToken(rawValue: "reason.null-optionals")!],
        expectedAllocatedBytes: nil,
        uncertaintyPermille: 1_000,
        relevancePermille: 700,
        investigationCostPermille: 800,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
    let encodedTarget = String(
        decoding: try DomainJSON.encode(target),
        as: UTF8.self
    )
    #expect(encodedTarget.contains(#""expectedAllocatedBytes":null"#))
    #expect(encodedTarget.contains(#""classificationID":null"#))
    #expect(encodedTarget.contains(#""snapshotID":null"#))
    #expect(
        try DomainJSON.decode(
            InvestigationTarget.self,
            from: Data(encodedTarget.utf8)
        ) == target
    )

    for mutation in [
        encodedTarget.replacingOccurrences(
            of: #""classificationID":null,"#,
            with: ""
        ),
        encodedTarget.replacingOccurrences(
            of: #""schemaVersion":2"#,
            with: #""schemaVersion":1"#
        ),
        encodedTarget.replacingOccurrences(
            of: #""id":"\#(target.id.rawValue)""#,
            with: #""id":"wrong-target""#
        ),
    ] {
        #expect(mutation != encodedTarget)
        #expect(throws: (any Error).self) {
            _ = try DomainJSON.decode(
                InvestigationTarget.self,
                from: Data(mutation.utf8)
            )
        }
    }

    let encodedPlan = String(
        decoding: try DomainJSON.encode(fixtureInvestigationPlan()),
        as: UTF8.self
    )
    for mutation in [
        encodedPlan.replacingOccurrences(
            of: #""schemaVersion":1"#,
            with: #""schemaVersion":2"#
        ),
        encodedPlan.replacingOccurrences(
            of: #""id":"investigation-fixture""#,
            with: #""id":"wrong-fixture""#
        ),
    ] {
        #expect(mutation != encodedPlan)
        #expect(throws: (any Error).self) {
            _ = try DomainJSON.decode(
                InvestigationPlan.self,
                from: Data(mutation.utf8)
            )
        }
    }
}

private func fixtureInvestigationPlan() throws -> InvestigationPlan {
    let target = try fixtureInvestigationTarget()
    return try InvestigationPlan(
        id: InvestigationID(rawValue: "investigation-fixture")!,
        scanSessionID: target.scanSessionID,
        scanScopeID: target.scanScopeID,
        sourceFingerprint: try InvestigationFingerprint(
            validatingHex:
                "318e1e01fb438c631a72056fa167fe0c94fffe8426adb6b25358e4cd3cfcd9df"
        ),
        budgetPreset: .focused,
        targets: [target],
        createdAt: Date(timeIntervalSince1970: 1_800_000_000),
        expiresAt: Date(timeIntervalSince1970: 1_800_000_600),
        requestedCoveragePermille: 900,
        remainingUnknownByteThreshold: ByteCount(1_073_741_824),
        requiredCapabilities: InvestigationCapability.required
    )
}

private func fixtureInvestigationTarget() throws -> InvestigationTarget {
    try InvestigationTarget(
        scanSessionID: ScanSessionID(rawValue: "scan-fixture")!,
        scanScopeID: ScanScopeID(rawValue: "scope-fixture")!,
        sourceBinding: .snapshot(
            SnapshotID(rawValue: "snapshot-fixture")!
        ),
        kind: .unknownLargeConsumer,
        reasonKeys: [
            DomainToken(rawValue: "reason.rule-miss")!,
            DomainToken(rawValue: "reason.unknown-producer")!,
        ],
        expectedAllocatedBytes: ByteCount(1_073_741_824),
        uncertaintyPermille: 750,
        relevancePermille: 900,
        investigationCostPermille: 250,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
}

private struct StrictUnsignedIntegerEnvelope:
    Codable,
    StrictIntegerDomainJSON
{
    let value: UInt64
}

private struct StrictSignedIntegerEnvelope:
    Codable,
    StrictIntegerDomainJSON
{
    let value: Int64
}

private func replacingTargetByteCount(
    in root: InvestigationCanonicalValue,
    with value: UInt64
) throws -> InvestigationCanonicalValue {
    guard case let .record(planFields) = root else {
        throw InvestigationDomainError.invalidPlan
    }
    let replacedPlanFields = try planFields.map { field in
        guard field.tag == 8 else {
            return field
        }
        guard case let .array(targetValues) = field.value,
              targetValues.count == 1,
              case let .record(targetFields) = targetValues[0]
        else {
            throw InvestigationDomainError.invalidPlan
        }
        let replacedTargetFields = targetFields.map { targetField in
            targetField.tag == 8
                ? InvestigationCanonicalField(
                    tag: targetField.tag,
                    value: .unsigned(value)
                )
                : targetField
        }
        return InvestigationCanonicalField(
            tag: field.tag,
            value: .array([.record(replacedTargetFields)])
        )
    }
    return .record(replacedPlanFields)
}

private func replacingCanonicalField(
    tag: UInt16,
    in root: InvestigationCanonicalValue,
    with value: InvestigationCanonicalValue
) throws -> InvestigationCanonicalValue {
    guard case let .record(fields) = root,
          fields.contains(where: { $0.tag == tag })
    else {
        throw InvestigationDomainError.invalidPlan
    }
    return .record(
        fields.map { field in
            field.tag == tag
                ? InvestigationCanonicalField(tag: tag, value: value)
                : field
        }
    )
}

private func normalizedHex(_ value: String) -> String {
    value.filter(\.isHexDigit).lowercased()
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
