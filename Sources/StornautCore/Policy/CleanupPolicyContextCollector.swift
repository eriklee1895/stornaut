import Foundation

public protocol CleanupPolicyStoreReading: Sendable {
    func scanSession(id: ScanSessionID) async throws -> ScanSession?
    func cleanupPolicyRecords(
        plan: CleanupPlan,
        selectedItemIDs: [CleanupPlanItemID]
    ) async throws -> [CleanupPolicyStoreRecord]
}

extension EvidenceStore: CleanupPolicyStoreReading {}

public protocol CleanupPolicyRootLeasing: AnyObject, Sendable {}

extension SettingsPrimaryRootAccessLease: CleanupPolicyRootLeasing {}

public enum CleanupPolicyRootAccess: Sendable {
    case direct
    case securityScoped(any CleanupPolicyRootLeasing)
    case unavailable

    public var isAvailable: Bool {
        switch self {
        case .direct, .securityScoped:
            true
        case .unavailable:
            false
        }
    }
}

public struct CleanupPolicyRootObservation: Sendable {
    public let rootURL: URL
    public let access: CleanupPolicyRootAccess

    public init(
        rootURL: URL,
        access: CleanupPolicyRootAccess
    ) {
        self.rootURL = rootURL
        self.access = access
    }
}

public protocol CleanupPolicyRootObserving: Sendable {
    func observeRoot() async -> CleanupPolicyRootObservation
}

public protocol CleanupWorkflowAvailabilityObserving: Sendable {
    func snapshot() async -> CleanupWorkflowAvailabilitySnapshot
}

public struct FixedCleanupWorkflowAvailabilityObserver:
    CleanupWorkflowAvailabilityObserving
{
    private let value: CleanupWorkflowAvailabilitySnapshot

    public init(_ value: CleanupWorkflowAvailabilitySnapshot) {
        self.value = value
    }

    public func snapshot() async -> CleanupWorkflowAvailabilitySnapshot {
        value
    }
}

public enum CleanupPolicyCollectionError:
    String,
    Error,
    Sendable,
    Equatable
{
    case invalidSelection
    case planUnavailable
    case incompleteScan
    case storeTruthUnavailable
    case rootUnavailable
    case catalogUnavailable
    case itemTruthUnavailable
}

public struct CleanupPolicyCollectedContext: Sendable {
    public let policyContext: CleanupPolicyContext
    let rootAccess: CleanupPolicyRootAccess

    init(
        policyContext: CleanupPolicyContext,
        rootAccess: CleanupPolicyRootAccess
    ) {
        self.policyContext = policyContext
        self.rootAccess = rootAccess
    }
}

public enum CleanupPolicyCollectionOutcome: Sendable {
    case collected(CleanupPolicyCollectedContext)
    case blocked(
        error: CleanupPolicyCollectionError,
        affectedItemIDs: Set<CleanupPlanItemID>
    )

    public var context: CleanupPolicyContext? {
        guard case let .collected(collected) = self else {
            return nil
        }
        return collected.policyContext
    }

    var collected: CleanupPolicyCollectedContext? {
        guard case let .collected(collected) = self else {
            return nil
        }
        return collected
    }
}

public struct CleanupPolicyContextCollector: Sendable {
    public typealias IdentityReader = @Sendable (URL) -> FileIdentity?
    public typealias MountRootCheck = @Sendable (URL) -> Bool
    public typealias Clock = @Sendable () -> Date

    private let store: any CleanupPolicyStoreReading
    private let ruleCatalog: RuleCatalog?
    private let profileCatalog: ExecutionProfileCatalog?
    private let resolver: ExecutableEvidenceResolver
    private let rootObserver: any CleanupPolicyRootObserving
    private let workflowObserver:
        any CleanupWorkflowAvailabilityObserving
    private let identityReader: IdentityReader
    private let homeDirectoryURL: URL
    private let isMountRoot: MountRootCheck
    private let now: Clock

    init(
        store: any CleanupPolicyStoreReading,
        ruleCatalog: RuleCatalog?,
        profileCatalog: ExecutionProfileCatalog?,
        resolver: ExecutableEvidenceResolver,
        rootObserver: any CleanupPolicyRootObserving,
        workflowObserver: any CleanupWorkflowAvailabilityObserving,
        identityReader: @escaping IdentityReader = FileIdentity.read(at:),
        homeDirectoryURL: URL =
            FileManager.default.homeDirectoryForCurrentUser,
        isMountRoot: @escaping MountRootCheck =
            CanonicalPathPolicy.defaultMountRootCheck,
        now: @escaping Clock = Date.init
    ) {
        self.store = store
        self.ruleCatalog = ruleCatalog
        self.profileCatalog = profileCatalog
        self.resolver = resolver
        self.rootObserver = rootObserver
        self.workflowObserver = workflowObserver
        self.identityReader = identityReader
        self.homeDirectoryURL = homeDirectoryURL.standardizedFileURL
            .resolvingSymlinksInPath()
        self.isMountRoot = isMountRoot
        self.now = now
    }

