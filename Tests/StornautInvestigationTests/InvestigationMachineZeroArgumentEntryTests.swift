import Darwin
import CryptoKit
import Foundation
import Testing

@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachineDriverSupport

@Suite("Investigation machine zero-argument entry", .serialized)
struct InvestigationMachineZeroArgumentEntryTests {
    @Test
    func completionArtifactMatchesIndependentGoldenAndZeroBeforeHash() throws {
        let summary = try completionSummary()
        let artifact = try InvestigationMachineDriverCompletionArtifact(
            summary: summary
        )
        let encoded = try artifact.encoded()
        let decoded = try InvestigationMachineDriverCompletionArtifact.decode(
            encoded
        )

        let zeroed = independentCompletionTranscript(
            summary: summary, digest: Data(repeating: 0, count: 32)
        )
        let goldenDigest =
            "12215fb369d714711e0f2c54bf5e43500"
            + "b811e0957ed0b5db6a52aeb82432b35"
        let goldenArtifact =
            "53544e4300000000002973746f726e6175742e7461736b33392e"
            + "6d616368696e652e6472697665722d636f6d706c6574696f6e"
            + "0001000000040000000100020000001000000000000000000000"
            + "0000000001010003000000202121212121212121212121212121"
            + "2121212121212121212121212121212121210004000000202222"
            + "2222222222222222222222222222222222222222222222222222"
            + "2222222200050000000400000008000600000020"
            + goldenDigest

        #expect(encoded.count == 207)
        #expect(encoded.hexadecimal == goldenArtifact)
        #expect(
            Data(SHA256.hash(data: zeroed)).hexadecimal
                == goldenDigest
        )
        #expect(artifact.completionSHA256.lowercaseHex == goldenDigest)
        #expect(decoded == artifact)
        #expect(try decoded.encoded() == encoded)
        #expect(decoded.outerAttemptUUID == summary.outerAttemptUUID)
        #expect(decoded.wholeCapsuleSHA256 == summary.wholeCapsuleSHA256)
        #expect(decoded.wholeInputSHA256 == summary.wholeInputSHA256)
        #expect(decoded.completedEpochCount == 8)
        #expect(decoded.completionSHA256.rawBytes.contains { $0 != 0 })
        #expect(!(InvestigationMachineDriverCompletionArtifact.self
            is any Codable.Type))
    }

    @Test(arguments: CompletionSummaryMutation.allCases)
    fileprivate func completionArtifactRejectsInvalidSummary(
        _ mutation: CompletionSummaryMutation
    ) throws {
        #expect(throws: InvestigationMachineZeroArgumentEntryError
            .invalidCompletion) {
            _ = try InvestigationMachineDriverCompletionArtifact(
                summary: try mutation.apply(to: completionSummary())
            )
        }
    }

    @Test(arguments: CompletionEncodingMutation.allCases)
    fileprivate func completionArtifactRejectsEveryEncodingMutation(
        _ mutation: CompletionEncodingMutation
    ) throws {
        let encoded = try InvestigationMachineDriverCompletionArtifact(
            summary: completionSummary()
        ).encoded()

        #expect(throws: (any Error).self) {
            _ = try InvestigationMachineDriverCompletionArtifact.decode(
                try mutation.apply(to: encoded)
            )
        }
    }

    @Test
    func roleSelectorChoosesInnerBeforeOuterDescriptorInspection() throws {
        let system = ScriptedZeroArgumentDescriptorSystem(role: .inner)
        let role = try InvestigationMachineZeroArgumentRoleSelector(
            system: system.system
        ).select()

        #expect(role == .inner)
        #expect(system.snapshot().descriptorFlagReads == [8, 9])
        #expect(system.snapshot().statusFlagReads.isEmpty)
        #expect(system.snapshot().nodeReads.isEmpty)
    }

    @Test
    func roleSelectorPreparesAndRevalidatesExactOuterDescriptors() throws {
        let system = ScriptedZeroArgumentDescriptorSystem(role: .outer)
        let selector = InvestigationMachineZeroArgumentRoleSelector(
            system: system.system
        )
        let role = try selector.select()
        let observation = try #require(role.outerObservation)

        try selector.revalidate(observation)
        let snapshot = system.snapshot()
        #expect(snapshot.setDescriptorFlags.count == 1)
        #expect(snapshot.setDescriptorFlags.first?.0 == STDOUT_FILENO)
        #expect(snapshot.setDescriptorFlags.first?.1 == FD_CLOEXEC)
        #expect(snapshot.setStatusFlags.count == 1)
        #expect(snapshot.setStatusFlags.first?.0 == STDOUT_FILENO)
        #expect(
            snapshot.setStatusFlags.first?.1 == O_WRONLY | O_NONBLOCK
        )
        #expect(snapshot.setNoSigpipe == [1])
        #expect(snapshot.descriptorFlagReads.contains(7))
        #expect(snapshot.descriptorFlagReads.filter { $0 == 0 }.count == 1)
        #expect(snapshot.descriptorFlagReads.filter { $0 == 1 }.count == 3)
        #expect(snapshot.descriptorFlagReads.filter { $0 == 2 }.count == 2)
        #expect(snapshot.descriptorFlagReads.filter { $0 == 7 }.count == 3)
        #expect(snapshot.descriptorFlagReads.filter { $0 == 8 }.count == 3)
        #expect(snapshot.descriptorFlagReads.filter { $0 == 9 }.count == 3)
        #expect(snapshot.statusFlagReads.filter { $0 == 0 }.count == 1)
        #expect(snapshot.statusFlagReads.filter { $0 == 1 }.count == 3)
        #expect(snapshot.statusFlagReads.filter { $0 == 2 }.count == 2)
        #expect(snapshot.nodeReads.filter { $0 == 0 }.count == 2)
        #expect(snapshot.nodeReads.filter { $0 == 1 }.count == 3)
        #expect(snapshot.nodeReads.filter { $0 == 2 }.count == 3)
        #expect(snapshot.noSigpipeReads == [STDOUT_FILENO, STDOUT_FILENO])
        #expect(snapshot.standardErrorReads == 3)
        #expect(system.descriptorFlags[STDIN_FILENO] == 0)
        #expect(system.descriptorFlags[STDERR_FILENO] == 0)
        #expect(system.noSigpipeValues[STDOUT_FILENO] == 1)
    }

    @Test
    func darwinAnonymousPipeIdentityIsAdmittedAsOuterOutput() throws {
        var descriptors: [Int32] = [-1, -1]
        try #require(Darwin.pipe(&descriptors) == 0)
        defer {
            Darwin.close(descriptors[0])
            Darwin.close(descriptors[1])
        }
        let pipeNode = try InvestigationMachineZeroArgumentDescriptorSystem
            .system.descriptorNode(descriptors[1]).get()
        #expect(pipeNode.deviceID == 0)
        #expect(pipeNode.inode > 0)
        #expect(pipeNode.fileType == mode_t(S_IFIFO))

        let system = ScriptedZeroArgumentDescriptorSystem(role: .outer)
        system.nodes[STDOUT_FILENO] = pipeNode
        let selector = InvestigationMachineZeroArgumentRoleSelector(
            system: system.system
        )
        let role = try selector.select()
        let observation = try #require(role.outerObservation)
        try selector.revalidate(observation)
    }

    @Test(arguments: InvalidRoleShape.allCases)
    fileprivate func roleSelectorRejectsAmbiguousOrInvalidShape(
        _ mutation: InvalidRoleShape
    ) {
        let system = ScriptedZeroArgumentDescriptorSystem(role: .outer)
        mutation.apply(to: system)

        #expect(throws: InvestigationMachineZeroArgumentEntryError.self) {
            let selector = InvestigationMachineZeroArgumentRoleSelector(
                system: system.system
            )
            let role = try selector.select()
            if let observation = role.outerObservation {
                try selector.revalidate(observation)
            }
        }
    }

    @Test
    func innerRoleRunsOnlyTheExistingInnerComposition() async throws {
        let trace = ZeroArgumentTrace()
        let entry = InvestigationMachineZeroArgumentEntry(
            dependencies: dependencies(trace: trace, role: .inner)
        )

        try await entry.run()

        #expect(trace.snapshot() == ["validate", "role", "inner"])
        #expect(trace.outputs.isEmpty)
    }

    @Test
    func outerRoleRunsTheExactJoinAndWritesOneCanonicalArtifact() async throws {
        let trace = ZeroArgumentTrace()
        let observation = outerObservation()
        let entry = InvestigationMachineZeroArgumentEntry(
            dependencies: dependencies(
                trace: trace, role: .outer(observation)
            )
        )

        try await entry.run()

        #expect(trace.snapshot() == [
            "validate", "role", "installed", "intake", "cohort",
            "cancel", "revalidate", "write",
        ])
        let output = try #require(trace.outputs.only)
        #expect(
            try InvestigationMachineDriverCompletionArtifact.decode(output)
                == InvestigationMachineDriverCompletionArtifact(
                    summary: completionSummary()
                )
        )
    }

    @Test(arguments: ZeroArgumentFailurePoint.allCases)
    fileprivate func failureBeforeOutputCommitsNoArtifact(
        _ failure: ZeroArgumentFailurePoint
    ) async {
        let trace = ZeroArgumentTrace()
        let entry = InvestigationMachineZeroArgumentEntry(
            dependencies: dependencies(
                trace: trace, role: .outer(outerObservation()),
                failure: failure
            )
        )

        await #expect(throws: failure.error) {
            try await entry.run()
        }
        #expect(trace.outputs.isEmpty)
    }

    @Test
    func outputWriterUsesFixedDescriptorAndDeadline() throws {
        let system = ScriptedZeroArgumentOutputSystem(
            now: 41, results: [.success(1)]
        )

        try InvestigationMachineZeroArgumentOutputWriter(
            system: system.system
        ).write(Data([0xaa]))

        let snapshot = system.snapshot()
        #expect(snapshot.waits.count == 1)
        #expect(snapshot.waits.first?.0 == STDOUT_FILENO)
        #expect(snapshot.waits.first?.1 == 5_000_000_041)
        #expect(snapshot.writeDescriptors == [STDOUT_FILENO])
        #expect(snapshot.clockReadCount == 2)
    }

    @Test
    func outputWriterRetriesWaitsAndShortWritesExactly() throws {
        let system = ScriptedZeroArgumentOutputSystem(results: [
            .failure(.init(errno: EINTR)), .success(2), .success(3),
        ], waitResults: [.failure(.init(errno: EINTR)), .success(())])
        let writer = InvestigationMachineZeroArgumentOutputWriter(
            system: system.system
        )

        try writer.write(Data([1, 2, 3, 4, 5]))

        let snapshot = system.snapshot()
        #expect(snapshot.writes == [
            Data([1, 2, 3, 4, 5]),
            Data([1, 2, 3, 4, 5]),
            Data([3, 4, 5]),
        ])
        #expect(snapshot.waits.count == 4)
        #expect(snapshot.waits.allSatisfy { $0.0 == STDOUT_FILENO })
        #expect(Set(snapshot.waits.map(\.1)).count == 1)
        #expect(snapshot.writeDescriptors.allSatisfy { $0 == STDOUT_FILENO })
    }

    @Test
    func completedFinalWriteIsNotReclassifiedByALateClockSample() throws {
        let system = ScriptedZeroArgumentOutputSystem(
            clockValues: [41, 42, 5_000_000_041],
            results: [.success(1)]
        )

        try InvestigationMachineZeroArgumentOutputWriter(
            system: system.system
        ).write(Data([1]))

        let snapshot = system.snapshot()
        #expect(snapshot.writes == [Data([1])])
        #expect(snapshot.clockReadCount == 2)
    }

    @Test(arguments: OutputFailure.allCases)
    fileprivate func outputWriterRejectsDeadlineWaitAndWriteFailures(
        _ failure: OutputFailure
    ) {
        let fixture = failure.fixture

        #expect(throws: InvestigationMachineZeroArgumentEntryError
            .outputUnavailable) {
            try InvestigationMachineZeroArgumentOutputWriter(
                system: fixture.system.system
            ).write(fixture.payload)
        }
        let snapshot = fixture.system.snapshot()
        switch failure {
        case .deadlineAfterReadiness:
            #expect(snapshot.writes.isEmpty)
        case .deadlineAfterPartialWrite:
            #expect(snapshot.writes == [fixture.payload])
        default:
            break
        }
    }

    @Test
    func outputWriterDoesNotRecheckLateCancellation() async throws {
        let trace = ZeroArgumentTrace()
        let cancellation = LateCancellationProbe()
        let entry = InvestigationMachineZeroArgumentEntry(
            dependencies: dependencies(
                trace: trace, role: .outer(outerObservation()),
                cancellation: cancellation
            )
        )

        try await entry.run()

        #expect(cancellation.snapshot().checks == 1)
        #expect(cancellation.snapshot().committed)
        #expect(trace.outputs.count == 1)
    }

    @Test
    func compositionCancellationCannotMaskContainmentUncertainty() async {
        let trace = ZeroArgumentTrace()
        let entry = InvestigationMachineZeroArgumentEntry(
            dependencies: dependencies(
                trace: trace, role: .outer(outerObservation()),
                failure: .compositionCancellation
            )
        )

        await #expect(
            throws: InvestigationMachineZeroArgumentEntryError
                .containmentUncertain
        ) {
            try await entry.run()
        }
        #expect(trace.outputs.isEmpty)
    }
}

