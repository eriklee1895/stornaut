import CryptoKit
import Foundation

protocol CleanupPlanBuildingStore: Sendable {
    func scanSession(id: ScanSessionID) async throws -> ScanSession?
    func quickScanSummary(
        sessionID: ScanSessionID
    ) async throws -> QuickScanStoreSummary
    func volumeBaseline(
        sessionID: ScanSessionID,
        scopeID: ScanScopeID
    ) async throws -> VolumeBaseline?
    func pathSnapshots(
        sessionID: ScanSessionID,
        after cursor: PathSnapshotCursor?,
        limit: Int
    ) async throws -> PathSnapshotCursorPage
    func cleanupPlanningPage(
        sessionID: ScanSessionID,
        after cursor: CleanupPlanningCursor?,
        limit: Int
    ) async throws -> CleanupPlanningPage
    func evidence(
        sessionID: ScanSessionID,
        limit: Int,
        offset: Int
    ) async throws -> StorePage<EvidenceRecord>
    func saveCleanupPlan(_ plan: CleanupPlan) async throws
}

extension EvidenceStore: CleanupPlanBuildingStore {}

public enum CleanupPlanBuildOutcome: Sendable, Equatable {
    case planReady(CleanupPlan, ReviewProjection)
    case empty(ReviewProjection)
    case scanAgain([DomainToken])
    case unavailable([DomainToken])
}

private enum CleanupPlanBuildError: Error {
    case corruptTruth
}

public struct CleanupPlanBuilder: Sendable {
    public typealias PlanIDSource = @Sendable () -> CleanupPlanID
    public typealias ItemIDSource = @Sendable (
        SnapshotID,
        ClassificationID
    ) -> CleanupPlanItemID
    public typealias EvidenceIDSource =
        ExecutableEvidenceResolver.EvidenceIDSource

    private static let pageSize = 100
    private static let evidenceLifetime: TimeInterval = 7 * 86_400

    private let store: any CleanupPlanBuildingStore
    private let ruleCatalog: RuleCatalog
    private let executionProfileCatalog: ExecutionProfileCatalog
    private let evidenceResolver: ExecutableEvidenceResolver
    private let now: @Sendable () -> Date
    private let planID: PlanIDSource
    private let itemID: ItemIDSource
    private let evidenceID: EvidenceIDSource

    init(
        store: any CleanupPlanBuildingStore,
        ruleCatalog: RuleCatalog,
        executionProfileCatalog: ExecutionProfileCatalog,
        evidenceResolver: ExecutableEvidenceResolver,
        now: @escaping @Sendable () -> Date = Date.init,
        planID: @escaping PlanIDSource = CleanupPlanID.init,
        itemID: @escaping ItemIDSource = { _, _ in CleanupPlanItemID() },
        evidenceID: @escaping EvidenceIDSource = { _, _ in EvidenceID() }
    ) {
        self.store = store
        self.ruleCatalog = ruleCatalog
        self.executionProfileCatalog = executionProfileCatalog
        self.evidenceResolver = evidenceResolver
        self.now = now
        self.planID = planID
        self.itemID = itemID
        self.evidenceID = evidenceID
    }

    public init(store: EvidenceStore) throws {
        let rules = try BuiltInRuleCatalog.load()
        self.init(
            store: store,
            ruleCatalog: rules,
            executionProfileCatalog:
                try BuiltInExecutionProfileCatalog.load(
                    ruleCatalog: rules
                ),
            evidenceResolver: ExecutableEvidenceResolver()
        )
    }

#if DEBUG
    public static func phaseCTrashDiagnostic(
        store: EvidenceStore,
        resolver: ExecutableEvidenceResolver
    ) throws -> CleanupPlanBuilder {
        let rules = try BuiltInRuleCatalog.load()
        return try CleanupPlanBuilder(
            store: store,
            ruleCatalog: rules,
            executionProfileCatalog:
                BuiltInExecutionProfileCatalog.load(
                    ruleCatalog: rules
                ),
            evidenceResolver: resolver
        )
    }
#endif

    public func build(
        sessionID: ScanSessionID,
        rootURL: URL
    ) async -> CleanupPlanBuildOutcome {
        do {
            return try await buildValidated(
                sessionID: sessionID,
                rootURL: rootURL.standardizedFileURL
            )
        } catch is CancellationError {
            return .unavailable([
                token("review.unavailable.cancelled"),
            ])
        } catch CleanupPlanBuildError.corruptTruth {
            return .scanAgain([
                token("review.scan-again.corrupt-truth"),
            ])
        } catch {
            return .unavailable([
                token("review.unavailable.persisted-truth"),
            ])
        }
    }

