import CLifecycleSupport
import Darwin
import Foundation

public enum DarwinLifecycleSupportError: Error, Sendable, Equatable {
    case privilegeRequired
    case enumerationFailed(errno: Int32)
    case auditSessionUnavailable(errno: Int32)
    case identityUnavailable(errno: Int32)
    case invalidIdentity
    case signalFailed(signal: Int32, errno: Int32)
    case currentAuditSessionUnavailable(errno: Int32)
}

public struct DarwinLifecycleInventory: LifecycleProcessInventory, Sendable {
    public let expectedUserID: uid_t?
    public let privilegedProcessID: pid_t?
    public let maximumProcessCount: Int

    public init(
        expectedUserID: uid_t? = nil,
        privilegedProcessID: pid_t? = nil,
        maximumProcessCount: Int = 8_192
    ) {
        self.expectedUserID = expectedUserID
        self.privilegedProcessID = privilegedProcessID
        self.maximumProcessCount = max(1, maximumProcessCount)
    }

    public func processes(
        in auditSessionID: Int32
    ) throws -> [LifecycleProcessIdentity] {
        guard geteuid() == 0 else {
            throw DarwinLifecycleSupportError.privilegeRequired
        }
        var capacity = 256
        while capacity <= maximumProcessCount {
            var processIDs = [pid_t](repeating: 0, count: capacity)
            let byteCount = processIDs.withUnsafeMutableBytes { buffer in
                proc_listpids(
                    UInt32(PROC_ALL_PIDS),
                    0,
                    buffer.baseAddress,
                    Int32(buffer.count)
                )
            }
            guard byteCount >= 0 else {
                throw DarwinLifecycleSupportError.enumerationFailed(
                    errno: errno
                )
            }
            let count = Int(byteCount) / MemoryLayout<pid_t>.size
            if count == capacity {
                capacity *= 2
                continue
            }

            var identities: [LifecycleProcessIdentity] = []
            identities.reserveCapacity(min(count, 64))
            for processID in processIDs.prefix(count) where processID > 1 {
                let observedAuditSessionID: Int32
                do {
                    observedAuditSessionID = try processAuditSessionID(
                        for: processID
                    )
                } catch let error as DarwinLifecycleSupportError {
                    if case .auditSessionUnavailable(let code) = error,
                       code == ESRCH
                    {
                        continue
                    }
                    throw error
                }
                guard observedAuditSessionID == auditSessionID else {
                    continue
                }
                do {
                    let observedIdentity: LifecycleProcessIdentity
                    if processID == privilegedProcessID {
                        observedIdentity = try identity(for: processID)
                    } else if let expectedUserID {
                        observedIdentity = try identity(
                            for: processID,
                            expectedUserID: expectedUserID
                        )
                    } else {
                        observedIdentity = try identity(for: processID)
                    }
                    identities.append(observedIdentity)
                } catch let error as DarwinLifecycleSupportError {
                    if case .identityUnavailable(let code) = error,
                       code == ESRCH
                    {
                        continue
                    }
                    throw error
                }
            }
            return identities
        }
        throw DarwinLifecycleSupportError.enumerationFailed(errno: EOVERFLOW)
    }

    private func processAuditSessionID(
        for processID: pid_t
    ) throws -> Int32 {
        var auditSessionID: Int32 = 0
        let result = stornaut_lifecycle_audit_session_for_pid(
            processID,
            &auditSessionID
        )
        guard result == 0, auditSessionID > 0 else {
            throw DarwinLifecycleSupportError.auditSessionUnavailable(
                errno: result
            )
        }
        return auditSessionID
    }

    public func identity(
        for processID: pid_t,
        expectedUserID: uid_t
    ) throws -> LifecycleProcessIdentity {
        var rawIdentity = stornaut_lifecycle_identity()
        let result = stornaut_lifecycle_identity_for_pid_as_user(
            processID,
            expectedUserID,
            &rawIdentity
        )
        guard result == 0 else {
            throw DarwinLifecycleSupportError.identityUnavailable(
                errno: result
            )
        }
        return try identity(
            from: rawIdentity,
            expectedProcessID: processID
        )
    }