private enum CompletionSummaryMutation: CaseIterable {
    case zeroUUID, zeroCapsule, zeroInput, wrongCount

    func apply(
        to value: InvestigationMachineEightEpochCompletionSummary
    ) throws -> InvestigationMachineEightEpochCompletionSummary {
        switch self {
        case .zeroUUID:
            .init(
                outerAttemptUUID: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0)),
                wholeCapsuleSHA256: value.wholeCapsuleSHA256,
                wholeInputSHA256: value.wholeInputSHA256,
                completedEpochCount: value.completedEpochCount
            )
        case .zeroCapsule:
            .init(
                outerAttemptUUID: value.outerAttemptUUID,
                wholeCapsuleSHA256: try completionDigest(0),
                wholeInputSHA256: value.wholeInputSHA256,
                completedEpochCount: value.completedEpochCount
            )
        case .zeroInput:
            .init(
                outerAttemptUUID: value.outerAttemptUUID,
                wholeCapsuleSHA256: value.wholeCapsuleSHA256,
                wholeInputSHA256: try completionDigest(0),
                completedEpochCount: value.completedEpochCount
            )
        case .wrongCount:
            .init(
                outerAttemptUUID: value.outerAttemptUUID,
                wholeCapsuleSHA256: value.wholeCapsuleSHA256,
                wholeInputSHA256: value.wholeInputSHA256,
                completedEpochCount: 7
            )
        }
    }
}

