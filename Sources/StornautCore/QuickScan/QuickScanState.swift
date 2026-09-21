import Foundation

public enum QuickScanProductIssueKind:
    String,
    Codable,
    Sendable,
    CaseIterable
{
    case activityUnavailable
    case classificationUnavailable
    case ledgerUnavailable
    case persistenceUnavailable
    case corruptRecords
}

public struct QuickScanProductIssue: Codable, Sendable, Equatable {
    public let kind: QuickScanProductIssueKind
    public let affectedSnapshotID: SnapshotID?
    public let reasonKey: DomainToken

    public init(
        kind: QuickScanProductIssueKind,
        affectedSnapshotID: SnapshotID?,
        reasonKey: DomainToken
    ) {
        self.kind = kind
        self.affectedSnapshotID = affectedSnapshotID
        self.reasonKey = reasonKey
    }
}

public enum QuickScanProductError: Error, Sendable, Equatable {
    case eventBufferExceeded(limit: Int)
    case missingBaseline
    case missingScanTerminal
}

public struct QuickScanDispositionCounts:
    Codable,
    Sendable,
    Equatable
{
    public let readyToReclaim: Int
    public let reviewRecommended: Int
    public let protected: Int
    public let unknown: Int

    public init(
        readyToReclaim: Int,
        reviewRecommended: Int,
        protected: Int,
        unknown: Int
    ) throws {
        let values = [
            readyToReclaim,
            reviewRecommended,
            protected,
            unknown,
        ]
        guard values.allSatisfy({ $0 >= 0 }),
              Self.checkedSum(values) != nil
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.readyToReclaim = readyToReclaim
        self.reviewRecommended = reviewRecommended
        self.protected = protected
        self.unknown = unknown
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            readyToReclaim: container.decode(
                Int.self,
                forKey: .readyToReclaim
            ),
            reviewRecommended: container.decode(
                Int.self,
                forKey: .reviewRecommended
            ),
            protected: container.decode(Int.self, forKey: .protected),
            unknown: container.decode(Int.self, forKey: .unknown)
        )
    }

    public init(classifications: [Classification]) {
        readyToReclaim = classifications.count {
            $0.disposition == .readyToReclaim
        }
        reviewRecommended = classifications.count {
            $0.disposition == .reviewRecommended
        }
        protected = classifications.count {
            $0.disposition == .protected
        }
        unknown = classifications.count {
            $0.disposition == .unknown
        }
    }

    public var total: Int {
        Self.checkedSum([
            readyToReclaim,
            reviewRecommended,
            protected,
            unknown,
        ])!
    }

    public subscript(_ disposition: ReclaimDisposition) -> Int {
        switch disposition {
        case .readyToReclaim:
            readyToReclaim
        case .reviewRecommended:
            reviewRecommended
        case .protected:
            protected
        case .unknown:
            unknown
        }
    }

    private static func checkedSum(_ values: [Int]) -> Int? {
        values.reduce(Optional(0)) { partial, value in
            guard let partial else {
                return nil
            }
            let result = partial.addingReportingOverflow(value)
            return result.overflow ? nil : result.partialValue
        }
    }
}

public struct QuickScanProjection: Codable, Sendable, Equatable {
    public let session: ScanSession
    public let snapshotCount: Int
    public let classificationCount: Int
    public let candidateCount: Int
    public let evidenceCount: Int
    public let dispositionCounts: QuickScanDispositionCounts
    public let snapshots: [PathSnapshot]
    public let classifications: [Classification]
    public let evidence: [EvidenceRecord]
    public let ledger: SpaceLedger?
    public let issues: [QuickScanProductIssue]
    public let corruptRecordIDs: [String]

