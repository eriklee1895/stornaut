import Darwin
import CryptoKit
import Foundation
import Testing
@testable import StornautCore

@Test
func investigationSourceProjectionMatchesNormativeOpaqueVector() throws {
    let scanPayload = Data(
        """
        {"aggregate":null,"completedScopes":[{"completedAt":1800000000,"id":"scope-fixture","rootPath":"/fixture"}],"finishedAt":1800000000,"id":"scan-fixture","schemaVersion":1,"startedAt":1799999999,"terminalState":"completed","unfinishedScopes":[]}
        """.utf8
    )
    let ledgerPayload = Data(
        """
        {"caveats":["cloneAndCompressionNotAttributed","purgeableNotEstimated"],"coverageGaps":[],"owners":[],"schemaVersion":1,"sessionID":"scan-fixture","status":"reconciled"}
        """.utf8
    )
    let scanRow = InvestigationSourceManifestRow(
        rowKind: .scanSession,
        primaryID: "scan-fixture",
        storageColumns: [
            .init(name: "id", value: .text("scan-fixture")),
            .init(name: "expires_at_ms", value: .int64(1_800_604_800_000)),
            .init(name: "started_at_ms", value: .int64(1_799_999_999_000)),
            .init(name: "finished_at_ms", value: .int64(1_800_000_000_000)),
        ],
        payloadByteCount: UInt64(scanPayload.count),
        payloadSHA256: try InvestigationFingerprint(
            validating: Data(SHA256.hash(data: scanPayload))
        )
    )
    let ledgerRow = InvestigationSourceManifestRow(
        rowKind: .spaceLedger,
        primaryID: "scan-fixture",
        storageColumns: [
            .init(name: "id", value: .text("scan-fixture")),
            .init(name: "session_id", value: .text("scan-fixture")),
        ],
        payloadByteCount: UInt64(ledgerPayload.count),
        payloadSHA256: try InvestigationFingerprint(
            validating: Data(SHA256.hash(data: ledgerPayload))
        )
    )
    let rows = try [scanRow.canonicalBytes, ledgerRow.canonicalBytes]
    #expect(rows[0].lexicographicallyPrecedes(rows[1]))

    var sink = try InvestigationCanonicalHashSink(
        scanSessionID: ScanSessionID(rawValue: "scan-fixture")!,
        primaryScopeID: ScanScopeID(rawValue: "scope-fixture")!,
        sourceRowCount: 2,
        framedRowsByteCount: UInt64(
            rows.reduce(0) { $0 + 8 + $1.count }
        ),
        relevanceTokens: [
            DomainToken(rawValue: "relevance.large")!,
            DomainToken(rawValue: "relevance.developer")!,
        ]
    )
    for row in rows {
        try sink.appendSourceRow(row)
    }
    let result = try sink.finalize()
    let root = InvestigationCanonicalValue.record([
            .init(tag: 1, value: .unsigned(1)),
            .init(tag: 2, value: .text("scan-fixture")),
            .init(tag: 3, value: .text("scope-fixture")),
            .init(
                tag: 4,
                value: .array([
                    canonicalValue(for: scanRow),
                    canonicalValue(for: ledgerRow),
                ])
            ),
            .init(
                tag: 5,
                value: .array([
                    .text("relevance.large"),
                    .text("relevance.developer"),
                ])
            ),
        ])
    let encoded = try StornautInvestigationCanonicalV1.encode(
        domain: "stornaut.investigation.source.v1",
        root: root
    )

    #expect(result.byteCount == 1_246)
    #expect(encoded.count == 1_246)
    #expect(
        encoded.hexString
            == normalizedHex(
                """
                53544f524e4155542d494e562d43414e4f4e2d310020000000000000002073746f726e6175742e696e76657374696761
                74696f6e2e736f757263652e763140000000000000000500010000000000000009100000000000000001000200000000
                0000001520000000000000000c7363616e2d666978747572650003000000000000001620000000000000000d73636f70
                652d66697874757265000400000000000003e4300000000000000002000000000000024c400000000000000005000100
                0000000000001820000000000000000f7363616e2d73657373696f6e2d76310002000000000000001520000000000000
                000c7363616e2d66697874757265000300000000000001b2300000000000000004000000000000006240000000000000
                00040001000000000000000b200000000000000002696400020000000000000010200000000000000007746578742d76
                310003000000000000001520000000000000000c7363616e2d6669787475726500040000000000000001000000000000
                0000624000000000000000040001000000000000001620000000000000000d657870697265735f61745f6d7300020000
                000000000011200000000000000008696e7436342d763100030000000000000001000004000000000000000911000001
                a33c68d40000000000000000624000000000000000040001000000000000001620000000000000000d73746172746564
                5f61745f6d7300020000000000000011200000000000000008696e7436342d7631000300000000000000010000040000
                00000000000911000001a3185c4c18000000000000006340000000000000000400010000000000000017200000000000
                00000e66696e69736865645f61745f6d7300020000000000000011200000000000000008696e7436342d763100030000
                000000000001000004000000000000000911000001a3185c5000000400000000000000091000000000000000f3000500
                00000000000029210000000000000020edc8d1502fbc7eb3ae2776a241e2798ffed497c75c9d4788de7e6f3c39d6cce3
                000000000000017f4000000000000000050001000000000000001820000000000000000f73706163652d6c6564676572
                2d76310002000000000000001520000000000000000c7363616e2d66697874757265000300000000000000e530000000
                000000000200000000000000624000000000000000040001000000000000000b20000000000000000269640002000000
                0000000010200000000000000007746578742d76310003000000000000001520000000000000000c7363616e2d666978
                747572650004000000000000000100000000000000006a40000000000000000400010000000000000013200000000000
                00000a73657373696f6e5f696400020000000000000010200000000000000007746578742d7631000300000000000000
                1520000000000000000c7363616e2d666978747572650004000000000000000100000400000000000000091000000000
                000000a900050000000000000029210000000000000020eda271dbe120df713681205a8591352a9b1374cbea8a37dd74
                b7efbd5d0b3e120005000000000000004d300000000000000002000000000000001820000000000000000f72656c6576
                616e63652e6c61726765000000000000001c20000000000000001372656c6576616e63652e646576656c6f706572
                """
            )
    )
    #expect(
        result.fingerprint.hex
            == "318e1e01fb438c631a72056fa167fe0c94fffe8426adb6b25358e4cd3cfcd9df"
    )
    #expect(
        Data(SHA256.hash(data: encoded)).hexString
            == "318e1e01fb438c631a72056fa167fe0c94fffe8426adb6b25358e4cd3cfcd9df"
    )
    let materializedFingerprint = try InvestigationFingerprint(
        validating: Data(SHA256.hash(data: encoded))
    )
    #expect(result.fingerprint == materializedFingerprint)
    #expect(
        try InvestigationSourceProjectionCanonicalCodec.validateBytes(encoded)
            == materializedFingerprint
    )

    guard case let .record(rootFields) = root else {
        throw InvestigationSourceProjectionError.payloadMismatch
    }
    let missingRelevance = try StornautInvestigationCanonicalV1.encode(
        domain: "stornaut.investigation.source.v1",
        root: .record(rootFields.filter { $0.tag != 5 })
    )
    #expect(throws: InvestigationSourceProjectionError.payloadMismatch) {
        _ = try InvestigationSourceProjectionCanonicalCodec.validateBytes(
            missingRelevance
        )
    }

    let duplicateRelevance = try StornautInvestigationCanonicalV1.encode(
        domain: "stornaut.investigation.source.v1",
        root: .record(
            rootFields.map { field in
                field.tag == 5
                    ? InvestigationCanonicalField(
                        tag: 5,
                        value: .array([
                            .text("relevance.large"),
                            .text("relevance.large"),
                        ])
                    )
                    : field
            }
        )
    )
    #expect(throws: InvestigationSourceProjectionError.nonCanonicalOrder) {
        _ = try InvestigationSourceProjectionCanonicalCodec.validateBytes(
            duplicateRelevance
        )
    }

    let wrongPayloadDigest = try replacingSourceRowField(
        tag: 5,
        rowIndex: 0,
        in: root,
        with: .bytes(Data(repeating: 0, count: 31))
    )
    let wrongPayloadDigestBytes = try StornautInvestigationCanonicalV1.encode(
        domain: "stornaut.investigation.source.v1",
        root: wrongPayloadDigest
    )
    #expect(throws: InvestigationSourceProjectionError.payloadMismatch) {
        _ = try InvestigationSourceProjectionCanonicalCodec.validateBytes(
            wrongPayloadDigestBytes
        )
    }
}

