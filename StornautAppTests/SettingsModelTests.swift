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
func runtimeGateFailsClosedAcrossEveryStatusCombination() throws {
    for availability in SettingsCodexAvailability.allCases {
        for syntax in SettingsCodexSyntaxStatus.allCases {
            for evidenceStatus in SettingsRuntimeEvidenceStatus.allCases {
                let model = SettingsModel(
                    state: .loaded(
                        try SettingsAppTestFactory.snapshot(
                            codex: SettingsCodexStatus(
                                availability: availability,
                                executablePath: availability == .installed
                                    ? PersistedPath(
                                        rawValue: "/tmp/codex-fixture"
                                    )
                                    : nil,
                                version: availability == .installed
                                    ? "codex-cli fixture"
                                    : nil,
                                syntaxStatus: syntax
                            ),
                            runtimeEvidence: runtimeEvidence(
                                status: evidenceStatus
                            )
                        )
                    ),
                    latestProjection: nil
                )
                let expected = expectedRuntimeGate(
                    availability: availability,
                    syntax: syntax,
                    evidence: evidenceStatus
                )

                #expect(model.codex.installationStatus == availability)
                #expect(model.codex.syntaxStatus == syntax)
                #expect(model.codex.runtimeEvidence.status == evidenceStatus)
                #expect(model.codex.runtimeGate == expected.status)
                #expect(model.codex.runtimeGateReason == expected.reason)
                #expect(
                    model.codex.deepDiveAvailability
                        == .implementationUnavailable
                )
                #expect(model.codex.deepDiveCanStart == false)
                #expect(model.permissions.quickScanRemainsAvailable)
            }
        }
    }
}

@Test
func admittedRuntimeEvidenceMatchesExactR5MachineReportReceipt() {
    let receipt = SettingsRuntimeEvidenceReceipt.admittedR5

    #expect(receipt.schemaVersion == 1)
    #expect(receipt.runtimeProfile == "capability-first-v1")
    #expect(
        receipt.runtimeRevision
            == "8b93852d901cc7bd78bf827c21dc4d85ab9d473f"
    )
    #expect(receipt.reportSchemaVersion == 2)
    #expect(
        receipt.reportSHA256
            == "08ba7c30373d4736124f0e507fcc9aa972880235251b8bbf636a7b2fabb1d193"
    )
    #expect(
        receipt.verifiedAt
            == Date(timeIntervalSince1970: 1_786_619_347)
    )
    #expect(receipt.provider == "openai")
    #expect(receipt.model == "gpt-5.6-luna")
    #expect(receipt.capabilitiesObserved == 9)
    #expect(receipt.integrityContained == 12)
    #expect(receipt.outcome == .passed)
}

@Test
func passedRuntimeEvidenceVerifiesBoundaryWithoutEnablingDeepDive()
    throws
{
    let model = SettingsModel(
        state: .loaded(
            try SettingsAppTestFactory.snapshot(
                codex: .installedSupported,
                runtimeEvidence: .admittedR5
            )
        ),
        latestProjection: nil
    )

    #expect(model.codex.runtimeEvidence == .admittedR5)
    #expect(model.codex.runtimeGate == .verified)
    #expect(model.codex.runtimeGateReason == nil)
    #expect(
        model.codex.deepDiveAvailability
            == .implementationUnavailable
    )
    #expect(model.codex.deepDiveCanStart == false)
}

@Test
func passedStatusWithoutReceiptRemainsUnverified() throws {
    let model = SettingsModel(
        state: .loaded(
            try SettingsAppTestFactory.snapshot(
                codex: .installedSupported,
                runtimeEvidence: .passed(
                    receipt: nil
                )
            )
        ),
        latestProjection: nil
    )

    #expect(model.codex.runtimeGate == .unverified)
    #expect(model.codex.runtimeGateReason == .evidenceUnverified)
    #expect(model.codex.runtimeEvidence == .unverified)
    #expect(model.codex.deepDiveCanStart == false)
}

@Test
func passedStatusWithUnadmittedReceiptRemainsUnverified() throws {
    let admitted = SettingsRuntimeEvidenceReceipt.admittedR5
    let unadmitted = SettingsRuntimeEvidenceReceipt(
        schemaVersion: admitted.schemaVersion,
        runtimeProfile: admitted.runtimeProfile,
        runtimeRevision: admitted.runtimeRevision,
        reportSchemaVersion: admitted.reportSchemaVersion,
        reportSHA256: String(repeating: "0", count: 64),
        verifiedAt: admitted.verifiedAt,
        provider: admitted.provider,
        model: admitted.model,
        capabilitiesObserved: admitted.capabilitiesObserved,
        integrityContained: admitted.integrityContained,
        outcome: admitted.outcome
    )
    let model = SettingsModel(
        state: .loaded(
            try SettingsAppTestFactory.snapshot(
                codex: .installedSupported,
                runtimeEvidence: .passed(
                    receipt: unadmitted
                )
            )
        ),
        latestProjection: nil
    )

    #expect(model.codex.runtimeGate == .unverified)
    #expect(model.codex.runtimeGateReason == .evidenceUnverified)
    #expect(model.codex.runtimeEvidence == .unverified)
    #expect(model.codex.deepDiveCanStart == false)
}

