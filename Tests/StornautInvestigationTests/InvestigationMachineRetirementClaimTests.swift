import Darwin
import Foundation
import Testing
import StornautInvestigation
@testable import StornautInvestigationMachine
@testable import StornautLifecycle

@Suite("Investigation machine retirement claim")
struct InvestigationMachineRetirementClaimTests {
    @Test
    func nonRootIsRejectedBeforeSource() async throws {
        let fixture = try ClaimFixture()
        let source = try fixture.source()
        let claimant = fixture.claimant(
            source: source,
            effectiveUserID: { 501 }
        )

        await expectClaimError(.rootAuthorityRequired) {
            try await claimant.claim(handle: fixture.handle)
        }
        #expect(source.fetchCount == 0)
    }

    @Test
    func validClaimUsesFreshChallengeAndBoundedWindow() async throws {
        let fixture = try ClaimFixture()
        let source = try fixture.source()
        let claimant = fixture.claimant(source: source)
        let first = try await claimant.claim(handle: fixture.handle)

        #expect(first.userID == fixture.userID)
        #expect(first.ownerRetirementObservation
            == .retiredOwnedResources)
        #expect(first.residueObservation.provedEmpty)
        #expect(source.fetchCount == 1)
        let request = try #require(source.requestSnapshot.first)
        #expect(request.challengeNonce == fixture.challenge)
        #expect(request.validBefore.timeIntervalSince(request.issuedAt) == 15)
    }

    @Test
    func foreignResponseIsRejected() async throws {
        let fixture = try ClaimFixture()
        let foreign = try ClaimFixture(
            investigationID: LifecycleInvestigationID(rawValue: UUID())
        )
        let source = try foreign.source(
            responseRequest: try foreign.request()
        )
        let claimant = fixture.claimant(source: source)

        await expectClaimError(.responseMismatch) {
            try await claimant.claim(handle: fixture.handle)
        }
    }

    @Test
    func staleResponseIsRejected() async throws {
        let fixture = try ClaimFixture()
        let clock = MutableClaimClock(now: fixture.now)
        let source = try fixture.source(afterFetch: {
            clock.set(fixture.now.addingTimeInterval(16))
        }, now: clock.read)
        let claimant = fixture.claimant(source: source, now: clock.read)

        await expectClaimError(.staleClaim) {
            try await claimant.claim(handle: fixture.handle)
        }
    }

    @Test
    func lateClaimUsesTheRemainingHandleWindow() async throws {
        let fixture = try ClaimFixture()
        let clock = MutableClaimClock(
            now: fixture.now.addingTimeInterval(10)
        )
        let source = try fixture.source(now: clock.read)
        let claimant = fixture.claimant(source: source, now: clock.read)

        _ = try await claimant.claim(handle: fixture.handle)

        let request = try #require(source.requestSnapshot.first)
        #expect(request.validBefore == fixture.handle.validBefore)
        #expect(
            request.validBefore.timeIntervalSince(request.issuedAt) == 5
        )
    }

    @Test
    func staleHelperAttestationIsRejected() async throws {
        let fixture = try ClaimFixture()
        let source = ClaimSource(
            escrow: try fixture.makeEscrow(),
            helperPeerIdentity: fixture.helperPeerIdentity,
            helperAttestedAt: fixture.now.addingTimeInterval(-1)
        )
        let claimant = fixture.claimant(source: source)

        await #expect(
            throws: InvestigationMachineRetirementClaimError.staleClaim
        ) {
            _ = try await claimant.claim(handle: fixture.handle)
        }
    }

    @Test
    func cancellationWinsWhenFetchReturnsATransportFailure() async throws {
        let fixture = try ClaimFixture()
        let source = SuspendedFailingClaimSource()
        let claimant = fixture.claimant(source: source)
        let task = Task {
            try await claimant.claim(handle: fixture.handle)
        }

        await source.waitUntilFetched()
        task.cancel()
        await source.fail()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }

    @Test
    func helperAndAppMismatchesAreRejected() async throws {
        let fixture = try ClaimFixture()
        let foreign = try ClaimFixture(
            appProcessID: 703,
            helperProcessID: 704
        )
        let mismatchedHelper = foreign.lifecycleIdentity
        let mismatchedSource = try fixture.source(
            helperPeerIdentity: mismatchedHelper
        )
        let mismatchClaimant = fixture.claimant(source: mismatchedSource)
        await expectClaimError(.helperPeerMismatch) {
            try await mismatchClaimant.claim(handle: fixture.handle)
        }

        let appSource = try fixture.source(appIdentity: foreign.appIdentity)
        let appClaimant = fixture.claimant(source: appSource)
        await expectClaimError(.identityMismatch) {
            try await appClaimant.claim(handle: fixture.handle)
        }
    }

    @Test
    func replayAndEmptyStoreAreTerminalAndClaimIsNotCodable() async throws {
        let fixture = try ClaimFixture()
        let source = try fixture.source()
        let claim = try await fixture.claimant(source: source)
            .claim(handle: fixture.handle)
        let store = InvestigationMachineRetirementClaimStore()

        await expectStoreError(.empty, operation: { try await store.consume() })
        #expect(!(InvestigationMachineRetirementClaim.self is any Codable.Type))

        let secondStore = InvestigationMachineRetirementClaimStore()
        try await secondStore.record(claim)
        let copiedStore = InvestigationMachineRetirementClaimStore()
        await expectStoreError(.consumed, operation: {
            try await copiedStore.record(claim)
        })
        #expect(await secondStore.isAwaitingClaim)
        let consumed = try await secondStore.consume()
        #expect(consumed == claim)
        #expect(!(await secondStore.isAwaitingClaim))
        await expectStoreError(.consumed, operation: {
            try await secondStore.consume()
        })
        await expectStoreError(.consumed, operation: {
            try await secondStore.record(claim)
        })
    }
}