@Test
func investigationSourceManifestWriterMatchesGenericCanonicalEncodingAtExtremes()
    throws
{
    let rows = [
        InvestigationSourceManifestRow(
            rowKind: .pathSnapshot,
            primaryID: "snapshot-writer-unicode",
            storageColumns: [
                .init(
                    name: "relative_path",
                    value: .text("目录/🚀/e\u{301}/é")
                ),
                .init(name: "observed_at_ms", value: .int64(.min)),
            ],
            payloadByteCount: .max,
            payloadSHA256: try InvestigationFingerprint(
                validating: Data((0..<32).map(UInt8.init))
            )
        ),
        InvestigationSourceManifestRow(
            rowKind: .scanSession,
            primaryID: "scan-writer-maximum",
            storageColumns: [
                .init(name: "started_at_ms", value: .int64(.max)),
                .init(name: "label", value: .text("纯文本🙂")),
            ],
            payloadByteCount: 0,
            payloadSHA256: try InvestigationFingerprint(
                validating: Data(
                    (0..<32).reversed().map(UInt8.init)
                )
            )
        ),
    ]

    for row in rows {
        var generic = Data()
        try StornautInvestigationCanonicalV1.appendValueForSchema(
            canonicalValue(for: row),
            to: &generic
        )
        #expect(try row.canonicalBytes == generic)
    }
}

