import Foundation

public struct LifecycleInteractiveWorkerConfiguration:
    Sendable,
    Equatable
{
    public let investigationID: LifecycleInvestigationID
    public let validBefore: Date
    public let maximumLineBytes: Int
    public let maximumSessionBytes: Int

    public init(
        investigationID: LifecycleInvestigationID,
        validBefore: Date,
        maximumLineBytes: Int,
        maximumSessionBytes: Int
    ) {
        self.investigationID = investigationID
        self.validBefore = validBefore
        self.maximumLineBytes = maximumLineBytes
        self.maximumSessionBytes = maximumSessionBytes
    }
}

public protocol LifecycleInteractiveWorkerDriving: Sendable {
    func start(
        _ configuration: LifecycleInteractiveWorkerConfiguration
    ) async throws

    func writeLine(_ line: Data) async throws

    func readLine(maximumBytes: Int) async throws -> Data?

    func retire() async throws
        -> LifecycleInteractiveWorkerRetirementObservation
}

public enum LifecycleInteractiveWorkerError:
    Error,
    Sendable,
    Equatable
{
    case sessionUnavailable
    case sessionExpired
    case lineLimitExceeded
    case sessionLimitExceeded
}

public enum LifecycleInteractiveSessionBrokerError:
    Error,
    Sendable,
    Equatable
{
    case invalidRequest
    case sessionUnavailable
    case sessionMismatch
    case sessionExpired
    case lineLimitExceeded
    case sessionLimitExceeded
    case startFailed
    case writeFailed
    case readFailed
    case retireFailed
}

