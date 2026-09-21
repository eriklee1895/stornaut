import Foundation

public enum SpaceLedgerStatus: String, Codable, Sendable {
    case reconciled
    case partial
    case inconsistent
}

public enum SpaceLedgerCaveat: String, Codable, Sendable, CaseIterable {
    case sparseFileObserved
    case hardLinkDeduplicated
    case hardLinkOwnershipAmbiguous
    case cloneAndCompressionNotAttributed
    case purgeableNotEstimated
    case volumeChangedDuringScan
    case knownExceedsVolumeUsed
}

public enum SpaceLedgerError: Error, Sendable, Equatable {
    case baselineMismatch
    case duplicateSnapshot
    case duplicatePath
    case duplicateClassification
    case classificationTargetMissing
    case snapshotScopeMismatch
    case hardLinkMetadataMismatch
    case integerOverflow
}

public struct SpaceLedgerInput: Sendable {
    public let startBaseline: VolumeBaseline
    public let endBaseline: VolumeBaseline
    public let snapshots: [PathSnapshot]
    public let classifications: [Classification]

    public init(
        startBaseline: VolumeBaseline,
        endBaseline: VolumeBaseline,
        snapshots: [PathSnapshot],
        classifications: [Classification]
    ) {
        self.startBaseline = startBaseline
        self.endBaseline = endBaseline
        self.snapshots = snapshots
        self.classifications = classifications
    }
}

public struct SpaceLedgerMeasure: Codable, Sendable, Equatable {
    public let status: AccountingMeasurementStatus
    public let bytes: ByteCount?
    public let sources: [AccountingSource]
    public let formulaKey: DomainToken
    public let explanationKey: DomainToken

    public init(
        status: AccountingMeasurementStatus,
        bytes: ByteCount?,
        sources: [AccountingSource],
        formulaKey: DomainToken,
        explanationKey: DomainToken
    ) throws {
        let requiresBytes = status == .measured || status == .estimated
        guard !sources.isEmpty,
              requiresBytes == (bytes != nil)
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.status = status
        self.bytes = bytes
        self.sources = sources
        self.formulaKey = formulaKey
        self.explanationKey = explanationKey
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            status: container.decode(
                AccountingMeasurementStatus.self,
                forKey: .status
            ),
            bytes: container.decodeIfPresent(ByteCount.self, forKey: .bytes),
            sources: container.decode(
                [AccountingSource].self,
                forKey: .sources
            ),
            formulaKey: container.decode(
                DomainToken.self,
                forKey: .formulaKey
            ),
            explanationKey: container.decode(
                DomainToken.self,
                forKey: .explanationKey
            )
        )
    }
}

public struct SpaceLedgerOwner: Codable, Sendable, Equatable {
    public let classificationID: ClassificationID
    public let snapshotID: SnapshotID
    public let relativePath: PersistedPath
    public let category: ArtifactCategory
    public let disposition: ReclaimDisposition
    public let logicalBytes: ByteCount?
    public let allocatedBytes: ByteCount?
    public let sources: [AccountingSource]

    public init(
        classificationID: ClassificationID,
        snapshotID: SnapshotID,
        relativePath: PersistedPath,
        category: ArtifactCategory,
        disposition: ReclaimDisposition,
        logicalBytes: ByteCount?,
        allocatedBytes: ByteCount?,
        sources: [AccountingSource]
    ) throws {
        guard (logicalBytes == nil) == (allocatedBytes == nil),
              !sources.isEmpty,
              sources.contains(where: { $0.kind == .surveyor }),
              sources.contains(where: { $0.kind == .classifier }),
              category != .protected || disposition == .protected
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.classificationID = classificationID
        self.snapshotID = snapshotID
        self.relativePath = relativePath
        self.category = category
        self.disposition = disposition
        self.logicalBytes = logicalBytes
        self.allocatedBytes = allocatedBytes
        self.sources = sources
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            classificationID: container.decode(
                ClassificationID.self,
                forKey: .classificationID
            ),
            snapshotID: container.decode(SnapshotID.self, forKey: .snapshotID),
            relativePath: container.decode(
                PersistedPath.self,
                forKey: .relativePath
            ),
            category: container.decode(
                ArtifactCategory.self,
                forKey: .category
            ),
            disposition: container.decode(
                ReclaimDisposition.self,
                forKey: .disposition
            ),
            logicalBytes: container.decodeIfPresent(
                ByteCount.self,
                forKey: .logicalBytes
            ),
            allocatedBytes: container.decodeIfPresent(
                ByteCount.self,
                forKey: .allocatedBytes
            ),
            sources: container.decode(
                [AccountingSource].self,
                forKey: .sources
            )
        )
    }
}

