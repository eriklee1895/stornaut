import Darwin
import Foundation
import Testing

@testable import StornautInvestigationMachineDriverSupport

@Suite("Investigation machine Darwin epoch retirement", .serialized)
struct InvestigationMachineDarwinEpochRetirementTests {
    @Test func naturalExitUsesWaitableProofReapsLastAndMintsOneProof() async throws {
        let processID: Int32 = 42
        let recorder = RetirementSystemRecorder(
            inventories: [.value(pidBytes([processID])), .value(Data())],
            waitIDs: [.value(processID)],
            waitPIDs: [.value(processID)]
        )
        let owner = InvestigationMachineDarwinEpochRetirementOwner(
            system: recorder.system()
        )

        _ = try await owner.retireOwnedProcessGroup(
            owned(processID: processID, descriptors: [11, 12])
        )

        let events = recorder.events
        #expect(events.filter(\.isSignal).isEmpty)
        #expect(events.filter { $0 == .close(11) }.count == 1)
        #expect(events.filter { $0 == .close(12) }.count == 1)
        #expect(
            events.contains(
                .inventory(
                    UInt32(PROC_PGRP_ONLY), processID,
                    InvestigationMachineDarwinEpochRetirementOwner
                        .maximumInventoryEntries
                )
            )
        )
        #expect(
            events.contains(
                .waitID(
                    processID, Int32(WEXITED | WNOHANG | WNOWAIT)
                )
            )
        )
        #expect(events.contains(.waitPID(processID, Int32(WNOHANG))))
        let reap = try eventIndex(
            .waitPID(processID, Int32(WNOHANG)), in: events
        )
        #expect(
            events[events.index(after: reap)...].contains { $0.isInventory }
        )
        #expect(try eventIndex(.waitID(processID, Int32(WEXITED | WNOHANG | WNOWAIT)), in: events)
            < eventIndex(.waitPID(processID, Int32(WNOHANG)), in: events))

        await expectFailure {
            try await owner.retireOwnedProcessGroup(owned(processID: processID))
        }
        #expect(recorder.events == events)
    }

    @Test func termDrainSignalsExactGroupAndNeverReapsBeforeDescendantsLeave() async throws {
        let processID: Int32 = 52
        let descendant: Int32 = 53
        let recorder = RetirementSystemRecorder(
            mode: .drainAfterTerm(processID: processID, descendant: descendant),
            waitPIDs: [.value(processID)]
        )
        let owner = InvestigationMachineDarwinEpochRetirementOwner(
            system: recorder.system()
        )

        _ = try await owner.retireOwnedProcessGroup(owned(processID: processID))

        let events = recorder.events
        #expect(events.filter(\.isSignal) == [.signal(-processID, SIGTERM)])
        let term = try eventIndex(.signal(-processID, SIGTERM), in: events)
        let reap = try eventIndex(.waitPID(processID, Int32(WNOHANG)), in: events)
        #expect(term < reap)
        #expect(
            events[..<reap].contains { event in
                event == .inventory(
                    UInt32(PROC_PGRP_ONLY), processID,
                    InvestigationMachineDarwinEpochRetirementOwner
                        .maximumInventoryEntries
                )
            }
        )
        #expect(recorder.inventorySnapshotsBeforeReap.contains([processID, descendant]))
        #expect(recorder.inventorySnapshotsBeforeReap.last == [processID])
    }

    @Test func termIgnoringDescendantEscalatesOnceToExactNegativeGroup() async throws {
        let processID: Int32 = 62
        let recorder = RetirementSystemRecorder(
            mode: .drainAfterKill(processID: processID, descendant: 63),
            waitPIDs: [.value(processID)]
        )
        let owner = InvestigationMachineDarwinEpochRetirementOwner(
            system: recorder.system()
        )

        _ = try await owner.retireOwnedProcessGroup(owned(processID: processID))

        #expect(
            recorder.events.filter(\.isSignal) == [
                .signal(-processID, SIGTERM),
                .signal(-processID, SIGKILL),
            ]
        )
        #expect(
            InvestigationMachineDarwinEpochRetirementOwner
                .totalWindowNanoseconds == 5_000_000_000
        )
        #expect(
            InvestigationMachineDarwinEpochRetirementOwner
                .termWindowNanoseconds == 1_000_000_000
        )
        let events = recorder.events
        let term = try eventIndex(.signal(-processID, SIGTERM), in: events)
        let kill = try eventIndex(.signal(-processID, SIGKILL), in: events)
        #expect(
            events[events.index(after: term)..<kill].contains {
                $0.isInventory
            }
        )
        #expect(
            events[events.index(after: term)..<kill].contains { $0.isWaitID }
        )
        #expect(recorder.clockValues.contains(1_100_000_000))
    }

    @Test func retirementUsesFreshFixedWindowAtAnyMonotonicOrigin() async throws {
        let processID: Int32 = 72
        let recorder = RetirementSystemRecorder(
            now: 9_000_000_000_000,
            inventories: [.value(pidBytes([processID])), .value(Data())],
            waitIDs: [.value(processID)],
            waitPIDs: [.value(processID)]
        )
        let owner = InvestigationMachineDarwinEpochRetirementOwner(
            system: recorder.system()
        )

        _ = try await owner.retireOwnedProcessGroup(owned(processID: processID))
        #expect(recorder.events.contains(.clock))
        #expect(recorder.events.contains(.waitPID(processID, Int32(WNOHANG))))
        #expect(recorder.events.filter(\.isSignal).isEmpty)
    }

    @Test func invalidOwnedAuthorityNeverInventoriesOrSignals() async {
        let currentGroup: Int32 = 700
        let invalidEpochs = [
            InvestigationMachineDarwinOwnedEpoch(
                processID: 1, processGroupID: 1, descriptors: [20]
            ),
            InvestigationMachineDarwinOwnedEpoch(
                processID: 701, processGroupID: 702, descriptors: [20]
            ),
            InvestigationMachineDarwinOwnedEpoch(
                processID: currentGroup, processGroupID: currentGroup,
                descriptors: [20]
            ),
        ]

        for epoch in invalidEpochs {
            let recorder = RetirementSystemRecorder(currentProcessGroup: currentGroup)
            let owner = InvestigationMachineDarwinEpochRetirementOwner(
                system: recorder.system()
            )
            await expectFailure { try await owner.retireOwnedProcessGroup(epoch) }
            #expect(recorder.events.filter(\.isInventory).isEmpty)
            #expect(recorder.events.filter(\.isSignal).isEmpty)
            #expect(recorder.events.filter { $0 == .close(20) }.count == 1)
        }
    }

    @Test func malformedOrUnavailableInventoryNeverBecomesEmptyProof() async {
        let processID: Int32 = 82
        let saturated = Array(Int32(2)...Int32(4_097))
        let cases: [Scripted<Data>] = [
            .value(pidBytes(saturated)),
            .value(Data([0x01, 0x02, 0x03])),
            .value(pidBytes([processID, processID])),
            .value(pidBytes([processID, 0])),
            .value(pidBytes([processID, -3])),
            .failure(EIO),
        ]

        for inventory in cases {
            let recorder = RetirementSystemRecorder(inventories: [inventory])
            let owner = InvestigationMachineDarwinEpochRetirementOwner(
                system: recorder.system()
            )
            await expectFailure {
                try await owner.retireOwnedProcessGroup(
                    owned(processID: processID)
                )
            }
            #expect(recorder.events.filter(\.isSignal).isEmpty)
            #expect(recorder.events.filter(\.isWaitPID).isEmpty)
        }
    }

    @Test func waitIDRetriesOnlyEINTRAndRequiresTheExactLeader() async throws {
        let processID: Int32 = 92
        let retry = RetirementSystemRecorder(
            inventories: [.value(pidBytes([processID])), .value(Data())],
            waitIDs: [.failure(EINTR), .value(processID)],
            waitPIDs: [.value(processID)]
        )
        _ = try await InvestigationMachineDarwinEpochRetirementOwner(
            system: retry.system()
        ).retireOwnedProcessGroup(owned(processID: processID))
        #expect(retry.events.filter(\.isWaitID).count == 2)

        let expiredRetry = RetirementSystemRecorder(
            expireAfterWaitID: true,
            inventories: [.value(pidBytes([processID]))],
            waitIDs: [.failure(EINTR)]
        )
        await expectFailure {
            try await InvestigationMachineDarwinEpochRetirementOwner(
                system: expiredRetry.system()
            ).retireOwnedProcessGroup(owned(processID: processID))
        }
        #expect(expiredRetry.events.filter(\.isWaitID).count == 1)

        for result in [
            Scripted<Int32?>.value(processID + 1),
            .failure(ECHILD),
            .failure(EIO),
        ] {
            let recorder = RetirementSystemRecorder(
                inventories: [.value(pidBytes([processID]))],
                waitIDs: [result]
            )
            await expectFailure {
                try await InvestigationMachineDarwinEpochRetirementOwner(
                    system: recorder.system()
                ).retireOwnedProcessGroup(owned(processID: processID))
            }
            #expect(recorder.events.filter(\.isInventory).count == 1)
            #expect(recorder.events.filter(\.isWaitID).count == 1)
            #expect(recorder.events.filter(\.isSignal).isEmpty)
            #expect(recorder.events.filter(\.isWaitPID).isEmpty)
        }
    }

    @Test func waitPIDRetriesOnlyEINTRAndRejectsZeroWrongPIDAndErrors() async throws {
        let processID: Int32 = 102
        let retry = RetirementSystemRecorder(
            inventories: [.value(pidBytes([processID])), .value(Data())],
            waitIDs: [.value(processID)],
            waitPIDs: [.failure(EINTR), .value(processID)]
        )
        _ = try await InvestigationMachineDarwinEpochRetirementOwner(
            system: retry.system()
        ).retireOwnedProcessGroup(owned(processID: processID))
        #expect(retry.events.filter(\.isWaitPID).count == 2)

        let expiredRetry = RetirementSystemRecorder(
            expireAfterNonReap: true,
            inventories: [.value(pidBytes([processID]))],
            waitIDs: [.value(processID)], waitPIDs: [.failure(EINTR)]
        )
        await expectFailure {
            try await InvestigationMachineDarwinEpochRetirementOwner(
                system: expiredRetry.system()
            ).retireOwnedProcessGroup(owned(processID: processID))
        }
        #expect(expiredRetry.events.filter(\.isWaitPID).count == 1)

        let failures: [Scripted<Int32?>] = [
            .value(0), .value(processID + 1), .failure(ECHILD), .failure(EIO),
        ]
        for result in failures {
            let recorder = RetirementSystemRecorder(
                expireAfterNonReap: true,
                inventories: [.value(pidBytes([processID]))],
                waitIDs: [.value(processID)], waitPIDs: [result]
            )
            await expectFailure {
                try await InvestigationMachineDarwinEpochRetirementOwner(
                    system: recorder.system()
                ).retireOwnedProcessGroup(owned(processID: processID))
            }
            #expect(recorder.events.filter(\.isWaitPID).count == 1)
        }
    }

    @Test func signalErrorsIncludingESRCHNeverMintProof() async {
        let processID: Int32 = 112
        for errorNumber in [ESRCH, EPERM, EIO] {
            let recorder = RetirementSystemRecorder(
                inventories: [
                    .value(pidBytes([processID, processID + 1])),
                    .value(pidBytes([processID])),
                    .value(Data()),
                ],
                waitIDs: [.value(nil), .value(processID)],
                signals: [.failure(errorNumber)],
                waitPIDs: [.value(processID)]
            )
            await expectFailure {
                try await InvestigationMachineDarwinEpochRetirementOwner(
                    system: recorder.system()
                ).retireOwnedProcessGroup(owned(processID: processID))
            }
            #expect(
                recorder.events.filter(\.isSignal)
                    == [.signal(-processID, SIGTERM)]
            )
            #expect(recorder.events.filter(\.isInventory).count == 1)
            #expect(recorder.events.filter(\.isWaitID).count == 1)
            #expect(recorder.events.filter(\.isWaitPID).isEmpty)
        }
    }

    @Test func postReapPGIDReuseWithholdsProofWithoutAnotherSignal() async {
        let processID: Int32 = 122
        let recorder = RetirementSystemRecorder(
            inventories: [
                .value(pidBytes([processID])),
                .value(pidBytes([777])),
            ],
            waitIDs: [.value(processID)], waitPIDs: [.value(processID)]
        )
        await expectFailure {
            try await InvestigationMachineDarwinEpochRetirementOwner(
                system: recorder.system()
            ).retireOwnedProcessGroup(owned(processID: processID))
        }
        #expect(recorder.events.filter(\.isSignal).isEmpty)
        #expect(recorder.events.filter(\.isInventory).count == 2)
    }

    @Test func descriptorFailureContinuesCleanupWithholdsProofAndNeverRetries() async {
        let processID: Int32 = 132
        let recorder = RetirementSystemRecorder(
            closeFailures: [31: EIO],
            inventories: [.value(pidBytes([processID])), .value(Data())],
            waitIDs: [.value(processID)], waitPIDs: [.value(processID)]
        )
        await expectFailure {
            try await InvestigationMachineDarwinEpochRetirementOwner(
                system: recorder.system()
            ).retireOwnedProcessGroup(
                owned(processID: processID, descriptors: [31, 32, 31])
            )
        }
        #expect(recorder.events.filter { $0 == .close(31) }.count == 1)
        #expect(recorder.events.filter { $0 == .close(32) }.count == 1)
        #expect(recorder.events.contains(.waitPID(processID, Int32(WNOHANG))))
        #expect(recorder.events.filter(\.isInventory).count == 2)
    }

    @Test func cancellationWaitsForBlockingWorkerBeforeReturning() async {
        let processID: Int32 = 142
        let gate = RetirementBlockingGate()
        let completion = RetirementCompletionFlag()
        let recorder = RetirementSystemRecorder(
            inventoryGate: gate,
            inventories: [.value(pidBytes([processID])), .value(Data())],
            waitIDs: [.value(processID)], waitPIDs: [.value(processID)]
        )
        let owner = InvestigationMachineDarwinEpochRetirementOwner(
            system: recorder.system()
        )
        let operation = Task {
            defer { completion.markCompleted() }
            return try await owner.retireOwnedProcessGroup(
                owned(processID: processID)
            )
        }
        #expect(gate.waitUntilEntered(timeout: .now() + 2) == .success)
        operation.cancel()
        try? await Task.sleep(for: .milliseconds(30))
        #expect(!completion.isCompleted)
        gate.release()
        await expectFailure { _ = try await operation.value }
        #expect(completion.isCompleted)
    }

    @Test func duplicateAndConcurrentRetirementAreOneShot() async {
        let processID: Int32 = 152
        let gate = RetirementBlockingGate()
        let recorder = RetirementSystemRecorder(
            inventoryGate: gate,
            inventories: [.value(pidBytes([processID])), .value(Data())],
            waitIDs: [.value(processID)], waitPIDs: [.value(processID)]
        )
        let owner = InvestigationMachineDarwinEpochRetirementOwner(
            system: recorder.system()
        )
        let first = Task {
            do {
                _ = try await owner.retireOwnedProcessGroup(
                    owned(processID: processID)
                )
                return true
            } catch { return false }
        }
        #expect(gate.waitUntilEntered(timeout: .now() + 2) == .success)
        let second = Task {
            do {
                _ = try await owner.retireOwnedProcessGroup(
                    owned(processID: processID)
                )
                return true
            } catch { return false }
        }
        gate.release()
        let results = await [first.value, second.value]
        #expect(results.filter { $0 }.count == 1)
        #expect(recorder.events.filter(\.isInventory).count == 2)
        await expectFailure {
            try await owner.retireOwnedProcessGroup(owned(processID: processID))
        }
        #expect(recorder.events.filter(\.isInventory).count == 2)
    }

    @Test func spawnedFallbackUsesPositivePIDOnlyAndCannotMintProof() async throws {
        let processID: Int32 = 162
        let recorder = RetirementSystemRecorder(
            waitIDs: [.value(nil), .value(processID)],
            waitPIDs: [.value(processID)]
        )
        let owner = InvestigationMachineDarwinEpochRetirementOwner(
            system: recorder.system()
        )

        let result: Void = try await owner.retireSpawnedProcess(
            .init(processID: processID, descriptors: [41])
        )
        _ = result

        #expect(recorder.events.filter(\.isInventory).isEmpty)
        #expect(recorder.events.filter(\.isSignal) == [.signal(processID, SIGKILL)])
        #expect(recorder.events.contains(.waitPID(processID, Int32(WNOHANG))))
    }

    @Test func successfulDirectChildExitWaitsWithoutSignalAndRequiresExitZero()
        async throws
    {
        let processID: Int32 = 172
        let recorder = RetirementSystemRecorder(
            waitIDs: [.value(nil), .value(processID)],
            waitPIDStatuses: [
                .value(.init(processID: processID, rawStatus: 0)),
            ]
        )
        let proof = try await InvestigationMachineDarwinEpochRetirementOwner(
            system: recorder.system()
        ).reapSuccessfulDirectChild(
            .init(processID: processID, descriptors: [42])
        )

        #expect(proof == .init())
        #expect(recorder.events.filter { $0.isSignal }.isEmpty)
        #expect(recorder.events.filter { $0.isInventory }.isEmpty)
        #expect(recorder.events.filter { $0.isWaitID }.count == 2)
        #expect(recorder.events.filter { $0.isWaitPIDStatus }.count == 1)
        #expect(recorder.events.filter { $0 == .close(42) }.count == 1)
    }

    @Test func successfulDirectChildExitRejectsNonzeroExitWithoutSignal()
        async
    {
        let processID: Int32 = 182
        let recorder = RetirementSystemRecorder(
            waitIDs: [.value(processID)],
            waitPIDStatuses: [
                .value(.init(processID: processID, rawStatus: 7 << 8)),
            ]
        )

        await expectFailure {
            try await InvestigationMachineDarwinEpochRetirementOwner(
                system: recorder.system()
            ).reapSuccessfulDirectChild(
                .init(processID: processID, descriptors: [43])
            )
        }
        #expect(recorder.events.filter { $0.isSignal }.isEmpty)
        #expect(recorder.events.filter { $0.isInventory }.isEmpty)
        #expect(recorder.events.filter { $0.isWaitPIDStatus }.count == 1)
    }

    @Test func successfulDirectChildExitTimesOutWithoutSignal() async {
        let processID: Int32 = 192
        let recorder = RetirementSystemRecorder(
            expireAfterWaitID: true,
            waitIDs: [.value(nil)]
        )

        await expectFailure {
            try await InvestigationMachineDarwinEpochRetirementOwner(
                system: recorder.system()
            ).reapSuccessfulDirectChild(
                .init(processID: processID, descriptors: [44])
            )
        }
        #expect(recorder.events.filter { $0.isSignal }.isEmpty)
        #expect(recorder.events.filter { $0.isInventory }.isEmpty)
        #expect(recorder.events.filter { $0.isWaitPIDStatus }.isEmpty)
    }

    @Test func physicalNaturalExitIsWaitableReapedAndLeavesNoGroup() async throws {
        let fixture = try PhysicalRetirementFixture.make(mode: .natural)
        defer { fixture.forceCleanup() }
        try fixture.awaitLeaderWaitable()

        _ = try await InvestigationMachineDarwinEpochRetirementOwner(
            system: .system
        ).retireOwnedProcessGroup(owned(processID: fixture.leader))

        #expect(fixture.leaderIsNoLongerAChild())
        #expect(fixture.groupIsAbsent())
    }

    @Test func physicalTermIgnoringDescendantIsKilledReapedLastAndLeavesNoGroup() async throws {
        let fixture = try PhysicalRetirementFixture.make(mode: .termIgnoring)
        defer { fixture.forceCleanup() }
        let descendant = try fixture.readDescendant()

        _ = try await InvestigationMachineDarwinEpochRetirementOwner(
            system: .system
        ).retireOwnedProcessGroup(owned(processID: fixture.leader))

        #expect(fixture.leaderIsNoLongerAChild())
        #expect(fixture.groupIsAbsent())
        #expect(try fixture.awaitProcessAbsent(descendant))
    }
}

