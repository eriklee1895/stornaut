#if DEBUG
import CInvestigationIdentitySupport
import CInvestigationMachineCampaignSupport
import Darwin
import Foundation
import StornautInvestigationHandoffContract

package struct InvestigationMachineCampaignExpectedBinding:
    Sendable, Equatable
{
    package let attemptUUID: UUID
    package let buildProvenanceSHA256: String
    package let signedRuntimeBindingSHA256: InvestigationHandoffSHA256
    package let wholeProjectedInputSHA256: InvestigationHandoffSHA256

    package init(
        attemptUUID: UUID, buildProvenanceSHA256: String,
        signedRuntimeBindingSHA256: InvestigationHandoffSHA256,
        wholeProjectedInputSHA256: InvestigationHandoffSHA256
    ) throws {
        guard Self.nonzero(attemptUUID),
              buildProvenanceSHA256.utf8.count == 64,
              buildProvenanceSHA256.utf8.allSatisfy({ byte in
                  (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                      || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte)
              }),
              signedRuntimeBindingSHA256.rawBytes.contains(where: { $0 != 0 }),
              wholeProjectedInputSHA256.rawBytes.contains(where: { $0 != 0 })
        else { throw InvestigationMachineCampaignHarnessFailure.bindingInvalid }
        self.attemptUUID = attemptUUID
        self.buildProvenanceSHA256 = buildProvenanceSHA256
        self.signedRuntimeBindingSHA256 = signedRuntimeBindingSHA256
        self.wholeProjectedInputSHA256 = wholeProjectedInputSHA256
    }

    private static func nonzero(_ value: UUID) -> Bool {
        withUnsafeBytes(of: value.uuid) { $0.contains(where: { $0 != 0 }) }
    }
}

package struct InvestigationMachineCampaignSpawnedProcess:
    Sendable, Equatable
{
    package let processID: pid_t
    package let terminalDescriptor: Int32
    package let receiptDescriptor: Int32
    package let bootstrapDescriptor: Int32
    package let parentTransferCloseError: Int32?

    package init(
        processID: pid_t, terminalDescriptor: Int32, receiptDescriptor: Int32,
        bootstrapDescriptor: Int32 = 12,
        parentTransferCloseError: Int32? = nil
    ) {
        self.processID = processID
        self.terminalDescriptor = terminalDescriptor
        self.receiptDescriptor = receiptDescriptor
        self.bootstrapDescriptor = bootstrapDescriptor
        self.parentTransferCloseError = parentTransferCloseError
    }
}

package struct InvestigationMachineCampaignOuterIdentity:
    Sendable, Equatable
{
    package let processID: pid_t
    package let processIDVersion: UInt32
    package let parentProcessID: pid_t
    package let processGroupID: pid_t
    package let sessionID: pid_t
    package let foregroundProcessGroupID: pid_t
    package let effectiveUserID: uid_t
    package let startTimeSeconds: UInt64
    package let startTimeMicroseconds: UInt64

    package init(
        processID: pid_t, processIDVersion: UInt32, parentProcessID: pid_t,
        processGroupID: pid_t, sessionID: pid_t,
        foregroundProcessGroupID: pid_t, effectiveUserID: uid_t,
        startTimeSeconds: UInt64, startTimeMicroseconds: UInt64
    ) {
        self.processID = processID
        self.processIDVersion = processIDVersion
        self.parentProcessID = parentProcessID
        self.processGroupID = processGroupID
        self.sessionID = sessionID
        self.foregroundProcessGroupID = foregroundProcessGroupID
        self.effectiveUserID = effectiveUserID
        self.startTimeSeconds = startTimeSeconds
        self.startTimeMicroseconds = startTimeMicroseconds
    }
}

package enum InvestigationMachineCampaignChannel: Hashable, Sendable {
    case terminal
    case receipt
}

