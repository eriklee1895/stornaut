import Darwin
import Dispatch
import Foundation

enum InvestigationMachineDarwinEpochRetirementError:
    Error, Sendable, Equatable
{
    case alreadyConsumed
    case authorityInvalid
    case deadlineExceeded
    case descriptorCloseFailed
    case inventoryInvalid
    case signalFailed
    case waitFailed
}

struct InvestigationMachineDarwinEpochRetirementSystem: Sendable {
    let currentProcessGroup: @Sendable () -> Int32
    let continuousNanoseconds: @Sendable () throws -> UInt64
    let closeDescriptor: @Sendable (Int32) throws -> Void
    let processGroupInventory:
        @Sendable (UInt32, Int32, Int) throws -> Data
    let waitID: @Sendable (Int32, Int32) throws -> Int32?
    let sendSignal: @Sendable (Int32, Int32) throws -> Void
    let waitPID: @Sendable (Int32, Int32) throws -> Int32?
    let waitPIDStatus:
        @Sendable (Int32, Int32) throws
            -> InvestigationMachineDarwinWaitPIDStatus?
    let pauseNanoseconds: @Sendable (UInt64) throws -> Void

    static let system = Self(
        currentProcessGroup: Darwin.getpgrp,
        continuousNanoseconds:
            investigationMachineDarwinRetirementContinuousNanoseconds,
        closeDescriptor: investigationMachineDarwinRetirementClose,
        processGroupInventory:
            investigationMachineDarwinRetirementProcessGroupInventory,
        waitID: investigationMachineDarwinRetirementWaitID,
        sendSignal: investigationMachineDarwinRetirementSignal,
        waitPID: investigationMachineDarwinRetirementWaitPID,
        waitPIDStatus: investigationMachineDarwinRetirementWaitPIDStatus,
        pauseNanoseconds: investigationMachineDarwinRetirementPause
    )
}

struct InvestigationMachineDarwinWaitPIDStatus: Sendable, Equatable {
    let processID: Int32
    let rawStatus: Int32
}