    private func buildValidated(
        sessionID: ScanSessionID,
        rootURL: URL
    ) async throws -> CleanupPlanBuildOutcome {
        guard executionProfileCatalog.ruleCatalogVersion
                == ruleCatalog.catalogVersion
        else {
            return .scanAgain([
                token("review.scan-again.catalog-changed"),
            ])
        }
        guard let session = try await store.scanSession(id: sessionID),
              session.terminalState == .completed,
              session.completedScopes.count == 1,
              session.unfinishedScopes.isEmpty,
              session.aggregate != nil,
              let scope = session.completedScopes.first
        else {
            return .scanAgain([
                token("review.scan-again.incomplete-scan"),
            ])
        }
        let createdAt = now()
        let evidenceExpiry = session.finishedAt.addingTimeInterval(
            Self.evidenceLifetime
        )
        guard createdAt <= evidenceExpiry else {
            return .scanAgain([
                token("review.scan-again.evidence-expired"),
            ])
        }
        guard let baseline = try await store.volumeBaseline(
            sessionID: sessionID,
            scopeID: scope.id
        ), baseline.rootPath == scope.rootPath,
           baseline.rootPath.rawValue == rootURL.path,
           FileIdentity.read(at: rootURL) == baseline.rootIdentity
        else {
            return .scanAgain([
                token("review.scan-again.root-changed"),
            ])
        }
        let summary = try await store.quickScanSummary(
            sessionID: sessionID
        )
        guard try await validateRetainedSnapshots(
            sessionID: sessionID,
            expectedCount: summary.retainedSnapshotCount
        ) else {
            return .scanAgain([
                token("review.scan-again.count-mismatch"),
            ])
        }
        let rulesByID = Dictionary(
            uniqueKeysWithValues: ruleCatalog.rules.map {
                ($0.id, $0)
            }
        )
        let activityContext = await evidenceResolver.captureActivity(
            observedAt: createdAt
        )
        var cursor: CleanupPlanningCursor?
        var physicalRowCount = 0
        var seenSnapshots = Set<SnapshotID>()
        var seenClassifications = Set<ClassificationID>()
        var seenProfileRuleIDs = Set<RuleID>()
        var seenProfilePaths = Set<String>()
        var candidateRecords: [CleanupPlanningRecord] = []
        var fallbackProjectionRows: [ReviewProjectionRow] = []
        var profileProjectionRows:
            [ClassificationID: ReviewProjectionRow] = [:]
        var totalProjectionRows = 0
        var nonProfileCounts = try ReviewProjectionCounts(
            executableReady: 0,
            executableReview: 0,
            noExecutionProfile: 0,
            persistedDispositionBlocked: 0,
            currentEvidenceBlocked: 0
        )
        while true {
            try Task.checkCancellation()
            let page = try await store.cleanupPlanningPage(
                sessionID: sessionID,
                after: cursor,
                limit: Self.pageSize
            )
            physicalRowCount += page.rowCount
            guard page.corruptRecordIDs.isEmpty else {
                return .scanAgain([
                    token("review.scan-again.corrupt-truth"),
                ])
            }
            for record in page.records {
                guard seenSnapshots.insert(record.snapshot.id).inserted,
                      seenClassifications.insert(
                          record.classification.id
                      ).inserted,
                      record.snapshot.scopeID == scope.id,
                      record.classification.snapshotID
                        == record.snapshot.id
                else {
                    return .scanAgain([
                        token("review.scan-again.duplicate-truth"),
                    ])
                }
                guard record.classification.catalogVersion
                        == ruleCatalog.catalogVersion
                else {
                    return .scanAgain([
                        token("review.scan-again.catalog-changed"),
                    ])
                }
                let profile = record.classification.ruleID.flatMap {
                    RuleID(rawValue: $0.rawValue)
                }.flatMap(executionProfileCatalog.profile(ruleID:))
                if let profile {
                    guard seenProfileRuleIDs.insert(profile.ruleID).inserted,
                          seenProfilePaths.insert(
                              record.snapshot.relativePath
                          ).inserted
                    else {
                        return .scanAgain([
                            token("review.scan-again.duplicate-truth"),
                        ])
                    }
                    candidateRecords.append(record)
                    profileProjectionRows[record.classification.id] =
                        basicProjectionRow(
                            record: record,
                            hasProfile: true
                        )
                } else if fallbackProjectionRows.count
                    < ReviewProjection.maximumRows
                {
                    fallbackProjectionRows.append(
                        basicProjectionRow(
                            record: record,
                            hasProfile: false
                        )
                    )
                }
                if profile == nil {
                    nonProfileCounts = try incrementNonProfileCount(
                        nonProfileCounts,
                        disposition: record.classification.disposition
                    )
                }
                totalProjectionRows += 1
            }
            if page.rowCount < Self.pageSize {
                break
            }
            guard let next = page.nextCursor, next != cursor else {
                throw DomainContractError.invalidMeasurement
            }
            cursor = next
        }
        guard physicalRowCount == summary.classificationCount,
              seenClassifications.count == summary.classificationCount,
              seenSnapshots.count == summary.classificationCount
        else {
            return .scanAgain([
                token("review.scan-again.count-mismatch"),
            ])
        }
        let scanEvidence = try await loadAndValidateEvidence(
            sessionID: sessionID,
            expectedCount: summary.evidenceCount,
            candidateSnapshotIDs: Set(
                candidateRecords.map(\.snapshot.id)
            ),
            startedAt: session.startedAt,
            observedBefore: createdAt
        )
        var planItems: [CleanupPlanItem] = []
        var updatedRows = profileProjectionRows
        for record in candidateRecords {
            guard let rawRuleID = record.classification.ruleID,
                  let ruleID = RuleID(rawValue: rawRuleID.rawValue),
                  let rule = rulesByID[ruleID],
                  let profile = executionProfileCatalog.profile(
                      ruleID: ruleID
                  )
            else {
                continue
            }
            guard record.classification.disposition
                    == .readyToReclaim
                    || record.classification.disposition
                        == .reviewRecommended
            else {
                updatedRows[record.classification.id] =
                    basicProjectionRow(
                        record: record,
                        hasProfile: true
                    )
                continue
            }
            guard hasCompleteScanEvidence(
                scanEvidence[record.snapshot.id, default: []],
                profile: profile
            ) else {
                updatedRows[record.classification.id] =
                    blockedProjectionRow(
                        record: record,
                        currentDisposition: .unknown,
                        reason: "review.current.scan-evidence-incomplete"
                    )
                continue
            }
            let resolution = try evidenceResolver.resolveReview(
                snapshot: record.snapshot,
                rootURL: rootURL,
                rootIdentity: baseline.rootIdentity,
                rule: rule,
                profile: profile,
                profileCatalogVersion:
                    executionProfileCatalog.catalogVersion,
                activityContext: activityContext,
                evidenceID: evidenceID
            )
            let currentClassification = try DeterministicClassifier().classify(
                snapshot: record.snapshot,
                candidates: [rule],
                satisfiedEvidenceKeys:
                    resolution.satisfiedEvidenceKeys,
                activityObservations:
                    resolution.activityObservations,
                classifiedAt: createdAt,
                classificationID: record.classification.id,
                catalogVersion: ruleCatalog.catalogVersion
            )
            guard resolution.isEligible,
                  currentClassification.disposition
                    == .readyToReclaim
                    || currentClassification.disposition
                        == .reviewRecommended,
                  let identity = record.snapshot.fileIdentity,
                  let logicalBytes = record.snapshot.logicalByteCount,
                  let allocatedBytes = record.snapshot.allocatedByteCount,
                  let relativePath = PersistedPath(
                      rawValue: record.snapshot.relativePath
                  )
            else {
                updatedRows[record.classification.id] =
                    blockedProjectionRow(
                        record: record,
                        currentDisposition:
                            currentClassification.disposition,
                        reason: "review.current.evidence-blocked"
                    )
                continue
            }
            let item = try CleanupPlanItem(
                id: itemID(
                    record.snapshot.id,
                    record.classification.id
                ),
                snapshotID: record.snapshot.id,
                classificationID: record.classification.id,
                ruleID: rawRuleID,
                executionProfileID: profile.id,
                proposedAction: .moveToTrash,
                expectedRelativePath: relativePath,
                expectedIdentity: identity,
                logicalBytes: logicalBytes,
                allocatedBytes: allocatedBytes,
                evidenceFingerprint: resolution.evidenceFingerprint,
                activityFingerprint: resolution.activityFingerprint
            )
            planItems.append(item)
            updatedRows[record.classification.id] =
                ReviewProjectionRow(
                    snapshotID: record.snapshot.id,
                    classificationID: record.classification.id,
                    relativePath: record.snapshot.relativePath,
                    ruleID: rawRuleID,
                    persistedDisposition:
                        record.classification.disposition,
                    currentDisposition:
                        currentClassification.disposition,
                    eligibility: .executable,
                    suggestedDefault:
                        profile.defaultSuggestion
                            == .readyWhenEligible
                            && currentClassification.disposition
                                == .readyToReclaim,
                    reasonKeys: [
                        token("review.current.executable"),
                    ]
                )
        }
        let requiredRows = updatedRows.values.sorted(by: reviewRowOrder)
        let counts = try projectionCounts(
            nonProfileCounts: nonProfileCounts,
            profileRows: requiredRows
        )
        guard counts.total == totalProjectionRows else {
            throw CleanupPlanBuildError.corruptTruth
        }
        let requiredIDs = Set(requiredRows.map(\.classificationID))
        let remainingCapacity = max(
            0,
            ReviewProjection.maximumRows - requiredRows.count
        )
        let rows = Array(
            (
                requiredRows
                    + fallbackProjectionRows.filter {
                        !requiredIDs.contains($0.classificationID)
                    }.prefix(remainingCapacity)
            ).sorted(by: reviewRowOrder)
        )
        let sortedItems = planItems.sorted {
            let lhs = $0.expectedRelativePath?.rawValue ?? ""
            let rhs = $1.expectedRelativePath?.rawValue ?? ""
            if lhs != rhs {
                return lhs < rhs
            }
            if $0.ruleID?.rawValue != $1.ruleID?.rawValue {
                return ($0.ruleID?.rawValue ?? "")
                    < ($1.ruleID?.rawValue ?? "")
            }
            if $0.snapshotID != $1.snapshotID {
                return $0.snapshotID.rawValue < $1.snapshotID.rawValue
            }
            return $0.classificationID.rawValue
                < $1.classificationID.rawValue
        }
        guard !sortedItems.isEmpty else {
            return .empty(
                try ReviewProjection(
                    sessionID: sessionID,
                    planID: nil,
                    rows: rows,
                    totalRowCount: totalProjectionRows,
                    counts: counts
                )
            )
        }
        let newPlanID = planID()
        let plan = try CleanupPlan(
            id: newPlanID,
            scanSessionID: sessionID,
            scanScopeID: scope.id,
            primaryRootIdentity: baseline.rootIdentity,
            catalogVersion: ruleCatalog.catalogVersion,
            executionProfileVersion:
                executionProfileCatalog.catalogVersion,
            planFingerprint: planFingerprint(
                sessionID: sessionID,
                scopeID: scope.id,
                rootIdentity: baseline.rootIdentity,
                catalogVersion: ruleCatalog.catalogVersion,
                profileVersion:
                    executionProfileCatalog.catalogVersion,
                items: sortedItems
            ),
            createdAt: createdAt,
            expiresAt: min(
                createdAt.addingTimeInterval(Self.evidenceLifetime),
                evidenceExpiry
            ),
            items: sortedItems
        )
        let canonicalPlan = try DomainJSON.decode(
            CleanupPlan.self,
            from: DomainJSON.encode(plan)
        )
        try await store.saveCleanupPlan(canonicalPlan)
        return .planReady(
            canonicalPlan,
            try ReviewProjection(
                sessionID: sessionID,
                planID: newPlanID,
                rows: rows,
                totalRowCount: totalProjectionRows,
                counts: counts
            )
        )
    }

