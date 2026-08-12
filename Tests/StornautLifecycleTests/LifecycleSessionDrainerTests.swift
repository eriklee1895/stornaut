import Darwin
import Foundation
import Testing
@testable import StornautLifecycle

@Suite("Lifecycle audit-session drainer")
struct LifecycleSessionDrainerTests {
    @Test
    func freezesNewMembersToAFixedPointBeforeKilling() throws {
        let parent = identity(pid: 101, pidVersion: 1)
        let escaped = identity(pid: 102, pidVersion: 1)
        let inventory = ScriptedLifecycleInventory([
            [parent],
            [parent, escaped],
            [parent, escaped],
            [],
        ])
        let signaler = RecordingLifecycleSignaler()
        let drainer = LifecycleSessionDrainer(
            inventory: inventory,
            signaler: signaler
        )

        let report = try drainer.drain(
            auditSessionID: 44_001,
            expectedUserID: 501,
            supervisorIdentity: nil
        )

        #expect(report.freezePasses == 3)
        #expect(report.killPasses == 1)
        #expect(report.uniqueMemberCount == 2)
        #expect(report.outcome == .drained)
        #expect(signaler.calls == [
            .init(signal: .stop, identity: parent),
            .init(signal: .stop, identity: escaped),
            .init(signal: .kill, identity: parent),
            .init(signal: .kill, identity: escaped),
        ])
    }

    @Test
    func keepsPidReusesDistinctAndSignalsTheFullIdentity() throws {
        let original = identity(pid: 212, pidVersion: 9)
        let reused = identity(pid: 212, pidVersion: 10)
        let inventory = ScriptedLifecycleInventory([
            [original],
            [original, reused],
            [original, reused],
            [],
        ])
        let signaler = RecordingLifecycleSignaler()

        _ = try LifecycleSessionDrainer(
            inventory: inventory,
            signaler: signaler
        ).drain(
            auditSessionID: 44_001,
            expectedUserID: 501,
            supervisorIdentity: nil
        )

        #expect(original != reused)
        #expect(signaler.calls == [
            .init(signal: .stop, identity: original),
            .init(signal: .stop, identity: reused),
            .init(signal: .kill, identity: original),
            .init(signal: .kill, identity: reused),
        ])
    }

    @Test
    func acceptsIdentityCheckedNoSuchProcessDuringKill() throws {
        let process = identity(pid: 301, pidVersion: 2)
        let inventory = ScriptedLifecycleInventory([
            [process],
            [process],
            [],
        ])
        let signaler = RecordingLifecycleSignaler(
            results: [
                .init(signal: .kill, identity: process): .noSuchProcess,
            ]
        )

        let report = try LifecycleSessionDrainer(
            inventory: inventory,
            signaler: signaler
        ).drain(
            auditSessionID: 44_001,
            expectedUserID: 501,
            supervisorIdentity: nil
        )

        #expect(report.outcome == .drained)
        #expect(signaler.calls.last == .init(
            signal: .kill,
            identity: process
        ))
    }

    @Test
    func processVanishingBeforeFreezeIsNotAddedToKillSet() throws {
        let process = identity(pid: 302, pidVersion: 2)
        let inventory = ScriptedLifecycleInventory([
            [process],
            [],
        ])
        let signaler = RecordingLifecycleSignaler(
            results: [
                .init(signal: .stop, identity: process): .noSuchProcess,
            ]
        )

        let report = try LifecycleSessionDrainer(
            inventory: inventory,
            signaler: signaler
        ).drain(
            auditSessionID: 44_001,
            expectedUserID: 501,
            supervisorIdentity: nil
        )

        #expect(report.uniqueMemberCount == 0)
        #expect(report.killPasses == 0)
        #expect(signaler.calls == [
            .init(signal: .stop, identity: process),
        ])
    }

    @Test
    func refusesAnInvalidAuditSession() {
        let inventory = ScriptedLifecycleInventory([])
        let signaler = RecordingLifecycleSignaler()

        #expect(throws: LifecycleDrainError.unsafeAuditSession) {
            _ = try LifecycleSessionDrainer(
                inventory: inventory,
                signaler: signaler
            ).drain(
                auditSessionID: 0,
                expectedUserID: 501,
                supervisorIdentity: nil
            )
        }
        #expect(inventory.requestedAuditSessionIDs.isEmpty)
        #expect(signaler.calls.isEmpty)
    }

    @Test
    func liveCancellationProtectsOnlyTheExactSupervisorIdentity() throws {
        let supervisor = identity(
            pid: 701,
            pidVersion: 3,
            effectiveUserID: 0
        )
        let child = identity(pid: 702, pidVersion: 1)
        let inventory = ScriptedLifecycleInventory([
            [supervisor, child],
            [supervisor, child],
            [supervisor],
        ])
        let signaler = RecordingLifecycleSignaler()

        let report = try LifecycleSessionDrainer(
            inventory: inventory,
            signaler: signaler
        ).drain(
            auditSessionID: 44_001,
            expectedUserID: 501,
            supervisorIdentity: supervisor
        )

        #expect(report.uniqueMemberCount == 1)
        #expect(signaler.calls == [
            .init(signal: .stop, identity: child),
            .init(signal: .kill, identity: child),
        ])
        #expect(!signaler.calls.contains(where: {
            $0.identity == supervisor
        }))
    }

    @Test
    func liveCancellationRejectsAnotherRootMember() {
        let supervisor = identity(
            pid: 710,
            pidVersion: 1,
            effectiveUserID: 0
        )
        let unexpectedRoot = identity(
            pid: 711,
            pidVersion: 1,
            effectiveUserID: 0
        )
        let child = identity(pid: 712, pidVersion: 1)
        let inventory = ScriptedLifecycleInventory([
            [supervisor, unexpectedRoot, child],
        ])
        let signaler = RecordingLifecycleSignaler()

        #expect(throws: LifecycleDrainError.identityMismatch) {
            _ = try LifecycleSessionDrainer(
                inventory: inventory,
                signaler: signaler
            ).drain(
                auditSessionID: 44_001,
                expectedUserID: 501,
                supervisorIdentity: supervisor
            )
        }
        #expect(signaler.calls.isEmpty)
    }

    @Test
    func liveCancellationRejectsAProtectedIdentityNotInTheSession() {
        let supervisor = identity(
            pid: 703,
            pidVersion: 1,
            auditSessionID: 44_002
        )
        let inventory = ScriptedLifecycleInventory([[]])
        let signaler = RecordingLifecycleSignaler()

        #expect(throws: LifecycleDrainError.unsafeAuditSession) {
            _ = try LifecycleSessionDrainer(
                inventory: inventory,
                signaler: signaler
            ).drain(
                auditSessionID: 44_001,
                expectedUserID: 501,
                supervisorIdentity: supervisor
            )
        }
        #expect(signaler.calls.isEmpty)
    }

    @Test
    func rejectsInventoryReturningAnotherAuditSession() {
        let unrelated = identity(
            pid: 401,
            pidVersion: 1,
            auditSessionID: 77_777
        )
        let inventory = ScriptedLifecycleInventory([[unrelated]])
        let signaler = RecordingLifecycleSignaler()

        #expect(throws: LifecycleDrainError.identityMismatch) {
            _ = try LifecycleSessionDrainer(
                inventory: inventory,
                signaler: signaler
            ).drain(
                auditSessionID: 44_001,
                expectedUserID: 501,
                supervisorIdentity: nil
            )
        }
        #expect(signaler.calls.isEmpty)
    }

    @Test
    func rejectsUnexpectedUserIdentity() {
        let rootProcess = identity(
            pid: 402,
            pidVersion: 1,
            effectiveUserID: 0
        )
        let inventory = ScriptedLifecycleInventory([[rootProcess]])
        let signaler = RecordingLifecycleSignaler()

        #expect(throws: LifecycleDrainError.identityMismatch) {
            _ = try LifecycleSessionDrainer(
                inventory: inventory,
                signaler: signaler
            ).drain(
                auditSessionID: 44_001,
                expectedUserID: 501,
                supervisorIdentity: nil
            )
        }
        #expect(signaler.calls.isEmpty)
    }

    @Test
    func forkStormFailsClosedAtTheFreezeBound() {
        let first = identity(pid: 501, pidVersion: 1)
        let second = identity(pid: 502, pidVersion: 1)
        let third = identity(pid: 503, pidVersion: 1)
        let inventory = ScriptedLifecycleInventory([
            [first],
            [first, second],
            [first, second, third],
        ])
        let signaler = RecordingLifecycleSignaler()
        let policy = LifecycleDrainPolicy(
            maximumFreezePasses: 2,
            maximumKillPasses: 2,
            maximumMembers: 8
        )

        #expect(throws: LifecycleDrainError.freezeDidNotConverge) {
            _ = try LifecycleSessionDrainer(
                inventory: inventory,
                signaler: signaler,
                policy: policy
            ).drain(
                auditSessionID: 44_001,
                expectedUserID: 501,
                supervisorIdentity: nil
            )
        }
        #expect(!signaler.calls.contains(where: { $0.signal == .kill }))
    }

    @Test
    func memberBoundFailsBeforeSignallingTheOverflow() {
        let first = identity(pid: 601, pidVersion: 1)
        let second = identity(pid: 602, pidVersion: 1)
        let inventory = ScriptedLifecycleInventory([[first, second]])
        let signaler = RecordingLifecycleSignaler()
        let policy = LifecycleDrainPolicy(
            maximumFreezePasses: 2,
            maximumKillPasses: 2,
            maximumMembers: 1
        )

        #expect(throws: LifecycleDrainError.memberLimitExceeded) {
            _ = try LifecycleSessionDrainer(
                inventory: inventory,
                signaler: signaler,
                policy: policy
            ).drain(
                auditSessionID: 44_001,
                expectedUserID: 501,
                supervisorIdentity: nil
            )
        }
        #expect(signaler.calls.isEmpty)
    }

    @Test
    func auditTokenRequiresTheCompleteKernelWordCount() {
        #expect(throws: LifecycleAuditTokenError.invalidWordCount) {
            _ = try LifecycleAuditToken(words: [1, 2, 3])
        }
        #expect(throws: Never.self) {
            _ = try LifecycleAuditToken(
                words: [1, 2, 3, 4, 5, 6, 7, 8]
            )
        }
    }
}

