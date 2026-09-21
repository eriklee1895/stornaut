import Darwin
import Foundation
import Testing
@testable import StornautCore

@Test
func investigationSourceProjectionMaximumStreamingBenchmark() throws {
    let fixture = try InvestigationStreamingBenchmarkFixture()
    let tracker = InvestigationFootprintTracker()
    let baselineFootprint = try tracker.sample()
    var factory = InvestigationStreamingBenchmarkFactory(
        fixture: fixture
    )
    var sink = InvestigationCountingManifestSink()
    let clock = ContinuousClock()

    let duration = try clock.measure {
        let projection = try InvestigationSourceProjectionBuilder().build(
            factory: &factory,
            planningAt: fixture.finishedAt.addingTimeInterval(1),
            manifestSink: &sink
        )
        #expect(projection.summary.sourceRowCount == 300_002)
        #expect(projection.summary.pathSnapshotCount == 100_000)
        #expect(projection.summary.classificationCount == 100_000)
        #expect(projection.summary.evidenceCount == 100_000)
        #expect(
            projection.summary.exactPayloadBytes
                == InvestigationSourceProjectionAccounting
                    .maximumExactPayloadBytes
        )
        #expect(projection.policyIndex.snapshots.count == 100_000)
        #expect(projection.policyIndex.classifications.count == 100_000)
        #expect(projection.policyIndex.evidence.count == 100_000)
    }
    let finalFootprint = try tracker.sample()
    let peakFootprint = try tracker.peakFootprint()
    let observedPeak = max(peakFootprint, finalFootprint)
    guard observedPeak >= baselineFootprint else {
        throw InvestigationBenchmarkError.invalidPeakFootprint(
            Int64(bitPattern: observedPeak)
        )
    }
    let peakIncrement = observedPeak - baselineFootprint

    #expect(factory.makeCursorCount == 2)
    #expect(sink.rowCount == 300_002)
    #expect(
        sink.payloadBytes
            == InvestigationSourceProjectionAccounting.maximumExactPayloadBytes
    )
    #expect(duration < .seconds(60))
    #expect(peakIncrement < 208 * 1_048_576)
    print(
        "Investigation source benchmark:",
        "duration=\(duration)",
        "peakIncrement=\(peakIncrement)",
        "payloadBytes=\(sink.payloadBytes)"
    )
}

@Test
func investigationCandidatePlannerHundredThousandRowBenchmark() throws {
    let fixture = try InvestigationCandidateBenchmarkFixture(rowCount: 50_000)
    let planner = InvestigationCandidatePlanner()
    let clock = ContinuousClock()
    let investigationID = InvestigationID(
        rawValue: "investigation-benchmark"
    )!
    var first: InvestigationPlanningResult?
    var second: InvestigationPlanningResult?

    let duration = try clock.measure {
        first = try planner.plan(
            investigationID: investigationID,
            source: fixture.source,
            budgetPreset: .thorough,
            planningAt: fixture.planningAt
        )
        second = try planner.plan(
            investigationID: investigationID,
            source: fixture.shuffledSource,
            budgetPreset: .thorough,
            planningAt: fixture.planningAt
        )
    }

    let firstResult = try #require(first)
    let secondResult = try #require(second)
    #expect(fixture.source.summary.sourceRowCount == 100_002)
    #expect(fixture.source.summary.pathSnapshotCount == 50_000)
    #expect(fixture.source.summary.classificationCount == 50_000)
    #expect(firstResult.diagnostics.consideredCount == 50_000)
    #expect(firstResult.plan.targets.count == 512)
    #expect(firstResult.diagnostics.omittedCount == 49_488)
    #expect(
        firstResult.plan.targets.map(\.id)
            == secondResult.plan.targets.map(\.id)
    )
    #expect(firstResult.plan.fingerprint == secondResult.plan.fingerprint)
    #expect(
        firstResult.plan.targets.dropFirst().enumerated().allSatisfy {
            index, target in
            let previous = firstResult.plan.targets[index]
            return previous.priority.tier == .measured
                && target.priority.tier == .measured
                && previous.priority.score >= target.priority.score
        }
    )
    #expect(duration < .seconds(20))
    print(
        "Investigation candidate benchmark:",
        "duration=\(duration)",
        "policyRows=\(fixture.source.summary.sourceRowCount - 2)",
        "considered=\(firstResult.diagnostics.consideredCount)"
    )
}

