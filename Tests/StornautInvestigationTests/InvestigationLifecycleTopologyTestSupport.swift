import Darwin
import Foundation
import Testing
@testable import StornautInvestigationMachine
import StornautInvestigation
@testable import StornautInvestigationRuntime
@testable import StornautLifecycle

struct LifecycleTopologyCollectorFixture {
    let contract: LifecycleLocalInstallationContract
    let investigationID = LifecycleInvestigationID(
        rawValue: UUID(
            uuidString: "12345678-1234-4234-8234-123456789abc"
        )!
    )
    let userID: UInt32 = 501
    let appIdentity: LifecycleProcessIdentity
    let helperIdentity: LifecycleProcessIdentity
    let binding: LifecycleRootTopologyBinding
    let signedBinding: SignedInvestigationRuntimeBinding
    let clock = TopologyCollectorClock(
        now: Date(timeIntervalSince1970: 1_900_000_000)
    )

    init() throws {
        contract = try LifecycleLocalInstallationContract()
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
        let appSigning = try LifecycleSigningIdentity(
            signingIdentifier: contract.appBundleIdentifier,
            designatedRequirementSHA256:
                String(repeating: "a", count: 64),
            codeDirectoryHash: String(repeating: "1", count: 40)
        )
        let helperSigning = try LifecycleSigningIdentity(
            signingIdentifier:
                "com.eriklee.stornaut.lifecycle.helper",
            designatedRequirementSHA256:
                String(repeating: "b", count: 64),
            codeDirectoryHash: String(repeating: "2", count: 40)
        )
        binding = try LifecycleRootTopologyBinding(
            appSigningEvidence: try LifecycleBundleSigningEvidence(
                identity: appSigning,
                executableSHA256: String(repeating: "c", count: 64),
                isAdHoc: true
            ),
            helperSigningEvidence: try LifecycleBundleSigningEvidence(
                identity: helperSigning,
                executableSHA256: String(repeating: "d", count: 64),
                isAdHoc: true
            ),
            appBundleIdentifier: contract.appBundleIdentifier,
            helperServiceIdentifier: contract.label
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
            helperServiceIdentifier: contract.label
        )
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
        investigationID: LifecycleInvestigationID? = nil
    ) throws -> InvestigationLifecycleTopologyCollectionRequest {
        try InvestigationLifecycleTopologyCollectionRequest(
            investigationID: investigationID ?? self.investigationID,
            userID: userID,
            signedBinding: signedBinding,
            appProcessIdentity: appIdentity,
            openedAt: clock.read(),
            validBefore: clock.read().addingTimeInterval(30)
        )
    }

    func retirementEvidenceStore() async throws
        -> InvestigationLifecycleRetirementEvidenceStore
    {
        let now = clock.read()
        let operationID = UUID(
            uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        )!
        let configurationSHA256 = String(repeating: "a", count: 64)
        let session = CollectorLifecycleSession(
            helperIdentity: helperIdentity,
            helperAttestedAt: now,
            response: .retired(
                investigationID: investigationID,
                operationID: operationID,
                drained: true,
                ownerRetirementObservation: .retiredOwnedResources,
                machineRetirementHandle:
                    try LifecycleMachineRetirementHandle(
                        token: UUID(),
                        investigationID: investigationID,
                        retireOperationID: operationID,
                        configurationSHA256: configurationSHA256,
                        validBefore: now.addingTimeInterval(30)
                    ),
                residueObservation:
                    try LifecycleInvestigationResidueObservation(
                        investigationID: investigationID,
                        auditSessionID: helperIdentity.auditSessionID,
                        userID: userID,
                        observedAt: now,
                        remainingAuditSessionMemberCount: 0,
                        matchingLeaseCount: 0,
                        leaseRootEntryCount: 0,
                        investigationArtifactCount: 0
                    )
            )
        )
        let store = InvestigationLifecycleRetirementEvidenceStore()
        let transport = try InvestigationLifecycleAppServerTransport(
            investigationID: investigationID,
            configurationSHA256: configurationSHA256,
            validBefore: now.addingTimeInterval(30),
            maximumLineBytes: 1_024,
            maximumSessionBytes: 8_192,
            expectedUserID: userID,
            now: clock.read,
            operationID: { operationID },
            session: session,
            retirementEvidenceStore: store
        )
        _ = try await transport.retireWithEvidence()
        return store
    }

