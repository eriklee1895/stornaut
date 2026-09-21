import Foundation
import StornautCore
import Testing
@testable import StornautApp

@Test
func historyExportNormalizesQuickScanHomePrefix() throws {
    let record = try HistoryExportTestFactory.scan(
        rootPath: "/Users/example/Projects/Stornaut"
    )
    let model = HistoryModel(
        state: .loaded(HistoryPage(records: [record])),
        now: record.session.finishedAt,
        calendar: HistoryExportTestFactory.calendar
    )
    let item = try #require(model.items.first)

    let document = try HistoryExport.document(
        for: item,
        homeDirectory: URL(fileURLWithPath: "/Users/example")
    )
    let object = try HistoryExportTestFactory.object(document)
    let quickScan = try #require(
        object["quickScan"] as? [String: Any]
    )

    #expect(document.suggestedFilename.hasSuffix(".json"))
    #expect(quickScan["scopePath"] as? String == "~/Projects/Stornaut")
}

@Test
func historyExportExpiredManifestContainsOnlyMinimalAuditTruth() throws {
    let fixture = try CleanupResultTestSupport.fixture(.completed)
    let model = HistoryModel(
        state: .loaded(
            HistoryPage(
                records: [],
                manifests: [
                    CleanupManifestHistoryRecord(
                        manifest: fixture.result.manifest,
                        linkedPlan: nil,
                        evidenceAvailability: .expired
                    ),
                ]
            )
        ),
        now: fixture.result.manifest.createdAt,
        calendar: HistoryExportTestFactory.calendar
    )
    let item = try #require(model.items.first)

    let document = try HistoryExport.document(
        for: item,
        homeDirectory: URL(fileURLWithPath: "/Users/example")
    )
    let object = try HistoryExportTestFactory.object(document)
    let manifest = try #require(
        object["cleanupManifest"] as? [String: Any]
    )
    let records = try #require(
        manifest["records"] as? [[String: Any]]
    )

    #expect(
        manifest["manifestID"] as? String
            == fixture.result.manifest.id.rawValue
    )
    #expect(records.count == fixture.result.manifest.records.count)
    for record in records {
        #expect(record["itemName"] == nil)
        #expect(record["relativePath"] == nil)
    }
}

@Test
func historyExportRetainedManifestIncludesOnlyBoundedRelativeEnrichment()
    throws
{
    let fixture = try CleanupResultTestSupport.fixture(.completed)
    let model = HistoryModel(
        state: .loaded(
            HistoryPage(
                records: [],
                manifests: [
                    CleanupManifestHistoryRecord(
                        manifest: fixture.result.manifest,
                        linkedPlan: fixture.plan,
                        evidenceAvailability: .retained
                    ),
                ]
            )
        ),
        now: fixture.result.manifest.createdAt,
        calendar: HistoryExportTestFactory.calendar
    )
    let item = try #require(model.items.first)

    let document = try HistoryExport.document(
        for: item,
        homeDirectory: URL(fileURLWithPath: "/Users/example")
    )
    let object = try HistoryExportTestFactory.object(document)
    let manifest = try #require(
        object["cleanupManifest"] as? [String: Any]
    )
    let records = try #require(
        manifest["records"] as? [[String: Any]]
    )
    let json = String(decoding: document.data, as: UTF8.self)

    #expect(document.data.count < 1_000_000)
    #expect(
        Set(records.compactMap { $0["relativePath"] as? String })
            == Set(
                fixture.plan.items.compactMap {
                    $0.expectedRelativePath?.rawValue
                }
            )
    )
    #expect(!json.contains("/Users/example"))
    #expect(!json.localizedCaseInsensitiveContains("trashURL"))
    #expect(!json.localizedCaseInsensitiveContains("destinationURL"))
}

@Test
func historyExportDropsPreviouslyLoadedEnrichmentWhenPlanExpires() throws {
    let fixture = try CleanupResultTestSupport.fixture(.completed)
    let now = fixture.plan.expiresAt
    let model = HistoryModel(
        state: .loaded(
            HistoryPage(
                records: [],
                manifests: [
                    CleanupManifestHistoryRecord(
                        manifest: fixture.result.manifest,
                        linkedPlan: fixture.plan,
                        evidenceAvailability: .retained
                    ),
                ]
            )
        ),
        now: now,
        calendar: HistoryExportTestFactory.calendar
    )
    let item = try #require(model.items.first)
    guard case let .cleanupManifest(manifestModel) = item else {
        Issue.record("Expected Cleanup Manifest History item")
        return
    }

    let document = try HistoryExport.document(
        for: item,
        homeDirectory: URL(fileURLWithPath: "/Users/example")
    )
    let object = try HistoryExportTestFactory.object(document)
    let manifest = try #require(
        object["cleanupManifest"] as? [String: Any]
    )
    let records = try #require(
        manifest["records"] as? [[String: Any]]
    )

    #expect(manifestModel.evidenceAvailability == .expired)
    #expect(manifestModel.items.allSatisfy { $0.itemName == nil })
    #expect(manifestModel.items.allSatisfy { $0.relativePath == nil })
    #expect(manifest["evidenceAvailability"] as? String == "expired")
    for record in records {
        #expect(record["itemName"] == nil)
        #expect(record["relativePath"] == nil)
    }
}

private enum HistoryExportTestFactory {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func scan(rootPath: String) throws -> HistoryRecord {
        let finishedAt = Date(timeIntervalSince1970: 1_786_700_000)
        let session = try ScanSession(
            id: ScanSessionID(rawValue: "scan-history-export")!,
            startedAt: finishedAt.addingTimeInterval(-60),
            finishedAt: finishedAt,
            terminalState: .completed,
            completedScopes: [
                ScanScope(
                    id: ScanScopeID(rawValue: "scope-history-export")!,
                    rootPath: PersistedPath(rawValue: rootPath)!,
                    completedAt: finishedAt
                ),
            ],
            unfinishedScopes: []
        )
        return HistoryRecord(session: session, ledger: nil)
    }

    static func object(
        _ document: HistoryExportDocument
    ) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: document.data)
                as? [String: Any]
        )
    }
}
