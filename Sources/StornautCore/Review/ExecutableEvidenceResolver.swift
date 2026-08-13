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

    private let activityProvider: RunningActivityProvider
    private let identityReader: IdentityReader

    public init(
        activityProvider: RunningActivityProvider = RunningActivityProvider(),
        identityReader: @escaping IdentityReader = FileIdentity.read(at:)
    ) {
        self.activityProvider = activityProvider
        self.identityReader = identityReader
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
        let identityCurrent = currentIdentity == snapshot.fileIdentity
            && currentIdentity?.isDirectory == true
        let userOwned = identityCurrent
            && currentIdentity?.ownerUserID == getuid()
        let activity = activityProvider.evaluate(
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
            let state = satisfied.contains(binding.key)
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
        activity.state.rawValue
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
