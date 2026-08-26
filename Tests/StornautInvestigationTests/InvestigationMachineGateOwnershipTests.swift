import Darwin
import Foundation
import Testing

@testable import StornautInvestigationMachineLaunchSupport

@Suite("Investigation machine gate ownership", .serialized)
struct InvestigationMachineGateOwnershipTests {
    @Test
    func acquireFreshOwnerWalksFromRootAndValidatesExactContract() throws {
        let system = ScriptedGateOwnershipSystem()
        let owner = try InvestigationMachineGateOwnershipAcquirer(
            system: system
        ).acquire()

        #expect(system.identityBufferByteCounts == [1_024])
        #expect(system.createCalls == [
            ModeCall(role: .caches, name: fixedBaseName, mode: 0o700),
        ])
        #expect(system.openCalls == expectedFreshOpenCalls)
        #expect(system.permissionCalls == [
            ModeCall(role: .lock, name: fixedLockName, mode: 0o600),
        ])
        #expect(system.lockDescriptors.count == 1)
        #expect(system.roles(for: system.lockDescriptors) == [.lock])
        #expect(system.namedCalls == [
            NamedCall(
                parentRole: .root, name: fixedBaseRelativePath,
                flags: baseNamedFlags),
            NamedCall(
                parentRole: .base, name: fixedLockName,
                flags: lockNamedFlags),
            NamedCall(
                parentRole: .root, name: fixedBaseRelativePath,
                flags: baseNamedFlags),
            NamedCall(
                parentRole: .base, name: fixedLockName,
                flags: lockNamedFlags),
        ])
        #expect(system.roles(for: system.metadataDescriptors) == [
            .root, .users, .home, .library, .caches, .base, .lock, .base, .lock,
        ])
        let descriptorStateRoles: [GateRole] = [
            .root, .users, .home, .library, .caches, .base, .lock, .base, .lock,
        ]
        #expect(system.roles(for: system.descriptorFlagDescriptors)
            == descriptorStateRoles)
        #expect(system.roles(for: system.statusFlagDescriptors)
            == descriptorStateRoles)
        #expect(system.roles(for: system.aclDescriptors) == [
            .base, .lock, .base, .lock,
        ])
        #expect(system.roles(for: system.xattrDescriptors) == [
            .base, .lock, .base, .lock,
        ])
        #expect(system.closeRoles == [
            .base, .caches, .library, .home, .users, .root,
        ])
        #expect(system.closeRoles.filter { $0 == .lock }.isEmpty)

        try owner.release()
        #expect(system.closeRoles.filter { $0 == .lock }.count == 1)
        #expect(system.everyOpenedDescriptorHasExactlyOneCloseAttempt)
    }

    @Test
    func acquireExistingOwnerReopensWithoutRepair() throws {
        let system = ScriptedGateOwnershipSystem(
            existingBase: true,
            existingLock: true
        )
        let owner = try InvestigationMachineGateOwnershipAcquirer(
            system: system
        ).acquire()

        let baseCalls = system.openCalls.filter { $0.name == fixedBaseName }
        let lockCalls = system.openCalls.filter { $0.name == fixedLockName }
        #expect(system.createCalls == [
            ModeCall(role: .caches, name: fixedBaseName, mode: 0o700),
        ])
        #expect(baseCalls == [
            OpenCall(
                parentRole: .caches,
                name: fixedBaseName,
                flags: directoryChildFlags,
                mode: nil
            ),
        ])
        #expect(system.permissionCalls.isEmpty)
        #expect(lockCalls == [
            OpenCall(
                parentRole: .base,
                name: fixedLockName,
                flags: lockOpenFlags | O_CREAT | O_EXCL,
                mode: 0o600
            ),
            OpenCall(
                parentRole: .base,
                name: fixedLockName,
                flags: lockOpenFlags,
                mode: nil
            ),
        ])
        try owner.release()
        #expect(system.everyOpenedDescriptorHasExactlyOneCloseAttempt)

        let invalid = ScriptedGateOwnershipSystem(
            existingBase: true, existingLock: true, lockPermissions: 0o400)
        #expect(throws: InvestigationMachineGateOwnershipError.ownershipUncertain) {
            _ = try InvestigationMachineGateOwnershipAcquirer(system: invalid)
                .acquire()
        }
        #expect(invalid.permissionCalls.isEmpty)
        #expect(invalid.lockDescriptors.isEmpty)
    }

    @Test
    func identityResolutionUsesTheExactBoundedCapacitySequence() throws {
        let eventuallyResolved = ScriptedGateOwnershipSystem(
            identityOutcomes: Array(
                repeating: .failure(ERANGE),
                count: identityBufferCapacities.count - 1
            ) + [.success(validIdentity)]
        )
        let owner = try InvestigationMachineGateOwnershipAcquirer(
            system: eventuallyResolved
        ).acquire()
        #expect(
            eventuallyResolved.identityBufferByteCounts
                == identityBufferCapacities
        )
        try owner.release()

        let exhausted = ScriptedGateOwnershipSystem(
            identityOutcomes: Array(
                repeating: .failure(ERANGE),
                count: identityBufferCapacities.count
            )
        )
        #expect(throws: InvestigationMachineGateOwnershipError.identityUnavailable) {
            _ = try InvestigationMachineGateOwnershipAcquirer(
                system: exhausted
            ).acquire()
        }
        #expect(exhausted.identityBufferByteCounts == identityBufferCapacities)
        #expect(exhausted.openCalls.isEmpty)

        for errorCode in [EINTR, EIO, ENOENT, EWOULDBLOCK, EAGAIN] {
            let failed = ScriptedGateOwnershipSystem(
                identityOutcomes: [.failure(errorCode)]
            )
            #expect(
                throws: InvestigationMachineGateOwnershipError
                    .identityUnavailable
            ) {
                _ = try InvestigationMachineGateOwnershipAcquirer(
                    system: failed
                ).acquire()
            }
            #expect(failed.identityBufferByteCounts == [1_024])
            #expect(failed.openCalls.isEmpty)
            #expect(failed.lockDescriptors.isEmpty)
        }
    }

    @Test(arguments: IdentityMutation.allCases)
    private func identityAndCanonicalHomeDriftFailClosed(
        _ mutation: IdentityMutation
    ) {
        let system = ScriptedGateOwnershipSystem(
            identityOutcomes: [.success(mutation.apply(to: validIdentity))]
        )

        #expect(throws: InvestigationMachineGateOwnershipError.identityUnavailable) {
            _ = try InvestigationMachineGateOwnershipAcquirer(
                system: system
            ).acquire()
        }
        #expect(system.identityBufferByteCounts == [1_024])
        #expect(system.openCalls.isEmpty)
        #expect(system.closeDescriptors.isEmpty)
        #expect(system.lockDescriptors.isEmpty)
    }

    @Test(arguments: DescriptorDrift.allCases)
    private func componentAndDescriptorDriftFailClosed(
        _ drift: DescriptorDrift
    ) {
        let system = ScriptedGateOwnershipSystem()
        drift.apply(to: system)

        #expect(throws: InvestigationMachineGateOwnershipError.ownershipUncertain) {
            _ = try InvestigationMachineGateOwnershipAcquirer(
                system: system
            ).acquire()
        }
        #expect(system.everySuccessfullyOpenedDescriptorWasClosedOnce)
    }

    @Test(arguments: MetadataDrift.allCases)
    private func metadataACLAndXattrDriftFailClosed(_ drift: MetadataDrift) {
        let system = ScriptedGateOwnershipSystem()
        drift.apply(to: system)

        #expect(throws: InvestigationMachineGateOwnershipError.ownershipUncertain) {
            _ = try InvestigationMachineGateOwnershipAcquirer(
                system: system
            ).acquire()
        }
        #expect(system.everySuccessfullyOpenedDescriptorWasClosedOnce)
    }

    @Test(arguments: NamedReplacement.allCases)
    private func namedIdentityReplacementBeforeOrAfterLockFailsClosed(
        _ replacement: NamedReplacement
    ) {
        let system = ScriptedGateOwnershipSystem()
        replacement.apply(to: system)

        #expect(throws: InvestigationMachineGateOwnershipError.ownershipUncertain) {
            _ = try InvestigationMachineGateOwnershipAcquirer(
                system: system
            ).acquire()
        }
        #expect(system.everySuccessfullyOpenedDescriptorWasClosedOnce)
        switch replacement {
        case .baseBeforeLock, .lockBeforeLock:
            #expect(system.lockDescriptors.isEmpty)
        case .baseAfterLock, .lockAfterLock:
            #expect(system.lockDescriptors.count == 1)
        }
    }

    @Test(arguments: [EWOULDBLOCK, EAGAIN])
    func onlyLockContentionMapsToActiveAttempt(_ errorCode: Int32) {
        let system = ScriptedGateOwnershipSystem(
            lockOutcomes: [.failure(errorCode)]
        )

        #expect(throws: InvestigationMachineGateOwnershipError.activeAttempt) {
            _ = try InvestigationMachineGateOwnershipAcquirer(
                system: system
            ).acquire()
        }
        #expect(system.lockDescriptors.count == 1)
        #expect(system.everySuccessfullyOpenedDescriptorWasClosedOnce)
    }

    @Test(arguments: [EINTR, EBUSY, EPERM, EIO])
    func nonContentionLockFailureRemainsUncertain(_ errorCode: Int32) {
        let system = ScriptedGateOwnershipSystem(
            lockOutcomes: [.failure(errorCode)]
        )

        #expect(throws: InvestigationMachineGateOwnershipError.ownershipUncertain) {
            _ = try InvestigationMachineGateOwnershipAcquirer(
                system: system
            ).acquire()
        }
        #expect(system.everySuccessfullyOpenedDescriptorWasClosedOnce)
    }

    @Test(arguments: nonLockContentionFailures)
    private func contentionErrnoOutsideFlockNeverMeansActiveAttempt(
        _ failure: FailureInjection
    ) {
        let system = ScriptedGateOwnershipSystem(
            failures: [failure]
        )

        #expect(throws: InvestigationMachineGateOwnershipError.ownershipUncertain) {
            _ = try InvestigationMachineGateOwnershipAcquirer(
                system: system
            ).acquire()
        }
        #expect(system.everySuccessfullyOpenedDescriptorWasClosedOnce)
    }

    @Test(arguments: acquisitionFailureInjections)
    private func acquisitionFailuresCloseEveryDescriptorOnce(
        _ failure: FailureInjection
    ) {
        let system = ScriptedGateOwnershipSystem(
            existingLock: failure.operation == .openComponent
                && failure.occurrence == 8,
            failures: [failure]
        )

        #expect(throws: InvestigationMachineGateOwnershipError.ownershipUncertain) {
            _ = try InvestigationMachineGateOwnershipAcquirer(
                system: system
            ).acquire()
        }
        #expect(system.everySuccessfullyOpenedDescriptorWasClosedOnce)
        if failure.operation == .openComponent, failure.occurrence == 6 {
            #expect(system.createCalls == [ModeCall(
                role: .caches, name: fixedBaseName, mode: 0o700)])
            #expect(system.permissionCalls.isEmpty)
        }
        if failure.operation == .setPermissions {
            #expect(system.permissionCalls == [ModeCall(
                role: .lock, name: fixedLockName, mode: 0o600)])
            #expect(system.closeRoles.filter { $0 == .lock }.count == 1)
        }
        if failure.operation == .openComponent, failure.occurrence == 8 {
            #expect(system.lockDescriptors.isEmpty)
            #expect(system.permissionCalls.isEmpty)
        }
    }

    @Test
    func eexistIsReopenedOnlyForTheTwoExclusiveCreateSites() {
        for occurrence in 1...6 {
            let system = ScriptedGateOwnershipSystem(
                failures: [FailureInjection(
                    operation: .openComponent,
                    occurrence: occurrence,
                    errorCode: EEXIST
                )]
            )
            #expect(
                throws: InvestigationMachineGateOwnershipError
                    .ownershipUncertain
            ) {
                _ = try InvestigationMachineGateOwnershipAcquirer(
                    system: system
                ).acquire()
            }
            #expect(system.everySuccessfullyOpenedDescriptorWasClosedOnce)
        }

        for configuration in [(true, false), (false, true), (true, true)] {
            let system = ScriptedGateOwnershipSystem(
                existingBase: configuration.0,
                existingLock: configuration.1
            )
            do {
                let owner = try InvestigationMachineGateOwnershipAcquirer(
                    system: system
                ).acquire()
                try owner.release()
                #expect(system.everyOpenedDescriptorHasExactlyOneCloseAttempt)
            } catch {
                Issue.record("exclusive EEXIST reopen failed: \(error)")
            }
        }
    }

    @Test
    func explicitReleaseIsExactlyOnceAndTerminal() throws {
        let system = ScriptedGateOwnershipSystem()
        let owner = try InvestigationMachineGateOwnershipAcquirer(
            system: system
        ).acquire()

        try owner.release()
        expectDescriptorIsClosed(
            try #require(system.lockDescriptors.last), system: system)
        #expect(throws: InvestigationMachineGateOwnershipError.alreadyReleased) {
            try owner.release()
        }
        #expect(system.closeRoles.filter { $0 == .lock }.count == 1)
        #expect(system.everyOpenedDescriptorHasExactlyOneCloseAttempt)
    }

    @Test
    func closeFailureIsReportedAsUncertainAndRemainsTerminal() throws {
        let system = ScriptedGateOwnershipSystem()
        let owner = try InvestigationMachineGateOwnershipAcquirer(
            system: system
        ).acquire()
        system.closeFailureRoles = [.lock: EIO]

        #expect(throws: InvestigationMachineGateOwnershipError.ownershipUncertain) {
            try owner.release()
        }
        #expect(throws: InvestigationMachineGateOwnershipError.alreadyReleased) {
            try owner.release()
        }
        #expect(system.closeRoles.filter { $0 == .lock }.count == 1)
    }

    @Test
    func exclusiveOperationReturnsAValueAndDoesNotConsumeOwnership() throws {
        let system = ScriptedGateOwnershipSystem()
        let owner = try InvestigationMachineGateOwnershipAcquirer(
            system: system
        ).acquire()

        let value: String = try owner.withExclusiveOwnership { "owned" }
        #expect(value == "owned")
        #expect(system.closeRoles.filter { $0 == .lock }.isEmpty)

        #expect(throws: ExclusiveOperationFixtureError.expected) {
            try owner.withExclusiveOwnership {
                throw ExclusiveOperationFixtureError.expected
            }
        }
        #expect(system.closeRoles.filter { $0 == .lock }.isEmpty)

        try owner.release()
        #expect(throws: InvestigationMachineGateOwnershipError.alreadyReleased) {
            _ = try owner.withExclusiveOwnership { 7 }
        }
        #expect(system.closeRoles.filter { $0 == .lock }.count == 1)
    }

    @Test
    func releaseWaitsForAnInProgressExclusiveOperation() throws {
        let system = ScriptedGateOwnershipSystem()
        let owner = try InvestigationMachineGateOwnershipAcquirer(
            system: system
        ).acquire()
        let operationEntered = DispatchSemaphore(value: 0)
        let allowOperationToFinish = DispatchSemaphore(value: 0)
        let operationFinished = DispatchSemaphore(value: 0)
        let releaseFinished = DispatchSemaphore(value: 0)
        let results = ThreadSafeExclusiveOperationResults()

        DispatchQueue.global().async {
            defer { operationFinished.signal() }
            do {
                let value: Int = try owner.withExclusiveOwnership {
                    operationEntered.signal()
                    guard allowOperationToFinish.wait(
                        timeout: .now() + .seconds(2)
                    ) == .success else {
                        throw ExclusiveOperationFixtureError.timedOut
                    }
                    return 41
                }
                results.recordOperation(value: value)
            } catch {
                results.recordOperation(error: error)
            }
        }
        try #require(
            operationEntered.wait(timeout: .now() + .seconds(2)) == .success
        )
        let releaseLockAttempted = system.ownershipMutex.armNextLockAttempt()
        DispatchQueue.global().async {
            do {
                try owner.release()
                results.recordRelease(error: nil)
            } catch {
                results.recordRelease(error: error)
            }
            releaseFinished.signal()
        }
        try #require(releaseLockAttempted.wait(
            timeout: .now() + .seconds(2)) == .success)
        #expect(system.closeRoles.filter { $0 == .lock }.isEmpty)

        allowOperationToFinish.signal()
        try #require(
            operationFinished.wait(timeout: .now() + .seconds(2)) == .success
        )
        try #require(
            releaseFinished.wait(timeout: .now() + .seconds(2)) == .success
        )
        #expect(results.operationValue == 41)
        #expect(results.operationError == nil)
        #expect(results.releaseError == nil)
        #expect(system.closeRoles.filter { $0 == .lock }.count == 1)
        #expect(throws: InvestigationMachineGateOwnershipError.alreadyReleased) {
            _ = try owner.withExclusiveOwnership { 43 }
        }
    }

    @Test
    func concurrentReleaseClosesTheLockExactlyOnce() throws {
        let system = ScriptedGateOwnershipSystem()
        let owner = try InvestigationMachineGateOwnershipAcquirer(
            system: system
        ).acquire()
        let results = ThreadSafeReleaseResults()

        DispatchQueue.concurrentPerform(iterations: 16) { _ in
            do {
                try owner.release()
                results.append(nil)
            } catch let error as InvestigationMachineGateOwnershipError {
                results.append(error)
            } catch {
                results.append(.ownershipUncertain)
            }
        }

        #expect(results.values.filter { $0 == nil }.count == 1)
        #expect(results.values.filter { $0 == .alreadyReleased }.count == 15)
        #expect(system.closeRoles.filter { $0 == .lock }.count == 1)
    }

    @Test
    func heldOwnerForcesActiveAttemptAndReleaseAllowsReacquire() throws {
        let system = ScriptedGateOwnershipSystem()
        let owner = try InvestigationMachineGateOwnershipAcquirer(
            system: system).acquire()
        #expect(throws: InvestigationMachineGateOwnershipError.activeAttempt) {
            _ = try InvestigationMachineGateOwnershipAcquirer(system: system)
                .acquire()
        }
        try owner.release()
        let reacquired = try InvestigationMachineGateOwnershipAcquirer(
            system: system).acquire()
        try reacquired.release()
        #expect(system.lockDescriptors.count == 3)
        #expect(system.closeRoles.filter { $0 == .lock }.count == 3)
        #expect(system.everyOpenedDescriptorHasExactlyOneCloseAttempt)
    }

    @Test
    func deinitPerformsOneBestEffortCloseWithoutRetryingExplicitFailure() throws {
        let leakedSystem = ScriptedGateOwnershipSystem()
        weak var weakOwner: InvestigationMachineGateOwnership?
        do {
            let owner = try InvestigationMachineGateOwnershipAcquirer(
                system: leakedSystem
            ).acquire()
            weakOwner = owner
        }
        #expect(weakOwner == nil)
        #expect(leakedSystem.closeRoles.filter { $0 == .lock }.count == 1)

        let failedSystem = ScriptedGateOwnershipSystem()
        var failedOwner: InvestigationMachineGateOwnership? =
            try InvestigationMachineGateOwnershipAcquirer(
                system: failedSystem
            ).acquire()
        failedSystem.closeFailureRoles = [.lock: EIO]
        #expect(throws: InvestigationMachineGateOwnershipError.ownershipUncertain) {
            try failedOwner?.release()
        }
        failedOwner = nil
        #expect(failedSystem.closeRoles.filter { $0 == .lock }.count == 1)
    }
}

