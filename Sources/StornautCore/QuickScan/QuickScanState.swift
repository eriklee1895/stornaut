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

public struct QuickScanProjection: Codable, Sendable, Equatable {
    public let session: ScanSession
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
        corruptRecordIDs: [String]
    ) throws {
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
              Set(corruptRecordIDs).count == corruptRecordIDs.count
        else {
            throw DomainContractError.invalidMeasurement
        }
        if session.terminalState == .completed {
            guard !snapshots.isEmpty,
                  !classifications.isEmpty,
                  ledger != nil,
                  issues.isEmpty,
                  corruptRecordIDs.isEmpty
            else {
                throw DomainContractError.invalidMeasurement
            }
        }
        self.session = session
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
