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

enum SettingsCodexAvailability:
    String,
    CaseIterable,
    Sendable,
    Equatable
{
    case installed
    case unavailable
    case checkFailed
}

enum SettingsCodexSyntaxStatus:
    String,
    CaseIterable,
    Sendable,
    Equatable
{
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

    static let installedSupported = SettingsCodexStatus(
        availability: .installed,
        executablePath: nil,
        version: nil,
        syntaxStatus: .supported
    )
}

enum SettingsRuntimeEvidenceStatus:
    String,
    CaseIterable,
    Sendable,
    Equatable
{
    case passed
    case stale
    case failed
    case unverified
}

enum SettingsRuntimeEvidenceOutcome: String, Sendable, Equatable {
    case passed
}

struct SettingsRuntimeEvidenceReceipt: Sendable, Equatable {
    let schemaVersion: Int
    let runtimeProfile: String
    let runtimeRevision: String
    let reportSchemaVersion: Int
    let reportSHA256: String
    let verifiedAt: Date
    let provider: String
    let model: String
    let capabilitiesObserved: Int
    let integrityContained: Int
    let outcome: SettingsRuntimeEvidenceOutcome

    static let admittedR5 = SettingsRuntimeEvidenceReceipt(
        schemaVersion: 1,
        runtimeProfile: "capability-first-v1",
        runtimeRevision:
            "8b93852d901cc7bd78bf827c21dc4d85ab9d473f",
        reportSchemaVersion: 2,
        reportSHA256:
            "08ba7c30373d4736124f0e507fcc9aa972880235251b8bbf636a7b2fabb1d193",
        verifiedAt: Date(timeIntervalSince1970: 1_786_619_347),
        provider: "openai",
        model: "gpt-5.6-luna",
        capabilitiesObserved: 9,
        integrityContained: 12,
        outcome: .passed
    )
}

struct SettingsRuntimeEvidence: Sendable, Equatable {
    let status: SettingsRuntimeEvidenceStatus
    let receipt: SettingsRuntimeEvidenceReceipt?

    private init(
        status: SettingsRuntimeEvidenceStatus,
        receipt: SettingsRuntimeEvidenceReceipt?
    ) {
        self.status = status
        self.receipt = receipt
    }

    static let admittedR5 = SettingsRuntimeEvidence(
        status: .passed,
        receipt: .admittedR5
    )

    static let staleR5 = SettingsRuntimeEvidence(
        status: .stale,
        receipt: .admittedR5
    )

    static let failed = SettingsRuntimeEvidence(
        status: .failed,
        receipt: nil
    )

    static let unverified = SettingsRuntimeEvidence(
        status: .unverified,
        receipt: nil
    )

    static func passed(
        receipt: SettingsRuntimeEvidenceReceipt?
    ) -> SettingsRuntimeEvidence {
        SettingsRuntimeEvidence(
            status: .passed,
            receipt: receipt
        )
    }
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
    let runtimeEvidence: SettingsRuntimeEvidence
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
        runtimeEvidence: SettingsRuntimeEvidence,
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
        self.runtimeEvidence = runtimeEvidence
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
        runtimeEvidence: SettingsRuntimeEvidence? = nil,
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
            runtimeEvidence: runtimeEvidence ?? self.runtimeEvidence,
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
            runtimeEvidence: .admittedR5,
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