    private func validateRetainedSnapshots(
        sessionID: ScanSessionID,
        expectedCount: Int
    ) async throws -> Bool {
        var cursor: PathSnapshotCursor?
        var physicalCount = 0
        while true {
            let page = try await store.pathSnapshots(
                sessionID: sessionID,
                after: cursor,
                limit: Self.pageSize
            )
            guard page.page.corruptRecordIDs.isEmpty else {
                throw CleanupPlanBuildError.corruptTruth
            }
            physicalCount += page.rowCount
            if page.rowCount < Self.pageSize {
                break
            }
            guard let next = page.nextCursor, next != cursor else {
                return false
            }
            cursor = next
        }
        return physicalCount == expectedCount
    }

    private func loadAndValidateEvidence(
        sessionID: ScanSessionID,
        expectedCount: Int,
        candidateSnapshotIDs: Set<SnapshotID>,
        startedAt: Date,
        observedBefore: Date
    ) async throws -> [SnapshotID: [EvidenceRecord]] {
        var offset = 0
        var physicalCount = 0
        var recordsBySnapshot: [SnapshotID: [EvidenceRecord]] = [:]
        var seen = Set<EvidenceID>()
        while true {
            let page = try await store.evidence(
                sessionID: sessionID,
                limit: Self.pageSize,
                offset: offset
            )
            let rowCount = page.records.count
                + page.corruptRecordIDs.count
            physicalCount += rowCount
            guard page.corruptRecordIDs.isEmpty else {
                throw CleanupPlanBuildError.corruptTruth
            }
            for record in page.records {
                guard seen.insert(record.id).inserted else {
                    throw CleanupPlanBuildError.corruptTruth
                }
                if candidateSnapshotIDs.contains(record.targetID) {
                    guard record.observedAt >= startedAt,
                          record.observedAt <= observedBefore
                    else {
                        throw CleanupPlanBuildError.corruptTruth
                    }
                    recordsBySnapshot[
                        record.targetID,
                        default: []
                    ].append(record)
                }
            }
            if rowCount < Self.pageSize {
                break
            }
            offset += rowCount
        }
        guard physicalCount == expectedCount,
              seen.count == expectedCount
        else {
            throw CleanupPlanBuildError.corruptTruth
        }
        return recordsBySnapshot
    }

