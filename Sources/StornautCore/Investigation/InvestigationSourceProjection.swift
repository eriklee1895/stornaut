import CryptoKit
import Foundation

public enum InvestigationSourceProjectionError:
    Error,
    Sendable,
    Equatable
{
    case payloadMismatch
    case storageMismatch
    case sourceProjectionTooLarge
    case nonCanonicalOrder
    case duplicateSourceRow
    case membershipMismatch
    case sourceExpired
    case sourceMissing
    case secondPassDrift
    case cursorCountExceeded
}

public struct InvestigationSourceGeneration:
    Sendable,
    Hashable
{
    public let token: DomainToken

    public init(token: DomainToken) {
        self.token = token
    }
}

public enum InvestigationSourceRowKind:
    String,
    Sendable,
    Hashable,
    CaseIterable
{
    case scanSession = "scan-session-v1"
    case pathSnapshot = "path-snapshot-v1"
    case classification = "classification-v1"
    case evidence = "evidence-v1"
    case spaceLedger = "space-ledger-v1"

    var payloadByteLimit: UInt64 {
        switch self {
        case .spaceLedger:
            16 * 1_048_576
        case .scanSession, .pathSnapshot, .classification, .evidence:
            1_048_576
        }
    }
}

public enum InvestigationStorageValue: Sendable, Hashable {
    case text(String)
    case int64(Int64)
}

public struct InvestigationStorageColumn:
    Sendable,
    Hashable
{
    public let name: String
    public let value: InvestigationStorageValue

    public init(name: String, value: InvestigationStorageValue) {
        self.name = name
        self.value = value
    }
}

public enum InvestigationStoredSourceRecord: Sendable, Equatable {
    case scanSession(ScanSession)
    case pathSnapshot(PathSnapshot)
    case classification(Classification)
    case evidence(EvidenceRecord)
    case spaceLedger(SpaceLedger)

    public var rowKind: InvestigationSourceRowKind {
        switch self {
        case .scanSession:
            .scanSession
        case .pathSnapshot:
            .pathSnapshot
        case .classification:
            .classification
        case .evidence:
            .evidence
        case .spaceLedger:
            .spaceLedger
        }
    }
}

public struct InvestigationStoredSourceRow: Sendable {
    public let rowKind: InvestigationSourceRowKind
    public let storageColumns: [InvestigationStorageColumn]
    public let exactPayload: Data

    public init(
        rowKind: InvestigationSourceRowKind,
        storageColumns: [InvestigationStorageColumn],
        exactPayload: Data
    ) throws {
        guard UInt64(exactPayload.count) <= rowKind.payloadByteLimit else {
            throw InvestigationSourceProjectionError.sourceProjectionTooLarge
        }
        try InvestigationSourceRawStorageBounds.validate(storageColumns)
        let primaryID: String
        do {
            primaryID = try storageColumns.primaryID(for: rowKind)
        } catch {
            throw InvestigationSourceProjectionError.storageMismatch
        }
        _ = try SourceCanonicalLayout(
            rowKind: rowKind,
            primaryID: primaryID,
            storageColumns: storageColumns,
            payloadSHAByteCount: SHA256.byteCount
        )
        self.rowKind = rowKind
        self.storageColumns = storageColumns
        self.exactPayload = exactPayload
    }

    public init(
        record: InvestigationStoredSourceRecord,
        storageColumns: [InvestigationStorageColumn],
        exactPayload: Data
    ) throws {
        try self.init(
            rowKind: record.rowKind,
            storageColumns: storageColumns,
            exactPayload: exactPayload
        )
        let decoded = try validatedRecord(
            using: DomainJSONCanonicalCodec()
        )
        guard decoded == record else {
            throw InvestigationSourceProjectionError.payloadMismatch
        }
    }

    func validatedRecord(
        using codec: DomainJSONCanonicalCodec
    ) throws -> InvestigationStoredSourceRecord {
        do {
            let record: InvestigationStoredSourceRecord
            switch rowKind {
            case .scanSession:
                let decoded = try codec.decode(
                    ScanSession.self,
                    from: exactPayload
                )
                record = .scanSession(decoded)
            case .pathSnapshot:
                let decoded = try codec.decode(
                    PathSnapshot.self,
                    from: exactPayload
                )
                record = .pathSnapshot(decoded)
            case .classification:
                let decoded = try codec.decode(
                    Classification.self,
                    from: exactPayload
                )
                record = .classification(decoded)
            case .evidence:
                let decoded = try codec.decode(
                    EvidenceRecord.self,
                    from: exactPayload
                )
                record = .evidence(decoded)
            case .spaceLedger:
                let decoded = try codec.decode(
                    SpaceLedger.self,
                    from: exactPayload
                )
                record = .spaceLedger(decoded)
            }
            guard storageColumns == (try record.expectedStorageColumns) else {
                throw InvestigationSourceProjectionError.storageMismatch
            }
            return record
        } catch let error as InvestigationSourceProjectionError {
            throw error
        } catch {
            throw InvestigationSourceProjectionError.payloadMismatch
        }
    }
}

public protocol InvestigationSourceCursor: Sendable {
    mutating func next() throws -> InvestigationStoredSourceRow?
}

public protocol InvestigationSourceCursorFactory {
    var scanSessionID: ScanSessionID { get }
    var primaryScopeID: ScanScopeID { get }
    var generation: InvestigationSourceGeneration { get }
    var relevanceTokens: [DomainToken] { get }

    mutating func makeCursor() throws -> any InvestigationSourceCursor
}

public protocol InvestigationManifestSink {
    mutating func record(
        _ row: InvestigationSourceManifestRow
    ) throws
}

public struct InvestigationSourceManifestRow: Sendable, Hashable {
    public let rowKind: InvestigationSourceRowKind
    public let primaryID: String
    public let storageColumns: [InvestigationStorageColumn]
    public let payloadByteCount: UInt64
    public let payloadSHA256: InvestigationFingerprint

    init(
        rowKind: InvestigationSourceRowKind,
        primaryID: String,
        storageColumns: [InvestigationStorageColumn],
        payloadByteCount: UInt64,
        payloadSHA256: InvestigationFingerprint
    ) {
        self.rowKind = rowKind
        self.primaryID = primaryID
        self.storageColumns = storageColumns
        self.payloadByteCount = payloadByteCount
        self.payloadSHA256 = payloadSHA256
    }
}

