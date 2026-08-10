import Foundation
import StornautCore
import Testing
@testable import StornautApp

@Test
func settingsProjectionHasExactlySixSectionsAndClosedEditableSurfaces()
    throws
{
    let model = SettingsModel(
        state: .loaded(
            try SettingsAppTestFactory.snapshot()
        ),
        latestProjection: nil
    )

    #expect(model.sections == SettingsSection.allCases)
    #expect(model.sections == [
        .general,
        .scanning,
        .permissions,
        .codexAndDeepDive,
        .privacyAndData,
        .localKnowledge,
    ])
    #expect(model.general.runsOnDemandOnly)
    #expect(model.scanning.primaryRootIsSingleScope)
    #expect(model.scanning.protectedLocationsAreEditable == false)
    #expect(model.scanning.canAddExclusion)
    #expect(model.permissions.hasInAppFullDiskAccessToggle == false)
    #expect(
        model.permissions.primaryRoot?.availability == .fallbackHome
    )
    #expect(model.codex.hasProviderSelector == false)
    #expect(model.codex.hasArbitraryCLIFlags == false)
    #expect(model.codex.hasSafetyBypass == false)
    #expect(model.privacy.evidenceRetentionDays == 7)
    #expect(model.privacy.manifestRetentionDays == 90)
    #expect(model.privacy.rawJSONLIsPersisted == false)
    #expect(model.localKnowledge.hasFreeTextEditor == false)
    #expect(model.localKnowledge.canOverrideDisposition == false)
}

@Test
func codexInstallationNeverImpliesDeepDiveSafety() throws {
    let installed = try SettingsAppTestFactory.snapshot(
        codex: SettingsCodexStatus(
            availability: .installed,
            executablePath: PersistedPath(
                rawValue: "/tmp/codex-fixture"
            ),
            version: "codex-cli fixture",
            syntaxStatus: .supported
        )
    )
    let model = SettingsModel(
        state: .loaded(installed),
        latestProjection: nil
    )

    #expect(model.codex.installationStatus == .installed)
    #expect(model.codex.syntaxStatus == .supported)
    #expect(model.codex.deepDiveSafety == .pausedRequired)
    #expect(model.codex.deepDiveCanStart == false)
}

@Test
func latestPermissionGapAffectsDiskAccessWithoutBlockingQuickScan()
    throws
{
    let projection = try OverviewTestProjectionFactory.projection(
        slug: "settings-permission",
        terminalState: .partial,
        permissionGap: true
    )
    let model = SettingsModel(
        state: .loaded(
            try SettingsAppTestFactory.snapshot()
        ),
        latestProjection: projection
    )

    #expect(model.permissions.diskAccess == .limited)
    #expect(model.permissions.coverageGapCount > 0)
    #expect(model.permissions.quickScanRemainsAvailable)
}

@Test
func unavailableConfiguredRootBlocksNewExclusionsAndRemainsVisible()
    throws
{
    let snapshot = try SettingsAppTestFactory.snapshot(
        primaryRootAvailability: .unavailable
    )
    let model = SettingsModel(
        state: .loaded(snapshot),
        latestProjection: nil
    )

    #expect(model.scanning.canAddExclusion == false)
    #expect(model.permissions.primaryRoot == snapshot.primaryRoot)
    #expect(model.permissions.quickScanRemainsAvailable == false)
}

@Test
func localKnowledgeWithoutCompleteLiveContextIsNeverCalledCurrent()
    throws
{
    let fact = try SettingsAppTestFactory.fact(
        catalogVersion: "builtin-runtime-tool-residue-v1"
    )
    let currentCatalog = try SettingsAppTestFactory.snapshot(
        knowledge: [fact],
        catalogVersion: "builtin-runtime-tool-residue-v1"
    )
    let changedCatalog = try SettingsAppTestFactory.snapshot(
        knowledge: [fact],
        catalogVersion: "builtin-runtime-tool-residue-v2"
    )

    let unavailable = SettingsModel(
        state: .loaded(currentCatalog),
        latestProjection: nil
    )
    let stale = SettingsModel(
        state: .loaded(changedCatalog),
        latestProjection: nil
    )

    #expect(unavailable.localKnowledge.records.first?.status
        == .contextUnavailable)
    #expect(stale.localKnowledge.records.first?.status == .stale)
}