private enum CompletionEncodingMutation: CaseIterable {
    case magic, domain, version, domainTag, businessTag, fieldOrder
    case uuidLength, capsuleLength, inputLength, countLength, digestLength
    case payload, digest, zeroDigest, wrongCount, missingDigest
    case truncated, unknownField, trailing, oversized

    func apply(to value: Data) throws -> Data {
        switch self {
        case .magic:
            var result = value; result[result.startIndex] ^= 0xff; return result
        case .domain:
            var result = value; result[10] ^= 0x01; return result
        case .version:
            var result = value; result[60] ^= 0x01; return result
        case .domainTag:
            var result = value; result[5] = 1; return result
        case .businessTag:
            var result = value; result[62] = 3; return result
        case .fieldOrder:
            var result = value
            let capsule = result.subdata(in: 83..<121)
            let input = result.subdata(in: 121..<159)
            result.replaceSubrange(83..<121, with: input)
            result.replaceSubrange(121..<159, with: capsule)
            return result
        case .uuidLength:
            var result = value; result[66] = 15; return result
        case .capsuleLength:
            var result = value; result[88] = 31; return result
        case .inputLength:
            var result = value; result[126] = 33; return result
        case .countLength:
            var result = value; result[164] = 8; return result
        case .digestLength:
            var result = value; result[174] = 31; return result
        case .payload:
            var result = value; result[89] ^= 0x01; return result
        case .digest:
            var result = value; result[result.index(before: result.endIndex)] ^= 1
            return result
        case .zeroDigest:
            var result = value
            result.replaceSubrange(175..<207, with: Data(repeating: 0, count: 32))
            return result
        case .wrongCount:
            let summary = InvestigationMachineEightEpochCompletionSummary(
                outerAttemptUUID: try completionSummary().outerAttemptUUID,
                wholeCapsuleSHA256: try completionDigest(0x21),
                wholeInputSHA256: try completionDigest(0x22),
                completedEpochCount: 7
            )
            let zeroed = independentCompletionTranscript(
                summary: summary, digest: Data(repeating: 0, count: 32)
            )
            return independentCompletionTranscript(
                summary: summary, digest: Data(SHA256.hash(data: zeroed))
            )
        case .missingDigest:
            return value.subdata(in: 0..<169)
        case .truncated:
            return Data(value.dropLast())
        case .unknownField:
            return value + Data([0, 7, 0, 0, 0, 1, 1])
        case .trailing:
            return value + Data([0])
        case .oversized:
            return value + Data(repeating: 1, count: 513)
        }
    }
}