public struct InvestigationSourceProjectionAccounting:
    Sendable,
    Equatable
{
    public static let maximumPathSnapshots: UInt64 = 100_000
    public static let maximumClassifications: UInt64 = 100_000
    public static let maximumEvidence: UInt64 = 100_000
    public static let maximumEvidencePerSnapshot: UInt64 = 100
    public static let maximumSourceRows: UInt64 = 300_002
    public static let maximumExactPayloadBytes: UInt64 = 256 * 1_048_576
    public static let maximumCanonicalBytes: UInt64 = 512 * 1_048_576

    public private(set) var sourceRowCount: UInt64 = 0
    public private(set) var scanSessionCount: UInt64 = 0
    public private(set) var pathSnapshotCount: UInt64 = 0
    public private(set) var classificationCount: UInt64 = 0
    public private(set) var evidenceCount: UInt64 = 0
    public private(set) var spaceLedgerCount: UInt64 = 0
    public private(set) var exactPayloadBytes: UInt64 = 0
    public private(set) var completeCanonicalBytes: UInt64 = 0

    public init() {}

    public mutating func add(
        rowKind: InvestigationSourceRowKind,
        payloadBytes: UInt64,
        canonicalRowBytes: UInt64
    ) throws {
        var candidate = self
        try candidate.applyAdd(
            rowKind: rowKind,
            payloadBytes: payloadBytes,
            canonicalRowBytes: canonicalRowBytes
        )
        self = candidate
    }

    private mutating func applyAdd(
        rowKind: InvestigationSourceRowKind,
        payloadBytes: UInt64,
        canonicalRowBytes: UInt64
    ) throws {
        guard payloadBytes <= rowKind.payloadByteLimit else {
            throw InvestigationSourceProjectionError.sourceProjectionTooLarge
        }
        try addChecked(1, to: &sourceRowCount, limit: Self.maximumSourceRows)
        switch rowKind {
        case .scanSession:
            try addChecked(1, to: &scanSessionCount, limit: 1)
        case .pathSnapshot:
            try addChecked(
                1,
                to: &pathSnapshotCount,
                limit: Self.maximumPathSnapshots
            )
        case .classification:
            try addChecked(
                1,
                to: &classificationCount,
                limit: Self.maximumClassifications
            )
        case .evidence:
            try addChecked(
                1,
                to: &evidenceCount,
                limit: Self.maximumEvidence
            )
        case .spaceLedger:
            try addChecked(1, to: &spaceLedgerCount, limit: 1)
        }
        try addSyntheticPayloadBytes(payloadBytes)
        try addSyntheticCanonicalBytes(canonicalRowBytes)
    }

    public mutating func addSyntheticPayloadBytes(
        _ byteCount: UInt64
    ) throws {
        try addChecked(
            byteCount,
            to: &exactPayloadBytes,
            limit: Self.maximumExactPayloadBytes
        )
    }

    public mutating func addSyntheticCanonicalBytes(
        _ byteCount: UInt64
    ) throws {
        try addChecked(
            byteCount,
            to: &completeCanonicalBytes,
            limit: Self.maximumCanonicalBytes
        )
    }

    private func addChecked(
        _ value: UInt64,
        to total: inout UInt64,
        limit: UInt64
    ) throws {
        let addition = total.addingReportingOverflow(value)
        guard !addition.overflow, addition.partialValue <= limit else {
            throw InvestigationSourceProjectionError.sourceProjectionTooLarge
        }
        total = addition.partialValue
    }
}

public struct InvestigationSourceSessionIndex: Sendable, Equatable {
    public let id: ScanSessionID
    public let terminalState: ScanTerminalState
    public let completedScopes: [ScanScope]
    public let unfinishedScopes: [UnfinishedScanScope]
    public let expiresAt: Date
}

public struct InvestigationSourceLedgerIndex: Sendable, Equatable {
    public let sessionID: ScanSessionID
    public let status: SpaceLedgerStatus
    public let unknown: SpaceLedgerMeasure
    public let unmeasurable: SpaceLedgerMeasure
    public let coverageGaps: [SpaceLedgerCoverageGap]
    public let unknownIncludesUnmeasurable: Bool
}

public struct InvestigationSourceSnapshotIndex: Sendable, Equatable {
    public let id: SnapshotID
    public let scopeID: ScanScopeID
    public let expectedAllocatedBytes: ByteCount?
    public let measurementStatus: MeasurementStatus
    public let observedAt: Date
    public let isRoot: Bool
}

public struct InvestigationSourceClassificationIndex: Sendable, Equatable {
    public let id: ClassificationID
    public let snapshotID: SnapshotID
    public let ruleID: DomainToken?
    public let producer: DomainLabel?
    public let category: ArtifactCategory
    public let disposition: ReclaimDisposition
    public let risk: RiskLevel
    public let confidence: EvidenceConfidence
    public let requiredEvidenceKeys: [DomainToken]
    public let missingEvidenceKeys: [DomainToken]
    public let classifiedAt: Date
}

public struct InvestigationSourceEvidenceIndex: Sendable, Equatable {
    public let id: EvidenceID
    public let snapshotID: SnapshotID
    public let kind: EvidenceKind
    public let freshness: EvidenceFreshness
    public let observedAt: Date
}

public struct InvestigationSourcePolicyIndex: Sendable, Equatable {
    public let session: InvestigationSourceSessionIndex
    public let ledger: InvestigationSourceLedgerIndex
    public let snapshots: [SnapshotID: InvestigationSourceSnapshotIndex]
    public let classifications:
        [ClassificationID: InvestigationSourceClassificationIndex]
    public let evidence: [EvidenceID: InvestigationSourceEvidenceIndex]
}

public struct InvestigationSourceProjectionSummary:
    Sendable,
    Equatable
{
    public let scanSessionID: ScanSessionID
    public let primaryScopeID: ScanScopeID
    public let sourceRowCount: UInt64
    public let pathSnapshotCount: UInt64
    public let classificationCount: UInt64
    public let evidenceCount: UInt64
    public let exactPayloadBytes: UInt64
    public let completeCanonicalBytes: UInt64
    public let relevanceTokens: [DomainToken]
    public let sourceFingerprint: InvestigationFingerprint
}

public struct InvestigationSourceProjection: Sendable, Equatable {
    public let summary: InvestigationSourceProjectionSummary
    public let policyIndex: InvestigationSourcePolicyIndex
}

public struct InvestigationSourceProjectionBuilder: Sendable {
    public init() {}

    public func build<
        Factory: InvestigationSourceCursorFactory,
        Manifest: InvestigationManifestSink
    >(
        factory: inout Factory,
        planningAt: Date,
        manifestSink: inout Manifest
    ) throws -> InvestigationSourceProjection {
        let selectedScanSessionID = factory.scanSessionID
        let selectedPrimaryScopeID = factory.primaryScopeID
        let relevanceTokens = factory.relevanceTokens
        try validateRelevanceTokens(relevanceTokens)

        let firstGeneration = factory.generation
        var firstCursor = try factory.makeCursor()
        guard factory.scanSessionID == selectedScanSessionID,
              factory.primaryScopeID == selectedPrimaryScopeID,
              factory.generation == firstGeneration,
              factory.relevanceTokens == relevanceTokens
        else {
            throw InvestigationSourceProjectionError.secondPassDrift
        }
        var passOne = PassOneState(
            scanSessionID: selectedScanSessionID,
            primaryScopeID: selectedPrimaryScopeID
        )
        let payloadCodec = DomainJSONCanonicalCodec()

        while true {
            var reachedEnd = false
            try autoreleasepool {
                guard let row = try firstCursor.next() else {
                    reachedEnd = true
                    return
                }
                let record = try row.validatedRecord(using: payloadCodec)
                let manifest = try row.manifestRow
                let encoded = try manifest.canonicalBytes
                try passOne.accept(
                    record: record,
                    manifestRow: manifest,
                    canonicalBytes: encoded,
                    manifestSink: &manifestSink
                )
            }
            if reachedEnd {
                break
            }
        }
        let index = try passOne.finish(planningAt: planningAt)

        let projectionByteCount = try sourceProjectionByteCount(
            scanSessionID: selectedScanSessionID,
            primaryScopeID: selectedPrimaryScopeID,
            rowCount: passOne.accounting.sourceRowCount,
            framedRowsByteCount: passOne.framedRowsByteCount,
            relevanceTokens: relevanceTokens
        )
        guard projectionByteCount
                <= InvestigationSourceProjectionAccounting.maximumCanonicalBytes
        else {
            throw InvestigationSourceProjectionError.sourceProjectionTooLarge
        }

        let secondGeneration = factory.generation
        guard secondGeneration == firstGeneration else {
            throw InvestigationSourceProjectionError.secondPassDrift
        }
        var secondCursor = try factory.makeCursor()
        guard factory.scanSessionID == selectedScanSessionID,
              factory.primaryScopeID == selectedPrimaryScopeID,
              factory.generation == firstGeneration,
              factory.relevanceTokens == relevanceTokens
        else {
            throw InvestigationSourceProjectionError.secondPassDrift
        }
        var passTwo = try PassTwoState(
            scanSessionID: selectedScanSessionID,
            primaryScopeID: selectedPrimaryScopeID,
            expectedRowCount: passOne.accounting.sourceRowCount,
            expectedFramedRowsByteCount: passOne.framedRowsByteCount,
            relevanceTokens: relevanceTokens
        )
        while true {
            var reachedEnd = false
            try autoreleasepool {
                guard let row = try secondCursor.next() else {
                    reachedEnd = true
                    return
                }
                let manifest = try row.manifestRow
                let encoded = try manifest.canonicalBytes
                try passTwo.accept(
                    manifestRow: manifest,
                    canonicalBytes: encoded
                )
            }
            if reachedEnd {
                break
            }
        }
        let finalGeneration = factory.generation
        guard factory.scanSessionID == selectedScanSessionID,
              factory.primaryScopeID == selectedPrimaryScopeID,
              factory.relevanceTokens == relevanceTokens
        else {
            throw InvestigationSourceProjectionError.secondPassDrift
        }
        let fingerprint = try passTwo.finish(
            expectedGeneration: firstGeneration,
            actualGeneration: finalGeneration,
            expectedAccounting: passOne.accounting,
            expectedSequenceFingerprint: passOne.sequenceFingerprint,
            expectedProjectionByteCount: projectionByteCount
        )

        return InvestigationSourceProjection(
            summary: InvestigationSourceProjectionSummary(
                scanSessionID: selectedScanSessionID,
                primaryScopeID: selectedPrimaryScopeID,
                sourceRowCount: passOne.accounting.sourceRowCount,
                pathSnapshotCount: passOne.accounting.pathSnapshotCount,
                classificationCount: passOne.accounting.classificationCount,
                evidenceCount: passOne.accounting.evidenceCount,
                exactPayloadBytes: passOne.accounting.exactPayloadBytes,
                completeCanonicalBytes: projectionByteCount,
                relevanceTokens: relevanceTokens,
                sourceFingerprint: fingerprint
            ),
            policyIndex: index
        )
    }
}

