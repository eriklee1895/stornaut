import Foundation

public struct ActionExecutor: Sendable {
    private let policyGate: ActionPolicyGate
    private let trashMoving: TrashMoving
    private let registeredActionRunner: any RegisteredActionRunning

    public init(
        policyGate: ActionPolicyGate,
        trashMoving: TrashMoving = TrashMoving(),
        registeredActionRunner: any RegisteredActionRunning =
            FoundationRegisteredActionRunner()
    ) {
        self.policyGate = policyGate
        self.trashMoving = trashMoving
        self.registeredActionRunner = registeredActionRunner
    }

    public func preflight(
        _ action: CleanupAction,
        context: ActionPolicyContext
    ) throws -> ActionPreflightToken {
        try policyGate.preflight(action, context: context)
    }

    public func execute(
        _ token: ActionPreflightToken,
        context: ActionPolicyContext
    ) async throws -> ActionExecution {
        try Task.checkCancellation()
        let action = try policyGate.revalidate(token, context: context)
        try Task.checkCancellation()
        let startedAt = Date()

        switch action {
        case let .moveToTrash(pathAction):
            let receipt = try await trashMoving.trashItem(
                at: pathAction.targetURL,
                expectedIdentity: pathAction.expectedIdentity
            )
            return .trash(
                receipt: receipt,
                startedAt: startedAt,
                finishedAt: Date()
            )
        case let .runRegisteredAction(request):
            guard let invocation = token.registeredInvocation,
                  invocation.id == request.id,
                  invocation.mode == request.mode
            else {
                throw ActionExecutionError.invalidPreflightToken
            }
            if request.mode == .dryRun {
                return .registered(
                    invocation: invocation,
                    output: nil,
                    startedAt: startedAt,
                    finishedAt: Date()
                )
            }
            do {
                let output = try await registeredActionRunner.run(invocation)
                return .registered(
                    invocation: invocation,
                    output: output,
                    startedAt: startedAt,
                    finishedAt: Date()
                )
            } catch RegisteredActionRunnerError.timedOut {
                throw ActionExecutionError.timedOut
            } catch let RegisteredActionRunnerError.launchFailed(reason) {
                throw ActionExecutionError.launchFailed(reason)
            } catch let RegisteredActionRunnerError.outputReadFailed(
                stream,
                reason
            ) {
                throw ActionExecutionError.outputReadFailed(
                    stream: stream,
                    reason: reason
                )
            } catch let RegisteredActionRunnerError.terminationFailed(error) {
                throw ActionExecutionError.terminationFailed(error)
            }
        }
    }

    public func postflight(
        _ execution: ActionExecution
    ) throws -> ActionResult {
        switch execution {
        case let .trash(receipt, startedAt, finishedAt):
            return ActionResult(
                status: .succeeded,
                logicalBytesAffected: receipt.logicalBytesMoved,
                allocatedBytesAffected: receipt.allocatedBytesMoved,
                completedItems: 1,
                failedItems: 0,
                exitStatus: nil,
                startedAt: startedAt,
                finishedAt: finishedAt,
                trashReceipt: receipt
            )
        case let .registered(
            invocation,
            output,
            startedAt,
            finishedAt
        ):
            if invocation.mode == .dryRun {
                guard output == nil else {
                    throw ActionExecutionError.unexpectedResult
                }
                return ActionResult(
                    status: .dryRun,
                    logicalBytesAffected: 0,
                    allocatedBytesAffected: 0,
                    completedItems: 0,
                    failedItems: 0,
                    exitStatus: nil,
                    startedAt: startedAt,
                    finishedAt: finishedAt,
                    trashReceipt: nil
                )
            }
            guard let output else {
                throw ActionExecutionError.unexpectedResult
            }
            guard !output.stdoutWasTruncated,
                  !output.stderrWasTruncated
            else {
                throw ActionExecutionError.outputTruncated
            }
            let report: RegisteredActionReport
            do {
                report = try JSONDecoder().decode(
                    RegisteredActionReport.self,
                    from: output.stdout
                )
            } catch {
                throw ActionExecutionError.malformedOutput
            }
            guard report.logicalBytesAffected >= 0,
                  report.allocatedBytesAffected >= 0,
                  report.completedItems >= 0,
                  report.failedItems >= 0
            else {
                throw ActionExecutionError.malformedOutput
            }
            switch invocation.mode {
            case .success:
                guard output.exitStatus == 0,
                      report.status == .succeeded,
                      report.failedItems == 0
                else {
                    throw ActionExecutionError.unexpectedResult
                }
            case .partialFailure:
                guard output.exitStatus != 0,
                      report.status == .partiallyFailed,
                      report.failedItems > 0
                else {
                    throw ActionExecutionError.unexpectedResult
                }
            case .dryRun, .timeout:
                throw ActionExecutionError.unexpectedResult
            }
            return ActionResult(
                status: report.status,
                logicalBytesAffected: report.logicalBytesAffected,
                allocatedBytesAffected: report.allocatedBytesAffected,
                completedItems: report.completedItems,
                failedItems: report.failedItems,
                exitStatus: output.exitStatus,
                startedAt: startedAt,
                finishedAt: finishedAt,
                trashReceipt: nil
            )
        }
    }
}

private struct RegisteredActionReport: Decodable {
    let status: ActionResultStatus
    let logicalBytesAffected: Int64
    let allocatedBytesAffected: Int64
    let completedItems: Int
    let failedItems: Int
}