    public init(
        store: EvidenceStore,
        rootObserver: any CleanupPolicyRootObserving,
        workflowObserver: any CleanupWorkflowAvailabilityObserving
    ) throws {
        let rules = try BuiltInRuleCatalog.load()
        self.init(
            store: store,
            ruleCatalog: rules,
            profileCatalog: try BuiltInExecutionProfileCatalog.load(
                ruleCatalog: rules
            ),
            resolver: ExecutableEvidenceResolver(),
            rootObserver: rootObserver,
            workflowObserver: workflowObserver
        )
    }

    public func collect(
        plan: CleanupPlan,
        selection: ReviewSelection
    ) async -> CleanupPolicyCollectionOutcome {
        let selectedIDs = selection.items.map(\.itemID)
        let affected = Set(selectedIDs)
        guard selection.planID == plan.id,
              !selectedIDs.isEmpty,
              selectedIDs.count <= ReviewSelection.maximumItemCount
        else {
            return .blocked(
                error: .invalidSelection,
                affectedItemIDs: affected
            )
        }
        guard let rules = ruleCatalog,
              let profiles = profileCatalog,
              profiles.ruleCatalogVersion == rules.catalogVersion
        else {
            return .blocked(
                error: .catalogUnavailable,
                affectedItemIDs: affected
            )
        }
        do {
            guard let session = try await store.scanSession(
                id: plan.scanSessionID
            ) else {
                return .blocked(
                    error: .planUnavailable,
                    affectedItemIDs: affected
                )
            }
            guard session.terminalState == .completed,
                  session.unfinishedScopes.isEmpty,
                  session.completedScopes.count == 1,
                  session.completedScopes.first?.id == plan.scanScopeID,
                  session.aggregate != nil
            else {
                return .blocked(
                    error: .incompleteScan,
                    affectedItemIDs: affected
                )
            }
            let records = try await store.cleanupPolicyRecords(
                plan: plan,
                selectedItemIDs: selectedIDs
            )
            guard records.count == selectedIDs.count else {
                return .blocked(
                    error: .storeTruthUnavailable,
                    affectedItemIDs: affected
                )
            }
            let root = await rootObserver.observeRoot()
            let workflow = await workflowObserver.snapshot()
            let capturedAt = now()
            let activityContext = await resolver.captureActivity(
                observedAt: capturedAt
            )
            let canonicalRoot = root.rootURL.standardizedFileURL
                .resolvingSymlinksInPath()
            let hasRootAccess = root.access.isAvailable
                && workflow.rootLeaseAvailable
            let rootIdentity = hasRootAccess
                ? identityReader(canonicalRoot)
                : nil
            let rulesByID = Dictionary(
                uniqueKeysWithValues: rules.rules.map { ($0.id, $0) }
            )
            var items: [CleanupPolicyItemContext] = []
            for record in records {
                guard let rawRuleID = record.planItem.ruleID,
                      let ruleID = RuleID(rawValue: rawRuleID.rawValue),
                      let rule = rulesByID[ruleID],
                      let profile = profiles.profile(ruleID: ruleID),
                      profile.id
                        == record.planItem.executionProfileID,
                      record.snapshot.sessionID == plan.scanSessionID,
                      record.snapshot.scopeID == plan.scanScopeID,
                      record.snapshot.id == record.planItem.snapshotID,
                      record.classification.id
                        == record.planItem.classificationID,
                      record.classification.snapshotID
                        == record.snapshot.id,
                      record.classification.ruleID == rawRuleID,
                      record.classification.catalogVersion
                        == plan.catalogVersion,
                      record.classification.category == rule.category,
                      record.classification.risk == rule.risk,
                      record.classification.confidence
                        == rule.confidenceRequirement,
                      record.classification.recovery == rule.recovery,
                      record.classification.producer == rule.producer,
                      record.classification.missingEvidenceKeys.isEmpty,
                      record.classification.requiredEvidenceKeys
                        == Array(Set(
                            rule.requiredEvidenceKeys
                                + rule.requiredActivityKeys
                        )).sorted(by: {
                            $0.rawValue < $1.rawValue
                        }),
                      record.classification.disposition
                        == rule.disposition,
                      profile.ruleID == rule.id,
                      profile.relativePath == rule.match.pathPattern,
                      profile.expectedKind == rule.match.expectedKind,
                      let expectedPath =
                        record.planItem.expectedRelativePath,
                      let expectedIdentity =
                        record.planItem.expectedIdentity,
                      let evidenceFingerprint =
                        record.planItem.evidenceFingerprint,
                      let activityFingerprint =
                        record.planItem.activityFingerprint,
                      let persistedPath = PersistedPath(
                          rawValue: record.snapshot.relativePath
                      ),
                      persistedPath == expectedPath,
                      record.snapshot.fileIdentity == expectedIdentity,
                      record.snapshot.logicalByteCount
                        == record.planItem.logicalBytes,
                      record.snapshot.allocatedByteCount
                        == record.planItem.allocatedBytes,
                      record.snapshot.kind == .directory,
                      record.snapshot.measurementStatus == .measured
                else {
                    return .blocked(
                        error: .itemTruthUnavailable,
                        affectedItemIDs: [record.planItem.id]
                    )
                }
                let candidateURL = canonicalRoot.appending(
                    path: expectedPath.rawValue,
                    directoryHint: .isDirectory
                ).standardizedFileURL
                let currentIdentity = hasRootAccess
                    ? identityReader(candidateURL)
                    : nil
                let currentResolution = try resolver.resolveReview(
                    snapshot: record.snapshot,
                    currentIdentity: currentIdentity,
                    rootIdentity: rootIdentity ?? expectedIdentity,
                    rule: rule,
                    profile: profile,
                    profileCatalogVersion: profiles.catalogVersion,
                    activityContext: activityContext,
                    evidenceID: { snapshotID, key in
                        deterministicPolicyEvidenceID(
                            snapshotID: snapshotID,
                            key: key
                        )
                    }
                )
                let currentClassification = try
                    DeterministicClassifier().classify(
                        snapshot: record.snapshot,
                        candidates: [rule],
                        satisfiedEvidenceKeys:
                            currentResolution.satisfiedEvidenceKeys,
                        activityObservations:
                            currentResolution.activityObservations,
                        classifiedAt: capturedAt,
                        classificationID: record.classification.id,
                        catalogVersion: rules.catalogVersion
                    )
                items.append(
                    try CleanupPolicyItemContext(
                        itemID: record.planItem.id,
                        snapshotID: record.snapshot.id,
                        classificationID: record.classification.id,
                        ruleID: rawRuleID,
                        executionProfileID: profile.id,
                        proposedAction: record.planItem.proposedAction,
                        persistedDisposition:
                            record.classification.disposition,
                        currentDisposition:
                            currentClassification.disposition,
                        expectedRelativePath: expectedPath,
                        currentRelativePath: persistedPath,
                        expectedIdentity: expectedIdentity,
                        currentIdentity: currentIdentity,
                        evidenceFingerprint: evidenceFingerprint,
                        currentEvidenceFingerprint:
                            currentResolution.evidenceFingerprint,
                        activityFingerprint: activityFingerprint,
                        currentActivityFingerprint:
                            currentResolution.activityFingerprint,
                        pathFacts: pathFacts(
                            candidateURL: candidateURL,
                            rootURL: canonicalRoot,
                            rootIdentity: rootIdentity,
                            currentIdentity: currentIdentity
                        ),
                        evidenceFacts: evidenceFacts(
                            persisted: record.evidence,
                            profile: profile,
                            session: session,
                            plan: plan,
                            capturedAt: capturedAt,
                            currentResolution: currentResolution
                        ),
                        activityFacts: activityFacts(
                            currentResolution.activityObservations
                        )
                    )
                )
            }
            return .collected(
                CleanupPolicyCollectedContext(
                    policyContext: try CleanupPolicyContext(
                    capturedAt: capturedAt,
                    planID: plan.id,
                    scanSessionID: plan.scanSessionID,
                    scanScopeID: plan.scanScopeID!,
                    scanIsTerminal: true,
                    planFingerprint: plan.planFingerprint!,
                    selectionGeneration: selection.generation,
                    selectionFingerprint: selection.fingerprint,
                    rootIdentity: rootIdentity,
                    catalogVersion: rules.catalogVersion,
                    executionProfileVersion: profiles.catalogVersion,
                    workflow: CleanupWorkflowAvailabilitySnapshot(
                        rootLeaseAvailable: hasRootAccess,
                        activeConflicts: workflow.activeConflicts
                    ),
                    items: items
                    ),
                    rootAccess: root.access
                )
            )
        } catch {
            return .blocked(
                error: .storeTruthUnavailable,
                affectedItemIDs: affected
            )
        }
    }