private enum RetirementTestFailure: Error {
    case exhaustedScript
    case expectedEvent
    case fixtureFailed
}

private enum Scripted<Value> {
    case value(Value)
    case failure(Int32)
}

private enum RetirementSystemMode {
    case scripted
    case drainAfterTerm(processID: Int32, descendant: Int32)
    case drainAfterKill(processID: Int32, descendant: Int32)
}

private enum RetirementSystemEvent: Equatable {
    case currentProcessGroup
    case clock
    case close(Int32)
    case inventory(UInt32, Int32, Int)
    case waitID(Int32, Int32)
    case signal(Int32, Int32)
    case waitPID(Int32, Int32)
    case waitPIDStatus(Int32, Int32)
    case pause(UInt64)

    var isSignal: Bool { if case .signal = self { true } else { false } }
    var isInventory: Bool { if case .inventory = self { true } else { false } }
    var isWaitID: Bool { if case .waitID = self { true } else { false } }
    var isWaitPID: Bool { if case .waitPID = self { true } else { false } }
    var isWaitPIDStatus: Bool {
        if case .waitPIDStatus = self { true } else { false }
    }
}

private final class RetirementSystemRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let mode: RetirementSystemMode
    private let currentGroup: Int32
    private let closeFailures: [Int32: Int32]
    private let inventoryGate: RetirementBlockingGate?
    private let expireAfterWaitID: Bool
    private let expireAfterNonReap: Bool
    private var currentNanoseconds: UInt64
    private var inventoryScript: [Scripted<Data>]
    private var waitIDScript: [Scripted<Int32?>]
    private var signalScript: [Scripted<Void>]
    private var waitPIDScript: [Scripted<Int32?>]
    private var waitPIDStatusScript:
        [Scripted<InvestigationMachineDarwinWaitPIDStatus?>]
    private var recordedEvents: [RetirementSystemEvent] = []
    private var recordedInventoryBeforeReap: [[Int32]] = []
    private var recordedClockValues: [UInt64] = []

    init(
        mode: RetirementSystemMode = .scripted,
        currentProcessGroup: Int32 = 900,
        now: UInt64 = 0,
        closeFailures: [Int32: Int32] = [:],
        inventoryGate: RetirementBlockingGate? = nil,
        expireAfterWaitID: Bool = false,
        expireAfterNonReap: Bool = false,
        inventories: [Scripted<Data>] = [],
        waitIDs: [Scripted<Int32?>] = [],
        signals: [Scripted<Void>] = [],
        waitPIDs: [Scripted<Int32?>] = [],
        waitPIDStatuses:
            [Scripted<InvestigationMachineDarwinWaitPIDStatus?>] = []
    ) {
        self.mode = mode
        currentGroup = currentProcessGroup
        currentNanoseconds = now
        self.closeFailures = closeFailures
        self.inventoryGate = inventoryGate
        self.expireAfterWaitID = expireAfterWaitID
        self.expireAfterNonReap = expireAfterNonReap
        inventoryScript = inventories
        waitIDScript = waitIDs
        signalScript = signals
        waitPIDScript = waitPIDs
        waitPIDStatusScript = waitPIDStatuses
    }

    var events: [RetirementSystemEvent] {
        lock.withLock { recordedEvents }
    }

    var inventorySnapshotsBeforeReap: [[Int32]] {
        lock.withLock { recordedInventoryBeforeReap }
    }

    var clockValues: [UInt64] {
        lock.withLock { recordedClockValues }
    }

    func system() -> InvestigationMachineDarwinEpochRetirementSystem {
        .init(
            currentProcessGroup: { self.readCurrentGroup() },
            continuousNanoseconds: { try self.readClock() },
            closeDescriptor: { try self.closeDescriptor($0) },
            processGroupInventory: { try self.inventory($0, $1, $2) },
            waitID: { try self.waitID($0, $1) },
            sendSignal: { try self.sendSignal($0, $1) },
            waitPID: { try self.waitPID($0, $1) },
            waitPIDStatus: { try self.waitPIDStatus($0, $1) },
            pauseNanoseconds: { try self.pause($0) }
        )
    }

    private func readCurrentGroup() -> Int32 {
        lock.withLock {
            recordedEvents.append(.currentProcessGroup)
            return currentGroup
        }
    }

    private func readClock() throws -> UInt64 {
        lock.withLock {
            recordedEvents.append(.clock)
            if expireAfterWaitID, recordedEvents.contains(where: \.isWaitID) {
                currentNanoseconds = currentNanoseconds &+ 6_000_000_000
            } else if expireAfterNonReap,
                recordedEvents.contains(where: \.isWaitPID)
            {
                currentNanoseconds = currentNanoseconds &+ 6_000_000_000
            } else if case .drainAfterKill = mode,
                recordedEvents.contains(.signal(-mode.processID, SIGTERM)),
                !recordedEvents.contains(.signal(-mode.processID, SIGKILL))
            {
                currentNanoseconds = currentNanoseconds &+ 1_100_000_000
            }
            recordedClockValues.append(currentNanoseconds)
            return currentNanoseconds
        }
    }

    private func closeDescriptor(_ descriptor: Int32) throws {
        let failure = lock.withLock {
            recordedEvents.append(.close(descriptor))
            return closeFailures[descriptor]
        }
        if let failure { try throwPOSIX(failure) }
    }

    private func inventory(
        _ flavor: UInt32, _ processGroup: Int32, _ maximumEntries: Int
    ) throws -> Data {
        inventoryGate?.blockOnce()
        return try lock.withLock {
            recordedEvents.append(.inventory(flavor, processGroup, maximumEntries))
            let data: Data
            switch mode {
            case .scripted:
                data = try next(&inventoryScript)
            case let .drainAfterTerm(processID, descendant):
                if recordedEvents.contains(where: \.isWaitPID) {
                    data = Data()
                } else if recordedEvents.contains(.signal(-processID, SIGTERM)) {
                    data = pidBytes([processID])
                } else {
                    data = pidBytes([processID, descendant])
                }
            case let .drainAfterKill(processID, descendant):
                if recordedEvents.contains(where: \.isWaitPID) {
                    data = Data()
                } else if recordedEvents.contains(.signal(-processID, SIGKILL)) {
                    data = pidBytes([processID])
                } else {
                    data = pidBytes([processID, descendant])
                }
            }
            if !recordedEvents.contains(where: \.isWaitPID) {
                recordedInventoryBeforeReap.append(decodePIDs(data))
            }
            return data
        }
    }

    private func waitID(_ processID: Int32, _ options: Int32) throws -> Int32? {
        try lock.withLock {
            recordedEvents.append(.waitID(processID, options))
            switch mode {
            case .scripted: return try next(&waitIDScript)
            case let .drainAfterTerm(leader, _):
                return recordedEvents.contains(.signal(-leader, SIGTERM))
                    ? leader : nil
            case let .drainAfterKill(leader, _):
                return recordedEvents.contains(.signal(-leader, SIGKILL))
                    ? leader : nil
            }
        }
    }

    private func sendSignal(_ target: Int32, _ signal: Int32) throws {
        try lock.withLock {
            recordedEvents.append(.signal(target, signal))
            if !signalScript.isEmpty { _ = try next(&signalScript) }
        }
    }

    private func waitPID(_ processID: Int32, _ options: Int32) throws -> Int32? {
        try lock.withLock {
            recordedEvents.append(.waitPID(processID, options))
            return try next(&waitPIDScript)
        }
    }

    private func waitPIDStatus(
        _ processID: Int32, _ options: Int32
    ) throws -> InvestigationMachineDarwinWaitPIDStatus? {
        try lock.withLock {
            recordedEvents.append(.waitPIDStatus(processID, options))
            return try next(&waitPIDStatusScript)
        }
    }

    private func pause(_ nanoseconds: UInt64) throws {
        lock.withLock {
            recordedEvents.append(.pause(nanoseconds))
            currentNanoseconds = currentNanoseconds &+ nanoseconds
        }
    }

    private func next<Value>(_ values: inout [Scripted<Value>]) throws -> Value {
        guard !values.isEmpty else { throw RetirementTestFailure.exhaustedScript }
        switch values.removeFirst() {
        case let .value(value): return value
        case let .failure(errorNumber): try throwPOSIX(errorNumber)
        }
    }
}