private struct PassOneState {
    let scanSessionID: ScanSessionID
    let primaryScopeID: ScanScopeID
    var accounting = InvestigationSourceProjectionAccounting()
    var framedRowsByteCount: UInt64 = 0
    var sequenceHasher = SHA256()
    var previousCanonicalRow: Data?
    var previousRowKey: SourceRowKey?
    var session: InvestigationSourceSessionIndex?
    var ledger: InvestigationSourceLedgerIndex?
    var snapshots: [SnapshotID: InvestigationSourceSnapshotIndex] = [:]
    var classifications:
        [ClassificationID: InvestigationSourceClassificationIndex] = [:]
    var evidence: [EvidenceID: InvestigationSourceEvidenceIndex] = [:]
    var evidencePerSnapshot: [SnapshotID: UInt64] = [:]

    mutating func accept<Manifest: InvestigationManifestSink>(
        record: InvestigationStoredSourceRecord,
        manifestRow: InvestigationSourceManifestRow,
        canonicalBytes: Data,
        manifestSink: inout Manifest
    ) throws {
        if let previousCanonicalRow,
           !previousCanonicalRow.lexicographicallyPrecedes(canonicalBytes)
        {
            throw InvestigationSourceProjectionError.nonCanonicalOrder
        }
        previousCanonicalRow = canonicalBytes

        let key = SourceRowKey(
            kind: manifestRow.rowKind,
            primaryID: manifestRow.primaryID
        )
        guard key != previousRowKey else {
            throw InvestigationSourceProjectionError.duplicateSourceRow
        }
        previousRowKey = key

        try accounting.add(
            rowKind: manifestRow.rowKind,
            payloadBytes: manifestRow.payloadByteCount,
            canonicalRowBytes: UInt64(canonicalBytes.count)
        )
        let frameCount = UInt64(canonicalBytes.count)
            .addingReportingOverflow(8)
        guard !frameCount.overflow else {
            throw InvestigationSourceProjectionError.sourceProjectionTooLarge
        }
        let framedTotal = framedRowsByteCount.addingReportingOverflow(
            frameCount.partialValue
        )
        guard !framedTotal.overflow else {
            throw InvestigationSourceProjectionError.sourceProjectionTooLarge
        }
        framedRowsByteCount = framedTotal.partialValue
        sequenceHasher.update(data: bigEndianData(UInt64(canonicalBytes.count)))
        sequenceHasher.update(data: canonicalBytes)

        try validateMembership(record)
        try manifestSink.record(manifestRow)
    }

    var sequenceFingerprint: Data {
        let copy = sequenceHasher
        return Data(copy.finalize())
    }

    mutating func finish(
        planningAt: Date
    ) throws -> InvestigationSourcePolicyIndex {
        guard accounting.scanSessionCount == 1,
              accounting.spaceLedgerCount == 1,
              let session,
              let ledger
        else {
            throw InvestigationSourceProjectionError.sourceMissing
        }
        guard session.expiresAt > planningAt else {
            throw InvestigationSourceProjectionError.sourceExpired
        }
        guard session.completedScopes.filter({ $0.id == primaryScopeID }).count
                == 1,
              session.completedScopes.contains(where: {
                  $0.id == primaryScopeID
              }),
              ledger.sessionID == scanSessionID
        else {
            throw InvestigationSourceProjectionError.membershipMismatch
        }
        let snapshotIDs = Set(snapshots.keys)
        guard classifications.values.allSatisfy({
            snapshotIDs.contains($0.snapshotID)
        }),
        evidence.values.allSatisfy({
            snapshotIDs.contains($0.snapshotID)
        }) else {
            throw InvestigationSourceProjectionError.membershipMismatch
        }

        return InvestigationSourcePolicyIndex(
            session: session,
            ledger: ledger,
            snapshots: snapshots,
            classifications: classifications,
            evidence: evidence
        )
    }

    private mutating func validateMembership(
        _ record: InvestigationStoredSourceRecord
    ) throws {
        switch record {
        case let .scanSession(value):
            guard value.id == scanSessionID, session == nil else {
                throw InvestigationSourceProjectionError.membershipMismatch
            }
            guard let expiresAtMillis = try record.expectedStorageColumns
                .int64Value(named: "expires_at_ms")
            else {
                throw InvestigationSourceProjectionError.storageMismatch
            }
            session = InvestigationSourceSessionIndex(
                id: value.id,
                terminalState: value.terminalState,
                completedScopes: value.completedScopes,
                unfinishedScopes: value.unfinishedScopes,
                expiresAt: Date(
                    timeIntervalSince1970:
                        TimeInterval(expiresAtMillis) / 1_000
                )
            )
        case let .spaceLedger(value):
            guard value.sessionID == scanSessionID, ledger == nil else {
                throw InvestigationSourceProjectionError.membershipMismatch
            }
            ledger = InvestigationSourceLedgerIndex(
                sessionID: value.sessionID,
                status: value.status,
                unknown: value.unknown,
                unmeasurable: value.unmeasurable,
                coverageGaps: value.coverageGaps,
                unknownIncludesUnmeasurable:
                    value.unknownIncludesUnmeasurable
            )
        case let .pathSnapshot(value):
            guard value.sessionID == scanSessionID,
                  value.scopeID == primaryScopeID,
                  snapshots[value.id] == nil
            else {
                throw InvestigationSourceProjectionError.membershipMismatch
            }
            snapshots[value.id] = InvestigationSourceSnapshotIndex(
                id: value.id,
                scopeID: value.scopeID,
                expectedAllocatedBytes: value.allocatedByteCount,
                measurementStatus: value.measurementStatus,
                observedAt: value.observedAt,
                isRoot: value.relativePath == "."
            )
        case let .classification(value):
            guard classifications[value.id] == nil else {
                throw InvestigationSourceProjectionError.membershipMismatch
            }
            classifications[value.id] =
                InvestigationSourceClassificationIndex(
                    id: value.id,
                    snapshotID: value.snapshotID,
                    ruleID: value.ruleID,
                    producer: value.producer,
                    category: value.category,
                    disposition: value.disposition,
                    risk: value.risk,
                    confidence: value.confidence,
                    requiredEvidenceKeys: value.requiredEvidenceKeys,
                    missingEvidenceKeys: value.missingEvidenceKeys,
                    classifiedAt: value.classifiedAt
                )
        case let .evidence(value):
            guard evidence[value.id] == nil else {
                throw InvestigationSourceProjectionError.membershipMismatch
            }
            let current = evidencePerSnapshot[value.targetID, default: 0]
            guard current
                    < InvestigationSourceProjectionAccounting
                        .maximumEvidencePerSnapshot
            else {
                throw InvestigationSourceProjectionError.sourceProjectionTooLarge
            }
            evidencePerSnapshot[value.targetID] = current + 1
            evidence[value.id] = InvestigationSourceEvidenceIndex(
                id: value.id,
                snapshotID: value.targetID,
                kind: value.kind,
                freshness: value.freshness,
                observedAt: value.observedAt
            )
        }
    }
}