    private func pathFacts(
        candidateURL: URL,
        rootURL: URL,
        rootIdentity: FileIdentity?,
        currentIdentity: FileIdentity?
    ) -> CleanupPathPolicyFacts {
        let canonicalCandidate = candidateURL.resolvingSymlinksInPath()
        let canonicalRoot = rootURL.resolvingSymlinksInPath()
        let isRoot = policySamePath(canonicalCandidate, canonicalRoot)
        let isHome = policySamePath(
            canonicalCandidate,
            homeDirectoryURL
        )
        let sensitive: Bool
        if case .denied = SensitivePathDenylist(
            homeDirectoryURL: homeDirectoryURL
        ).evaluate(canonicalCandidate) {
            sensitive = true
        } else {
            sensitive = false
        }
        return CleanupPathPolicyFacts(
            isRoot: isRoot,
            isHome: isHome,
            isMountRoot: isMountRoot(canonicalCandidate),
            isSymbolicLink: currentIdentity?.isSymbolicLink ?? true,
            isSensitive: sensitive,
            isInsideRoot: policyPathContains(
                canonicalRoot,
                canonicalCandidate
            ) && !isRoot,
            ownerMatches: currentIdentity?.ownerUserID == getuid(),
            volumeMatches: currentIdentity?.device == rootIdentity?.device
        )
    }

