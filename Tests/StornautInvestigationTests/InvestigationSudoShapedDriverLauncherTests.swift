import Darwin
import Foundation
import Testing

@testable import StornautInvestigationHandoffContract
@testable import StornautInvestigationMachineGateSupport

@Suite("Investigation sudo-shaped driver launcher", .serialized)
struct InvestigationSudoShapedDriverLauncherTests {
    @Test
    func fixedContractHasNoCallerSelectedProcessAuthority() {
        #expect(
            InvestigationMachineFixedGateContract.launcherPath
                == "/usr/bin/sudo"
        )
        #expect(
            InvestigationMachineFixedGateContract.driverPath
                == "/Library/Application Support/Stornaut/"
                    + "Stornaut-R5-Diagnostic.app/Contents/MacOS/"
                    + "StornautInvestigationMachineDriver"
        )
        #expect(InvestigationMachineFixedGateContract.arguments == [
            "/usr/bin/sudo", "-N", "-p",
            "Stornaut Task 39 ii-c administrator authorization: ",
            "--",
            "/Library/Application Support/Stornaut/"
                + "Stornaut-R5-Diagnostic.app/Contents/MacOS/"
                + "StornautInvestigationMachineDriver",
        ])
        #expect(InvestigationMachineFixedGateContract.environment.isEmpty)
        #expect(InvestigationMachineFixedGateContract.requiredUserID == 501)
        #expect(InvestigationMachineFixedGateContract.requiredGroupID == 20)
        #expect(
            InvestigationMachineFixedGateContract.deadlineNanoseconds
                == 1_200_000_000_000
        )
        #expect(
            InvestigationMachineFixedGateContract.maximumCapturedOutputByteCount
                == 512
        )
        #expect(
            InvestigationMachineFixedGateContract.maximumReadOutputByteCount
                == 513
        )
        #expect(
            InvestigationMachineFixedGateContract.forwardedSignals
                == [SIGHUP, SIGINT, SIGQUIT, SIGTERM]
        )
        #expect(
            InvestigationMachineFixedGateContract.childSpawnFlags
                == Int16(
                    POSIX_SPAWN_CLOEXEC_DEFAULT
                        | POSIX_SPAWN_START_SUSPENDED
                        | POSIX_SPAWN_SETSIGMASK
                        | POSIX_SPAWN_SETSIGDEF
                )
        )
    }

    @Test(arguments: GateInvocationMutation.allCases)
    fileprivate func invocationRequiresFixedIdentityAndForegroundTTY(
        _ mutation: GateInvocationMutation
    ) {
        let observation = mutation.apply(to: .valid)
        if mutation == .valid {
            #expect(throws: Never.self) {
                try InvestigationMachineGateInvocationValidator.validate(
                    observation
                )
            }
        } else {
            #expect(
                throws: InvestigationMachineGateError.invalidInvocation
            ) {
                try InvestigationMachineGateInvocationValidator.validate(
                    observation
                )
            }
        }
    }

    @Test
    func preparedFrameIsStrictAndBindsRecoveryBeforeForegroundHandoff() throws {
        let frame = try InvestigationMachineGatePreparedFrame(
            gateProcessID: 41,
            coordinatorProcessID: 40, sessionID: 40,
            childProcessID: 52,
            recoveryProcessGroupID: 41,
            savedForegroundProcessGroupID: 40,
            childParentProcessID: 41,
            childSessionID: 40, childStartSeconds: 12,
            childStartMicroseconds: 34, initialStopStatus: 0x7f,
            outerAttemptUUID: try #require(
                UUID(uuidString: "10000000-0000-4000-8000-000000000001")
            ),
            wholeInputSHA256: digest(0x11)
            , capsule: .init(
                device: 7, inode: 8, generation: 9, size: 1_024
            )
            , terminal: tty(foreground: 40)
            , absoluteDeadlineNanoseconds: 1_200_000_000_100
        )
        let encoded = try frame.encoded()
        #expect(encoded.count <= Int(PIPE_BUF))
        #expect(try InvestigationMachineGatePreparedFrame.decode(encoded) == frame)
        #expect(frame.recoveryProcessGroupID == frame.gateProcessID)
        #expect(frame.childIdentity == childIdentity())
        #expect(frame.childIdentity.processID != frame.recoveryProcessGroupID)
        #expect(!(type(of: frame) is any Codable.Type))

        for bytes in [
            Data(),
            encoded.dropLast(),
            encoded + Data([0]),
            replacingFirst(encoded, byte: 0xff),
        ] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationMachineGatePreparedFrame.decode(Data(bytes))
            }
        }
        #expect(throws: InvestigationMachineGateError.invalidFrame) {
            _ = try InvestigationMachineGatePreparedFrame(
                gateProcessID: 41, coordinatorProcessID: 40,
                sessionID: 40, childProcessID: 52,
                recoveryProcessGroupID: 53,
                savedForegroundProcessGroupID: 40,
                childParentProcessID: 41,
                childSessionID: 40, childStartSeconds: 12,
                childStartMicroseconds: 34, initialStopStatus: 0x7f,
                outerAttemptUUID: frame.outerAttemptUUID,
                wholeInputSHA256: frame.wholeInputSHA256
                , capsule: frame.capsule, terminal: frame.terminal
                , absoluteDeadlineNanoseconds: frame.absoluteDeadlineNanoseconds
            )
        }
    }

    @Test
    func transportReceiptRoundTripsWithoutSemanticOrCleanupClaims() throws {
        let receipt = try sampleReceipt()
        let encoded = try receipt.encoded()
        #expect(encoded.count <= Int(PIPE_BUF))
        #expect(try InvestigationMachineGateTransportReceipt.decode(encoded) == receipt)
        #expect(!(type(of: receipt) is any Codable.Type))
        #expect(receipt.output.byteCount == 512)
        #expect(receipt.output.overflowObserved)
        #expect(receipt.output.reachedEOF)
        #expect(!receipt.output.deadlineExpired)
        #expect(receipt.waitClassification == .exited(status: 0))
        #expect(receipt.terminationProgression == .natural)
        #expect(receipt.childProcessGroupEmpty)
        #expect(receipt.exactChildReaped)
        #expect(receipt.savedForegroundProcessGroupRestored)
        #expect(receipt.borrowedDescriptorOutcome == .closed)

        for bytes in [
            Data(), encoded.dropLast(), encoded + Data([0]),
            replacingFirst(encoded, byte: 0xff),
        ] {
            #expect(throws: (any Error).self) {
                _ = try InvestigationMachineGateTransportReceipt.decode(Data(bytes))
            }
        }
    }

    @Test
    func launcherOrdersPreparedStopForegroundRetirementAndClose() throws {
        let system = GateLauncherRecorder()
        let result = try InvestigationMachineFixedGateLauncher(
            system: system
        ).run(inheritedCapsuleDescriptor: STDIN_FILENO)

        let expectedReceipt = try sampleReceipt()
        #expect(result.receipt == expectedReceipt)
        #expect(system.events == [
            .validateInvocation, .observeStart,
            .observeLauncherExecutable, .observeInitialInput,
            .observeInitialTTY,
            .makeOutputPipe, .spawnSuspendedChild,
            .closeOutputDescriptor(11), .verifyChildProcessGroup,
            .observeChildIdentity,
            .joinCoordinatorProcessGroup(40),
            .verifyGateAndChildTopology,
            .writePreparedFrame(try preparedBytes()),
            .stopGateForCoordinator,
            .verifyGateAndChildTopology, .verifyForegroundProcessGroup(40),
            .revalidateTransitionTTY,
            .setForegroundProcessGroup(41), .continueChildGroup(41),
            .observeChildTTY, .drainOutput, .observeWaitableChild,
            .setForegroundProcessGroup(40),
            .verifyForegroundProcessGroup(40),
            .observeLeaderOnlyChildGroup, .reapExactChild,
            .observeEmptyChildGroup, .setForegroundProcessGroup(40),
            .verifyForegroundProcessGroup(40), .revalidateFinalTTY,
            .observeFinalInput,
            .closeOutputDescriptor(10), .closeBorrowedDescriptor(STDIN_FILENO),
            .observeCompletion,
            .writeTerminalReceipt(try sampleReceipt().encoded()),
        ])
    }

    @Test(arguments: GateTerminalScenario.allCases)
    fileprivate func everyTerminalPathRestoresAndReapsBeforeBorrowedClose(
        _ scenario: GateTerminalScenario
    ) throws {
        let system = GateLauncherRecorder(scenario: scenario)
        let launcher = InvestigationMachineFixedGateLauncher(
            system: system
        )
        if scenario == .outputFailure {
            #expect(throws: (any Error).self) {
                _ = try launcher.run(
                    inheritedCapsuleDescriptor: STDIN_FILENO
                )
            }
            #expect(system.events.contains(.sendTermToChildGroup(41)))
            #expect(system.events.contains(.reapExactChild))
            #expect(system.events.contains(.observeEmptyChildGroup))
            #expect(system.events.contains(.closeOutputDescriptor(10)))
            #expect(system.events.contains(.closeBorrowedDescriptor(0)))
            #expect(!system.events.contains { event in
                if case .writeTerminalReceipt = event { return true }
                return false
            })
            return
        }
        let result = try launcher.run(
            inheritedCapsuleDescriptor: STDIN_FILENO
        )

        let events = system.events
        #expect(try index(of: .setForegroundProcessGroup(40), in: events)
            < index(of: .reapExactChild, in: events))
        #expect(try index(of: .revalidateFinalTTY, in: events)
            < index(of: .closeBorrowedDescriptor(STDIN_FILENO), in: events))
        #expect(result.receipt.childProcessGroupEmpty)
        #expect(result.receipt.exactChildReaped)
        #expect(result.receipt.savedForegroundProcessGroupRestored)
        if scenario.requiresTermination {
            #expect(events.contains(.sendTermToChildGroup(41)))
        }
        if scenario.requiresKill {
            #expect(events.contains(.sendKillToChildGroup(41)))
        }
    }

    @Test(arguments: GateFailurePoint.allCases)
    fileprivate func postSpawnFailureRunsCompleteCleanupBeforeReturning(
        _ point: GateFailurePoint
    ) throws {
        let system = GateLauncherRecorder(failureEvent: point.event)
        #expect(throws: GateInjectedFailure.self) {
            _ = try InvestigationMachineFixedGateLauncher(system: system)
                .run(inheritedCapsuleDescriptor: STDIN_FILENO)
        }
        let events = system.events
        if point.isBeforeCoordinatorJoin {
            let settle = try index(
                of: .settleChildBeforeCoordinatorJoin, in: events
            )
            let borrowedClose = try index(
                of: .closeBorrowedDescriptor(STDIN_FILENO), in: events
            )
            #expect(settle < borrowedClose)
            #expect(!events.contains(.sendTermToChildGroup(41)))
            #expect(!events.contains(.sendKillToChildGroup(41)))
            #expect(!events.contains(.reapExactChild))
            return
        }
        let restore = try index(of: .setForegroundProcessGroup(40), in: events)
        let term = try index(of: .sendTermToChildGroup(41), in: events)
        let leaderOnly = try #require(
            events.lastIndex(of: .observeLeaderOnlyChildGroup)
        )
        let reap = try index(of: .reapExactChild, in: events)
        let empty = try index(of: .observeEmptyChildGroup, in: events)
        #expect(restore < term)
        #expect(leaderOnly < reap)
        #expect(reap < empty)
        #expect(events.contains(.closeOutputDescriptor(10)))
        #expect(events.contains(.closeBorrowedDescriptor(STDIN_FILENO)))
        #expect(events.contains(.closeOutputDescriptor(STDOUT_FILENO)))
        #expect(events.last == .closeOutputDescriptor(STDOUT_FILENO))
        #expect(!events.contains { event in
            if case .writeTerminalReceipt = event { return true }
            return false
        })
    }

    @Test
    func pendingSignalBeforeHandoffNeverMakesChildForeground() throws {
        let system = GateLauncherRecorder(pendingSignal: SIGINT)
        #expect(throws: InvestigationMachineGateError.forwardedSignal(SIGINT)) {
            _ = try InvestigationMachineFixedGateLauncher(system: system)
                .run(inheritedCapsuleDescriptor: STDIN_FILENO)
        }
        #expect(!system.events.contains(.setForegroundProcessGroup(41)))
        let restore = try index(
            of: .setForegroundProcessGroup(40), in: system.events
        )
        let term = try index(of: .sendTermToChildGroup(41), in: system.events)
        #expect(restore < term)
        #expect(system.events.contains(.reapExactChild))
        #expect(system.events.contains(.observeEmptyChildGroup))
    }

    @Test
    func transportOutcomeMapsToFailClosedExecutableStatus() throws {
        #expect(
            InvestigationMachineGateSupport.status(for: try sampleReceipt())
                == InvestigationMachineGateSupport.transportFailureExitStatus
        )
        #expect(
            InvestigationMachineGateSupport.status(
                for: try sampleReceipt(
                    outputOverflow: false, outputEOF: true
                )
            ) == InvestigationMachineGateSupport.completedExitStatus
        )
        #expect(
            InvestigationMachineGateSupport.status(
                for: try sampleReceipt(
                    outputOverflow: false, outputEOF: true,
                    forwardedSignal: SIGINT
                )
            ) == InvestigationMachineGateSupport.forwardedSignalExitStatus
        )
        #expect(
            InvestigationMachineGateSupport.status(
                for: try sampleReceipt(
                    outputOverflow: false, outputEOF: true,
                    waitClassification: .exited(status: 1)
                )
            ) == InvestigationMachineGateSupport.transportFailureExitStatus
        )
        #expect(
            InvestigationMachineGateSupport.status(
                for: try sampleReceipt(
                    outputOverflow: false, outputEOF: true,
                    waitClassification: .exited(status: 0),
                    terminationProgression: .term
                )
            ) == InvestigationMachineGateSupport.transportFailureExitStatus
        )
        #expect(
            InvestigationMachineGateSupport.status(
                for: try sampleReceipt(
                    outputOverflow: false, outputEOF: true,
                    borrowedDescriptorOutcome: .closeFailed(errno: EIO)
                )
            ) == InvestigationMachineGateSupport.transportFailureExitStatus
        )
    }

    @Test
    func exactReapAlwaysRepeatsForegroundRestoration() throws {
        let system = GateLauncherRecorder(scenario: .stoppedThenExitZero)
        let result = try InvestigationMachineFixedGateLauncher(system: system)
            .run(inheritedCapsuleDescriptor: STDIN_FILENO)

        let restores = system.events.indices.filter {
            system.events[$0] == .setForegroundProcessGroup(40)
        }
        #expect(restores.count == 2)
        let reap = try index(of: .reapExactChild, in: system.events)
        let empty = try index(of: .observeEmptyChildGroup, in: system.events)
        let finalRestore = try #require(restores.last)
        let finalVerify = try #require(system.events.lastIndex(
            of: .verifyForegroundProcessGroup(40)
        ))
        let finalTTY = try index(of: .revalidateFinalTTY, in: system.events)
        #expect(reap < empty)
        #expect(empty < finalRestore)
        #expect(finalRestore < finalVerify)
        #expect(finalVerify < finalTTY)
        #expect(result.receipt.waitClassification == .exited(status: 0))
        #expect(result.receipt.terminationProgression == .term)
        #expect(
            InvestigationMachineGateSupport.status(for: result.receipt)
                == InvestigationMachineGateSupport.transportFailureExitStatus
        )
    }

    @Test
    func failureCleanupRepeatsForegroundRestorationAfterRetirement() throws {
        let system = GateLauncherRecorder(failureEvent: .drainOutput)
        #expect(throws: GateInjectedFailure.self) {
            _ = try InvestigationMachineFixedGateLauncher(system: system)
                .run(inheritedCapsuleDescriptor: STDIN_FILENO)
        }

        let empty = try index(of: .observeEmptyChildGroup, in: system.events)
        let finalRestore = try #require(system.events.lastIndex(
            of: .setForegroundProcessGroup(40)
        ))
        let finalVerify = try #require(system.events.lastIndex(
            of: .verifyForegroundProcessGroup(40)
        ))
        let finalTTY = try #require(system.events.lastIndex(
            of: .revalidateFinalTTY
        ))
        #expect(empty < finalRestore)
        #expect(finalRestore < finalVerify)
        #expect(finalVerify < finalTTY)
    }

    @Test
    func initialStopDeadlineReservesFiveSecondCleanupWindow() throws {
        #expect(
            try InvestigationMachineGateDeadlinePolicy.operationDeadline(
                absoluteDeadlineNanoseconds: 1_200_000_000_100
            ) == 1_195_000_000_100
        )
        #expect(throws: InvestigationMachineGateError.containmentUncertain) {
            _ = try InvestigationMachineGateDeadlinePolicy.operationDeadline(
                absoluteDeadlineNanoseconds: 5_000_000_000
            )
        }
    }

    @Test
    func initialStopFailureUsesBoundedNonblockingExactCleanup() throws {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appending(
                path: "Sources/StornautInvestigationMachineGateSupport/"
                    + "DarwinInvestigationMachineFixedGateSystem.swift"
            ),
            encoding: .utf8
        )

        #expect(source.contains(
            "let deadline = try operationDeadline()"
        ))
        #expect(source.contains(
            "waitpid(processID, &status, WNOHANG)"
        ))
        #expect(!source.contains("waitpid(processID, nil, 0)"))
        #expect(source.contains(
            "guard Darwin.kill(processID, SIGKILL) == 0"
        ))
        #expect(!source.contains(
            "Darwin.kill(-recoveryGroup, SIGKILL)"
        ))
        #expect(source.contains(
            "guard try stableChildIdentity(processID: processID)"
        ))
        #expect(source.contains(
            "recoveryGroupMembers == [gateProcessID]"
        ))
        #expect(source.contains("setpgid(0, coordinatorGroup)"))
        #expect(source.contains(
            "recoveryGroupMembers.isEmpty"
        ))
    }

    @Test
    func runtimeSignalAndPreJoinRecoveryUseExactIdentities() throws {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appending(
                path: "Sources/StornautInvestigationMachineGateSupport/"
                    + "DarwinInvestigationMachineFixedGateSystem.swift"
            ), encoding: .utf8
        )

        #expect(source.contains(
            "waitableChild(child)"
        ))
        #expect(!source.contains(
            "waitableChild(group)"
        ))
        #expect(source.contains(
            "recoveryGroupMembers.isEmpty"
        ))
        #expect(source.contains(
            "Darwin.kill(processID, SIGKILL)"
        ))
        #expect(!source.contains(
            "Darwin.kill(-recoveryGroup, SIGKILL)"
        ))
        let observation = try #require(
            source.range(of: "func observeChildState() throws")
        )
        let grace = try #require(
            source.range(of: "func waitForTerminationGrace() throws",
                range: observation.lowerBound..<source.endIndex)
        )
        let body = source[observation.lowerBound..<grace.lowerBound]
        let consume = try #require(body.range(
            of: "try consumeAndForwardPendingSignal()"
        ))
        let terminal = try #require(body.range(
            of: "if let terminal = try waitableChild(child)"
        ))
        #expect(consume.lowerBound < terminal.lowerBound)
    }

    @Test(arguments: [
        (true, [pid_t](), true),
        (true, [pid_t(61)], false),
        (false, [pid_t](), false),
    ])
    func missingGroupSignalRequiresExactChildAndEmptyRecoveryGroup(
        _ childWaitable: Bool, _ members: [pid_t], _ accepted: Bool
    ) {
        #expect(
            InvestigationMachineGateRuntimePolicy
                .missingGroupSignalIsSettled(
                    directChildWaitable: childWaitable,
                    recoveryGroupMembers: members
                ) == accepted
        )
    }

    @Test(arguments: [
        (false, [pid_t](), true),
        (true, [pid_t(61)], true),
        (true, [pid_t](), false),
    ])
    func pendingSignalSkipsOnlyTerminalEmptyRecoveryGroup(
        _ directChildTerminal: Bool, _ members: [pid_t], _ shouldForward: Bool
    ) {
        #expect(
            InvestigationMachineGateRuntimePolicy
                .shouldForwardPendingSignal(
                    directChildTerminal: directChildTerminal,
                    recoveryGroupMembers: members
                ) == shouldForward
        )
    }

    @Test
    func preJoinSettlementRequiresReapThenJoinThenEmptyProof() {
        #expect(
            InvestigationMachineGateRuntimePolicy.preJoinAction(
                childReaped: false, gateJoinedCoordinator: false,
                recoveryGroupMembers: [41, 52], gateProcessID: 41
            ) == .reapExactChild
        )
        #expect(
            InvestigationMachineGateRuntimePolicy.preJoinAction(
                childReaped: true, gateJoinedCoordinator: false,
                recoveryGroupMembers: [41], gateProcessID: 41
            ) == .joinCoordinator
        )
        #expect(
            InvestigationMachineGateRuntimePolicy.preJoinAction(
                childReaped: true, gateJoinedCoordinator: true,
                recoveryGroupMembers: [52], gateProcessID: 41
            ) == .proveRecoveryGroupEmpty
        )
        #expect(
            InvestigationMachineGateRuntimePolicy.preJoinAction(
                childReaped: true, gateJoinedCoordinator: true,
                recoveryGroupMembers: [], gateProcessID: 41
            ) == .complete
        )
        #expect(
            InvestigationMachineGateRuntimePolicy.preJoinAction(
                childReaped: true, gateJoinedCoordinator: false,
                recoveryGroupMembers: [41, 52], gateProcessID: 41
            ) == .reject
        )
    }

    @Test
    func nonInitialStoppedObservationIsNotAReap() {
        #expect(!InvestigationMachineGateRuntimePolicy
            .initialStopObservationWasReaped(.stopped(signal: SIGTSTP)))
        #expect(InvestigationMachineGateRuntimePolicy
            .initialStopObservationWasReaped(.exited(status: 1)))
        #expect(InvestigationMachineGateRuntimePolicy
            .initialStopObservationWasReaped(.signaled(signal: SIGKILL)))
    }

    @Test(arguments: [
        GateFailurePoint.closeChildPipeWriter,
        GateFailurePoint.verifyChildGroup,
    ])
    fileprivate func preJoinFailuresUseExactSettlementBeforeGroupCleanup(
        _ point: GateFailurePoint
    ) throws {
        let system = GateLauncherRecorder(failureEvent: point.event)
        #expect(throws: GateInjectedFailure.self) {
            _ = try InvestigationMachineFixedGateLauncher(system: system)
                .run(inheritedCapsuleDescriptor: STDIN_FILENO)
        }
        let settle = try index(
            of: .settleChildBeforeCoordinatorJoin, in: system.events
        )
        let borrowedClose = try index(
            of: .closeBorrowedDescriptor(STDIN_FILENO), in: system.events
        )
        #expect(settle < borrowedClose)
        #expect(!system.events.contains(.sendTermToChildGroup(41)))
        #expect(!system.events.contains(.sendKillToChildGroup(41)))
        #expect(!system.events.contains(.reapExactChild))
    }

    @Test
    func settledInitialStopFailureIsNeverSignaledOrReapedAgain() throws {
        let system = GateLauncherRecorder(settledSpawnFailure: true)
        #expect(throws: InvestigationMachineGateError.containmentUncertain) {
            _ = try InvestigationMachineFixedGateLauncher(system: system)
                .run(inheritedCapsuleDescriptor: STDIN_FILENO)
        }

        #expect(!system.events.contains(.sendTermToChildGroup(52)))
        #expect(!system.events.contains(.sendKillToChildGroup(52)))
        #expect(!system.events.contains(.reapExactChild))
        #expect(system.events.contains(.closeOutputDescriptor(10)))
        #expect(system.events.contains(.closeOutputDescriptor(11)))
        #expect(system.events.contains(.closeBorrowedDescriptor(STDIN_FILENO)))
    }

    @Test(arguments: [
        ([], true),
        (["__CF_USER_TEXT_ENCODING=0x1F5:0x0:0x0"], true),
        (["HOME=/tmp"], false),
        (["__CF_USER_TEXT_ENCODING"], false),
        (["__CF_USER_TEXT_ENCODING=invalid"], false),
        ([
            "__CF_USER_TEXT_ENCODING=0x1F5:0x0:0x0",
            "__CF_USER_TEXT_ENCODING=0x1F5:0x0:0x0",
        ], false),
    ])
    func environmentNormalizationAcceptsOnlySystemInjection(
        _ entries: [String], _ accepted: Bool
    ) throws {
        if accepted {
            #expect(
                try InvestigationMachineGateEnvironmentValidator
                    .normalizedSourceEnvironmentCount(entries) == 0
            )
        } else {
            #expect(throws: InvestigationMachineGateError.invalidInvocation) {
                _ = try InvestigationMachineGateEnvironmentValidator
                    .normalizedSourceEnvironmentCount(entries)
            }
        }
    }
}