private enum InvalidRoleShape: CaseIterable {
    case onlyEight, onlyNine, fdEightLookupFailure, fdNineLookupFailure
    case fdSeven, inputMissing, outputMissing, stderrMissing
    case stderrCloexec, writableInput, readonlyOutput
    case readonlyError, invalidInputNode, invalidOutputNode, invalidErrorNode
    case outputNotPipe, outputAlias, stderrAlias, noSigpipeReadFailure
    case noSigpipeSetFailure, noSigpipeNotSet, descriptorSetFailure
    case statusSetFailure, descriptorFlagsNotSet, statusFlagsNotSet
    case stderrObservationFailure, stderrNodeMismatch, ttyNotCharacter
    case ttyMissingForeground, ttyInvalidForeground, nonTTYForeground
    case outputDrift, stderrDrift, fdEightDrift, fdNineDrift

    func apply(to system: ScriptedZeroArgumentDescriptorSystem) {
        switch self {
        case .onlyEight: system.openDescriptors.insert(8)
        case .onlyNine: system.openDescriptors.insert(9)
        case .fdEightLookupFailure: system.flagErrors[8] = EIO
        case .fdNineLookupFailure: system.flagErrors[9] = EIO
        case .fdSeven: system.openDescriptors.insert(7)
        case .inputMissing: system.openDescriptors.remove(0)
        case .outputMissing: system.openDescriptors.remove(1)
        case .stderrMissing: system.openDescriptors.remove(2)
        case .stderrCloexec: system.descriptorFlags[2] = FD_CLOEXEC
        case .writableInput: system.statusFlags[0] = O_RDWR
        case .readonlyOutput: system.statusFlags[1] = O_RDONLY
        case .readonlyError: system.statusFlags[2] = O_RDONLY
        case .invalidInputNode:
            system.nodes[0] = .init(deviceID: 1, inode: 0, fileType: 0)
        case .invalidOutputNode:
            system.nodes[1] = .init(deviceID: 2, inode: 0, fileType: 0)
        case .invalidErrorNode:
            system.nodes[2] = .init(deviceID: 3, inode: 0, fileType: 0)
        case .outputNotPipe:
            system.nodes[1] = .init(
                deviceID: 2, inode: 20, fileType: mode_t(S_IFREG)
            )
        case .outputAlias: system.nodes[1] = system.nodes[0]
        case .stderrAlias: system.nodes[2] = system.nodes[1]
        case .noSigpipeReadFailure: system.noSigpipeError = EIO
        case .noSigpipeSetFailure: system.setNoSigpipeError = EIO
        case .noSigpipeNotSet: system.ignoreNoSigpipeSet = true
        case .descriptorSetFailure: system.setDescriptorFlagsError = EIO
        case .statusSetFailure: system.setStatusFlagsError = EIO
        case .descriptorFlagsNotSet: system.ignoreDescriptorFlagsSet = true
        case .statusFlagsNotSet: system.ignoreStatusFlagsSet = true
        case .stderrObservationFailure: system.standardErrorError = EIO
        case .stderrNodeMismatch: system.standardErrorInode = 31
        case .ttyNotCharacter: system.standardErrorMode = mode_t(S_IFREG | 0o600)
        case .ttyMissingForeground: system.standardErrorForeground = nil
        case .ttyInvalidForeground: system.standardErrorForeground = 1
        case .nonTTYForeground:
            system.standardErrorIsTTY = false
            system.standardErrorForeground = 42
        case .outputDrift: system.finalOutputInode = 99
        case .stderrDrift: system.finalErrorInode = 99
        case .fdEightDrift: system.finalOpenDescriptors.insert(8)
        case .fdNineDrift: system.finalOpenDescriptors.insert(9)
        }
    }
}

