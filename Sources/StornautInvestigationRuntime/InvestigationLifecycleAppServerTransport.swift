import Foundation
import StornautCodex
import StornautLifecycle

package enum InvestigationLifecycleAppServerTransportError:
    Error,
    Sendable,
    Equatable
{
    case invalidConfiguration
    case invalidState
    case identityMismatch
    case inputLimitExceeded
    case unexpectedEndOfStream
    case drainUnconfirmed
    case transportFailed
}

package actor InvestigationLifecycleAppServerTransport:
    CodexInteractiveAppServerTransport
{
    private enum State {
        case ready
        case starting
        case active
        case retiring
        case failed
        case retired
    }

    private let investigationID: LifecycleInvestigationID
    private let expectedUserID: UInt32
    private let validBefore: Date
    private let maximumLineBytes: Int
    private let maximumSessionBytes: Int
    private let now: @Sendable () -> Date
    private let operationID: @Sendable () throws -> UUID
    private let session: any LifecycleInteractiveSessionSending
    private var state = State.ready
    private var transferredBytes = 0
    private var residueObservation:
        LifecycleInvestigationResidueObservation?
    private var operationInProgress = false
    private var operationWaiters: [
        (
            id: UUID,
            continuation: CheckedContinuation<Bool, Never>
        )
    ] = []
    private var pendingOperationWaiterIDs = Set<UUID>()
    private var cancelledOperationWaiterIDs = Set<UUID>()

    package init(
        investigationID: LifecycleInvestigationID,
        validBefore: Date,
        maximumLineBytes: Int,
        maximumSessionBytes: Int,
        expectedUserID: UInt32 = UInt32(geteuid()),
        now: @escaping @Sendable () -> Date = Date.init,
        operationID: @escaping @Sendable () throws -> UUID = UUID.init,
        session: any LifecycleInteractiveSessionSending
    ) throws {
        let current = now()
        guard
            validBefore.timeIntervalSince1970.isFinite,
            validBefore > current,
            validBefore.timeIntervalSince(current) <= 900,
            (1...LifecycleInteractiveSessionRequest
                .maximumAllowedLineBytes).contains(maximumLineBytes),
            maximumSessionBytes >= maximumLineBytes,
            maximumSessionBytes <= LifecycleInteractiveSessionRequest
                .maximumAllowedSessionBytes,
            expectedUserID > 0
        else {
            throw InvestigationLifecycleAppServerTransportError
                .invalidConfiguration
        }
        self.investigationID = investigationID
        self.expectedUserID = expectedUserID
        self.validBefore = validBefore
        self.maximumLineBytes = maximumLineBytes
        self.maximumSessionBytes = maximumSessionBytes
        self.now = now
        self.operationID = operationID
        self.session = session
    }

    package func writeLine(_ line: Data) async throws {
        try await acquireOperation(cancellationSensitive: true)
        defer { releaseOperation() }
        try Task.checkCancellation()
        do {
            try await startIfNeeded()
            guard state == .active else {
                throw InvestigationLifecycleAppServerTransportError
                    .invalidState
            }
            try requireUnexpired()
            try account(line)
            let request = try LifecycleInteractiveSessionRequest.write(
                investigationID: investigationID,
                operationID: operationID(),
                line: line
            )
            try Task.checkCancellation()
            let response = try await session.send(request)
            try requireUnexpired()
            let validated = try response.validated(for: request)
            guard validated.kind == .writeAccepted else {
                throw InvestigationLifecycleAppServerTransportError
                    .identityMismatch
            }
        } catch {
            fail()
            throw map(error)
        }
    }

    package func readLine() async throws -> Data {
        try await acquireOperation(cancellationSensitive: true)
        defer { releaseOperation() }
        try Task.checkCancellation()
        do {
            try await startIfNeeded()
            guard state == .active else {
                throw InvestigationLifecycleAppServerTransportError
                    .invalidState
            }
            try requireUnexpired()
            let request = LifecycleInteractiveSessionRequest.read(
                investigationID: investigationID,
                operationID: try operationID()
            )
            try Task.checkCancellation()
            let response = try await session.send(request)
            try requireUnexpired()
            let validated = try response.validated(for: request)
            switch validated.kind {
            case .line:
                guard let line = validated.line else {
                    throw InvestigationLifecycleAppServerTransportError
                        .identityMismatch
                }
                try account(line)
                return line
            case .endOfStream:
                throw InvestigationLifecycleAppServerTransportError
                    .unexpectedEndOfStream
            default:
                throw InvestigationLifecycleAppServerTransportError
                    .identityMismatch
            }
        } catch {
            fail()
            throw map(error)
        }
    }

    package func retire() async throws {
        try await acquireOperation(cancellationSensitive: false)
        defer { releaseOperation() }
        guard state != .retired, state != .retiring else {
            throw InvestigationLifecycleAppServerTransportError
                .invalidState
        }
        do {
            guard state == .ready || state == .active || state == .failed else {
                throw InvestigationLifecycleAppServerTransportError
                    .invalidState
            }
            state = .retiring
            let retirementStartedAt = now()
            let request = LifecycleInteractiveSessionRequest.retire(
                investigationID: investigationID,
                operationID: try operationID()
            )
            let response = try await session.send(request)
            let validated = try response.validated(for: request)
            guard
                validated.kind == .retired,
                validated.drained == true,
                let observation = validated.residueObservation
            else {
                throw InvestigationLifecycleAppServerTransportError
                    .drainUnconfirmed
            }
            guard
                observation.investigationID == investigationID,
                observation.userID == expectedUserID
            else {
                throw InvestigationLifecycleAppServerTransportError
                    .identityMismatch
            }
            let observedNow = now()
            guard
                observation.observedAt >= retirementStartedAt,
                observation.observedAt <= observedNow,
                observedNow.timeIntervalSince(observation.observedAt)
                    <= 60,
                observation.provedEmpty
            else {
                throw InvestigationLifecycleAppServerTransportError
                    .drainUnconfirmed
            }
            residueObservation = observation
            state = .retired
        } catch {
            fail()
            throw map(error)
        }
    }

    package func acceptedResidueObservation() throws
        -> LifecycleInvestigationResidueObservation
    {
        guard state == .retired, let residueObservation else {
            throw InvestigationLifecycleAppServerTransportError
                .drainUnconfirmed
        }
        return residueObservation
    }

    private func startIfNeeded() async throws {
        switch state {
        case .active:
            return
        case .ready:
            state = .starting
        case .starting, .retiring, .failed, .retired:
            throw InvestigationLifecycleAppServerTransportError
                .invalidState
        }
        do {
            try requireUnexpired()
            let request = try LifecycleInteractiveSessionRequest.start(
                investigationID: investigationID,
                operationID: operationID(),
                validBefore: validBefore,
                maximumLineBytes: maximumLineBytes,
                maximumSessionBytes: maximumSessionBytes
            )
            try Task.checkCancellation()
            let response = try await session.send(request)
            try requireUnexpired()
            let validated = try response.validated(for: request)
            guard validated.kind == .started else {
                throw InvestigationLifecycleAppServerTransportError
                    .identityMismatch
            }
            guard state == .starting else {
                throw InvestigationLifecycleAppServerTransportError
                    .invalidState
            }
            state = .active
        } catch {
            fail()
            throw map(error)
        }
    }

    private func account(_ line: Data) throws {
        guard
            line.count <= maximumLineBytes,
            line.last == 0x0A,
            !line.dropLast().contains(0x00)
        else {
            throw InvestigationLifecycleAppServerTransportError
                .inputLimitExceeded
        }
        let total = transferredBytes.addingReportingOverflow(line.count)
        guard
            !total.overflow,
            total.partialValue <= maximumSessionBytes
        else {
            throw InvestigationLifecycleAppServerTransportError
                .inputLimitExceeded
        }
        transferredBytes = total.partialValue
    }

    private func requireUnexpired() throws {
        guard now() < validBefore else {
            throw InvestigationLifecycleAppServerTransportError
                .invalidConfiguration
        }
    }

    private func acquireOperation(
        cancellationSensitive: Bool
    ) async throws {
        if cancellationSensitive {
            try Task.checkCancellation()
        }
        if !operationInProgress {
            operationInProgress = true
            return
        }
        let waiterID = UUID()
        pendingOperationWaiterIDs.insert(waiterID)
        let acquired: Bool
        if cancellationSensitive {
            acquired = await withTaskCancellationHandler {
                await enqueueOperationWaiter(waiterID)
            } onCancel: {
                Task {
                    await self.cancelOperationWaiter(waiterID)
                }
            }
        } else {
            acquired = await enqueueOperationWaiter(waiterID)
        }
        guard acquired else {
            throw CancellationError()
        }
    }

    private func enqueueOperationWaiter(_ id: UUID) async -> Bool {
        await withCheckedContinuation {
            pendingOperationWaiterIDs.remove(id)
            if cancelledOperationWaiterIDs.remove(id) != nil {
                $0.resume(returning: false)
                return
            }
            operationWaiters.append((id: id, continuation: $0))
        }
    }

    private func releaseOperation() {
        if operationWaiters.isEmpty {
            operationInProgress = false
        } else {
            operationWaiters.removeFirst().continuation.resume(
                returning: true
            )
        }
    }

    private func cancelOperationWaiter(_ id: UUID) {
        guard
            let index = operationWaiters.firstIndex(where: {
                $0.id == id
            })
        else {
            if pendingOperationWaiterIDs.contains(id) {
                cancelledOperationWaiterIDs.insert(id)
            }
            return
        }
        operationWaiters.remove(at: index).continuation.resume(
            returning: false
        )
    }

    private func fail() {
        guard state != .retired else {
            return
        }
        state = .failed
    }

    private func map(
        _ error: any Error
    ) -> InvestigationLifecycleAppServerTransportError {
        if let error =
            error as? InvestigationLifecycleAppServerTransportError
        {
            return error
        }
        if
            error as? LifecycleInteractiveSessionContractError
                == .identityMismatch
        {
            return .identityMismatch
        }
        return .transportFailed
    }
}