final class InvestigationMachineDarwinEpochRetirementOwner:
    @unchecked Sendable, InvestigationMachineDarwinEpochRetirementOwning
{
    static let maximumInventoryEntries = 4_096
    static let totalWindowNanoseconds: UInt64 = 5_000_000_000
    static let termWindowNanoseconds: UInt64 = 1_000_000_000
    private static let pollNanoseconds: UInt64 = 10_000_000
    private static let queue = DispatchQueue(
        label: "com.eriklee.stornaut.machine-epoch-retirement",
        qos: .utility, attributes: .concurrent
    )

    private enum State { case idle, running, terminal }

    private let system: InvestigationMachineDarwinEpochRetirementSystem
    private let lock = NSLock()
    private var state = State.idle

    init(system: InvestigationMachineDarwinEpochRetirementSystem = .system) {
        self.system = system
    }

    func retireOwnedProcessGroup(
        _ ownedEpoch: InvestigationMachineDarwinOwnedEpoch
    ) async throws -> InvestigationMachineSingleEpochRetirementProof {
        try beginOnce()
        return try await perform {
            defer { self.finish() }
            return try self.retireOwnedProcessGroupSynchronously(ownedEpoch)
        }
    }

    func retireSpawnedProcess(
        _ spawnedEpoch: InvestigationMachineDarwinSpawnedEpoch
    ) async throws {
        try beginOnce()
        try await perform {
            defer { self.finish() }
            try self.retireSpawnedProcessSynchronously(spawnedEpoch)
        }
    }

    func reapSuccessfulDirectChild(
        _ spawnedEpoch: InvestigationMachineDarwinSpawnedEpoch
    ) async throws -> InvestigationMachineSingleEpochRetirementProof {
        try beginOnce()
        return try await perform {
            defer { self.finish() }
            return try self.reapSuccessfulDirectChildSynchronously(spawnedEpoch)
        }
    }

    private func beginOnce() throws {
        let accepted = lock.withLock { () -> Bool in
            guard state == .idle else { return false }
            state = .running
            return true
        }
        guard accepted else {
            throw InvestigationMachineDarwinEpochRetirementError
                .alreadyConsumed
        }
    }

    private func finish() {
        lock.withLock { state = .terminal }
    }

    private func perform<Value: Sendable>(
        _ operation: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        let resolution = InvestigationMachineDarwinRetirementResolution<Value>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                resolution.install(continuation)
                Self.queue.async {
                    resolution.finish(Result { try operation() })
                }
                if Task.isCancelled { resolution.requestCancellation() }
            }
        } onCancel: {
            resolution.requestCancellation()
        }
    }

    private func retireOwnedProcessGroupSynchronously(
        _ epoch: InvestigationMachineDarwinOwnedEpoch
    ) throws -> InvestigationMachineSingleEpochRetirementProof {
        let descriptorFailure = closeExactlyOnce(epoch.descriptors)
        guard
            epoch.processID > 1,
            epoch.processGroupID > 1,
            epoch.processGroupID == epoch.processID,
            epoch.processGroupID != system.currentProcessGroup()
        else {
            throw InvestigationMachineDarwinEpochRetirementError
                .authorityInvalid
        }

        let started = try clock()
        let termDeadline = try adding(Self.termWindowNanoseconds, to: started)
        let totalDeadline = try adding(Self.totalWindowNanoseconds, to: started)
        var termSent = false
        var killSent = false

        while true {
            _ = try requireBefore(totalDeadline)
            let members = try inventory(epoch.processGroupID)
            _ = try requireBefore(totalDeadline)
            let waitable = try waitableLeader(
                epoch.processID, deadline: totalDeadline
            )
            let observationCompletedAt = try requireBefore(totalDeadline)
            if waitable == nil, !members.contains(epoch.processID) {
                throw InvestigationMachineDarwinEpochRetirementError
                    .authorityInvalid
            }
            let descendants = members.filter { $0 != epoch.processID }
            if waitable == epoch.processID, descendants.isEmpty {
                try reapLeader(epoch.processID, deadline: totalDeadline)
                _ = try requireBefore(totalDeadline)
                let postReapMembers = try inventory(epoch.processGroupID)
                guard postReapMembers.isEmpty else {
                    throw InvestigationMachineDarwinEpochRetirementError
                        .inventoryInvalid
                }
                _ = try requireBefore(totalDeadline)
                guard !descriptorFailure else {
                    throw InvestigationMachineDarwinEpochRetirementError
                        .descriptorCloseFailed
                }
                return .init()
            }

            if !termSent {
                try signal(-epoch.processGroupID, SIGTERM)
                termSent = true
                continue
            }
            if !killSent, observationCompletedAt >= termDeadline {
                try signal(-epoch.processGroupID, SIGKILL)
                killSent = true
                continue
            }

            let nextBoundary = killSent ? totalDeadline : termDeadline
            try pause(until: nextBoundary, totalDeadline: totalDeadline)
        }
    }

    private func retireSpawnedProcessSynchronously(
        _ epoch: InvestigationMachineDarwinSpawnedEpoch
    ) throws {
        let descriptorFailure = closeExactlyOnce(epoch.descriptors)
        guard epoch.processID > 1 else {
            throw InvestigationMachineDarwinEpochRetirementError
                .authorityInvalid
        }
        let started = try clock()
        let totalDeadline = try adding(Self.totalWindowNanoseconds, to: started)

        var waitable = try waitableLeader(
            epoch.processID, deadline: totalDeadline
        )
        if waitable == nil {
            try signal(epoch.processID, SIGKILL)
            while waitable == nil {
                try pause(
                    until: totalDeadline, totalDeadline: totalDeadline
                )
                waitable = try waitableLeader(
                    epoch.processID, deadline: totalDeadline
                )
            }
        }
        guard waitable == epoch.processID else {
            throw InvestigationMachineDarwinEpochRetirementError.waitFailed
        }
        try reapLeader(epoch.processID, deadline: totalDeadline)
        _ = try requireBefore(totalDeadline)
        guard !descriptorFailure else {
            throw InvestigationMachineDarwinEpochRetirementError
                .descriptorCloseFailed
        }
    }

    private func reapSuccessfulDirectChildSynchronously(
        _ epoch: InvestigationMachineDarwinSpawnedEpoch
    ) throws -> InvestigationMachineSingleEpochRetirementProof {
        let descriptorFailure = closeExactlyOnce(epoch.descriptors)
        guard epoch.processID > 1 else {
            throw InvestigationMachineDarwinEpochRetirementError
                .authorityInvalid
        }
        let started = try clock()
        let deadline = try adding(Self.totalWindowNanoseconds, to: started)
        while try waitableLeader(epoch.processID, deadline: deadline) == nil {
            try pause(until: deadline, totalDeadline: deadline)
        }
        let status = try reapStatus(epoch.processID, deadline: deadline)
        _ = try requireBefore(deadline)
        guard
            status.processID == epoch.processID,
            status.rawStatus & 0x7f == 0,
            status.rawStatus >> 8 & 0xff == 0
        else {
            throw InvestigationMachineDarwinEpochRetirementError.waitFailed
        }
        guard !descriptorFailure else {
            throw InvestigationMachineDarwinEpochRetirementError
                .descriptorCloseFailed
        }
        return .init()
    }

    private func closeExactlyOnce(_ descriptors: [Int32]) -> Bool {
        var failed = false
        for descriptor in Set(descriptors).sorted() {
            do { try system.closeDescriptor(descriptor) }
            catch { failed = true }
        }
        return failed
    }

    private func inventory(_ processGroupID: Int32) throws -> [Int32] {
        let data: Data
        do {
            data = try system.processGroupInventory(
                UInt32(PROC_PGRP_ONLY), processGroupID,
                Self.maximumInventoryEntries
            )
        } catch {
            throw InvestigationMachineDarwinEpochRetirementError
                .inventoryInvalid
        }
        let width = MemoryLayout<Int32>.size
        guard
            data.count.isMultiple(of: width),
            data.count < Self.maximumInventoryEntries * width
        else {
            throw InvestigationMachineDarwinEpochRetirementError
                .inventoryInvalid
        }
        let values = data.withUnsafeBytes { bytes in
            stride(from: 0, to: data.count, by: width).map { offset in
                bytes.loadUnaligned(fromByteOffset: offset, as: Int32.self)
            }
        }
        guard
            values.allSatisfy({ $0 > 1 }),
            Set(values).count == values.count
        else {
            throw InvestigationMachineDarwinEpochRetirementError
                .inventoryInvalid
        }
        return values
    }

    private func waitableLeader(
        _ processID: Int32, deadline: UInt64
    ) throws -> Int32? {
        while true {
            _ = try requireBefore(deadline)
            do {
                let observed = try system.waitID(
                    processID, Int32(WEXITED | WNOHANG | WNOWAIT)
                )
                guard observed == nil || observed == processID else {
                    throw InvestigationMachineDarwinEpochRetirementError
                        .waitFailed
                }
                return observed
            } catch let error as POSIXError where error.code == .EINTR {
                _ = try requireBefore(deadline)
                continue
            } catch let error as InvestigationMachineDarwinEpochRetirementError {
                throw error
            } catch {
                throw InvestigationMachineDarwinEpochRetirementError.waitFailed
            }
        }
    }

    private func reapLeader(_ processID: Int32, deadline: UInt64) throws {
        _ = try requireBefore(deadline)
        while true {
            let observed: Int32?
            do {
                observed = try system.waitPID(processID, Int32(WNOHANG))
            } catch let error as POSIXError where error.code == .EINTR {
                _ = try requireBefore(deadline)
                continue
            } catch {
                throw InvestigationMachineDarwinEpochRetirementError.waitFailed
            }
            if observed == processID { return }
            throw InvestigationMachineDarwinEpochRetirementError.waitFailed
        }
    }

    private func reapStatus(
        _ processID: Int32, deadline: UInt64
    ) throws -> InvestigationMachineDarwinWaitPIDStatus {
        _ = try requireBefore(deadline)
        while true {
            do {
                guard let observed = try system.waitPIDStatus(
                    processID, Int32(WNOHANG)
                ), observed.processID == processID else {
                    throw InvestigationMachineDarwinEpochRetirementError
                        .waitFailed
                }
                return observed
            } catch let error as POSIXError where error.code == .EINTR {
                _ = try requireBefore(deadline)
                continue
            } catch let error as InvestigationMachineDarwinEpochRetirementError {
                throw error
            } catch {
                throw InvestigationMachineDarwinEpochRetirementError.waitFailed
            }
        }
    }

    private func signal(_ target: Int32, _ signal: Int32) throws {
        do { try system.sendSignal(target, signal) }
        catch {
            throw InvestigationMachineDarwinEpochRetirementError.signalFailed
        }
    }

    private func pause(
        until boundary: UInt64, totalDeadline: UInt64
    ) throws {
        let now = try requireBefore(totalDeadline)
        let effectiveBoundary = min(boundary, totalDeadline)
        guard now < effectiveBoundary else { return }
        let interval = min(Self.pollNanoseconds, effectiveBoundary - now)
        do { try system.pauseNanoseconds(interval) }
        catch {
            throw InvestigationMachineDarwinEpochRetirementError.waitFailed
        }
    }

    private func clock() throws -> UInt64 {
        do { return try system.continuousNanoseconds() }
        catch {
            throw InvestigationMachineDarwinEpochRetirementError
                .deadlineExceeded
        }
    }

    @discardableResult
    private func requireBefore(_ deadline: UInt64) throws -> UInt64 {
        let now = try clock()
        guard now < deadline else {
            throw InvestigationMachineDarwinEpochRetirementError
                .deadlineExceeded
        }
        return now
    }

    private func adding(_ delta: UInt64, to value: UInt64) throws -> UInt64 {
        let result = value.addingReportingOverflow(delta)
        guard !result.overflow else {
            throw InvestigationMachineDarwinEpochRetirementError
                .deadlineExceeded
        }
        return result.partialValue
    }
}