    private func evidenceFacts(
        persisted: [EvidenceRecord],
        profile: ExecutionProfile,
        session: ScanSession,
        plan: CleanupPlan,
        capturedAt: Date,
        currentResolution: ExecutableEvidenceResolution
    ) -> CleanupEvidencePolicyFacts {
        let expected = Set(profile.resolverBindings.map {
            "execution.ah.nopii.\($0.resolver.rawValue).\($0.key.rawValue)"
        })
        let records = persisted.filter {
            $0.source.identifier.rawValue.hasPrefix("execution.")
        }
        guard records.count == expected.count,
              Set(records.map(\.source.identifier.rawValue)) == expected,
              records.allSatisfy({
                  $0.observedAt >= session.startedAt
                      && $0.observedAt <= plan.createdAt
              }),
              records.allSatisfy({ record in
                  guard let binding = profile.resolverBindings.first(
                      where: {
                          record.source.identifier.rawValue
                            == "execution.ah.nopii.\($0.resolver.rawValue).\($0.key.rawValue)"
                      }
                  ) else {
                      return false
                  }
                  return record.kind
                      == cleanupPolicyEvidenceKind(binding.resolver)
                      && record.source.kind
                      == cleanupPolicyEvidenceSourceKind(binding.resolver)
                      && record.summaryKey.rawValue
                      == "execution.\(binding.key.rawValue).satisfied"
              })
        else {
            return .missing
        }
        if records.contains(where: { $0.freshness == .expired })
            || capturedAt > plan.expiresAt
        {
            return .expired
        }
        if records.contains(where: { $0.freshness == .stale }) {
            return .stale
        }
        return currentResolution.isEligible
            ? .current
            : .unavailable
    }

    private func activityFacts(
        _ observations: [ActivityObservation]
    ) -> CleanupActivityPolicyFacts {
        guard observations.count == 1,
              let observation = observations.first
        else {
            return .unavailable
        }
        switch observation.state {
        case .satisfied:
            return .inactive
        case .contradicted:
            return .active
        case .unavailable:
            return .unavailable
        }
    }
}

private func cleanupPolicyEvidenceKind(
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

private func cleanupPolicyEvidenceSourceKind(
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

private func deterministicPolicyEvidenceID(
    snapshotID: SnapshotID,
    key: DomainToken
) -> EvidenceID {
    let fingerprint = cleanupFingerprint(
        prefix: "evidence-id",
        lines: [snapshotID.rawValue, key.rawValue]
    )
    return EvidenceID(
        rawValue: "evidence-\(fingerprint.rawValue)"
    )!
}

private func policyPathContains(_ root: URL, _ candidate: URL) -> Bool {
    let rootComponents = root.standardizedFileURL.pathComponents
    let candidateComponents = candidate.standardizedFileURL.pathComponents
    guard candidateComponents.count >= rootComponents.count else {
        return false
    }
    return zip(rootComponents, candidateComponents).allSatisfy(==)
}

private func policySamePath(_ lhs: URL, _ rhs: URL) -> Bool {
    lhs.standardizedFileURL.pathComponents
        == rhs.standardizedFileURL.pathComponents
}
