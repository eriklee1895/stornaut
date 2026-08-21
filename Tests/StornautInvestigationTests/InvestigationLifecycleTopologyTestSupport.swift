import Darwin
import Foundation
import Testing
import StornautCodex
@testable import StornautInvestigationMachine
import StornautInvestigation
@testable import StornautInvestigationRuntime
@testable import StornautLifecycle

final class LifecycleTopologyCollectorFixture: @unchecked Sendable {
    let contract: LifecycleLocalInstallationContract
    let investigationID: LifecycleInvestigationID
    let userID: UInt32 = 501
    let appIdentity: LifecycleProcessIdentity
    let helperIdentity: LifecycleProcessIdentity
    let signedBinding: SignedInvestigationRuntimeBinding
    let root: URL
    let configuration: SignedInvestigationRuntimeDiagnosticConfiguration
    let clock = TopologyCollectorClock(
        now: Date(timeIntervalSince1970: 1_900_000_000)
    )

    init(
        investigationID: LifecycleInvestigationID =
            LifecycleInvestigationID(
                rawValue: UUID(
                    uuidString:
                        "12345678-1234-4234-8234-123456789abc"
                )!
            )
    ) throws {
        self.investigationID = investigationID
        contract = try LifecycleLocalInstallationContract()
        let resolvedTemporaryPath = try #require(
            realpath(FileManager.default.temporaryDirectory.path, nil)
        )
        defer { free(resolvedTemporaryPath) }
        root = URL(
            filePath: String(cString: resolvedTemporaryPath),
            directoryHint: .isDirectory
        ).appending(
            path: "stornaut-topology-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        appIdentity = Self.identity(
            processID: 701,
            processIDVersion: 11,
            auditSessionID: 44_001,
            effectiveUserID: 501
        )
        helperIdentity = Self.identity(
            processID: 702,
            processIDVersion: 12,
            auditSessionID: 33_001,
            effectiveUserID: 0
        )
        signedBinding = SignedInvestigationRuntimeBinding(
            repositoryHEAD: String(repeating: "1", count: 40),
            sourceFingerprintSHA256: String(repeating: "2", count: 64),
            appExecutableSHA256: String(repeating: "c", count: 64),
            helperExecutableSHA256: String(repeating: "d", count: 64),
            runtimeReceiptSHA256: String(repeating: "3", count: 64),
            promptSHA256: String(repeating: "4", count: 64),
            envelopeSchemaSHA256: String(repeating: "5", count: 64),
            facadeSHA256: String(repeating: "6", count: 64),
            codexExecutableSHA256: String(repeating: "7", count: 64),
            appBundleIdentifier: contract.appBundleIdentifier,
            helperServiceIdentifier: contract.label,
            machineDriver: try SignedInvestigationRuntimeMachineDriverBinding(
                executableSHA256: String(repeating: "8", count: 64),
                signingIdentifier:
                    contract.machineDriverSigningIdentifier,
                designatedRequirementSHA256:
                    String(repeating: "9", count: 64),
                codeDirectoryHash: String(repeating: "3", count: 40),
                machineClaimServiceIdentifier:
                    contract.machineClaimMachServiceName
            )
        )
        configuration = try Self.configuration(
            root: root,
            nonce: investigationID.rawValue,
            binding: signedBinding,
            now: clock.read()
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    func processIdentity(
        processID: pid_t,
        processIDVersion: Int32,
        auditSessionID: Int32,
        effectiveUserID: uid_t
    ) -> LifecycleProcessIdentity {
        Self.identity(
            processID: processID,
            processIDVersion: processIDVersion,
            auditSessionID: auditSessionID,
            effectiveUserID: effectiveUserID
        )
    }

    func collectionRequest(
        configuration:
            SignedInvestigationRuntimeDiagnosticConfiguration? = nil
    ) throws -> InvestigationLifecycleTopologyCollectionRequest {
        try InvestigationLifecycleTopologyCollectionRequest(
            userID: userID,
            configuration: configuration ?? self.configuration,
            appProcessIdentity: appIdentity,
            openedAt: clock.read(),
            validBefore: clock.read().addingTimeInterval(30)
        )
    }

    func retirementClaimStore(
        helperPeerIdentityOverride: LifecycleProcessIdentity? = nil
    ) async throws
        -> InvestigationMachineRetirementClaimStore
    {
        let now = clock.read()
        let operationID = UUID(
            uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        )!
        let handle = try LifecycleMachineRetirementHandle(
            token: UUID(
                uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
            )!,
            investigationID: investigationID,
            retireOperationID: operationID,
            configurationSHA256: configuration.machineConfigurationSHA256(),
            validBefore: now.addingTimeInterval(30)
        )
        let residueObservedAt = now.addingTimeInterval(-4)
        let recordedAt = now.addingTimeInterval(-3)
        let claimIssuedAt = now.addingTimeInterval(-2)
        let claimCompletedAt = now.addingTimeInterval(-1)
        let request = try LifecycleMachineRetirementClaimRequest(
            handle: handle,
            challengeNonce: UUID(
                uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
            )!,
            issuedAt: claimIssuedAt,
            validBefore: now.addingTimeInterval(13)
        )
        let response = try LifecycleMachineRetirementClaimResponse(
            request: request,
            appIdentity: try machineRecord(appIdentity),
            helperIdentity: try machineRecord(helperIdentity),
            userID: userID,
            recordedAt: recordedAt,
            claimedAt: claimCompletedAt,
            ownerRetirementObservation: .retiredOwnedResources,
            residueObservation: try LifecycleInvestigationResidueObservation(
                investigationID: investigationID,
                auditSessionID: helperIdentity.auditSessionID,
                userID: userID,
                observedAt: residueObservedAt,
                remainingAuditSessionMemberCount: 0,
                matchingLeaseCount: 0,
                leaseRootEntryCount: 0,
                investigationArtifactCount: 0
            )
        )
        let claim: InvestigationMachineRetirementClaim
        if let helperPeerIdentityOverride {
            claim = InvestigationMachineRetirementClaim(
                response: response,
                helperPeerIdentity: helperPeerIdentityOverride,
                helperPeerAttestedAt: claimIssuedAt
            )
        } else {
            let claimant = try InvestigationMachineRetirementClaimant(
                source: CollectorMachineClaimSource(
                    response: response,
                    helperIdentity: helperIdentity
                ),
                signingVerifier: CollectorHelperSigningVerifier(),
                effectiveUserID: { 0 },
                now: { claimIssuedAt },
                challenge: { request.challengeNonce },
                configuration: configuration,
                expectedAppIdentity: try machineRecord(appIdentity),
                expectedUserID: userID
            )
            claim = try await claimant.claim(handle: handle)
        }
        let store = InvestigationMachineRetirementClaimStore()
        try await store.record(claim)
        return store
    }

    private func machineRecord(
        _ identity: LifecycleProcessIdentity
    ) throws -> LifecycleMachineProcessIdentityRecord {
        try LifecycleMachineProcessIdentityRecord(
            processID: identity.processID,
            processIDVersion: identity.processIDVersion,
            auditSessionID: identity.auditSessionID,
            effectiveUserID: identity.effectiveUserID,
            auditTokenWords: identity.auditToken.words
        )
    }

    func configuration(
        nonce: UUID? = nil,
        binding: SignedInvestigationRuntimeBinding? = nil,
        scenario: SignedInvestigationRuntimeDiagnosticScenario = .success,
        rootOverride: URL? = nil
    ) throws -> SignedInvestigationRuntimeDiagnosticConfiguration {
        try Self.configuration(
            root: rootOverride ?? root,
            nonce: nonce ?? investigationID.rawValue,
            binding: binding ?? signedBinding,
            scenario: scenario,
            now: clock.read()
        )
    }

    private static func configuration(
        root: URL,
        nonce: UUID,
        binding: SignedInvestigationRuntimeBinding,
        scenario: SignedInvestigationRuntimeDiagnosticScenario = .success,
        now: Date
    ) throws -> SignedInvestigationRuntimeDiagnosticConfiguration {
        let sourceRoot = root.appending(
            path: "source",
            directoryHint: .isDirectory
        )
        let supportRoot = root.appending(
            path: "support",
            directoryHint: .isDirectory
        )
        let runtimeRoot = root.appending(
            path: "runtime",
            directoryHint: .isDirectory
        )
        let storeParent = supportRoot.appending(
            path: "com.eriklee.stornaut",
            directoryHint: .isDirectory
        )
        for directory in [root, sourceRoot, supportRoot, runtimeRoot, storeParent] {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        return try SignedInvestigationRuntimeDiagnosticConfiguration(
            nonce: nonce,
            scenario: scenario,
            optIn: SignedInvestigationRuntimeDiagnosticConfiguration.requiredOptIn,
            diagnosticRootPath: root.path,
            sourceRootPath: sourceRoot.path,
            supportRootPath: supportRoot.path,
            runtimeRootPath: runtimeRoot.path,
            reportPath: root.appending(path: "report.json").path,
            storePath: storeParent.appending(path: "Evidence.sqlite").path,
            binding: binding,
            expectedModel: .gpt56Luna,
            expectedProvider: .openAI,
            validBefore: now.addingTimeInterval(60),
            maximumWallClockSeconds: 30,
            maximumTurns: 1,
            maximumProbeCalls: 1,
            maximumContextBytes: 1_024,
            now: now
        )
    }

    func postTeardownObservation() throws
        -> LifecycleRootTopologyObservation
    {
        try topologyObservation()
    }

    func nonAbsentPostTeardownObservation() throws
        -> LifecycleRootTopologyObservation
    {
        try topologyObservation(
            processResults: [.absent, .absent],
            serviceResult: .unavailable(
                reasonKey: "runtime.topology.fixture-service-present"
            )
        )
    }

    private func topologyObservation(
        processResults: [LifecycleRootTopologyProcessObservation] = [
            .absent, .absent,
        ],
        serviceResult: LifecycleRootTopologyServiceProbeResult = .absent
    ) throws -> LifecycleRootTopologyObservation {
        let now = clock.read()
        return try LifecycleRootTopologyObserver(
            artifactReader: FixedTopologyArtifactReader(),
            processReader: ScriptedTopologyProcessReader(
                observations: processResults
            ),
            serviceProbe: FixedTopologyServiceProbe(
                result: serviceResult
            ),
            now: { now }
        ).observe(
            try LifecycleRootTopologyObservationRequest(
                appProcessIdentity: appIdentity,
                helperProcessIdentity: helperIdentity,
                window: LifecycleRootTopologyObservationWindow(
                    openedAt: now,
                    validBefore: now.addingTimeInterval(30)
                )
            )
        )
    }

    private static func identity(
        processID: pid_t,
        processIDVersion: Int32,
        auditSessionID: Int32,
        effectiveUserID: uid_t
    ) -> LifecycleProcessIdentity {
        LifecycleProcessIdentity(
            processID: processID,
            processIDVersion: processIDVersion,
            auditSessionID: auditSessionID,
            effectiveUserID: effectiveUserID,
            auditToken: try! LifecycleAuditToken(words: [
                effectiveUserID, effectiveUserID, 0,
                effectiveUserID, 0,
                UInt32(processID), UInt32(auditSessionID),
                UInt32(processIDVersion),
            ])
        )
    }
}

private struct FixedTopologyArtifactReader:
    LifecycleRootTopologyArtifactAbsenceReading
{
    func observeAbsence(
        _ role: LifecycleRootTopologyArtifactRole,
        contract _: LifecycleLocalInstallationContract
    ) -> LifecycleRootTopologyArtifactObservation {
        .absent
    }
}

private final class ScriptedTopologyProcessReader:
    LifecycleRootTopologyProcessAbsenceReading,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var observations: [LifecycleRootTopologyProcessObservation]

    init(observations: [LifecycleRootTopologyProcessObservation]) {
        self.observations = observations
    }

    func observeAbsence(
        of expectedIdentity: LifecycleProcessIdentity
    ) -> LifecycleRootTopologyProcessObservation {
        let _ = expectedIdentity
        return lock.withLock { observations.removeFirst() }
    }
}

private struct FixedTopologyServiceProbe:
    LifecycleRootTopologyServiceProbing
{
    let result: LifecycleRootTopologyServiceProbeResult

    func observeFixedService(
        label _: String
    ) -> LifecycleRootTopologyServiceProbeResult {
        result
    }
}

final class TopologyCollectorClock: @unchecked Sendable {
    private let lock = NSLock()
    private var now: Date

    init(now: Date) {
        self.now = now
    }

    func read() -> Date {
        lock.withLock { now }
    }

    func advance(_ interval: TimeInterval) {
        lock.withLock { now = now.addingTimeInterval(interval) }
    }
}

private struct CollectorMachineClaimSource:
    InvestigationMachineRetirementClaimSource
{
    let response: LifecycleMachineRetirementClaimResponse
    let helperIdentity: LifecycleProcessIdentity

    func fetch(
        request _: LifecycleMachineRetirementClaimRequest
    ) async throws -> (
        LifecycleMachineRetirementClaimResponse,
        LifecycleProcessIdentity,
        Date
    ) {
        (response, helperIdentity, response.request.issuedAt)
    }
}

private struct CollectorHelperSigningVerifier:
    InvestigationMachineRetirementHelperSigningVerifying
{
    func verifies(helperIdentity _: LifecycleProcessIdentity) -> Bool {
        true
    }
}
