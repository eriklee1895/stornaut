import Darwin
import CryptoKit
import Foundation

public struct ExecutableEvidenceResolution:
    Sendable,
    Equatable
{
    public let satisfiedEvidenceKeys: [DomainToken]
    public let activityObservations: [ActivityObservation]
    public let evidenceRecords: [EvidenceRecord]
    public let evidenceFingerprint: DomainToken
    public let activityFingerprint: DomainToken
    public let isCurrentIdentity: Bool
    public let isEligible: Bool

    public init(
        satisfiedEvidenceKeys: [DomainToken],
        activityObservations: [ActivityObservation],
        evidenceRecords: [EvidenceRecord],
        evidenceFingerprint: DomainToken,
        activityFingerprint: DomainToken,
        isCurrentIdentity: Bool,
        isEligible: Bool
    ) {
        self.satisfiedEvidenceKeys = satisfiedEvidenceKeys
        self.activityObservations = activityObservations
        self.evidenceRecords = evidenceRecords
        self.evidenceFingerprint = evidenceFingerprint
        self.activityFingerprint = activityFingerprint
        self.isCurrentIdentity = isCurrentIdentity
        self.isEligible = isEligible
    }
}

public struct ExecutableEvidenceResolver: Sendable {
    public typealias EvidenceIDSource = @Sendable (
        SnapshotID,
        DomainToken
    ) -> EvidenceID
    public typealias IdentityReader = @Sendable (URL) -> FileIdentity?
    private typealias DiagnosticEvaluator = @Sendable (
        PathSnapshot,
        FileIdentity?,
        CompiledRule,
        ExecutionProfile,
        DomainToken,
        Date
    ) -> PhaseCTrashDiagnosticEvaluation

    private let activityProvider: RunningActivityProvider
    private let identityReader: IdentityReader
    private let diagnosticEvaluator: DiagnosticEvaluator?

    public init(
        activityProvider: RunningActivityProvider = RunningActivityProvider(),
        identityReader: @escaping IdentityReader = FileIdentity.read(at:)
    ) {
        self.activityProvider = activityProvider
        self.identityReader = identityReader
        diagnosticEvaluator = nil
    }

#if DEBUG
    public static func phaseCTrashDiagnostic(
        diagnosticRootURL: URL,
        fixtureRootURL: URL,
        nonce: String,
        expectedTargetIdentity: FileIdentity,
        activityProvider: RunningActivityProvider =
            RunningActivityProvider()
    ) throws -> ExecutableEvidenceResolver {
        let rules = try BuiltInRuleCatalog.load()
        let profiles = try BuiltInExecutionProfileCatalog.load(
            ruleCatalog: rules
        )
        guard let profile = profiles.profiles.first(where: {
            $0.id.rawValue == "phase-c.npm-cacache-v1"
                && $0.ruleID.rawValue == "cache-npm-content"
        })
        else {
            throw PhaseCTrashDiagnosticAttestationError.invalidProfile
        }
        let attestation = try PhaseCTrashDiagnosticAttestation(
            diagnosticRootURL: diagnosticRootURL,
            fixtureRootURL: fixtureRootURL,
            nonce: nonce,
            expectedTargetIdentity: expectedTargetIdentity,
            expectedProfile: profile,
            expectedProfileCatalogVersion:
                profiles.catalogVersion
        )
        return ExecutableEvidenceResolver(
            activityProvider: activityProvider,
            identityReader: FileIdentity.read(at:),
            diagnosticEvaluator: {
                attestation.evaluate(
                    snapshot: $0,
                    currentIdentity: $1,
                    rule: $2,
                    profile: $3,
                    profileCatalogVersion: $4,
                    observedAt: $5
                )
            }
        )
    }
#endif

    private init(
        activityProvider: RunningActivityProvider,
        identityReader: @escaping IdentityReader,
        diagnosticEvaluator: @escaping DiagnosticEvaluator
    ) {
        self.activityProvider = activityProvider
        self.identityReader = identityReader
        self.diagnosticEvaluator = diagnosticEvaluator
    }

    public func captureActivity(
        observedAt: Date
    ) async -> RunningActivityContext {
        await activityProvider.capture(observedAt: observedAt)
    }

    public func evaluateActivity(
        subjects: ExecutionProcessSubjects,
        context: RunningActivityContext
    ) -> ActivityObservation {
        activityProvider.evaluate(
            subjects: subjects,
            context: context
        ).observation
    }

