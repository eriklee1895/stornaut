import Foundation
import StornautCore

enum HistoryRecordID: Hashable, Sendable {
    case quickScan(ScanSessionID)
    case cleanupManifest(CleanupManifestID)

    var rawValue: String {
        switch self {
        case let .quickScan(id):
            "quickScan:\(id.rawValue)"
        case let .cleanupManifest(id):
            "cleanupManifest:\(id.rawValue)"
        }
    }
}

struct HistoryRecord: Sendable, Equatable {
    let session: ScanSession
    let ledger: SpaceLedger?
}

struct HistoryPage: Sendable, Equatable {
    let records: [HistoryRecord]
    let manifests: [CleanupManifestHistoryRecord]
    let corruptSessionIDs: [String]
    let corruptLedgerSessionIDs: [String]
    let corruptManifestIDs: [String]

    init(
        records: [HistoryRecord],
        manifests: [CleanupManifestHistoryRecord] = [],
        corruptSessionIDs: [String] = [],
        corruptLedgerSessionIDs: [String] = [],
        corruptManifestIDs: [String] = []
    ) {
        self.records = records
        self.manifests = manifests
        self.corruptSessionIDs = Array(Set(corruptSessionIDs)).sorted()
        self.corruptLedgerSessionIDs =
            Array(Set(corruptLedgerSessionIDs)).sorted()
        self.corruptManifestIDs =
            Array(Set(corruptManifestIDs)).sorted()
    }

    static let empty = HistoryPage(records: [])
}

enum HistoryPhase: String, Sendable, Equatable {
    case idle
    case loading
    case loaded
    case deleting
    case error
}

struct HistoryState: Sendable, Equatable {
    let phase: HistoryPhase
    let page: HistoryPage?
    let deletingRecordID: HistoryRecordID?
    let reasonKey: DomainToken?

    var deletingSessionID: ScanSessionID? {
        guard case let .quickScan(id) = deletingRecordID else {
            return nil
        }
        return id
    }

    static let idle = HistoryState(
        phase: .idle,
        page: nil,
        deletingRecordID: nil,
        reasonKey: nil
    )

    static func loading(
        _ page: HistoryPage? = nil
    ) -> HistoryState {
        HistoryState(
            phase: .loading,
            page: page,
            deletingRecordID: nil,
            reasonKey: nil
        )
    }

    static func loaded(_ page: HistoryPage) -> HistoryState {
        HistoryState(
            phase: .loaded,
            page: page,
            deletingRecordID: nil,
            reasonKey: nil
        )
    }

    static func deleting(
        _ sessionID: ScanSessionID,
        page: HistoryPage
    ) -> HistoryState {
        deleting(.quickScan(sessionID), page: page)
    }

    static func deleting(
        _ recordID: HistoryRecordID,
        page: HistoryPage
    ) -> HistoryState {
        HistoryState(
            phase: .deleting,
            page: page,
            deletingRecordID: recordID,
            reasonKey: nil
        )
    }

    static func failed(
        page: HistoryPage?,
        reasonKey: DomainToken
    ) -> HistoryState {
        HistoryState(
            phase: .error,
            page: page,
            deletingRecordID: nil,
            reasonKey: reasonKey
        )
    }
}