@Test
func investigationSourceProjectionBinaryValidationEnforcesMembershipAndEvidenceLimit()
    throws
{
    let sessionID = ScanSessionID(rawValue: "scan-binary-membership")!
    let scopeID = ScanScopeID(rawValue: "scope-binary-membership")!
    let snapshotID = SnapshotID(rawValue: "snapshot-binary-membership")!
    let orphanID = SnapshotID(rawValue: "snapshot-binary-orphan")!
    let baseRows = [
        binaryManifestRow(
            kind: .scanSession,
            primaryID: sessionID.rawValue,
            columns: [
                .init(name: "id", value: .text(sessionID.rawValue)),
                .init(name: "expires_at_ms", value: .int64(1_800_604_800_000)),
                .init(name: "started_at_ms", value: .int64(1_799_999_999_000)),
                .init(name: "finished_at_ms", value: .int64(1_800_000_000_000)),
            ]
        ),
        binaryManifestRow(
            kind: .spaceLedger,
            primaryID: sessionID.rawValue,
            columns: [
                .init(name: "id", value: .text(sessionID.rawValue)),
                .init(name: "session_id", value: .text(sessionID.rawValue)),
            ]
        ),
        binaryManifestRow(
            kind: .pathSnapshot,
            primaryID: snapshotID.rawValue,
            columns: [
                .init(name: "id", value: .text(snapshotID.rawValue)),
                .init(name: "session_id", value: .text(sessionID.rawValue)),
                .init(name: "relative_path", value: .text("fixture")),
                .init(name: "observed_at_ms", value: .int64(1_800_000_000_000)),
            ]
        ),
    ]
    let classificationID = ClassificationID(
        rawValue: "classification-binary-membership"
    )!
    let validClassification = binaryManifestRow(
        kind: .classification,
        primaryID: classificationID.rawValue,
        columns: [
            .init(name: "id", value: .text(classificationID.rawValue)),
            .init(name: "disposition", value: .text("unknown")),
            .init(name: "snapshot_id", value: .text(snapshotID.rawValue)),
            .init(name: "classified_at_ms", value: .int64(1_800_000_000_000)),
        ]
    )
    let orphanClassification = binaryManifestRow(
        kind: .classification,
        primaryID: classificationID.rawValue,
        columns: [
            .init(name: "id", value: .text(classificationID.rawValue)),
            .init(name: "disposition", value: .text("unknown")),
            .init(name: "snapshot_id", value: .text(orphanID.rawValue)),
            .init(name: "classified_at_ms", value: .int64(1_800_000_000_000)),
        ]
    )
    let evidence = (0..<101).map { index in
        binaryManifestRow(
            kind: .evidence,
            primaryID: "evidence-binary-\(index)",
            columns: [
                .init(name: "id", value: .text("evidence-binary-\(index)")),
                .init(name: "snapshot_id", value: .text(snapshotID.rawValue)),
                .init(name: "observed_at_ms", value: .int64(1_800_000_000_000)),
            ]
        )
    }
    let orphanEvidence = binaryManifestRow(
        kind: .evidence,
        primaryID: "evidence-binary-orphan",
        columns: [
            .init(name: "id", value: .text("evidence-binary-orphan")),
            .init(name: "snapshot_id", value: .text(orphanID.rawValue)),
            .init(name: "observed_at_ms", value: .int64(1_800_000_000_000)),
        ]
    )

    let valid = try binarySourceProjection(
        sessionID: sessionID,
        scopeID: scopeID,
        rows: baseRows + [validClassification] + Array(evidence.prefix(100))
    )
    #expect(
        try InvestigationSourceProjectionCanonicalCodec.validateBytes(valid)
            == InvestigationFingerprint(
                validating: Data(SHA256.hash(data: valid))
            )
    )

    for invalidRows in [
        baseRows + [orphanClassification],
        baseRows + [orphanEvidence],
    ] {
        let invalid = try binarySourceProjection(
            sessionID: sessionID,
            scopeID: scopeID,
            rows: invalidRows
        )
        #expect(
            throws: InvestigationSourceProjectionError.membershipMismatch
        ) {
            _ = try InvestigationSourceProjectionCanonicalCodec.validateBytes(
                invalid
            )
        }
    }
    let tooManyEvidence = try binarySourceProjection(
        sessionID: sessionID,
        scopeID: scopeID,
        rows: baseRows + evidence
    )
    #expect(
        throws: InvestigationSourceProjectionError.sourceProjectionTooLarge
    ) {
        _ = try InvestigationSourceProjectionCanonicalCodec.validateBytes(
            tooManyEvidence
        )
    }
}

@Test
func investigationSourceProjectionBinaryValidationEnforcesRawStorageBounds()
    throws
{
    let sessionID = ScanSessionID(rawValue: "scan-binary-bounds")!
    let scopeID = ScanScopeID(rawValue: "scope-binary-bounds")!
    let validRows = [
        binaryManifestRow(
            kind: .scanSession,
            primaryID: sessionID.rawValue,
            columns: [
                .init(name: "id", value: .text(sessionID.rawValue)),
                .init(name: "expires_at_ms", value: .int64(1_800_604_800_000)),
                .init(name: "started_at_ms", value: .int64(1_799_999_999_000)),
                .init(name: "finished_at_ms", value: .int64(1_800_000_000_000)),
            ]
        ),
        binaryManifestRow(
            kind: .spaceLedger,
            primaryID: sessionID.rawValue,
            columns: [
                .init(name: "id", value: .text(sessionID.rawValue)),
                .init(name: "session_id", value: .text(sessionID.rawValue)),
            ]
        ),
    ]
    let boundarySnapshot = binaryManifestRow(
        kind: .pathSnapshot,
        primaryID: "snapshot-binary-boundary",
        columns: [
            .init(name: "id", value: .text("snapshot-binary-boundary")),
            .init(name: "session_id", value: .text(sessionID.rawValue)),
            .init(
                name: "relative_path",
                value: .text(String(repeating: "x", count: 16_384))
            ),
            .init(name: "observed_at_ms", value: .int64(.max)),
        ]
    )
    let acceptedBoundary = try binarySourceProjection(
        sessionID: sessionID,
        scopeID: scopeID,
        rows: validRows + [boundarySnapshot]
    )
    _ = try InvestigationSourceProjectionCanonicalCodec.validateBytes(
        acceptedBoundary
    )

    let invalidColumns: [[InvestigationStorageColumn]] = [
        [
            .init(name: "id", value: .text("snapshot-binary-too-many")),
            .init(name: "session_id", value: .text(sessionID.rawValue)),
            .init(name: "relative_path", value: .text("fixture")),
            .init(name: "observed_at_ms", value: .int64(.max)),
            .init(name: "extra", value: .text("value")),
        ],
        [
            .init(name: "id", value: .text("snapshot-binary-long-name")),
            .init(name: "session_id", value: .text(sessionID.rawValue)),
            .init(
                name: String(repeating: "n", count: 65),
                value: .text("fixture")
            ),
            .init(name: "observed_at_ms", value: .int64(.max)),
        ],
        [
            .init(name: "id", value: .text("snapshot-binary-long-text")),
            .init(name: "session_id", value: .text(sessionID.rawValue)),
            .init(
                name: "relative_path",
                value: .text(String(repeating: "x", count: 16_385))
            ),
            .init(name: "observed_at_ms", value: .int64(.max)),
        ],
    ]
    for (index, columns) in invalidColumns.enumerated() {
        let row = binaryManifestRow(
            kind: .pathSnapshot,
            primaryID: "snapshot-binary-invalid-\(index)",
            columns: columns
        )
        let encoded = try binarySourceProjection(
            sessionID: sessionID,
            scopeID: scopeID,
            rows: validRows + [row]
        )
        #expect(
            throws: InvestigationSourceProjectionError.sourceProjectionTooLarge
        ) {
            _ = try InvestigationSourceProjectionCanonicalCodec.validateBytes(
                encoded
            )
        }
    }
}