private let identityBufferCapacities =
    [1_024, 2_048, 4_096, 8_192, 16_384, 32_768, 65_536]
private let fixedBaseName = "com.eriklee.stornaut.task39-machine-gate"
private let fixedBaseRelativePath = "Users/eriklee/Library/Caches/\(fixedBaseName)"
private let fixedLockName = ".owner-lock-v1"
private let directoryRootFlags = O_RDONLY | O_DIRECTORY | O_CLOEXEC
    | O_NONBLOCK | O_NOFOLLOW_ANY
private let directoryChildFlags = directoryRootFlags | O_RESOLVE_BENEATH
private let lockOpenFlags = O_RDWR | O_CLOEXEC | O_NONBLOCK
    | O_NOFOLLOW_ANY | O_RESOLVE_BENEATH | O_UNIQUE
private let baseNamedFlags = AT_SYMLINK_NOFOLLOW_ANY | AT_RESOLVE_BENEATH
    | AT_UNIQUE
private let lockNamedFlags = baseNamedFlags

private let validIdentity = InvestigationMachineGateIdentitySnapshot(
    realUID: 501,
    effectiveUID: 501,
    accountUID: 501,
    realGID: 20,
    effectiveGID: 20,
    accountGID: 20,
    homePath: "/Users/eriklee"
)