    private func hasCompleteScanEvidence(
        _ records: [EvidenceRecord],
        profile: ExecutionProfile
    ) -> Bool {
        let expectedIdentifiers = Set(
            profile.resolverBindings.map {
                "execution.ah.nopii.\($0.resolver.rawValue).\($0.key.rawValue)"
            }
        )
        let executionRecords = records.filter {
            $0.source.identifier.rawValue.hasPrefix("execution.")
        }
        return executionRecords.count == expectedIdentifiers.count
            && executionRecords.allSatisfy { $0.freshness == .current }
            && Set(executionRecords.map(\.source.identifier.rawValue))
                == expectedIdentifiers
            && executionRecords.allSatisfy { record in
                guard let binding = profile.resolverBindings.first(where: {
                    record.source.identifier.rawValue
                        == "execution.ah.nopii.\($0.resolver.rawValue).\($0.key.rawValue)"
                }) else {
                    return false
                }
                return record.kind == expectedEvidenceKind(binding.resolver)
                    && record.source.kind
                        == expectedEvidenceSourceKind(binding.resolver)
                    && evidenceResolver.acceptsPersistedSummary(
                        record.summaryKey,
                        binding: binding
                    )
            }
    }

    private func basicProjectionRow(
        record: CleanupPlanningRecord,
        hasProfile: Bool
    ) -> ReviewProjectionRow {
        let disposition = record.classification.disposition
        let eligibility: ReviewEligibility
        let reason: String
        if disposition == .protected || disposition == .unknown {
            eligibility = .persistedDispositionBlocked
            reason = "review.non-executable.persisted-disposition"
        } else if !hasProfile {
            eligibility = .noExecutionProfile
            reason = "review.non-executable.no-profile"
        } else {
            eligibility = .currentEvidenceBlocked
            reason = "review.current.pending"
        }
        return ReviewProjectionRow(
            snapshotID: record.snapshot.id,
            classificationID: record.classification.id,
            relativePath: record.snapshot.relativePath,
            ruleID: record.classification.ruleID,
            persistedDisposition: disposition,
            currentDisposition: disposition,
            eligibility: eligibility,
            suggestedDefault: false,
            reasonKeys: [token(reason)]
        )
    }

