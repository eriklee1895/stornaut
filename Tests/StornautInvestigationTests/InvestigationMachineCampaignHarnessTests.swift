import Darwin
import Foundation
import Testing

@testable import StornautInvestigationMachineCampaignSupport
@testable import StornautInvestigationHandoffContract

@Suite("Investigation machine campaign harness", .serialized)
struct InvestigationMachineCampaignHarnessTests {
    @Test
    func validFragmentedReceiptUsesOneDeadlineAndFairDrain() async throws {
        let fixture = try CampaignHarnessFixture()
        let outcome = await InvestigationMachineCampaignHarness(
            system: fixture.system).run(expected: fixture.binding)
        let result = try #require(outcome.completedResult)

        #expect(result.receipt == fixture.receipt)
        #expect(result.diagnosticBytes == Data("terminal-output".utf8))
        #expect(result.outerIdentity == fixture.outerIdentity)
        #expect(result.receiptReachedEOF)
        #expect(result.terminalReachedEOF)
        #expect(result.exactWait == .exited(status: 0))
        #expect(result.residue == .init(
            processGroupMembers: [], sessionMembers: [], complete: true))
        let operations = await fixture.system.operations
        #expect(operations.compactMap(\.deadline).allSatisfy {
            $0 == fixture.deadline
        })
        #expect(operations.compactMap(\.readChannel).prefix(4) == [
            .terminal, .receipt, .terminal, .receipt,
        ])
        #expect(operations.filter(\.isWait).count == 1)
        #expect(operations.filter(\.isClose).count == 1)
        #expect(operations.filter(\.isSpawn).count == 1)
        #expect(operations.filter(\.isBootstrap).count == 1)
    }

    @Test
    func concurrentAndRepeatedCallsSpawnExactlyOnce() async throws {
        let fixture = try CampaignHarnessFixture(blockSpawn: true)
        let harness = InvestigationMachineCampaignHarness(system: fixture.system)
        let first = Task { await harness.run(expected: fixture.binding) }
        await fixture.system.waitUntilSpawnEntered()
        let concurrent = await harness.run(expected: fixture.binding)
        #expect(concurrent.failure?.primary == .alreadyConsumed)
        await fixture.system.releaseSpawn()
        #expect(try #require(await first.value.completedResult).receipt == fixture.receipt)
        #expect((await harness.run(expected: fixture.binding)).failure?.primary
            == .alreadyConsumed)
        #expect(await fixture.system.operations.filter(\.isSpawn).count == 1)
    }

    @Test
    func invalidSpawnDescriptorsRetainOwnedChildForCleanup() async throws {
        let fixture = try CampaignHarnessFixture(
            waitMutation: .stopped, invalidSpawnDescriptors: true
        )
        let outcome = await InvestigationMachineCampaignHarness(
            system: fixture.system).run(expected: fixture.binding)
        #expect(outcome.failure?.primary == .spawnUncertain)
        let operations = await fixture.system.operations
        #expect(operations.filter(\.isTerminate).count == 2)
        #expect(operations.filter(\.isWait).count == 2)
        #expect(operations.filter(\.isClose).count == 1)
        #expect(operations.filter(\.isResidue).count == 1)
        #expect(outcome.failure?.cleanupIssues.contains(
            .identityObservationFailed) == true)
    }

    @Test(arguments: CampaignHarnessWaitMutation.allCases)
    fileprivate func nonterminalWaitForcesTerminationAndSecondExactWait(
        _ mutation: CampaignHarnessWaitMutation
    ) async throws {
        let fixture = try CampaignHarnessFixture(waitMutation: mutation)
        let outcome = await InvestigationMachineCampaignHarness(
            system: fixture.system).run(expected: fixture.binding)
        #expect(outcome.failure?.primary == mutation.expectedFailure)
        let operations = await fixture.system.operations
        #expect(operations.filter(\.isTerminate).count == 1)
        #expect(operations.filter(\.isWait).count == 2)
        #expect(operations.filter(\.isClose).count == 1)
        #expect(operations.filter(\.isResidue).count == 1)
    }

    @Test(arguments: CampaignHarnessBootstrapMutation.allCases)
    fileprivate func childCreationUncertaintyRemainsOwned(
        _ mutation: CampaignHarnessBootstrapMutation
    ) async throws {
        let fixture = try CampaignHarnessFixture(bootstrapMutation: mutation)
        let outcome = await InvestigationMachineCampaignHarness(
            system: fixture.system).run(expected: fixture.binding)
        #expect(outcome.failure?.primary == .spawnUncertain)
        let operations = await fixture.system.operations
        #expect(operations.filter(\.isSpawn).count == 1)
        #expect(operations.filter(\.isWait).count == 1)
        #expect(operations.filter(\.isClose).count == 1)
        #expect(operations.filter(\.isResidue).count == 1)
    }

    @Test(arguments: CampaignHarnessInvalidReceipt.allCases)
    fileprivate func invalidReceiptFrameFailsClosed(
        _ mutation: CampaignHarnessInvalidReceipt
    ) async throws {
        let fixture = try CampaignHarnessFixture(receiptMutation: mutation)
        let outcome = await InvestigationMachineCampaignHarness(
            system: fixture.system).run(expected: fixture.binding)
        #expect(outcome.failure?.primary == mutation.expectedFailure)
        #expect(await fixture.system.operations.filter(\.isWait).count == 1)
        #expect(await fixture.system.operations.filter(\.isClose).count == 1)
        #expect(await fixture.system.operations.filter(\.isResidue).count == 1)
    }

    @Test(arguments: CampaignHarnessIdentityMutation.allCases)
    fileprivate func outerAndInnerIdentityRemainIndependent(
        _ mutation: CampaignHarnessIdentityMutation
    ) async throws {
        let fixture = try CampaignHarnessFixture(identityMutation: mutation)
        let outcome = await InvestigationMachineCampaignHarness(
            system: fixture.system).run(expected: fixture.binding)
        #expect(outcome.failure?.primary == .identityMismatch)
        #expect(await fixture.system.operations.filter(\.isWait).count == 1)
    }

    @Test(arguments: CampaignHarnessResidueMutation.allCases)
    fileprivate func residueAndCleanupFailuresRemainFailClosed(
        _ mutation: CampaignHarnessResidueMutation
    ) async throws {
        let fixture = try CampaignHarnessFixture(residueMutation: mutation)
        let outcome = await InvestigationMachineCampaignHarness(
            system: fixture.system).run(expected: fixture.binding)
        #expect(outcome.failure?.primary == mutation.expectedFailure)
        #expect(outcome.failure?.cleanupIssues == mutation.expectedCleanupIssues)
        let operations = await fixture.system.operations
        #expect(operations.filter(\.isWait).count == 1)
        #expect(operations.filter(\.isResidue).count == 1)
    }
}