private let expectedFreshOpenCalls: [OpenCall] = [
    OpenCall(
        parentRole: nil, name: "/", flags: directoryRootFlags, mode: nil),
    OpenCall(
        parentRole: .root, name: "Users",
        flags: directoryChildFlags, mode: nil),
    OpenCall(
        parentRole: .users, name: "eriklee",
        flags: directoryChildFlags, mode: nil),
    OpenCall(
        parentRole: .home, name: "Library",
        flags: directoryChildFlags, mode: nil),
    OpenCall(
        parentRole: .library, name: "Caches",
        flags: directoryChildFlags, mode: nil),
    OpenCall(
        parentRole: .caches, name: fixedBaseName,
        flags: directoryChildFlags, mode: nil),
    OpenCall(
        parentRole: .base, name: fixedLockName,
        flags: lockOpenFlags | O_CREAT | O_EXCL, mode: 0o600),
]

private enum GateRole: String, Hashable, Sendable {
    case root, users, home, library, caches, base, lock
}

private struct OpenCall: Equatable, Sendable {
    let parentRole: GateRole?; let name: String
    let flags: Int32; let mode: mode_t?
}

private struct NamedCall: Equatable, Sendable {
    let parentRole: GateRole; let name: String; let flags: Int32
}

private struct ModeCall: Equatable, Sendable {
    let role: GateRole; let name: String; let mode: mode_t
}