private final class InvestigationFootprintTracker: @unchecked Sendable {
    @discardableResult
    func sample() throws -> UInt64 {
        try taskVMInfo().phys_footprint
    }

    func peakFootprint() throws -> UInt64 {
        let peak = try taskVMInfo().ledger_phys_footprint_peak
        guard peak >= 0 else {
            throw InvestigationBenchmarkError.invalidPeakFootprint(peak)
        }
        return UInt64(peak)
    }

    private func taskVMInfo() throws -> task_vm_info_data_t {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size
                / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) { rebound in
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    rebound,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else {
            throw InvestigationBenchmarkError.footprintUnavailable(result)
        }
        return info
    }
}

private enum InvestigationBenchmarkError: Error {
    case cursorCountExceeded
    case footprintUnavailable(kern_return_t)
    case invalidPeakFootprint(Int64)
    case payloadTemplateMismatch
}

private struct InvestigationStreamingBenchmarkFactory:
    InvestigationSourceCursorFactory
{
    let fixture: InvestigationStreamingBenchmarkFixture
    var makeCursorCount = 0

    var scanSessionID: ScanSessionID {
        fixture.session.id
    }

    var primaryScopeID: ScanScopeID {
        fixture.scopeID
    }

    var generation: InvestigationSourceGeneration {
        fixture.generation
    }

    var relevanceTokens: [DomainToken] {
        fixture.relevanceTokens
    }

    mutating func makeCursor() throws -> any InvestigationSourceCursor {
        guard makeCursorCount < 2 else {
            throw InvestigationBenchmarkError.cursorCountExceeded
        }
        makeCursorCount += 1
        return InvestigationStreamingBenchmarkCursor(
            fixture: fixture
        )
    }
}

private struct InvestigationStreamingBenchmarkCursor:
    InvestigationSourceCursor
{
    let fixture: InvestigationStreamingBenchmarkFixture
    var index = 0

    mutating func next() throws -> InvestigationStoredSourceRow? {
        guard index < 300_002 else {
            return nil
        }
        defer { index += 1 }
        switch index {
        case 0..<100_000:
            return try fixture.evidenceRow(index)
        case 100_000:
            return fixture.sessionRow
        case 100_001:
            return fixture.ledgerRow
        case 100_002..<200_002:
            return try fixture.snapshotRow(index - 100_002)
        default:
            return try fixture.classificationRow(index - 200_002)
        }
    }
}

private struct InvestigationCountingManifestSink:
    InvestigationManifestSink
{
    var rowCount: UInt64 = 0
    var payloadBytes: UInt64 = 0

    mutating func record(
        _ row: InvestigationSourceManifestRow
    ) throws {
        rowCount += 1
        payloadBytes += row.payloadByteCount
    }
}

private struct InvestigationStreamingBenchmarkFixture: Sendable {
    private static let templateMarker = "999999"

    let session: ScanSession
    let scopeID: ScanScopeID
    let ledger: SpaceLedger
    let finishedAt: Date
    let generation: InvestigationSourceGeneration
    let relevanceTokens: [DomainToken]
    let sessionRow: InvestigationStoredSourceRow
    let ledgerRow: InvestigationStoredSourceRow
    let evidencePayloadTemplate: InvestigationBenchmarkPayloadTemplate
    let snapshotPayloadTemplate: InvestigationBenchmarkPayloadTemplate
    let classificationPayloadTemplate: InvestigationBenchmarkPayloadTemplate
    let maximumSnapshotPadding: String
    let maximumSnapshotPaddingBytes: Data
    let partialSnapshotPadding: String
    let partialSnapshotPaddingBytes: Data
    let maximumPaddedSnapshotRowCount: Int

