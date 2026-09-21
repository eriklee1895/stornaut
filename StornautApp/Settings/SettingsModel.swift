import Foundation
import StornautCore

enum SettingsPresentation: String, Sendable, Equatable {
    case loading
    case loaded
    case error
}

enum SettingsRuntimeGateStatus: String, Sendable, Equatable {
    case verified
    case blocked
    case unverified
}

enum SettingsRuntimeGateReason: String, Sendable, Equatable {
    case codexUnavailable
    case codexCheckFailed
    case syntaxUnsupported
    case syntaxUnverified
    case evidenceStale
    case evidenceFailed
    case evidenceUnverified
}

typealias SettingsRuntimeDisclosureItem = DeepDiveDisclosureSemanticItem

extension DeepDiveDisclosureSemanticItem {
    var localizationKey: String {
        switch self {
        case .authorizedScopeDirectRead:
            "settings.codex.disclosure.directRead"
        case .modelContextEvidence:
            "settings.codex.disclosure.modelContext"
        case .publicInternetServices:
            "settings.codex.disclosure.publicInternet"
        case .autonomousReadOnlyTools:
            "settings.codex.disclosure.autonomousTools"
        case .aggregateConsent:
            "settings.codex.disclosure.aggregateConsent"
        case .noWriteCleanupPolicyAuthorizationExecutor:
            "settings.codex.disclosure.noWriteAuthority"
        case .cleanupRejoinAndReauthorization:
            "settings.codex.disclosure.swiftRevalidation"
        case .noCompletenessGuarantee:
            "settings.codex.disclosure.noGuarantee"
        case .quickScanRemainsLocal:
            "settings.codex.disclosure.quickScanLocal"
        }
    }

    var systemImage: String {
        switch self {
        case .authorizedScopeDirectRead:
            "doc.text.magnifyingglass"
        case .modelContextEvidence:
            "brain.head.profile"
        case .publicInternetServices:
            "network"
        case .autonomousReadOnlyTools:
            "wrench.and.screwdriver"
        case .aggregateConsent:
            "checkmark.circle"
        case .noWriteCleanupPolicyAuthorizationExecutor:
            "lock.shield"
        case .cleanupRejoinAndReauthorization:
            "checkmark.seal"
        case .noCompletenessGuarantee:
            "questionmark.circle"
        case .quickScanRemainsLocal:
            "internaldrive"
        }
    }
}

struct SettingsRuntimeDisclosure: Sendable, Equatable {
    let version: DomainToken
    let items: [SettingsRuntimeDisclosureItem]
    let readiness: DeepDiveDisclosureReadiness
    let canReview: Bool
    let canAccept: Bool
    let canForget: Bool
}

struct SettingsDeepDiveModel: Sendable, Equatable {
    let projection: DeepDiveAvailabilityProjection

    var dimensions: DeepDiveAdmissionDimensions {
        projection.dimensions
    }

    var aggregate: DeepDiveAggregateAvailability {
        projection.aggregate
    }

    var safetyRuntimeVerified: Bool {
        projection.dimensions.runtime == .admitted
    }

    var productFlowAdmissionPending: Bool { true }

    var normalProductStartEnabled: Bool {
        projection.normalProductStartEnabled
    }

    var quickScanAvailable: Bool {
        projection.quickScanAvailable
    }
}

enum SettingsDeepDiveRepairAction: String, Sendable, Equatable {
    case runQuickScan
    case reviewDisclosure
    case checkCodexAgain
    case runSafetyCheck
    case chooseBudget
}

enum SettingsDeepDiveRepairActions {
    static func primary(
        for availability: DeepDiveAggregateAvailability
    ) -> SettingsDeepDiveRepairAction? {
        switch availability {
        case .needsBaselineScan:
            .runQuickScan
        case .needsDisclosure, .disclosureDeclined:
            .reviewDisclosure
        case .codexUnavailable:
            .checkCodexAgain
        case .runtimeBlocked, .runtimeStale:
            .runSafetyCheck
        case .invalidBudget:
            .chooseBudget
        case .available, .dependenciesUnavailable, .workflowBusy:
            nil
        }
    }
}

enum SettingsKnowledgeStatus: String, Sendable, Equatable {
    case current
    case stale
    case contextUnavailable
}