    public func identity(
        for processID: pid_t
    ) throws -> LifecycleProcessIdentity {
        var rawIdentity = stornaut_lifecycle_identity()
        let result = stornaut_lifecycle_identity_for_pid(
            processID,
            &rawIdentity
        )
        guard result == 0 else {
            throw DarwinLifecycleSupportError.identityUnavailable(
                errno: result
            )
        }
        return try identity(
            from: rawIdentity,
            expectedProcessID: processID
        )
    }

    private func identity(
        from rawIdentity: stornaut_lifecycle_identity,
        expectedProcessID: pid_t
    ) throws -> LifecycleProcessIdentity {
        let words = withUnsafeBytes(
            of: rawIdentity.audit_token_words
        ) { rawWords -> [UInt32] in
            let wordCount = rawWords.count / MemoryLayout<UInt32>.size
            return rawWords.bindMemory(to: UInt32.self)
                .prefix(wordCount)
                .map { $0 }
        }
        let token: LifecycleAuditToken
        do {
            token = try LifecycleAuditToken(words: words)
        } catch {
            throw DarwinLifecycleSupportError.invalidIdentity
        }
        guard
            rawIdentity.process_id == expectedProcessID,
            rawIdentity.process_id_version > 0,
            rawIdentity.audit_session_id > 0
        else {
            throw DarwinLifecycleSupportError.invalidIdentity
        }
        return LifecycleProcessIdentity(
            processID: rawIdentity.process_id,
            processIDVersion: rawIdentity.process_id_version,
            auditSessionID: rawIdentity.audit_session_id,
            effectiveUserID: rawIdentity.effective_user_id,
            auditToken: token
        )
    }

    func rawIdentity(
        for identity: LifecycleProcessIdentity
    ) -> stornaut_lifecycle_identity {
        var rawIdentity = stornaut_lifecycle_identity()
        rawIdentity.process_id = identity.processID
        rawIdentity.process_id_version = identity.processIDVersion
        rawIdentity.audit_session_id = identity.auditSessionID
        rawIdentity.effective_user_id = identity.effectiveUserID
        withUnsafeMutableBytes(
            of: &rawIdentity.audit_token_words
        ) { rawWords in
            let tokenBytes = identity.auditToken.words.withUnsafeBytes {
                Data($0)
            }
            rawWords.copyBytes(from: tokenBytes)
        }
        return rawIdentity
    }

    func waitUntilStopped(
        _ identity: LifecycleProcessIdentity,
        maximumAttempts: Int = 1_000
    ) throws -> LifecycleSignalResult {
        var rawIdentity = rawIdentity(for: identity)
        for _ in 0..<max(1, maximumAttempts) {
            var isStopped: Int32 = 0
            let result = stornaut_lifecycle_identity_is_stopped(
                &rawIdentity,
                &isStopped
            )
            if result == 0, isStopped != 0 {
                return .sent
            }
            if result == ESRCH {
                return .noSuchProcess
            }
            if result != 0 {
                throw DarwinLifecycleSupportError.identityUnavailable(
                    errno: result
                )
            }
            usleep(1_000)
        }
        throw DarwinLifecycleSupportError.signalFailed(
            signal: SIGSTOP,
            errno: ETIMEDOUT
        )
    }
}

public struct DarwinLifecycleSignaler: LifecycleIdentitySignaling, Sendable {
    private let inventory: DarwinLifecycleInventory

    public init(inventory: DarwinLifecycleInventory = .init()) {
        self.inventory = inventory
    }

    public func send(
        _ signal: LifecycleSignal,
        to identity: LifecycleProcessIdentity
    ) throws -> LifecycleSignalResult {
        var rawIdentity = inventory.rawIdentity(for: identity)

        let result = stornaut_lifecycle_signal_identity(
            &rawIdentity,
            signal.rawValue
        )
        if result == 0 {
            if signal == .stop {
                return try inventory.waitUntilStopped(identity)
            }
            return .sent
        }
        if result == ESRCH {
            return .noSuchProcess
        }
        throw DarwinLifecycleSupportError.signalFailed(
            signal: signal.rawValue,
            errno: result
        )
    }
}

public func currentLifecycleAuditSessionID() throws -> Int32 {
    var auditSessionID: Int32 = 0
    let result = stornaut_lifecycle_current_audit_session_id(
        &auditSessionID
    )
    guard result == 0, auditSessionID > 0 else {
        throw DarwinLifecycleSupportError.currentAuditSessionUnavailable(
            errno: result
        )
    }
    return auditSessionID
}