    init() throws {
        let sessionID = ScanSessionID(rawValue: "scan-benchmark")!
        scopeID = ScanScopeID(rawValue: "scope-benchmark")!
        finishedAt = Date(timeIntervalSince1970: 1_800_000_000)
        generation = InvestigationSourceGeneration(
            token: DomainToken(rawValue: "benchmark-generation")!
        )
        relevanceTokens = [
            DomainToken(rawValue: "relevance.large")!,
            DomainToken(rawValue: "relevance.developer")!,
        ]
        let rootPath = PersistedPath(rawValue: "/benchmark")!
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
        let start = try VolumeBaseline(
            sessionID: sessionID,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: rootIdentity,
            totalCapacity: ByteCount(10 * 1_073_741_824),
            availableCapacity: ByteCount(5 * 1_073_741_824),
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: false,
            source: AccountingSource(
                kind: .volumeResourceValues,
                identifier: DomainToken(rawValue: "benchmark.start")!,
                sampledAt: finishedAt.addingTimeInterval(-60)
            )
        )
        let end = try VolumeBaseline(
            sessionID: sessionID,
            scopeID: scopeID,
            rootPath: rootPath,
            rootIdentity: rootIdentity,
            totalCapacity: ByteCount(10 * 1_073_741_824),
            availableCapacity: ByteCount(4 * 1_073_741_824),
            availableCapacityForImportantUsage: nil,
            availableCapacityForOpportunisticUsage: nil,
            volumeIsReadOnly: false,
            source: AccountingSource(
                kind: .volumeResourceValues,
                identifier: DomainToken(rawValue: "benchmark.end")!,
                sampledAt: finishedAt
            )
        )
        ledger = try SpaceLedgerReconciler().reconcile(
            SpaceLedgerInput(
                startBaseline: start,
                endBaseline: end,
                snapshots: [],
                classifications: []
            )
        )
        sessionRow = try InvestigationStoredSourceRow(
            record: .scanSession(session),
            storageColumns: [
                .init(name: "id", value: .text(sessionID.rawValue)),
                .init(
                    name: "expires_at_ms",
                    value: .int64(1_800_604_800_000)
                ),
                .init(
                    name: "started_at_ms",
                    value: .int64(1_799_999_940_000)
                ),
                .init(
                    name: "finished_at_ms",
                    value: .int64(1_800_000_000_000)
                ),
            ],
            exactPayload: DomainJSON.encode(session)
        )
        ledgerRow = try InvestigationStoredSourceRow(
            record: .spaceLedger(ledger),
            storageColumns: [
                .init(name: "id", value: .text(sessionID.rawValue)),
                .init(name: "session_id", value: .text(sessionID.rawValue)),
            ],
            exactPayload: DomainJSON.encode(ledger)
        )
        evidencePayloadTemplate = try InvestigationBenchmarkPayloadTemplate(
            payload: DomainJSON.encode(
                Self.evidence(
                    index: 999_999,
                    finishedAt: finishedAt
                )
            ),
            marker: Self.templateMarker,
            expectedOccurrences: 2
        )
        snapshotPayloadTemplate = try InvestigationBenchmarkPayloadTemplate(
            payload: DomainJSON.encode(
                Self.snapshot(
                    index: 999_999,
                    sessionID: sessionID,
                    scopeID: scopeID,
                    finishedAt: finishedAt
                )
            ),
            marker: Self.templateMarker,
            expectedOccurrences: 2
        )
        classificationPayloadTemplate =
            try InvestigationBenchmarkPayloadTemplate(
                payload: DomainJSON.encode(
                    Self.classification(
                        index: 999_999,
                        finishedAt: finishedAt
                    )
                ),
                marker: Self.templateMarker,
                expectedOccurrences: 2
            )
        let targetPayloadBytes =
            InvestigationSourceProjectionAccounting.maximumExactPayloadBytes
        let basePayloadBytes = UInt64(
            sessionRow.exactPayload.count
                + ledgerRow.exactPayload.count
                + 100_000
                    * (
                        evidencePayloadTemplate.renderedByteCount
                            + snapshotPayloadTemplate.renderedByteCount
                            + classificationPayloadTemplate.renderedByteCount
                    )
        )
        guard basePayloadBytes < targetPayloadBytes else {
            throw InvestigationBenchmarkError.payloadTemplateMismatch
        }
        let additionalBytes = targetPayloadBytes - basePayloadBytes
        let maximumRelativePathBytes = 16_384
        let baseRelativePathBytes = "item-\(Self.templateMarker)".utf8.count
        let maximumPaddingByteCount =
            maximumRelativePathBytes - baseRelativePathBytes
        maximumPaddedSnapshotRowCount = Int(
            additionalBytes / UInt64(maximumPaddingByteCount)
        )
        let partialPaddingByteCount = Int(
            additionalBytes % UInt64(maximumPaddingByteCount)
        )
        guard maximumPaddedSnapshotRowCount < 100_000 else {
            throw InvestigationBenchmarkError.payloadTemplateMismatch
        }
        maximumSnapshotPadding = String(
            repeating: "x",
            count: maximumPaddingByteCount
        )
        maximumSnapshotPaddingBytes = Data(
            repeating: 0x78,
            count: maximumPaddingByteCount
        )
        partialSnapshotPadding = String(
            repeating: "x",
            count: partialPaddingByteCount
        )
        partialSnapshotPaddingBytes = Data(
            repeating: 0x78,
            count: partialPaddingByteCount
        )
    }

