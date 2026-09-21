import Foundation
import Testing
@testable import StornautCore

@Test
func surveyorPersistsExcludedBoundaryWithoutReadingDescendants() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "stornaut-exclusion-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    let excluded = root.appending(
        path: "Excluded",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: excluded,
        withIntermediateDirectories: true
    )
    try Data("hidden".utf8).write(
        to: excluded.appending(path: "hidden.bin")
    )
    try Data("visible".utf8).write(
        to: root.appending(path: "visible.bin")
    )
    defer { try? FileManager.default.removeItem(at: root) }

    let request = ScanRequest(
        rootURL: root,
        exclusions: [
            try ScanExclusion(validating: "Excluded"),
        ],
        maximumWorkers: 1
    )
    var observations: [SurveyorObservation] = []
    for try await observation in Surveyor().scan(request) {
        observations.append(observation)
    }

    let boundary = try #require(
        observations.first { $0.relativePath == "Excluded" }
    )
    #expect(boundary.kind == .directory)
    #expect(boundary.measurementStatus == .userExcluded)
    #expect(
        observations.contains {
            $0.relativePath == "Excluded/hidden.bin"
        } == false
    )
    #expect(
        observations.contains {
            $0.relativePath == "visible.bin"
                && $0.measurementStatus == .measured
        }
    )
}

@Test
func excludedBoundaryMakesSpaceLedgerPartialWithoutGuessingBytes() async throws {
    let root = try EvidenceStoreTestSupport.temporaryDirectory(
        "settings-exclusion-ledger"
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let excluded = root.appending(
        path: "Excluded",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: excluded,
        withIntermediateDirectories: true
    )
    try Data(repeating: 0xAB, count: 4_096).write(
        to: excluded.appending(path: "hidden.bin")
    )
    let store = try EvidenceStore(configuration: .memory)
    let coordinator = QuickScanCoordinator(
        store: store,
        catalog: try BuiltInRuleCatalog.load()
    )

    let events = try await collectSettingsProductEvents(
        try await coordinator.start(
            ScanRequest(
                rootURL: root,
                exclusions: [
                    try ScanExclusion(validating: "Excluded"),
                ]
            )
        )
    )
    let projection = try #require(events.compactMap(\.terminal).last)
    let gap = try #require(
        projection.ledger?.coverageGaps.first {
            $0.relativePath.rawValue == "Excluded"
        }
    )

    #expect(projection.session.terminalState == .partial)
    #expect(projection.ledger?.status == .partial)
    #expect(gap.status == .userExcluded)
    #expect(gap.includedInUnknownResidual)
    #expect(projection.ledger?.unmeasurable.bytes == nil)
    #expect(projection.ledger?.unknownIncludesUnmeasurable == true)
    #expect(
        projection.classifications.contains {
            $0.snapshotID == gap.snapshotID
        } == false
    )
    #expect(
        projection.ledger?.owners.contains {
            $0.snapshotID == gap.snapshotID
        } == false
    )
}

private extension QuickScanProductEvent {
    var terminal: QuickScanProjection? {
        guard case let .terminal(projection) = self else {
            return nil
        }
        return projection
    }
}

private func collectSettingsProductEvents(
    _ stream: AsyncThrowingStream<QuickScanProductEvent, Error>
) async throws -> [QuickScanProductEvent] {
    var events: [QuickScanProductEvent] = []
    for try await event in stream {
        events.append(event)
    }
    return events
}