private enum IdentityOutcome: Sendable {
    case success(InvestigationMachineGateIdentitySnapshot), failure(Int32)
}

private enum ScriptedOperation: Hashable, Sendable {
    case createDirectory
    case openComponent
    case metadata
    case namedMetadata
    case descriptorFlags
    case descriptorStatusFlags
    case setPermissions
    case extendedACL
    case extendedAttributes
    case lock
    case close
}

private struct FailureInjection: Sendable {
    let operation: ScriptedOperation; let occurrence: Int; let errorCode: Int32
}

private let acquisitionFailureInjections: [FailureInjection] = [
    (.createDirectory, 1),
    (.openComponent, 8),
    (.metadata, 9),
    (.namedMetadata, 4),
    (.descriptorFlags, 9),
    (.descriptorStatusFlags, 9),
    (.setPermissions, 1),
    (.extendedACL, 4),
    (.extendedAttributes, 4),
    (.lock, 1),
    (.close, 6),
].flatMap { operation, maximumOccurrence in
    (1...maximumOccurrence).map { occurrence in
        FailureInjection(
            operation: operation, occurrence: occurrence, errorCode: EIO)
    }
}

private let nonLockContentionFailures: [FailureInjection] = [
    .createDirectory, .openComponent, .metadata, .namedMetadata,
    .descriptorFlags, .descriptorStatusFlags, .setPermissions, .extendedACL,
    .extendedAttributes, .close,
].map { FailureInjection(
    operation: $0, occurrence: 1, errorCode: EWOULDBLOCK
) }

private enum IdentityMutation: CaseIterable, Sendable {
    case realUID
    case effectiveUID
    case realGID
    case effectiveGID
    case accountUID
    case accountGID
    case emptyHome
    case relativeHome
    case repeatedSeparator
    case dotComponent
    case dotDotComponent
    case trailingSeparator
    case rootHome

