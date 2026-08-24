import Foundation
import Testing
@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationInstalledL2
@testable import StornautInvestigationMachineDriverSupport

@Suite("Investigation machine single epoch physical bridge", .serialized)
struct InvestigationMachineSingleEpochPhysicalBridgeTests {
    @Test(arguments: InvestigationHandoffScenario.allCases)
    func invocationSelfContainedDecodeRemainsUntrustedAndCanonical(
        _ scenario: InvestigationHandoffScenario
    ) async throws {
        let fixture = try PhysicalBridgeFixture(
            ordinal: scenario.rawValue - 1
        )
        let invocation = try await fixture.invocation()
        let encoded = try invocation.encoded()

        let decoded = try InvestigationMachineSingleEpochInvocation
            .decodeUntrusted(encoded)

        #expect(decoded == invocation)
        #expect(decoded.selection == fixture.selection)
        #expect(try decoded.encoded() == encoded)
        #expect(!(type(of: decoded) is any Codable.Type))
        let wrongDomain = scenario == .success
            ? "stornaut.task39.machine.epoch-invocation.successor"
            : "stornaut.task39.machine.epoch-invocation.genesis"
        for mutation in try strictWireMutations(encoded) + [
            invocationWithDomain(invocation, wrongDomain),
        ] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationMachineSingleEpochInvocation
                    .decodeUntrusted(mutation)
            }
        }
    }

    @Test(arguments: PhysicalBridgeInvocationKind.allCases)
    fileprivate func invocationRoundTripsCanonicalPredecessor(
        _ kind: PhysicalBridgeInvocationKind
    ) async throws {
        let fixture = try PhysicalBridgeFixture(ordinal: kind.ordinal)
        let predecessor = try await fixture.predecessor()
        let invocation = try predecessor.invocation(for: fixture.selection)
        let expectedPrevious = kind == .successor
            ? try PhysicalBridgeFixture(ordinal: 0, cohort: fixture.cohort)
                .helperIdentity
            : nil

        #expect(invocation.selection == fixture.selection)
        #expect(invocation.previousHelperIdentity == expectedPrevious)
        #expect(invocation.predecessorSHA256 == predecessor.continuitySHA256)
        #expect(
            InvestigationHandoffSHA256.hashing(
                invocation.predecessorTranscript
            ) == invocation.predecessorSHA256
        )
        let encoded = try invocation.encoded()
        let decoded = try InvestigationMachineSingleEpochInvocation.decode(
            encoded, expectedSelection: fixture.selection
        )
        #expect(decoded == invocation)
        #expect(try decoded.encoded() == encoded)
    }

    @Test
    func invocationRejectsForeignSelectionTamperAndTrailingBytes() async throws {
        let fixture = try PhysicalBridgeFixture(ordinal: 1)
        let invocation = try await fixture.invocation()
        let encoded = try invocation.encoded()
        let foreign = try PhysicalBridgeFixture(ordinal: 1, cohort: .foreign)
        let wrongOrdinal = try PhysicalBridgeFixture(
            ordinal: 2, cohort: fixture.cohort
        )
        let foreignInvocation = try await foreign.invocation()
        let foreignBytes = try foreignInvocation.encoded()
        #expect(
            try InvestigationMachineSingleEpochInvocation.decodeUntrusted(
                foreignBytes
            ) == foreignInvocation
        )
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineSingleEpochInvocation.decode(
                foreignBytes, expectedSelection: fixture.selection
            )
        }

        for selection in [foreign.selection, wrongOrdinal.selection] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationMachineSingleEpochInvocation.decode(
                    encoded, expectedSelection: selection
                )
            }
        }
        let digestDrift = try replacingUniqueBusinessField(
            in: encoded, matching: invocation.predecessorSHA256.rawBytes,
            with: PhysicalBridgeFixture.digest(0xfe).rawBytes
        )
        let nestedTrailing = try invocationWithTrailingPredecessorByte(
            invocation
        )
        let zeroPreviousEpoch = try invocationWithPreviousEpochUUID(
            invocation, UUID(uuid: (
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
            ))
        )
        let reusedAttempt = try invocationWithPreviousEpochUUID(
            invocation, fixture.selection.outerAttemptUUID
        )
        let reusedNonce = try invocationWithPreviousEpochUUID(
            invocation, fixture.selection.epoch.configurationNonce
        )
        var outerTrailing = encoded
        outerTrailing.append(0xa5)
        let malformed = try strictWireMutations(encoded)
            + [
                digestDrift, nestedTrailing, zeroPreviousEpoch, reusedAttempt,
                reusedNonce, outerTrailing, Data(encoded.dropLast()),
                invocationWithDomain(
                    invocation,
                    "stornaut.task39.machine.epoch-invocation.genesis"
                ),
            ]
        for bytes in malformed {
            #expect(throws: (any Error).self) {
                _ = try InvestigationMachineSingleEpochInvocation
                    .decodeUntrusted(bytes)
            }
            #expect(throws: (any Error).self) {
                _ = try InvestigationMachineSingleEpochInvocation.decode(
                    bytes, expectedSelection: fixture.selection
                )
            }
        }
    }

    @Test
    func protocolDefaultForwardsLegacyHelperAndCompositionUsesFullInvocation() async throws {
        let successor = try PhysicalBridgeFixture(ordinal: 1)
        let successorInvocation = try await successor.invocation()
        let legacy = PhysicalBridgeLegacyComposer(
            selection: successor.selection, result: successor.localResult
        )
        #expect(
            try await legacy.run(invocation: successorInvocation)
                == successor.localResult
        )
        #expect(legacy.previousHelpers == [
            successorInvocation.previousHelperIdentity
        ])

        let genesis = try PhysicalBridgeFixture(ordinal: 0)
        let expected = try await genesis.invocation()
        let composer = PhysicalBridgeCapturingComposer(
            selection: genesis.selection, result: genesis.localResult
        )
        let continuity = try await InvestigationMachineSingleEpochComposition(
            selection: genesis.selection,
            predecessor: try .genesis(for: genesis.selection),
            composer: composer,
            outerJoin: .init(prover: PhysicalBridgeProver(.exact))
        ).run()
        let next = try PhysicalBridgeFixture(
            ordinal: 1, cohort: genesis.cohort
        )
        #expect(composer.invocations == [expected])
        #expect(composer.legacyPreviousHelpers.isEmpty)
        #expect(
            try continuity.consume(for: next.selection)
                .previousHelperIdentity == genesis.helperIdentity
        )
    }

    @Test(arguments: PhysicalBridgeResultKind.allCases)
    fileprivate func physicalResultRoundTripsAllModesAndRemainsNonCodable(
        _ kind: PhysicalBridgeResultKind
    ) throws {
        let fixture = try PhysicalBridgeFixture(ordinal: kind.ordinal)
        let projected = try InvestigationMachineSingleEpochPhysicalResult(
            projecting: kind.localResult(from: fixture)
        )
        let encoded = try projected.encoded()
        let decoded = try InvestigationMachineSingleEpochPhysicalResult.decode(
            encoded, expectedSelection: fixture.selection
        )

        #expect(decoded == projected)
        #expect(try decoded.encoded() == encoded)
        #expect(decoded.helperIdentity == fixture.helperIdentity)
        #expect(decoded.mode == kind.mode)
        #expect(decoded.bindingSHA256 == kind.bindingSHA256(from: fixture))
        #expect(!(InvestigationMachineSingleEpochInvocation.self
            is any Codable.Type))
        #expect(!(InvestigationMachineSingleEpochPhysicalResult.self
            is any Codable.Type))
    }

    @Test(arguments: PhysicalBridgeResultKind.allCases)
    fileprivate func physicalResultRejectsMismatchForeignSelectionAndTamper(
        _ kind: PhysicalBridgeResultKind
    ) throws {
        let fixture = try PhysicalBridgeFixture(ordinal: kind.ordinal)
        let physical = try InvestigationMachineSingleEpochPhysicalResult(
            projecting: kind.localResult(from: fixture)
        )
        let encoded = try physical.encoded()
        let foreign = try PhysicalBridgeFixture(
            ordinal: kind.ordinal, cohort: .foreign
        )
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineSingleEpochPhysicalResult.decode(
                encoded, expectedSelection: foreign.selection
            )
        }
        for bytes in try strictWireMutations(encoded) {
            #expect(throws: (any Error).self) {
                _ = try InvestigationMachineSingleEpochPhysicalResult.decode(
                    bytes, expectedSelection: fixture.selection
                )
            }
        }

        let normal = try PhysicalBridgeFixture(ordinal: 0)
        let parentCrash = try PhysicalBridgeFixture(ordinal: 6)
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineSingleEpochPhysicalResult(
                projecting: normal.transferredResult
            )
        }
        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineSingleEpochPhysicalResult(
                projecting: parentCrash.localResult
            )
        }
    }

    @Test
    func predecessorIssuesOnlyOneInvocation() async throws {
        let fixture = try PhysicalBridgeFixture(ordinal: 1)
        let predecessor = try await fixture.predecessor()
        let driftedSelection = try fixture.selectionWithDifferentConfiguration()
        #expect(throws: InvestigationMachineHelperEpochContinuityError
            .invalidPredecessor) {
            _ = try predecessor.invocation(for: driftedSelection)
        }
        async let first = invocationSucceeds(
            predecessor, selection: fixture.selection
        )
        async let second = invocationSucceeds(
            predecessor, selection: fixture.selection
        )
        #expect(await [first, second].filter { $0 }.count == 1)
    }
}

