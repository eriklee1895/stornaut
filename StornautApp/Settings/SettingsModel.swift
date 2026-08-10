import Foundation
import StornautCore

enum SettingsPresentation: String, Sendable, Equatable {
    case loading
    case loaded
    case error
}

enum SettingsDeepDiveSafety: String, Sendable, Equatable {
    case pausedRequired
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
    let deepDiveSafety: SettingsDeepDiveSafety
    let runsOnDemandOnly: Bool
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
    let deepDiveSafety: SettingsDeepDiveSafety
    let deepDiveCanStart: Bool
    let budget: InvestigationBudgetPreset
    let hasProviderSelector: Bool
    let hasArbitraryCLIFlags: Bool
    let hasSafetyBypass: Bool
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
        latestProjection: QuickScanProjection?
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
        general = GeneralSettingsModel(
            language: preferences.language,
            appearance: preferences.appearance,
            diskAccess: diskAccess,
            codexInstallation: codexStatus.availability,
            deepDiveSafety: .pausedRequired,
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
            deepDiveSafety: .pausedRequired,
            deepDiveCanStart: false,
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