    func evidenceRow(_ index: Int) throws -> InvestigationStoredSourceRow {
        let suffix = Self.padded(index)
        let evidenceID = "evidence-bench-\(suffix)"
        let snapshotID = "snapshot-bench-\(suffix)"
        return try InvestigationStoredSourceRow(
            rowKind: .evidence,
            storageColumns: [
                .init(name: "id", value: .text(evidenceID)),
                .init(
                    name: "snapshot_id",
                    value: .text(snapshotID)
                ),
                .init(
                    name: "observed_at_ms",
                    value: .int64(1_800_000_000_000)
                ),
            ],
            exactPayload: evidencePayloadTemplate.render(replacingWith: suffix)
        )
    }

    func snapshotRow(_ index: Int) throws -> InvestigationStoredSourceRow {
        let suffix = Self.padded(index)
        let snapshotID = "snapshot-bench-\(suffix)"
        let padding: String
        let paddingBytes: Data
        if index < maximumPaddedSnapshotRowCount {
            padding = maximumSnapshotPadding
            paddingBytes = maximumSnapshotPaddingBytes
        } else if index == maximumPaddedSnapshotRowCount {
            padding = partialSnapshotPadding
            paddingBytes = partialSnapshotPaddingBytes
        } else {
            padding = ""
            paddingBytes = Data()
        }
        return try InvestigationStoredSourceRow(
            rowKind: .pathSnapshot,
            storageColumns: [
                .init(name: "id", value: .text(snapshotID)),
                .init(
                    name: "session_id",
                    value: .text(session.id.rawValue)
                ),
                .init(
                    name: "relative_path",
                    value: .text("item-\(suffix)\(padding)")
                ),
                .init(
                    name: "observed_at_ms",
                    value: .int64(1_800_000_000_000)
                ),
            ],
            exactPayload: snapshotPayloadTemplate.render(
                replacingWith: suffix,
                appending: paddingBytes,
                afterOccurrence: 2
            )
        )
    }

    func classificationRow(
        _ index: Int
    ) throws -> InvestigationStoredSourceRow {
        let suffix = Self.padded(index)
        let classificationID = "classification-bench-\(suffix)"
        let snapshotID = "snapshot-bench-\(suffix)"
        return try InvestigationStoredSourceRow(
            rowKind: .classification,
            storageColumns: [
                .init(
                    name: "id",
                    value: .text(classificationID)
                ),
                .init(
                    name: "disposition",
                    value: .text(ReclaimDisposition.unknown.rawValue)
                ),
                .init(
                    name: "snapshot_id",
                    value: .text(snapshotID)
                ),
                .init(
                    name: "classified_at_ms",
                    value: .int64(1_800_000_000_000)
                ),
            ],
            exactPayload:
                classificationPayloadTemplate.render(replacingWith: suffix)
        )
    }

