import CryptoKit
import Foundation
import Testing
@testable import StornautCore

@Test
func quickScanExecutionProfilesUseOneActivitySnapshotForAllCandidates()
    async throws
{
    let fixture = try QuickScanExecutionFixture()
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: .memory)
    let rules = try BuiltInRuleCatalog.load()
    let profiles = try BuiltInExecutionProfileCatalog.load(
        ruleCatalog: rules
    )
    let activitySource = QuickScanExecutionActivitySource(
        snapshot: RunningActivitySnapshot(
            applications: [],
            processes: [],
            observedAt: fixture.observedAt
        )
    )
    let coordinator = QuickScanCoordinator(
        store: store,
        catalog: rules,
        activityProvider: QuickScanExecutionGenericActivityProvider(),
        executionProfileCatalog: profiles,
        executableEvidenceResolver: ExecutableEvidenceResolver(
            activityProvider: RunningActivityProvider(
                source: activitySource
            )
        ),
        now: { fixture.observedAt },
        snapshotID: quickScanExecutionSnapshotID,
        classificationID: quickScanExecutionClassificationID,
        evidenceID: quickScanExecutionActivityEvidenceID,
        executionEvidenceID: quickScanExecutionEvidenceID
    )
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: 1,
        persistenceBatchSize: 2,
        sessionID: ScanSessionID(
            rawValue: "scan-quick-execution-evidence"
        )!,
        scopeID: ScanScopeID(
            rawValue: "scope-quick-execution-evidence"
        )!
    )

    _ = try await collectQuickScanExecutionEvents(
        try await coordinator.start(request)
    )

    let classifications = try await store.classifications(
        sessionID: request.sessionID,
        limit: 100,
        offset: 0
    )
    let snapshots = try await store.pathSnapshots(
        sessionID: request.sessionID,
        limit: 100,
        offset: 0
    )
    let evidence = try await store.evidence(
        sessionID: request.sessionID,
        limit: 100,
        offset: 0
    )
    let pathsBySnapshot = Dictionary(
        uniqueKeysWithValues: snapshots.records.map {
            ($0.id, $0.relativePath)
        }
    )
    let dispositions = Dictionary(
        uniqueKeysWithValues: classifications.records.compactMap {
            classification in
            pathsBySnapshot[classification.snapshotID].map {
                ($0, classification.disposition)
            }
        }
    )

    #expect(await activitySource.callCount == 1)
    #expect(dispositions[".npm/_cacache"] == .readyToReclaim)
    #expect(dispositions["Library/Caches/pip"] == .readyToReclaim)
    #expect(
        dispositions["Library/Caches/go-build"]
            == .reviewRecommended
    )
    #expect(dispositions[".cache/uv"] == .reviewRecommended)
    for path in [
        ".npm/_cacache",
        "Library/Caches/pip",
        "Library/Caches/go-build",
    ] {
        let snapshotID = try #require(
            snapshots.records.first { $0.relativePath == path }?.id
        )
        let records = evidence.records.filter {
            $0.targetID == snapshotID
        }
        #expect(records.count == 5)
        #expect(records.allSatisfy {
            $0.source.identifier.rawValue.hasPrefix("execution.")
        })
    }
    let uvID = try #require(
        snapshots.records.first { $0.relativePath == ".cache/uv" }?.id
    )
    #expect(
        evidence.records.filter { $0.targetID == uvID }.count == 1
    )
}

@Test
func quickScanExecutionProfilesProtectActiveAndFailClosedOnIncompleteCoverage()
    async throws
{
    let fixture = try QuickScanExecutionFixture(includeUV: false)
    defer { fixture.remove() }
    let store = try EvidenceStore(configuration: .memory)
    let rules = try BuiltInRuleCatalog.load()
    let profiles = try BuiltInExecutionProfileCatalog.load(
        ruleCatalog: rules
    )
    let activitySource = QuickScanExecutionActivitySource(
        snapshot: RunningActivitySnapshot(
            applications: [],
            processes: [
                try RunningProcessRecord(
                    name: DomainLabel(validating: "node"),
                    processIdentifier: 82
                ),
            ],
            processStatus: .unavailable(.permissionDenied),
            observedAt: fixture.observedAt
        )
    )
    let coordinator = QuickScanCoordinator(
        store: store,
        catalog: rules,
        activityProvider: QuickScanExecutionGenericActivityProvider(),
        executionProfileCatalog: profiles,
        executableEvidenceResolver: ExecutableEvidenceResolver(
            activityProvider: RunningActivityProvider(
                source: activitySource
            )
        ),
        now: { fixture.observedAt },
        snapshotID: quickScanExecutionSnapshotID,
        classificationID: quickScanExecutionClassificationID,
        evidenceID: quickScanExecutionActivityEvidenceID,
        executionEvidenceID: quickScanExecutionEvidenceID
    )
    let request = ScanRequest(
        rootURL: fixture.rootURL,
        maximumWorkers: 1,
        sessionID: ScanSessionID(
            rawValue: "scan-quick-execution-active"
        )!,
        scopeID: ScanScopeID(
            rawValue: "scope-quick-execution-active"
        )!
    )

    _ = try await collectQuickScanExecutionEvents(
        try await coordinator.start(request)
    )

    let snapshots = try await store.pathSnapshots(
        sessionID: request.sessionID,
        limit: 100,
        offset: 0
    ).records
    let paths = Dictionary(
        uniqueKeysWithValues: snapshots.map { ($0.id, $0.relativePath) }
    )
    let dispositions = Dictionary(
        uniqueKeysWithValues: try await store.classifications(
            sessionID: request.sessionID,
            limit: 100,
            offset: 0
        ).records.compactMap { classification in
            paths[classification.snapshotID].map {
                ($0, classification.disposition)
            }
        }
    )

    #expect(await activitySource.callCount == 1)
    #expect(dispositions[".npm/_cacache"] == .protected)
    #expect(dispositions["Library/Caches/pip"] == .unknown)
    #expect(dispositions["Library/Caches/go-build"] == .unknown)
}