private enum OutputFailure: CaseIterable {
    case empty, oversized, clockOverflow, waitError, zeroWrite
    case writeError, overreportedWrite, deadlineAfterReadiness
    case deadlineAfterPartialWrite

    var fixture: (
        system: ScriptedZeroArgumentOutputSystem, payload: Data
    ) {
        switch self {
        case .empty:
            (ScriptedZeroArgumentOutputSystem(results: []), Data())
        case .oversized:
            (ScriptedZeroArgumentOutputSystem(results: []),
             Data(repeating: 1, count: 513))
        case .clockOverflow:
            (ScriptedZeroArgumentOutputSystem(
                now: .max - 1, results: [.success(1)]
            ), Data([1]))
        case .waitError:
            (ScriptedZeroArgumentOutputSystem(
                results: [.success(1)],
                waitResults: [.failure(.init(errno: ETIMEDOUT))]
            ), Data([1]))
        case .zeroWrite:
            (ScriptedZeroArgumentOutputSystem(results: [.success(0)]), Data([1]))
        case .writeError:
            (ScriptedZeroArgumentOutputSystem(
                results: [.failure(.init(errno: EIO))]
            ), Data([1]))
        case .overreportedWrite:
            (ScriptedZeroArgumentOutputSystem(results: [.success(2)]), Data([1]))
        case .deadlineAfterReadiness:
            (ScriptedZeroArgumentOutputSystem(
                clockValues: [41, 5_000_000_041],
                results: [.success(1)]
            ), Data([1]))
        case .deadlineAfterPartialWrite:
            (ScriptedZeroArgumentOutputSystem(
                clockValues: [41, 42, 5_000_000_041],
                results: [.success(1)]
            ), Data([1, 2]))
        }
    }
}

private enum ZeroArgumentFailurePoint: CaseIterable {
    case invocation, role, installed, intake, cohort, artifact
    case cancellation, revalidate, write
    case compositionCancellation

    var error: InvestigationMachineZeroArgumentEntryError {
        switch self {
        case .invocation: .invalidInvocation
        case .role: .invalidRole
        case .installed: .installedObservationUnavailable
        case .intake: .invalidInput
        case .cohort: .protocolFailure
        case .compositionCancellation: .containmentUncertain
        case .artifact: .invalidCompletion
        case .cancellation: .cancelled
        case .revalidate: .invalidOuterDescriptor
        case .write: .outputUnavailable
        }
    }
}