    private static func evidence(
        index: Int,
        finishedAt: Date
    ) -> EvidenceRecord {
        EvidenceRecord(
            id: evidenceID(index),
            targetID: snapshotID(index),
            kind: .activity,
            source: EvidenceSource(
                kind: .system,
                identifier: DomainToken(rawValue: "benchmark.evidence")!
            ),
            summaryKey: DomainToken(rawValue: "benchmark.current")!,
            observedAt: finishedAt,
            freshness: .current
        )
    }

    private static func snapshot(
        index: Int,
        sessionID: ScanSessionID,
        scopeID: ScanScopeID,
        finishedAt: Date
    ) throws -> PathSnapshot {
        let bytes = Int64(1_073_741_824)
        let identity = try FileIdentity(
            device: 1,
            inode: 10,
            mode: UInt16(S_IFREG | 0o644),
            ownerUserID: 501,
            ownerGroupID: 20,
            size: bytes,
            allocatedBytes: bytes,
            modificationSeconds: 1_800_000_000,
            modificationNanoseconds: 0
        )
        return try PathSnapshot(
            id: snapshotID(index),
            sessionID: sessionID,
            scopeID: scopeID,
            relativePath: "item-\(padded(index))",
            kind: .regularFile,
            logicalByteCount: ByteCount(UInt64(bytes)),
            allocatedByteCount: ByteCount(UInt64(bytes)),
            modifiedAt: finishedAt,
            fileIdentity: identity,
            symlinkTarget: nil,
            measurementStatus: .measured,
            observedAt: finishedAt
        )
    }

    private static func classification(
        index: Int,
        finishedAt: Date
    ) throws -> Classification {
        try Classification(
            id: classificationID(index),
            snapshotID: snapshotID(index),
            ruleID: nil,
            producer: nil,
            category: .unknownLargeConsumers,
            disposition: .unknown,
            risk: .medium,
            confidence: .high,
            recovery: nil,
            requiredEvidenceKeys: [],
            missingEvidenceKeys: [],
            catalogVersion: DomainToken(rawValue: "benchmark.catalog")!,
            classifiedAt: finishedAt
        )
    }

    private static func padded(_ index: Int) -> String {
        String(format: "%06d", index)
    }

    private static func snapshotID(_ index: Int) -> SnapshotID {
        SnapshotID(rawValue: "snapshot-bench-\(padded(index))")!
    }

    private static func classificationID(_ index: Int) -> ClassificationID {
        ClassificationID(
            rawValue: "classification-bench-\(padded(index))"
        )!
    }

    private static func evidenceID(_ index: Int) -> EvidenceID {
        EvidenceID(rawValue: "evidence-bench-\(padded(index))")!
    }
}

private struct InvestigationBenchmarkPayloadTemplate: Sendable {
    let fragments: [Data]
    let renderedByteCount: Int

    init(
        payload: Data,
        marker: String,
        expectedOccurrences: Int
    ) throws {
        let markerBytes = Data(marker.utf8)
        var fragments: [Data] = []
        var start = payload.startIndex
        while let range = payload.range(
            of: markerBytes,
            in: start..<payload.endIndex
        ) {
            fragments.append(payload[start..<range.lowerBound])
            start = range.upperBound
        }
        fragments.append(payload[start..<payload.endIndex])
        guard fragments.count == expectedOccurrences + 1 else {
            throw InvestigationBenchmarkError.payloadTemplateMismatch
        }
        self.fragments = fragments
        renderedByteCount = payload.count
    }

    func render(
        replacingWith replacement: String,
        appending padding: Data = Data(),
        afterOccurrence paddedOccurrence: Int? = nil
    ) -> Data {
        let replacementBytes = Data(replacement.utf8)
        var result = Data()
        result.reserveCapacity(renderedByteCount + padding.count)
        for (index, fragment) in fragments.enumerated() {
            if index > 0 {
                result.append(replacementBytes)
                if index == paddedOccurrence {
                    result.append(padding)
                }
            }
            result.append(fragment)
        }
        return result
    }
}

private struct InvestigationCandidateBenchmarkFixture {
    let planningAt = Date(timeIntervalSince1970: 1_800_000_000)
    let source: InvestigationSourceProjection
    let shuffledSource: InvestigationSourceProjection