    func apply(
        to value: InvestigationMachineGateIdentitySnapshot
    ) -> InvestigationMachineGateIdentitySnapshot {
        var realUID = value.realUID
        var effectiveUID = value.effectiveUID
        var realGID = value.realGID
        var effectiveGID = value.effectiveGID
        var accountUID = value.accountUID
        var accountGID = value.accountGID
        var homePath = value.homePath
        switch self {
        case .realUID: realUID = 502
        case .effectiveUID: effectiveUID = 502
        case .realGID: realGID = 21
        case .effectiveGID: effectiveGID = 21
        case .accountUID: accountUID = 502
        case .accountGID: accountGID = 21
        case .emptyHome: homePath = ""
        case .relativeHome: homePath = "Users/eriklee"
        case .repeatedSeparator: homePath = "/Users//eriklee"
        case .dotComponent: homePath = "/Users/./eriklee"
        case .dotDotComponent: homePath = "/Users/admin/../eriklee"
        case .trailingSeparator: homePath = "/Users/eriklee/"
        case .rootHome: homePath = "/"
        }
        return InvestigationMachineGateIdentitySnapshot(
            realUID: realUID,
            effectiveUID: effectiveUID,
            accountUID: accountUID,
            realGID: realGID,
            effectiveGID: effectiveGID,
            accountGID: accountGID,
            homePath: homePath
        )
    }
}

private enum DescriptorDrift: CaseIterable, Sendable {
    case rootType
    case usersType
    case homeType
    case libraryType
    case cachesType
    case missingRootCloseOnExec
    case missingParentCloseOnExec
    case missingBaseCloseOnExec
    case missingLockCloseOnExec
    case missingRootNonblocking
    case missingParentNonblocking
    case missingBaseNonblocking
    case missingLockNonblocking
    case directoryWriteAccess
    case lockReadOnlyAccess

    func apply(to system: ScriptedGateOwnershipSystem) {
        switch self {
        case .rootType: system.metadataByRole[.root] = otherMetadata(.root)
        case .usersType: system.metadataByRole[.users] = otherMetadata(.users)
        case .homeType: system.metadataByRole[.home] = otherMetadata(.home)
        case .libraryType:
            system.metadataByRole[.library] = otherMetadata(.library)
        case .cachesType:
            system.metadataByRole[.caches] = otherMetadata(.caches)
        case .missingRootCloseOnExec:
            system.descriptorFlagsByRole[.root] = 0
        case .missingParentCloseOnExec:
            system.descriptorFlagsByRole[.library] = 0
        case .missingBaseCloseOnExec:
            system.descriptorFlagsByRole[.base] = 0
        case .missingLockCloseOnExec:
            system.descriptorFlagsByRole[.lock] = 0
        case .missingRootNonblocking:
            system.statusFlagsByRole[.root] = O_RDONLY
        case .missingParentNonblocking:
            system.statusFlagsByRole[.library] = O_RDONLY
        case .missingBaseNonblocking:
            system.statusFlagsByRole[.base] = O_RDONLY
        case .missingLockNonblocking:
            system.statusFlagsByRole[.lock] = O_RDWR
        case .directoryWriteAccess:
            system.statusFlagsByRole[.caches] = O_NONBLOCK | O_RDWR
        case .lockReadOnlyAccess:
            system.statusFlagsByRole[.lock] = O_NONBLOCK | O_RDONLY
        }
    }
}

private enum MetadataDrift: CaseIterable, Sendable {
    case baseType
    case baseOwnerUID
    case baseOwnerGID
    case baseMode
    case baseFlags
    case baseACL
    case baseXattr
    case lockType
    case lockOwnerUID
    case lockOwnerGID
    case lockMode
    case lockLinkCount
    case lockSize
    case lockFlags
    case lockACL
    case lockXattr
    case deviceMismatch

    func apply(to system: ScriptedGateOwnershipSystem) {
        switch self {
        case .baseType:
            system.metadataByRole[.base] = otherMetadata(.base)
        case .baseOwnerUID:
            system.metadataByRole[.base] = fixtureMetadata(.base, ownerUID: 502)
        case .baseOwnerGID:
            system.metadataByRole[.base] = fixtureMetadata(.base, ownerGID: 21)
        case .baseMode:
            system.metadataByRole[.base] = fixtureMetadata(
                .base, permissions: 0o755)
        case .baseFlags:
            system.metadataByRole[.base] = fixtureMetadata(.base, flags: 1)
        case .baseACL:
            system.aclEmptyByRole[.base] = false
        case .baseXattr:
            system.xattrsByRole[.base] = ["com.example.injected"]
        case .lockType:
            system.metadataByRole[.lock] = otherMetadata(.lock)
        case .lockOwnerUID:
            system.metadataByRole[.lock] = fixtureMetadata(.lock, ownerUID: 502)
        case .lockOwnerGID:
            system.metadataByRole[.lock] = fixtureMetadata(.lock, ownerGID: 21)
        case .lockMode:
            system.metadataByRole[.lock] = fixtureMetadata(
                .lock, permissions: 0o644)
        case .lockLinkCount:
            system.metadataByRole[.lock] = fixtureMetadata(.lock, linkCount: 2)
        case .lockSize:
            system.metadataByRole[.lock] = fixtureMetadata(.lock, size: 1)
        case .lockFlags:
            system.metadataByRole[.lock] = fixtureMetadata(.lock, flags: 1)
        case .lockACL:
            system.aclEmptyByRole[.lock] = false
        case .lockXattr:
            system.xattrsByRole[.lock] = ["com.example.injected"]
        case .deviceMismatch:
            system.metadataByRole[.lock] = fixtureMetadata(.lock, device: 99)
        }
    }
}

private enum NamedReplacement: CaseIterable, Sendable {
    case baseBeforeLock
    case lockBeforeLock
    case baseAfterLock
    case lockAfterLock

    func apply(to system: ScriptedGateOwnershipSystem) {
        let replacementRole: GateRole
        let responses: [InvestigationMachineGateMetadataSnapshot]
        switch self {
        case .baseBeforeLock:
            replacementRole = .base
            responses = [replacementMetadata(.base)]
        case .lockBeforeLock:
            replacementRole = .lock
            responses = [replacementMetadata(.lock)]
        case .baseAfterLock:
            replacementRole = .base
            responses = [fixtureMetadata(.base), replacementMetadata(.base)]
        case .lockAfterLock:
            replacementRole = .lock
            responses = [fixtureMetadata(.lock), replacementMetadata(.lock)]
        }
        system.namedMetadataByRole[replacementRole] = responses
    }
}

