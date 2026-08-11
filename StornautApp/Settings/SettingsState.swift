import Foundation
import StornautCore

enum SettingsSection:
    String,
    CaseIterable,
    Sendable,
    Equatable,
    Identifiable
{
    case general
    case scanning
    case permissions
    case codexAndDeepDive
    case privacyAndData
    case localKnowledge

    var id: Self { self }

    var localizationKey: String {
        switch self {
        case .general:
            "settings.section.general"
        case .scanning:
            "settings.section.scanning"
        case .permissions:
            "settings.section.permissions"
        case .codexAndDeepDive:
            "settings.section.codex"
        case .privacyAndData:
            "settings.section.privacy"
        case .localKnowledge:
            "settings.section.knowledge"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            "gearshape"
        case .scanning:
            StornautSystemImage.quickScan
        case .permissions:
            "lock.shield"
        case .codexAndDeepDive:
            "scope"
        case .privacyAndData:
            "hand.raised"
        case .localKnowledge:
            "brain.head.profile"
        }
    }
}

enum SettingsDiskAccessStatus: String, Sendable, Equatable {
    case full
    case limited
    case checkFailed
}

enum SettingsCodexAvailability: String, Sendable, Equatable {
    case installed
    case unavailable
    case checkFailed
}

enum SettingsCodexSyntaxStatus: String, Sendable, Equatable {
    case supported
    case unsupported
    case unverified
}

struct SettingsCodexStatus: Sendable, Equatable {
    let availability: SettingsCodexAvailability
    let executablePath: PersistedPath?
    let version: String?
    let syntaxStatus: SettingsCodexSyntaxStatus

    static let unavailable = SettingsCodexStatus(
        availability: .unavailable,
        executablePath: nil,
        version: nil,
        syntaxStatus: .unverified
    )
}

struct SettingsPrimaryRootStatus: Sendable, Equatable {
    let path: PersistedPath
    let availability: SettingsPrimaryRootAvailability
}

struct SettingsRecordCounts: Sendable, Equatable {
    let evidence: Int
    let manifests: Int
    let localKnowledge: Int
}

struct SettingsSnapshot: Sendable, Equatable {
    let preferences: SettingsPreferences
    let primaryRoot: SettingsPrimaryRootStatus
    let diskAccess: SettingsDiskAccessStatus
    let codex: SettingsCodexStatus
    let counts: SettingsRecordCounts
    let knowledge: [LocalKnowledgeFact]
    let corruptKnowledgeIDs: [String]
    let currentCatalogVersion: DomainToken
    let refreshedAt: Date

    init(
        preferences: SettingsPreferences,
        primaryRoot: SettingsPrimaryRootStatus,
        diskAccess: SettingsDiskAccessStatus,
        codex: SettingsCodexStatus,
        counts: SettingsRecordCounts,
        knowledge: [LocalKnowledgeFact],
        corruptKnowledgeIDs: [String],
        currentCatalogVersion: DomainToken,
        refreshedAt: Date
    ) {
        self.preferences = preferences
        self.primaryRoot = primaryRoot
        self.diskAccess = diskAccess
        self.codex = codex
        self.counts = counts
        self.knowledge = knowledge.sorted {
            if $0.updatedAt != $1.updatedAt {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.id.rawValue < $1.id.rawValue
        }
        self.corruptKnowledgeIDs =
            Array(Set(corruptKnowledgeIDs)).sorted()
        self.currentCatalogVersion = currentCatalogVersion
        self.refreshedAt = refreshedAt
    }

    func replacing(
        preferences: SettingsPreferences? = nil,
        primaryRoot: SettingsPrimaryRootStatus? = nil,
        diskAccess: SettingsDiskAccessStatus? = nil,
        codex: SettingsCodexStatus? = nil,
        counts: SettingsRecordCounts? = nil,
        knowledge: [LocalKnowledgeFact]? = nil,
        corruptKnowledgeIDs: [String]? = nil,
        refreshedAt: Date? = nil
    ) -> SettingsSnapshot {
        SettingsSnapshot(
            preferences: preferences ?? self.preferences,
            primaryRoot: primaryRoot ?? self.primaryRoot,
            diskAccess: diskAccess ?? self.diskAccess,
            codex: codex ?? self.codex,
            counts: counts ?? self.counts,
            knowledge: knowledge ?? self.knowledge,
            corruptKnowledgeIDs:
                corruptKnowledgeIDs ?? self.corruptKnowledgeIDs,
            currentCatalogVersion: currentCatalogVersion,
            refreshedAt: refreshedAt ?? self.refreshedAt
        )
    }

    static func fallback(
        preferences: SettingsPreferences,
        rootURL: URL,
        refreshedAt: Date
    ) -> SettingsSnapshot {
        SettingsSnapshot(
            preferences: preferences,
            primaryRoot: SettingsPrimaryRootStatus(
                path: PersistedPath(rawValue: rootURL.path)!,
                availability: .fallbackHome
            ),
            diskAccess: .limited,
            codex: .unavailable,
            counts: SettingsRecordCounts(
                evidence: 0,
                manifests: 0,
                localKnowledge: 0
            ),
            knowledge: [],
            corruptKnowledgeIDs: [],
            currentCatalogVersion: DomainToken(
                rawValue: "builtin-runtime-tool-residue-v1"
            )!,
            refreshedAt: refreshedAt
        )
    }
}

enum SettingsMutationKind: String, Sendable, Equatable {
    case preferences
    case root
    case exclusion
    case clearEvidence
    case clearManifests
    case forgetKnowledge
    case forgetAllKnowledge
    case refresh
}

enum SettingsPhase: String, Sendable, Equatable {
    case idle
    case loading
    case loaded
    case mutating
    case error
}

struct SettingsState: Sendable, Equatable {
    let phase: SettingsPhase
    let snapshot: SettingsSnapshot?
    let mutation: SettingsMutationKind?
    let reasonKey: DomainToken?

    static let idle = SettingsState(
        phase: .idle,
        snapshot: nil,
        mutation: nil,
        reasonKey: nil
    )

    static func loading(
        _ snapshot: SettingsSnapshot? = nil
    ) -> SettingsState {
        SettingsState(
            phase: .loading,
            snapshot: snapshot,
            mutation: nil,
            reasonKey: nil
        )
    }

    static func loaded(
        _ snapshot: SettingsSnapshot
    ) -> SettingsState {
        SettingsState(
            phase: .loaded,
            snapshot: snapshot,
            mutation: nil,
            reasonKey: nil
        )
    }

    static func mutating(
        _ mutation: SettingsMutationKind,
        snapshot: SettingsSnapshot
    ) -> SettingsState {
        SettingsState(
            phase: .mutating,
            snapshot: snapshot,
            mutation: mutation,
            reasonKey: nil
        )
    }

    static func failed(
        snapshot: SettingsSnapshot?,
        reasonKey: DomainToken
    ) -> SettingsState {
        SettingsState(
            phase: .error,
            snapshot: snapshot,
            mutation: nil,
            reasonKey: reasonKey
        )
    }
}