private func identity(
    pid: pid_t,
    pidVersion: Int32,
    auditSessionID: Int32 = 44_001,
    effectiveUserID: uid_t = 501
) -> LifecycleProcessIdentity {
    let words = [
        UInt32(effectiveUserID),
        UInt32(effectiveUserID),
        UInt32(effectiveUserID),
        UInt32(effectiveUserID),
        UInt32(bitPattern: pid),
        UInt32(bitPattern: auditSessionID),
        UInt32(bitPattern: pidVersion),
        0,
    ]
    return LifecycleProcessIdentity(
        processID: pid,
        processIDVersion: pidVersion,
        auditSessionID: auditSessionID,
        effectiveUserID: effectiveUserID,
        auditToken: try! LifecycleAuditToken(words: words)
    )
}

private final class ScriptedLifecycleInventory:
    LifecycleProcessInventory,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var snapshots: [[LifecycleProcessIdentity]]
    private(set) var requestedAuditSessionIDs: [Int32] = []

    init(_ snapshots: [[LifecycleProcessIdentity]]) {
        self.snapshots = snapshots
    }

    func processes(
        in auditSessionID: Int32
    ) throws -> [LifecycleProcessIdentity] {
        lock.withLock {
            requestedAuditSessionIDs.append(auditSessionID)
            guard !snapshots.isEmpty else {
                return []
            }
            return snapshots.removeFirst()
        }
    }
}

private final class RecordingLifecycleSignaler:
    LifecycleIdentitySignaling,
    @unchecked Sendable
{
    struct Call: Hashable {
        let signal: LifecycleSignal
        let identity: LifecycleProcessIdentity
    }

    private let lock = NSLock()
    private let results: [Call: LifecycleSignalResult]
    private(set) var calls: [Call] = []

    init(results: [Call: LifecycleSignalResult] = [:]) {
        self.results = results
    }

    func send(
        _ signal: LifecycleSignal,
        to identity: LifecycleProcessIdentity
    ) throws -> LifecycleSignalResult {
        lock.withLock {
            let call = Call(signal: signal, identity: identity)
            calls.append(call)
            return results[call] ?? .sent
        }
    }
}