    public init(
        session: ScanSession,
        snapshots: [PathSnapshot],
        classifications: [Classification],
        evidence: [EvidenceRecord],
        ledger: SpaceLedger?,
        issues: [QuickScanProductIssue],
        corruptRecordIDs: [String],
        snapshotCount: Int? = nil,
        classificationCount: Int? = nil,
        candidateCount: Int? = nil,
        evidenceCount: Int? = nil,
        dispositionCounts: QuickScanDispositionCounts? = nil
    ) throws {
        let snapshotCount = snapshotCount ?? snapshots.count
        let classificationCount =
            classificationCount ?? classifications.count
        let projectedSnapshotByID = Dictionary(
            uniqueKeysWithValues: snapshots.map { ($0.id, $0) }
        )
        let candidateCount = candidateCount
            ?? classifications.count {
                projectedSnapshotByID[$0.snapshotID]?.relativePath != "."
            }
        let evidenceCount = evidenceCount ?? evidence.count
        let dispositionCounts = dispositionCounts
            ?? QuickScanDispositionCounts(classifications: classifications)
        let projectedDispositionCounts = QuickScanDispositionCounts(
            classifications: classifications
        )
        let snapshotIDs = Set(snapshots.map(\.id))
        let classificationIDs = Set(classifications.map(\.id))
        let classificationTargets = Set(classifications.map(\.snapshotID))
        let evidenceIDs = Set(evidence.map(\.id))
        guard Set(snapshots.map(\.id)).count == snapshots.count,
              classificationIDs.count == classifications.count,
              evidenceIDs.count == evidence.count,
              snapshots.allSatisfy({ $0.sessionID == session.id }),
              classificationTargets.count == classifications.count,
              classificationTargets.isSubset(of: snapshotIDs),
              evidence.allSatisfy({
                  snapshotIDs.contains($0.targetID)
              }),
              ledger == nil || ledger?.sessionID == session.id,
              Set(corruptRecordIDs).count == corruptRecordIDs.count,
              snapshotCount >= snapshots.count,
              classificationCount >= classifications.count,
              classificationCount <= snapshotCount,
              candidateCount >= 0,
              candidateCount <= classificationCount,
              evidenceCount >= evidence.count,
              dispositionCounts.total == classificationCount,
              projectedDispositionCounts.readyToReclaim
                <= dispositionCounts.readyToReclaim,
              projectedDispositionCounts.reviewRecommended
                <= dispositionCounts.reviewRecommended,
              projectedDispositionCounts.protected
                <= dispositionCounts.protected,
              projectedDispositionCounts.unknown
                <= dispositionCounts.unknown,
              session.aggregate?.entries.total == nil
                || session.aggregate?.entries.total == snapshotCount
        else {
            throw DomainContractError.invalidMeasurement
        }
        if session.terminalState == .completed {
            guard snapshotCount > 0,
                  !snapshots.isEmpty,
                  !classifications.isEmpty,
                  ledger != nil,
                  issues.isEmpty,
                  corruptRecordIDs.isEmpty
            else {
                throw DomainContractError.invalidMeasurement
            }
        }
        self.session = session
        self.snapshotCount = snapshotCount
        self.classificationCount = classificationCount
        self.candidateCount = candidateCount
        self.evidenceCount = evidenceCount
        self.dispositionCounts = dispositionCounts
        self.snapshots = snapshots.sorted {
            $0.relativePath < $1.relativePath
        }
        self.classifications = classifications.sorted {
            if $0.snapshotID.rawValue != $1.snapshotID.rawValue {
                return $0.snapshotID.rawValue < $1.snapshotID.rawValue
            }
            return $0.id.rawValue < $1.id.rawValue
        }
        self.evidence = evidence.sorted {
            if $0.targetID.rawValue != $1.targetID.rawValue {
                return $0.targetID.rawValue < $1.targetID.rawValue
            }
            return $0.id.rawValue < $1.id.rawValue
        }
        self.ledger = ledger
        self.issues = issues
        self.corruptRecordIDs = corruptRecordIDs.sorted()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            session: container.decode(ScanSession.self, forKey: .session),
            snapshots: container.decode(
                [PathSnapshot].self,
                forKey: .snapshots
            ),
            classifications: container.decode(
                [Classification].self,
                forKey: .classifications
            ),
            evidence: container.decode(
                [EvidenceRecord].self,
                forKey: .evidence
            ),
            ledger: container.decodeIfPresent(
                SpaceLedger.self,
                forKey: .ledger
            ),
            issues: container.decode(
                [QuickScanProductIssue].self,
                forKey: .issues
            ),
            corruptRecordIDs: container.decode(
                [String].self,
                forKey: .corruptRecordIDs
            ),
            snapshotCount: container.decodeIfPresent(
                Int.self,
                forKey: .snapshotCount
            ),
            classificationCount: container.decodeIfPresent(
                Int.self,
                forKey: .classificationCount
            ),
            candidateCount: container.decodeIfPresent(
                Int.self,
                forKey: .candidateCount
            ),
            evidenceCount: container.decodeIfPresent(
                Int.self,
                forKey: .evidenceCount
            ),
            dispositionCounts: container.decodeIfPresent(
                QuickScanDispositionCounts.self,
                forKey: .dispositionCounts
            )
        )
    }
}

public enum QuickScanProductEvent: Sendable, Equatable {
    case stageChanged(QuickScanStage)
    case progress(QuickScanProgress)
    case issueObserved(QuickScanIssueObservation)
    case classifiedSnapshotObserved(PathSnapshot, Classification)
    case evidenceObserved(EvidenceRecord)
    case productIssueObserved(QuickScanProductIssue)
    case ledgerUpdated(SpaceLedger)
    case terminal(QuickScanProjection)
}
