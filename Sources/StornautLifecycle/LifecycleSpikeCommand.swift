import Darwin

public enum LifecycleSpikeCommand: Sendable, Equatable {
    case drain(
        auditSessionID: Int32,
        userID: uid_t,
        protectCurrentProcess: Bool
    )

    public init(arguments: [String]) throws {
        guard arguments.first == "drain" else {
            throw LifecycleSpikeCommandError.invalidCommand
        }

        var auditSessionID: Int32?
        var userID: uid_t?
        var protectCurrentProcess = false
        var index = 1
        while index < arguments.count {
            switch arguments[index] {
            case "--audit-session-id":
                guard
                    auditSessionID == nil,
                    index + 1 < arguments.count,
                    let value = Int32(arguments[index + 1]),
                    value > 0
                else {
                    throw LifecycleSpikeCommandError.invalidArgument
                }
                auditSessionID = value
                index += 2
            case "--user-id":
                guard
                    userID == nil,
                    index + 1 < arguments.count,
                    let value = UInt32(arguments[index + 1]),
                    value > 0
                else {
                    throw LifecycleSpikeCommandError.invalidArgument
                }
                userID = uid_t(value)
                index += 2
            case "--protect-current-process":
                guard !protectCurrentProcess else {
                    throw LifecycleSpikeCommandError.invalidArgument
                }
                protectCurrentProcess = true
                index += 1
            default:
                throw LifecycleSpikeCommandError.invalidArgument
            }
        }

        guard let auditSessionID, let userID else {
            throw LifecycleSpikeCommandError.invalidArgument
        }
        self = .drain(
            auditSessionID: auditSessionID,
            userID: userID,
            protectCurrentProcess: protectCurrentProcess
        )
    }
}

public enum LifecycleSpikeCommandError: Error, Sendable, Equatable {
    case invalidCommand
    case invalidArgument
}
