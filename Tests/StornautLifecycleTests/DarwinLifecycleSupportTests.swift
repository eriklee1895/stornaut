import Darwin
import Foundation
import Testing
@testable import StornautLifecycle

@Suite("Darwin lifecycle support")
struct DarwinLifecycleSupportTests {
    @Test
    func currentProcessIdentityMatchesKernelFields() throws {
        let inventory = DarwinLifecycleInventory()
        let identity = try inventory.identity(for: getpid())
        let auditSessionID = try currentLifecycleAuditSessionID()

        #expect(identity.processID == getpid())
        #expect(identity.processIDVersion > 0)
        #expect(identity.auditSessionID == auditSessionID)
        #expect(identity.effectiveUserID == geteuid())
        #expect(
            identity.auditToken.words.count
                == LifecycleAuditToken.wordCount
        )
    }

    @Test
    func currentUserInventoryCanScanTheCurrentAuditSession() throws {
        let inventory = DarwinLifecycleInventory()
        if geteuid() == 0 {
            let identities = try inventory.processes(
                in: currentLifecycleAuditSessionID()
            )
            #expect(identities.contains(where: {
                $0.processID == getpid()
            }))
            #expect(identities.allSatisfy({
                $0.effectiveUserID == geteuid()
            }))
        } else {
            #expect(throws: DarwinLifecycleSupportError.privilegeRequired) {
                _ = try inventory.processes(
                    in: currentLifecycleAuditSessionID()
                )
            }
        }
    }

    @Test
    func identityCheckedSignalDoesNotRetargetAfterExit() throws {
        let child = try spawnSleepingChild()
        defer {
            if kill(child, 0) == 0 {
                kill(child, SIGKILL)
            }
            _ = waitpid(child, nil, 0)
        }

        let inventory = DarwinLifecycleInventory()
        let identity = try inventory.identity(for: child)
        let signaler = DarwinLifecycleSignaler()

        #expect(try signaler.send(.kill, to: identity) == .sent)
        var status: Int32 = 0
        while waitpid(child, &status, 0) < 0 {
            if errno != EINTR {
                Issue.record("waitpid failed with errno \(errno)")
                break
            }
        }

        #expect(
            try signaler.send(.kill, to: identity)
                == .noSuchProcess
        )
    }
}

private func spawnSleepingChild() throws -> pid_t {
    var attributes: posix_spawnattr_t?
    guard posix_spawnattr_init(&attributes) == 0 else {
        throw DarwinLifecycleTestError.spawnFailed(EINVAL)
    }
    defer { posix_spawnattr_destroy(&attributes) }
    guard
        posix_spawnattr_setflags(
            &attributes,
            Int16(POSIX_SPAWN_CLOEXEC_DEFAULT)
        ) == 0
    else {
        throw DarwinLifecycleTestError.spawnFailed(EINVAL)
    }

    var child: pid_t = 0
    let executable = "/bin/sleep"
    let arguments = [executable, "30"]
    let environment = ["PATH=/usr/bin:/bin"]
    let result = try withCStringArray(arguments) { argv in
        try withCStringArray(environment) { envp in
            executable.withCString { path in
                posix_spawn(
                    &child,
                    path,
                    nil,
                    &attributes,
                    argv,
                    envp
                )
            }
        }
    }
    guard result == 0 else {
        throw DarwinLifecycleTestError.spawnFailed(result)
    }
    return child
}

private func withCStringArray<Result>(
    _ strings: [String],
    body: (
        UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
    ) throws -> Result
) throws -> Result {
    var storage: [UnsafeMutablePointer<CChar>?] = []
    defer {
        for pointer in storage {
            free(pointer)
        }
    }
    for string in strings {
        guard let pointer = strdup(string) else {
            throw DarwinLifecycleTestError.spawnFailed(ENOMEM)
        }
        storage.append(pointer)
    }
    storage.append(nil)
    return try storage.withUnsafeMutableBufferPointer { buffer in
        try body(buffer.baseAddress!)
    }
}

private enum DarwinLifecycleTestError: Error {
    case spawnFailed(Int32)
}