private func expectClaimError<T>(
    _ expected: InvestigationMachineRetirementClaimError,
    operation: () async throws -> T
) async {
    do {
        _ = try await operation()
        Issue.record("Expected retirement claim error \(expected)")
    } catch let error as InvestigationMachineRetirementClaimError {
        #expect(error == expected)
    } catch {
        Issue.record("Unexpected retirement claim error: \(error)")
    }
}

private func expectStoreError<T>(
    _ expected: InvestigationMachineRetirementClaimError,
    operation: () async throws -> T
) async {
    await expectClaimError(expected, operation: operation)
}

private final class ClaimSource: InvestigationMachineRetirementClaimSource,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let escrow: LifecycleMachineRetirementEscrow
    private let responseRequest: LifecycleMachineRetirementClaimRequest?
    private let storedHelperPeerIdentity: LifecycleProcessIdentity
    private let helperAttestedAt: Date?
    private var storedRequests: [LifecycleMachineRetirementClaimRequest] = []

    init(
        escrow: LifecycleMachineRetirementEscrow,
        responseRequest: LifecycleMachineRetirementClaimRequest? = nil,
        helperPeerIdentity: LifecycleProcessIdentity,
        helperAttestedAt: Date? = nil,
        afterFetch: (@Sendable () -> Void)? = nil
    ) {
        self.escrow = escrow
        self.responseRequest = responseRequest
        storedHelperPeerIdentity = helperPeerIdentity
        self.helperAttestedAt = helperAttestedAt
        self.afterFetch = afterFetch
    }

    private let afterFetch: (@Sendable () -> Void)?

    var fetchCount: Int { lock.withLock { storedRequests.count } }

    var requestSnapshot: [LifecycleMachineRetirementClaimRequest] {
        lock.withLock { storedRequests }
    }

    func fetch(
        request: LifecycleMachineRetirementClaimRequest
    ) async throws -> (
        LifecycleMachineRetirementClaimResponse,
        LifecycleProcessIdentity,
        Date
    ) {
        lock.withLock { storedRequests.append(request) }
        let response = try escrow.claim(
            responseRequest ?? request,
            authorized: true
        )
        afterFetch?()
        return (
            response,
            storedHelperPeerIdentity,
            helperAttestedAt ?? request.issuedAt
        )
    }
}

private actor SuspendedFailingClaimSource:
    InvestigationMachineRetirementClaimSource
{
    private struct TransportFailure: Error {}

    private var fetchContinuation:
        CheckedContinuation<
            (
                LifecycleMachineRetirementClaimResponse,
                LifecycleProcessIdentity,
                Date
            ),
            any Error
        >?
    private var fetchWaiters: [CheckedContinuation<Void, Never>] = []

    func fetch(
        request _: LifecycleMachineRetirementClaimRequest
    ) async throws -> (
        LifecycleMachineRetirementClaimResponse,
        LifecycleProcessIdentity,
        Date
    ) {
        fetchWaiters.forEach { $0.resume() }
        fetchWaiters.removeAll()
        return try await withCheckedThrowingContinuation {
            fetchContinuation = $0
        }
    }

    func waitUntilFetched() async {
        if fetchContinuation != nil { return }
        await withCheckedContinuation {
            fetchWaiters.append($0)
        }
    }

    func fail() {
        fetchContinuation?.resume(throwing: TransportFailure())
        fetchContinuation = nil
    }
}