struct GeneralSettingsModel: Sendable, Equatable {
    let language: SettingsLanguage
    let appearance: SettingsAppearance
    let diskAccess: SettingsDiskAccessStatus
    let codexInstallation: SettingsCodexAvailability
    let runtimeGate: SettingsRuntimeGateStatus
    let deepDiveAvailability: DeepDiveAggregateAvailability
    let runsOnDemandOnly: Bool

    var deepDiveAvailabilityLocalizationKey: String {
        "settings.status.deepDive.implementationUnavailable"
    }
}

struct ScanningSettingsModel: Sendable, Equatable {
    let primaryRoot: SettingsPrimaryRootStatus?
    let exclusions: [ScanExclusion]
    let canAddExclusion: Bool
    let primaryRootIsSingleScope: Bool
    let protectedLocationsAreEditable: Bool
    let catalogRuleCount: Int
}

struct PermissionsSettingsModel: Sendable, Equatable {
    let diskAccess: SettingsDiskAccessStatus
    let primaryRoot: SettingsPrimaryRootStatus?
    let coverageGapCount: Int
    let quickScanRemainsAvailable: Bool
    let hasInAppFullDiskAccessToggle: Bool
}

struct CodexSettingsModel: Sendable, Equatable {
    let installationStatus: SettingsCodexAvailability
    let syntaxStatus: SettingsCodexSyntaxStatus
    let executablePath: PersistedPath?
    let version: String?
    let runtimeEvidence: SettingsRuntimeEvidence
    let runtimeGate: SettingsRuntimeGateStatus
    let runtimeGateReason: SettingsRuntimeGateReason?
    let deepDive: SettingsDeepDiveModel
    let deepDiveCanStart: Bool
    let disclosure: SettingsRuntimeDisclosure
    let budget: InvestigationBudgetPreset
    let hasProviderSelector: Bool
    let hasArbitraryCLIFlags: Bool
    let hasSafetyBypass: Bool

    var deepDiveAvailability: DeepDiveAggregateAvailability {
        deepDive.aggregate
    }

    var deepDiveAvailabilityLocalizationKey: String {
        "settings.status.deepDive.implementationUnavailable"
    }

    var runtimeEvidenceLocalizationKey: String {
        switch runtimeEvidence.status {
        case .admitted:
            "settings.status.evidence.passed"
        case .stale:
            "settings.status.evidence.stale"
        case .failed:
            "settings.status.evidence.failed"
        case .unverified:
            "settings.status.evidence.unverified"
        }
    }
}

struct PrivacySettingsModel: Sendable, Equatable {
    let evidenceCount: Int
    let manifestCount: Int
    let evidenceRetentionDays: Int
    let manifestRetentionDays: Int
    let rawJSONLIsPersisted: Bool
}

struct SettingsKnowledgeRecord: Identifiable, Sendable, Equatable {
    let fact: LocalKnowledgeFact
    let status: SettingsKnowledgeStatus

    var id: LocalKnowledgeID { fact.id }
}

struct LocalKnowledgeSettingsModel: Sendable, Equatable {
    let records: [SettingsKnowledgeRecord]
    let corruptRecordIDs: [String]
    let hasFreeTextEditor: Bool
    let canOverrideDisposition: Bool
}

struct SettingsModel: Sendable, Equatable {
    let presentation: SettingsPresentation
    let sections: [SettingsSection]
    let general: GeneralSettingsModel
    let scanning: ScanningSettingsModel
    let permissions: PermissionsSettingsModel
    let codex: CodexSettingsModel
    let privacy: PrivacySettingsModel
    let localKnowledge: LocalKnowledgeSettingsModel
    let mutation: SettingsMutationKind?
    let reasonKey: DomainToken?