private final class ZeroArgumentTrace: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [String] = []
    private var outputValues: [Data] = []

    func append(_ event: String) { lock.withLock { events.append(event) } }
    func output(_ data: Data) { lock.withLock { outputValues.append(data) } }
    func snapshot() -> [String] { lock.withLock { events } }
    var outputs: [Data] { lock.withLock { outputValues } }
}

private final class LateCancellationProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var checkCount = 0
    private var didCommit = false

    func check() { lock.withLock { checkCount += 1 } }
    func commit() { lock.withLock { didCommit = true } }
    func snapshot() -> (checks: Int, committed: Bool) {
        lock.withLock { (checkCount, didCommit) }
    }
}

private actor EmptyEightEpochPlan: InvestigationMachineEightEpochPlan {
    func takeNext() throws -> InvestigationMachineFixedEpochSelection {
        throw InvestigationMachineFixedCapsuleIntakeError.exhausted
    }
}

private func dependencies(
    trace: ZeroArgumentTrace,
    role: InvestigationMachineZeroArgumentRole,
    failure: ZeroArgumentFailurePoint? = nil,
    cancellation: LateCancellationProbe? = nil
) -> InvestigationMachineZeroArgumentEntryDependencies {
    let plan = EmptyEightEpochPlan()
    return .init(
        validateInvocation: {
            trace.append("validate")
            if failure == .invocation { throw failure!.error }
        },
        selectRole: {
            trace.append("role")
            if failure == .role { throw failure!.error }
            return role
        },
        runInner: { trace.append("inner") },
        observeInstalledDriver: {
            trace.append("installed")
            if failure == .installed { throw failure!.error }
        },
        readPlan: {
            trace.append("intake")
            if failure == .intake { throw failure!.error }
            return plan
        },
        runCohort: { _ in
            trace.append("cohort")
            if failure == .cohort { throw failure!.error }
            if failure == .compositionCancellation {
                throw InvestigationMachineDarwinOuterInnerCompositionError
                    .cancelled
            }
            if failure == .artifact {
                let value = try completionSummary()
                return .init(
                    outerAttemptUUID: value.outerAttemptUUID,
                    wholeCapsuleSHA256: value.wholeCapsuleSHA256,
                    wholeInputSHA256: value.wholeInputSHA256,
                    completedEpochCount: 7
                )
            }
            return try completionSummary()
        },
        checkCancellation: {
            trace.append("cancel")
            cancellation?.check()
            if failure == .cancellation { throw failure!.error }
        },
        revalidateOuter: { _ in
            trace.append("revalidate")
            if failure == .revalidate { throw failure!.error }
        },
        writeArtifact: { data in
            trace.append("write")
            if failure == .write { throw failure!.error }
            trace.output(data)
            cancellation?.commit()
        }
    )
}

private let completionDomain =
    "stornaut.task39.machine.driver-completion"

private func independentCompletionTranscript(
    summary: InvestigationMachineEightEpochCompletionSummary,
    digest: Data
) -> Data {
    var result = Data([0x53, 0x54, 0x4e, 0x43])
    appendCompletionField(0, Data(completionDomain.utf8), to: &result)
    appendCompletionField(1, completionUInt32Data(1), to: &result)
    appendCompletionField(2, completionUUIDData(summary.outerAttemptUUID), to: &result)
    appendCompletionField(3, summary.wholeCapsuleSHA256.rawBytes, to: &result)
    appendCompletionField(4, summary.wholeInputSHA256.rawBytes, to: &result)
    appendCompletionField(5, completionUInt32Data(summary.completedEpochCount), to: &result)
    appendCompletionField(6, digest, to: &result)
    return result
}

private func appendCompletionField(
    _ tag: UInt16, _ payload: Data, to result: inout Data
) {
    result.append(contentsOf: [
        UInt8(truncatingIfNeeded: tag >> 8),
        UInt8(truncatingIfNeeded: tag),
    ])
    result.append(completionUInt32Data(UInt32(payload.count)))
    result.append(payload)
}

private func completionUUIDData(_ value: UUID) -> Data {
    var bytes = value.uuid
    return withUnsafeBytes(of: &bytes) { Data($0) }
}

private func completionUInt32Data(_ value: UInt32) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 24),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}

private func completionSummary() throws
    -> InvestigationMachineEightEpochCompletionSummary
{
    .init(
        outerAttemptUUID: UUID(
            uuidString: "00000000-0000-0000-0000-000000000101"
        )!,
        wholeCapsuleSHA256: try completionDigest(0x21),
        wholeInputSHA256: try completionDigest(0x22),
        completedEpochCount: 8
    )
}

private func completionDigest(
    _ byte: UInt8
) throws -> InvestigationHandoffSHA256 {
    try .init(rawBytes: Data(repeating: byte, count: 32))
}

