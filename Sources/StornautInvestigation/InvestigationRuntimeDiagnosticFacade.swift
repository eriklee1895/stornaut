import Foundation
import StornautCore

public enum InvestigationRuntimeDiagnosticFacadeError:
    Error,
    Sendable,
    Equatable
{
    case noActiveRun
    case runAlreadyActive
}

package protocol InvestigationProductionSessionDriving:
    InvestigationRuntimeOwning
{
    func nextValidatedAppServerLine(
        rootSessionID: DomainToken
    ) async throws -> Data?
}

public actor InvestigationRuntimeDiagnosticFacade {
    private struct ActiveIdentity {
        let investigationID: InvestigationID
        let runID: InvestigationRunID
        let rootSessionID: DomainToken
    }

    private let coordinator: InvestigationCoordinator
    private let session: any InvestigationProductionSessionDriving
    private var activeIdentity: ActiveIdentity?

    package init(
        store: any InvestigationStoreOwning,
        session: any InvestigationProductionSessionDriving,
        lifecycle: any InvestigationLifecycleOwning,
        probe: any InvestigationProbeOwning,
        idProvider: any InvestigationIDProviding,
        monotonicNow: @escaping @Sendable () -> UInt64,
        wallNow: @escaping @Sendable () -> Date = Date.init
    ) {
        self.session = session
        coordinator = InvestigationCoordinator(
            store: store,
            runtime: session,
            lifecycle: lifecycle,
            probe: probe,
            idProvider: idProvider,
            monotonicNow: monotonicNow,
            wallNow: wallNow
        )
    }

    public func start(
        _ admission: InvestigationStartAdmissionV1
    ) async throws -> InvestigationStartResultV1 {
        guard activeIdentity == nil else {
            throw InvestigationRuntimeDiagnosticFacadeError
                .runAlreadyActive
        }
        let started = try await coordinator.start(admission)
        activeIdentity = ActiveIdentity(
            investigationID: started.investigationID,
            runID: started.runID,
            rootSessionID: started.rootSessionID
        )
        return started
    }

    public func forwardNextValidatedAppServerLine()
        async throws -> Bool
    {
        let identity = try requireActiveIdentity()
        let line: Data?
        do {
            line = try await session.nextValidatedAppServerLine(
                rootSessionID: identity.rootSessionID
            )
        } catch {
            try await revokeAndClean(identity)
            throw error
        }
        guard let line else {
            return false
        }
        try await coordinator.acceptAppServerLine(
            investigationID: identity.investigationID,
            runID: identity.runID,
            line: line
        )
        return true
    }

    public func startTurn(
        threadID: DomainToken,
        turnID: DomainToken,
        contextBytes: Data
    ) async throws -> DomainToken {
        let identity = try requireActiveIdentity()
        do {
            return try await coordinator.startTurn(
                investigationID: identity.investigationID,
                runID: identity.runID,
                threadID: threadID,
                turnID: turnID,
                contextBytes: contextBytes
            ).turnID
        } catch {
            try await revokeAndClean(identity)
            throw error
        }
    }

    public func acceptScientificDelta(
        _ delta: InvestigationScientificDeltaV1
    ) async throws -> InvestigationScientificProgressV1 {
        let identity = try requireActiveIdentity()
        return try await coordinator.acceptScientificDelta(
            investigationID: identity.investigationID,
            runID: identity.runID,
            delta: delta
        )
    }

    public func requestPause()
        async throws -> InvestigationClosingResultV1
    {
        let identity = try requireActiveIdentity()
        return try await coordinator.requestPause(
            investigationID: identity.investigationID,
            runID: identity.runID
        )
    }

    public func requestStop()
        async throws -> InvestigationClosingResultV1
    {
        let identity = try requireActiveIdentity()
        return try await coordinator.requestStop(
            investigationID: identity.investigationID,
            runID: identity.runID
        )
    }

    public func cancel()
        async throws -> InvestigationClosingResultV1
    {
        let identity = try requireActiveIdentity()
        return try await coordinator.cancel(
            investigationID: identity.investigationID,
            runID: identity.runID
        )
    }

    public func settle() async throws -> InvestigationTerminalResult {
        let identity = try requireActiveIdentity()
        let result = try await coordinator.settle(
            investigationID: identity.investigationID,
            runID: identity.runID
        )
        activeIdentity = nil
        return result
    }

    private func requireActiveIdentity() throws -> ActiveIdentity {
        guard let activeIdentity else {
            throw InvestigationRuntimeDiagnosticFacadeError.noActiveRun
        }
        return activeIdentity
    }

    private func revokeAndClean(
        _ identity: ActiveIdentity
    ) async throws {
        activeIdentity = nil
        do {
            try await coordinator.failClosedTransport(
                investigationID: identity.investigationID,
                runID: identity.runID
            )
        } catch {
            throw InvestigationCoordinatorError.runtimeCleanupUnconfirmed
        }
    }
}