@Test
func investigationSourceProjectionStreamsTwoIdenticalPasses() throws {
    let fixture = try InvestigationSourceFixture()
    var factory = TestInvestigationSourceFactory(
        scanSessionID: fixture.session.id,
        primaryScopeID: fixture.scopeID,
        generations: [fixture.generation, fixture.generation],
        relevanceTokens: [
            DomainToken(rawValue: "relevance.large")!,
            DomainToken(rawValue: "relevance.developer")!,
        ],
        passes: [fixture.rows, fixture.rows]
    )
    var sink = CollectingInvestigationManifestSink()

    let source = try InvestigationSourceProjectionBuilder().build(
        factory: &factory,
        planningAt: fixture.finishedAt.addingTimeInterval(1),
        manifestSink: &sink
    )

    #expect(factory.makeCursorCount == 2)
    #expect(sink.rows.count == 3)
    #expect(source.summary.scanSessionID == fixture.session.id)
    #expect(source.summary.primaryScopeID == fixture.scopeID)
    #expect(source.summary.sourceRowCount == 3)
    #expect(source.summary.pathSnapshotCount == 1)
    #expect(source.summary.classificationCount == 0)
    #expect(source.summary.evidenceCount == 0)
    #expect(
        source.summary.exactPayloadBytes
            == UInt64(fixture.rows.reduce(0) { $0 + $1.exactPayload.count })
    )
    #expect(source.summary.sourceFingerprint.bytes.count == 32)
    #expect(source.summary.relevanceTokens.map(\.rawValue) == [
        "relevance.large",
        "relevance.developer",
    ])
    #expect(source.policyIndex.snapshots.count == 1)
    #expect(source.policyIndex.snapshots[fixture.rootSnapshot.id]?.isRoot == true)
    #expect(
        source.policyIndex.snapshots[fixture.rootSnapshot.id]?
            .expectedAllocatedBytes == ByteCount(0)
    )
}

@Test
func investigationStoredSourceRowRejectsPayloadAndStorageDrift() throws {
    let fixture = try InvestigationSourceFixture()
    let sessionPayload = try DomainJSON.encode(fixture.session)
    var changedPayload = sessionPayload
    changedPayload.append(0x20)
    let sessionJSON = String(decoding: sessionPayload, as: UTF8.self)
    let duplicateIDPayload = Data(
        sessionJSON.replacingOccurrences(
            of: #""id":"\#(fixture.session.id.rawValue)""#,
            with:
                #""id":"\#(fixture.session.id.rawValue)","id":"\#(fixture.session.id.rawValue)""#
        ).utf8
    )

    var wrongColumns = fixture.sessionColumns
    wrongColumns[0] = InvestigationStorageColumn(
        name: "id",
        value: .text("scan-wrong")
    )
    let malformedRows = try [
        InvestigationStoredSourceRow(
            rowKind: .scanSession,
            storageColumns: fixture.sessionColumns,
            exactPayload: changedPayload
        ),
        InvestigationStoredSourceRow(
            rowKind: .scanSession,
            storageColumns: fixture.sessionColumns,
            exactPayload: duplicateIDPayload
        ),
        InvestigationStoredSourceRow(
            rowKind: .scanSession,
            storageColumns: wrongColumns,
            exactPayload: sessionPayload
        ),
    ]
    let expectedErrors: [InvestigationSourceProjectionError] = [
        .payloadMismatch,
        .payloadMismatch,
        .storageMismatch,
    ]

    for (malformedRow, expectedError) in zip(
        malformedRows,
        expectedErrors
    ) {
        var factory = TestInvestigationSourceFactory(
            scanSessionID: fixture.session.id,
            primaryScopeID: fixture.scopeID,
            generations: [fixture.generation, fixture.generation],
            relevanceTokens: [],
            passes: [
                [malformedRow, fixture.rows[1], fixture.rows[2]],
                [malformedRow, fixture.rows[1], fixture.rows[2]],
            ]
        )
        var sink = CollectingInvestigationManifestSink()
        #expect(throws: expectedError) {
            _ = try InvestigationSourceProjectionBuilder().build(
                factory: &factory,
                planningAt: fixture.finishedAt.addingTimeInterval(1),
                manifestSink: &sink
            )
        }
    }
}

@Test
func investigationStoredSourceRowRejectsOutOfRangeStorageDates() throws {
    let evidence = EvidenceRecord(
        id: EvidenceID(rawValue: "evidence-out-of-range-date")!,
        targetID: SnapshotID(rawValue: "snapshot-out-of-range-date")!,
        kind: .activity,
        source: EvidenceSource(
            kind: .system,
            identifier: DomainToken(rawValue: "source.invalid-date")!
        ),
        summaryKey: DomainToken(rawValue: "summary.invalid-date")!,
        observedAt: Date(
            timeIntervalSince1970: 9_223_372_036_854_776
        ),
        freshness: .current
    )

    #expect(throws: InvestigationSourceProjectionError.storageMismatch) {
        _ = try InvestigationStoredSourceRow(
            record: .evidence(evidence),
            storageColumns: [
                .init(
                    name: "id",
                    value: .text(evidence.id.rawValue)
                ),
                .init(
                    name: "snapshot_id",
                    value: .text(evidence.targetID.rawValue)
                ),
                .init(name: "observed_at_ms", value: .int64(.max)),
            ],
            exactPayload: try DomainJSON.encode(evidence)
        )
    }
}