private func outerObservation()
    -> InvestigationMachineZeroArgumentOuterDescriptorObservation
{
    .init(
        standardOutputNode: .init(
            deviceID: 0, inode: 20, fileType: mode_t(S_IFIFO)
        ),
        standardOutputDescriptorFlags: FD_CLOEXEC,
        standardOutputStatusFlags: O_WRONLY | O_NONBLOCK,
        standardError: .init(
            deviceID: 3, inode: 30, mode: mode_t(S_IFCHR | 0o600),
            statusFlags: O_WRONLY, isTTY: true,
            foregroundProcessGroup: 42
        )
    )
}

private final class ScriptedZeroArgumentDescriptorSystem: @unchecked Sendable {
    struct Snapshot {
        let descriptorFlagReads: [Int32]
        let statusFlagReads: [Int32]
        let nodeReads: [Int32]
        let setDescriptorFlags: [(Int32, Int32)]
        let setStatusFlags: [(Int32, Int32)]
        let noSigpipeReads: [Int32]
        let setNoSigpipe: [Int32]
        let standardErrorReads: Int
    }

    private let lock = NSLock()
    var openDescriptors: Set<Int32>
    var finalOpenDescriptors: Set<Int32> = []
    var flagErrors: [Int32: Int32] = [:]
    var descriptorFlags: [Int32: Int32] = [0: 0, 1: 0, 2: 0]
    var statusFlags: [Int32: Int32] = [
        0: O_RDONLY, 1: O_WRONLY, 2: O_WRONLY,
    ]
    var nodes: [Int32: InvestigationMachineDarwinDescriptorNodeObservation] = [
        0: .init(deviceID: 1, inode: 10, fileType: mode_t(S_IFREG)),
        1: .init(deviceID: 0, inode: 20, fileType: mode_t(S_IFIFO)),
        2: .init(deviceID: 3, inode: 30, fileType: mode_t(S_IFCHR)),
    ]
    var finalOutputInode: UInt64?
    var finalErrorInode: UInt64?
    var noSigpipeValues: [Int32: Int32] = [STDOUT_FILENO: 0]
    var noSigpipeError: Int32?
    var setNoSigpipeError: Int32?
    var setDescriptorFlagsError: Int32?
    var setStatusFlagsError: Int32?
    var standardErrorError: Int32?
    var ignoreNoSigpipeSet = false
    var ignoreDescriptorFlagsSet = false
    var ignoreStatusFlagsSet = false
    var standardErrorInode: UInt64 = 30
    var standardErrorMode = mode_t(S_IFCHR | 0o600)
    var standardErrorIsTTY = true
    var standardErrorForeground: Int32? = 42
    private var flagReads: [Int32] = []
    private var statusReads: [Int32] = []
    private var nodeReadValues: [Int32] = []
    private var descriptorSets: [(Int32, Int32)] = []
    private var statusSets: [(Int32, Int32)] = []
    private var noSigpipeReadValues: [Int32] = []
    private var noSigpipeSets: [Int32] = []
    private var outputNodeReads = 0
    private var errorNodeReads = 0
    private var errorObservationReads = 0

    init(role: InvestigationMachineZeroArgumentRoleKind) {
        openDescriptors = role == .inner
            ? [0, 1, 2, 8, 9] : [0, 1, 2]
    }