private enum GateInvocationMutation: CaseIterable {
    case valid
    case notRecoveryGroupLeader
    case recoveryGroupIsForeground
    case extraArgument
    case nonemptyEnvironment
    case realUser
    case effectiveUser
    case realGroup
    case effectiveGroup
    case fd0Missing
    case fd1NotWritable
    case fd2NotWritableCharacterDevice
    case invalidProcessGroup
    case invalidForeground
    case parentIsNotCoordinatorLeader
    case sessionIsNotCoordinatorLeader
    case foregroundIsNotCoordinatorLeader

    func apply(
        to value: InvestigationMachineGateInvocationObservation
    ) -> InvestigationMachineGateInvocationObservation {
        switch self {
        case .valid:
            value
        case .notRecoveryGroupLeader:
            value.replacing(processID: 41, processGroupID: 40)
        case .recoveryGroupIsForeground:
            value.replacing(foregroundProcessGroupID: 41)
        case .extraArgument:
            value.replacing(argumentCount: 2)
        case .nonemptyEnvironment:
            value.replacing(environmentCount: 1)
        case .realUser:
            value.replacing(realUserID: 502)
        case .effectiveUser:
            value.replacing(effectiveUserID: 502)
        case .realGroup:
            value.replacing(realGroupID: 21)
        case .effectiveGroup:
            value.replacing(effectiveGroupID: 21)
        case .fd0Missing:
            value.replacing(inputDescriptorValid: false)
        case .fd1NotWritable:
            value.replacing(outputDescriptorWritable: false)
        case .fd2NotWritableCharacterDevice:
            value.replacing(terminalDescriptorWritableCharacterDevice: false)
        case .invalidProcessGroup:
            value.replacing(processGroupID: 0, foregroundProcessGroupID: 0)
        case .invalidForeground:
            value.replacing(foregroundProcessGroupID: 0)
        case .parentIsNotCoordinatorLeader:
            value.replacing(parentProcessID: 39)
        case .sessionIsNotCoordinatorLeader:
            value.replacing(sessionID: 39)
        case .foregroundIsNotCoordinatorLeader:
            value.replacing(foregroundProcessGroupID: 39)
        }
    }
}