    init(
        state: SettingsState,
        latestProjection: QuickScanProjection?,
        sourceReadiness: DeepDiveSourceReadiness? = nil,
        workflowReadiness: DeepDiveWorkflowReadiness? = nil,
        budgetReadiness: DeepDiveBudgetReadiness? = nil
    ) {
        let snapshot = state.snapshot
        sections = SettingsSection.allCases
        mutation = state.mutation
        reasonKey = state.reasonKey
        switch state.phase {
        case .idle, .loading:
            presentation = .loading
        case .loaded, .mutating:
            presentation = .loaded
        case .error:
            presentation = .error
        }
        let preferences = snapshot?.preferences ?? .defaults
        let coverageGapCount = latestProjection?.ledger?
            .coverageGaps.count ?? 0
        let hasPermissionGap = latestProjection.map {
            projectionHasPermissionGap($0)
        } ?? false
        let diskAccess: SettingsDiskAccessStatus =
            snapshot?.diskAccess == .checkFailed
                ? .checkFailed
                : hasPermissionGap ? .limited
                    : snapshot?.diskAccess ?? .limited
        let codexStatus = snapshot?.codex ?? .unavailable
        let runtimeEvidence = normalizedRuntimeEvidence(
            snapshot?.runtimeEvidence ?? .unverified
        )
        let runtimeGate = deriveRuntimeGate(
            codex: codexStatus,
            evidence: runtimeEvidence
        )
        let dimensions = DeepDiveAdmissionDimensions(
            source: sourceReadiness
                ?? deepDiveSourceReadiness(latestProjection),
            disclosure:
                snapshot?.disclosureReadiness ?? .notPresented,
            codex: deepDiveCodexReadiness(codexStatus),
            runtime: deepDiveRuntimeReadiness(runtimeEvidence),
            dependencies:
                snapshot?.dependencyReadiness
                    ?? .task38FacadeUnavailable,
            workflow: workflowReadiness ?? (
                state.phase == .mutating
                    ? .settingsMutationInProgress
                    : .idle
            ),
            budget: budgetReadiness ?? .valid(
                preset: preferences.investigationBudget,
                limits: .forPreset(preferences.investigationBudget)
            )
        )
        let deepDive = SettingsDeepDiveModel(
            projection: DeepDiveAvailabilityEvaluator.evaluate(dimensions)
        )
        general = GeneralSettingsModel(
            language: preferences.language,
            appearance: preferences.appearance,
            diskAccess: diskAccess,
            codexInstallation: codexStatus.availability,
            runtimeGate: runtimeGate.status,
            deepDiveAvailability: deepDive.aggregate,
            runsOnDemandOnly: true
        )
        scanning = ScanningSettingsModel(
            primaryRoot: snapshot?.primaryRoot,
            exclusions: preferences.exclusions,
            canAddExclusion:
                snapshot?.primaryRoot.availability == .available
                    || snapshot?.primaryRoot.availability == .fallbackHome,
            primaryRootIsSingleScope: true,
            protectedLocationsAreEditable: false,
            catalogRuleCount: 67
        )
        permissions = PermissionsSettingsModel(
            diskAccess: diskAccess,
            primaryRoot: snapshot?.primaryRoot,
            coverageGapCount: coverageGapCount,
            quickScanRemainsAvailable:
                snapshot?.primaryRoot.availability == .available
                    || snapshot?.primaryRoot.availability == .fallbackHome,
            hasInAppFullDiskAccessToggle: false
        )
        codex = CodexSettingsModel(
            installationStatus: codexStatus.availability,
            syntaxStatus: codexStatus.syntaxStatus,
            executablePath: codexStatus.executablePath,
            version: codexStatus.version,
            runtimeEvidence: runtimeEvidence,
            runtimeGate: runtimeGate.status,
            runtimeGateReason: runtimeGate.reason,
            deepDive: deepDive,
            deepDiveCanStart: deepDive.normalProductStartEnabled,
            disclosure: SettingsRuntimeDisclosure(
                version: DeepDiveDisclosureDescriptor.current.version,
                items: DeepDiveDisclosureDescriptor.current.semanticItems(
                    for: preferences.language
                ),
                readiness: dimensions.disclosure,
                canReview: true,
                canAccept: true,
                canForget: dimensions.disclosure == .accepted
            ),
            budget: preferences.investigationBudget,
            hasProviderSelector: false,
            hasArbitraryCLIFlags: false,
            hasSafetyBypass: false
        )
        privacy = PrivacySettingsModel(
            evidenceCount: snapshot?.counts.evidence ?? 0,
            manifestCount: snapshot?.counts.manifests ?? 0,
            evidenceRetentionDays: 7,
            manifestRetentionDays: 90,
            rawJSONLIsPersisted: false
        )
        localKnowledge = LocalKnowledgeSettingsModel(
            records: (snapshot?.knowledge ?? []).map { fact in
                SettingsKnowledgeRecord(
                    fact: fact,
                    status: knowledgeStatus(
                        fact,
                        latestProjection: latestProjection,
                        currentCatalogVersion:
                            snapshot?.currentCatalogVersion
                    )
                )
            },
            corruptRecordIDs:
                snapshot?.corruptKnowledgeIDs ?? [],
            hasFreeTextEditor: false,
            canOverrideDisposition: false
        )
    }
}