private func invocationSucceeds(
    _ predecessor: InvestigationMachineHelperEpochPredecessor,
    selection: InvestigationMachineFixedEpochSelection
) -> Bool {
    do {
        _ = try predecessor.invocation(for: selection)
        return true
    } catch {
        return false
    }
}

private enum PhysicalBridgeInvocationKind: CaseIterable, Equatable {
    case genesis, successor
    var ordinal: UInt32 { self == .genesis ? 0 : 1 }
}

private enum PhysicalBridgeResultKind: CaseIterable, Equatable {
    case local, transferred
    var ordinal: UInt32 { self == .local ? 0 : 6 }
    var mode: InvestigationMachineOuterContainmentMode {
        self == .local ? .normal : .parentCrash
    }
    func localResult(
        from fixture: PhysicalBridgeFixture
    ) -> InvestigationMachineSingleEpochResult {
        self == .local ? fixture.localResult : fixture.transferredResult
    }
    func bindingSHA256(
        from fixture: PhysicalBridgeFixture
    ) -> InvestigationHandoffSHA256 {
        self == .local
            ? fixture.localCompletion.bindingSHA256
            : fixture.ownership.bindingSHA256
    }
}

private struct PhysicalBridgeCohort: Sendable, Equatable {
    let outerAttemptUUID: UUID
    let capsuleSHA256: InvestigationHandoffSHA256
    let inputSHA256: InvestigationHandoffSHA256
    static var foreign: Self {
        get throws {
            try .init(
                outerAttemptUUID: PhysicalBridgeFixture.uuid(0xe1),
                capsuleSHA256: PhysicalBridgeFixture.digest(0xe2),
                inputSHA256: PhysicalBridgeFixture.digest(0xe3)
            )
        }
    }
}