private final class InvestigationMachineDarwinRetirementResolution<
    Value: Sendable
>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, any Error>?
    private var pending: Result<Value, any Error>?
    private var completed = false
    private var cancellationRequested = false

    func install(_ value: CheckedContinuation<Value, any Error>) {
        let result = lock.withLock { () -> Result<Value, any Error>? in
            if completed { return pending }
            continuation = value
            return nil
        }
        if let result { value.resume(with: result) }
    }

    func finish(_ result: Result<Value, any Error>) {
        let state = lock.withLock {
            () -> (Result<Value, any Error>,
                CheckedContinuation<Value, any Error>?)? in
            guard !completed else { return nil }
            completed = true
            let final: Result<Value, any Error> = cancellationRequested
                ? .failure(CancellationError()) : result
            pending = final
            let value = continuation
            continuation = nil
            return (final, value)
        }
        if let state { state.1?.resume(with: state.0) }
    }

    func requestCancellation() {
        lock.withLock {
            guard !completed else { return }
            cancellationRequested = true
        }
    }
}

private func investigationMachineDarwinRetirementProcessGroupInventory(
    _ flavor: UInt32, _ processGroupID: Int32, _ maximumEntries: Int
) throws -> Data {
    guard
        flavor == UInt32(PROC_PGRP_ONLY), processGroupID > 1,
        maximumEntries ==
            InvestigationMachineDarwinEpochRetirementOwner
                .maximumInventoryEntries
    else {
        throw InvestigationMachineDarwinEpochRetirementError.inventoryInvalid
    }
    var processIDs = [pid_t](repeating: 0, count: maximumEntries)
    let byteCount = processIDs.withUnsafeMutableBytes { buffer in
        proc_listpids(
            flavor, UInt32(bitPattern: processGroupID), buffer.baseAddress,
            Int32(buffer.count)
        )
    }
    guard byteCount >= 0, Int(byteCount) <= processIDs.count * MemoryLayout<pid_t>.size else {
        throw InvestigationMachineDarwinEpochRetirementError.inventoryInvalid
    }
    return processIDs.withUnsafeBytes { bytes in
        Data(bytes.prefix(Int(byteCount)))
    }
}