private struct PassTwoState {
    let expectedRowCount: UInt64
    var accounting = InvestigationSourceProjectionAccounting()
    var framedRowsByteCount: UInt64 = 0
    var sequenceHasher = SHA256()
    var hashSink: InvestigationCanonicalHashSink
    var previousCanonicalRow: Data?

    init(
        scanSessionID: ScanSessionID,
        primaryScopeID: ScanScopeID,
        expectedRowCount: UInt64,
        expectedFramedRowsByteCount: UInt64,
        relevanceTokens: [DomainToken]
    ) throws {
        self.expectedRowCount = expectedRowCount
        hashSink = try InvestigationCanonicalHashSink(
            scanSessionID: scanSessionID,
            primaryScopeID: primaryScopeID,
            sourceRowCount: expectedRowCount,
            framedRowsByteCount: expectedFramedRowsByteCount,
            relevanceTokens: relevanceTokens
        )
    }

    mutating func accept(
        manifestRow: InvestigationSourceManifestRow,
        canonicalBytes: Data
    ) throws {
        guard accounting.sourceRowCount < expectedRowCount else {
            throw InvestigationSourceProjectionError.secondPassDrift
        }
        if let previousCanonicalRow,
           !previousCanonicalRow.lexicographicallyPrecedes(canonicalBytes)
        {
            throw InvestigationSourceProjectionError.secondPassDrift
        }
        previousCanonicalRow = canonicalBytes
        do {
            try accounting.add(
                rowKind: manifestRow.rowKind,
                payloadBytes: manifestRow.payloadByteCount,
                canonicalRowBytes: UInt64(canonicalBytes.count)
            )
        } catch {
            throw InvestigationSourceProjectionError.secondPassDrift
        }
        let framed = UInt64(canonicalBytes.count).addingReportingOverflow(8)
        let total = framedRowsByteCount.addingReportingOverflow(
            framed.partialValue
        )
        guard !framed.overflow, !total.overflow else {
            throw InvestigationSourceProjectionError.secondPassDrift
        }
        framedRowsByteCount = total.partialValue
        sequenceHasher.update(data: bigEndianData(UInt64(canonicalBytes.count)))
        sequenceHasher.update(data: canonicalBytes)
        try hashSink.appendSourceRow(canonicalBytes)
    }

    mutating func finish(
        expectedGeneration: InvestigationSourceGeneration,
        actualGeneration: InvestigationSourceGeneration,
        expectedAccounting: InvestigationSourceProjectionAccounting,
        expectedSequenceFingerprint: Data,
        expectedProjectionByteCount: UInt64
    ) throws -> InvestigationFingerprint {
        let sequenceFingerprint = Data(sequenceHasher.finalize())
        let expectedFramedRows = try expectedFramedRowsByteCount(
            expectedAccounting
        )
        guard expectedGeneration == actualGeneration,
              accounting == expectedAccounting,
              framedRowsByteCount == expectedFramedRows,
              sequenceFingerprint == expectedSequenceFingerprint
        else {
            throw InvestigationSourceProjectionError.secondPassDrift
        }
        let result = try hashSink.finalize()
        guard result.byteCount == expectedProjectionByteCount else {
            throw InvestigationSourceProjectionError.secondPassDrift
        }
        return result.fingerprint
    }

    private func expectedFramedRowsByteCount(
        _ accounting: InvestigationSourceProjectionAccounting
    ) throws -> UInt64 {
        let framing = accounting.sourceRowCount.multipliedReportingOverflow(
            by: 8
        )
        let total = accounting.completeCanonicalBytes.addingReportingOverflow(
            framing.partialValue
        )
        guard !framing.overflow, !total.overflow else {
            throw InvestigationSourceProjectionError.secondPassDrift
        }
        return total.partialValue
    }
}

struct InvestigationCanonicalHashSink {
    private var hasher = SHA256()
    private(set) var byteCount: UInt64 = 0
    private let relevanceBytes: Data

    init(
        scanSessionID: ScanSessionID,
        primaryScopeID: ScanScopeID,
        sourceRowCount: UInt64,
        framedRowsByteCount: UInt64,
        relevanceTokens: [DomainToken]
    ) throws {
        relevanceBytes = try canonicalValueBytes(
            .array(relevanceTokens.map { .text($0.rawValue) })
        )
        let sourceArrayLength = framedRowsByteCount.addingReportingOverflow(9)
        guard !sourceArrayLength.overflow else {
            throw InvestigationSourceProjectionError.sourceProjectionTooLarge
        }

        append(Data("STORNAUT-INV-CANON-1\0".utf8))
        append(
            try canonicalValueBytes(
                .text("stornaut.investigation.source.v1")
            )
        )
        append(Data([0x40]))
        append(bigEndianData(UInt64(5)))
        try appendField(tag: 1, value: .unsigned(1))
        try appendField(
            tag: 2,
            value: .text(scanSessionID.rawValue)
        )
        try appendField(
            tag: 3,
            value: .text(primaryScopeID.rawValue)
        )
        append(bigEndianData(UInt16(4)))
        append(bigEndianData(sourceArrayLength.partialValue))
        append(Data([0x30]))
        append(bigEndianData(sourceRowCount))
    }

    mutating func appendSourceRow(_ canonicalBytes: Data) throws {
        append(bigEndianData(UInt64(canonicalBytes.count)))
        append(canonicalBytes)
    }

    mutating func finalize() throws -> (
        fingerprint: InvestigationFingerprint,
        byteCount: UInt64
    ) {
        append(bigEndianData(UInt16(5)))
        append(bigEndianData(UInt64(relevanceBytes.count)))
        append(relevanceBytes)
        return (
            try InvestigationFingerprint(
                validating: Data(hasher.finalize())
            ),
            byteCount
        )
    }

    private mutating func appendField(
        tag: UInt16,
        value: InvestigationCanonicalValue
    ) throws {
        let bytes = try canonicalValueBytes(value)
        append(bigEndianData(tag))
        append(bigEndianData(UInt64(bytes.count)))
        append(bytes)
    }

    private mutating func append(_ data: Data) {
        hasher.update(data: data)
        byteCount += UInt64(data.count)
    }
}