private final class PhysicalBridgeLegacyComposer:
    InvestigationMachineSingleEpochComposing, @unchecked Sendable
{
    private let selection: InvestigationMachineFixedEpochSelection
    private let result: InvestigationMachineSingleEpochResult
    private let lock = NSLock()
    private var calls: [InvestigationMachineProcessIdentity?] = []
    var previousHelpers: [InvestigationMachineProcessIdentity?] {
        lock.withLock { calls }
    }
    init(
        selection: InvestigationMachineFixedEpochSelection,
        result: InvestigationMachineSingleEpochResult
    ) {
        self.selection = selection
        self.result = result
    }
    func isBound(to value: InvestigationMachineFixedEpochSelection) -> Bool {
        value == selection
    }
    func run(
        previousHelperIdentity: InvestigationMachineProcessIdentity?
    ) async throws -> InvestigationMachineSingleEpochResult {
        lock.withLock { calls.append(previousHelperIdentity) }
        return result
    }
}

private final class PhysicalBridgeCapturingComposer:
    InvestigationMachineSingleEpochComposing, @unchecked Sendable
{
    private let selection: InvestigationMachineFixedEpochSelection
    private let result: InvestigationMachineSingleEpochResult
    private let lock = NSLock()
    private var captured: [InvestigationMachineSingleEpochInvocation] = []
    private var legacy: [InvestigationMachineProcessIdentity?] = []
    var invocations: [InvestigationMachineSingleEpochInvocation] {
        lock.withLock { captured }
    }
    var legacyPreviousHelpers: [InvestigationMachineProcessIdentity?] {
        lock.withLock { legacy }
    }
    init(
        selection: InvestigationMachineFixedEpochSelection,
        result: InvestigationMachineSingleEpochResult
    ) {
        self.selection = selection
        self.result = result
    }
    func isBound(to value: InvestigationMachineFixedEpochSelection) -> Bool {
        value == selection
    }
    func run(
        invocation: InvestigationMachineSingleEpochInvocation
    ) async throws -> InvestigationMachineSingleEpochResult {
        lock.withLock { captured.append(invocation) }
        return result
    }
    func run(
        previousHelperIdentity: InvestigationMachineProcessIdentity?
    ) async throws -> InvestigationMachineSingleEpochResult {
        lock.withLock { legacy.append(previousHelperIdentity) }
        return result
    }
}