@Test
func aggregateRuntimeDisclosureIsTypedAndNonActionable() throws {
    let model = SettingsModel(
        state: .loaded(
            try SettingsAppTestFactory.snapshot(
                codex: .installedSupported,
                runtimeEvidence: .admittedR5
            )
        ),
        latestProjection: nil
    )
    let disclosure = model.codex.disclosure

    #expect(disclosure.items == SettingsRuntimeDisclosureItem.allCases)
    #expect(disclosure.items == [
        .directReadOnlyFilesystemInvestigation,
        .modelContextProcessing,
        .publicInternetInvestigation,
        .noWriteOrCleanupAuthority,
        .swiftRevalidationAndExplicitSelection,
    ])
    #expect(disclosure.hasAction == false)
    #expect(disclosure.persistsAcceptance == false)
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

@Test
func verifiedRuntimeCopyIsExactInBothLanguages() throws {
    let bundle = try #require(Bundle(identifier: "com.eriklee.stornaut"))
    let expected = [
        "en":
            "Runtime boundary verified · Deep Dive implementation not yet available",
        "zh-Hans": "运行时边界已验证 · 深度调查实现尚不可用",
    ]

    for (language, copy) in expected {
        let path = try #require(
            bundle.path(forResource: language, ofType: "lproj")
        )
        let localized = try #require(Bundle(path: path))

        #expect(
            localized.localizedString(
                forKey: "settings.codex.runtimeGate.verified.message",
                value: nil,
                table: nil
            ) == copy
        )
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
        "settings.codex.evidence",
        "settings.codex.runtimeGate",
        "settings.codex.deepDiveAvailability",
        "settings.codex.disclosure",
        "settings.codex.disclosure.directRead",
        "settings.codex.disclosure.modelContext",
        "settings.codex.disclosure.publicInternet",
        "settings.codex.disclosure.noWriteAuthority",
        "settings.codex.disclosure.swiftRevalidation",
        "settings.status.evidence.passed",
        "settings.status.evidence.stale",
        "settings.status.evidence.failed",
        "settings.status.evidence.unverified",
        "settings.status.runtimeGate.verified",
        "settings.status.runtimeGate.blocked",
        "settings.status.runtimeGate.unverified",
        "settings.status.deepDive.implementationUnavailable",
        "settings.runtimeGate.reason.codexUnavailable",
        "settings.runtimeGate.reason.codexCheckFailed",
        "settings.runtimeGate.reason.syntaxUnsupported",
        "settings.runtimeGate.reason.syntaxUnverified",
        "settings.runtimeGate.reason.evidenceStale",
        "settings.runtimeGate.reason.evidenceFailed",
        "settings.runtimeGate.reason.evidenceUnverified",
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
        runtimeEvidence: SettingsRuntimeEvidence = .admittedR5,
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
            runtimeEvidence: runtimeEvidence,
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

private func expectedRuntimeGate(
    availability: SettingsCodexAvailability,
    syntax: SettingsCodexSyntaxStatus,
    evidence: SettingsRuntimeEvidenceStatus
) -> (
    status: SettingsRuntimeGateStatus,
    reason: SettingsRuntimeGateReason?
) {
    if availability == .unavailable {
        return (.blocked, .codexUnavailable)
    }
    if syntax == .unsupported {
        return (.blocked, .syntaxUnsupported)
    }
    if evidence == .stale {
        return (.blocked, .evidenceStale)
    }
    if evidence == .failed {
        return (.blocked, .evidenceFailed)
    }
    if availability == .checkFailed {
        return (.unverified, .codexCheckFailed)
    }
    if syntax == .unverified {
        return (.unverified, .syntaxUnverified)
    }
    if evidence == .unverified {
        return (.unverified, .evidenceUnverified)
    }
    return (.verified, nil)
}

private func runtimeEvidence(
    status: SettingsRuntimeEvidenceStatus
) -> SettingsRuntimeEvidence {
    switch status {
    case .passed:
        .admittedR5
    case .stale:
        .staleR5
    case .failed:
        .failed
    case .unverified:
        .unverified
    }
}