enum InvestigationSourceProjectionCanonicalCodec {
    static func validateBytes(
        _ data: Data
    ) throws -> InvestigationFingerprint {
        let root = try StornautInvestigationCanonicalV1.decode(
            data,
            expectedDomain: "stornaut.investigation.source.v1",
            maximumInputBytes: Int(
                InvestigationSourceProjectionAccounting.maximumCanonicalBytes
            )
        )
        let fields = try exactRecord(root, tags: Array(1...5))
        guard try unsigned(fields[1]) == 1 else {
            throw InvestigationSourceProjectionError.payloadMismatch
        }
        let scanSessionID = try ScanSessionID(
            validating: text(fields[2])
        )
        _ = try ScanScopeID(validating: text(fields[3]))
        let sourceRows = try array(fields[4])
        let relevanceValues = try array(fields[5])
        guard sourceRows.count
                <= Int(
                    InvestigationSourceProjectionAccounting.maximumSourceRows
                ),
              relevanceValues.count <= 256
        else {
            throw InvestigationSourceProjectionError.sourceProjectionTooLarge
        }

        var accounting = InvestigationSourceProjectionAccounting()
        var previousRowBytes: Data?
        var sourceKeys = Set<SourceRowKey>()
        var snapshotIDs = Set<SnapshotID>()
        var parentSnapshotIDs: [SnapshotID] = []
        var evidenceCountsBySnapshot: [SnapshotID: UInt64] = [:]
        for value in sourceRows {
            let row = try decodeRow(
                value,
                selectedScanSessionID: scanSessionID
            )
            let encoded = try canonicalValueBytes(value)
            if let previousRowBytes,
               !previousRowBytes.lexicographicallyPrecedes(encoded)
            {
                throw InvestigationSourceProjectionError.nonCanonicalOrder
            }
            previousRowBytes = encoded
            guard sourceKeys.insert(
                SourceRowKey(kind: row.kind, primaryID: row.primaryID)
            ).inserted else {
                throw InvestigationSourceProjectionError.duplicateSourceRow
            }
            switch row.kind {
            case .pathSnapshot:
                snapshotIDs.insert(
                    try SnapshotID(validating: row.primaryID)
                )
            case .classification:
                guard let parentSnapshotID = row.parentSnapshotID else {
                    throw InvestigationSourceProjectionError.membershipMismatch
                }
                parentSnapshotIDs.append(parentSnapshotID)
            case .evidence:
                guard let parentSnapshotID = row.parentSnapshotID else {
                    throw InvestigationSourceProjectionError.membershipMismatch
                }
                parentSnapshotIDs.append(parentSnapshotID)
                let current = evidenceCountsBySnapshot[
                    parentSnapshotID,
                    default: 0
                ]
                let addition = current.addingReportingOverflow(1)
                guard !addition.overflow,
                      addition.partialValue
                        <= InvestigationSourceProjectionAccounting
                            .maximumEvidencePerSnapshot
                else {
                    throw InvestigationSourceProjectionError
                        .sourceProjectionTooLarge
                }
                evidenceCountsBySnapshot[parentSnapshotID] =
                    addition.partialValue
            case .scanSession, .spaceLedger:
                break
            }
            try accounting.add(
                rowKind: row.kind,
                payloadBytes: row.payloadByteCount,
                canonicalRowBytes: UInt64(encoded.count)
            )
        }
        guard accounting.scanSessionCount == 1,
              accounting.spaceLedgerCount == 1,
              parentSnapshotIDs.allSatisfy(snapshotIDs.contains)
        else {
            throw InvestigationSourceProjectionError.membershipMismatch
        }

        var previousRelevanceBytes: Data?
        var relevanceTokens: [DomainToken] = []
        for value in relevanceValues {
            let token = try DomainToken(validating: text(value))
            let encoded = try canonicalValueBytes(value)
            if let previousRelevanceBytes,
               !previousRelevanceBytes.lexicographicallyPrecedes(encoded)
            {
                throw InvestigationSourceProjectionError.nonCanonicalOrder
            }
            previousRelevanceBytes = encoded
            relevanceTokens.append(token)
        }
        try validateRelevanceTokens(relevanceTokens)
        guard try StornautInvestigationCanonicalV1.encode(
            domain: "stornaut.investigation.source.v1",
            root: root
        ) == data else {
            throw InvestigationSourceProjectionError.payloadMismatch
        }
        return try InvestigationFingerprint(
            validating: Data(SHA256.hash(data: data))
        )
    }

    private static func decodeRow(
        _ value: InvestigationCanonicalValue,
        selectedScanSessionID: ScanSessionID
    ) throws -> (
        kind: InvestigationSourceRowKind,
        primaryID: String,
        payloadByteCount: UInt64,
        parentSnapshotID: SnapshotID?
    ) {
        let fields = try exactRecord(value, tags: Array(1...5))
        guard let kind = InvestigationSourceRowKind(
            rawValue: try text(fields[1])
        ) else {
            throw InvestigationSourceProjectionError.payloadMismatch
        }
        let primaryID = try text(fields[2])
        let columns = try array(fields[3]).map(decodeColumn)
        try InvestigationSourceRawStorageBounds.validate(columns)
        let parentSnapshotID = try validateColumns(
            columns,
            for: kind,
            primaryID: primaryID,
            selectedScanSessionID: selectedScanSessionID
        )
        let payloadByteCount = try unsigned(fields[4])
        guard payloadByteCount <= kind.payloadByteLimit else {
            throw InvestigationSourceProjectionError.sourceProjectionTooLarge
        }
        guard try bytes(fields[5]).count == 32 else {
            throw InvestigationSourceProjectionError.payloadMismatch
        }
        return (
            kind,
            primaryID,
            payloadByteCount,
            parentSnapshotID
        )
    }

    private static func decodeColumn(
        _ value: InvestigationCanonicalValue
    ) throws -> InvestigationStorageColumn {
        let fields = try exactRecord(value, tags: Array(1...4))
        let name = try text(fields[1])
        switch try text(fields[2]) {
        case "text-v1":
            guard try isNull(fields[4]) else {
                throw InvestigationSourceProjectionError.storageMismatch
            }
            return InvestigationStorageColumn(
                name: name,
                value: .text(try text(fields[3]))
            )
        case "int64-v1":
            guard try isNull(fields[3]) else {
                throw InvestigationSourceProjectionError.storageMismatch
            }
            return InvestigationStorageColumn(
                name: name,
                value: .int64(try signed(fields[4]))
            )
        default:
            throw InvestigationSourceProjectionError.storageMismatch
        }
    }