private final class PhysicalBridgeProver:
    InvestigationMachineOuterContainmentProving, @unchecked Sendable
{
    enum Behavior: Sendable, Equatable { case exact, uncertain }
    private let behavior: Behavior
    private let lock = NSLock()
    private var calls = 0
    var callCount: Int { lock.withLock { calls } }
    init(_ behavior: Behavior) { self.behavior = behavior }
    func proveContainment(
        selection: InvestigationMachineFixedEpochSelection,
        result: InvestigationMachineSingleEpochResult,
        predecessor: InvestigationMachineHelperEpochPredecessor
    ) async -> InvestigationMachineOuterContainmentOutcome {
        lock.withLock { calls += 1 }
        guard behavior == .exact else { return .terminalUncertain }
        guard let proof = try? InvestigationMachineOuterContainmentProof(
            selection: selection, result: result, predecessor: predecessor,
            terminalProofSHA256: PhysicalBridgeFixture.digest(0xa1)
        ) else { return .terminalUncertain }
        return .contained(proof)
    }
}

private struct PhysicalBridgeFixture {
    let cohort: PhysicalBridgeCohort
    let selection: InvestigationMachineFixedEpochSelection
    let helperIdentity: InvestigationMachineProcessIdentity
    let ownership: InvestigationMachineSingleEpochOwnershipCandidate
    let localCompletion:
        InvestigationMachineSingleEpochLocalCompletionCandidate
    var localResult: InvestigationMachineSingleEpochResult {
        .localCompletion(localCompletion)
    }
    var transferredResult: InvestigationMachineSingleEpochResult {
        .ownershipTransferred(ownership)
    }
    func invocation() async throws -> InvestigationMachineSingleEpochInvocation {
        try await predecessor().invocation(for: selection)
    }
    func predecessor() async throws
        -> InvestigationMachineHelperEpochPredecessor
    {
        if selection.epoch.ordinal == 0 {
            return try InvestigationMachineHelperEpochContinuity
                .genesis(for: selection).consume(for: selection)
        }
        let previous = try PhysicalBridgeFixture(
            ordinal: selection.epoch.ordinal - 1, cohort: cohort
        )
        let previousResult = previous.selection.epoch.scenario
            == .lifecycleRecovery
            ? previous.transferredResult : previous.localResult
        let continuity = try await InvestigationMachineOuterCompletionJoin(
            prover: PhysicalBridgeProver(.exact)
        ).seal(
            selection: previous.selection, result: previousResult,
            predecessor: try await previous.predecessor()
        )
        return try continuity.consume(for: selection)
    }