public actor LifecycleInteractiveSessionBroker {
    private enum Phase {
        case ready
        case starting
        case active
        case failed
        case retiring
        case retired
    }

    private static let maximumOperationCount = 16_384

    private let worker: any LifecycleInteractiveWorkerDriving
    private let now: @Sendable () -> Date
    private var phase = Phase.ready
    private var configuration: LifecycleInteractiveWorkerConfiguration?
    private var operationIDs = Set<UUID>()
    private var transferredBytes = 0
    private var ioOperationInProgress = false
    private var retirementTask: Task<
        LifecycleInteractiveWorkerRetirementObservation?,
        Never
    >?
    private var retirementObservation:
        LifecycleInteractiveWorkerRetirementObservation?

    public init(
        worker: any LifecycleInteractiveWorkerDriving,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.worker = worker
        self.now = now
    }

    public func handle(
        _ request: LifecycleInteractiveSessionRequest
    ) async throws -> LifecycleInteractiveSessionResponse {
        switch request.kind {
        case .start:
            return try await start(request)
        case .write:
            return try await write(request)
        case .read:
            return try await read(request)
        case .retire:
            return try await retire(request)
        }
    }

    public func invalidateAndRetire() async -> Bool {
        await drainOnce() != nil
    }

    private func start(
        _ request: LifecycleInteractiveSessionRequest
    ) async throws -> LifecycleInteractiveSessionResponse {
        guard
            phase == .ready,
            configuration == nil,
            let validBefore = request.validBefore,
            let maximumLineBytes = request.maximumLineBytes,
            let maximumSessionBytes = request.maximumSessionBytes,
            validBefore > now(),
            validBefore.timeIntervalSince(now()) <= 900
        else {
            throw LifecycleInteractiveSessionBrokerError.invalidRequest
        }
        try admitOperation(request.operationID)
        let configuration = LifecycleInteractiveWorkerConfiguration(
            investigationID: request.investigationID,
            validBefore: validBefore,
            maximumLineBytes: maximumLineBytes,
            maximumSessionBytes: maximumSessionBytes
        )
        self.configuration = configuration
        phase = .starting
        do {
            try await worker.start(configuration)
        } catch let error as LifecycleInteractiveWorkerError {
            if phase == .starting {
                phase = .failed
                throw brokerError(error)
            }
            throw LifecycleInteractiveSessionBrokerError
                .sessionUnavailable
        } catch {
            if phase == .starting {
                phase = .failed
                throw LifecycleInteractiveSessionBrokerError.startFailed
            }
            throw LifecycleInteractiveSessionBrokerError
                .sessionUnavailable
        }
        guard phase == .starting else {
            throw LifecycleInteractiveSessionBrokerError.sessionUnavailable
        }
        guard now() < validBefore else {
            phase = .failed
            throw LifecycleInteractiveSessionBrokerError.sessionExpired
        }
        phase = .active
        return .started(
            investigationID: request.investigationID,
            operationID: request.operationID
        )
    }

    private func write(
        _ request: LifecycleInteractiveSessionRequest
    ) async throws -> LifecycleInteractiveSessionResponse {
        let configuration = try admitActive(request)
        defer { ioOperationInProgress = false }
        guard let line = request.line else {
            throw LifecycleInteractiveSessionBrokerError.invalidRequest
        }
        try account(
            line,
            configuration: configuration
        )
        do {
            try await worker.writeLine(line)
        } catch let error as LifecycleInteractiveWorkerError {
            if phase != .active {
                throw LifecycleInteractiveSessionBrokerError
                    .sessionUnavailable
            }
            phase = .failed
            throw brokerError(error)
        } catch {
            if phase != .active {
                throw LifecycleInteractiveSessionBrokerError
                    .sessionUnavailable
            }
            phase = .failed
            throw LifecycleInteractiveSessionBrokerError.writeFailed
        }
        try acceptCompletedOperation(configuration)
        return .writeAccepted(
            investigationID: request.investigationID,
            operationID: request.operationID
        )
    }

    private func read(
        _ request: LifecycleInteractiveSessionRequest
    ) async throws -> LifecycleInteractiveSessionResponse {
        let configuration = try admitActive(request)
        defer { ioOperationInProgress = false }
        let line: Data?
        do {
            line = try await worker.readLine(
                maximumBytes: configuration.maximumLineBytes
            )
        } catch let error as LifecycleInteractiveWorkerError {
            if phase != .active {
                throw LifecycleInteractiveSessionBrokerError
                    .sessionUnavailable
            }
            phase = .failed
            throw brokerError(error)
        } catch {
            if phase != .active {
                throw LifecycleInteractiveSessionBrokerError
                    .sessionUnavailable
            }
            phase = .failed
            throw LifecycleInteractiveSessionBrokerError.readFailed
        }
        try acceptCompletedOperation(configuration)
        guard let line else {
            return .endOfStream(
                investigationID: request.investigationID,
                operationID: request.operationID
            )
        }
        try account(
            line,
            configuration: configuration
        )
        do {
            return try .line(
                investigationID: request.investigationID,
                operationID: request.operationID,
                line: line
            )
        } catch {
            phase = .failed
            throw LifecycleInteractiveSessionBrokerError.readFailed
        }
    }

    private func retire(
        _ request: LifecycleInteractiveSessionRequest
    ) async throws -> LifecycleInteractiveSessionResponse {
        try admitRetirement(request)
        guard let observation = await drainOnce() else {
            throw LifecycleInteractiveSessionBrokerError.retireFailed
        }
        return .retired(
            investigationID: request.investigationID,
            operationID: request.operationID,
            drained: true,
            ownerRetirementObservation: observation
        )
    }

    private func admitActive(
        _ request: LifecycleInteractiveSessionRequest
    ) throws -> LifecycleInteractiveWorkerConfiguration {
        guard
            phase == .active,
            let configuration
        else {
            throw LifecycleInteractiveSessionBrokerError
                .sessionUnavailable
        }
        guard
            configuration.investigationID == request.investigationID
        else {
            throw LifecycleInteractiveSessionBrokerError.sessionMismatch
        }
        guard now() < configuration.validBefore else {
            phase = .failed
            throw LifecycleInteractiveSessionBrokerError.sessionExpired
        }
        guard !ioOperationInProgress else {
            throw LifecycleInteractiveSessionBrokerError
                .sessionUnavailable
        }
        try admitOperation(request.operationID)
        ioOperationInProgress = true
        return configuration
    }

    private func admitRetirement(
        _ request: LifecycleInteractiveSessionRequest
    ) throws {
        if let configuration {
            guard
                configuration.investigationID == request.investigationID
            else {
                throw LifecycleInteractiveSessionBrokerError
                    .sessionMismatch
            }
        } else {
            configuration = LifecycleInteractiveWorkerConfiguration(
                investigationID: request.investigationID,
                validBefore: now(),
                maximumLineBytes: 1,
                maximumSessionBytes: 1
            )
        }
        try admitOperation(request.operationID)
    }

    private func admitOperation(_ operationID: UUID) throws {
        guard
            operationIDs.count < Self.maximumOperationCount,
            operationIDs.insert(operationID).inserted
        else {
            throw LifecycleInteractiveSessionBrokerError.invalidRequest
        }
    }

    private func acceptCompletedOperation(
        _ admitted: LifecycleInteractiveWorkerConfiguration
    ) throws {
        guard
            phase == .active,
            configuration == admitted
        else {
            throw LifecycleInteractiveSessionBrokerError
                .sessionUnavailable
        }
        guard now() < admitted.validBefore else {
            phase = .failed
            throw LifecycleInteractiveSessionBrokerError.sessionExpired
        }
    }

    private func account(
        _ line: Data,
        configuration: LifecycleInteractiveWorkerConfiguration
    ) throws {
        guard
            !line.isEmpty,
            line.count <= configuration.maximumLineBytes,
            line.last == 0x0A,
            !line.dropLast().contains(0x00)
        else {
            phase = .failed
            throw LifecycleInteractiveSessionBrokerError
                .lineLimitExceeded
        }
        let total = transferredBytes.addingReportingOverflow(line.count)
        guard
            !total.overflow,
            total.partialValue <= configuration.maximumSessionBytes
        else {
            phase = .failed
            throw LifecycleInteractiveSessionBrokerError
                .sessionLimitExceeded
        }
        transferredBytes = total.partialValue
    }

    private func brokerError(
        _ error: LifecycleInteractiveWorkerError
    ) -> LifecycleInteractiveSessionBrokerError {
        switch error {
        case .sessionUnavailable:
            .sessionUnavailable
        case .sessionExpired:
            .sessionExpired
        case .lineLimitExceeded:
            .lineLimitExceeded
        case .sessionLimitExceeded:
            .sessionLimitExceeded
        }
    }

    private func drainOnce() async
        -> LifecycleInteractiveWorkerRetirementObservation?
    {
        if phase == .retired {
            return retirementObservation
        }
        if let retirementTask {
            return await retirementTask.value
        }
        phase = .retiring
        let worker = self.worker
        let task = Task<
            LifecycleInteractiveWorkerRetirementObservation?,
            Never
        > {
            do {
                return try await worker.retire()
            } catch {
                return nil
            }
        }
        retirementTask = task
        let observation = await task.value
        retirementObservation = observation
        phase = observation == nil ? .failed : .retired
        return observation
    }
}