package struct InvestigationMachineCampaignPreArmFrame:
    Sendable, Equatable
{
    package static let maximumByteCount =
        InvestigationProjectedCohortInput.maximumByteCount + 1_024
    package let repositoryHEAD, repositoryTree: String
    package let canonicalSourceManifestSHA256: InvestigationHandoffSHA256
    package let buildProvenanceSHA256: InvestigationHandoffSHA256
    package let signedRuntimeBindingSHA256: InvestigationHandoffSHA256
    package let outerAttemptUUID: UUID
    package let wholeCapsuleSHA256: InvestigationHandoffSHA256
    package let wholeProjectedInputSHA256: InvestigationHandoffSHA256
    package let canonicalProjectedInput: Data
    package let frameSHA256: InvestigationHandoffSHA256

    package static func decode(_ bytes: Data) throws -> Self {
        let fields = try HandoffBinaryTranscript.decode(
            bytes,
            expectedDomain: "stornaut.task39.iic.coordinator-prearm.v1",
            expectedBusinessFieldByteCounts: [
                40...40, 40...40, 32...32, 32...32, 32...32,
                16...16, 32...32, 32...32,
                1...InvestigationProjectedCohortInput.maximumByteCount, 32...32,
            ],
            maximumByteCount: maximumByteCount
        )
        guard let head = String(data: fields[0], encoding: .utf8),
              let tree = String(data: fields[1], encoding: .utf8),
              Data(head.utf8) == fields[0], Data(tree.utf8) == fields[1],
              validHex(head), validHex(tree)
        else { throw InvestigationMachineCampaignHarnessFailure.receiptInvalid }
        let value = try Self(
            repositoryHEAD: head, repositoryTree: tree,
            canonicalSourceManifestSHA256: .init(rawBytes: fields[2]),
            buildProvenanceSHA256: .init(rawBytes: fields[3]),
            signedRuntimeBindingSHA256: .init(rawBytes: fields[4]),
            outerAttemptUUID: decodeUUID(fields[5]),
            wholeCapsuleSHA256: .init(rawBytes: fields[6]),
            wholeProjectedInputSHA256: .init(rawBytes: fields[7]),
            canonicalProjectedInput: fields[8],
            frameSHA256: .init(rawBytes: fields[9])
        )
        var zeroed = fields
        zeroed[9] = Data(repeating: 0, count: 32)
        let transcript = try HandoffBinaryTranscript.encode(
            domain: "stornaut.task39.iic.coordinator-prearm.v1",
            businessFields: zeroed, maximumByteCount: maximumByteCount
        )
        guard InvestigationHandoffSHA256.hashing(transcript) == value.frameSHA256
        else { throw InvestigationMachineCampaignHarnessFailure.receiptInvalid }
        return value
    }

    private init(
        repositoryHEAD: String, repositoryTree: String,
        canonicalSourceManifestSHA256: InvestigationHandoffSHA256,
        buildProvenanceSHA256: InvestigationHandoffSHA256,
        signedRuntimeBindingSHA256: InvestigationHandoffSHA256,
        outerAttemptUUID: UUID, wholeCapsuleSHA256: InvestigationHandoffSHA256,
        wholeProjectedInputSHA256: InvestigationHandoffSHA256,
        canonicalProjectedInput: Data,
        frameSHA256: InvestigationHandoffSHA256
    ) throws {
        let digests = [
            canonicalSourceManifestSHA256, buildProvenanceSHA256, signedRuntimeBindingSHA256,
            wholeCapsuleSHA256, wholeProjectedInputSHA256, frameSHA256,
        ]
        guard digests.allSatisfy({ $0.rawBytes.contains { $0 != 0 } }),
              Self.nonzero(outerAttemptUUID)
        else { throw InvestigationMachineCampaignHarnessFailure.receiptInvalid }
        let projected = try InvestigationProjectedCohortInput.decode(
            canonicalProjectedInput
        )
        guard projected.wholeInputSHA256 == wholeProjectedInputSHA256,
              projected.capsule.outerAttemptUUID == outerAttemptUUID,
              projected.capsule.wholeCapsuleSHA256 == wholeCapsuleSHA256,
              projected.projections.count
                == InvestigationProjectedCohortInput.projectionCount
        else { throw InvestigationMachineCampaignHarnessFailure.receiptInvalid }
        self.repositoryHEAD = repositoryHEAD; self.repositoryTree = repositoryTree
        self.canonicalSourceManifestSHA256 = canonicalSourceManifestSHA256
        self.buildProvenanceSHA256 = buildProvenanceSHA256
        self.signedRuntimeBindingSHA256 = signedRuntimeBindingSHA256
        self.outerAttemptUUID = outerAttemptUUID
        self.wholeCapsuleSHA256 = wholeCapsuleSHA256
        self.wholeProjectedInputSHA256 = wholeProjectedInputSHA256
        self.canonicalProjectedInput = canonicalProjectedInput
        self.frameSHA256 = frameSHA256
    }
    private static func validHex(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy {
            (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0)
                || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains($0)
        }
    }
    private static func nonzero(_ value: UUID) -> Bool {
        var bytes = value.uuid
        return withUnsafeBytes(of: &bytes) { $0.contains { $0 != 0 } }
    }
    private static func decodeUUID(_ bytes: Data) throws -> UUID {
        guard bytes.count == 16 else {
            throw InvestigationMachineCampaignHarnessFailure.receiptInvalid
        }
        let b = Array(bytes)
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
            b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }

}