private extension RetirementSystemMode {
    var processID: Int32 {
        switch self {
        case .scripted: 0
        case let .drainAfterTerm(processID, _): processID
        case let .drainAfterKill(processID, _): processID
        }
    }
}

private final class RetirementBlockingGate: @unchecked Sendable {
    private let entered = DispatchSemaphore(value: 0)
    private let mayReturn = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var didBlock = false

    func blockOnce() {
        let shouldBlock = lock.withLock {
            if didBlock { return false }
            didBlock = true
            return true
        }
        guard shouldBlock else { return }
        entered.signal()
        mayReturn.wait()
    }

    func waitUntilEntered(timeout: DispatchTime) -> DispatchTimeoutResult {
        entered.wait(timeout: timeout)
    }

    func release() { mayReturn.signal() }
}

private final class RetirementCompletionFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    var isCompleted: Bool { lock.withLock { completed } }
    func markCompleted() { lock.withLock { completed = true } }
}

private enum PhysicalRetirementMode: String {
    case natural
    case termIgnoring = "term-ignoring"
}

private final class PhysicalRetirementFixture {
    let directory: URL
    let leader: Int32
    private let readDescriptor: Int32
    private var reportedDescendant: Int32?

    private init(directory: URL, leader: Int32, readDescriptor: Int32) {
        self.directory = directory
        self.leader = leader
        self.readDescriptor = readDescriptor
    }