    private static func validateColumns(
        _ columns: [InvestigationStorageColumn],
        for kind: InvestigationSourceRowKind,
        primaryID: String,
        selectedScanSessionID: ScanSessionID
    ) throws -> SnapshotID? {
        var previousBytes: Data?
        var byName: [String: InvestigationStorageValue] = [:]
        for column in columns {
            let encoded = try canonicalValueBytes(column.canonicalValue)
            if let previousBytes,
               !previousBytes.lexicographicallyPrecedes(encoded)
            {
                throw InvestigationSourceProjectionError.nonCanonicalOrder
            }
            previousBytes = encoded
            guard byName.updateValue(column.value, forKey: column.name) == nil
            else {
                throw InvestigationSourceProjectionError.storageMismatch
            }
        }

        let expectedNames: Set<String>
        switch kind {
        case .scanSession:
            expectedNames = [
                "id",
                "started_at_ms",
                "finished_at_ms",
                "expires_at_ms",
            ]
        case .pathSnapshot:
            expectedNames = [
                "id",
                "session_id",
                "relative_path",
                "observed_at_ms",
            ]
        case .classification:
            expectedNames = [
                "id",
                "snapshot_id",
                "disposition",
                "classified_at_ms",
            ]
        case .evidence:
            expectedNames = ["id", "snapshot_id", "observed_at_ms"]
        case .spaceLedger:
            expectedNames = ["id", "session_id"]
        }
        guard Set(byName.keys) == expectedNames,
              case let .text(id)? = byName["id"],
              id == primaryID
        else {
            throw InvestigationSourceProjectionError.storageMismatch
        }

        switch kind {
        case .scanSession:
            guard try ScanSessionID(validating: primaryID)
                    == selectedScanSessionID
            else {
                throw InvestigationSourceProjectionError.membershipMismatch
            }
            try requireInt64(
                ["started_at_ms", "finished_at_ms", "expires_at_ms"],
                in: byName
            )
            return nil
        case .pathSnapshot:
            _ = try SnapshotID(validating: primaryID)
            try requireSession(
                selectedScanSessionID,
                in: byName
            )
            guard case let .text(relativePath)? = byName["relative_path"] else {
                throw InvestigationSourceProjectionError.storageMismatch
            }
            _ = try PersistedPath(validating: relativePath)
            try requireInt64(["observed_at_ms"], in: byName)
            return nil
        case .classification:
            _ = try ClassificationID(validating: primaryID)
            guard case let .text(snapshotID)? = byName["snapshot_id"],
                  case let .text(disposition)? = byName["disposition"]
            else {
                throw InvestigationSourceProjectionError.storageMismatch
            }
            let parentSnapshotID = try SnapshotID(validating: snapshotID)
            guard ReclaimDisposition(rawValue: disposition) != nil else {
                throw InvestigationSourceProjectionError.storageMismatch
            }
            try requireInt64(["classified_at_ms"], in: byName)
            return parentSnapshotID
        case .evidence:
            _ = try EvidenceID(validating: primaryID)
            guard case let .text(snapshotID)? = byName["snapshot_id"] else {
                throw InvestigationSourceProjectionError.storageMismatch
            }
            let parentSnapshotID = try SnapshotID(validating: snapshotID)
            try requireInt64(["observed_at_ms"], in: byName)
            return parentSnapshotID
        case .spaceLedger:
            guard primaryID == selectedScanSessionID.rawValue else {
                throw InvestigationSourceProjectionError.membershipMismatch
            }
            try requireSession(selectedScanSessionID, in: byName)
            return nil
        }
    }

    private static func requireSession(
        _ expected: ScanSessionID,
        in values: [String: InvestigationStorageValue]
    ) throws {
        guard case let .text(sessionID)? = values["session_id"],
              try ScanSessionID(validating: sessionID) == expected
        else {
            throw InvestigationSourceProjectionError.membershipMismatch
        }
    }

    private static func requireInt64(
        _ names: [String],
        in values: [String: InvestigationStorageValue]
    ) throws {
        guard names.allSatisfy({
            if case .int64? = values[$0] {
                return true
            }
            return false
        }) else {
            throw InvestigationSourceProjectionError.storageMismatch
        }
    }

    private static func exactRecord(
        _ value: InvestigationCanonicalValue,
        tags: [UInt16]
    ) throws -> [UInt16: InvestigationCanonicalValue] {
        guard case let .record(fields) = value,
              fields.map(\.tag) == tags
        else {
            throw InvestigationSourceProjectionError.payloadMismatch
        }
        return Dictionary(
            uniqueKeysWithValues: fields.map { ($0.tag, $0.value) }
        )
    }

    private static func unsigned(
        _ value: InvestigationCanonicalValue?
    ) throws -> UInt64 {
        guard case let .unsigned(decoded)? = value else {
            throw InvestigationSourceProjectionError.payloadMismatch
        }
        return decoded
    }

    private static func signed(
        _ value: InvestigationCanonicalValue?
    ) throws -> Int64 {
        guard case let .signed(decoded)? = value else {
            throw InvestigationSourceProjectionError.storageMismatch
        }
        return decoded
    }

    private static func text(
        _ value: InvestigationCanonicalValue?
    ) throws -> String {
        guard case let .text(decoded)? = value else {
            throw InvestigationSourceProjectionError.payloadMismatch
        }
        return decoded
    }

    private static func bytes(
        _ value: InvestigationCanonicalValue?
    ) throws -> Data {
        guard case let .bytes(decoded)? = value else {
            throw InvestigationSourceProjectionError.payloadMismatch
        }
        return decoded
    }

    private static func array(
        _ value: InvestigationCanonicalValue?
    ) throws -> [InvestigationCanonicalValue] {
        guard case let .array(decoded)? = value else {
            throw InvestigationSourceProjectionError.payloadMismatch
        }
        return decoded
    }

    private static func isNull(
        _ value: InvestigationCanonicalValue?
    ) throws -> Bool {
        guard let value else {
            throw InvestigationSourceProjectionError.payloadMismatch
        }
        if case .null = value {
            return true
        }
        return false
    }
}

private struct SourceRowKey: Hashable {
    let kind: InvestigationSourceRowKind
    let primaryID: String
}

extension InvestigationStoredSourceRow {
    var manifestRow: InvestigationSourceManifestRow {
        get throws {
            let primaryID: String
            do {
                primaryID = try storageColumns.primaryID(for: rowKind)
            } catch {
                throw InvestigationSourceProjectionError.storageMismatch
            }
            return InvestigationSourceManifestRow(
                rowKind: rowKind,
                primaryID: primaryID,
                storageColumns: storageColumns,
                payloadByteCount: UInt64(exactPayload.count),
                payloadSHA256: try InvestigationFingerprint(
                    validating: Data(SHA256.hash(data: exactPayload))
                )
            )
        }
    }
}

private extension InvestigationStoredSourceRecord {
    var expectedStorageColumns: [InvestigationStorageColumn] {
        get throws {
        switch self {
        case let .scanSession(value):
            [
                .init(name: "id", value: .text(value.id.rawValue)),
                .init(
                    name: "expires_at_ms",
                    value: .int64(
                        try storageInt64(
                            from: value.finishedAt.addingTimeInterval(
                                7 * 86_400
                            )
                        )
                    )
                ),
                .init(
                    name: "started_at_ms",
                    value: .int64(try storageInt64(from: value.startedAt))
                ),
                .init(
                    name: "finished_at_ms",
                    value: .int64(try storageInt64(from: value.finishedAt))
                ),
            ]
        case let .pathSnapshot(value):
            [
                .init(name: "id", value: .text(value.id.rawValue)),
                .init(
                    name: "session_id",
                    value: .text(value.sessionID.rawValue)
                ),
                .init(
                    name: "relative_path",
                    value: .text(value.relativePath)
                ),
                .init(
                    name: "observed_at_ms",
                    value: .int64(try storageInt64(from: value.observedAt))
                ),
            ]
        case let .classification(value):
            [
                .init(name: "id", value: .text(value.id.rawValue)),
                .init(
                    name: "disposition",
                    value: .text(value.disposition.rawValue)
                ),
                .init(
                    name: "snapshot_id",
                    value: .text(value.snapshotID.rawValue)
                ),
                .init(
                    name: "classified_at_ms",
                    value: .int64(try storageInt64(from: value.classifiedAt))
                ),
            ]
        case let .evidence(value):
            [
                .init(name: "id", value: .text(value.id.rawValue)),
                .init(
                    name: "snapshot_id",
                    value: .text(value.targetID.rawValue)
                ),
                .init(
                    name: "observed_at_ms",
                    value: .int64(try storageInt64(from: value.observedAt))
                ),
            ]
        case let .spaceLedger(value):
            [
                .init(name: "id", value: .text(value.sessionID.rawValue)),
                .init(
                    name: "session_id",
                    value: .text(value.sessionID.rawValue)
                ),
            ]
        }
        }
    }
}