    init(rowCount: Int) throws {
        let sessionID = ScanSessionID(rawValue: "scan-candidate-benchmark")!
        let scopeID = ScanScopeID(rawValue: "scope-candidate-benchmark")!
        let sourceValue = AccountingSource(
            kind: .volumeResourceValues,
            identifier: DomainToken(rawValue: "candidate.benchmark")!,
            sampledAt: planningAt
        )
        let zero = try SpaceLedgerMeasure(
            status: .measured,
            bytes: ByteCount(0),
            sources: [sourceValue],
            formulaKey: DomainToken(rawValue: "candidate.zero")!,
            explanationKey: DomainToken(rawValue: "candidate.zero")!
        )
        let session = InvestigationSourceSessionIndex(
            id: sessionID,
            terminalState: .completed,
            completedScopes: [
                ScanScope(
                    id: scopeID,
                    rootPath: PersistedPath(rawValue: "/candidate")!,
                    completedAt: planningAt
                ),
            ],
            unfinishedScopes: [],
            expiresAt: planningAt.addingTimeInterval(7 * 86_400)
        )
        let ledger = InvestigationSourceLedgerIndex(
            sessionID: sessionID,
            status: .reconciled,
            unknown: zero,
            unmeasurable: zero,
            coverageGaps: [],
            unknownIncludesUnmeasurable: false
        )
        var snapshots:
            [SnapshotID: InvestigationSourceSnapshotIndex] = [:]
        var classifications:
            [ClassificationID: InvestigationSourceClassificationIndex] = [:]
        snapshots.reserveCapacity(rowCount)
        classifications.reserveCapacity(rowCount)

        for index in 0..<rowCount {
            let suffix = String(format: "%06d", index)
            let snapshotID = SnapshotID(
                rawValue: "snapshot-candidate-\(suffix)"
            )!
            let classificationID = ClassificationID(
                rawValue: "classification-candidate-\(suffix)"
            )!
            snapshots[snapshotID] = InvestigationSourceSnapshotIndex(
                id: snapshotID,
                scopeID: scopeID,
                expectedAllocatedBytes: ByteCount(
                    UInt64(index + 1) * 1_073_741_824
                ),
                measurementStatus: .measured,
                observedAt: planningAt,
                isRoot: false
            )
            classifications[classificationID] =
                InvestigationSourceClassificationIndex(
                    id: classificationID,
                    snapshotID: snapshotID,
                    ruleID: nil,
                    producer: nil,
                    category: .unknownLargeConsumers,
                    disposition: .unknown,
                    risk: .medium,
                    confidence: .high,
                    requiredEvidenceKeys: [],
                    missingEvidenceKeys: [],
                    classifiedAt: planningAt
                )
        }
        let summary = InvestigationSourceProjectionSummary(
            scanSessionID: sessionID,
            primaryScopeID: scopeID,
            sourceRowCount: UInt64(2 + rowCount * 2),
            pathSnapshotCount: UInt64(rowCount),
            classificationCount: UInt64(rowCount),
            evidenceCount: 0,
            exactPayloadBytes: 0,
            completeCanonicalBytes: 0,
            relevanceTokens: [
                DomainToken(rawValue: "relevance.large")!,
                DomainToken(rawValue: "relevance.developer")!,
            ],
            sourceFingerprint: try InvestigationFingerprint(
                validating: Data(repeating: 9, count: 32)
            )
        )
        source = InvestigationSourceProjection(
            summary: summary,
            policyIndex: InvestigationSourcePolicyIndex(
                session: session,
                ledger: ledger,
                snapshots: snapshots,
                classifications: classifications,
                evidence: [:]
            )
        )
        shuffledSource = InvestigationSourceProjection(
            summary: summary,
            policyIndex: InvestigationSourcePolicyIndex(
                session: session,
                ledger: ledger,
                snapshots: Dictionary(
                    uniqueKeysWithValues: snapshots.reversed()
                ),
                classifications: Dictionary(
                    uniqueKeysWithValues: classifications.reversed()
                ),
                evidence: [:]
            )
        )
    }
}