    func acceptsPersistedSummary(
        _ summary: DomainToken,
        binding: ExecutionEvidenceBinding
    ) -> Bool {
        if summary.rawValue
            == "execution.\(binding.key.rawValue).satisfied"
        {
            return true
        }
        return diagnosticEvaluator != nil
            && binding.resolver == .currentActivity
            && binding.key.rawValue
                == ActivityKey.processInactive.rawValue
            && summary.rawValue
                == "execution.activity.process.inactive.isolated-diagnostic-attested"
    }

    public func resolveQuickScan(
        snapshot: PathSnapshot,
        rule: CompiledRule,
        profile: ExecutionProfile,
        profileCatalogVersion: DomainToken,
        activityContext: RunningActivityContext,
        evidenceID: EvidenceIDSource
    ) throws -> ExecutableEvidenceResolution {
        try resolve(
            snapshot: snapshot,
            currentIdentity: snapshot.fileIdentity,
            rule: rule,
            profile: profile,
            profileCatalogVersion: profileCatalogVersion,
            activityContext: activityContext,
            evidenceID: evidenceID
        )
    }

    public func resolveReview(
        snapshot: PathSnapshot,
        rootURL: URL,
        rootIdentity: FileIdentity,
        rule: CompiledRule,
        profile: ExecutionProfile,
        profileCatalogVersion: DomainToken,
        activityContext: RunningActivityContext,
        evidenceID: EvidenceIDSource
    ) throws -> ExecutableEvidenceResolution {
        let candidateURL = rootURL.appending(
            path: snapshot.relativePath,
            directoryHint: .isDirectory
        )
        let currentIdentity = identityReader(candidateURL)
        return try resolveReview(
            snapshot: snapshot,
            currentIdentity: currentIdentity,
            rootIdentity: rootIdentity,
            rule: rule,
            profile: profile,
            profileCatalogVersion: profileCatalogVersion,
            activityContext: activityContext,
            evidenceID: evidenceID
        )
    }

    public func resolveReview(
        snapshot: PathSnapshot,
        currentIdentity: FileIdentity?,
        rootIdentity: FileIdentity,
        rule: CompiledRule,
        profile: ExecutionProfile,
        profileCatalogVersion: DomainToken,
        activityContext: RunningActivityContext,
        evidenceID: EvidenceIDSource
    ) throws -> ExecutableEvidenceResolution {
        let sameRootDevice = currentIdentity?.device == rootIdentity.device
        return try resolve(
            snapshot: snapshot,
            currentIdentity: sameRootDevice ? currentIdentity : nil,
            rule: rule,
            profile: profile,
            profileCatalogVersion: profileCatalogVersion,
            activityContext: activityContext,
            evidenceID: evidenceID
        )
    }