private extension InvestigationMachineGateInvocationObservation {
    static let valid = Self(
        argumentCount: 1, environmentCount: 0,
        realUserID: 501, effectiveUserID: 501,
        realGroupID: 20, effectiveGroupID: 20,
        inputDescriptorValid: true, outputDescriptorWritable: true,
        terminalDescriptorWritableCharacterDevice: true,
        processID: 41, parentProcessID: 40, sessionID: 40,
        processGroupID: 41, foregroundProcessGroupID: 40
    )
}

private enum GateTerminalScenario: CaseIterable {
    case ordinaryExit
    case signaledExit
    case stopped
    case timeout
    case outputFailure
    case stoppedThenExitZero

    var requiresTermination: Bool {
        self == .stopped || self == .timeout || self == .outputFailure
            || self == .stoppedThenExitZero
    }
    var requiresKill: Bool { self == .timeout }
}

private struct GateInjectedFailure: Error {}

private enum GateFailurePoint: CaseIterable {
    case closeChildPipeWriter
    case verifyChildGroup
    case observeChildIdentity
    case joinCoordinator
    case writePrepared
    case stopForCoordinator
    case foregroundHandoff
    case observeChildTTY
    case drainOutput
    case observeChildState

    var event: InvestigationMachineGateLauncherEvent {
        switch self {
        case .closeChildPipeWriter: .closeOutputDescriptor(11)
        case .verifyChildGroup: .verifyChildProcessGroup
        case .observeChildIdentity: .observeChildIdentity
        case .joinCoordinator: .joinCoordinatorProcessGroup(40)
        case .writePrepared: .writePreparedFrame(try! preparedBytes())
        case .stopForCoordinator: .stopGateForCoordinator
        case .foregroundHandoff: .setForegroundProcessGroup(41)
        case .observeChildTTY: .observeChildTTY
        case .drainOutput: .drainOutput
        case .observeChildState: .observeWaitableChild
        }
    }