private enum CampaignHarnessInvalidReceipt: CaseIterable {
    case truncated, trailing, missingEOF
    var expectedFailure: InvestigationMachineCampaignHarnessFailure {
        .receiptInvalid
    }
}

private enum CampaignHarnessIdentityMutation: CaseIterable {
    case outerStart, outerGroup, innerAttempt
}

private enum CampaignHarnessBootstrapMutation: CaseIterable {
    case failureRecord, missingEOF, parentTransferClose
}

private enum CampaignHarnessWaitMutation: CaseIterable {
    case stopped, stoppedTwice, failed
    var expectedFailure: InvestigationMachineCampaignHarnessFailure {
        switch self {
        case .stopped, .stoppedTwice: .childTerminated
        case .failed: .exactReapUncertain
        }
    }
}

private enum CampaignHarnessResidueMutation: CaseIterable {
    case processGroup, session, closeWithPrimaryFailure
    var expectedFailure: InvestigationMachineCampaignHarnessFailure {
        self == .closeWithPrimaryFailure ? .receiptInvalid : .residueUncertain
    }
    var expectedCleanupIssues: [InvestigationMachineCampaignCleanupIssue] {
        self == .closeWithPrimaryFailure ? [.closeFailed] : []
    }
}

private actor CampaignHarnessSystemRecorder:
    InvestigationMachineCampaignHarnessSystem
{
    private(set) var operations: [InvestigationMachineCampaignHarnessOperation] = []
    private let deadlineValue: UInt64
    private let spawnedValue: InvestigationMachineCampaignSpawnedProcess
    private let outerValue: InvestigationMachineCampaignOuterIdentity
    private let frame: Data
    private let identityMutation: CampaignHarnessIdentityMutation?
    private let bootstrapMutation: CampaignHarnessBootstrapMutation?
    private let waitMutation: CampaignHarnessWaitMutation?
    private let invalidSpawnDescriptors: Bool
    private let residueMutation: CampaignHarnessResidueMutation?
    private let blockSpawn: Bool
    private var reads: [InvestigationMachineCampaignChannel: [InvestigationMachineCampaignReadObservation]]
    private var outerObservationCount = 0
    private var waitCount = 0
    private var spawnContinuation: CheckedContinuation<Void, Never>?
    private var enteredContinuations: [CheckedContinuation<Void, Never>] = []

    init(
        deadline: UInt64, spawned: InvestigationMachineCampaignSpawnedProcess,
        outer: InvestigationMachineCampaignOuterIdentity, frame: Data,
        receiptMutation: CampaignHarnessInvalidReceipt?,
        identityMutation: CampaignHarnessIdentityMutation?,
        residueMutation: CampaignHarnessResidueMutation?,
        bootstrapMutation: CampaignHarnessBootstrapMutation?,
        waitMutation: CampaignHarnessWaitMutation?,
        invalidSpawnDescriptors: Bool, blockSpawn: Bool
    ) {
        deadlineValue = deadline; spawnedValue = spawned; outerValue = outer
        self.identityMutation = identityMutation
        self.bootstrapMutation = bootstrapMutation
        self.waitMutation = waitMutation
        self.invalidSpawnDescriptors = invalidSpawnDescriptors
        self.residueMutation = residueMutation; self.blockSpawn = blockSpawn
        let effectiveReceiptMutation = receiptMutation
            ?? (residueMutation == .closeWithPrimaryFailure ? .trailing : nil)
        let receiptBytes: Data
        switch effectiveReceiptMutation {
        case .truncated: receiptBytes = Data(frame.dropLast())
        case .trailing: receiptBytes = frame + Data([0xff])
        case .missingEOF, .none: receiptBytes = frame
        }
        self.frame = receiptBytes
        let terminalReads: [InvestigationMachineCampaignReadObservation] = [
            .bytes(Data("terminal-".utf8)), .bytes(Data("output".utf8)), .eof,
        ]
        let receiptTail: [InvestigationMachineCampaignReadObservation] =
            effectiveReceiptMutation == .missingEOF ? [] : [.eof]
        let receiptReads: [InvestigationMachineCampaignReadObservation] = [
            .bytes(Data(receiptBytes.prefix(3))),
            .bytes(Data(receiptBytes.dropFirst(3))),
        ] + receiptTail
        reads = [.terminal: terminalReads, .receipt: receiptReads]
    }

    func perform(
        _ operation: InvestigationMachineCampaignHarnessOperation
    ) async throws -> InvestigationMachineCampaignHarnessResponse {
        operations.append(operation)
        switch operation {
        case .makeAbsoluteDeadline:
            return .absoluteDeadline(deadlineValue)
        case .observeHarness:
            return .harnessIdentity(processID: 100, effectiveUserID: 501)
        case .spawnFixedSibling:
            if blockSpawn {
                for continuation in enteredContinuations { continuation.resume() }
                enteredContinuations.removeAll()
                await withCheckedContinuation { spawnContinuation = $0 }
            }
            return .spawned(spawnedValue)
        case .readBootstrap:
            switch bootstrapMutation {
            case .failureRecord:
                return .bootstrap(bytes: Data(repeating: 1, count: 16), reachedEOF: true)
            case .missingEOF:
                return .bootstrap(bytes: Data([0xa5]), reachedEOF: false)
            default:
                return .bootstrap(bytes: Data([0xa5]), reachedEOF: true)
            }
        case .observeOuterIdentity:
            if invalidSpawnDescriptors { throw FixtureError.failed }
            outerObservationCount += 1
            var value = outerValue
            if identityMutation == .outerStart, outerObservationCount > 1 {
                value = value.replacing(startTimeMicroseconds: 99)
            } else if identityMutation == .outerGroup, outerObservationCount > 1 {
                value = value.replacing(processGroupID: 201)
            }
            return .outerIdentity(value)
        case .pollReadable(let channels, _):
            return .readable(channels.filter { !(reads[$0] ?? []).isEmpty })
        case .read(let channel, _, _):
            guard var queue = reads[channel], !queue.isEmpty else { return .read(.eof) }
            let value = queue.removeFirst(); reads[channel] = queue
            return .read(value)
        case .waitExact:
            waitCount += 1
            if waitCount == 1, waitMutation == .stopped {
                return .wait(.stopped(signal: SIGSTOP))
            }
            if waitMutation == .stoppedTwice {
                return .wait(.stopped(
                    signal: waitCount == 1 ? SIGSTOP : SIGTSTP
                ))
            }
            if waitCount == 1, waitMutation == .failed {
                throw FixtureError.failed
            }
            return .wait(.exited(status: 0))
        case .observeResidue:
            let residue: InvestigationMachineCampaignResidueObservation
            switch residueMutation {
            case .processGroup: residue = .init(
                processGroupMembers: [spawnedValue.processID],
                sessionMembers: [], complete: true)
            case .session: residue = .init(
                processGroupMembers: [], sessionMembers: [spawnedValue.processID],
                complete: true)
            default: residue = .init(
                processGroupMembers: [], sessionMembers: [], complete: true)
            }
            return .residue(residue)
        case .terminateOwnedGroup:
            return .completed
        case .closeParentChannels:
            if invalidSpawnDescriptors { throw FixtureError.failed }
            if residueMutation == .closeWithPrimaryFailure { throw FixtureError.failed }
            return .completed
        }
    }

    func waitUntilSpawnEntered() async {
        if operations.contains(where: \.isSpawn) { return }
        await withCheckedContinuation { enteredContinuations.append($0) }
    }

    func releaseSpawn() { spawnContinuation?.resume(); spawnContinuation = nil }
}