    private func blockedProjectionRow(
        record: CleanupPlanningRecord,
        currentDisposition: ReclaimDisposition,
        reason: String
    ) -> ReviewProjectionRow {
        ReviewProjectionRow(
            snapshotID: record.snapshot.id,
            classificationID: record.classification.id,
            relativePath: record.snapshot.relativePath,
            ruleID: record.classification.ruleID,
            persistedDisposition: record.classification.disposition,
            currentDisposition: currentDisposition,
            eligibility: .currentEvidenceBlocked,
            suggestedDefault: false,
            reasonKeys: [token(reason)]
        )
    }
}

private func incrementNonProfileCount(
    _ counts: ReviewProjectionCounts,
    disposition: ReclaimDisposition
) throws -> ReviewProjectionCounts {
    try ReviewProjectionCounts(
        executableReady: counts.executableReady,
        executableReview: counts.executableReview,
        noExecutionProfile: counts.noExecutionProfile
            + (
                disposition == .readyToReclaim
                    || disposition == .reviewRecommended ? 1 : 0
            ),
        persistedDispositionBlocked:
            counts.persistedDispositionBlocked
                + (
                    disposition == .protected
                        || disposition == .unknown ? 1 : 0
                ),
        currentEvidenceBlocked: counts.currentEvidenceBlocked
    )
}