private struct AcceptingHelperSignature:
    InvestigationMachineRetirementHelperSigningVerifying
{
    let accepted: LifecycleProcessIdentity

    func verifies(helperIdentity: LifecycleProcessIdentity) -> Bool {
        helperIdentity == accepted
    }
}

private final class ClaimFixture: @unchecked Sendable {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let investigationID: LifecycleInvestigationID
    let root: URL
    let configuration: SignedInvestigationRuntimeDiagnosticConfiguration
    let handle: LifecycleMachineRetirementHandle
    let challenge = UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-dddddddddddd")!
    let userID: UInt32 = 501
    let appIdentity: LifecycleMachineProcessIdentityRecord
    let helperIdentity: LifecycleMachineProcessIdentityRecord
    let helperPeerIdentity: LifecycleProcessIdentity
    var lifecycleIdentity: LifecycleProcessIdentity {
        helperPeerIdentity
    }

    init(
        investigationID: LifecycleInvestigationID = LifecycleInvestigationID(
            rawValue: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
        ),
        appProcessID: Int32 = 701,
        helperProcessID: Int32 = 702
    ) throws {
        self.investigationID = investigationID
        let resolvedTemporaryPath = try #require(
            realpath(FileManager.default.temporaryDirectory.path, nil)
        )
        defer { free(resolvedTemporaryPath) }
        root = URL(
            filePath: String(cString: resolvedTemporaryPath),
            directoryHint: .isDirectory
        ).appending(
            path: "stornaut-machine-claim-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
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
        appIdentity = try Self.record(
            processID: appProcessID,
            processIDVersion: 11,
            auditSessionID: 44_001,
            effectiveUserID: userID
        )
        helperIdentity = try Self.record(
            processID: helperProcessID,
            processIDVersion: 12,
            auditSessionID: 33_001,
            effectiveUserID: 0
        )
        helperPeerIdentity = try Self.lifecycleIdentity(
            processID: helperProcessID,
            processIDVersion: 12,
            auditSessionID: 33_001,
            effectiveUserID: 0
        )
        configuration = try SignedInvestigationRuntimeDiagnosticConfiguration(
            nonce: investigationID.rawValue,
            scenario: .success,
            optIn: SignedInvestigationRuntimeDiagnosticConfiguration.requiredOptIn,
            diagnosticRootPath: root.path,
            sourceRootPath: sourceRoot.path,
            supportRootPath: supportRoot.path,
            runtimeRootPath: runtimeRoot.path,
            reportPath: root.appending(path: "report.json").path,
            storePath: storeParent.appending(path: "Evidence.sqlite").path,
            binding: Self.signedBinding(),
            expectedModel: .gpt56Luna,
            expectedProvider: .openAI,
            validBefore: now.addingTimeInterval(30),
            maximumWallClockSeconds: 30,
            maximumTurns: 1,
            maximumProbeCalls: 1,
            maximumContextBytes: 1_024,
            now: now
        )
        handle = try LifecycleMachineRetirementHandle(
            token: UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!,
            investigationID: investigationID,
            retireOperationID: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!,
            configurationSHA256: configuration.machineConfigurationSHA256(),
            validBefore: now.addingTimeInterval(15)
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    func claimant(
        source: any InvestigationMachineRetirementClaimSource,
        effectiveUserID: @escaping @Sendable () -> uid_t = { 0 },
        now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 2_000_000_000) }
    ) -> InvestigationMachineRetirementClaimant {
        try! InvestigationMachineRetirementClaimant(
            source: source,
            signingVerifier: AcceptingHelperSignature(
                accepted: helperPeerIdentity
            ),
            effectiveUserID: effectiveUserID,
            now: now,
            challenge: { self.challenge },
            configuration: configuration,
            expectedAppIdentity: appIdentity,
            expectedUserID: userID
        )
    }

