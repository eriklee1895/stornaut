import Darwin
import CryptoKit
import Foundation
import Testing

@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachineDriverSupport

@Suite("Investigation machine zero-argument entry", .serialized)
struct InvestigationMachineZeroArgumentEntryTests {
    @Test
    func completionArtifactMatchesFixed180ByteV3Layout() throws {
        let summary = try completionSummary()
        let claim = try claimFixture()
        let claimSHA = InvestigationHandoffSHA256.hashing(try claim.encoded())
        let bundleSHA = try completionDigest(0x55)
        let artifact = try InvestigationMachineDriverCompletionArtifact(
            summary: summary,
            lineageClaimSHA256: claimSHA,
            driverEvidenceBundleSHA256: bundleSHA
        )
        let encoded = try artifact.encoded()
        let decoded = try InvestigationMachineDriverCompletionArtifact.decode(
            encoded
        )
        let business = Data([
            completionUUIDData(summary.outerAttemptUUID),
            summary.wholeCapsuleSHA256.rawBytes,
            summary.wholeInputSHA256.rawBytes,
            completionUInt32Data(summary.completedEpochCount),
            claimSHA.rawBytes,
            bundleSHA.rawBytes,
        ].joined())
        let expectedSelfSHA = InvestigationHandoffSHA256.hashing(
            business + Data(repeating: 0, count: 32)
        )

        #expect(encoded.count == 180)
        #expect(encoded.prefix(148) == business)
        #expect(encoded.suffix(32) == expectedSelfSHA.rawBytes)
        #expect(artifact.selfSHA256 == expectedSelfSHA)
        #expect(decoded == artifact)
        #expect(try decoded.encoded() == encoded)
        #expect(decoded.outerAttemptUUID == summary.outerAttemptUUID)
        #expect(decoded.wholeCapsuleSHA256 == summary.wholeCapsuleSHA256)
        #expect(decoded.wholeInputSHA256 == summary.wholeInputSHA256)
        #expect(decoded.completedEpochCount == 8)
        #expect(decoded.lineageClaimSHA256 == claimSHA)
        #expect(decoded.driverEvidenceBundleSHA256 == bundleSHA)
        #expect(decoded.selfSHA256.rawBytes.contains { $0 != 0 })
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
                summary: try mutation.apply(to: completionSummary()),
                lineageClaimSHA256: try completionDigest(0x44),
                driverEvidenceBundleSHA256: try completionDigest(0x55)
            )
        }
    }

    @Test(arguments: CompletionEncodingMutation.allCases)
    fileprivate func completionArtifactRejectsEveryEncodingMutation(
        _ mutation: CompletionEncodingMutation
    ) throws {
        let encoded = try InvestigationMachineDriverCompletionArtifact(
            summary: completionSummary(),
            lineageClaimSHA256: try completionDigest(0x44),
            driverEvidenceBundleSHA256: try completionDigest(0x55)
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
    func outerRoleWritesFramedClaimBeforeBusinessAndThenCompletionV3() async throws {
        let trace = ZeroArgumentTrace()
        let observation = outerObservation()
        let entry = InvestigationMachineZeroArgumentEntry(
            dependencies: dependencies(
                trace: trace, role: .outer(observation)
            )
        )

        try await entry.run()

        #expect(trace.snapshot() == [
            "validate", "role", "installed", "intake", "prebind",
            "claim", "claim-write", "stop", "begin-evidence", "cohort",
            "cancel", "revalidate", "evidence-write", "write",
        ])
        #expect(trace.outputs.count == 2)
        let framedClaim = try #require(trace.outputs.first)
        let stdoutCompletion = try #require(trace.outputs.last)
        let count = try decodeBigEndianUInt32(framedClaim.prefix(4))
        #expect(count == 1_006)
        let claimBytes = framedClaim.dropFirst(4)
        #expect(claimBytes.count == 1_006)
        let claim = try ResolvedRootDriverClaimV1.decode(Data(claimBytes))
        let evidence = try #require(trace.stderr.only)
        let lines = String(decoding: evidence, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count >= 2)
        #expect(lines[0].hasPrefix("STORNAUT_TASK39_IIC_ROOT_DRIVER_CLAIM_V1 "))
        #expect(lines[1].hasPrefix("STORNAUT_TASK39_IIC_EPOCH_BUNDLE_V1 "))
        let completion = try InvestigationMachineDriverCompletionArtifact.decode(stdoutCompletion)
        #expect(completion.lineageClaimSHA256 == .hashing(Data(claimBytes)))
        #expect(stdoutCompletion.count == 180)
        #expect(framedClaim.count + stdoutCompletion.count == 1_190)
        let expectedOuterAttemptUUID = try completionSummary().outerAttemptUUID
        #expect(claim.outerAttemptUUID == expectedOuterAttemptUUID)
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
        switch failure {
        case .invocation, .role, .installed, .intake:
            #expect(trace.outputs.isEmpty)
            #expect(trace.stderr.isEmpty)
        case .cohort, .artifact, .cancellation, .revalidate, .write,
             .compositionCancellation:
            #expect(trace.outputs.count == 1)
            let framedClaim = try! #require(trace.outputs.only)
            #expect(framedClaim.count == 1_010)
            let count = try! decodeBigEndianUInt32(framedClaim.prefix(4))
            #expect(count == 1_006)
            switch failure {
            case .artifact, .write:
                #expect(trace.stderr.count == 1)
                let evidence = try! #require(trace.stderr.only)
                let lines = String(decoding: evidence, as: UTF8.self)
                    .split(separator: "\n", omittingEmptySubsequences: false)
                #expect(lines.count >= 2)
                #expect(lines[0].hasPrefix(
                    "STORNAUT_TASK39_IIC_ROOT_DRIVER_CLAIM_V1 "
                ))
                #expect(lines[1].hasPrefix(
                    "STORNAUT_TASK39_IIC_EPOCH_BUNDLE_V1 "
                ))
            default:
                #expect(trace.stderr.isEmpty)
            }
        }
    }

    @Test
    func outputWriterUsesFixedDescriptorAndDeadline() throws {
        let system = ScriptedZeroArgumentOutputSystem(
            now: 41, results: [.success(1)]
        )

        try InvestigationMachineZeroArgumentOutputWriter(
            system: system.system
        ).write(
            Data([0xaa]),
            descriptor: STDOUT_FILENO,
            maximumByteCount:
                InvestigationMachineDriverCompletionArtifact.maximumByteCount,
            deadlineNanoseconds: 5_000_000_041
        )

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

        try writer.write(
            Data([1, 2, 3, 4, 5]),
            descriptor: STDOUT_FILENO,
            maximumByteCount:
                InvestigationMachineDriverCompletionArtifact.maximumByteCount,
            deadlineNanoseconds: 5_000_000_001
        )

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
    func outputWriterRetriesEagainAndEwouldblockWithinSameDeadline() throws {
        let system = ScriptedZeroArgumentOutputSystem(
            results: [
                .failure(.init(errno: EAGAIN)),
                .failure(.init(errno: EWOULDBLOCK)),
                .success(2),
            ]
        )
        let writer = InvestigationMachineZeroArgumentOutputWriter(
            system: system.system
        )

        try writer.write(
            Data([1, 2]),
            descriptor: STDOUT_FILENO,
            maximumByteCount:
                InvestigationMachineDriverCompletionArtifact.maximumByteCount,
            deadlineNanoseconds: 5_000_000_001
        )

        let snapshot = system.snapshot()
        #expect(snapshot.waits.count == 3)
        #expect(snapshot.waits.allSatisfy { $0.0 == STDOUT_FILENO })
        #expect(Set(snapshot.waits.map(\.1)) == [5_000_000_001])
        #expect(snapshot.writes == [
            Data([1, 2]),
            Data([1, 2]),
            Data([1, 2]),
        ])
    }

    @Test
    func completedFinalWriteIsNotReclassifiedByALateClockSample() throws {
        let system = ScriptedZeroArgumentOutputSystem(
            clockValues: [41, 42, 5_000_000_041],
            results: [.success(1)]
        )

        try InvestigationMachineZeroArgumentOutputWriter(
            system: system.system
        ).write(
            Data([1]),
            descriptor: STDOUT_FILENO,
            maximumByteCount:
                InvestigationMachineDriverCompletionArtifact.maximumByteCount,
            deadlineNanoseconds: 5_000_000_041
        )

        let snapshot = system.snapshot()
        #expect(snapshot.writes == [Data([1])])
        #expect(snapshot.clockReadCount == 2)
    }

    @Test
    func outputWriterTemporarilyMakesStandardErrorNonblockingAndRestoresIt() throws {
        let system = ScriptedZeroArgumentOutputSystem(
            results: [.success(1)]
        )
        let writer = InvestigationMachineZeroArgumentOutputWriter(
            system: system.system
        )

        try writer.write(
            Data([0xaa]),
            descriptor: STDERR_FILENO,
            maximumByteCount: 16,
            deadlineNanoseconds: 5_000_000_001
        )

        let snapshot = system.snapshot()
        #expect(snapshot.statusReads == [STDERR_FILENO, STDERR_FILENO, STDERR_FILENO])
        #expect(snapshot.statusSets.count == 2)
        #expect(snapshot.statusSets[0].0 == STDERR_FILENO)
        #expect(snapshot.statusSets[0].1 == O_WRONLY | O_NONBLOCK)
        #expect(snapshot.statusSets[1].0 == STDERR_FILENO)
        #expect(snapshot.statusSets[1].1 == O_WRONLY)
    }

    @Test
    func outputWriterBestEffortRestoresFlagsWhenReadbackAfterSetFails() {
        let system = ScriptedZeroArgumentOutputSystem(
            results: [.success(1)]
        )
        system.failStatusReadAfterFirstSet = true
        let writer = InvestigationMachineZeroArgumentOutputWriter(
            system: system.system
        )

        #expect(throws: InvestigationMachineZeroArgumentEntryError
            .containmentUncertain) {
            try writer.write(
                Data([0xaa]),
                descriptor: STDERR_FILENO,
                maximumByteCount: 16,
                deadlineNanoseconds: 5_000_000_001
            )
        }
        let snapshot = system.snapshot()
        #expect(snapshot.statusSets.count == 2)
        #expect(snapshot.statusSets[0].1 == O_WRONLY | O_NONBLOCK)
        #expect(snapshot.statusSets[1].1 == O_WRONLY)
    }

    @Test
    func outputWriterRestoreFailureAfterCommittedStandardErrorIsContainmentUncertain() {
        let system = ScriptedZeroArgumentOutputSystem(
            results: [.success(1)]
        )
        system.failRestoreSet = true
        let writer = InvestigationMachineZeroArgumentOutputWriter(
            system: system.system
        )

        #expect(throws: InvestigationMachineZeroArgumentEntryError
            .containmentUncertain) {
            try writer.write(
                Data([0xaa]),
                descriptor: STDERR_FILENO,
                maximumByteCount: 16,
                deadlineNanoseconds: 5_000_000_001
            )
        }
        let snapshot = system.snapshot()
        #expect(snapshot.writes == [Data([0xaa])])
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
            ).write(
                fixture.payload,
                descriptor: STDOUT_FILENO,
                maximumByteCount:
                    InvestigationMachineDriverCompletionArtifact.maximumByteCount,
                deadlineNanoseconds: fixture.deadline
            )
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
        #expect(trace.outputs.count == 2)
    }

    @Test
    func outerRoleReusesOneTerminalDeadlineForEvidenceAndCompletion() async throws {
        let trace = ZeroArgumentTrace()
        let terminalOutput = TerminalOutputProbe()
        let entry = InvestigationMachineZeroArgumentEntry(
            dependencies: dependencies(
                trace: trace,
                role: .outer(outerObservation()),
                terminalOutput: terminalOutput
            )
        )

        try await entry.run()

        #expect(terminalOutput.snapshot().deadlines == [777, 777])
        #expect(terminalOutput.snapshot().writes == [
            .evidence,
            .completion,
        ])
    }

    @Test
    func sharedTerminalDeadlinePreventsFreshCompletionBudget() async {
        let trace = ZeroArgumentTrace()
        let terminalOutput = TerminalOutputProbe(
            writeArtifactError: .outputUnavailable
        )
        let entry = InvestigationMachineZeroArgumentEntry(
            dependencies: dependencies(
                trace: trace,
                role: .outer(outerObservation()),
                terminalOutput: terminalOutput
            )
        )

        await #expect(
            throws: InvestigationMachineZeroArgumentEntryError.outputUnavailable
        ) {
            try await entry.run()
        }
        #expect(terminalOutput.snapshot().deadlines == [777, 777])
        #expect(terminalOutput.snapshot().writes == [
            .evidence,
            .completion,
        ])
        #expect(trace.stderr.count == 1)
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
        #expect(trace.outputs.count == 1)
        let framedClaim = try! #require(trace.outputs.only)
        #expect(framedClaim.count == 1_010)
        let count = try! decodeBigEndianUInt32(framedClaim.prefix(4))
        #expect(count == 1_006)
        #expect(trace.stderr.isEmpty)
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
    case payload, claimSHA, bundleSHA, selfSHA, zeroSelfSHA
    case wrongCount, truncated, trailing, oversized

    func apply(to value: Data) throws -> Data {
        switch self {
        case .payload:
            var result = value; result[8] ^= 0x01; return result
        case .claimSHA:
            var result = value; result[100] ^= 0x01; return result
        case .bundleSHA:
            var result = value; result[132] ^= 0x01; return result
        case .selfSHA:
            var result = value; result[179] ^= 0x01; return result
        case .zeroSelfSHA:
            var result = value
            result.replaceSubrange(148..<180, with: Data(repeating: 0, count: 32))
            return result
        case .wrongCount:
            var result = value
            result.replaceSubrange(80..<84, with: completionUInt32Data(7))
            return result
        case .truncated:
            return Data(value.dropLast())
        case .trailing:
            return value + Data([0])
        case .oversized:
            return value + Data(repeating: 1, count: 181)
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
        system: ScriptedZeroArgumentOutputSystem, payload: Data, deadline: UInt64
    ) {
        switch self {
        case .empty:
            (ScriptedZeroArgumentOutputSystem(results: []), Data(), 5_000_000_001)
        case .oversized:
            (ScriptedZeroArgumentOutputSystem(results: []),
             Data(repeating: 1, count: 513),
             5_000_000_001)
        case .clockOverflow:
            (ScriptedZeroArgumentOutputSystem(
                now: .max - 1, results: [.success(1)]
            ), Data([1]), 5_000_000_001)
        case .waitError:
            (ScriptedZeroArgumentOutputSystem(
                results: [.success(1)],
                waitResults: [.failure(.init(errno: ETIMEDOUT))]
            ), Data([1]), 5_000_000_001)
        case .zeroWrite:
            (ScriptedZeroArgumentOutputSystem(results: [.success(0)]), Data([1]), 5_000_000_001)
        case .writeError:
            (ScriptedZeroArgumentOutputSystem(
                results: [.failure(.init(errno: EIO))]
            ), Data([1]), 5_000_000_001)
        case .overreportedWrite:
            (ScriptedZeroArgumentOutputSystem(results: [.success(2)]), Data([1]), 5_000_000_001)
        case .deadlineAfterReadiness:
            (ScriptedZeroArgumentOutputSystem(
                clockValues: [41, 5_000_000_041],
                results: [.success(1)]
            ), Data([1]), 5_000_000_041)
        case .deadlineAfterPartialWrite:
            (ScriptedZeroArgumentOutputSystem(
                clockValues: [41, 42, 5_000_000_041],
                results: [.success(1)]
            ), Data([1, 2]), 5_000_000_041)
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
    private var standardErrorValues: [Data] = []

    func append(_ event: String) { lock.withLock { events.append(event) } }
    func output(_ data: Data) { lock.withLock { outputValues.append(data) } }
    func standardError(_ data: Data) { lock.withLock { standardErrorValues.append(data) } }
    func snapshot() -> [String] { lock.withLock { events } }
    var outputs: [Data] { lock.withLock { outputValues } }
    var stderr: [Data] { lock.withLock { standardErrorValues } }
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

private final class TerminalOutputProbe: @unchecked Sendable {
    enum WriteKind: Equatable {
        case evidence
        case completion
    }

    private let lock = NSLock()
    private let beginDeadline: UInt64
    private let writeEvidenceError: InvestigationMachineZeroArgumentEntryError?
    private let writeArtifactError: InvestigationMachineZeroArgumentEntryError?
    private var deadlines: [UInt64] = []
    private var writes: [WriteKind] = []

    init(
        beginDeadline: UInt64 = 777,
        writeEvidenceError: InvestigationMachineZeroArgumentEntryError? = nil,
        writeArtifactError: InvestigationMachineZeroArgumentEntryError? = nil
    ) {
        self.beginDeadline = beginDeadline
        self.writeEvidenceError = writeEvidenceError
        self.writeArtifactError = writeArtifactError
    }

    func begin() -> UInt64 { beginDeadline }

    func writeEvidence(_ deadline: UInt64) throws {
        try lock.withLock {
            deadlines.append(deadline)
            writes.append(.evidence)
            if let writeEvidenceError { throw writeEvidenceError }
        }
    }

    func writeArtifact(_ deadline: UInt64) throws {
        try lock.withLock {
            deadlines.append(deadline)
            writes.append(.completion)
            if let writeArtifactError { throw writeArtifactError }
        }
    }

    func snapshot() -> (deadlines: [UInt64], writes: [WriteKind]) {
        lock.withLock { (deadlines, writes) }
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
    cancellation: LateCancellationProbe? = nil,
    terminalOutput: TerminalOutputProbe? = nil
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
            _ = try installedObservation()
        },
        readPlan: {
            trace.append("intake")
            if failure == .intake { throw failure!.error }
            return plan
        },
        prebindPlan: { plan in
            trace.append("prebind")
            let first = try selectionFixture()
            return InvestigationMachineZeroArgumentPreboundPlan(
                firstSelection: first,
                plan: plan
            )
        },
        collectLineageClaim: { selection in
            trace.append("claim")
            return try claimFixture(selection: selection)
        },
        writeFramedClaim: { claim in
            trace.append("claim-write")
            trace.output(try framedClaimData(claim))
        },
        stopForGate: { trace.append("stop") },
        beginEvidenceCollection: { _ in trace.append("begin-evidence") },
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
        beginTerminalOutputDeadline: {
            terminalOutput?.begin() ?? 777
        },
        writeArtifact: { data, deadline in
            trace.append("write")
            try terminalOutput?.writeArtifact(deadline)
            if failure == .write { throw failure!.error }
            trace.output(data)
            cancellation?.commit()
        },
        finishEvidenceCollection: { _ in try evidenceBundleFixture() },
        writeEvidence: { claim, bundle, deadline in
            trace.append("evidence-write")
            try terminalOutput?.writeEvidence(deadline)
            trace.standardError(try evidenceData(claim: claim, bundle: bundle))
        }
    )
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

private func decodeBigEndianUInt32<S: DataProtocol>(_ data: S) throws -> UInt32 {
    let bytes = Array(data)
    guard bytes.count == 4 else {
        throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
    }
    return bytes.reduce(0) { ($0 << 8) | UInt32($1) }
}

private func framedClaimData(_ claim: ResolvedRootDriverClaimV1) throws -> Data {
    let encoded = try claim.encoded()
    guard let count = UInt32(exactly: encoded.count) else {
        throw InvestigationMachineZeroArgumentEntryError.outputUnavailable
    }
    return completionUInt32Data(count) + encoded
}

private func evidenceData(
    claim: ResolvedRootDriverClaimV1,
    bundle: Data
) throws -> Data {
    let claimLine = Data(
        ("STORNAUT_TASK39_IIC_ROOT_DRIVER_CLAIM_V1 "
            + (try claim.encoded()).base64EncodedString()
            + "\n").utf8
    )
    let bundleLine = Data(
        ("STORNAUT_TASK39_IIC_EPOCH_BUNDLE_V1 "
            + bundle.base64EncodedString()
            + "\n").utf8
    )
    return claimLine + bundleLine
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

private func selectionFixture() throws -> InvestigationMachineFixedEpochSelection {
    let configuration = Data("claim-flow-configuration".utf8)
    let epochUUID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000201"
    )!
    let configurationNonce = UUID(
        uuidString: "00000000-0000-0000-0000-000000000301"
    )!
    let configurationSHA256 = InvestigationHandoffSHA256.hashing(configuration)
    let signedRuntimeBindingSHA256 = try completionDigest(0x7a)
    let epoch = try InvestigationCohortEpoch(
        ordinal: 0,
        epochUUID: epochUUID,
        scenario: .success,
        configurationNonce: configurationNonce,
        configuration: configuration,
        configurationSHA256: configurationSHA256,
        signedRuntimeBindingSHA256: signedRuntimeBindingSHA256
    )
    return .init(
        outerAttemptUUID: try completionSummary().outerAttemptUUID,
        wholeCapsuleSHA256: try completionDigest(0x21),
        wholeInputSHA256: try completionDigest(0x22),
        epoch: epoch,
        projection: try projectionFixture(
            epochUUID: epochUUID,
            configurationNonce: configurationNonce,
            configurationSHA256: configurationSHA256,
            signedRuntimeBindingSHA256: signedRuntimeBindingSHA256
        )
    )
}

private func projectionFixture(
    epochUUID: UUID,
    configurationNonce: UUID,
    configurationSHA256: InvestigationHandoffSHA256,
    signedRuntimeBindingSHA256: InvestigationHandoffSHA256
) throws -> InvestigationInstalledL2IdentityProjection {
    try .init(
        epochUUID: epochUUID,
        configurationNonce: configurationNonce,
        configurationValidBefore: .init(rawValue: 2_000_000_000_000_000),
        configurationSHA256: configurationSHA256,
        signedRuntimeBindingSHA256: signedRuntimeBindingSHA256,
        appExecutableSHA256: .hashing(Data([0x7b])),
        appBundleIdentifier:
            InvestigationInstalledL2IdentityProjection.fixedAppBundleIdentifier,
        helperExecutableSHA256: .hashing(Data([0x7c])),
        helperServiceIdentifier:
            InvestigationInstalledL2IdentityProjection
            .fixedHelperServiceIdentifier,
        machineDriverExecutableSHA256: .hashing(Data([0x7d])),
        machineDriverSigningIdentifier:
            InvestigationInstalledL2IdentityProjection
            .fixedMachineDriverSigningIdentifier,
        machineDriverDesignatedRequirementSHA256: .hashing(Data([0x80])),
        machineDriverCodeDirectoryHash: Data(repeating: 0x03, count: 20),
        machineClaimServiceIdentifier:
            InvestigationInstalledL2IdentityProjection
            .fixedMachineClaimServiceIdentifier
    )
}

private func claimFixture(
    selection: InvestigationMachineFixedEpochSelection? = nil
) throws -> ResolvedRootDriverClaimV1 {
    let selected = try selection ?? selectionFixture()
    let process = try InvestigationGeneralProcessIdentityV1(
        processID: 9001,
        processIDVersion: 2,
        startSeconds: 100,
        startMicroseconds: 200,
        parentProcessID: 42,
        processGroupID: 9001,
        sessionID: 42,
        auditSessionID: 7,
        auditTokenWords: [0, 0, 0, 0, 0, 9001, 7, 2],
        realUserID: 0,
        effectiveUserID: 0,
        savedUserID: 0,
        realGroupID: 0,
        effectiveGroupID: 0,
        savedGroupID: 0,
        supplementaryGroups: [0]
    )
    let signing = try InvestigationResolvedRootDriverSigningIdentityV1(
        signingIdentifier: ResolvedRootDriverClaimV1.fixedSigningIdentifier,
        designatedRequirementSHA256: .hashing(Data([0x44])),
        codeDirectoryHash: Data(repeating: 0x45, count: 20),
        isAdHoc: true
    )
    let executable = try InvestigationResolvedRootDriverExecutableIdentityV1(
        path: ResolvedRootDriverClaimV1.fixedExecutablePath,
        node: .init(
            deviceID: 1,
            inode: 2,
            generation: 3,
            isRegularFile: true,
            ownerUserID: 0,
            ownerGroupID: 0,
            mode: 0o755,
            linkCount: 1,
            size: 4_096,
            flags: 0
        ),
        sha256: .hashing(Data([0x46])),
        staticSigning: signing,
        liveSigning: signing
    )
    return try .init(
        outerAttemptUUID: selected.outerAttemptUUID,
        wholeInputSHA256: selected.wholeInputSHA256,
        process: process,
        executable: executable,
        observedAtContinuousNanoseconds: 1_234_567_890
    )
}

private func evidenceBundleFixture() throws -> Data {
    Data("evidence-bundle".utf8)
}

private func installedObservation() throws -> InvestigationMachineInstalledDriverObservation {
    .init(
        executablePath: ResolvedRootDriverClaimV1.fixedExecutablePath,
        node: .init(
            deviceID: 1,
            inode: 2,
            generation: 3,
            isRegularFile: true,
            ownerUserID: 0,
            ownerGroupID: 0,
            mode: 0o755,
            linkCount: 1,
            size: 4_096,
            flags: 0,
            modificationSeconds: 1,
            modificationNanoseconds: 2,
            statusChangeSeconds: 3,
            statusChangeNanoseconds: 4
        ),
        executableSHA256: String(repeating: "a", count: 64),
        signing: .init(
            signingIdentifier: ResolvedRootDriverClaimV1.fixedSigningIdentifier,
            designatedRequirementSHA256: String(repeating: "b", count: 64),
            codeDirectoryHash: String(repeating: "c", count: 40),
            isAdHoc: true
        ),
        manifest: .init(
            path: InvestigationMachineInstalledDriverObservation.fixedLaunchDaemonManifestPath,
            node: .init(
                deviceID: 5,
                inode: 6,
                generation: 7,
                isRegularFile: true,
                ownerUserID: 0,
                ownerGroupID: 0,
                mode: 0o644,
                linkCount: 1,
                size: 128,
                flags: 0,
                modificationSeconds: 1,
                modificationNanoseconds: 2,
                statusChangeSeconds: 3,
                statusChangeNanoseconds: 4
            ),
            sha256: InvestigationMachineInstalledDriverObservation.fixedLaunchDaemonManifestSHA256,
            label: InvestigationMachineInstalledDriverObservation.fixedLifecycleLabel,
            program: InvestigationMachineInstalledDriverObservation.fixedLifecycleProgram,
            primaryServiceIdentifier: InvestigationMachineInstalledDriverObservation.fixedLifecycleLabel,
            machineClaimServiceIdentifier: InvestigationMachineInstalledDriverObservation.fixedMachineClaimServiceIdentifier
        )
    )
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
        let statusReads: [Int32]
        let statusSets: [(Int32, Int32)]
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
    private var descriptorStatusValues: [Int32: Int32] = [
        STDOUT_FILENO: O_WRONLY | O_NONBLOCK,
        STDERR_FILENO: O_WRONLY,
    ]
    private var statusReadValues: [Int32] = []
    private var statusSetValues: [(Int32, Int32)] = []
    var failStatusReadAfterFirstSet = false
    var failRestoreSet = false

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
            descriptorStatusFlags: { [self] descriptor in
                lock.withLock {
                    statusReadValues.append(descriptor)
                    if failStatusReadAfterFirstSet, statusSetValues.count == 1 {
                        return .failure(.init(errno: EIO))
                    }
                    guard let value = descriptorStatusValues[descriptor] else {
                        return .failure(.init(errno: EBADF))
                    }
                    return .success(value)
                }
            },
            setStatusFlags: { [self] descriptor, flags in
                lock.withLock {
                    statusSetValues.append((descriptor, flags))
                    if failRestoreSet, statusSetValues.count > 1 {
                        return .failure(.init(errno: EIO))
                    }
                    descriptorStatusValues[descriptor] = flags
                    return .success(())
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
                statusReads: statusReadValues,
                statusSets: statusSetValues,
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