@Test
func settingsLocalizationKeysResolveInBothLanguages() throws {
    let bundle = try #require(Bundle(identifier: "com.eriklee.stornaut"))

    for language in ["en", "zh-Hans"] {
        let path = try #require(
            bundle.path(forResource: language, ofType: "lproj")
        )
        let localized = try #require(Bundle(path: path))
        for key in SettingsLocalizationKeys.all {
            #expect(
                localized.localizedString(
                    forKey: key,
                    value: nil,
                    table: nil
                ) != key
            )
        }
    }
}

private enum SettingsLocalizationKeys {
    static let all = [
        "settings.section.general",
        "settings.section.scanning",
        "settings.section.permissions",
        "settings.section.codex",
        "settings.section.privacy",
        "settings.section.knowledge",
        "settings.general.language",
        "settings.general.appearance",
        "settings.general.onDemand",
        "settings.scanning.primaryRoot",
        "settings.scanning.exclusions",
        "settings.permissions.fullDiskAccess",
        "settings.codex.installation",
        "settings.codex.safety",
        "settings.privacy.evidence",
        "settings.privacy.manifests",
        "settings.privacy.jsonl",
        "settings.knowledge.empty",
        "settings.action.clearEvidence",
        "settings.action.clearManifests",
        "settings.action.forget",
        "settings.action.forgetAll",
    ]
}

enum SettingsAppTestFactory {
    static let now = Date(timeIntervalSince1970: 1_786_449_600)

    static func snapshot(
        codex: SettingsCodexStatus = .unavailable,
        knowledge: [LocalKnowledgeFact] = [],
        catalogVersion: String = "builtin-runtime-tool-residue-v1",
        counts: SettingsRecordCounts? = nil,
        primaryRootAvailability: SettingsPrimaryRootAvailability = .fallbackHome
    ) throws -> SettingsSnapshot {
        SettingsSnapshot(
            preferences: .defaults,
            primaryRoot: SettingsPrimaryRootStatus(
                path: PersistedPath(rawValue: "/tmp/settings-root")!,
                availability: primaryRootAvailability
            ),
            diskAccess: .limited,
            codex: codex,
            counts: counts ?? SettingsRecordCounts(
                evidence: 3,
                manifests: 2,
                localKnowledge: knowledge.count
            ),
            knowledge: knowledge,
            corruptKnowledgeIDs: [],
            currentCatalogVersion: DomainToken(
                rawValue: catalogVersion
            )!,
            refreshedAt: now
        )
    }

    static func fact(
        catalogVersion: String
    ) throws -> LocalKnowledgeFact {
        try LocalKnowledgeFact(
            id: LocalKnowledgeID(rawValue: "knowledge-settings-fixture")!,
            payload: .keepDecision,
            binding: LocalKnowledgeBinding(
                scope: PersistedPath(
                    rawValue: "/tmp/settings-root/cache"
                )!,
                fileIdentity: FileIdentity(
                    device: 1,
                    inode: 2,
                    mode: UInt16(S_IFDIR | 0o755),
                    ownerUserID: 501,
                    ownerGroupID: 20,
                    size: 0,
                    allocatedBytes: 0,
                    modificationSeconds: 1,
                    modificationNanoseconds: 0
                ),
                activityFingerprint: DomainToken(
                    rawValue: "activity.settings-fixture"
                )!,
                catalogVersion: DomainToken(
                    rawValue: catalogVersion
                )!
            ),
            provenance: .userConfirmed,
            observedAt: now.addingTimeInterval(-60),
            updatedAt: now
        )
    }
}
