import Foundation
import StornautCore

public enum InvestigationProbeAdapterError:
    Error,
    Sendable,
    Equatable
{
    case invalidLimits
    case runAlreadyPrepared
    case runIdentityMismatch
}

package final class InvestigationProbeBrokerAdapter:
    InvestigationProbeOwning,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let broker: ProbeBroker
    private let allowedRoots: [URL]
    private let maximumReadLevel: ProbeReadLevel
    private let perCallTimeout: Duration
    private let perCallOutputByteLimit: Int
    private let auditRecorder: ProbeAuditRecorder
    private var preparedRunID: InvestigationRunID?
    private var session: ProbeSessionBudget?

    package init(
        broker: ProbeBroker,
        allowedRoots: [URL],
        maximumReadLevel: ProbeReadLevel,
        perCallTimeout: Duration,
        perCallOutputByteLimit: Int,
        auditRecorder: ProbeAuditRecorder = ProbeAuditRecorder()
    ) {
        self.broker = broker
        self.allowedRoots = allowedRoots
        self.maximumReadLevel = maximumReadLevel
        self.perCallTimeout = perCallTimeout
        self.perCallOutputByteLimit = perCallOutputByteLimit
        self.auditRecorder = auditRecorder
    }

    package func prepare(
        runID: InvestigationRunID,
        limits: InvestigationBudgetLimits
    ) throws {
        guard limits.probeCalls <= UInt64(Int.max),
              limits.probeReadBytes <= UInt64(Int.max),
              limits.probeOutputBytes <= UInt64(Int.max)
        else {
            throw InvestigationProbeAdapterError.invalidLimits
        }
        try lock.withLock {
            if let preparedRunID {
                guard preparedRunID == runID else {
                    throw InvestigationProbeAdapterError.runAlreadyPrepared
                }
                return
            }
            preparedRunID = runID
            session = ProbeSessionBudget(
                limits: ProbeBudgetLimits(
                    maximumCallCount: Int(limits.probeCalls),
                    maximumReadBytes: Int(limits.probeReadBytes),
                    maximumOutputBytes: Int(limits.probeOutputBytes)
                )
            )
        }
    }

    package func execute(
        _ request: ProbeRequest,
        runID: InvestigationRunID
    ) async -> ProbeResult {
        let session = lock.withLock {
            preparedRunID == runID ? self.session : nil
        }
        guard let session else {
            return .failure(.accessFailed)
        }
        return await broker.execute(
            request,
            in: ProbeContext(
                allowedRoots: allowedRoots,
                maximumReadLevel: maximumReadLevel,
                perCallTimeout: perCallTimeout,
                perCallOutputByteLimit: perCallOutputByteLimit,
                session: session,
                auditRecorder: auditRecorder
            )
        )
    }

    package func usage(
        runID: InvestigationRunID
    ) async -> ProbeBudgetUsage? {
        let session = lock.withLock {
            preparedRunID == runID ? self.session : nil
        }
        guard let session else {
            return nil
        }
        return await session.usage
    }
}