private struct CampaignHarnessFixture {
    let binding: InvestigationMachineCampaignExpectedBinding
    let receipt: InvestigationMachineCoordinatorRawReceiptV1
    let outerIdentity: InvestigationMachineCampaignOuterIdentity
    let deadline: UInt64 = 999_000
    let system: CampaignHarnessSystemRecorder

    init(
        receiptMutation: CampaignHarnessInvalidReceipt? = nil,
        identityMutation: CampaignHarnessIdentityMutation? = nil,
        residueMutation: CampaignHarnessResidueMutation? = nil,
        bootstrapMutation: CampaignHarnessBootstrapMutation? = nil,
        waitMutation: CampaignHarnessWaitMutation? = nil,
        invalidSpawnDescriptors: Bool = false,
        blockSpawn: Bool = false
    ) throws {
        let attempt = Self.uuid(0x41)
        let build = String(repeating: "a", count: 64)
        let signed = Self.digest(0x42), input = Self.digest(0x43)
        binding = try .init(
            attemptUUID: attempt, buildProvenanceSHA256: build,
            signedRuntimeBindingSHA256: signed, wholeProjectedInputSHA256: input)
        let valid = try InvestigationMachineCoordinatorRawReceiptV1(
            buildProvenanceSHA256: build, signedBindingSHA256: signed,
            outerAttemptUUID: identityMutation == .innerAttempt ? Self.uuid(0xee) : attempt,
            wholeProjectedInputSHA256: input,
            capsule: .init(device: 1, inode: 2, generation: 3, size: 4),
            gateExecutableSHA256: Self.digest(0x44),
            gateTransportReceiptSHA256: Self.digest(0x45),
            gateProcessID: 4_001, gateProcessGroupID: 4_001,
            gateSessionID: 3_901, exactGateWaitClassification: .exited(status: 0),
            receiptReachedEOF: true, receiptOverflowObserved: false,
            receiptDeadlineExpired: false, capsuleSettlementRemoved: true,
            attemptBaseRetired: true, runtimeArtifactsRetired: true,
            monotonicStartedNanoseconds: 10, monotonicCompletedNanoseconds: 20)
        receipt = valid
        let body = try valid.encoded()
        var count = UInt32(body.count).bigEndian
        let frame = withUnsafeBytes(of: &count) { Data($0) } + body
        let spawned = InvestigationMachineCampaignSpawnedProcess(
            processID: 200, terminalDescriptor: 10,
            receiptDescriptor: invalidSpawnDescriptors ? 10 : 11,
            parentTransferCloseError:
                bootstrapMutation == .parentTransferClose ? EIO : nil)
        outerIdentity = .init(
            processID: 200, processIDVersion: 7, parentProcessID: 100,
            processGroupID: 200, sessionID: 200,
            foregroundProcessGroupID: 200, effectiveUserID: 501,
            startTimeSeconds: 20, startTimeMicroseconds: 30)
        system = CampaignHarnessSystemRecorder(
            deadline: deadline, spawned: spawned, outer: outerIdentity,
            frame: frame, receiptMutation: receiptMutation,
            identityMutation: identityMutation, residueMutation: residueMutation,
            bootstrapMutation: bootstrapMutation, waitMutation: waitMutation,
            invalidSpawnDescriptors: invalidSpawnDescriptors,
            blockSpawn: blockSpawn)
    }