    private func resolve(
        snapshot: PathSnapshot,
        currentIdentity: FileIdentity?,
        rule: CompiledRule,
        profile: ExecutionProfile,
        profileCatalogVersion: DomainToken,
        activityContext: RunningActivityContext,
        evidenceID: EvidenceIDSource
    ) throws -> ExecutableEvidenceResolution {
        let staticAttested = rule.id == profile.ruleID
            && rule.match.pathPattern == profile.relativePath
            && rule.match.expectedKind == profile.expectedKind
            && snapshot.relativePath == profile.relativePath.rawValue
            && snapshot.kind == .directory
            && snapshot.measurementStatus == .measured
            && rule.confidenceRequirement == .high
            && rule.recovery != nil
            && rule.recommendedAction == .moveToTrash
            && !rule.veto
        let diagnosticEvaluation = diagnosticEvaluator?(
            snapshot,
            currentIdentity,
            rule,
            profile,
            profileCatalogVersion,
            activityContext.observedAt
        )
        let identityCurrent = currentIdentity == snapshot.fileIdentity
            && currentIdentity?.isDirectory == true
            && (diagnosticEvaluation?.identityCurrent ?? true)
        let userOwned = identityCurrent
            && currentIdentity?.ownerUserID == getuid()
        let activity = diagnosticEvaluation?.activity
            ?? activityProvider.evaluate(
                subjects: profile.processSubjects,
                context: activityContext
            )
        var satisfied: [DomainToken] = []
        if staticAttested {
            satisfied.append(contentsOf: profile.resolverBindings.compactMap {
                $0.resolver == .compilerAttested ? $0.key : nil
            })
        }
        if userOwned {
            satisfied.append(contentsOf: profile.resolverBindings.compactMap {
                $0.resolver == .currentFilesystem ? $0.key : nil
            })
        }
        if activity.observation.state == .satisfied {
            satisfied.append(contentsOf: profile.resolverBindings.compactMap {
                $0.resolver == .currentActivity ? $0.key : nil
            })
        }
        satisfied = Array(Set(satisfied)).sorted {
            $0.rawValue < $1.rawValue
        }
        let evidenceRecords = profile.resolverBindings.map { binding in
            let diagnosticActivity =
                binding.resolver == .currentActivity
                && activity.observation.reason.rawValue.hasPrefix(
                    "activity.process.isolated-diagnostic-"
                )
            let state = diagnosticActivity
                ? evidenceState(
                    binding: binding,
                    identityCurrent: identityCurrent,
                    activity: activity.observation
                )
                : satisfied.contains(binding.key)
                ? "satisfied"
                : evidenceState(
                    binding: binding,
                    identityCurrent: identityCurrent,
                    activity: activity.observation
                )
            let sourceKind = evidenceSourceKind(binding.resolver)
            return EvidenceRecord(
                id: evidenceID(snapshot.id, binding.key),
                targetID: snapshot.id,
                kind: evidenceKind(binding.resolver),
                source: EvidenceSource(
                    kind: sourceKind,
                    identifier: DomainToken(
                        rawValue:
                            "execution.ah.nopii.\(binding.resolver.rawValue).\(binding.key.rawValue)"
                    )!
                ),
                summaryKey: DomainToken(
                    rawValue:
                        "execution.\(binding.key.rawValue).\(state)"
                )!,
                observedAt: evidenceObservedAt(
                    binding.resolver,
                    snapshot: snapshot,
                    activity: activity.observation
                ),
                freshness: .current
            )
        }.sorted { $0.source.identifier.rawValue < $1.source.identifier.rawValue }
        let evidenceFingerprint = fingerprint(
            prefix: "evidence",
            lines: [
                profileCatalogVersion.rawValue,
                profile.id.rawValue,
                rule.id.rawValue,
                staticAttested.description,
                identityCurrent.description,
                identityFingerprintLine(currentIdentity),
            ] + evidenceRecords.map {
                [
                    $0.source.identifier.rawValue,
                    $0.summaryKey.rawValue,
                    $0.freshness.rawValue,
                ].joined(separator: "|")
            }
        )
        let currentActivityFingerprint = fingerprint(
            prefix: "activity",
            lines: [
                profile.id.rawValue,
                profile.ruleID.rawValue,
                profile.processSubjects.exactNames
                    .map(\.rawValue)
                    .joined(separator: ","),
                profile.processSubjects.versionedFamilies
                    .map(\.rawValue)
                    .joined(separator: ","),
                activity.matchedBundleIdentifiers
                    .map(\.rawValue)
                    .joined(separator: ","),
                activity.matchedProcessNames
                    .map(\.rawValue)
                    .joined(separator: ","),
                activity.observation.key.rawValue,
                activity.observation.state.rawValue,
                activity.observation.source.rawValue,
                activity.observation.reason.rawValue,
            ]
        )
        let requiredKeys = Set(
            rule.requiredEvidenceKeys + rule.requiredActivityKeys
        )
        let eligible = staticAttested
            && identityCurrent
            && requiredKeys.isSubset(of: Set(satisfied))
        return ExecutableEvidenceResolution(
            satisfiedEvidenceKeys: satisfied,
            activityObservations: [activity.observation],
            evidenceRecords: evidenceRecords,
            evidenceFingerprint: evidenceFingerprint,
            activityFingerprint: currentActivityFingerprint,
            isCurrentIdentity: identityCurrent,
            isEligible: eligible
        )
    }
}

private func evidenceObservedAt(
    _ resolver: ExecutionEvidenceResolver,
    snapshot: PathSnapshot,
    activity: ActivityObservation
) -> Date {
    resolver == .currentActivity
        ? activity.observedAt
        : snapshot.observedAt
}