public struct SpaceLedgerCoverageGap: Codable, Sendable, Equatable {
    public let snapshotID: SnapshotID
    public let relativePath: PersistedPath
    public let status: MeasurementStatus
    public let observedAt: Date
    public let includedInUnknownResidual: Bool

    public init(
        snapshotID: SnapshotID,
        relativePath: PersistedPath,
        status: MeasurementStatus,
        observedAt: Date,
        includedInUnknownResidual: Bool
    ) throws {
        guard status != .measured,
              (status == .mountBoundary) != includedInUnknownResidual
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.snapshotID = snapshotID
        self.relativePath = relativePath
        self.status = status
        self.observedAt = observedAt
        self.includedInUnknownResidual = includedInUnknownResidual
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            snapshotID: container.decode(SnapshotID.self, forKey: .snapshotID),
            relativePath: container.decode(
                PersistedPath.self,
                forKey: .relativePath
            ),
            status: container.decode(
                MeasurementStatus.self,
                forKey: .status
            ),
            observedAt: container.decode(Date.self, forKey: .observedAt),
            includedInUnknownResidual: container.decode(
                Bool.self,
                forKey: .includedInUnknownResidual
            )
        )
    }
}

public struct SpaceLedger: Codable, Sendable, Equatable {
    public let schemaVersion: DomainSchemaVersion
    public let sessionID: ScanSessionID
    public let status: SpaceLedgerStatus
    public let volumeCapacityAtStart: SpaceLedgerMeasure
    public let volumeCapacity: SpaceLedgerMeasure
    public let known: SpaceLedgerMeasure
    public let knownLogical: SpaceLedgerMeasure
    public let unknown: SpaceLedgerMeasure
    public let unmeasurable: SpaceLedgerMeasure
    public let freeAtStart: SpaceLedgerMeasure
    public let free: SpaceLedgerMeasure
    public let observedUnclassified: SpaceLedgerMeasure
    public let observedUnclassifiedLogical: SpaceLedgerMeasure
    public let owners: [SpaceLedgerOwner]
    public let coverageGaps: [SpaceLedgerCoverageGap]
    public let unknownIncludesUnmeasurable: Bool
    public let freeSpaceDelta: SignedByteDelta?
    public let freeSpaceDeltaSources: [AccountingSource]
    public let freeSpaceDeltaFormulaKey: DomainToken
    public let freeSpaceDeltaExplanationKey: DomainToken
    public let caveats: [SpaceLedgerCaveat]