private final class ScriptedGateOwnershipSystem:
    @unchecked Sendable, InvestigationMachineGateOwnershipSystem
{
    private let stateLock = NSLock()
    let ownershipMutex = ScriptedOwnershipMutex()
    private var state: State

    init(
        identityOutcomes: [IdentityOutcome] = [.success(validIdentity)],
        existingBase: Bool = false,
        existingLock: Bool = false,
        lockPermissions: mode_t = 0o600,
        lockOutcomes: [LockOutcome] = [],
        failures: [FailureInjection] = []
    ) {
        state = State(
            identityOutcomes: identityOutcomes,
            existingBase: existingBase,
            existingLock: existingLock,
            lockOutcomes: lockOutcomes,
            failures: failures
        )
        state.lockPermissions = lockPermissions
    }

    var metadataByRole: [GateRole: InvestigationMachineGateMetadataSnapshot] {
        get { withState { $0.metadataByRole } }
        set { withState { $0.metadataByRole = newValue } }
    }

    var namedMetadataByRole:
        [GateRole: [InvestigationMachineGateMetadataSnapshot]]
    {
        get { withState { $0.namedMetadataByRole } }
        set { withState { $0.namedMetadataByRole = newValue } }
    }

    var descriptorFlagsByRole: [GateRole: Int32] {
        get { withState { $0.descriptorFlagsByRole } }
        set { withState { $0.descriptorFlagsByRole = newValue } }
    }

    var statusFlagsByRole: [GateRole: Int32] {
        get { withState { $0.statusFlagsByRole } }
        set { withState { $0.statusFlagsByRole = newValue } }
    }

    var aclEmptyByRole: [GateRole: Bool] {
        get { withState { $0.aclEmptyByRole } }
        set { withState { $0.aclEmptyByRole = newValue } }
    }

    var xattrsByRole: [GateRole: [String]] {
        get { withState { $0.xattrsByRole } }
        set { withState { $0.xattrsByRole = newValue } }
    }

    var closeFailureRoles: [GateRole: Int32] {
        get { withState { $0.closeFailureRoles } }
        set { withState { $0.closeFailureRoles = newValue } }
    }

    var identityBufferByteCounts: [Int] {
        withState { $0.identityBufferByteCounts }
    }

    var openCalls: [OpenCall] { withState { $0.openCalls } }
    var createCalls: [ModeCall] { withState { $0.createCalls } }
    var permissionCalls: [ModeCall] { withState { $0.permissionCalls } }
    var namedCalls: [NamedCall] { withState { $0.namedCalls } }
    var lockDescriptors: [Int32] { withState { $0.lockDescriptors } }
    var closeDescriptors: [Int32] { withState { $0.closeDescriptors } }
    var metadataDescriptors: [Int32] { withState { $0.metadataDescriptors } }
    var descriptorFlagDescriptors: [Int32] {
        withState { $0.descriptorFlagDescriptors }
    }
    var statusFlagDescriptors: [Int32] {
        withState { $0.statusFlagDescriptors }
    }
    var aclDescriptors: [Int32] { withState { $0.aclDescriptors } }
    var xattrDescriptors: [Int32] { withState { $0.xattrDescriptors } }
    var closeRoles: [GateRole] { roles(for: closeDescriptors) }

    var everySuccessfullyOpenedDescriptorWasClosedOnce: Bool {
        withState { state in
            let opened = Set(state.rolesByDescriptor.keys)
            let closeCounts = Dictionary(
                grouping: state.closeDescriptors, by: { $0 }
            ).mapValues(\.count)
            return opened.allSatisfy { closeCounts[$0] == 1 }
        }
    }

    var everyOpenedDescriptorHasExactlyOneCloseAttempt: Bool {
        everySuccessfullyOpenedDescriptorWasClosedOnce
    }

    func roles(for descriptors: [Int32]) -> [GateRole] {
        withState { state in
            descriptors.compactMap { state.rolesByDescriptor[$0] }
        }
    }

    func identitySnapshot(
        bufferByteCount: Int
    ) throws -> InvestigationMachineGateIdentitySnapshot {
        try withState { state in
            state.identityBufferByteCounts.append(bufferByteCount)
            let outcome = state.identityOutcomes.isEmpty
                ? IdentityOutcome.success(validIdentity)
                : state.identityOutcomes.removeFirst()
            switch outcome {
            case .success(let snapshot): return snapshot
            case .failure(let errorCode):
                throw InvestigationMachineGateSystemError.errno(errorCode)
            }
        }
    }

    func makeOwnershipMutex() -> any InvestigationMachineGateOwnershipMutex {
        ownershipMutex
    }

    func createDirectory(
        parentDescriptor: Int32, name: String, mode: mode_t
    ) throws {
        try withState { state in
            let parentRole = try state.role(for: parentDescriptor)
            state.createCalls.append(ModeCall(
                role: parentRole, name: name, mode: mode))
            try state.failIfRequested(.createDirectory)
            guard name == fixedBaseName else {
                throw InvestigationMachineGateSystemError.errno(EINVAL)
            }
            guard !state.existingBase else {
                throw InvestigationMachineGateSystemError.errno(EEXIST)
            }
            state.existingBase = true
        }
    }

    func openComponent(
        parentDescriptor: Int32?,
        name: String,
        flags: Int32,
        mode: mode_t?
    ) throws -> Int32 {
        try withState { state in
            let parentRole: GateRole?
            if let parentDescriptor {
                parentRole = try state.role(for: parentDescriptor)
            } else {
                parentRole = nil
            }
            state.openCalls.append(OpenCall(
                parentRole: parentRole, name: name, flags: flags, mode: mode
            ))
            try state.failIfRequested(.openComponent)

            if name == fixedLockName,
               flags & O_CREAT != 0,
               state.existingLock
            {
                throw InvestigationMachineGateSystemError.errno(EEXIST)
            }

            let role = try roleForOpen(parentRole: parentRole, name: name)
            let descriptor = state.nextDescriptor
            state.nextDescriptor += 1
            state.rolesByDescriptor[descriptor] = role
            if role == .lock {
                if flags & O_CREAT != 0 { state.lockPermissions = 0o400 }
                state.existingLock = true
            }
            return descriptor
        }
    }

    func metadata(
        descriptor: Int32
    ) throws -> InvestigationMachineGateMetadataSnapshot {
        try withState { state in
            try state.failIfRequested(.metadata)
            let role = try state.role(for: descriptor)
            state.metadataDescriptors.append(descriptor)
            return state.metadataByRole[role] ?? fixtureMetadata(
                role, permissions: role == .lock ? state.lockPermissions : nil)
        }
    }

    func namedMetadata(
        parentDescriptor: Int32,
        name: String,
        flags: Int32
    ) throws -> InvestigationMachineGateMetadataSnapshot {
        try withState { state in
            let parentRole = try state.role(for: parentDescriptor)
            state.namedCalls.append(NamedCall(
                parentRole: parentRole, name: name, flags: flags
            ))
            try state.failIfRequested(.namedMetadata)
            let role: GateRole = name == fixedBaseRelativePath ? .base : .lock
            if var responses = state.namedMetadataByRole[role],
               !responses.isEmpty
            {
                let response = responses.removeFirst()
                state.namedMetadataByRole[role] = responses
                return response
            }
            return state.metadataByRole[role] ?? fixtureMetadata(
                role, permissions: role == .lock ? state.lockPermissions : nil)
        }
    }

    func descriptorFlags(_ descriptor: Int32) throws -> Int32 {
        try withState { state in
            try state.failIfRequested(.descriptorFlags)
            let role = try state.role(for: descriptor)
            state.descriptorFlagDescriptors.append(descriptor)
            return state.descriptorFlagsByRole[role] ?? FD_CLOEXEC
        }
    }

    func descriptorStatusFlags(_ descriptor: Int32) throws -> Int32 {
        try withState { state in
            try state.failIfRequested(.descriptorStatusFlags)
            let role = try state.role(for: descriptor)
            state.statusFlagDescriptors.append(descriptor)
            return state.statusFlagsByRole[role]
                ?? (role == .lock ? O_NONBLOCK | O_RDWR : O_NONBLOCK | O_RDONLY)
        }
    }

    func setPermissions(descriptor: Int32, mode: mode_t) throws {
        try withState { state in
            let role = try state.role(for: descriptor)
            state.permissionCalls.append(ModeCall(
                role: role, name: role == .lock ? fixedLockName : role.rawValue,
                mode: mode))
            try state.failIfRequested(.setPermissions)
            if role == .lock { state.lockPermissions = mode }
        }
    }

    func extendedACLIsEmpty(descriptor: Int32) throws -> Bool {
        try withState { state in
            state.aclDescriptors.append(descriptor)
            try state.failIfRequested(.extendedACL)
            let role = try state.role(for: descriptor)
            return state.aclEmptyByRole[role] ?? true
        }
    }

    func extendedAttributeNames(descriptor: Int32) throws -> [String] {
        try withState { state in
            state.xattrDescriptors.append(descriptor)
            try state.failIfRequested(.extendedAttributes)
            let role = try state.role(for: descriptor)
            return state.xattrsByRole[role] ?? []
        }
    }

    func acquireExclusiveNonblockingLock(descriptor: Int32) throws {
        try withState { state in
            _ = try state.role(for: descriptor)
            state.lockDescriptors.append(descriptor)
            try state.failIfRequested(.lock)
            if !state.lockOutcomes.isEmpty {
                let outcome = state.lockOutcomes.removeFirst()
                if case .failure(let errorCode) = outcome {
                    throw InvestigationMachineGateSystemError.errno(errorCode)
                }
            }
            guard state.heldLockDescriptor == nil else {
                throw InvestigationMachineGateSystemError.errno(EWOULDBLOCK)
            }
            state.heldLockDescriptor = descriptor
        }
    }

    func close(descriptor: Int32) throws {
        try withState { state in
            let role = try state.role(for: descriptor)
            state.closeDescriptors.append(descriptor)
            if let errorCode = state.closeFailureRoles[role] {
                throw InvestigationMachineGateSystemError.errno(errorCode)
            }
            try state.failIfRequested(.close)
            state.closedDescriptors.insert(descriptor)
            if state.heldLockDescriptor == descriptor {
                state.heldLockDescriptor = nil
            }
        }
    }

    private func withState<T>(_ body: (inout State) throws -> T) rethrows -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return try body(&state)
    }

    private struct State {
        var identityOutcomes: [IdentityOutcome]
        var existingBase: Bool
        var existingLock: Bool
        var lockOutcomes: [LockOutcome]
        var failures: [FailureInjection]
        var operationCounts: [ScriptedOperation: Int] = [:]
        var identityBufferByteCounts: [Int] = []
        var createCalls: [ModeCall] = []
        var openCalls: [OpenCall] = []
        var permissionCalls: [ModeCall] = []
        var namedCalls: [NamedCall] = []
        var lockDescriptors: [Int32] = []
        var closeDescriptors: [Int32] = []
        var metadataDescriptors: [Int32] = []
        var descriptorFlagDescriptors: [Int32] = []
        var statusFlagDescriptors: [Int32] = []
        var heldLockDescriptor: Int32?
        var lockPermissions: mode_t = 0o600
        var aclDescriptors: [Int32] = []
        var xattrDescriptors: [Int32] = []
        var nextDescriptor: Int32 = 10
        var rolesByDescriptor: [Int32: GateRole] = [:]
        var metadataByRole: [GateRole: InvestigationMachineGateMetadataSnapshot] = [:]
        var namedMetadataByRole:
            [GateRole: [InvestigationMachineGateMetadataSnapshot]] = [:]
        var descriptorFlagsByRole: [GateRole: Int32] = [:]
        var statusFlagsByRole: [GateRole: Int32] = [:]
        var aclEmptyByRole: [GateRole: Bool] = [:]
        var xattrsByRole: [GateRole: [String]] = [:]
        var closeFailureRoles: [GateRole: Int32] = [:]
        var closedDescriptors: Set<Int32> = []

        mutating func failIfRequested(_ operation: ScriptedOperation) throws {
            operationCounts[operation, default: 0] += 1
            let occurrence = operationCounts[operation, default: 0]
            if let failure = failures.first(where: {
                $0.operation == operation && $0.occurrence == occurrence
            }) {
                throw InvestigationMachineGateSystemError.errno(
                    failure.errorCode)
            }
        }

        func role(for descriptor: Int32) throws -> GateRole {
            guard !closedDescriptors.contains(descriptor),
                  let role = rolesByDescriptor[descriptor] else {
                throw InvestigationMachineGateSystemError.errno(EBADF)
            }
            return role
        }
    }
}