    func selectionWithDifferentConfiguration() throws
        -> InvestigationMachineFixedEpochSelection
    {
        let configuration = Data("physical-bridge-drift".utf8)
        let epoch = try InvestigationCohortEpoch(
            ordinal: selection.epoch.ordinal,
            epochUUID: selection.epoch.epochUUID,
            scenario: selection.epoch.scenario,
            configurationNonce: selection.epoch.configurationNonce,
            configuration: configuration,
            configurationSHA256: .hashing(configuration),
            signedRuntimeBindingSHA256:
                selection.epoch.signedRuntimeBindingSHA256
        )
        let source = selection.projection
        let projection = try InvestigationInstalledL2IdentityProjection(
            epochUUID: epoch.epochUUID,
            configurationNonce: epoch.configurationNonce,
            configurationValidBefore: source.configurationValidBefore,
            configurationSHA256: epoch.configurationSHA256,
            signedRuntimeBindingSHA256: epoch.signedRuntimeBindingSHA256,
            appExecutableSHA256: source.appExecutableSHA256,
            appBundleIdentifier: source.appBundleIdentifier,
            helperExecutableSHA256: source.helperExecutableSHA256,
            helperServiceIdentifier: source.helperServiceIdentifier,
            machineDriverExecutableSHA256: source.machineDriverExecutableSHA256,
            machineDriverSigningIdentifier:
                source.machineDriverSigningIdentifier,
            machineDriverDesignatedRequirementSHA256:
                source.machineDriverDesignatedRequirementSHA256,
            machineDriverCodeDirectoryHash:
                source.machineDriverCodeDirectoryHash,
            machineClaimServiceIdentifier:
                source.machineClaimServiceIdentifier
        )
        return .init(
            outerAttemptUUID: selection.outerAttemptUUID,
            wholeCapsuleSHA256: selection.wholeCapsuleSHA256,
            wholeInputSHA256: selection.wholeInputSHA256,
            epoch: epoch, projection: projection
        )
    }