package struct InvestigationMachineCampaignPreArmFailureFrame:
    Sendable, Equatable
{
    package enum Stage: UInt8, CaseIterable, Sendable {
        case materializeSource = 1, makeBinding, makeConfigurations
        case authorCohort, preArmPublication
        package var name: String {
            switch self {
            case .materializeSource: "materializeSource"
            case .makeBinding: "makeBinding"
            case .makeConfigurations: "makeConfigurations"
            case .authorCohort: "authorCohort"
            case .preArmPublication: "preArmPublication"
            }
        }
    }
    package enum Reason: UInt8, CaseIterable, Sendable {
        case buildProvenanceRejected = 1, installedObservationInvalid
        case codexIdentityChanged, admissionDeadline, protocolRejected
        case containmentUncertain
        package var expectedExitStatus: Int32 {
            self == .containmentUncertain ? 82 : 81
        }
        package var name: String {
            switch self {
            case .buildProvenanceRejected: "buildProvenanceRejected"
            case .installedObservationInvalid: "installedObservationInvalid"
            case .codexIdentityChanged: "codexIdentityChanged"
            case .admissionDeadline: "admissionDeadline"
            case .protocolRejected: "protocolRejected"
            case .containmentUncertain: "containmentUncertain"
            }
        }
    }
    package enum Checkpoint: Sendable, Equatable {
        case bootstrapStarted(nonce: InvestigationHandoffSHA256)
        case sourceVerified(
            nonce: InvestigationHandoffSHA256,
            sourceFingerprintSHA256: InvestigationHandoffSHA256
        )
        case runtimeBound(
            nonce: InvestigationHandoffSHA256,
            sourceFingerprintSHA256: InvestigationHandoffSHA256,
            buildProvenanceSHA256: InvestigationHandoffSHA256,
            signedRuntimeBindingSHA256: InvestigationHandoffSHA256
        )
    }
    package static let domain =
        "stornaut.task39.iic.coordinator-prearm-failure.v1"
    package static let maximumByteCount = 512
    package let stage: Stage
    package let checkpoint: Checkpoint
    package let reason: Reason
    package let frameSHA256: InvestigationHandoffSHA256

    package static func decode(_ data: Data) throws -> Self {
        let fields = try HandoffBinaryTranscript.decode(
            data, expectedDomain: domain,
            expectedBusinessFieldByteCounts: [
                1...1, 33...129, 1...1, 4...4, 32...32,
            ], maximumByteCount: maximumByteCount
        )
        guard let stage = Stage(rawValue: fields[0][fields[0].startIndex]),
              let reason = Reason(rawValue: fields[2][fields[2].startIndex]),
              uint32(fields[3]) == UInt32(reason.expectedExitStatus)
        else { throw InvestigationMachineCampaignHarnessFailure.receiptInvalid }
        let checkpoint = try decodeCheckpoint(fields[1])
        guard admits(stage: stage, checkpoint: checkpoint, reason: reason)
        else { throw InvestigationMachineCampaignHarnessFailure.receiptInvalid }
        let digest = try InvestigationHandoffSHA256(rawBytes: fields[4])
        let zeroed = try transcript(
            stage: stage, checkpoint: checkpoint, reason: reason,
            digest: try .init(rawBytes: Data(repeating: 0, count: 32))
        )
        guard .hashing(zeroed) == digest else {
            throw InvestigationMachineCampaignHarnessFailure.receiptInvalid
        }
        let value = Self(
            stage: stage, checkpoint: checkpoint, reason: reason,
            frameSHA256: digest
        )
        guard try value.encoded() == data else {
            throw InvestigationMachineCampaignHarnessFailure.receiptInvalid
        }
        return value
    }

    package static func decodeFrame(
        _ data: Data, reachedEOF: Bool
    ) throws -> Self {
        guard reachedEOF, data.count >= 4 else {
            throw InvestigationMachineCampaignHarnessFailure.receiptInvalid
        }
        let count = data.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard count > 0, Int(count) <= maximumByteCount,
              data.count == Int(count) + 4
        else { throw InvestigationMachineCampaignHarnessFailure.receiptInvalid }
        return try decode(Data(data.dropFirst(4)))
    }

    package func encoded() throws -> Data {
        try Self.transcript(
            stage: stage, checkpoint: checkpoint, reason: reason,
            digest: frameSHA256
        )
    }

    private static func admits(
        stage: Stage, checkpoint: Checkpoint, reason: Reason
    ) -> Bool {
        let zero = try! InvestigationHandoffSHA256(
            rawBytes: Data(repeating: 0, count: 32))
        let shape = switch checkpoint {
        case .bootstrapStarted(let nonce):
            stage == .materializeSource && nonce != zero
        case .sourceVerified(let nonce, let source):
            stage == .makeBinding && nonce != zero && source != zero
        case .runtimeBound(let nonce, let source, let build, let binding):
            [.makeConfigurations, .authorCohort, .preArmPublication].contains(stage)
                && [nonce, source, build, binding].allSatisfy { $0 != zero }
        }
        guard shape else { return false }
        switch reason {
        case .buildProvenanceRejected, .installedObservationInvalid:
            return stage == .makeBinding
        case .codexIdentityChanged:
            return stage == .makeBinding || stage == .makeConfigurations
        case .admissionDeadline:
            return stage == .preArmPublication
        case .protocolRejected, .containmentUncertain:
            return true
        }
    }
    private static func transcript(
        stage: Stage, checkpoint: Checkpoint, reason: Reason,
        digest: InvestigationHandoffSHA256
    ) throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: domain, businessFields: [
                Data([stage.rawValue]), checkpointData(checkpoint),
                Data([reason.rawValue]), uint32Data(UInt32(reason.expectedExitStatus)),
                digest.rawBytes,
            ], maximumByteCount: maximumByteCount
        )
    }
    private static func checkpointData(_ value: Checkpoint) -> Data {
        switch value {
        case .bootstrapStarted(let nonce): return Data([1]) + nonce.rawBytes
        case .sourceVerified(let nonce, let source):
            return Data([2]) + nonce.rawBytes + source.rawBytes
        case .runtimeBound(let nonce, let source, let build, let binding):
            return Data([3]) + nonce.rawBytes + source.rawBytes + build.rawBytes
                + binding.rawBytes
        }
    }
    private static func decodeCheckpoint(_ data: Data) throws -> Checkpoint {
        guard let tag = data.first else {
            throw InvestigationMachineCampaignHarnessFailure.receiptInvalid
        }
        let bytes = data.dropFirst()
        func digest(_ offset: Int) throws -> InvestigationHandoffSHA256 {
            guard bytes.count >= offset + 32 else {
                throw InvestigationMachineCampaignHarnessFailure.receiptInvalid
            }
            return try .init(rawBytes: Data(bytes.dropFirst(offset).prefix(32)))
        }
        switch (tag, bytes.count) {
        case (1, 32): return .bootstrapStarted(nonce: try digest(0))
        case (2, 64): return .sourceVerified(
            nonce: try digest(0), sourceFingerprintSHA256: try digest(32))
        case (3, 128): return .runtimeBound(
            nonce: try digest(0), sourceFingerprintSHA256: try digest(32),
            buildProvenanceSHA256: try digest(64),
            signedRuntimeBindingSHA256: try digest(96))
        default: throw InvestigationMachineCampaignHarnessFailure.receiptInvalid
        }
    }
    private static func uint32Data(_ value: UInt32) -> Data {
        Data([UInt8(value >> 24), UInt8(truncatingIfNeeded: value >> 16),
            UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)])
    }
    private static func uint32(_ data: Data) -> UInt32? {
        guard data.count == 4 else { return nil }
        return data.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }
}

package enum InvestigationMachineCampaignReadObservation:
    Sendable, Equatable
{
    case bytes(Data)
    case eof
}

package enum InvestigationMachineCampaignExactWait: Sendable, Equatable {
    case exited(status: Int32)
    case signaled(signal: Int32)
    case stopped(signal: Int32)
}

package struct InvestigationMachineCampaignResidueObservation:
    Sendable, Equatable
{
    package let processGroupMembers: [pid_t]
    package let sessionMembers: [pid_t]
    package let complete: Bool

    package init(
        processGroupMembers: [pid_t], sessionMembers: [pid_t], complete: Bool
    ) {
        self.processGroupMembers = processGroupMembers
        self.sessionMembers = sessionMembers
        self.complete = complete
    }
}

package enum InvestigationMachineCampaignHarnessOperation:
    Sendable, Equatable
{
    case makeAbsoluteDeadline
    case observeHarness(absoluteDeadlineNanoseconds: UInt64)
    case spawnFixedSibling(absoluteDeadlineNanoseconds: UInt64)
    case readBootstrap(
        descriptor: Int32, maximumByteCount: Int,
        absoluteDeadlineNanoseconds: UInt64
    )
    case observeOuterIdentity(
        processID: pid_t, absoluteDeadlineNanoseconds: UInt64
    )
    case pollReadable(
        channels: [InvestigationMachineCampaignChannel],
        absoluteDeadlineNanoseconds: UInt64
    )
    case read(
        channel: InvestigationMachineCampaignChannel, maximumByteCount: Int,
        absoluteDeadlineNanoseconds: UInt64
    )
    case terminateOwnedGroup(
        processID: pid_t, processGroupID: pid_t,
        absoluteDeadlineNanoseconds: UInt64
    )
    case waitExact(
        processID: pid_t, absoluteDeadlineNanoseconds: UInt64
    )
    case observeResidue(
        processGroupID: pid_t, sessionID: pid_t,
        absoluteDeadlineNanoseconds: UInt64
    )
    case closeParentChannels(
        terminalDescriptor: Int32, receiptDescriptor: Int32,
        bootstrapDescriptor: Int32,
        absoluteDeadlineNanoseconds: UInt64
    )
}