private func deriveRuntimeGate(
    codex: SettingsCodexStatus,
    evidence: SettingsRuntimeEvidence
) -> (
    status: SettingsRuntimeGateStatus,
    reason: SettingsRuntimeGateReason?
) {
    if codex.availability == .unavailable {
        return (.blocked, .codexUnavailable)
    }
    if codex.syntaxStatus == .unsupported {
        return (.blocked, .syntaxUnsupported)
    }
    if evidence.status == .stale {
        return (.blocked, .evidenceStale)
    }
    if evidence.status == .failed {
        return (.blocked, .evidenceFailed)
    }
    if codex.availability == .checkFailed {
        return (.unverified, .codexCheckFailed)
    }
    if codex.syntaxStatus == .unverified {
        return (.unverified, .syntaxUnverified)
    }
    if evidence.status == .unverified {
        return (.unverified, .evidenceUnverified)
    }
    guard evidence.status == .admitted,
          evidence.receipt != nil
    else {
        return (.unverified, .evidenceUnverified)
    }
    return (.verified, nil)
}

private func normalizedRuntimeEvidence(
    _ evidence: SettingsRuntimeEvidence
) -> SettingsRuntimeEvidence {
    if evidence.status == .admitted {
        guard let receipt = evidence.receipt else {
            return .unverified
        }
        return .admitted(receipt)
    }
    return evidence
}

private func deepDiveCodexReadiness(
    _ status: SettingsCodexStatus
) -> DeepDiveCodexReadiness {
    switch status.availability {
    case .unavailable:
        return .notInstalled
    case .checkFailed:
        return .checkFailed
    case .installed:
        break
    }
    switch status.syntaxStatus {
    case .unsupported:
        return .syntaxUnsupported
    case .unverified:
        return .checkFailed
    case .supported:
        break
    }
    switch status.authenticationStatus {
    case .authenticated:
        return .available
    case .unavailable:
        return .authenticationUnavailable
    case .unverified:
        return .checkFailed
    }
}

private func deepDiveRuntimeReadiness(
    _ evidence: SettingsRuntimeEvidence
) -> DeepDiveRuntimeReadiness {
    switch evidence.status {
    case .admitted:
        return evidence.receipt == nil ? .unverified : .admitted
    case .stale:
        return .stale
    case .failed:
        return .failed
    case .unverified:
        return .unverified
    }
}

private func deepDiveSourceReadiness(
    _ projection: QuickScanProjection?
) -> DeepDiveSourceReadiness {
    guard let projection else { return .missing }
    guard projection.session.terminalState != .failed,
          projection.session.completedScopes.count == 1,
          projection.session.unfinishedScopes.isEmpty,
          let ledger = projection.ledger,
          ledger.status == .reconciled,
          ledger.coverageGaps.isEmpty,
          ledger.unmeasurable.status == .measured,
          ledger.unmeasurable.bytes?.value == 0,
          !ledger.unknownIncludesUnmeasurable
    else {
        return .partial
    }
    return .ready
}

private func knowledgeStatus(
    _ fact: LocalKnowledgeFact,
    latestProjection: QuickScanProjection?,
    currentCatalogVersion: DomainToken?
) -> SettingsKnowledgeStatus {
    if let currentCatalogVersion,
       fact.binding.catalogVersion != currentCatalogVersion
    {
        return .stale
    }
    guard let latestProjection,
          let snapshot = latestProjection.snapshots.first(where: {
              PersistedPath(rawValue: $0.relativePath) == fact.scope
          }),
          snapshot.fileIdentity == fact.binding.fileIdentity
    else {
        return .contextUnavailable
    }
    return .contextUnavailable
}

private func projectionHasPermissionGap(
    _ projection: QuickScanProjection
) -> Bool {
    projection.session.unfinishedScopes.contains {
        $0.reason == .permissionDenied
    } || projection.ledger?.coverageGaps.contains {
        $0.status == .permissionDenied
    } == true
}