extension InvestigationSourceManifestRow {
    var canonicalBytes: Data {
        get throws {
            let layout = try SourceCanonicalLayout(
                rowKind: rowKind,
                primaryID: primaryID,
                storageColumns: storageColumns,
                payloadSHAByteCount: payloadSHA256.bytes.count
            )
            var data = Data(count: layout.rowByteCount)
            let result = data.withUnsafeMutableBytes { rawBuffer in
                var writer = SourceCanonicalBufferWriter(
                    buffer: rawBuffer.bindMemory(to: UInt8.self)
                )
                writer.appendRecordHeader(fieldCount: 5)
                writer.appendFieldHeader(
                    tag: 1,
                    valueByteCount:
                        SourceCanonicalBufferWriter.textByteCount(
                            rowKind.rawValue
                        )
                )
                writer.appendText(rowKind.rawValue)
                writer.appendFieldHeader(
                    tag: 2,
                    valueByteCount:
                        SourceCanonicalBufferWriter.textByteCount(primaryID)
                )
                writer.appendText(primaryID)
                writer.appendFieldHeader(
                    tag: 3,
                    valueByteCount: layout.storageColumnsByteCount
                )
                writer.appendArrayHeader(count: storageColumns.count)
                for (column, columnByteCount) in zip(
                    storageColumns,
                    layout.columnByteCounts
                ) {
                    writer.appendFrameHeader(
                        valueByteCount: columnByteCount
                    )
                    writer.appendStorageColumn(column)
                }
                writer.appendFieldHeader(tag: 4, valueByteCount: 9)
                writer.appendUnsigned(payloadByteCount)
                writer.appendFieldHeader(
                    tag: 5,
                    valueByteCount: 9 + payloadSHA256.bytes.count
                )
                writer.appendBytes(payloadSHA256.bytes)
                return (writer.index, writer.failed)
            }
            guard !result.1, result.0 == layout.rowByteCount else {
                throw InvestigationSourceProjectionError.sourceProjectionTooLarge
            }
            return data
        }
    }
}

private extension InvestigationStorageColumn {
    var canonicalValue: InvestigationCanonicalValue {
        switch value {
        case let .text(text):
            .record([
                .init(tag: 1, value: .text(name)),
                .init(tag: 2, value: .text("text-v1")),
                .init(tag: 3, value: .text(text)),
                .init(tag: 4, value: .null),
            ])
        case let .int64(value):
            .record([
                .init(tag: 1, value: .text(name)),
                .init(tag: 2, value: .text("int64-v1")),
                .init(tag: 3, value: .null),
                .init(tag: 4, value: .signed(value)),
            ])
        }
    }

}

private enum InvestigationSourceRawStorageBounds {
    private static let maximumColumnCount = 4
    private static let maximumColumnNameBytes = 64
    private static let maximumTextValueBytes = 16_384

    static func validate(
        _ storageColumns: [InvestigationStorageColumn]
    ) throws {
        guard storageColumns.count <= maximumColumnCount else {
            throw InvestigationSourceProjectionError.sourceProjectionTooLarge
        }
        for column in storageColumns {
            let nameByteCount = column.name.utf8.count
            guard nameByteCount > 0,
                  nameByteCount <= maximumColumnNameBytes
            else {
                throw InvestigationSourceProjectionError.sourceProjectionTooLarge
            }
            if case let .text(value) = column.value {
                guard value.utf8.count <= maximumTextValueBytes else {
                    throw InvestigationSourceProjectionError.sourceProjectionTooLarge
                }
            }
        }
    }
}

private struct SourceCanonicalLayout {
    let rowByteCount: Int
    let storageColumnsByteCount: Int
    let columnByteCounts: [Int]

    init(
        rowKind: InvestigationSourceRowKind,
        primaryID: String,
        storageColumns: [InvestigationStorageColumn],
        payloadSHAByteCount: Int
    ) throws {
        var encodedColumns: [Int] = []
        encodedColumns.reserveCapacity(storageColumns.count)
        var storageByteCount: UInt64 = 9
        for column in storageColumns {
            let columnByteCount = try Self.columnByteCount(column)
            try Self.add(8, to: &storageByteCount)
            try Self.add(columnByteCount, to: &storageByteCount)
            guard let encodedColumnByteCount = Int(exactly: columnByteCount) else {
                throw InvestigationSourceProjectionError.sourceProjectionTooLarge
            }
            encodedColumns.append(encodedColumnByteCount)
        }

        var rowByteCount: UInt64 = 9
        try Self.add(10, to: &rowByteCount)
        try Self.add(
            try Self.textByteCount(rowKind.rawValue),
            to: &rowByteCount
        )
        try Self.add(10, to: &rowByteCount)
        try Self.add(try Self.textByteCount(primaryID), to: &rowByteCount)
        try Self.add(10, to: &rowByteCount)
        try Self.add(storageByteCount, to: &rowByteCount)
        try Self.add(10 + 9, to: &rowByteCount)
        try Self.add(10 + 9, to: &rowByteCount)
        try Self.add(UInt64(payloadSHAByteCount), to: &rowByteCount)

        guard let checkedRowByteCount = Int(exactly: rowByteCount),
              let checkedStorageByteCount = Int(exactly: storageByteCount)
        else {
            throw InvestigationSourceProjectionError.sourceProjectionTooLarge
        }
        self.rowByteCount = checkedRowByteCount
        storageColumnsByteCount = checkedStorageByteCount
        columnByteCounts = encodedColumns
    }

    private static func columnByteCount(
        _ column: InvestigationStorageColumn
    ) throws -> UInt64 {
        var count: UInt64 = 9
        try add(10, to: &count)
        try add(try textByteCount(column.name), to: &count)
        try add(10, to: &count)
        switch column.value {
        case let .text(text):
            try add(try textByteCount("text-v1"), to: &count)
            try add(10, to: &count)
            try add(try textByteCount(text), to: &count)
            try add(10 + 1, to: &count)
        case .int64:
            try add(try textByteCount("int64-v1"), to: &count)
            try add(10 + 1, to: &count)
            try add(10 + 9, to: &count)
        }
        return count
    }

    private static func textByteCount(_ value: String) throws -> UInt64 {
        var count: UInt64 = 9
        try add(UInt64(value.utf8.count), to: &count)
        return count
    }

    private static func add(
        _ value: UInt64,
        to total: inout UInt64
    ) throws {
        let addition = total.addingReportingOverflow(value)
        guard !addition.overflow,
              addition.partialValue
                <= InvestigationSourceProjectionAccounting.maximumCanonicalBytes
        else {
            throw InvestigationSourceProjectionError.sourceProjectionTooLarge
        }
        total = addition.partialValue
    }
}

private struct SourceCanonicalBufferWriter {
    let buffer: UnsafeMutableBufferPointer<UInt8>
    private(set) var index = 0
    private(set) var failed = false

    static func textByteCount(_ value: String) -> Int {
        9 + value.utf8.count
    }

    mutating func appendRecordHeader(fieldCount: Int) {
        appendByte(0x40)
        appendUInt64(UInt64(fieldCount))
    }

    mutating func appendArrayHeader(count: Int) {
        appendByte(0x30)
        appendUInt64(UInt64(count))
    }

    mutating func appendFieldHeader(
        tag: UInt16,
        valueByteCount: Int
    ) {
        appendUInt16(tag)
        appendUInt64(UInt64(valueByteCount))
    }

    mutating func appendFrameHeader(valueByteCount: Int) {
        appendUInt64(UInt64(valueByteCount))
    }

    mutating func appendText(_ value: String) {
        appendByte(0x20)
        appendUInt64(UInt64(value.utf8.count))
        appendUTF8(value)
    }