    var isBeforeCoordinatorJoin: Bool {
        switch self {
        case .closeChildPipeWriter, .verifyChildGroup, .observeChildIdentity,
            .joinCoordinator:
            true
        default:
            false
        }
    }
}

private final class GateLauncherRecorder:
    InvestigationMachineFixedGateLauncherSystem, @unchecked Sendable
{
    private(set) var events: [InvestigationMachineGateLauncherEvent] = []
    private let scenario: GateTerminalScenario
    private let failureEvent: InvestigationMachineGateLauncherEvent?
    private let pendingSignal: Int32?
    private let settledSpawnFailure: Bool
    private var didInjectFailure = false
    private var didConsumePendingSignal = false

    init(
        scenario: GateTerminalScenario = .ordinaryExit,
        failureEvent: InvestigationMachineGateLauncherEvent? = nil,
        pendingSignal: Int32? = nil,
        settledSpawnFailure: Bool = false
    ) {
        self.scenario = scenario
        self.failureEvent = failureEvent
        self.pendingSignal = pendingSignal
        self.settledSpawnFailure = settledSpawnFailure
    }

    func consumePendingForwardedSignal() throws -> Int32? {
        guard !didConsumePendingSignal, let pendingSignal else { return nil }
        didConsumePendingSignal = true
        return pendingSignal
    }

    func perform(
        _ event: InvestigationMachineGateLauncherEvent
    ) throws -> InvestigationMachineGateLauncherResponse {
        events.append(event)
        if !didInjectFailure, event == failureEvent {
            didInjectFailure = true
            throw GateInjectedFailure()
        }
        switch event {
        case .validateInvocation:
            return .invocation(.valid)
        case .observeStart:
            return .nanoseconds(100)
        case .observeLauncherExecutable:
            return .sha256(digest(0x01))
        case .observeInitialInput:
            return .inputContext(.init(
                outerAttemptUUID: UUID(
                    uuidString: "10000000-0000-4000-8000-000000000001"
                )!,
                wholeInputSHA256: digest(0x11),
                node: .init(
                    device: 7, inode: 8, generation: 9, size: 1_024
                ),
                initialOffset: 0
            ))
        case .observeInitialTTY, .revalidateTransitionTTY, .revalidateFinalTTY:
            return .terminal(tty(foreground: 40))
        case .observeChildTTY:
            return .terminal(tty(foreground: 41))
        case .makeOutputPipe:
            return .descriptorPair(read: 10, write: 11)
        case .spawnSuspendedChild:
            if settledSpawnFailure {
                throw InvestigationMachineGateSettledSpawnFailure(
                    processID: 52, processGroupID: 41,
                    childAlreadyReaped: true, childGroupEmpty: true
                )
            }
            return .processID(52)
        case .verifyChildProcessGroup:
            return .processGroupID(41)
        case .observeChildIdentity:
            return .childIdentity(childIdentity())
        case .joinCoordinatorProcessGroup, .verifyGateAndChildTopology:
            return .completed
        case .drainOutput:
            if scenario == .outputFailure { return .outputFailure }
            return .output(.init(
                byteCount: 512, sha256: digest(0x44),
                overflowObserved: true
            ))
        case .observeWaitableChild:
            if scenario == .timeout, events.contains(.sendKillToChildGroup(41)) {
                return .waitClassification(.signaled(signal: SIGKILL))
            }
            if scenario == .timeout { return .childRunning }
            if scenario == .outputFailure || failureEvent != nil
                || pendingSignal != nil
            {
                return .waitClassification(.stopped(signal: SIGSTOP))
            }
            return .waitClassification(waitClassification)
        case .waitForTerminationGrace:
            if scenario == .timeout { return .childRunning }
            if scenario == .stoppedThenExitZero {
                return .waitClassification(.exited(status: 0))
            }
            return .waitClassification(.signaled(signal: SIGTERM))
        case .observeCompletion:
            return .nanoseconds(200)
        case .observeFinalInput:
            return .input(.init(
                node: .init(
                    device: 7, inode: 8, generation: 9, size: 1_024
                ),
                initialOffset: 0, finalOffset: 1_024, reachedEOF: true,
                sha256: digest(0x11)
            ))
        default:
            return .completed
        }
    }

    private var waitClassification: InvestigationMachineGateWaitClassification {
        switch scenario {
        case .ordinaryExit: .exited(status: 0)
        case .signaledExit: .signaled(signal: SIGTERM)
        case .stopped: .stopped(signal: SIGTSTP)
        case .timeout: .signaled(signal: SIGKILL)
        case .outputFailure: .signaled(signal: SIGTERM)
        case .stoppedThenExitZero: .stopped(signal: SIGTSTP)
        }
    }
}

