import Darwin
import Foundation

public enum LifecycleAuditTokenError: Error, Sendable, Equatable {
    case invalidWordCount
}

public struct LifecycleAuditToken: Sendable, Hashable {
    public static let wordCount = 8

    public let words: [UInt32]

    public init(words: [UInt32]) throws {
        guard words.count == Self.wordCount else {
            throw LifecycleAuditTokenError.invalidWordCount
        }
        self.words = words
    }
}

public struct LifecycleProcessIdentity: Sendable, Hashable {
    public let processID: pid_t
    public let processIDVersion: Int32
    public let auditSessionID: Int32
    public let effectiveUserID: uid_t
    public let auditToken: LifecycleAuditToken

    public init(
        processID: pid_t,
        processIDVersion: Int32,
        auditSessionID: Int32,
        effectiveUserID: uid_t,
        auditToken: LifecycleAuditToken
    ) {
        self.processID = processID
        self.processIDVersion = processIDVersion
        self.auditSessionID = auditSessionID
        self.effectiveUserID = effectiveUserID
        self.auditToken = auditToken
    }
}

public protocol LifecycleProcessInventory: Sendable {
    func processes(
        in auditSessionID: Int32
    ) throws -> [LifecycleProcessIdentity]
}

public enum LifecycleSignal: Sendable, Hashable {
    case stop
    case kill

    public var rawValue: Int32 {
        switch self {
        case .stop:
            SIGSTOP
        case .kill:
            SIGKILL
        }
    }
}

public enum LifecycleSignalResult: Sendable, Equatable {
    case sent
    case noSuchProcess
}

public protocol LifecycleIdentitySignaling: Sendable {
    func send(
        _ signal: LifecycleSignal,
        to identity: LifecycleProcessIdentity
    ) throws -> LifecycleSignalResult
}

public struct LifecycleDrainPolicy: Sendable, Equatable {
    public let maximumFreezePasses: Int
    public let maximumKillPasses: Int
    public let maximumMembers: Int

    public init(
        maximumFreezePasses: Int = 64,
        maximumKillPasses: Int = 64,
        maximumMembers: Int = 4_096
    ) {
        self.maximumFreezePasses = max(1, maximumFreezePasses)
        self.maximumKillPasses = max(1, maximumKillPasses)
        self.maximumMembers = max(1, maximumMembers)
    }
}

public enum LifecycleDrainOutcome: String, Sendable, Equatable {
    case drained
}

public struct LifecycleDrainReport: Sendable, Equatable {
    public let auditSessionID: Int32
    public let freezePasses: Int
    public let killPasses: Int
    public let uniqueMemberCount: Int
    public let outcome: LifecycleDrainOutcome
}

public enum LifecycleDrainError: Error, Sendable, Equatable {
    case unsafeAuditSession
    case identityMismatch
    case duplicateIdentity
    case memberLimitExceeded
    case freezeDidNotConverge
    case killDidNotConverge
}

public struct LifecycleSessionDrainer: Sendable {
    private let inventory: any LifecycleProcessInventory
    private let signaler: any LifecycleIdentitySignaling
    private let policy: LifecycleDrainPolicy

    public init(
        inventory: any LifecycleProcessInventory,
        signaler: any LifecycleIdentitySignaling,
        policy: LifecycleDrainPolicy = LifecycleDrainPolicy()
    ) {
        self.inventory = inventory
        self.signaler = signaler
        self.policy = policy
    }