private enum LockOutcome: Sendable {
    case success, failure(Int32)
}

private enum ExclusiveOperationFixtureError: Error, Equatable {
    case expected, timedOut
}

private final class ThreadSafeExclusiveOperationResults: @unchecked Sendable {
    private let lock = NSLock()
    private var operationValueStorage: Int?; private var operationErrorStorage: (any Error)?
    private var releaseErrorStorage: (any Error)?
    var operationValue: Int? { lock.withLock { operationValueStorage } }
    var operationError: (any Error)? { lock.withLock { operationErrorStorage } }
    var releaseError: (any Error)? { lock.withLock { releaseErrorStorage } }
    func recordOperation(value: Int) { lock.withLock { operationValueStorage = value } }
    func recordOperation(error: any Error) { lock.withLock { operationErrorStorage = error } }
    func recordRelease(error: (any Error)?) { lock.withLock { releaseErrorStorage = error } }
}

private final class ScriptedOwnershipMutex:
    @unchecked Sendable, InvestigationMachineGateOwnershipMutex
{
    private let mutex = NSLock(); private let stateLock = NSLock()
    private var nextAttempt: DispatchSemaphore?
    func armNextLockAttempt() -> DispatchSemaphore {
        let signal = DispatchSemaphore(value: 0)
        stateLock.withLock { nextAttempt = signal }; return signal
    }
    func lock() {
        let signal = stateLock.withLock { () -> DispatchSemaphore? in
            defer { nextAttempt = nil }; return nextAttempt
        }
        signal?.signal(); mutex.lock()
    }
    func unlock() { mutex.unlock() }
}

