import Darwin
import Foundation

public struct ProcessGroupID: RawRepresentable, Sendable, Equatable {
    public let rawValue: pid_t

    public init(rawValue: pid_t) {
        self.rawValue = rawValue
    }
}

public enum ProcessTreeTerminationTransition: String, Sendable, Equatable {
    case interruptSent
    case terminateSent
    case killSent
}

public enum ProcessTreeTerminationError: Error, Sendable, Equatable {
    case unsafeProcessGroup
    case signalFailed(signal: Int32, errno: Int32)
    case unexpected
}

public struct ProcessTreeTerminator: Sendable {
    public init() {}

    static func processGroupHasMembers(
        _ processGroup: ProcessGroupID,
        excluding excludedPID: pid_t
    ) -> Bool {
        guard let members = processGroupMembers(processGroup) else {
            return true
        }
        return members.contains(where: {
            $0 > 0 && $0 != excludedPID
        })
    }

    static func processGroupMembers(
        _ processGroup: ProcessGroupID
    ) -> [pid_t]? {
        var capacity = 16
        while capacity <= 4_096 {
            var pids = [pid_t](repeating: 0, count: capacity)
            let byteCount = pids.withUnsafeMutableBytes { buffer in
                proc_listpids(
                    UInt32(PROC_PGRP_ONLY),
                    UInt32(bitPattern: processGroup.rawValue),
                    buffer.baseAddress,
                    Int32(buffer.count)
                )
            }
            guard byteCount >= 0 else {
                return nil
            }
            let count = Int(byteCount) / MemoryLayout<pid_t>.size
            if count < capacity {
                return Array(pids.prefix(count)).filter { $0 > 0 }
            }
            capacity *= 2
        }
        return nil
    }

    static func leaderHasWaitableExit(
        _ processGroup: ProcessGroupID
    ) -> Bool {
        var information = siginfo_t()
        let result = waitid(
            P_PID,
            UInt32(processGroup.rawValue),
            &information,
            WEXITED | WNOHANG | WNOWAIT
        )
        return result == 0 && information.si_pid == processGroup.rawValue
    }

    static func hasSignalableMembers(
        _ processGroup: ProcessGroupID
    ) -> Bool {
        !leaderHasWaitableExit(processGroup)
            || processGroupHasMembers(
                processGroup,
                excluding: processGroup.rawValue
            )
    }

    public func terminateProcessGroup(
        _ processGroup: ProcessGroupID,
        gracePeriod: Duration
    ) async throws -> [ProcessTreeTerminationTransition] {
        try await Task.detached(priority: .utility) {
            try terminateSynchronously(
                processGroup,
                gracePeriod: gracePeriod
            )
        }.value
    }
}

private func terminateSynchronously(
    _ processGroup: ProcessGroupID,
    gracePeriod: Duration
) throws -> [ProcessTreeTerminationTransition] {
    let groupID = processGroup.rawValue
    guard groupID > 1, groupID != getpgrp() else {
        throw ProcessTreeTerminationError.unsafeProcessGroup
    }

    var transitions: [ProcessTreeTerminationTransition] = []
    guard processGroupExists(processGroup) else {
        return transitions
    }

    try send(SIGINT, to: groupID)
    transitions.append(.interruptSent)
    sleepForDuration(gracePeriod.divided(by: 2))

    if processGroupExists(processGroup) {
        try send(SIGTERM, to: groupID)
        transitions.append(.terminateSent)
        sleepForDuration(gracePeriod.divided(by: 2))
    }

    if processGroupExists(processGroup) {
        try send(SIGKILL, to: groupID)
        transitions.append(.killSent)
    }
    return transitions
}

private func send(_ signal: Int32, to processGroup: pid_t) throws {
    if kill(-processGroup, signal) == 0 || errno == ESRCH {
        return
    }
    if
        errno == EPERM,
        ProcessTreeTerminator.leaderHasWaitableExit(
            ProcessGroupID(rawValue: processGroup)
        ),
        let members = ProcessTreeTerminator.processGroupMembers(
            ProcessGroupID(rawValue: processGroup)
        )
    {
        for member in members where member != processGroup {
            if kill(member, signal) != 0 && errno != ESRCH {
                throw ProcessTreeTerminationError.signalFailed(
                    signal: signal,
                    errno: errno
                )
            }
        }
        return
    }
    throw ProcessTreeTerminationError.signalFailed(
        signal: signal,
        errno: errno
    )
}

private func processGroupExists(
    _ processGroup: ProcessGroupID
) -> Bool {
    if kill(-processGroup.rawValue, 0) == 0 {
        return ProcessTreeTerminator.hasSignalableMembers(processGroup)
    }
    if errno == EPERM {
        return ProcessTreeTerminator.hasSignalableMembers(processGroup)
    }
    return false
}

private func sleepForDuration(_ duration: Duration) {
    let microseconds = duration.clampedMicroseconds
    guard microseconds > 0 else {
        return
    }
    usleep(useconds_t(clamping: microseconds))
}

private extension Duration {
    func divided(by divisor: Int64) -> Duration {
        guard divisor > 0 else {
            return .zero
        }
        let components = self.components
        let seconds = components.seconds
        let nanoseconds = components.attoseconds / 1_000_000_000
        let dividedSeconds = seconds / divisor
        let remainderSeconds = seconds % divisor
        let carriedNanoseconds = remainderSeconds
            .multipliedReportingOverflow(by: 1_000_000_000)
        let combinedNanoseconds = carriedNanoseconds.overflow
            ? Int64.max
            : carriedNanoseconds.partialValue.addingReportingOverflow(
                nanoseconds
            ).partialValue
        return .seconds(dividedSeconds)
            + .nanoseconds(combinedNanoseconds / divisor)
    }

    var clampedMicroseconds: Int64 {
        guard self > .zero else {
            return 0
        }
        let components = self.components
        let seconds = components.seconds.multipliedReportingOverflow(
            by: 1_000_000
        )
        if seconds.overflow {
            return .max
        }
        let fractional = components.attoseconds / 1_000_000_000_000
        let total = seconds.partialValue.addingReportingOverflow(fractional)
        return total.overflow ? .max : max(0, total.partialValue)
    }
}