@Test
func investigationStoredSourceRowBoundsRawStorageBeforeCanonicalAllocation()
    throws
{
    let exactBoundary = try InvestigationStoredSourceRow(
        rowKind: .pathSnapshot,
        storageColumns: [
            .init(name: "id", value: .text("snapshot-boundary")),
            .init(
                name: String(repeating: "n", count: 64),
                value: .text(String(repeating: "x", count: 16_384))
            ),
            .init(name: "session_id", value: .text("scan-boundary")),
            .init(name: "observed_at_ms", value: .int64(.max)),
        ],
        exactPayload: Data()
    )
    #expect(exactBoundary.storageColumns.count == 4)

    let tooManyColumns = (0..<5).map { index in
        InvestigationStorageColumn(
            name: "column-\(index)",
            value: .text("value")
        )
    }
    #expect(throws: InvestigationSourceProjectionError.sourceProjectionTooLarge) {
        _ = try InvestigationStoredSourceRow(
            rowKind: .pathSnapshot,
            storageColumns: tooManyColumns,
            exactPayload: Data()
        )
    }

    #expect(throws: InvestigationSourceProjectionError.sourceProjectionTooLarge) {
        _ = try InvestigationStoredSourceRow(
            rowKind: .pathSnapshot,
            storageColumns: [
                .init(name: "id", value: .text("snapshot-empty-name")),
                .init(name: "", value: .text("value")),
            ],
            exactPayload: Data()
        )
    }

    #expect(throws: InvestigationSourceProjectionError.sourceProjectionTooLarge) {
        _ = try InvestigationStoredSourceRow(
            rowKind: .pathSnapshot,
            storageColumns: [
                .init(
                    name: String(repeating: "n", count: 65),
                    value: .text("value")
                ),
            ],
            exactPayload: Data()
        )
    }

    #expect(throws: InvestigationSourceProjectionError.sourceProjectionTooLarge) {
        _ = try InvestigationStoredSourceRow(
            rowKind: .pathSnapshot,
            storageColumns: [
                .init(
                    name: "relative_path",
                    value: .text(String(repeating: "x", count: 16_385))
                ),
            ],
            exactPayload: Data()
        )
    }
}

@Test(arguments: [
    SecondPassMutation.earlyEnd,
    .extraRow,
    .changedRow,
    .generationChanged,
])
private func investigationSourceProjectionRejectsSecondPassDrift(
    mutation: SecondPassMutation
) throws {
    let fixture = try InvestigationSourceFixture()
    let secondRows: [InvestigationStoredSourceRow]
    let generations: [InvestigationSourceGeneration]
    switch mutation {
    case .earlyEnd:
        secondRows = Array(fixture.rows.dropLast())
        generations = [fixture.generation, fixture.generation]
    case .extraRow:
        secondRows = fixture.rows + [fixture.rows.last!]
        generations = [fixture.generation, fixture.generation]
    case .changedRow:
        let changed = try fixture.changedLedgerRow()
        secondRows = [fixture.rows[0], changed, fixture.rows[2]]
        generations = [fixture.generation, fixture.generation]
    case .generationChanged:
        secondRows = fixture.rows
        generations = [
            fixture.generation,
            InvestigationSourceGeneration(
                token: DomainToken(rawValue: "source-generation-2")!
            ),
        ]
    }
    var factory = TestInvestigationSourceFactory(
        scanSessionID: fixture.session.id,
        primaryScopeID: fixture.scopeID,
        generations: generations,
        relevanceTokens: [],
        passes: [fixture.rows, secondRows]
    )
    var sink = CollectingInvestigationManifestSink()

    #expect(throws: InvestigationSourceProjectionError.secondPassDrift) {
        _ = try InvestigationSourceProjectionBuilder().build(
            factory: &factory,
            planningAt: fixture.finishedAt.addingTimeInterval(1),
            manifestSink: &sink
        )
    }
}

@Test
func investigationSourceProjectionRejectsSelectedIdentityDrift() throws {
    let fixture = try InvestigationSourceFixture()
    var factory = IdentityDriftingInvestigationSourceFactory(
        firstScanSessionID: fixture.session.id,
        secondScanSessionID: ScanSessionID(
            rawValue: "scan-projection-drifted"
        )!,
        firstScopeID: fixture.scopeID,
        secondScopeID: ScanScopeID(
            rawValue: "scope-projection-drifted"
        )!,
        generation: fixture.generation,
        relevanceTokens: [],
        passes: [fixture.rows, fixture.rows]
    )
    var sink = CollectingInvestigationManifestSink()

    #expect(throws: InvestigationSourceProjectionError.secondPassDrift) {
        _ = try InvestigationSourceProjectionBuilder().build(
            factory: &factory,
            planningAt: fixture.finishedAt.addingTimeInterval(1),
            manifestSink: &sink
        )
    }
}

@Test
func investigationSourceProjectionRejectsNonCanonicalRelevanceAndRowOrder()
    throws
{
    let fixture = try InvestigationSourceFixture()
    var relevanceFactory = TestInvestigationSourceFactory(
        scanSessionID: fixture.session.id,
        primaryScopeID: fixture.scopeID,
        generations: [fixture.generation, fixture.generation],
        relevanceTokens: [
            DomainToken(rawValue: "relevance.developer")!,
            DomainToken(rawValue: "relevance.large")!,
        ],
        passes: [fixture.rows, fixture.rows]
    )
    var sink = CollectingInvestigationManifestSink()
    #expect(throws: InvestigationSourceProjectionError.nonCanonicalOrder) {
        _ = try InvestigationSourceProjectionBuilder().build(
            factory: &relevanceFactory,
            planningAt: fixture.finishedAt.addingTimeInterval(1),
            manifestSink: &sink
        )
    }

    let reversed = Array(fixture.rows.reversed())
    var rowFactory = TestInvestigationSourceFactory(
        scanSessionID: fixture.session.id,
        primaryScopeID: fixture.scopeID,
        generations: [fixture.generation, fixture.generation],
        relevanceTokens: [],
        passes: [reversed, reversed]
    )
    var rowSink = CollectingInvestigationManifestSink()
    #expect(throws: InvestigationSourceProjectionError.nonCanonicalOrder) {
        _ = try InvestigationSourceProjectionBuilder().build(
            factory: &rowFactory,
            planningAt: fixture.finishedAt.addingTimeInterval(1),
            manifestSink: &rowSink
        )
    }
}