    public init(
        schemaVersion: DomainSchemaVersion = .v1,
        sessionID: ScanSessionID,
        status: SpaceLedgerStatus,
        volumeCapacityAtStart: SpaceLedgerMeasure,
        volumeCapacity: SpaceLedgerMeasure,
        known: SpaceLedgerMeasure,
        knownLogical: SpaceLedgerMeasure,
        unknown: SpaceLedgerMeasure,
        unmeasurable: SpaceLedgerMeasure,
        freeAtStart: SpaceLedgerMeasure,
        free: SpaceLedgerMeasure,
        observedUnclassified: SpaceLedgerMeasure,
        observedUnclassifiedLogical: SpaceLedgerMeasure,
        owners: [SpaceLedgerOwner],
        coverageGaps: [SpaceLedgerCoverageGap],
        unknownIncludesUnmeasurable: Bool,
        freeSpaceDelta: SignedByteDelta?,
        freeSpaceDeltaSources: [AccountingSource],
        freeSpaceDeltaFormulaKey: DomainToken,
        freeSpaceDeltaExplanationKey: DomainToken,
        caveats: [SpaceLedgerCaveat]
    ) throws {
        try requireDomainSchemaVersion(schemaVersion, expected: .v1)
        let ownerAllocated = try Self.sumOwners(
            owners,
            keyPath: \.allocatedBytes
        )
        let ownerLogical = try Self.sumOwners(
            owners,
            keyPath: \.logicalBytes
        )
        let expectedFreeDelta = Self.signedDelta(
            from: freeAtStart.bytes,
            to: free.bytes
        )
        let usedAtEnd = Self.usedBytes(
            capacity: volumeCapacity.bytes,
            free: free.bytes
        )
        let expectedUnknown: UInt64?
        if let usedAtEnd, ownerAllocated <= usedAtEnd {
            expectedUnknown = usedAtEnd - ownerAllocated
        } else {
            expectedUnknown = nil
        }
        let knownExceedsUsed = usedAtEnd.map {
            ownerAllocated > $0
        } ?? false
        let observedVolumeDrift = expectedFreeDelta?.value != 0
            || volumeCapacityAtStart.bytes != volumeCapacity.bytes
        let residualGapExists = coverageGaps.contains {
            $0.includedInUnknownResidual
        }
        let expectedUnknownExplanation = residualGapExists
            ? "accounting.unknown.includesUnmeasurable"
            : "accounting.unknown.volumeResidual"
        let statusIsValid: Bool
        switch status {
        case .reconciled:
            statusIsValid = coverageGaps.isEmpty
                && volumeCapacity.status == .measured
                && free.status == .measured
                && unknown.status == .measured
        case .partial:
            statusIsValid = !coverageGaps.isEmpty
                || volumeCapacity.status != .measured
                || free.status != .measured
                || unknown.status != .measured
        case .inconsistent:
            statusIsValid = caveats.contains(.knownExceedsVolumeUsed)
                && unknown.status == .unknown
                && unknown.bytes == nil
        }
        let unknownFormulaIsValid: Bool
        if status == .inconsistent {
            unknownFormulaIsValid =
                unknown.formulaKey.rawValue
                    == "accounting.formula.unknownInconsistent"
                && unknown.explanationKey.rawValue
                    == "accounting.unknown.knownExceedsUsed"
        } else if unknown.status == .measured {
            unknownFormulaIsValid =
                unknown.formulaKey.rawValue
                    == "accounting.formula.usedMinusKnown"
                && unknown.explanationKey.rawValue
                    == expectedUnknownExplanation
        } else {
            unknownFormulaIsValid =
                unknown.formulaKey.rawValue
                    == "accounting.formula.unknownUnavailable"
                && unknown.explanationKey.rawValue
                    == "accounting.unknown.volumeBaselineUnavailable"
        }
        let isVolumeSource: (AccountingSource) -> Bool = {
            $0.kind == .volumeResourceValues
                || $0.kind == .fileSystemAttributes
        }
        guard !volumeCapacity.sources.isEmpty,
              volumeCapacity.sources.allSatisfy(isVolumeSource),
              !volumeCapacityAtStart.sources.isEmpty,
              volumeCapacityAtStart.sources.allSatisfy(isVolumeSource),
              !free.sources.isEmpty,
              free.sources.allSatisfy(isVolumeSource),
              !freeAtStart.sources.isEmpty,
              freeAtStart.sources.allSatisfy(isVolumeSource),
              !freeSpaceDeltaSources.isEmpty,
              freeSpaceDeltaSources.allSatisfy(isVolumeSource),
              freeSpaceDeltaSources.count == 2,
              freeSpaceDeltaSources
                == [freeAtStart.sources[0], free.sources[0]],
              freeSpaceDelta == expectedFreeDelta,
              freeSpaceDeltaFormulaKey.rawValue
                == "accounting.formula.freeEndMinusStart",
              freeSpaceDeltaExplanationKey.rawValue
                == "accounting.free.deltaNotAttributed",
              volumeCapacityAtStart.formulaKey.rawValue
                == "accounting.formula.volumeCapacityAtStart",
              volumeCapacityAtStart.explanationKey.rawValue
                == "accounting.volume.startCapacity",
              volumeCapacity.formulaKey.rawValue
                == "accounting.formula.volumeCapacity",
              volumeCapacity.explanationKey.rawValue
                == "accounting.volume.capacity",
              freeAtStart.formulaKey.rawValue
                == "accounting.formula.freeAtStart",
              freeAtStart.explanationKey.rawValue
                == "accounting.free.startSystemObservation",
              free.formulaKey.rawValue == "accounting.formula.free",
              free.explanationKey.rawValue
                == "accounting.free.systemObservation",
              known.formulaKey.rawValue
                == "accounting.formula.knownOwners",
              known.explanationKey.rawValue
                == "accounting.known.classifiedOwners",
              knownLogical.formulaKey.rawValue
                == "accounting.formula.knownLogicalOwners",
              knownLogical.explanationKey.rawValue
                == "accounting.known.logicalOwners",
              (unknown.status == .measured
                  && unknown.bytes?.value == expectedUnknown)
                || (unknown.status == .unknown
                  && unknown.bytes == nil
                  && expectedUnknown == nil),
              observedUnclassified.formulaKey.rawValue
                == "accounting.formula.observedUnclassified",
              observedUnclassified.explanationKey.rawValue
                == "accounting.unknown.observedUnclassified",
              observedUnclassifiedLogical.formulaKey.rawValue
                == "accounting.formula.observedUnclassifiedLogical",
              observedUnclassifiedLogical.explanationKey.rawValue
                == "accounting.unknown.observedUnclassifiedLogical",
              unknownFormulaIsValid,
              statusIsValid,
              observedUnclassified.sources.allSatisfy({
                  $0.kind == .surveyor
              }),
              observedUnclassifiedLogical.sources.allSatisfy({
                  $0.kind == .surveyor
              }),
              (coverageGaps.isEmpty
                  && unmeasurable.sources.allSatisfy({
                      $0.kind == .surveyor
                  }))
                || (!coverageGaps.isEmpty
                  && unmeasurable.sources.allSatisfy({
                      $0.kind == .permissionGap
                  })),
              caveats.contains(.cloneAndCompressionNotAttributed),
              caveats.contains(.purgeableNotEstimated),
              caveats.contains(.volumeChangedDuringScan)
                == observedVolumeDrift,
              known.status == .measured,
              known.bytes?.value == ownerAllocated,
              knownLogical.status == .measured,
              knownLogical.bytes?.value == ownerLogical,
              observedUnclassified.status == .measured,
              observedUnclassifiedLogical.status == .measured,
              unknownIncludesUnmeasurable == residualGapExists,
              (coverageGaps.isEmpty
                  && unmeasurable.status == .measured
                  && unmeasurable.bytes?.value == 0)
                || (!coverageGaps.isEmpty
                  && unmeasurable.status == .unmeasurable
                  && unmeasurable.bytes == nil),
              Set(caveats).count == caveats.count,
              Set(owners.map(\.classificationID)).count == owners.count,
              Set(owners.map(\.snapshotID)).count == owners.count,
              Set(coverageGaps.map(\.snapshotID)).count == coverageGaps.count,
              (status == .inconsistent) == knownExceedsUsed,
              caveats.contains(.knownExceedsVolumeUsed) == knownExceedsUsed,
              (coverageGaps.isEmpty
                  && unmeasurable.formulaKey.rawValue
                    == "accounting.formula.noCoverageGaps"
                  && unmeasurable.explanationKey.rawValue
                    == "accounting.unmeasurable.none")
                || (!coverageGaps.isEmpty
                  && unmeasurable.formulaKey.rawValue
                    == "accounting.formula.coverageGapUnavailable"
                  && unmeasurable.explanationKey.rawValue
                    == "accounting.unmeasurable.permissionOrBoundary")
        else {
            throw DomainContractError.invalidMeasurement
        }
        self.schemaVersion = schemaVersion
        self.sessionID = sessionID
        self.status = status
        self.volumeCapacityAtStart = volumeCapacityAtStart
        self.volumeCapacity = volumeCapacity
        self.known = known
        self.knownLogical = knownLogical
        self.unknown = unknown
        self.unmeasurable = unmeasurable
        self.freeAtStart = freeAtStart
        self.free = free
        self.observedUnclassified = observedUnclassified
        self.observedUnclassifiedLogical = observedUnclassifiedLogical
        self.owners = owners
        self.coverageGaps = coverageGaps
        self.unknownIncludesUnmeasurable = unknownIncludesUnmeasurable
        self.freeSpaceDelta = freeSpaceDelta
        self.freeSpaceDeltaSources = freeSpaceDeltaSources
        self.freeSpaceDeltaFormulaKey = freeSpaceDeltaFormulaKey
        self.freeSpaceDeltaExplanationKey = freeSpaceDeltaExplanationKey
        self.caveats = caveats
    }

