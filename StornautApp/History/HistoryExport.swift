import Foundation
import StornautCore

struct HistoryExportDocument: Sendable, Equatable {
    let data: Data
    let suggestedFilename: String
}

enum HistoryExportError: Error, Sendable, Equatable {
    case documentTooLarge
}

enum HistoryExport {
    private static let maximumDocumentBytes = 1_000_000

    static func document(
        for item: HistoryItemModel,
        homeDirectory: URL
    ) throws -> HistoryExportDocument {
        let payload: Payload
        let identifier: String
        switch item {
        case let .quickScan(record):
            payload = .quickScan(
                QuickScanPayload(
                    record: record,
                    homeDirectory: homeDirectory
                )
            )
            identifier = record.sessionID.rawValue
        case let .cleanupManifest(record):
            payload = .cleanupManifest(
                CleanupManifestPayload(record: record)
            )
            identifier = record.manifestID.rawValue
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        guard data.count <= maximumDocumentBytes else {
            throw HistoryExportError.documentTooLarge
        }
        return HistoryExportDocument(
            data: data,
            suggestedFilename:
                "stornaut-history-\(identifier).json"
        )
    }

    private enum Payload: Encodable {
        case quickScan(QuickScanPayload)
        case cleanupManifest(CleanupManifestPayload)

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(1, forKey: .schemaVersion)
            switch self {
            case let .quickScan(payload):
                try container.encode("quickScan", forKey: .recordType)
                try container.encode(payload, forKey: .quickScan)
            case let .cleanupManifest(payload):
                try container.encode(
                    "cleanupManifest",
                    forKey: .recordType
                )
                try container.encode(
                    payload,
                    forKey: .cleanupManifest
                )
            }
        }

        private enum CodingKeys: String, CodingKey {
            case schemaVersion
            case recordType
            case quickScan
            case cleanupManifest
        }
    }

    private struct QuickScanPayload: Encodable {
        let sessionID: String
        let startedAt: Date
        let finishedAt: Date
        let durationSeconds: TimeInterval
        let terminalState: ScanTerminalState
        let scopePath: String?
        let unfinishedReason: ScanScopeCompletionReason?
        let expiresAt: Date
        let coverage: String
        let ledger: LedgerPayload?

        init(
            record: HistoryRecordModel,
            homeDirectory: URL
        ) {
            sessionID = record.sessionID.rawValue
            startedAt = record.startedAt
            finishedAt = record.finishedAt
            durationSeconds = record.duration
            terminalState = record.terminalState
            scopePath = record.scopePath.map {
                HistoryExport.normalized(
                    path: $0.rawValue,
                    homeDirectory: homeDirectory
                )
            }
            unfinishedReason = record.unfinishedReason
            expiresAt = record.expiresAt
            coverage = record.coverage.rawValue
            ledger = record.ledgerStatus == .available
                ? LedgerPayload(record: record)
                : nil
        }
    }

    private struct LedgerPayload: Encodable {
        let status: String
        let rows: [LedgerRowPayload]
        let volumeCapacityStatus: AccountingMeasurementStatus?
        let volumeCapacityBytes: UInt64?
        let reconciliationStatus: SpaceLedgerStatus?
        let caveats: [SpaceLedgerCaveat]

        init(record: HistoryRecordModel) {
            status = record.ledgerStatus.rawValue
            rows = record.ledgerRows.map(LedgerRowPayload.init)
            volumeCapacityStatus = record.volumeCapacityStatus
            volumeCapacityBytes = record.volumeCapacity?.value
            reconciliationStatus = record.ledgerReconciliationStatus
            caveats = record.caveats
        }
    }

    private struct LedgerRowPayload: Encodable {
        let kind: String
        let status: AccountingMeasurementStatus
        let bytes: UInt64?
        let sources: [AccountingSource]

        init(_ row: HistoryLedgerRow) {
            kind = row.kind.rawValue
            status = row.status
            bytes = row.bytes?.value
            sources = row.sources
        }
    }

    private struct CleanupManifestPayload: Encodable {
        let manifestID: String
        let planID: String
        let createdAt: Date
        let expiresAt: Date
        let evidenceAvailability: String
        let outcome: String
        let summary: CleanupManifestSummary
        let records: [ManifestRecordPayload]
        let systemObservation: ManifestSystemObservation?

        init(record: HistoryManifestRecordModel) {
            manifestID = record.manifestID.rawValue
            planID = record.planID.rawValue
            createdAt = record.createdAt
            expiresAt = record.expiresAt
            evidenceAvailability = record.evidenceAvailability.rawValue
            outcome = record.outcome.rawValue
            summary = record.summary
            records = record.items.map {
                ManifestRecordPayload(
                    item: $0,
                    includesEnrichment:
                        record.evidenceAvailability == .retained
                )
            }
            systemObservation = record.systemObservation
        }
    }

    private struct ManifestRecordPayload: Encodable {
        let actionID: String
        let planItemID: String
        let policyDisposition: ReclaimDisposition
        let policyReasonKeys: [DomainToken]
        let action: ProposedCleanupAction
        let result: ManifestActionResult
        let recovery: CleanupRecoveryState
        let measures: CleanupManifestMeasures
        let startedAt: Date?
        let finishedAt: Date?
        let error: CleanupManifestError?
        let itemName: String?
        let relativePath: String?

        init(
            item: HistoryManifestItemModel,
            includesEnrichment: Bool
        ) {
            actionID = item.actionID.rawValue
            planItemID = item.planItemID.rawValue
            policyDisposition = item.policyDisposition
            policyReasonKeys = item.policyReasonKeys
            action = item.action
            result = item.result
            recovery = item.recovery
            measures = item.measures
            startedAt = item.startedAt
            finishedAt = item.finishedAt
            error = item.error
            itemName = includesEnrichment ? item.itemName : nil
            relativePath = includesEnrichment
                ? item.relativePath?.rawValue
                : nil
        }
    }

    private static func normalized(
        path: String,
        homeDirectory: URL
    ) -> String {
        let home = homeDirectory.standardizedFileURL.path
        let standardized = URL(fileURLWithPath: path)
            .standardizedFileURL.path
        if standardized == home {
            return "~"
        }
        let prefix = home.hasSuffix("/") ? home : home + "/"
        guard standardized.hasPrefix(prefix) else {
            return standardized
        }
        return "~/" + standardized.dropFirst(prefix.count)
    }
}