@Test
func investigationSourceProjectionRejectsExpiredAndMismatchedMembership()
    throws
{
    let fixture = try InvestigationSourceFixture()
    var expiredFactory = TestInvestigationSourceFactory(
        scanSessionID: fixture.session.id,
        primaryScopeID: fixture.scopeID,
        generations: [fixture.generation, fixture.generation],
        relevanceTokens: [],
        passes: [fixture.rows, fixture.rows]
    )
    var expiredSink = CollectingInvestigationManifestSink()
    #expect(throws: InvestigationSourceProjectionError.sourceExpired) {
        _ = try InvestigationSourceProjectionBuilder().build(
            factory: &expiredFactory,
            planningAt: fixture.expiresAt,
            manifestSink: &expiredSink
        )
    }

    var mismatchedFactory = TestInvestigationSourceFactory(
        scanSessionID: ScanSessionID(rawValue: "scan-another")!,
        primaryScopeID: fixture.scopeID,
        generations: [fixture.generation, fixture.generation],
        relevanceTokens: [],
        passes: [fixture.rows, fixture.rows]
    )
    var mismatchedSink = CollectingInvestigationManifestSink()
    #expect(throws: InvestigationSourceProjectionError.membershipMismatch) {
        _ = try InvestigationSourceProjectionBuilder().build(
            factory: &mismatchedFactory,
            planningAt: fixture.finishedAt.addingTimeInterval(1),
            manifestSink: &mismatchedSink
        )
    }
}

@Test
func investigationSourceAccountingKeepsIndependentCapacityBounds() throws {
    var accounting = InvestigationSourceProjectionAccounting()
    try accounting.add(
        rowKind: .scanSession,
        payloadBytes: 1_048_576,
        canonicalRowBytes: 1_024
    )
    try accounting.add(
        rowKind: .spaceLedger,
        payloadBytes: 16 * 1_048_576,
        canonicalRowBytes: 1_024
    )
    try accounting.addSyntheticPayloadBytes(
        256 * 1_048_576 - accounting.exactPayloadBytes
    )
    #expect(accounting.exactPayloadBytes == 256 * 1_048_576)
    #expect(throws: InvestigationSourceProjectionError.sourceProjectionTooLarge) {
        try accounting.addSyntheticPayloadBytes(1)
    }

    var canonicalAccounting = InvestigationSourceProjectionAccounting()
    try canonicalAccounting.addSyntheticCanonicalBytes(512 * 1_048_576)
    #expect(
        canonicalAccounting.completeCanonicalBytes == 512 * 1_048_576
    )
    #expect(throws: InvestigationSourceProjectionError.sourceProjectionTooLarge) {
        try canonicalAccounting.addSyntheticCanonicalBytes(1)
    }
}

@Test(arguments: InvestigationSourceRowKind.allCases)
func investigationSourceAccountingEnforcesPerRowPayloadLimits(
    rowKind: InvestigationSourceRowKind
) throws {
    var accounting = InvestigationSourceProjectionAccounting()
    try accounting.add(
        rowKind: rowKind,
        payloadBytes: rowKind.payloadByteLimit,
        canonicalRowBytes: 1
    )
    #expect(accounting.sourceRowCount == 1)

    var rejected = InvestigationSourceProjectionAccounting()
    #expect(throws: InvestigationSourceProjectionError.sourceProjectionTooLarge) {
        try rejected.add(
            rowKind: rowKind,
            payloadBytes: rowKind.payloadByteLimit + 1,
            canonicalRowBytes: 1
        )
    }
    #expect(rejected == InvestigationSourceProjectionAccounting())
}

@Test
func investigationSourceAccountingEnforcesEveryRowCountLimitAtomically()
    throws
{
    let cases: [(InvestigationSourceRowKind, UInt64)] = [
        (.pathSnapshot, InvestigationSourceProjectionAccounting.maximumPathSnapshots),
        (
            .classification,
            InvestigationSourceProjectionAccounting.maximumClassifications
        ),
        (.evidence, InvestigationSourceProjectionAccounting.maximumEvidence),
    ]
    for (rowKind, limit) in cases {
        var accounting = InvestigationSourceProjectionAccounting()
        for _ in 0..<limit {
            try accounting.add(
                rowKind: rowKind,
                payloadBytes: 0,
                canonicalRowBytes: 0
            )
        }
        let atLimit = accounting
        #expect(accounting.sourceRowCount == limit)
        #expect(throws: InvestigationSourceProjectionError.sourceProjectionTooLarge) {
            try accounting.add(
                rowKind: rowKind,
                payloadBytes: 0,
                canonicalRowBytes: 0
            )
        }
        #expect(accounting == atLimit)
    }

    var totalRows = InvestigationSourceProjectionAccounting()
    try totalRows.add(
        rowKind: .scanSession,
        payloadBytes: 0,
        canonicalRowBytes: 0
    )
    try totalRows.add(
        rowKind: .spaceLedger,
        payloadBytes: 0,
        canonicalRowBytes: 0
    )
    for _ in 0..<InvestigationSourceProjectionAccounting.maximumPathSnapshots {
        try totalRows.add(
            rowKind: .pathSnapshot,
            payloadBytes: 0,
            canonicalRowBytes: 0
        )
    }
    for _ in 0..<InvestigationSourceProjectionAccounting.maximumClassifications {
        try totalRows.add(
            rowKind: .classification,
            payloadBytes: 0,
            canonicalRowBytes: 0
        )
    }
    for _ in 0..<InvestigationSourceProjectionAccounting.maximumEvidence {
        try totalRows.add(
            rowKind: .evidence,
            payloadBytes: 0,
            canonicalRowBytes: 0
        )
    }
    #expect(
        totalRows.sourceRowCount
            == InvestigationSourceProjectionAccounting.maximumSourceRows
    )
}

private enum SecondPassMutation: Sendable {
    case earlyEnd
    case extraRow
    case changedRow
    case generationChanged
}

private func canonicalValue(
    for row: InvestigationSourceManifestRow
) -> InvestigationCanonicalValue {
    .record([
        .init(tag: 1, value: .text(row.rowKind.rawValue)),
        .init(tag: 2, value: .text(row.primaryID)),
        .init(
            tag: 3,
            value: .array(row.storageColumns.map(canonicalValue))
        ),
        .init(tag: 4, value: .unsigned(row.payloadByteCount)),
        .init(tag: 5, value: .bytes(row.payloadSHA256.bytes)),
    ])
}