    mutating func appendUnsigned(_ value: UInt64) {
        appendByte(0x10)
        appendUInt64(value)
    }

    mutating func appendSigned(_ value: Int64) {
        appendByte(0x11)
        appendUInt64(UInt64(bitPattern: value))
    }

    mutating func appendBytes(_ value: Data) {
        appendByte(0x21)
        appendUInt64(UInt64(value.count))
        appendRawData(value)
    }

    mutating func appendStorageColumn(
        _ column: InvestigationStorageColumn
    ) {
        appendRecordHeader(fieldCount: 4)
        appendFieldHeader(
            tag: 1,
            valueByteCount: Self.textByteCount(column.name)
        )
        appendText(column.name)
        switch column.value {
        case let .text(text):
            appendFieldHeader(
                tag: 2,
                valueByteCount: Self.textByteCount("text-v1")
            )
            appendText("text-v1")
            appendFieldHeader(
                tag: 3,
                valueByteCount: Self.textByteCount(text)
            )
            appendText(text)
            appendFieldHeader(tag: 4, valueByteCount: 1)
            appendByte(0x00)
        case let .int64(value):
            appendFieldHeader(
                tag: 2,
                valueByteCount: Self.textByteCount("int64-v1")
            )
            appendText("int64-v1")
            appendFieldHeader(tag: 3, valueByteCount: 1)
            appendByte(0x00)
            appendFieldHeader(tag: 4, valueByteCount: 9)
            appendSigned(value)
        }
    }

    private mutating func appendByte(_ value: UInt8) {
        guard reserve(1) else {
            return
        }
        buffer[index] = value
        index += 1
    }

    private mutating func appendUInt16(_ value: UInt16) {
        guard reserve(2) else {
            return
        }
        buffer[index] = UInt8(truncatingIfNeeded: value >> 8)
        buffer[index + 1] = UInt8(truncatingIfNeeded: value)
        index += 2
    }

    private mutating func appendUInt64(_ value: UInt64) {
        guard reserve(8) else {
            return
        }
        buffer[index] = UInt8(truncatingIfNeeded: value >> 56)
        buffer[index + 1] = UInt8(truncatingIfNeeded: value >> 48)
        buffer[index + 2] = UInt8(truncatingIfNeeded: value >> 40)
        buffer[index + 3] = UInt8(truncatingIfNeeded: value >> 32)
        buffer[index + 4] = UInt8(truncatingIfNeeded: value >> 24)
        buffer[index + 5] = UInt8(truncatingIfNeeded: value >> 16)
        buffer[index + 6] = UInt8(truncatingIfNeeded: value >> 8)
        buffer[index + 7] = UInt8(truncatingIfNeeded: value)
        index += 8
    }

    private mutating func appendUTF8(_ value: String) {
        let byteCount = value.utf8.count
        guard reserve(byteCount),
              let destination = buffer.baseAddress?.advanced(by: index)
        else {
            return
        }
        if value.utf8.withContiguousStorageIfAvailable({ source in
            if source.count > 0, let sourceAddress = source.baseAddress {
                destination.update(from: sourceAddress, count: source.count)
            }
            return true
        }) == true {
            index += byteCount
            return
        }
        for byte in value.utf8 {
            buffer[index] = byte
            index += 1
        }
    }

    private mutating func appendRawData(_ value: Data) {
        guard reserve(value.count),
              let destination = buffer.baseAddress?.advanced(by: index)
        else {
            return
        }
        value.withUnsafeBytes { source in
            if source.count > 0, let sourceAddress = source.baseAddress {
                destination.update(
                    from: sourceAddress.assumingMemoryBound(to: UInt8.self),
                    count: source.count
                )
            }
        }
        index += value.count
    }

    private mutating func reserve(_ byteCount: Int) -> Bool {
        guard !failed, byteCount >= 0 else {
            failed = true
            return false
        }
        let end = index.addingReportingOverflow(byteCount)
        guard !end.overflow, end.partialValue <= buffer.count else {
            failed = true
            return false
        }
        return true
    }
}

private extension Array where Element == InvestigationStorageColumn {
    func primaryID(
        for rowKind: InvestigationSourceRowKind
    ) throws -> String {
        let columnName = rowKind == .spaceLedger ? "session_id" : "id"
        guard let column = first(where: { $0.name == columnName }),
              case let .text(value) = column.value
        else {
            throw InvestigationSourceProjectionError.storageMismatch
        }
        return value
    }

    func int64Value(named name: String) -> Int64? {
        guard let column = first(where: { $0.name == name }),
              case let .int64(value) = column.value
        else {
            return nil
        }
        return value
    }
}

private func validateRelevanceTokens(
    _ tokens: [DomainToken]
) throws {
    guard tokens.count <= 256 else {
        throw InvestigationSourceProjectionError.sourceProjectionTooLarge
    }
    var previous: Data?
    for token in tokens {
        let encoded = try canonicalValueBytes(.text(token.rawValue))
        if let previous, !previous.lexicographicallyPrecedes(encoded) {
            throw InvestigationSourceProjectionError.nonCanonicalOrder
        }
        previous = encoded
    }
}

private func sourceProjectionByteCount(
    scanSessionID: ScanSessionID,
    primaryScopeID: ScanScopeID,
    rowCount: UInt64,
    framedRowsByteCount: UInt64,
    relevanceTokens: [DomainToken]
) throws -> UInt64 {
    let relevance = try canonicalValueBytes(
        .array(relevanceTokens.map { .text($0.rawValue) })
    )
    let values = [
        try canonicalValueBytes(.unsigned(1)),
        try canonicalValueBytes(.text(scanSessionID.rawValue)),
        try canonicalValueBytes(.text(primaryScopeID.rawValue)),
        Data([0x30]) + bigEndianData(rowCount),
        relevance,
    ]
    var count = UInt64(Data("STORNAUT-INV-CANON-1\0".utf8).count)
    try checkedAdd(
        UInt64(
            canonicalValueBytes(
                .text("stornaut.investigation.source.v1")
            ).count
        ),
        to: &count
    )
    try checkedAdd(9, to: &count)
    for (index, value) in values.enumerated() {
        try checkedAdd(10, to: &count)
        try checkedAdd(UInt64(value.count), to: &count)
        if index == 3 {
            try checkedAdd(framedRowsByteCount, to: &count)
        }
    }
    return count
}

private func canonicalValueBytes(
    _ value: InvestigationCanonicalValue
) throws -> Data {
    var data = Data()
    try StornautInvestigationCanonicalV1.appendValueForSchema(
        value,
        to: &data
    )
    return data
}

private func checkedAdd(
    _ value: UInt64,
    to total: inout UInt64
) throws {
    let addition = total.addingReportingOverflow(value)
    guard !addition.overflow else {
        throw InvestigationSourceProjectionError.sourceProjectionTooLarge
    }
    total = addition.partialValue
}

private func bigEndianData(_ value: UInt16) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}

private func bigEndianData(_ value: UInt64) -> Data {
    var data = Data()
    data.reserveCapacity(8)
    for shift in stride(from: 56, through: 0, by: -8) {
        data.append(UInt8(truncatingIfNeeded: value >> UInt64(shift)))
    }
    return data
}

private func storageInt64(from date: Date) throws -> Int64 {
    let seconds = date.timeIntervalSince1970
    guard seconds.isFinite else {
        throw InvestigationSourceProjectionError.storageMismatch
    }
    let scaled = seconds * 1_000
    guard scaled.isFinite,
          let value = Int64(exactly: scaled.rounded(.towardZero))
    else {
        throw InvestigationSourceProjectionError.storageMismatch
    }
    return value
}