    private static func digest(_ byte: UInt8) -> InvestigationHandoffSHA256 {
        .hashing(Data(repeating: byte, count: 32))
    }
    private static func uuid(_ byte: UInt8) -> UUID {
        UUID(uuid: (byte, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    }
}

private enum FixtureError: Error { case failed }

private extension InvestigationMachineCampaignOuterIdentity {
    func replacing(
        processGroupID: pid_t? = nil, startTimeMicroseconds: UInt64? = nil
    ) -> Self {
        .init(
            processID: processID, processIDVersion: processIDVersion,
            parentProcessID: parentProcessID,
            processGroupID: processGroupID ?? self.processGroupID,
            sessionID: sessionID,
            foregroundProcessGroupID: foregroundProcessGroupID,
            effectiveUserID: effectiveUserID, startTimeSeconds: startTimeSeconds,
            startTimeMicroseconds: startTimeMicroseconds ?? self.startTimeMicroseconds)
    }
}

private extension InvestigationMachineCampaignHarnessOutcome {
    var completedResult: InvestigationMachineCampaignHarnessResult? {
        guard case .completed(let value) = self else { return nil }
        return value
    }
    var failure: InvestigationMachineCampaignHarnessFailureResult? {
        guard case .failed(let value) = self else { return nil }
        return value
    }
}

private extension InvestigationMachineCampaignHarnessOperation {
    var deadline: UInt64? {
        switch self {
        case .makeAbsoluteDeadline: nil
        case .observeHarness(let value), .spawnFixedSibling(let value),
             .readBootstrap(_, _, let value),
             .observeOuterIdentity(_, let value), .pollReadable(_, let value),
             .read(_, _, let value), .terminateOwnedGroup(_, _, let value),
             .waitExact(_, let value), .observeResidue(_, _, let value),
             .closeParentChannels(_, _, _, let value): value
        }
    }
    var readChannel: InvestigationMachineCampaignChannel? {
        guard case .read(let channel, _, _) = self else { return nil }
        return channel
    }
    var isWait: Bool { if case .waitExact = self { true } else { false } }
    var isClose: Bool { if case .closeParentChannels = self { true } else { false } }
    var isSpawn: Bool { if case .spawnFixedSibling = self { true } else { false } }
    var isTerminate: Bool { if case .terminateOwnedGroup = self { true } else { false } }
    var isBootstrap: Bool { if case .readBootstrap = self { true } else { false } }
    var isResidue: Bool { if case .observeResidue = self { true } else { false } }
}