    static func make(mode: PhysicalRetirementMode) throws -> PhysicalRetirementFixture {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "stornaut-iib5biid-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: false
        )
        var directoryTransferred = false
        defer {
            if !directoryTransferred {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let source = directory.appending(path: "retirement.c")
        let executable = directory.appending(path: "retirement")
        try Data(physicalFixtureSource.utf8).write(
            to: source, options: .withoutOverwriting
        )
        try compilePhysicalFixture(source: source, executable: executable)

        var pipeDescriptors: [Int32] = [-1, -1]
        guard pipe(&pipeDescriptors) == 0 else {
            throw RetirementTestFailure.fixtureFailed
        }
        var readDescriptorTransferred = false
        var writeDescriptorOpen = true
        defer {
            if !readDescriptorTransferred { close(pipeDescriptors[0]) }
            if writeDescriptorOpen { close(pipeDescriptors[1]) }
        }
        var actions: posix_spawn_file_actions_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else {
            throw RetirementTestFailure.fixtureFailed
        }
        defer { posix_spawn_file_actions_destroy(&actions) }
        guard posix_spawn_file_actions_addclose(&actions, pipeDescriptors[0]) == 0
        else {
            throw RetirementTestFailure.fixtureFailed
        }
        var attributes: posix_spawnattr_t?
        guard posix_spawnattr_init(&attributes) == 0 else {
            throw RetirementTestFailure.fixtureFailed
        }
        defer { posix_spawnattr_destroy(&attributes) }
        guard
            posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP)) == 0,
            posix_spawnattr_setpgroup(&attributes, 0) == 0
        else {
            throw RetirementTestFailure.fixtureFailed
        }
        var processID: pid_t = 0
        let status = try withCStringArray([
            executable.path, mode.rawValue, String(pipeDescriptors[1]),
        ]) { arguments in
            try withCStringArray([]) { environment in
                executable.path.withCString { path in
                    posix_spawn(
                        &processID, path, &actions, &attributes, arguments,
                        environment
                    )
                }
            }
        }
        close(pipeDescriptors[1])
        writeDescriptorOpen = false
        let observedProcessGroup = processID > 1 ? getpgid(processID) : -1
        guard
            status == 0, processID > 1, observedProcessGroup == processID
        else {
            if processID > 1 {
                if observedProcessGroup == processID {
                    _ = kill(-processID, SIGKILL)
                }
                _ = kill(processID, SIGKILL)
                let deadline = Date().addingTimeInterval(2)
                while Date() < deadline {
                    errno = 0
                    let result = waitpid(processID, nil, WNOHANG)
                    if result == processID
                        || result == -1 && errno == ECHILD
                    {
                        break
                    }
                    if result == -1, errno != EINTR { break }
                    usleep(10_000)
                }
            }
            throw RetirementTestFailure.fixtureFailed
        }
        let fixture = PhysicalRetirementFixture(
            directory: directory, leader: processID,
            readDescriptor: pipeDescriptors[0]
        )
        readDescriptorTransferred = true
        directoryTransferred = true
        return fixture
    }

    func awaitLeaderWaitable() throws {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            var information = siginfo_t()
            if waitid(P_PID, UInt32(leader), &information, WEXITED | WNOHANG | WNOWAIT) == 0,
                information.si_pid == leader
            {
                return
            }
            usleep(10_000)
        }
        throw RetirementTestFailure.fixtureFailed
    }

    func readDescendant() throws -> Int32 {
        var descriptor = pollfd(fd: readDescriptor, events: Int16(POLLIN), revents: 0)
        guard poll(&descriptor, 1, 2_000) == 1 else {
            throw RetirementTestFailure.fixtureFailed
        }
        var processID: Int32 = 0
        guard read(readDescriptor, &processID, MemoryLayout.size(ofValue: processID))
            == MemoryLayout.size(ofValue: processID), processID > 1
        else {
            throw RetirementTestFailure.fixtureFailed
        }
        reportedDescendant = processID
        return processID
    }

    func leaderIsNoLongerAChild() -> Bool {
        var status: Int32 = 0
        errno = 0
        return waitpid(leader, &status, WNOHANG) == -1 && errno == ECHILD
    }

    func groupIsAbsent() -> Bool {
        errno = 0
        return kill(-leader, 0) == -1 && errno == ESRCH
    }

    func awaitProcessAbsent(_ processID: Int32) throws -> Bool {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            errno = 0
            if kill(processID, 0) == -1, errno == ESRCH { return true }
            usleep(10_000)
        }
        return false
    }

    func forceCleanup() {
        close(readDescriptor)
        var leaderStillOwned = false
        while true {
            errno = 0
            let firstWait = waitpid(leader, nil, WNOHANG)
            if firstWait == 0 {
                leaderStillOwned = true
                break
            }
            if firstWait == leader || firstWait == -1 && errno == ECHILD {
                break
            }
            if firstWait == -1, errno == EINTR { continue }
            break
        }
        if leaderStillOwned, getpgid(leader) == leader {
            _ = kill(-leader, SIGKILL)
            _ = kill(leader, SIGKILL)
        }
        if let reportedDescendant, getpgid(reportedDescendant) == leader {
            _ = kill(reportedDescendant, SIGKILL)
        }
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            errno = 0
            let result = waitpid(leader, nil, WNOHANG)
            if result == leader || result == -1 && errno == ECHILD { break }
            if result == -1, errno != EINTR { break }
            usleep(10_000)
        }
        try? FileManager.default.removeItem(at: directory)
    }
}