    init(ordinal: UInt32, cohort: PhysicalBridgeCohort? = nil) throws {
        let scenario = try #require(InvestigationHandoffScenario(
            rawValue: ordinal + 1
        ))
        self.cohort = try cohort ?? .init(
            outerAttemptUUID: Self.uuid(0x01),
            capsuleSHA256: Self.digest(0x02),
            inputSHA256: Self.digest(0x03)
        )
        let configuration = Data("physical-bridge-\(ordinal)".utf8)
        let epoch = try InvestigationCohortEpoch(
            ordinal: ordinal, epochUUID: Self.uuid(UInt8(0x10 + ordinal)),
            scenario: scenario,
            configurationNonce: Self.uuid(UInt8(0x20 + ordinal)),
            configuration: configuration,
            configurationSHA256: .hashing(configuration),
            signedRuntimeBindingSHA256: Self.digest(UInt8(0x30 + ordinal))
        )
        let driverSigning = try Self.signing(
            "com.eriklee.stornaut.investigation.machine-driver", 0x43, true
        )
        let projection = try InvestigationInstalledL2IdentityProjection(
            epochUUID: epoch.epochUUID,
            configurationNonce: epoch.configurationNonce,
            configurationValidBefore: .init(rawValue: 1_000),
            configurationSHA256: epoch.configurationSHA256,
            signedRuntimeBindingSHA256: epoch.signedRuntimeBindingSHA256,
            appExecutableSHA256: Self.digest(0x51),
            appBundleIdentifier: "com.eriklee.stornaut",
            helperExecutableSHA256: Self.digest(0x52),
            helperServiceIdentifier: "com.eriklee.stornaut.lifecycle",
            machineDriverExecutableSHA256: Self.digest(0x53),
            machineDriverSigningIdentifier: driverSigning.signingIdentifier,
            machineDriverDesignatedRequirementSHA256:
                driverSigning.designatedRequirementSHA256,
            machineDriverCodeDirectoryHash: driverSigning.codeDirectoryHash,
            machineClaimServiceIdentifier:
                "com.eriklee.stornaut.lifecycle.machine-claim"
        )
        selection = .init(
            outerAttemptUUID: self.cohort.outerAttemptUUID,
            wholeCapsuleSHA256: self.cohort.capsuleSHA256,
            wholeInputSHA256: self.cohort.inputSHA256,
            epoch: epoch, projection: projection
        )
        let appIdentity = try Self.identity(
            role: .app, pid: 701 + ordinal, version: 11 + ordinal,
            asid: 44_001 + ordinal, euid: 501
        )
        helperIdentity = try Self.identity(
            role: .helper, pid: 801 + ordinal, version: 21 + ordinal,
            asid: 55_001 + ordinal, euid: 0
        )
        let claim = try InvestigationMachineClaimEvidence(
            requestBindingSHA256: Self.digest(UInt8(0x61 + ordinal)),
            originalClaimChallenge: Self.uuid(UInt8(0x62 + ordinal)),
            claimConnectionEpoch: Self.uuid(UInt8(0x63 + ordinal)),
            appIdentity: appIdentity, helperIdentity: helperIdentity,
            appUserID: 501, recordedAt: .init(rawValue: 250),
            claimedAt: .init(rawValue: 275), ownerRetirement: .init(),
            l1Residue: .init(
                investigationUUID: epoch.configurationNonce,
                auditSessionID: helperIdentity.auditSessionID, userID: 501,
                observedAt: .init(rawValue: 200),
                remainingAuditSessionMembers: 0, matchingLeases: 0,
                leaseRootEntries: 0, investigationArtifacts: 0
            ), releaseDeadlineNanoseconds: 400
        )
        let appSigning = try Self.signing(
            "com.eriklee.stornaut", 0x71, false
        )
        let helperSigning = try Self.signing(
            "com.eriklee.stornaut.lifecycle.helper", 0x72, false
        )
        let semantic = try InvestigationInstalledL2SemanticContract.evaluate(
            projection: projection,
            artifacts: Dictionary(uniqueKeysWithValues:
                InvestigationInstalledL2ArtifactRole.allCases.map {
                    ($0, .presentValid)
                }),
            app: try .init(
                identity: appIdentity,
                executableSHA256: projection.appExecutableSHA256,
                staticSigning: appSigning, liveSigning: appSigning
            ),
            helper: try .init(
                identity: helperIdentity,
                executableSHA256: projection.helperExecutableSHA256,
                staticSigning: helperSigning, liveSigning: helperSigning
            ),
            machineDriver: try .init(
                executableSHA256: projection.machineDriverExecutableSHA256,
                staticSigning: driverSigning, liveSigning: driverSigning
            ),
            service: .loaded(identity: helperIdentity),
            started: try .init(
                wallUTC: .init(rawValue: 300), continuousNanoseconds: 350
            ),
            observed: try .init(
                wallUTC: .init(rawValue: 301), continuousNanoseconds: 351
            )
        )
        let installedProof = try InvestigationMachineSingleEpochInstalledL2Join
            .prove(
                projection: projection, claimEvidence: claim,
                semanticObservation: semantic,
                repeatedAppIdentity: appIdentity, epochUUID: epoch.epochUUID,
                deadlineNanoseconds: 500
            )
        ownership = try .init(
            commitment: try .init(selection: selection),
            appIdentity: appIdentity, claimEvidence: claim,
            semanticObservation: semantic, repeatedAppIdentity: appIdentity,
            installedL2Proof: installedProof, epochDeadlineNanoseconds: 500
        )
        let released = try InvestigationMachineClaimReleased(
            requestBindingSHA256: claim.requestBindingSHA256,
            releaseChallenge: Self.uuid(UInt8(0x64 + ordinal)),
            claimedHelperIdentitySHA256: helperIdentity.helperIdentitySHA256(),
            claimConnectionEpoch: claim.claimConnectionEpoch,
            exitScheduled: true, postReplyExitDeadlineNanoseconds: 450
        )
        let driver = InvestigationMachineSingleEpochDriverObservation(
            .physicalBridgeFixture
        )
        localCompletion = try .init(
            ownership: ownership, claimRelease: released,
            retirement: .init(), initialDriverObservation: driver,
            finalDriverObservation: driver
        )
    }

    fileprivate static func digest(_ byte: UInt8) throws
        -> InvestigationHandoffSHA256
    {
        try .init(rawBytes: Data(repeating: byte, count: 32))
    }
    fileprivate static func uuid(_ byte: UInt8) -> UUID {
        UUID(uuid: (byte, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    }
    fileprivate static func identity(
        role: InvestigationMachineProcessRole, pid: UInt32, version: UInt32,
        asid: UInt32, euid: UInt32
    ) throws -> InvestigationMachineProcessIdentity {
        try .init(
            role: role, processID: pid, processIDVersion: version,
            auditSessionID: asid, effectiveUserID: euid,
            auditTokenWords: [euid, euid, 20, euid, 20, pid, asid, version]
        )
    }
    private static func signing(
        _ identifier: String, _ byte: UInt8, _ adHoc: Bool
    ) throws -> InvestigationInstalledL2SigningIdentity {
        try .init(
            signingIdentifier: identifier,
            designatedRequirementSHA256: digest(byte),
            codeDirectoryHash: Data(repeating: byte, count: 20),
            isAdHoc: adHoc
        )
    }
}

private struct PhysicalBridgeWireTranscript {
    let domain: String
    var fields: [Data]
    init(_ encoded: Data) throws {
        var cursor = HandoffBinaryCursor(data: encoded)
        guard try cursor.readUInt32() == HandoffBinaryTranscript.magic else {
            throw PhysicalBridgeFixtureError.invalidTranscript
        }
        let domainBytes = try cursor.readTaggedField(
            expectedTag: 0,
            admittedByteCounts: 1...HandoffBinaryTranscript.maximumDomainByteCount
        )
        guard let domain = String(data: domainBytes, encoding: .utf8) else {
            throw PhysicalBridgeFixtureError.invalidTranscript
        }
        let version = try cursor.readTaggedField(
            expectedTag: 1, admittedByteCounts: 4...4
        )
        var versionCursor = HandoffBinaryCursor(data: version)
        guard
            try versionCursor.readUInt32() == HandoffBinaryTranscript.version,
            versionCursor.isAtEnd
        else { throw PhysicalBridgeFixtureError.invalidTranscript }
        var fields: [Data] = []
        var tag: UInt16 = 2
        while !cursor.isAtEnd {
            fields.append(try cursor.readTaggedField(
                expectedTag: tag, admittedByteCounts: 1...encoded.count
            ))
            tag += 1
        }
        self.domain = domain
        self.fields = fields
    }
    func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: domain, businessFields: fields,
            maximumByteCount: 64 * 1_024
        )
    }
}