private final class ThreadSafeReleaseResults: @unchecked Sendable {
    private let lock = NSLock(); private var storage: [InvestigationMachineGateOwnershipError?] = []
    var values: [InvestigationMachineGateOwnershipError?] { lock.withLock { storage } }
    func append(_ value: InvestigationMachineGateOwnershipError?) { lock.withLock { storage.append(value) } }
}

private func expectDescriptorIsClosed(
    _ descriptor: Int32, system: ScriptedGateOwnershipSystem) {
    let bad = InvestigationMachineGateSystemError.errno(EBADF)
    #expect(throws: bad) { _ = try system.metadata(descriptor: descriptor) }
    #expect(throws: bad) { _ = try system.namedMetadata(
        parentDescriptor: descriptor, name: fixedLockName, flags: lockNamedFlags) }
    #expect(throws: bad) { _ = try system.openComponent(
        parentDescriptor: descriptor, name: fixedLockName,
        flags: lockOpenFlags, mode: nil) }
    #expect(throws: bad) { _ = try system.descriptorFlags(descriptor) }
    #expect(throws: bad) { _ = try system.descriptorStatusFlags(descriptor) }
    #expect(throws: bad) { try system.setPermissions(descriptor: descriptor, mode: 0o600) }
    #expect(throws: bad) { _ = try system.extendedACLIsEmpty(descriptor: descriptor) }
    #expect(throws: bad) { _ = try system.extendedAttributeNames(descriptor: descriptor) }
    #expect(throws: bad) { try system.acquireExclusiveNonblockingLock(descriptor: descriptor) }
}

private func roleForOpen(
    parentRole: GateRole?, name: String) throws -> GateRole {
    switch (parentRole, name) {
    case (nil, "/"): .root
    case (.root, "Users"): .users
    case (.users, "eriklee"): .home
    case (.home, "Library"): .library
    case (.library, "Caches"): .caches
    case (.caches, fixedBaseName): .base
    case (.base, fixedLockName): .lock
    default: throw InvestigationMachineGateSystemError.errno(EINVAL)
    }
}

private func fixtureMetadata(
    _ role: GateRole,
    device: UInt64 = 7,
    ownerUID: uid_t? = nil,
    ownerGID: gid_t? = nil,
    permissions: mode_t? = nil,
    linkCount: UInt64? = nil,
    size: Int64 = 0,
    flags: UInt32 = 0
) -> InvestigationMachineGateMetadataSnapshot {
    let isSystemDirectory = role == .root || role == .users
    let isLock = role == .lock
    return InvestigationMachineGateMetadataSnapshot(
        device: device,
        inode: UInt64(GateRole.allIndex(of: role) + 100),
        generation: UInt64(GateRole.allIndex(of: role) + 1),
        fileType: isLock ? .regularFile : .directory,
        ownerUID: ownerUID ?? (isSystemDirectory ? 0 : 501),
        ownerGID: ownerGID ?? (isSystemDirectory ? 0 : 20),
        permissions: permissions ?? (
            isLock ? 0o600 : (role == .base ? 0o700 : 0o755)
        ),
        linkCount: linkCount ?? (isLock ? 1 : 2),
        size: size,
        flags: flags
    )
}

private func otherMetadata(
    _ role: GateRole
) -> InvestigationMachineGateMetadataSnapshot {
    let value = fixtureMetadata(role)
    return InvestigationMachineGateMetadataSnapshot(
        device: value.device,
        inode: value.inode,
        generation: value.generation,
        fileType: .other,
        ownerUID: value.ownerUID,
        ownerGID: value.ownerGID,
        permissions: value.permissions,
        linkCount: value.linkCount,
        size: value.size,
        flags: value.flags
    )
}

private func replacementMetadata(
    _ role: GateRole
) -> InvestigationMachineGateMetadataSnapshot {
    let value = fixtureMetadata(role)
    return InvestigationMachineGateMetadataSnapshot(
        device: value.device,
        inode: value.inode + 10_000,
        generation: value.generation + 1,
        fileType: value.fileType,
        ownerUID: value.ownerUID,
        ownerGID: value.ownerGID,
        permissions: value.permissions,
        linkCount: value.linkCount,
        size: value.size,
        flags: value.flags
    )
}

private extension GateRole {
    static func allIndex(of role: GateRole) -> Int {
        switch role {
        case .root: 0
        case .users: 1
        case .home: 2
        case .library: 3
        case .caches: 4
        case .base: 5
        case .lock: 6
        }
    }
}