private let physicalFixtureSource = #"""
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
  if (argc != 3) return 40;
  if (strcmp(argv[1], "natural") == 0) {
    usleep(100000);
    return 0;
  }
  if (strcmp(argv[1], "term-ignoring") != 0) return 41;
  int report_fd = atoi(argv[2]);
  if (signal(SIGTERM, SIG_IGN) == SIG_ERR) return 42;
  alarm(10);
  pid_t child = fork();
  if (child < 0) return 43;
  if (child == 0) {
    alarm(10);
    for (;;) pause();
  }
  if (write(report_fd, &child, sizeof(child)) != sizeof(child)) return 44;
  for (;;) pause();
}
"""#

private func compilePhysicalFixture(source: URL, executable: URL) throws {
    let compiler = Process()
    compiler.executableURL = URL(filePath: "/usr/bin/xcrun")
    compiler.arguments = [
        "clang", "-std=c11", "-Wall", "-Wextra", "-Werror",
        source.path, "-o", executable.path,
    ]
    compiler.standardOutput = FileHandle.nullDevice
    compiler.standardError = FileHandle.nullDevice
    try compiler.run()
    compiler.waitUntilExit()
    guard compiler.terminationStatus == 0 else {
        throw RetirementTestFailure.fixtureFailed
    }
}

private func withCStringArray<Result>(
    _ strings: [String],
    body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> Result
) throws -> Result {
    var storage: [UnsafeMutablePointer<CChar>?] = strings.map { strdup($0) }
    guard storage.allSatisfy({ $0 != nil }) else {
        storage.compactMap { $0 }.forEach { free($0) }
        throw RetirementTestFailure.fixtureFailed
    }
    defer { storage.compactMap { $0 }.forEach { free($0) } }
    storage.append(nil)
    return try storage.withUnsafeMutableBufferPointer { buffer in
        try body(buffer.baseAddress!)
    }
}

private func owned(
    processID: Int32, descriptors: [Int32] = []
) -> InvestigationMachineDarwinOwnedEpoch {
    .init(
        processID: processID, processGroupID: processID,
        descriptors: descriptors
    )
}

private func pidBytes(_ processIDs: [Int32]) -> Data {
    processIDs.withUnsafeBytes { Data($0) }
}

private func decodePIDs(_ data: Data) -> [Int32] {
    guard data.count.isMultiple(of: MemoryLayout<Int32>.size) else { return [] }
    return data.withUnsafeBytes { bytes in
        stride(from: 0, to: data.count, by: MemoryLayout<Int32>.size).map {
            bytes.loadUnaligned(fromByteOffset: $0, as: Int32.self)
        }
    }
}

private func throwPOSIX(_ errorNumber: Int32) throws -> Never {
    guard let code = POSIXErrorCode(rawValue: errorNumber) else {
        throw RetirementTestFailure.fixtureFailed
    }
    throw POSIXError(code)
}

private func eventIndex(
    _ event: RetirementSystemEvent, in events: [RetirementSystemEvent]
) throws -> Int {
    guard let index = events.firstIndex(of: event) else {
        throw RetirementTestFailure.expectedEvent
    }
    return index
}

private func expectFailure<Value>(
    _ operation: () async throws -> Value
) async {
    do {
        _ = try await operation()
        Issue.record("expected retirement uncertainty")
    } catch RetirementTestFailure.exhaustedScript {
        Issue.record("test double script was unexpectedly exhausted")
    } catch {}
}