private enum PhysicalBridgeFixtureError: Error {
    case invalidTranscript, expectedUniqueField
}

private func replacingUniqueBusinessField(
    in encoded: Data, matching expected: Data, with replacement: Data
) throws -> Data {
    var transcript = try PhysicalBridgeWireTranscript(encoded)
    let matches = transcript.fields.indices.filter {
        transcript.fields[$0] == expected
    }
    guard matches.count == 1, let index = matches.first else {
        throw PhysicalBridgeFixtureError.expectedUniqueField
    }
    transcript.fields[index] = replacement
    return try transcript.encoded()
}

private func invocationWithTrailingPredecessorByte(
    _ invocation: InvestigationMachineSingleEpochInvocation
) throws -> Data {
    var transcript = try PhysicalBridgeWireTranscript(invocation.encoded())
    let matches = transcript.fields.indices.filter {
        transcript.fields[$0] == invocation.predecessorTranscript
    }
    guard matches.count == 1, let index = matches.first else {
        throw PhysicalBridgeFixtureError.expectedUniqueField
    }
    transcript.fields[index].append(0xa5)
    let digestMatches = transcript.fields.indices.filter {
        transcript.fields[$0] == invocation.predecessorSHA256.rawBytes
    }
    guard digestMatches.count == 1, let digestIndex = digestMatches.first else {
        throw PhysicalBridgeFixtureError.expectedUniqueField
    }
    transcript.fields[digestIndex] = InvestigationHandoffSHA256.hashing(
        transcript.fields[index]
    ).rawBytes
    return try transcript.encoded()
}