package enum InvestigationMachineCampaignHarnessResponse:
    Sendable, Equatable
{
    case absoluteDeadline(UInt64)
    case harnessIdentity(processID: pid_t, effectiveUserID: uid_t)
    case spawned(InvestigationMachineCampaignSpawnedProcess)
    case bootstrap(bytes: Data, reachedEOF: Bool)
    case outerIdentity(InvestigationMachineCampaignOuterIdentity)
    case readable([InvestigationMachineCampaignChannel])
    case read(InvestigationMachineCampaignReadObservation)
    case wait(InvestigationMachineCampaignExactWait)
    case residue(InvestigationMachineCampaignResidueObservation)
    case completed
}

package protocol InvestigationMachineCampaignHarnessSystem: Sendable {
    func prepareActivation(
        receiptDescriptor: Int32, terminalDescriptor: Int32,
        absoluteDeadlineNanoseconds: UInt64
    ) async throws -> InvestigationMachineCampaignPreArmFrame?
    func durablyPublishArmedConsumed(
        _ preArm: InvestigationMachineCampaignPreArmFrame,
        absoluteDeadlineNanoseconds: UInt64
    ) async throws
    func sendArmAfterDurablePublish(
        _ preArm: InvestigationMachineCampaignPreArmFrame,
        terminalDescriptor: Int32, absoluteDeadlineNanoseconds: UInt64
    ) async throws
    func relayCredentialAfterExactPrompt(
        _ preArm: InvestigationMachineCampaignPreArmFrame,
        terminalDescriptor: Int32, absoluteDeadlineNanoseconds: UInt64
    ) async throws
    func validateTerminalEvidence(
        _ bytes: Data, rawGateReceipt: Data,
        finalReceipt: InvestigationMachineCoordinatorRawReceiptV1,
        preArm: InvestigationMachineCampaignPreArmFrame,
        absoluteDeadlineNanoseconds: UInt64
    ) async throws
    func perform(
        _ operation: InvestigationMachineCampaignHarnessOperation
    ) async throws -> InvestigationMachineCampaignHarnessResponse
}

package extension InvestigationMachineCampaignHarnessSystem {
    func prepareActivation(
        receiptDescriptor: Int32, terminalDescriptor: Int32,
        absoluteDeadlineNanoseconds: UInt64
    ) async throws -> InvestigationMachineCampaignPreArmFrame? { nil }

    func durablyPublishArmedConsumed(
        _ preArm: InvestigationMachineCampaignPreArmFrame,
        absoluteDeadlineNanoseconds: UInt64
    ) async throws {}

    func sendArmAfterDurablePublish(
        _ preArm: InvestigationMachineCampaignPreArmFrame,
        terminalDescriptor: Int32, absoluteDeadlineNanoseconds: UInt64
    ) async throws {}

    func relayCredentialAfterExactPrompt(
        _ preArm: InvestigationMachineCampaignPreArmFrame,
        terminalDescriptor: Int32, absoluteDeadlineNanoseconds: UInt64
    ) async throws {}
    func validateTerminalEvidence(
        _ bytes: Data, rawGateReceipt: Data,
        finalReceipt: InvestigationMachineCoordinatorRawReceiptV1,
        preArm: InvestigationMachineCampaignPreArmFrame,
        absoluteDeadlineNanoseconds: UInt64
    ) async throws {}
}

package struct InvestigationMachineCampaignHarnessResult:
    Sendable, Equatable
{
    package let receipt: InvestigationMachineCoordinatorRawReceiptV1
    package let rawGateReceiptBytes: Data
    package let diagnosticBytes: Data
    package let outerIdentity: InvestigationMachineCampaignOuterIdentity
    package let receiptReachedEOF: Bool
    package let terminalReachedEOF: Bool
    package let exactWait: InvestigationMachineCampaignExactWait
    package let residue: InvestigationMachineCampaignResidueObservation
}

package enum InvestigationMachineCampaignHarnessFailure:
    Error, Sendable, Equatable
{
    case alreadyConsumed
    case bindingInvalid
    case deadlineExceeded
    case spawnUncertain
    case identityMismatch
    case receiptInvalid
    case diagnosticOverflow
    case childTerminated
    case exactReapUncertain
    case residueUncertain
    case transportUncertain
    case cancelled
    case unexpectedResponse
}

package enum InvestigationMachineCampaignCleanupIssue:
    Sendable, Equatable
{
    case identityObservationFailed
    case terminateFailed
    case waitFailed
    case closeFailed
    case residueObservationFailed
}

package struct InvestigationMachineCampaignHarnessFailureResult:
    Sendable, Equatable
{
    package let primary: InvestigationMachineCampaignHarnessFailure
    package let cleanupIssues: [InvestigationMachineCampaignCleanupIssue]
    package let verifiedPreArmFailure:
        InvestigationMachineCampaignPreArmFailureFrame?
    package let exactWait: InvestigationMachineCampaignExactWait?

    package init(
        primary: InvestigationMachineCampaignHarnessFailure,
        cleanupIssues: [InvestigationMachineCampaignCleanupIssue],
        verifiedPreArmFailure:
            InvestigationMachineCampaignPreArmFailureFrame? = nil,
        exactWait: InvestigationMachineCampaignExactWait? = nil
    ) {
        self.primary = primary
        self.cleanupIssues = cleanupIssues
        self.verifiedPreArmFailure = verifiedPreArmFailure
        self.exactWait = exactWait
    }
}

package enum InvestigationMachineCampaignHarnessOutcome:
    Sendable, Equatable
{
    case completed(InvestigationMachineCampaignHarnessResult)
    case failed(InvestigationMachineCampaignHarnessFailureResult)
}

