import Darwin
import Foundation

public struct CleanupVolumeSample: Sendable, Equatable {
    public let device: UInt64
    public let freeBytes: ByteCount
    public let source: DomainToken
    public let sampledAt: Date

    public init(
        device: UInt64,
        freeBytes: ByteCount,
        source: DomainToken,
        sampledAt: Date
    ) throws {
        guard sampledAt.timeIntervalSince1970.isFinite else {
            throw DomainContractError.invalidMeasurement
        }
        self.device = device
        self.freeBytes = freeBytes
        self.source = source
        self.sampledAt = sampledAt
    }
}

package struct FoundationCleanupVolumeSampler: CleanupVolumeSampling {
    package init() {}

    package func sample(
        rootURL: URL,
        sampledAt: Date
    ) throws -> CleanupVolumeSample {
        let canonical = rootURL.standardizedFileURL
            .resolvingSymlinksInPath()
        var information = stat()
        guard lstat(canonical.path, &information) == 0,
              mode_t(information.st_mode) & S_IFMT == S_IFDIR,
              let free = try canonical.resourceValues(
                  forKeys: [.volumeAvailableCapacityKey]
              ).volumeAvailableCapacity,
              free >= 0,
              let freeBytes = ByteCount(UInt64(free))
        else {
            throw DomainContractError.invalidMeasurement
        }
        return try CleanupVolumeSample(
            device: UInt64(bitPattern: Int64(information.st_dev)),
            freeBytes: freeBytes,
            source: DomainToken(
                rawValue: "foundation.volume-available-capacity"
            )!,
            sampledAt: sampledAt
        )
    }
}

public struct CleanupAccounting: Sendable {
    public init() {}

    public func manifest(
        journal: CleanupRunJournal,
        volumeBefore: CleanupVolumeSample?,
        volumeAfter: CleanupVolumeSample?,
        createdAt: Date
    ) throws -> CleanupManifest {
        guard journal.stage == .manifestPending
                || journal.stage == .auditPending
                || journal.stage == .finalized,
              journal.entries.allSatisfy({
                  $0.state == .outcomeRecorded
                      || $0.state == .cancelled
              }),
              journal.manifestCreatedAt == nil
                || journal.manifestCreatedAt == createdAt,
              journal.entries.allSatisfy({ entry in
                  (entry.outcome?.finishedAt ?? createdAt) <= createdAt
              })
        else {
            throw DomainContractError.invalidMeasurement
        }
        let records = try journal.entries.map(manifestRecord)
        let summary = try CleanupManifestSummary(records: records)
        return try CleanupManifest(
            id: journal.manifestID,
            planID: journal.planID,
            createdAt: createdAt,
            expiresAt: createdAt.addingTimeInterval(90 * 86_400),
            records: records,
            summary: summary,
            systemObservation: journal.systemObservation
                ?? systemObservation(
                    before: volumeBefore,
                    after: volumeAfter
                )
        )
    }

    func systemObservation(
        before: CleanupVolumeSample?,
        after: CleanupVolumeSample?
    ) throws -> ManifestSystemObservation? {
        try makeSystemObservation(before: before, after: after)
    }

    private func manifestRecord(
        _ entry: CleanupRunJournalEntry
    ) throws -> CleanupManifestRecord {
        guard let outcome = entry.outcome else {
            throw DomainContractError.invalidMeasurement
        }
        return try CleanupManifestRecord(
            actionID: entry.actionID,
            planItemID: entry.planItemID,
            policyDecisionID: entry.policyDecisionID,
            policyDisposition: entry.policyDisposition,
            policyReasonKeys: entry.policyReasonKeys,
            action: entry.action,
            result: outcome.result,
            recovery: outcome.recovery,
            measures: outcome.measures,
            startedAt: entry.startedAt,
            finishedAt: entry.state == .cancelled
                ? nil
                : outcome.finishedAt,
            error: outcome.error
        )
    }

    private func makeSystemObservation(
        before: CleanupVolumeSample?,
        after: CleanupVolumeSample?
    ) throws -> ManifestSystemObservation? {
        guard let before, let after else {
            return nil
        }
        guard before.device == after.device,
              before.source == after.source,
              after.sampledAt >= before.sampledAt
        else {
            return nil
        }
        let delta = Int64(after.freeBytes.value)
            .subtractingReportingOverflow(
                Int64(before.freeBytes.value)
            )
        guard !delta.overflow else {
            throw DomainContractError.invalidMeasurement
        }
        let signedDelta = SignedByteDelta(delta.partialValue)
        return try ManifestSystemObservation(
            source: before.source,
            freeBytesBefore: before.freeBytes,
            sampledBeforeAt: before.sampledAt,
            freeBytesAfter: after.freeBytes,
            sampledAfterAt: after.sampledAt,
            freeSpaceDelta: signedDelta,
            unexplainedDelta: signedDelta
        )
    }
}