private func invocationWithPreviousEpochUUID(
    _ invocation: InvestigationMachineSingleEpochInvocation, _ uuid: UUID
) throws -> Data {
    var outer = try PhysicalBridgeWireTranscript(invocation.encoded())
    let predecessorMatches = outer.fields.indices.filter {
        outer.fields[$0] == invocation.predecessorTranscript
    }
    let digestMatches = outer.fields.indices.filter {
        outer.fields[$0] == invocation.predecessorSHA256.rawBytes
    }
    guard
        predecessorMatches.count == 1, digestMatches.count == 1,
        let predecessorIndex = predecessorMatches.first,
        let digestIndex = digestMatches.first
    else {
        throw PhysicalBridgeFixtureError.expectedUniqueField
    }
    var predecessor = try PhysicalBridgeWireTranscript(
        outer.fields[predecessorIndex]
    )
    guard predecessor.fields.count == 10 else {
        throw PhysicalBridgeFixtureError.invalidTranscript
    }
    var bytes = uuid.uuid
    predecessor.fields[4] = withUnsafeBytes(of: &bytes) { Data($0) }
    outer.fields[predecessorIndex] = try predecessor.encoded()
    outer.fields[digestIndex] = InvestigationHandoffSHA256.hashing(
        outer.fields[predecessorIndex]
    ).rawBytes
    return try outer.encoded()
}

private func invocationWithDomain(
    _ invocation: InvestigationMachineSingleEpochInvocation, _ domain: String
) throws -> Data {
    let transcript = try PhysicalBridgeWireTranscript(invocation.encoded())
    return try HandoffBinaryTranscript.encode(
        domain: domain, businessFields: transcript.fields,
        maximumByteCount: 96 * 1_024
    )
}

private func strictWireMutations(_ encoded: Data) throws -> [Data] {
    let transcript = try PhysicalBridgeWireTranscript(encoded)
    var mutations = try transcript.fields.indices.map { index in
        var mutation = transcript
        var field = mutation.fields[index]
        field[field.startIndex] ^= 0x01
        mutation.fields[index] = field
        return try mutation.encoded()
    }
    if transcript.fields.count >= 2 {
        var missing = transcript
        missing.fields.removeLast()
        var duplicate = transcript
        duplicate.fields.append(duplicate.fields.last!)
        var reordered = transcript
        reordered.fields.swapAt(0, 1)
        mutations += try [missing.encoded(), duplicate.encoded(), reordered.encoded()]
    }
    var trailing = encoded
    trailing.append(0x7f)
    mutations += [trailing, Data(encoded.dropLast())]
    return mutations
}

private extension InvestigationMachineInstalledDriverObservation {
    static var physicalBridgeFixture: Self {
        let node = InvestigationMachineInstalledDriverNodeIdentity(
            deviceID: 1, inode: 2, generation: 3, isRegularFile: true,
            ownerUserID: 0, ownerGroupID: 0, mode: 0o755, linkCount: 1,
            size: 65_536, flags: 0, modificationSeconds: 4,
            modificationNanoseconds: 5, statusChangeSeconds: 6,
            statusChangeNanoseconds: 7
        )
        let signing = InvestigationMachineInstalledDriverSigningIdentity(
            signingIdentifier: fixedSigningIdentifier,
            designatedRequirementSHA256: String(repeating: "a", count: 64),
            codeDirectoryHash: String(repeating: "b", count: 40),
            isAdHoc: true
        )
        return .init(
            executablePath: fixedExecutablePath, node: node,
            executableSHA256: String(repeating: "c", count: 64),
            signing: signing,
            manifest: .init(
                path: fixedLaunchDaemonManifestPath, node: node,
                sha256: fixedLaunchDaemonManifestSHA256,
                label: fixedLifecycleLabel, program: fixedLifecycleProgram,
                primaryServiceIdentifier: fixedLifecycleLabel,
                machineClaimServiceIdentifier: fixedMachineClaimServiceIdentifier
            )
        )
    }
}