    func source(
        appIdentity: LifecycleMachineProcessIdentityRecord? = nil,
        helperPeerIdentity: LifecycleProcessIdentity? = nil,
        responseRequest: LifecycleMachineRetirementClaimRequest? = nil,
        afterFetch: (@Sendable () -> Void)? = nil,
        now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 2_000_000_000) }
    ) throws -> ClaimSource {
        let escrow = LifecycleMachineRetirementEscrow(
            now: now,
            token: { self.handle.token }
        )
        _ = try escrow.record(
            investigationID: investigationID,
            retireOperationID: handle.retireOperationID,
            configurationSHA256: handle.configurationSHA256,
            validBefore: handle.validBefore,
            appIdentity: appIdentity ?? self.appIdentity,
            helperIdentity: self.helperIdentity,
            userID: userID,
            ownerRetirementObservation: .retiredOwnedResources,
            residueObservation: residue()
        )
        return ClaimSource(
            escrow: escrow,
            responseRequest: responseRequest,
            helperPeerIdentity: helperPeerIdentity ?? self.helperPeerIdentity,
            afterFetch: afterFetch
        )
    }

    func makeEscrow() throws -> LifecycleMachineRetirementEscrow {
        let escrow = LifecycleMachineRetirementEscrow(
            now: { self.now },
            token: { self.handle.token }
        )
        _ = try escrow.record(
            investigationID: investigationID,
            retireOperationID: handle.retireOperationID,
            configurationSHA256: handle.configurationSHA256,
            validBefore: handle.validBefore,
            appIdentity: appIdentity,
            helperIdentity: helperIdentity,
            userID: userID,
            ownerRetirementObservation: .retiredOwnedResources,
            residueObservation: residue()
        )
        return escrow
    }

    func residue() throws -> LifecycleInvestigationResidueObservation {
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
    }

    func request() throws -> LifecycleMachineRetirementClaimRequest {
        try LifecycleMachineRetirementClaimRequest(
            handle: handle,
            challengeNonce: challenge,
            issuedAt: now,
            validBefore: now.addingTimeInterval(15)
        )
    }

    private static func record(
        processID: Int32,
        processIDVersion: Int32,
        auditSessionID: Int32,
        effectiveUserID: UInt32
    ) throws -> LifecycleMachineProcessIdentityRecord {
        try LifecycleMachineProcessIdentityRecord(
            processID: processID,
            processIDVersion: processIDVersion,
            auditSessionID: auditSessionID,
            effectiveUserID: effectiveUserID,
            auditTokenWords: [
                effectiveUserID, effectiveUserID, 0,
                effectiveUserID, 0,
                UInt32(processID), UInt32(auditSessionID),
                UInt32(processIDVersion),
            ]
        )
    }

    private static func signedBinding()
        -> SignedInvestigationRuntimeBinding
    {
        SignedInvestigationRuntimeBinding(
            repositoryHEAD: String(repeating: "1", count: 40),
            sourceFingerprintSHA256: String(repeating: "2", count: 64),
            appExecutableSHA256: String(repeating: "3", count: 64),
            helperExecutableSHA256: String(repeating: "4", count: 64),
            runtimeReceiptSHA256: String(repeating: "5", count: 64),
            promptSHA256: String(repeating: "6", count: 64),
            envelopeSchemaSHA256: String(repeating: "7", count: 64),
            facadeSHA256: String(repeating: "8", count: 64),
            codexExecutableSHA256: String(repeating: "9", count: 64),
            appBundleIdentifier: "com.eriklee.stornaut",
            helperServiceIdentifier: "com.eriklee.stornaut.lifecycle",
            machineDriver: try! SignedInvestigationRuntimeMachineDriverBinding(
                executableSHA256: String(repeating: "a", count: 64),
                signingIdentifier:
                    "com.eriklee.stornaut.investigation.machine-driver",
                designatedRequirementSHA256:
                    String(repeating: "b", count: 64),
                codeDirectoryHash: String(repeating: "4", count: 40),
                machineClaimServiceIdentifier:
                    "com.eriklee.stornaut.lifecycle.machine-claim"
            )
        )
    }

    private static func lifecycleIdentity(
        processID: Int32,
        processIDVersion: Int32,
        auditSessionID: Int32,
        effectiveUserID: UInt32
    ) throws -> LifecycleProcessIdentity {
        LifecycleProcessIdentity(
            processID: processID,
            processIDVersion: processIDVersion,
            auditSessionID: auditSessionID,
            effectiveUserID: effectiveUserID,
            auditToken: try LifecycleAuditToken(words: [
                effectiveUserID, 0, 0, effectiveUserID, 0,
                UInt32(processID), UInt32(auditSessionID),
                UInt32(processIDVersion),
            ])
        )
    }
}

private final class MutableClaimClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(now: Date) { value = now }

    func read() -> Date { lock.withLock { value } }

    func set(_ now: Date) { lock.withLock { value = now } }
}

private extension LifecycleMachineProcessIdentityRecord {
    func lifecycleIdentityForTests() throws -> LifecycleProcessIdentity {
        LifecycleProcessIdentity(
            processID: processID,
            processIDVersion: processIDVersion,
            auditSessionID: auditSessionID,
            effectiveUserID: effectiveUserID,
            auditToken: try LifecycleAuditToken(words: auditTokenWords)
        )
    }
}