private actor QuickScanExecutionActivitySource:
    RunningActivitySnapshotting
{
    private let snapshotValue: RunningActivitySnapshot
    private(set) var callCount = 0

    init(snapshot: RunningActivitySnapshot) {
        snapshotValue = snapshot
    }

    func snapshot() async throws -> RunningActivitySnapshot {
        callCount += 1
        return snapshotValue
    }
}

private struct QuickScanExecutionGenericActivityProvider:
    QuickScanActivityProviding
{
    func observations(
        for snapshot: PathSnapshot,
        rule: CompiledRule,
        rootURL: URL,
        observedAt: Date
    ) async throws -> [ActivityObservation] {
        try rule.requiredActivityKeys.map {
            try ActivityObservation(
                key: ActivityKey(validating: $0.rawValue),
                state: rule.id.rawValue == "cache-uv"
                    ? .unavailable
                    : .satisfied,
                source: .runningProcess,
                origin: .external,
                observedAt: observedAt,
                reason: DomainToken(
                    rawValue: rule.id.rawValue == "cache-uv"
                        ? "activity.fixture.unavailable"
                        : "activity.fixture.inactive"
                )!
            )
        }
    }
}

private final class QuickScanExecutionFixture: @unchecked Sendable {
    let rootURL: URL
    let observedAt = Date(timeIntervalSince1970: 1_786_650_000)

    init(includeUV: Bool = true) throws {
        rootURL = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-task29-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: false
        )
        for path in [
            ".npm/_cacache",
            "Library/Caches/pip",
            "Library/Caches/go-build",
        ] + (includeUV ? [".cache/uv"] : []) {
            try FileManager.default.createDirectory(
                at: rootURL.appending(
                    path: path,
                    directoryHint: .isDirectory
                ),
                withIntermediateDirectories: true
            )
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}

private func collectQuickScanExecutionEvents(
    _ stream: AsyncThrowingStream<QuickScanProductEvent, Error>
) async throws -> [QuickScanProductEvent] {
    var events: [QuickScanProductEvent] = []
    for try await event in stream {
        events.append(event)
    }
    return events
}

private func quickScanExecutionSnapshotID(
    _ relativePath: String
) -> SnapshotID {
    SnapshotID(
        rawValue: "snapshot-\(quickScanExecutionDigest(relativePath))"
    )!
}

private func quickScanExecutionClassificationID(
    _ snapshotID: SnapshotID
) -> ClassificationID {
    ClassificationID(
        rawValue:
            "classification-\(quickScanExecutionDigest(snapshotID.rawValue))"
    )!
}

private func quickScanExecutionActivityEvidenceID(
    _ snapshotID: SnapshotID,
    _ observation: ActivityObservation
) -> EvidenceID {
    let payload = "\(snapshotID.rawValue)|\(observation.key.rawValue)"
    let digest = quickScanExecutionDigest(payload)
    return EvidenceID(
        rawValue: "evidence-activity-\(digest)"
    )!
}

private func quickScanExecutionEvidenceID(
    _ snapshotID: SnapshotID,
    _ key: DomainToken
) -> EvidenceID {
    let payload = "\(snapshotID.rawValue)|\(key.rawValue)"
    let digest = quickScanExecutionDigest(payload)
    return EvidenceID(
        rawValue: "evidence-execution-\(digest)"
    )!
}

private func quickScanExecutionDigest(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8))
        .prefix(12)
        .map { String(format: "%02x", $0) }
        .joined()
}
