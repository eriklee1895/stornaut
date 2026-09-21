import Foundation

public struct SpaceLedgerReconciler: Sendable {
    public init() {}

    public func reconcile(_ input: SpaceLedgerInput) throws -> SpaceLedger {
        try validateBaselines(input)
        let snapshotByID = try validateSnapshots(input)
        let classificationBySnapshot = try validateClassifications(
            input.classifications,
            snapshots: snapshotByID
        )
        var incremental = try IncrementalSpaceLedger(
            startBaseline: input.startBaseline,
            endBaseline: input.endBaseline,
            ownerInputs: classificationBySnapshot.map {
                SpaceLedgerOwnerInput(
                    snapshot: snapshotByID[$0.key]!,
                    classification: $0.value
                )
            },
            groupAllRegularFiles: true
        )
        try incremental.consume(
            input.snapshots.sorted {
                $0.relativePath < $1.relativePath
            }
        )
        return try incremental.finish()
    }
}

private extension SpaceLedgerReconciler {
    func validateBaselines(_ input: SpaceLedgerInput) throws {
        let start = input.startBaseline
        let end = input.endBaseline
        guard start.sessionID == end.sessionID,
              start.scopeID == end.scopeID,
              start.rootPath == end.rootPath,
              start.rootIdentity.device == end.rootIdentity.device,
              start.rootIdentity.inode == end.rootIdentity.inode,
              start.rootIdentity.isDirectory,
              end.rootIdentity.isDirectory,
              start.source.sampledAt <= end.source.sampledAt
        else {
            throw SpaceLedgerError.baselineMismatch
        }
    }

    func validateSnapshots(
        _ input: SpaceLedgerInput
    ) throws -> [SnapshotID: PathSnapshot] {
        var byID: [SnapshotID: PathSnapshot] = [:]
        var paths = Set<String>()
        for snapshot in input.snapshots {
            guard snapshot.sessionID == input.endBaseline.sessionID,
                  snapshot.scopeID == input.endBaseline.scopeID
            else {
                throw SpaceLedgerError.snapshotScopeMismatch
            }
            guard byID.updateValue(snapshot, forKey: snapshot.id) == nil else {
                throw SpaceLedgerError.duplicateSnapshot
            }
            guard paths.insert(snapshot.relativePath).inserted else {
                throw SpaceLedgerError.duplicatePath
            }
        }
        return byID
    }

    func validateClassifications(
        _ classifications: [Classification],
        snapshots: [SnapshotID: PathSnapshot]
    ) throws -> [SnapshotID: Classification] {
        var IDs = Set<ClassificationID>()
        var bySnapshot: [SnapshotID: Classification] = [:]
        for classification in classifications {
            guard IDs.insert(classification.id).inserted,
                  bySnapshot.updateValue(
                      classification,
                      forKey: classification.snapshotID
                  ) == nil
            else {
                throw SpaceLedgerError.duplicateClassification
            }
            guard snapshots[classification.snapshotID] != nil else {
                throw SpaceLedgerError.classificationTargetMissing
            }
        }
        return bySnapshot
    }
}