private func binaryManifestRow(
    kind: InvestigationSourceRowKind,
    primaryID: String,
    columns: [InvestigationStorageColumn]
) -> InvestigationSourceManifestRow {
    InvestigationSourceManifestRow(
        rowKind: kind,
        primaryID: primaryID,
        storageColumns: columns,
        payloadByteCount: 0,
        payloadSHA256: try! InvestigationFingerprint(
            validating: Data(repeating: UInt8(kind.rawValue.utf8.count), count: 32)
        )
    )
}

private func binarySourceProjection(
    sessionID: ScanSessionID,
    scopeID: ScanScopeID,
    rows: [InvestigationSourceManifestRow]
) throws -> Data {
    let orderedRows = try rows.map { row in
        let value = canonicalValue(for: row)
        var bytes = Data()
        try StornautInvestigationCanonicalV1.appendValueForSchema(
            value,
            to: &bytes
        )
        return (value, bytes)
    }.sorted {
        $0.1.lexicographicallyPrecedes($1.1)
    }.map(\.0)
    return try StornautInvestigationCanonicalV1.encode(
        domain: "stornaut.investigation.source.v1",
        root: .record([
            .init(tag: 1, value: .unsigned(1)),
            .init(tag: 2, value: .text(sessionID.rawValue)),
            .init(tag: 3, value: .text(scopeID.rawValue)),
            .init(tag: 4, value: .array(orderedRows)),
            .init(tag: 5, value: .array([])),
        ])
    )
}

private func replacingSourceRowField(
    tag: UInt16,
    rowIndex: Int,
    in root: InvestigationCanonicalValue,
    with replacement: InvestigationCanonicalValue
) throws -> InvestigationCanonicalValue {
    guard case let .record(rootFields) = root else {
        throw InvestigationSourceProjectionError.payloadMismatch
    }
    return .record(
        try rootFields.map { field in
            guard field.tag == 4 else {
                return field
            }
            guard case var .array(rows) = field.value,
                  rows.indices.contains(rowIndex),
                  case let .record(rowFields) = rows[rowIndex],
                  rowFields.contains(where: { $0.tag == tag })
            else {
                throw InvestigationSourceProjectionError.payloadMismatch
            }
            rows[rowIndex] = .record(
                rowFields.map { rowField in
                    rowField.tag == tag
                        ? InvestigationCanonicalField(
                            tag: tag,
                            value: replacement
                        )
                        : rowField
                }
            )
            return InvestigationCanonicalField(
                tag: 4,
                value: .array(rows)
            )
        }
    )
}

private func canonicalValue(
    for column: InvestigationStorageColumn
) -> InvestigationCanonicalValue {
    switch column.value {
    case let .text(value):
        .record([
            .init(tag: 1, value: .text(column.name)),
            .init(tag: 2, value: .text("text-v1")),
            .init(tag: 3, value: .text(value)),
            .init(tag: 4, value: .null),
        ])
    case let .int64(value):
        .record([
            .init(tag: 1, value: .text(column.name)),
            .init(tag: 2, value: .text("int64-v1")),
            .init(tag: 3, value: .null),
            .init(tag: 4, value: .signed(value)),
        ])
    }
}