    private static func sumOwners(
        _ owners: [SpaceLedgerOwner],
        keyPath: KeyPath<SpaceLedgerOwner, ByteCount?>
    ) throws -> UInt64 {
        var total: UInt64 = 0
        for owner in owners where owner.category != .unknownLargeConsumers {
            let value = owner[keyPath: keyPath]?.value ?? 0
            let result = total.addingReportingOverflow(value)
            guard !result.overflow,
                  result.partialValue <= UInt64(Int64.max)
            else {
                throw DomainContractError.invalidMeasurement
            }
            total = result.partialValue
        }
        return total
    }

    private static func signedDelta(
        from start: ByteCount?,
        to end: ByteCount?
    ) -> SignedByteDelta? {
        guard let start, let end,
              let startValue = Int64(exactly: start.value),
              let endValue = Int64(exactly: end.value)
        else {
            return nil
        }
        return SignedByteDelta(endValue - startValue)
    }

    private static func usedBytes(
        capacity: ByteCount?,
        free: ByteCount?
    ) -> UInt64? {
        guard let capacity, let free, free <= capacity else {
            return nil
        }
        return capacity.value - free.value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(
                DomainSchemaVersion.self,
                forKey: .schemaVersion
            ),
            sessionID: container.decode(ScanSessionID.self, forKey: .sessionID),
            status: container.decode(SpaceLedgerStatus.self, forKey: .status),
            volumeCapacityAtStart: container.decode(
                SpaceLedgerMeasure.self,
                forKey: .volumeCapacityAtStart
            ),
            volumeCapacity: container.decode(
                SpaceLedgerMeasure.self,
                forKey: .volumeCapacity
            ),
            known: container.decode(SpaceLedgerMeasure.self, forKey: .known),
            knownLogical: container.decode(
                SpaceLedgerMeasure.self,
                forKey: .knownLogical
            ),
            unknown: container.decode(SpaceLedgerMeasure.self, forKey: .unknown),
            unmeasurable: container.decode(
                SpaceLedgerMeasure.self,
                forKey: .unmeasurable
            ),
            freeAtStart: container.decode(
                SpaceLedgerMeasure.self,
                forKey: .freeAtStart
            ),
            free: container.decode(SpaceLedgerMeasure.self, forKey: .free),
            observedUnclassified: container.decode(
                SpaceLedgerMeasure.self,
                forKey: .observedUnclassified
            ),
            observedUnclassifiedLogical: container.decode(
                SpaceLedgerMeasure.self,
                forKey: .observedUnclassifiedLogical
            ),
            owners: container.decode([SpaceLedgerOwner].self, forKey: .owners),
            coverageGaps: container.decode(
                [SpaceLedgerCoverageGap].self,
                forKey: .coverageGaps
            ),
            unknownIncludesUnmeasurable: container.decode(
                Bool.self,
                forKey: .unknownIncludesUnmeasurable
            ),
            freeSpaceDelta: container.decodeIfPresent(
                SignedByteDelta.self,
                forKey: .freeSpaceDelta
            ),
            freeSpaceDeltaSources: container.decode(
                [AccountingSource].self,
                forKey: .freeSpaceDeltaSources
            ),
            freeSpaceDeltaFormulaKey: container.decode(
                DomainToken.self,
                forKey: .freeSpaceDeltaFormulaKey
            ),
            freeSpaceDeltaExplanationKey: container.decode(
                DomainToken.self,
                forKey: .freeSpaceDeltaExplanationKey
            ),
            caveats: container.decode(
                [SpaceLedgerCaveat].self,
                forKey: .caveats
            )
        )
    }
}