private func preparedBytes() throws -> Data {
    try InvestigationMachineGatePreparedFrame(
        gateProcessID: 41, coordinatorProcessID: 40, sessionID: 40,
        childProcessID: 52, recoveryProcessGroupID: 41,
        savedForegroundProcessGroupID: 40,
        childParentProcessID: 41,
        childSessionID: 40, childStartSeconds: 12,
        childStartMicroseconds: 34, initialStopStatus: 0x7f,
        outerAttemptUUID: UUID(
            uuidString: "10000000-0000-4000-8000-000000000001"
        )!,
        wholeInputSHA256: digest(0x11)
        , capsule: .init(
            device: 7, inode: 8, generation: 9, size: 1_024
        )
        , terminal: tty(foreground: 40)
        , absoluteDeadlineNanoseconds: 1_200_000_000_100
    ).encoded()
}

private func sampleReceipt(
    outputOverflow: Bool = true,
    outputEOF: Bool = true,
    forwardedSignal: Int32? = nil,
    waitClassification: InvestigationMachineGateWaitClassification =
        .exited(status: 0),
    terminationProgression: InvestigationMachineGateTerminationProgression =
        .natural,
    borrowedDescriptorOutcome: InvestigationMachineGateBorrowedDescriptorOutcome =
        .closed
) throws -> InvestigationMachineGateTransportReceipt {
    let attempt = try #require(
        UUID(uuidString: "10000000-0000-4000-8000-000000000001")
    )
    return try InvestigationMachineGateTransportReceipt(
        launcherExecutableSHA256: digest(0x01),
        outerAttemptUUID: attempt, wholeInputSHA256: digest(0x11),
        preparedFrameSHA256: .hashing(try preparedBytes()),
        capsule: .init(device: 7, inode: 8, generation: 9, size: 1_024),
        gateProcessID: 41, coordinatorProcessID: 40, sessionID: 40,
        recoveryProcessGroupID: 41,
        savedForegroundProcessGroupID: 40, childIdentity: childIdentity(),
        input: .init(
            node: .init(device: 7, inode: 8, generation: 9, size: 1_024),
            initialOffset: 0, finalOffset: 1_024, reachedEOF: true,
            sha256: digest(0x11)
        ),
        initialTerminal: tty(foreground: 40),
        childTerminal: tty(foreground: 41),
        finalTerminal: tty(foreground: 40),
        output: .init(
            byteCount: outputOverflow ? 512 : 4, sha256: digest(0x44),
            overflowObserved: outputOverflow, reachedEOF: outputEOF
        ),
        waitClassification: waitClassification,
        forwardedSignal: forwardedSignal, monotonicStartedNanoseconds: 100,
        monotonicCompletedNanoseconds: 200,
        terminationProgression: terminationProgression, childProcessGroupEmpty: true,
        exactChildReaped: true, savedForegroundProcessGroupRestored: true,
        borrowedDescriptorOutcome: borrowedDescriptorOutcome
    )
}

private func childIdentity() -> InvestigationMachineGateChildIdentity {
    .init(
        processID: 52, parentProcessID: 41, processGroupID: 41,
        sessionID: 40, startSeconds: 12, startMicroseconds: 34
    )
}

private func tty(
    foreground: pid_t
) -> InvestigationMachineGateTerminalObservation {
    .init(device: 9, inode: 10, foregroundProcessGroupID: foreground)
}

private func digest(_ byte: UInt8) -> InvestigationHandoffSHA256 {
    try! InvestigationHandoffSHA256(rawBytes: Data(repeating: byte, count: 32))
}

private func replacingFirst(_ data: Data, byte: UInt8) -> Data {
    guard !data.isEmpty else { return data }
    var copy = data
    copy[copy.startIndex] = byte
    return copy
}

private func index(
    of event: InvestigationMachineGateLauncherEvent,
    in events: [InvestigationMachineGateLauncherEvent]
) throws -> Int {
    try #require(events.firstIndex(of: event))
}