private func normalizedHex(_ value: String) -> String {
    value.filter(\.isHexDigit).lowercased()
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

private struct IdentityDriftingInvestigationSourceFactory:
    InvestigationSourceCursorFactory
{
    let firstScanSessionID: ScanSessionID
    let secondScanSessionID: ScanSessionID
    let firstScopeID: ScanScopeID
    let secondScopeID: ScanScopeID
    let generation: InvestigationSourceGeneration
    let relevanceTokens: [DomainToken]
    let passes: [[InvestigationStoredSourceRow]]
    var makeCursorCount = 0

    var scanSessionID: ScanSessionID {
        makeCursorCount < 2 ? firstScanSessionID : secondScanSessionID
    }

    var primaryScopeID: ScanScopeID {
        makeCursorCount < 2 ? firstScopeID : secondScopeID
    }

    mutating func makeCursor() throws -> any InvestigationSourceCursor {
        guard makeCursorCount < passes.count else {
            throw InvestigationSourceProjectionError.cursorCountExceeded
        }
        defer { makeCursorCount += 1 }
        return TestInvestigationSourceCursor(rows: passes[makeCursorCount])
    }
}

private struct TestInvestigationSourceCursor: InvestigationSourceCursor {
    var rows: [InvestigationStoredSourceRow]
    var index = 0

    mutating func next() throws -> InvestigationStoredSourceRow? {
        guard index < rows.count else {
            return nil
        }
        defer { index += 1 }
        return rows[index]
    }
}

private struct TestInvestigationSourceFactory:
    InvestigationSourceCursorFactory
{
    let scanSessionID: ScanSessionID
    let primaryScopeID: ScanScopeID
    let generations: [InvestigationSourceGeneration]
    let relevanceTokens: [DomainToken]
    let passes: [[InvestigationStoredSourceRow]]
    var makeCursorCount = 0

    var generation: InvestigationSourceGeneration {
        generations[min(makeCursorCount, generations.count - 1)]
    }

    mutating func makeCursor() throws -> any InvestigationSourceCursor {
        guard makeCursorCount < passes.count else {
            throw InvestigationSourceProjectionError.cursorCountExceeded
        }
        defer { makeCursorCount += 1 }
        return TestInvestigationSourceCursor(rows: passes[makeCursorCount])
    }
}

private struct CollectingInvestigationManifestSink:
    InvestigationManifestSink
{
    var rows: [InvestigationSourceManifestRow] = []

    mutating func record(_ row: InvestigationSourceManifestRow) throws {
        rows.append(row)
    }
}

private struct InvestigationSourceFixture {
    let session: ScanSession
    let scopeID: ScanScopeID
    let rootSnapshot: PathSnapshot
    let ledger: SpaceLedger
    let finishedAt: Date
    let expiresAt: Date
    let generation: InvestigationSourceGeneration
    let rows: [InvestigationStoredSourceRow]
    let sessionColumns: [InvestigationStorageColumn]

    init() throws {
        let sessionID = ScanSessionID(rawValue: "scan-projection-fixture")!
        scopeID = ScanScopeID(rawValue: "scope-projection-fixture")!
        finishedAt = Date(timeIntervalSince1970: 1_800_000_000)
        expiresAt = finishedAt.addingTimeInterval(7 * 86_400)
        generation = InvestigationSourceGeneration(
            token: DomainToken(rawValue: "source-generation-1")!
        )
        let rootPath = PersistedPath(rawValue: "/fixture")!
        let rootIdentity = try FileIdentity(
            device: 1,
            inode: 1,
            mode: UInt16(S_IFDIR | 0o755),
            ownerUserID: 501,
            ownerGroupID: 20,
            size: 0,
            allocatedBytes: 0,
            modificationSeconds: 1_800_000_000,
            modificationNanoseconds: 0
        )
        session = try ScanSession(
            id: sessionID,
            startedAt: finishedAt.addingTimeInterval(-60),
            finishedAt: finishedAt,
            terminalState: .completed,
            completedScopes: [
                ScanScope(
                    id: scopeID,
                    rootPath: rootPath,
                    completedAt: finishedAt
                ),
            ],
            unfinishedScopes: []
        )
        rootSnapshot = try PathSnapshot(
            id: SnapshotID(rawValue: "snapshot-projection-root")!,
            sessionID: sessionID,
            scopeID: scopeID,
            relativePath: ".",
            kind: .directory,
            logicalByteCount: ByteCount(0),
            allocatedByteCount: ByteCount(0),
            modifiedAt: finishedAt,
            fileIdentity: rootIdentity,
            symlinkTarget: nil,
            measurementStatus: .measured,
            observedAt: finishedAt
        )
        let start = try VolumeBaseline(
            sessionID: sessionID,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: rootIdentity,
            totalCapacity: ByteCount(2_000),
            availableCapacity: ByteCount(1_000),
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: false,
            source: AccountingSource(
                kind: .volumeResourceValues,
                identifier: DomainToken(rawValue: "projection.start")!,
                sampledAt: finishedAt.addingTimeInterval(-60)
            )
        )
        let end = try VolumeBaseline(
            sessionID: sessionID,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: rootIdentity,
            totalCapacity: ByteCount(2_000),
            availableCapacity: ByteCount(900),
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: false,
            source: AccountingSource(
                kind: .volumeResourceValues,
                identifier: DomainToken(rawValue: "projection.end")!,
                sampledAt: finishedAt
            )
        )
        ledger = try SpaceLedgerReconciler().reconcile(
            SpaceLedgerInput(
                startBaseline: start,
                endBaseline: end,
                snapshots: [rootSnapshot],
                classifications: []
            )
        )
        sessionColumns = [
            .init(name: "id", value: .text(sessionID.rawValue)),
            .init(
                name: "expires_at_ms",
                value: .int64(Int64(expiresAt.timeIntervalSince1970 * 1_000))
            ),
            .init(
                name: "started_at_ms",
                value: .int64(
                    Int64(
                        session.startedAt.timeIntervalSince1970 * 1_000
                    )
                )
            ),
            .init(
                name: "finished_at_ms",
                value: .int64(
                    Int64(
                        session.finishedAt.timeIntervalSince1970 * 1_000
                    )
                )
            ),
        ]
        let sessionRow = try InvestigationStoredSourceRow(
            record: .scanSession(session),
            storageColumns: sessionColumns,
            exactPayload: DomainJSON.encode(session)
        )
        let ledgerRow = try InvestigationStoredSourceRow(
            record: .spaceLedger(ledger),
            storageColumns: [
                .init(name: "id", value: .text(sessionID.rawValue)),
                .init(
                    name: "session_id",
                    value: .text(sessionID.rawValue)
                ),
            ],
            exactPayload: DomainJSON.encode(ledger)
        )
        let snapshotRow = try InvestigationStoredSourceRow(
            record: .pathSnapshot(rootSnapshot),
            storageColumns: [
                .init(
                    name: "id",
                    value: .text(rootSnapshot.id.rawValue)
                ),
                .init(
                    name: "session_id",
                    value: .text(sessionID.rawValue)
                ),
                .init(
                    name: "relative_path",
                    value: .text(rootSnapshot.relativePath)
                ),
                .init(
                    name: "observed_at_ms",
                    value: .int64(
                        Int64(
                            rootSnapshot.observedAt.timeIntervalSince1970
                                * 1_000
                        )
                    )
                ),
            ],
            exactPayload: DomainJSON.encode(rootSnapshot)
        )
        rows = [sessionRow, ledgerRow, snapshotRow]
    }

    func changedLedgerRow() throws -> InvestigationStoredSourceRow {
        let changedEnd = try VolumeBaseline(
            sessionID: session.id,
            scopeID: scopeID,
            rootPath: session.completedScopes[0].rootPath,
            rootIdentity: rootSnapshot.fileIdentity!,
            totalCapacity: ByteCount(2_000),
            availableCapacity: ByteCount(899),
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: false,
            source: AccountingSource(
                kind: .volumeResourceValues,
                identifier: DomainToken(rawValue: "projection.changed")!,
                sampledAt: finishedAt
            )
        )
        let start = try VolumeBaseline(
            sessionID: session.id,
            scopeID: scopeID,
            rootPath: session.completedScopes[0].rootPath,
            rootIdentity: rootSnapshot.fileIdentity!,
            totalCapacity: ByteCount(2_000),
            availableCapacity: ByteCount(1_000),
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: false,
            source: AccountingSource(
                kind: .volumeResourceValues,
                identifier: DomainToken(rawValue: "projection.start")!,
                sampledAt: finishedAt.addingTimeInterval(-60)
            )
        )
        let changed = try SpaceLedgerReconciler().reconcile(
            SpaceLedgerInput(
                startBaseline: start,
                endBaseline: changedEnd,
                snapshots: [rootSnapshot],
                classifications: []
            )
        )
        return try InvestigationStoredSourceRow(
            record: .spaceLedger(changed),
            storageColumns: [
                .init(name: "id", value: .text(session.id.rawValue)),
                .init(
                    name: "session_id",
                    value: .text(session.id.rawValue)
                ),
            ],
            exactPayload: DomainJSON.encode(changed)
        )
    }
}