private func projectionCounts(
    nonProfileCounts: ReviewProjectionCounts,
    profileRows: [ReviewProjectionRow]
) throws -> ReviewProjectionCounts {
    var ready = nonProfileCounts.executableReady
    var review = nonProfileCounts.executableReview
    var noProfile = nonProfileCounts.noExecutionProfile
    var persistedBlocked = nonProfileCounts.persistedDispositionBlocked
    var currentBlocked = nonProfileCounts.currentEvidenceBlocked
    for row in profileRows {
        switch row.eligibility {
        case .executable:
            if row.currentDisposition == .readyToReclaim {
                ready += 1
            } else if row.currentDisposition == .reviewRecommended {
                review += 1
            } else {
                throw CleanupPlanBuildError.corruptTruth
            }
        case .noExecutionProfile:
            noProfile += 1
        case .persistedDispositionBlocked:
            persistedBlocked += 1
        case .currentEvidenceBlocked:
            currentBlocked += 1
        }
    }
    return try ReviewProjectionCounts(
        executableReady: ready,
        executableReview: review,
        noExecutionProfile: noProfile,
        persistedDispositionBlocked: persistedBlocked,
        currentEvidenceBlocked: currentBlocked
    )
}

private func reviewRowOrder(
    _ lhs: ReviewProjectionRow,
    _ rhs: ReviewProjectionRow
) -> Bool {
    if lhs.relativePath != rhs.relativePath {
        return lhs.relativePath < rhs.relativePath
    }
    return lhs.classificationID.rawValue
        < rhs.classificationID.rawValue
}

private func planFingerprint(
    sessionID: ScanSessionID,
    scopeID: ScanScopeID,
    rootIdentity: FileIdentity,
    catalogVersion: DomainToken,
    profileVersion: DomainToken,
    items: [CleanupPlanItem]
) -> DomainToken {
    var lines = [
        sessionID.rawValue,
        scopeID.rawValue,
        identityFingerprintLine(rootIdentity),
        catalogVersion.rawValue,
        profileVersion.rawValue,
    ]
    lines.append(contentsOf: items.map {
        [
            $0.snapshotID.rawValue,
            $0.classificationID.rawValue,
            $0.ruleID?.rawValue ?? "",
            $0.executionProfileID?.rawValue ?? "",
            $0.expectedRelativePath?.rawValue ?? "",
            identityFingerprintLine($0.expectedIdentity),
            String($0.logicalBytes?.value ?? 0),
            String($0.allocatedBytes?.value ?? 0),
            $0.evidenceFingerprint?.rawValue ?? "",
            $0.activityFingerprint?.rawValue ?? "",
        ].joined(separator: "|")
    })
    let hash = SHA256.hash(
        data: Data(lines.joined(separator: "\n").utf8)
    ).map { String(format: "%02x", $0) }.joined()
    return DomainToken(rawValue: "plan.\(hash)")!
}

private func token(_ rawValue: String) -> DomainToken {
    DomainToken(rawValue: rawValue)!
}

private func expectedEvidenceKind(
    _ resolver: ExecutionEvidenceResolver
) -> EvidenceKind {
    switch resolver {
    case .compilerAttested:
        .rule
    case .currentFilesystem:
        .producer
    case .currentActivity:
        .activity
    }
}

private func expectedEvidenceSourceKind(
    _ resolver: ExecutionEvidenceResolver
) -> EvidenceSourceKind {
    switch resolver {
    case .compilerAttested:
        .rule
    case .currentFilesystem:
        .surveyor
    case .currentActivity:
        .activityProvider
    }
}

private func identityFingerprintLine(_ identity: FileIdentity?) -> String {
    guard let identity else {
        return ""
    }
    return [
        String(identity.device),
        String(identity.inode),
        String(identity.mode),
        String(identity.ownerUserID),
        String(identity.ownerGroupID),
        String(identity.linkCount),
        String(identity.size),
        String(identity.allocatedBytes),
        String(identity.modificationSeconds),
        String(identity.modificationNanoseconds),
    ].joined(separator: ":")
}