    public func drain(
        auditSessionID: Int32,
        expectedUserID: uid_t,
        supervisorIdentity: LifecycleProcessIdentity?,
        allowRootMembersDuringRecovery: Bool = false
    ) throws -> LifecycleDrainReport {
        guard auditSessionID > 0 else {
            throw LifecycleDrainError.unsafeAuditSession
        }
        guard
            !allowRootMembersDuringRecovery
                || supervisorIdentity == nil
        else {
            throw LifecycleDrainError.unsafeAuditSession
        }
        if let supervisorIdentity {
            guard
                supervisorIdentity.processID > 1,
                supervisorIdentity.processIDVersion > 0,
                supervisorIdentity.auditSessionID == auditSessionID,
                supervisorIdentity.effectiveUserID == 0
            else {
                throw LifecycleDrainError.unsafeAuditSession
            }
        }

        var knownIdentities = Set<LifecycleProcessIdentity>()
        var freezePasses = 0
        var didConverge = false

        for pass in 1...policy.maximumFreezePasses {
            let snapshot = try targetSnapshot(
                auditSessionID: auditSessionID,
                expectedUserID: expectedUserID,
                supervisorIdentity: supervisorIdentity,
                allowRootMembersDuringRecovery:
                    allowRootMembersDuringRecovery
            )
            freezePasses = pass
            let newIdentities = snapshot.filter {
                !knownIdentities.contains($0)
            }
            guard
                knownIdentities.count + newIdentities.count
                    <= policy.maximumMembers
            else {
                throw LifecycleDrainError.memberLimitExceeded
            }

            for identity in newIdentities.sortedByStableIdentity {
                let result = try signaler.send(.stop, to: identity)
                if result == .sent {
                    knownIdentities.insert(identity)
                }
            }

            if newIdentities.isEmpty {
                didConverge = true
                break
            }
        }

        guard didConverge else {
            throw LifecycleDrainError.freezeDidNotConverge
        }

        if knownIdentities.isEmpty {
            return LifecycleDrainReport(
                auditSessionID: auditSessionID,
                freezePasses: freezePasses,
                killPasses: 0,
                uniqueMemberCount: 0,
                outcome: .drained
            )
        }

        for pass in 1...policy.maximumKillPasses {
            for identity in knownIdentities.sortedByStableIdentity {
                _ = try signaler.send(.kill, to: identity)
            }

            let remaining = try targetSnapshot(
                auditSessionID: auditSessionID,
                expectedUserID: expectedUserID,
                supervisorIdentity: supervisorIdentity,
                allowRootMembersDuringRecovery:
                    allowRootMembersDuringRecovery
            )
            guard remaining.allSatisfy(knownIdentities.contains) else {
                throw LifecycleDrainError.killDidNotConverge
            }
            if remaining.isEmpty {
                return LifecycleDrainReport(
                    auditSessionID: auditSessionID,
                    freezePasses: freezePasses,
                    killPasses: pass,
                    uniqueMemberCount: knownIdentities.count,
                    outcome: .drained
                )
            }
        }

        throw LifecycleDrainError.killDidNotConverge
    }

    private func targetSnapshot(
        auditSessionID: Int32,
        expectedUserID: uid_t,
        supervisorIdentity: LifecycleProcessIdentity?,
        allowRootMembersDuringRecovery: Bool
    ) throws -> [LifecycleProcessIdentity] {
        let snapshot = try inventory.processes(in: auditSessionID)
        guard Set(snapshot).count == snapshot.count else {
            throw LifecycleDrainError.duplicateIdentity
        }
        var targets: [LifecycleProcessIdentity] = []
        for identity in snapshot {
            guard
                identity.processID > 1,
                identity.processIDVersion > 0,
                identity.auditSessionID == auditSessionID,
                identity.auditToken.words.count
                    == LifecycleAuditToken.wordCount
            else {
                throw LifecycleDrainError.identityMismatch
            }
            if identity == supervisorIdentity {
                continue
            }
            guard
                identity.effectiveUserID == expectedUserID
                    || allowRootMembersDuringRecovery
                        && identity.effectiveUserID == 0
            else {
                throw LifecycleDrainError.identityMismatch
            }
            targets.append(identity)
        }
        guard targets.count <= policy.maximumMembers else {
            throw LifecycleDrainError.memberLimitExceeded
        }
        return targets
    }
}

private extension Sequence where Element == LifecycleProcessIdentity {
    var sortedByStableIdentity: [LifecycleProcessIdentity] {
        sorted {
            if $0.processID == $1.processID {
                return $0.processIDVersion < $1.processIDVersion
            }
            return $0.processID < $1.processID
        }
    }
}