private func evidenceKind(
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

private func evidenceSourceKind(
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

private func evidenceState(
    binding: ExecutionEvidenceBinding,
    identityCurrent: Bool,
    activity: ActivityObservation
) -> String {
    switch binding.resolver {
    case .compilerAttested:
        "unavailable"
    case .currentFilesystem:
        identityCurrent ? "contradicted" : "identity-drift"
    case .currentActivity:
        activity.reason.rawValue.hasPrefix(
            "activity.process.isolated-diagnostic-"
        )
            ? String(
                activity.reason.rawValue.dropFirst(
                    "activity.process.".count
                )
            )
            : activity.state.rawValue
    }
}

private func fingerprint(
    prefix: String,
    lines: [String]
) -> DomainToken {
    let payload = lines.sorted().joined(separator: "\n")
    let hash = SHA256.hash(data: Data(payload.utf8))
        .map { String(format: "%02x", $0) }
        .joined()
    return DomainToken(rawValue: "\(prefix).\(hash)")!
}

private func identityFingerprintLine(_ identity: FileIdentity?) -> String {
    guard let identity else {
        return "identity.unavailable"
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

private struct PhaseCTrashDiagnosticEvaluation {
    let activity: RunningActivityResult
    let identityCurrent: Bool
}

#if DEBUG
private enum PhaseCTrashDiagnosticAttestationError: Error {
    case invalidNonce
    case invalidLayout
    case invalidIdentity
    case invalidProfile
    case invalidMarker
}

private struct PhaseCTrashDiagnosticAttestation: Sendable {
    private let diagnosticRootURL: URL
    private let fixtureRootURL: URL
    private let npmRootURL: URL
    private let targetURL: URL
    private let rootMarkerURL: URL
    private let targetMarkerURL: URL
    private let nonce: String
    private let expectedRootIdentity: FileIdentity
    private let expectedFixtureIdentity: FileIdentity
    private let expectedNPMIdentity: FileIdentity
    private let expectedTargetIdentity: FileIdentity
    private let expectedTemporaryIdentity: FileIdentity
    private let expectedProfile: ExecutionProfile
    private let expectedProfileCatalogVersion: DomainToken

    init(
        diagnosticRootURL: URL,
        fixtureRootURL: URL,
        nonce: String,
        expectedTargetIdentity: FileIdentity,
        expectedProfile: ExecutionProfile,
        expectedProfileCatalogVersion: DomainToken
    ) throws {
        guard UUID(uuidString: nonce) != nil else {
            throw PhaseCTrashDiagnosticAttestationError.invalidNonce
        }
        let root = diagnosticRootURL.standardizedFileURL
        let fixture = fixtureRootURL.standardizedFileURL
        let npm = fixture.appending(
            path: ".npm",
            directoryHint: .isDirectory
        )
        let target = npm.appending(
            path: "_cacache",
            directoryHint: .isDirectory
        )
        let temporary =
            FileManager.default.temporaryDirectory.standardizedFileURL
        guard fixture == root.appending(
            path: "fixture",
            directoryHint: .isDirectory
        ),
        root.lastPathComponent.hasPrefix("stornaut-phase-c-trash.")
        else {
            throw PhaseCTrashDiagnosticAttestationError.invalidLayout
        }
        guard
        let rootIdentity = FileIdentity.read(at: root),
        let fixtureIdentity = FileIdentity.read(at: fixture),
        let npmIdentity = FileIdentity.read(at: npm),
        let targetIdentity = FileIdentity.read(at: target),
        let temporaryIdentity = FileIdentity.read(at: temporary),
        sameFileObject(
            FileIdentity.read(at: root.deletingLastPathComponent()),
            temporaryIdentity
        ),
        privateDiagnosticDirectory(rootIdentity),
        privateDiagnosticDirectory(fixtureIdentity),
        privateDiagnosticDirectory(npmIdentity),
        privateDiagnosticDirectory(targetIdentity),
        targetIdentity == expectedTargetIdentity
        else {
            throw PhaseCTrashDiagnosticAttestationError.invalidIdentity
        }
        guard
        expectedProfile.id.rawValue == "phase-c.npm-cacache-v1",
        expectedProfile.ruleID.rawValue == "cache-npm-content",
        expectedProfile.relativePath.rawValue == ".npm/_cacache",
        expectedProfileCatalogVersion.rawValue == "safe-execution-v1"
        else {
            throw PhaseCTrashDiagnosticAttestationError.invalidProfile
        }
        self.diagnosticRootURL = root
        self.fixtureRootURL = fixture
        npmRootURL = npm
        targetURL = target
        rootMarkerURL = root.appending(
            path: ".stornaut-phase-c-trash-fixture-\(nonce)"
        )
        targetMarkerURL = target.appending(
            path: ".stornaut-phase-c-trash-item-\(nonce)"
        )
        self.nonce = nonce
        expectedRootIdentity = rootIdentity
        expectedFixtureIdentity = fixtureIdentity
        expectedNPMIdentity = npmIdentity
        self.expectedTargetIdentity = expectedTargetIdentity
        expectedTemporaryIdentity = temporaryIdentity
        self.expectedProfile = expectedProfile
        self.expectedProfileCatalogVersion =
            expectedProfileCatalogVersion
        guard markerContentsAreCurrent else {
            throw PhaseCTrashDiagnosticAttestationError.invalidMarker
        }
    }

    func evaluate(
        snapshot: PathSnapshot,
        currentIdentity: FileIdentity?,
        rule: CompiledRule,
        profile: ExecutionProfile,
        profileCatalogVersion: DomainToken,
        observedAt: Date
    ) -> PhaseCTrashDiagnosticEvaluation {
        let currentTargetIdentity = FileIdentity.read(at: targetURL)
        let identityCurrent = currentTargetIdentity
            == expectedTargetIdentity
            && currentIdentity == expectedTargetIdentity
            && snapshot.fileIdentity == expectedTargetIdentity
        let contractCurrent = profile == expectedProfile
            && profileCatalogVersion
                == expectedProfileCatalogVersion
            && rule.id == expectedProfile.ruleID
            && rule.match.pathPattern
                == expectedProfile.relativePath
            && rule.match.expectedKind
                == expectedProfile.expectedKind
            && snapshot.relativePath
                == expectedProfile.relativePath.rawValue
        let rootCurrent = sameDiagnosticDirectory(
            diagnosticRootURL,
            expectedRootIdentity
        ) && sameDiagnosticDirectory(
            fixtureRootURL,
            expectedFixtureIdentity
        ) && sameDiagnosticDirectory(
            npmRootURL,
            expectedNPMIdentity
        ) && sameFileObject(
            FileIdentity.read(
                at: diagnosticRootURL.deletingLastPathComponent()
            ),
            expectedTemporaryIdentity
        )
        let targetCurrent = identityCurrent
            && privateDiagnosticDirectory(
                currentTargetIdentity
            )
        let markersCurrent = markerContentsAreCurrent
        let reason: String
        let state: ActivityEvidenceState
        if !contractCurrent {
            reason =
                "activity.process.isolated-diagnostic-contract-drift"
            state = .unavailable
        } else if !rootCurrent {
            reason =
                "activity.process.isolated-diagnostic-root-drift"
            state = .unavailable
        } else if !targetCurrent {
            reason =
                "activity.process.isolated-diagnostic-identity-drift"
            state = .unavailable
        } else if !markersCurrent {
            reason =
                "activity.process.isolated-diagnostic-marker-drift"
            state = .unavailable
        } else {
            reason =
                "activity.process.isolated-diagnostic-attested"
            state = .satisfied
        }
        let observation = try! ActivityObservation(
            key: .processInactive,
            state: state,
            source: .runningProcess,
            origin: .stornaut,
            observedAt: observedAt,
            reason: DomainToken(rawValue: reason)!
        )
        return PhaseCTrashDiagnosticEvaluation(
            activity: RunningActivityResult(
                status: state == .satisfied
                    ? .available
                    : .unavailable(.invalidInput),
                observation: observation,
                matchedBundleIdentifiers: [],
                matchedProcessNames: []
            ),
            identityCurrent: identityCurrent
        )
    }

    private var markerContentsAreCurrent: Bool {
        exactMarker(
            at: rootMarkerURL,
            expected: "stornaut-phase-c-root:\(nonce)"
        ) && exactMarker(
            at: targetMarkerURL,
            expected: "stornaut-phase-c-trash-item:\(nonce)"
        )
    }
}

private func privateDiagnosticDirectory(
    _ identity: FileIdentity?
) -> Bool {
    guard let identity else {
        return false
    }
    return identity.isDirectory
        && !identity.isSymbolicLink
        && identity.ownerUserID == getuid()
        && mode_t(identity.mode) & 0o777 == 0o700
        && identity.linkCount >= 1
}

private func sameDiagnosticDirectory(
    _ url: URL,
    _ expected: FileIdentity
) -> Bool {
    guard let current = FileIdentity.read(at: url) else {
        return false
    }
    return privateDiagnosticDirectory(current)
        && sameFileObject(current, expected)
}

private func sameFileObject(
    _ current: FileIdentity?,
    _ expected: FileIdentity
) -> Bool {
    current?.device == expected.device
        && current?.inode == expected.inode
}

private func exactMarker(
    at url: URL,
    expected: String
) -> Bool {
    guard let identity = FileIdentity.read(at: url),
          identity.isRegularFile,
          !identity.isSymbolicLink,
          identity.ownerUserID == getuid(),
          identity.linkCount == 1,
          identity.size >= 0,
          identity.size <= 4_096,
          mode_t(identity.mode) & 0o022 == 0,
          let data = try? Data(
              contentsOf: url,
              options: .mappedIfSafe
          ),
          data.count == expected.utf8.count
    else {
        return false
    }
    return data == Data(expected.utf8)
}
#endif
