import Foundation
import StornautCore

struct HistoryRecord: Sendable, Equatable {
    let session: ScanSession
    let ledger: SpaceLedger?
}

struct HistoryPage: Sendable, Equatable {
    let records: [HistoryRecord]
    let corruptSessionIDs: [String]
    let corruptLedgerSessionIDs: [String]

    init(
        records: [HistoryRecord],
        corruptSessionIDs: [String] = [],
        corruptLedgerSessionIDs: [String] = []
    ) {
        self.records = records
        self.corruptSessionIDs = Array(Set(corruptSessionIDs)).sorted()
        self.corruptLedgerSessionIDs =
            Array(Set(corruptLedgerSessionIDs)).sorted()
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
    let deletingSessionID: ScanSessionID?
    let reasonKey: DomainToken?

    static let idle = HistoryState(
        phase: .idle,
        page: nil,
        deletingSessionID: nil,
        reasonKey: nil
    )

    static func loading(
        _ page: HistoryPage? = nil
    ) -> HistoryState {
        HistoryState(
            phase: .loading,
            page: page,
            deletingSessionID: nil,
            reasonKey: nil
        )
    }

    static func loaded(_ page: HistoryPage) -> HistoryState {
        HistoryState(
            phase: .loaded,
            page: page,
            deletingSessionID: nil,
            reasonKey: nil
        )
    }

    static func deleting(
        _ sessionID: ScanSessionID,
        page: HistoryPage
    ) -> HistoryState {
        HistoryState(
            phase: .deleting,
            page: page,
            deletingSessionID: sessionID,
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
            deletingSessionID: nil,
            reasonKey: reasonKey
        )
    }
}