private func investigationMachineDarwinRetirementWaitID(
    _ processID: Int32, _ options: Int32
) throws -> Int32? {
    var information = siginfo_t()
    errno = 0
    let result = waitid(
        P_PID, UInt32(bitPattern: processID), &information, options
    )
    guard result == 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
    return information.si_pid == 0 ? nil : information.si_pid
}

private func investigationMachineDarwinRetirementWaitPID(
    _ processID: Int32, _ options: Int32
) throws -> Int32? {
    errno = 0
    let result = waitpid(processID, nil, options)
    if result > 0 { return result }
    if result == 0 { return nil }
    throw POSIXError(.init(rawValue: errno) ?? .EIO)
}

private func investigationMachineDarwinRetirementWaitPIDStatus(
    _ processID: Int32, _ options: Int32
) throws -> InvestigationMachineDarwinWaitPIDStatus? {
    var status: Int32 = 0
    errno = 0
    let result = waitpid(processID, &status, options)
    if result > 0 {
        return .init(processID: result, rawStatus: status)
    }
    if result == 0 { return nil }
    throw POSIXError(.init(rawValue: errno) ?? .EIO)
}

private func investigationMachineDarwinRetirementSignal(
    _ target: Int32, _ signal: Int32
) throws {
    errno = 0
    guard Darwin.kill(target, signal) == 0 else {
        throw POSIXError(.init(rawValue: errno) ?? .EIO)
    }
}

private func investigationMachineDarwinRetirementClose(
    _ descriptor: Int32
) throws {
    errno = 0
    guard Darwin.close(descriptor) == 0 else {
        throw POSIXError(.init(rawValue: errno) ?? .EIO)
    }
}

private func investigationMachineDarwinRetirementPause(
    _ nanoseconds: UInt64
) throws {
    var requested = timespec(
        tv_sec: Int(nanoseconds / 1_000_000_000),
        tv_nsec: Int(nanoseconds % 1_000_000_000)
    )
    errno = 0
    guard nanosleep(&requested, nil) == 0 else {
        throw POSIXError(.init(rawValue: errno) ?? .EIO)
    }
}

private func investigationMachineDarwinRetirementContinuousNanoseconds() throws
    -> UInt64
{
    var timebase = mach_timebase_info_data_t()
    guard mach_timebase_info(&timebase) == KERN_SUCCESS, timebase.denom > 0 else {
        throw InvestigationMachineDarwinEpochRetirementError.deadlineExceeded
    }
    let product = mach_continuous_time()
        .multipliedFullWidth(by: UInt64(timebase.numer))
    guard product.high < UInt64(timebase.denom) else {
        throw InvestigationMachineDarwinEpochRetirementError.deadlineExceeded
    }
    return UInt64(timebase.denom).dividingFullWidth(product).quotient
}