    func installedObservation() throws
        -> LifecycleRootTopologyObservation
    {
        try topologyObservation(phase: .installed)
    }

    func postTeardownObservation() throws
        -> LifecycleRootTopologyObservation
    {
        try topologyObservation(phase: .postTeardown)
    }

    private func topologyObservation(
        phase: LifecycleRootTopologyPhase
    ) throws -> LifecycleRootTopologyObservation {
        let processResults: [LifecycleRootTopologyProcessReadResult]
        let serviceResult: LifecycleRootTopologyServiceProbeResult
        if phase == .installed {
            processResults = [
                .observed(LifecycleRootTopologyProcessSnapshot(
                    identity: appIdentity,
                    executableURL: contract.appExecutableURL,
                    signingIdentity:
                        binding.appSigningEvidence.identity
                )),
                .observed(LifecycleRootTopologyProcessSnapshot(
                    identity: helperIdentity,
                    executableURL: contract.helperExecutableURL,
                    signingIdentity:
                        binding.helperSigningEvidence.identity
                )),
            ]
            serviceResult = .loaded(identity: helperIdentity)
        } else {
            processResults = [.absent, .absent]
            serviceResult = .absent
        }
        let now = clock.read()
        return try LifecycleRootTopologyObserver(
            artifactReader: FixedTopologyArtifactReader(phase: phase),
            processReader: ScriptedTopologyProcessReader(
                results: processResults
            ),
            serviceProbe: FixedTopologyServiceProbe(
                result: serviceResult
            ),
            now: { now }
        ).observe(
            try LifecycleRootTopologyObservationRequest(
                phase: phase,
                binding: binding,
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
                effectiveUserID, 0, 0, effectiveUserID, 0,
                UInt32(processID), UInt32(auditSessionID),
                UInt32(processIDVersion),
            ])
        )
    }
}

private struct FixedTopologyArtifactReader:
    LifecycleRootTopologyArtifactReading
{
    let phase: LifecycleRootTopologyPhase

    func observe(
        _ role: LifecycleRootTopologyArtifactRole,
        contract _: LifecycleLocalInstallationContract,
        binding _: LifecycleRootTopologyBinding
    ) -> LifecycleRootTopologyArtifactObservation {
        if phase == .postTeardown {
            return .absent
        }
        switch role {
        case .runtimeRoot, .leaseRoot:
            return .absent
        default:
            return .presentValid
        }
    }
}

private final class ScriptedTopologyProcessReader:
    LifecycleRootTopologyProcessReading,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var results: [LifecycleRootTopologyProcessReadResult]

    init(results: [LifecycleRootTopologyProcessReadResult]) {
        self.results = results
    }

    func read(
        processID _: pid_t
    ) -> LifecycleRootTopologyProcessReadResult {
        lock.withLock { results.removeFirst() }
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

private actor CollectorLifecycleSession:
    LifecycleInteractiveSessionEvidenceSending
{
    private let helperIdentity: LifecycleProcessIdentity
    private let helperAttestedAt: Date
    private let response: LifecycleInteractiveSessionResponse
    private var peer: LifecycleConnectedHelperPeer?

    init(
        helperIdentity: LifecycleProcessIdentity,
        helperAttestedAt: Date,
        response: LifecycleInteractiveSessionResponse
    ) {
        self.helperIdentity = helperIdentity
        self.helperAttestedAt = helperAttestedAt
        self.response = response
    }

    func freshAttestedHelperPeer() -> LifecycleConnectedHelperPeer {
        let value = LifecycleConnectedHelperPeer(
            identity: helperIdentity,
            attestedAt: helperAttestedAt
        )
        peer = value
        return value
    }

    func send(
        _ request: LifecycleInteractiveSessionRequest
    ) async throws -> LifecycleInteractiveSessionResponse {
        _ = freshAttestedHelperPeer()
        return try response.validated(for: request)
    }

    func takeRetirementHelperPeer(
        operationID _: UUID
    ) -> LifecycleConnectedHelperPeer? {
        defer { peer = nil }
        return peer
    }
}