package actor InvestigationMachineCampaignHarness {
    private static let readMaximumByteCount = 16 * 1_024
    private static let diagnosticMaximumByteCount =
        Int(InvestigationMachineEvidenceArtifact.maximumByteCount)
    private static let receiptMaximumByteCount =
        InvestigationMachineCoordinatorRawReceiptV1.maximumByteCount + 4
            + 512 + 4

    private enum State { case fresh, running, consumed }
    private let system: any InvestigationMachineCampaignHarnessSystem
    private var state = State.fresh

    package init(system: any InvestigationMachineCampaignHarnessSystem) {
        self.system = system
    }

    package func run(
        expected: InvestigationMachineCampaignExpectedBinding? = nil
    ) async -> InvestigationMachineCampaignHarnessOutcome {
        guard state == .fresh else { return Self.failure(.alreadyConsumed) }
        state = .running
        defer { state = .consumed }
        return await execute(expected: expected)
    }

    private func execute(
        expected: InvestigationMachineCampaignExpectedBinding?
    ) async -> InvestigationMachineCampaignHarnessOutcome {
        let deadline: UInt64
        do {
            guard case let .absoluteDeadline(value) = try await system.perform(
                .makeAbsoluteDeadline
            ), value > 0 else { return Self.failure(.deadlineExceeded) }
            deadline = value
        } catch { return Self.failure(.deadlineExceeded) }

        let harnessPID: pid_t
        let harnessUID: uid_t
        do {
            guard case let .harnessIdentity(processID, effectiveUserID) =
                    try await system.perform(.observeHarness(
                        absoluteDeadlineNanoseconds: deadline
                    )),
                  processID > 1
            else { return Self.failure(.identityMismatch) }
            harnessPID = processID
            harnessUID = effectiveUserID
        } catch { return Self.failure(.identityMismatch) }

        let spawned: InvestigationMachineCampaignSpawnedProcess
        do {
            guard case let .spawned(value) = try await system.perform(
                .spawnFixedSibling(absoluteDeadlineNanoseconds: deadline)
            )
            else { return Self.failure(.spawnUncertain) }
            spawned = value
        } catch { return Self.failure(.spawnUncertain) }
        guard Self.valid(spawned) else {
            guard spawned.processID > 1 else {
                return Self.failure(.spawnUncertain)
            }
            return await finalizeMalformedSpawn(
                primary: .spawnUncertain, spawned: spawned, deadline: deadline,
                harnessPID: harnessPID, harnessUID: harnessUID
            )
        }

        var primary: InvestigationMachineCampaignHarnessFailure?
        do {
            guard spawned.parentTransferCloseError == nil,
                  case let .bootstrap(bytes, reachedEOF) = try await system.perform(
                    .readBootstrap(
                        descriptor: spawned.bootstrapDescriptor,
                        maximumByteCount: 16,
                        absoluteDeadlineNanoseconds: deadline
                    )
                  ),
                  bytes == Data([
                      UInt8(STORNAUT_INVESTIGATION_CAMPAIGN_BOOTSTRAP_READY)
                  ]), reachedEOF
            else { primary = .spawnUncertain; throw HarnessInternalError.bootstrap }
        } catch {
            return await finalize(
                primary: primary ?? .spawnUncertain, spawned: spawned,
                deadline: deadline, outerIdentity: nil, receipt: nil,
                diagnosticBytes: Data(), receiptEOF: false, terminalEOF: false
            )
        }
        var outerIdentity: InvestigationMachineCampaignOuterIdentity?
        do {
            guard case let .outerIdentity(value) = try await system.perform(
                .observeOuterIdentity(
                    processID: spawned.processID,
                    absoluteDeadlineNanoseconds: deadline
                )
            ), Self.valid(
                value, spawned: spawned, harnessPID: harnessPID,
                harnessUID: harnessUID
            ) else {
                primary = .identityMismatch
                return await finalize(
                    primary: primary!, spawned: spawned, deadline: deadline,
                    outerIdentity: nil, receipt: nil, diagnosticBytes: Data(),
                    receiptEOF: false, terminalEOF: false
                )
            }
            outerIdentity = value
        } catch {
            return await finalize(
                primary: .identityMismatch, spawned: spawned,
                deadline: deadline, outerIdentity: nil, receipt: nil,
                diagnosticBytes: Data(), receiptEOF: false, terminalEOF: false
            )
        }

        var preArm: InvestigationMachineCampaignPreArmFrame?
        do {
            preArm = try await system.prepareActivation(
                receiptDescriptor: spawned.receiptDescriptor,
                terminalDescriptor: spawned.terminalDescriptor,
                absoluteDeadlineNanoseconds: deadline
            )
            if let preArm {
                try await system.durablyPublishArmedConsumed(
                    preArm, absoluteDeadlineNanoseconds: deadline
                )
                try await system.sendArmAfterDurablePublish(
                    preArm, terminalDescriptor: spawned.terminalDescriptor,
                    absoluteDeadlineNanoseconds: deadline
                )
                try await system.relayCredentialAfterExactPrompt(
                    preArm, terminalDescriptor: spawned.terminalDescriptor,
                    absoluteDeadlineNanoseconds: deadline
                )
            }
        } catch {
            return await finalize(
                primary: Task.isCancelled ? .cancelled : .transportUncertain,
                spawned: spawned, deadline: deadline,
                outerIdentity: outerIdentity, receipt: nil,
                diagnosticBytes: Data(), receiptEOF: false, terminalEOF: false
            )
        }

        var diagnosticBytes = Data()
        var receiptBytes = Data()
        var terminalEOF = false
        var receiptEOF = false
        var preferred = InvestigationMachineCampaignChannel.terminal

        drain: while !terminalEOF || !receiptEOF {
            if Task.isCancelled { primary = .cancelled; break }
            let channels = Self.orderedOpenChannels(
                preferred: preferred, terminalEOF: terminalEOF,
                receiptEOF: receiptEOF
            )
            do {
                guard case let .readable(ready) = try await system.perform(
                    .pollReadable(
                        channels: channels,
                        absoluteDeadlineNanoseconds: deadline
                    )
                ) else { primary = .unexpectedResponse; break }
                guard let channel = channels.first(where: { ready.contains($0) })
                else {
                    primary = !receiptEOF && !receiptBytes.isEmpty
                        ? .receiptInvalid : .deadlineExceeded
                    break
                }
                guard case let .read(observation) = try await system.perform(
                    .read(
                        channel: channel,
                        maximumByteCount: Self.readMaximumByteCount,
                        absoluteDeadlineNanoseconds: deadline
                    )
                ) else { primary = .unexpectedResponse; break }
                switch (channel, observation) {
                case (.terminal, .bytes(let bytes)):
                    guard !bytes.isEmpty, diagnosticBytes.count + bytes.count
                            <= Self.diagnosticMaximumByteCount
                    else { primary = .diagnosticOverflow; break drain }
                    diagnosticBytes.append(bytes)
                case (.receipt, .bytes(let bytes)):
                    guard !bytes.isEmpty, receiptBytes.count + bytes.count
                            <= Self.receiptMaximumByteCount
                    else { primary = .receiptInvalid; break drain }
                    receiptBytes.append(bytes)
                case (.terminal, .eof): terminalEOF = true
                case (.receipt, .eof): receiptEOF = true
                }
                preferred = channel == .terminal ? .receipt : .terminal
            } catch {
                primary = Task.isCancelled ? .cancelled : .transportUncertain
                break
            }
        }

        var receipt: InvestigationMachineCoordinatorRawReceiptV1?
        var preArmFailure: InvestigationMachineCampaignPreArmFailureFrame?
        var rawGateReceipt = Data()
        if primary == nil {
            do {
                let decoded = try Self.decodeReceiptStream(
                    receiptBytes, reachedEOF: receiptEOF, preArm: preArm
                )
                switch decoded {
                case .preArmFailure(let value):
                    guard preArm == nil, diagnosticBytes.isEmpty, terminalEOF else {
                        throw InvestigationMachineCampaignHarnessFailure.receiptInvalid
                    }
                    preArmFailure = value
                case .success(let value, let rawGate):
                    rawGateReceipt = rawGate
                    guard Self.matches(value, expected: expected, preArm: preArm)
                    else {
                        primary = .identityMismatch
                        return await finalize(
                            primary: primary!, spawned: spawned, deadline: deadline,
                            outerIdentity: outerIdentity, receipt: nil,
                            diagnosticBytes: diagnosticBytes,
                            receiptEOF: receiptEOF, terminalEOF: terminalEOF
                        )
                    }
                    receipt = value
                    if let preArm {
                        try await system.validateTerminalEvidence(
                            diagnosticBytes, rawGateReceipt: rawGateReceipt,
                            finalReceipt: value, preArm: preArm,
                            absoluteDeadlineNanoseconds: deadline
                        )
                    }
                }
            } catch { primary = .receiptInvalid }
        }

        if primary == nil, preArmFailure == nil {
            do {
                guard case let .outerIdentity(value) = try await system.perform(
                    .observeOuterIdentity(
                        processID: spawned.processID,
                        absoluteDeadlineNanoseconds: deadline
                    )
                ), value == outerIdentity, Self.valid(
                    value, spawned: spawned, harnessPID: harnessPID,
                    harnessUID: harnessUID
                ) else {
                    primary = .identityMismatch
                    return await finalize(
                        primary: primary!, spawned: spawned, deadline: deadline,
                        outerIdentity: outerIdentity, receipt: receipt,
                        diagnosticBytes: diagnosticBytes, receiptEOF: receiptEOF,
                        terminalEOF: terminalEOF
                    )
                }
            } catch { primary = .identityMismatch }
        }

        return await finalize(
            primary: primary, spawned: spawned, deadline: deadline,
            outerIdentity: outerIdentity, receipt: receipt,
            preArmFailure: preArmFailure,
            rawGateReceipt: rawGateReceipt, diagnosticBytes: diagnosticBytes,
            receiptEOF: receiptEOF,
            terminalEOF: terminalEOF
        )
    }

    private func finalize(
        primary initialPrimary: InvestigationMachineCampaignHarnessFailure?,
        spawned: InvestigationMachineCampaignSpawnedProcess, deadline: UInt64,
        outerIdentity: InvestigationMachineCampaignOuterIdentity?,
        receipt: InvestigationMachineCoordinatorRawReceiptV1?,
        preArmFailure: InvestigationMachineCampaignPreArmFailureFrame? = nil,
        rawGateReceipt: Data = Data(),
        diagnosticBytes: Data, receiptEOF: Bool, terminalEOF: Bool
    ) async -> InvestigationMachineCampaignHarnessOutcome {
        var primary = initialPrimary
        var cleanupIssues: [InvestigationMachineCampaignCleanupIssue] = []
        var terminationAttempted = false
        if primary != nil {
            terminationAttempted = true
            do {
                guard case .completed = try await system.perform(
                    .terminateOwnedGroup(
                        processID: spawned.processID,
                        processGroupID: spawned.processID,
                        absoluteDeadlineNanoseconds: deadline
                    )
                ) else { throw HarnessInternalError.unexpectedResponse }
            } catch { cleanupIssues.append(.terminateFailed) }
        }

        var exactWait: InvestigationMachineCampaignExactWait?
        var needsTerminalWaitRetry = false
        do {
            guard case let .wait(value) = try await system.perform(
                .waitExact(
                    processID: spawned.processID,
                    absoluteDeadlineNanoseconds: deadline
                )
            ) else { throw HarnessInternalError.unexpectedResponse }
            exactWait = value
            switch value {
            case .exited(let status):
                if let preArmFailure {
                    if status != preArmFailure.reason.expectedExitStatus {
                        primary = .receiptInvalid
                    }
                } else if status != 0, primary == nil {
                    primary = .childTerminated
                }
            case .signaled:
                if primary == nil { primary = .childTerminated }
            case .stopped:
                if primary == nil { primary = .childTerminated }
                needsTerminalWaitRetry = true
            }
        } catch {
            cleanupIssues.append(.waitFailed)
            if primary == nil { primary = .exactReapUncertain }
            needsTerminalWaitRetry = true
        }
        if needsTerminalWaitRetry {
            if !terminationAttempted {
                terminationAttempted = true
                do {
                    guard case .completed = try await system.perform(
                        .terminateOwnedGroup(
                            processID: spawned.processID,
                            processGroupID: spawned.processID,
                            absoluteDeadlineNanoseconds: deadline
                        )
                    ) else { throw HarnessInternalError.unexpectedResponse }
                } catch { cleanupIssues.append(.terminateFailed) }
            }
            do {
                guard case let .wait(value) = try await system.perform(
                    .waitExact(
                        processID: spawned.processID,
                        absoluteDeadlineNanoseconds: deadline
                    )
                ) else { throw HarnessInternalError.unexpectedResponse }
                switch value {
                case .exited, .signaled: exactWait = value
                case .stopped: throw HarnessInternalError.unexpectedResponse
                }
            } catch { cleanupIssues.append(.waitFailed) }
        }
        return await completeFinalization(
            primary: primary, cleanupIssues: cleanupIssues, spawned: spawned,
            deadline: deadline, outerIdentity: outerIdentity, receipt: receipt,
            preArmFailure: preArmFailure,
            rawGateReceipt: rawGateReceipt, diagnosticBytes: diagnosticBytes,
            receiptEOF: receiptEOF,
            terminalEOF: terminalEOF, exactWait: exactWait
        )
    }

    private func finalizeMalformedSpawn(
        primary: InvestigationMachineCampaignHarnessFailure,
        spawned: InvestigationMachineCampaignSpawnedProcess, deadline: UInt64,
        harnessPID: pid_t, harnessUID: uid_t
    ) async -> InvestigationMachineCampaignHarnessOutcome {
        var cleanupIssues: [InvestigationMachineCampaignCleanupIssue] = []
        do {
            guard case let .outerIdentity(value) = try await system.perform(
                .observeOuterIdentity(
                    processID: spawned.processID,
                    absoluteDeadlineNanoseconds: deadline
                )
            ), Self.validIdentityShape(
                value, processID: spawned.processID, harnessPID: harnessPID,
                harnessUID: harnessUID
            ) else { throw HarnessInternalError.unexpectedResponse }
            _ = value
        } catch { cleanupIssues.append(.identityObservationFailed) }
        do {
            guard case .completed = try await system.perform(
                .terminateOwnedGroup(
                    processID: spawned.processID,
                    processGroupID: spawned.processID,
                    absoluteDeadlineNanoseconds: deadline
                )
            ) else { throw HarnessInternalError.unexpectedResponse }
        } catch { cleanupIssues.append(.terminateFailed) }
        do {
            guard case let .wait(value) = try await system.perform(.waitExact(
                processID: spawned.processID,
                absoluteDeadlineNanoseconds: deadline
            )) else { throw HarnessInternalError.unexpectedResponse }
            switch value {
            case .exited, .signaled: break
            case .stopped:
                guard case .completed = try await system.perform(
                    .terminateOwnedGroup(
                        processID: spawned.processID,
                        processGroupID: spawned.processID,
                        absoluteDeadlineNanoseconds: deadline
                    )
                ), case let .wait(retry) = try await system.perform(.waitExact(
                    processID: spawned.processID,
                    absoluteDeadlineNanoseconds: deadline
                )) else { throw HarnessInternalError.unexpectedResponse }
                guard case .exited = retry else {
                    if case .signaled = retry { break }
                    throw HarnessInternalError.unexpectedResponse
                }
            }
        } catch { cleanupIssues.append(.waitFailed) }
        do {
            guard case .completed = try await system.perform(
                .closeParentChannels(
                    terminalDescriptor: spawned.terminalDescriptor,
                    receiptDescriptor: spawned.receiptDescriptor,
                    bootstrapDescriptor: spawned.bootstrapDescriptor,
                    absoluteDeadlineNanoseconds: deadline
                )
            ) else { throw HarnessInternalError.unexpectedResponse }
        } catch { cleanupIssues.append(.closeFailed) }
        do {
            guard case let .residue(value) = try await system.perform(
                .observeResidue(
                    processGroupID: spawned.processID,
                    sessionID: spawned.processID,
                    absoluteDeadlineNanoseconds: deadline
                )
            ), value.complete, value.processGroupMembers.isEmpty,
                value.sessionMembers.isEmpty
            else { throw HarnessInternalError.unexpectedResponse }
        } catch { cleanupIssues.append(.residueObservationFailed) }
        return .failed(.init(primary: primary, cleanupIssues: cleanupIssues))
    }

    private func completeFinalization(
        primary initialPrimary: InvestigationMachineCampaignHarnessFailure?,
        cleanupIssues initialCleanupIssues:
            [InvestigationMachineCampaignCleanupIssue],
        spawned: InvestigationMachineCampaignSpawnedProcess, deadline: UInt64,
        outerIdentity: InvestigationMachineCampaignOuterIdentity?,
        receipt: InvestigationMachineCoordinatorRawReceiptV1?,
        preArmFailure: InvestigationMachineCampaignPreArmFailureFrame?,
        rawGateReceipt: Data,
        diagnosticBytes: Data, receiptEOF: Bool, terminalEOF: Bool,
        exactWait: InvestigationMachineCampaignExactWait?
    ) async -> InvestigationMachineCampaignHarnessOutcome {
        var primary = initialPrimary
        var cleanupIssues = initialCleanupIssues
        do {
            guard case .completed = try await system.perform(
                .closeParentChannels(
                    terminalDescriptor: spawned.terminalDescriptor,
                    receiptDescriptor: spawned.receiptDescriptor,
                    bootstrapDescriptor: spawned.bootstrapDescriptor,
                    absoluteDeadlineNanoseconds: deadline
                )
            ) else { throw HarnessInternalError.unexpectedResponse }
        } catch {
            cleanupIssues.append(.closeFailed)
            if primary == nil { primary = .transportUncertain }
        }

        var residue: InvestigationMachineCampaignResidueObservation?
        do {
            guard case let .residue(value) = try await system.perform(
                .observeResidue(
                    processGroupID: spawned.processID,
                    sessionID: spawned.processID,
                    absoluteDeadlineNanoseconds: deadline
                )
            ) else { throw HarnessInternalError.unexpectedResponse }
            residue = value
            if !value.complete || !value.processGroupMembers.isEmpty
                || !value.sessionMembers.isEmpty
            {
                if primary == nil { primary = .residueUncertain }
            }
        } catch {
            cleanupIssues.append(.residueObservationFailed)
            if primary == nil { primary = .residueUncertain }
        }

        if let primary {
            return .failed(.init(
                primary: primary, cleanupIssues: cleanupIssues,
                exactWait: exactWait
            ))
        }
        if let preArmFailure {
            guard cleanupIssues.isEmpty, receipt == nil, rawGateReceipt.isEmpty,
                  diagnosticBytes.isEmpty, receiptEOF, terminalEOF,
                  let exactWait, let residue, let outerIdentity,
                  case .exited(preArmFailure.reason.expectedExitStatus) = exactWait,
                  residue.complete, residue.processGroupMembers.isEmpty,
                  residue.sessionMembers.isEmpty, outerIdentity.processID > 1
            else { return Self.failure(.unexpectedResponse) }
            return .failed(.init(
                primary: .childTerminated, cleanupIssues: [],
                verifiedPreArmFailure: preArmFailure, exactWait: exactWait
            ))
        }
        guard cleanupIssues.isEmpty, let receipt, let outerIdentity,
              let exactWait, let residue, receiptEOF, terminalEOF
        else { return Self.failure(.unexpectedResponse) }
        return .completed(.init(
            receipt: receipt, rawGateReceiptBytes: rawGateReceipt,
            diagnosticBytes: diagnosticBytes,
            outerIdentity: outerIdentity, receiptReachedEOF: receiptEOF,
            terminalReachedEOF: terminalEOF, exactWait: exactWait,
            residue: residue
        ))
    }

    private static func valid(
        _ spawned: InvestigationMachineCampaignSpawnedProcess
    ) -> Bool {
        spawned.processID > 1 && spawned.terminalDescriptor >= 3
            && spawned.receiptDescriptor >= 3
            && spawned.bootstrapDescriptor >= 3
            && spawned.terminalDescriptor != spawned.receiptDescriptor
            && spawned.terminalDescriptor != spawned.bootstrapDescriptor
            && spawned.receiptDescriptor != spawned.bootstrapDescriptor
    }

    private static func valid(
        _ identity: InvestigationMachineCampaignOuterIdentity,
        spawned: InvestigationMachineCampaignSpawnedProcess,
        harnessPID: pid_t, harnessUID: uid_t
    ) -> Bool {
        validIdentityShape(
            identity, processID: spawned.processID, harnessPID: harnessPID,
            harnessUID: harnessUID
        )
    }

    private static func validIdentityShape(
        _ identity: InvestigationMachineCampaignOuterIdentity,
        processID: pid_t, harnessPID: pid_t, harnessUID: uid_t
    ) -> Bool {
        identity.processID == processID
            && identity.processIDVersion > 0
            && identity.parentProcessID == harnessPID
            && identity.processGroupID == processID
            && identity.sessionID == processID
            && identity.foregroundProcessGroupID == processID
            && identity.effectiveUserID == harnessUID
            && identity.startTimeSeconds > 0
            && identity.startTimeMicroseconds < 1_000_000
    }

    private static func matches(
        _ receipt: InvestigationMachineCoordinatorRawReceiptV1,
        expected: InvestigationMachineCampaignExpectedBinding?,
        preArm: InvestigationMachineCampaignPreArmFrame?
    ) -> Bool {
        if let preArm {
            return receipt.outerAttemptUUID == preArm.outerAttemptUUID
                && receipt.buildProvenanceSHA256
                    == preArm.buildProvenanceSHA256.lowercaseHex
                && receipt.signedBindingSHA256
                    == preArm.signedRuntimeBindingSHA256
                && receipt.wholeProjectedInputSHA256
                    == preArm.wholeProjectedInputSHA256
        }
        guard let expected else { return false }
        return receipt.outerAttemptUUID == expected.attemptUUID
            && receipt.buildProvenanceSHA256 == expected.buildProvenanceSHA256
            && receipt.signedBindingSHA256 == expected.signedRuntimeBindingSHA256
            && receipt.wholeProjectedInputSHA256 == expected.wholeProjectedInputSHA256
    }

    private enum ReceiptStream {
        case success(InvestigationMachineCoordinatorRawReceiptV1, Data)
        case preArmFailure(InvestigationMachineCampaignPreArmFailureFrame)
    }

    private static func decodeReceiptStream(
        _ bytes: Data, reachedEOF: Bool,
        preArm: InvestigationMachineCampaignPreArmFrame?
    ) throws -> ReceiptStream {
        guard reachedEOF else {
            throw InvestigationMachineCampaignHarnessFailure.receiptInvalid
        }
        guard preArm != nil else {
            if let failure = try? InvestigationMachineCampaignPreArmFailureFrame
                .decodeFrame(bytes, reachedEOF: true) {
                return .preArmFailure(failure)
            }
            return .success(
                try InvestigationMachineCoordinatorRawReceiptV1.decodeFrame(
                    bytes, reachedEOF: true
                ), Data()
            )
        }
        var cursor = 0
        func nextFrame() throws -> Data {
            guard cursor <= bytes.count - 4 else {
                throw InvestigationMachineCampaignHarnessFailure.receiptInvalid
            }
            let length = bytes[cursor..<(cursor + 4)].reduce(UInt32(0)) {
                ($0 << 8) | UInt32($1)
            }
            cursor += 4
            guard length > 0, let count = Int(exactly: length),
                  count <= InvestigationMachineCoordinatorRawReceiptV1.maximumByteCount,
                  cursor <= bytes.count - count
            else { throw InvestigationMachineCampaignHarnessFailure.receiptInvalid }
            defer { cursor += count }
            return Data(bytes[cursor..<(cursor + count)])
        }
        let rawGateReceipt = try nextFrame()
        let finalReceiptBytes = try nextFrame()
        guard cursor == bytes.count else {
            throw InvestigationMachineCampaignHarnessFailure.receiptInvalid
        }
        let final = try InvestigationMachineCoordinatorRawReceiptV1.decode(
            finalReceiptBytes
        )
        guard InvestigationHandoffSHA256.hashing(rawGateReceipt)
                == final.gateTransportReceiptSHA256
        else { throw InvestigationMachineCampaignHarnessFailure.receiptInvalid }
        return .success(final, rawGateReceipt)
    }

    private static func orderedOpenChannels(
        preferred: InvestigationMachineCampaignChannel,
        terminalEOF: Bool, receiptEOF: Bool
    ) -> [InvestigationMachineCampaignChannel] {
        let other: InvestigationMachineCampaignChannel = preferred == .terminal
            ? .receipt : .terminal
        return [preferred, other].filter { channel in
            channel == .terminal ? !terminalEOF : !receiptEOF
        }
    }

    private static func failure(
        _ primary: InvestigationMachineCampaignHarnessFailure
    ) -> InvestigationMachineCampaignHarnessOutcome {
        .failed(.init(primary: primary, cleanupIssues: []))
    }
}

private enum HarnessInternalError: Error {
    case bootstrap
    case unexpectedResponse
}
#endif