    var system: InvestigationMachineZeroArgumentDescriptorSystem {
        .init(
            descriptorFlags: { [self] descriptor in
                lock.withLock {
                    flagReads.append(descriptor)
                    if let error = flagErrors[descriptor] {
                        return .failure(.init(errno: error))
                    }
                    if flagReads.count > 2,
                       finalOpenDescriptors.contains(descriptor)
                    {
                        return .success(descriptorFlags[descriptor] ?? 0)
                    }
                    guard openDescriptors.contains(descriptor) else {
                        return .failure(.init(errno: EBADF))
                    }
                    return .success(descriptorFlags[descriptor] ?? 0)
                }
            },
            descriptorStatusFlags: { [self] descriptor in
                lock.withLock {
                    statusReads.append(descriptor)
                    guard let value = statusFlags[descriptor] else {
                        return .failure(.init(errno: EBADF))
                    }
                    return .success(value)
                }
            },
            setDescriptorFlags: { [self] descriptor, flags in
                lock.withLock {
                    descriptorSets.append((descriptor, flags))
                    if let error = setDescriptorFlagsError {
                        return .failure(.init(errno: error))
                    }
                    if !ignoreDescriptorFlagsSet {
                        descriptorFlags[descriptor] = flags
                    }
                    return .success(())
                }
            },
            setStatusFlags: { [self] descriptor, flags in
                lock.withLock {
                    statusSets.append((descriptor, flags))
                    if let error = setStatusFlagsError {
                        return .failure(.init(errno: error))
                    }
                    if !ignoreStatusFlagsSet {
                        statusFlags[descriptor] = flags
                    }
                    return .success(())
                }
            },
            noSigpipe: { [self] descriptor in
                lock.withLock {
                    noSigpipeReadValues.append(descriptor)
                    if let error = noSigpipeError {
                        return .failure(.init(errno: error))
                    }
                    return .success(noSigpipeValues[descriptor] ?? 0)
                }
            },
            setNoSigpipe: { [self] descriptor in
                lock.withLock {
                    noSigpipeSets.append(descriptor)
                    if let error = setNoSigpipeError {
                        return .failure(.init(errno: error))
                    }
                    if !ignoreNoSigpipeSet { noSigpipeValues[descriptor] = 1 }
                    return .success(())
                }
            },
            descriptorNode: { [self] descriptor in
                lock.withLock {
                    nodeReadValues.append(descriptor)
                    guard var value = nodes[descriptor] else {
                        return .failure(.init(errno: EBADF))
                    }
                    if descriptor == 1 {
                        outputNodeReads += 1
                        if outputNodeReads > 1, let finalOutputInode {
                            value = .init(
                                deviceID: value.deviceID, inode: finalOutputInode,
                                fileType: value.fileType
                            )
                        }
                    }
                    if descriptor == 2 {
                        errorNodeReads += 1
                        if errorNodeReads > 2, let finalErrorInode {
                            value = .init(
                                deviceID: value.deviceID,
                                inode: finalErrorInode,
                                fileType: value.fileType
                            )
                        }
                    }
                    return .success(value)
                }
            },
            standardErrorObservation: { [self] in
                try lock.withLock {
                    errorObservationReads += 1
                    if let error = standardErrorError {
                        throw InvestigationMachineZeroArgumentSystemError(
                            errno: error
                        )
                    }
                    return .init(
                        deviceID: nodes[2]!.deviceID,
                        inode: standardErrorInode,
                        mode: standardErrorMode,
                        statusFlags: statusFlags[2]!,
                        isTTY: standardErrorIsTTY,
                        foregroundProcessGroup: standardErrorForeground
                    )
                }
            }
        )
    }

    func snapshot() -> Snapshot {
        lock.withLock {
            .init(
                descriptorFlagReads: flagReads, statusFlagReads: statusReads,
                nodeReads: nodeReadValues, setDescriptorFlags: descriptorSets,
                setStatusFlags: statusSets, noSigpipeReads: noSigpipeReadValues,
                setNoSigpipe: noSigpipeSets,
                standardErrorReads: errorObservationReads
            )
        }
    }
}

private final class ScriptedZeroArgumentOutputSystem: @unchecked Sendable {
    struct Snapshot {
        let waits: [(Int32, UInt64)]
        let writeDescriptors: [Int32]
        let writes: [Data]
        let clockReadCount: Int
    }
    private let lock = NSLock()
    private var clockValues: [UInt64]
    private var clockReads = 0
    private var results:
        [Result<Int, InvestigationMachineZeroArgumentSystemError>]
    private var waitResults:
        [Result<Void, InvestigationMachineZeroArgumentSystemError>]
    private var waitValues: [(Int32, UInt64)] = []
    private var descriptorValues: [Int32] = []
    private var values: [Data] = []

    init(
        now: UInt64 = 1,
        clockValues: [UInt64]? = nil,
        results: [Result<Int, InvestigationMachineZeroArgumentSystemError>],
        waitResults: [
            Result<Void, InvestigationMachineZeroArgumentSystemError>
        ] = []
    ) {
        self.clockValues = clockValues ?? [now]
        self.results = results
        self.waitResults = waitResults
    }

    var system: InvestigationMachineZeroArgumentOutputSystem {
        .init(
            continuousNanoseconds: { [self] in
                lock.withLock {
                    clockReads += 1
                    if clockValues.count > 1 { return clockValues.removeFirst() }
                    return clockValues[0]
                }
            },
            waitWritable: { [self] descriptor, deadline in
                lock.withLock {
                    waitValues.append((descriptor, deadline))
                    return waitResults.isEmpty
                        ? .success(()) : waitResults.removeFirst()
                }
            },
            write: { [self] descriptor, data in
                lock.withLock {
                    descriptorValues.append(descriptor)
                    values.append(data)
                    return results.removeFirst()
                }
            }
        )
    }

    func snapshot() -> Snapshot {
        lock.withLock {
            .init(
                waits: waitValues,
                writeDescriptors: descriptorValues,
                writes: values,
                clockReadCount: clockReads
            )
        }
    }
}

private extension Array {
    var only: Element? { count == 1 ? self[0] : nil }
}

private extension Data {
    var hexadecimal: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
