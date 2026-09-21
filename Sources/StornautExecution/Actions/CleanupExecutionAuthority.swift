import Foundation
import StornautCore

package protocol TrashAdapting: Sendable {
    func trashItem(at url: URL) throws -> URL?
}

package enum TrashAdapterError: Error, Sendable, Equatable {
    case permissionDenied
    case operationFailed(String)
}

package struct FileManagerTrashAdapter: TrashAdapting {
    package init() {}

    package func trashItem(at url: URL) throws -> URL? {
        var resultingURL: NSURL?
        do {
            try FileManager.default.trashItem(
                at: url,
                resultingItemURL: &resultingURL
            )
            return resultingURL as URL?
        } catch let error as CocoaError
            where error.code == .fileReadNoPermission
                || error.code == .fileWriteNoPermission
        {
            throw TrashAdapterError.permissionDenied
        } catch {
            throw TrashAdapterError.operationFailed(
                String(describing: error)
            )
        }
    }
}

package typealias TrashMovingError = CleanupActionExecutionFailure

package struct TrashMoving: Sendable {
    private let adapter: any TrashAdapting

    package init(adapter: any TrashAdapting) {
        self.adapter = adapter
    }

    package func trashItem(
        at url: URL,
        expectedIdentity: ActionFileIdentity
    ) async throws -> TrashedItemReceipt {
        try Task.checkCancellation()
        guard let observedIdentity = ActionFileIdentity.read(at: url) else {
            throw TrashMovingError.missingItem
        }
        guard observedIdentity == expectedIdentity else {
            throw TrashMovingError.identityChanged
        }
        try Task.checkCancellation()

        let resultingURL: URL?
        do {
            resultingURL = try adapter.trashItem(at: url)
        } catch TrashAdapterError.permissionDenied {
            throw TrashMovingError.permissionDenied
        } catch let TrashAdapterError.operationFailed(reason) {
            throw TrashMovingError.operationFailed(reason)
        } catch {
            throw TrashMovingError.operationFailed(
                String(describing: error)
            )
        }

        if ActionFileIdentity.read(at: url) == expectedIdentity {
            throw TrashMovingError.postconditionFailed
        }
        if let resultingURL,
           ActionFileIdentity.read(at: resultingURL) != expectedIdentity
        {
            throw TrashMovingError.postconditionFailed
        }

        return TrashedItemReceipt(
            originalURL: url,
            originalIdentity: expectedIdentity,
            resultingTrashURL: resultingURL,
            movedAt: Date(),
            logicalBytesMoved: expectedIdentity.size,
            allocatedBytesMoved: expectedIdentity.allocatedBytes
        )
    }
}

package struct ActionExecutor: CleanupActionExecuting, Sendable {
    private let policyGate: ActionPolicyGate
    private let trashMoving: TrashMoving
    private let registeredActionRunner: any RegisteredActionRunning

    package init(
        policyGate: ActionPolicyGate,
        trashMoving: TrashMoving,
        registeredActionRunner: any RegisteredActionRunning
    ) {
        self.policyGate = policyGate
        self.trashMoving = trashMoving
        self.registeredActionRunner = registeredActionRunner
    }

    package func preflight(
        _ action: CleanupAction,
        context: ActionPolicyContext
    ) throws -> ActionPreflightToken {
        try policyGate.preflight(action, context: context)
    }

    package func execute(
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

    package func postflight(
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

private struct DenyRegisteredActionRunner: RegisteredActionRunning {
    func run(
        _ invocation: RegisteredActionInvocation
    ) async throws -> RegisteredActionProcessOutput {
        _ = invocation
        throw RegisteredActionRunnerError.launchFailed(
            "registered actions are unavailable"
        )
    }
}

public extension CleanupExecutionRuntime {
    static func production(
        store: EvidenceStore,
        rootObserver: any CleanupPolicyRootObserving,
        workflowCoordinator: CleanupWorkflowCoordinator
    ) throws -> CleanupExecutionRuntime {
        let collector = try CleanupPolicyContextCollector(
            store: store,
            rootObserver: rootObserver,
            workflowObserver: workflowCoordinator
        )
        let authorizationController = CleanupAuthorizationController()
        return CleanupExecutionRuntime(
            collect: { plan, selection in
                await collector.collect(
                    plan: plan,
                    selection: selection
                )
            },
            authorizationController: authorizationController,
            coordinator: CleanupExecutionCoordinator(
                store: store,
                authorizationController: authorizationController,
                workflowCoordinator: workflowCoordinator,
                itemCollector: collector,
                executor: ActionExecutor(
                    policyGate: ActionPolicyGate(
                        registry: ActionRegistry(definitions: [])
                    ),
                    trashMoving: TrashMoving(
                        adapter: FileManagerTrashAdapter()
                    ),
                    registeredActionRunner: DenyRegisteredActionRunner()
                ),
                volumeSampler: FoundationCleanupVolumeSampler()
            )
        )
    }

#if DEBUG
    static func diagnostic(
        store: EvidenceStore,
        rootObserver: any CleanupPolicyRootObserving,
        workflowCoordinator: CleanupWorkflowCoordinator,
        resolver: ExecutableEvidenceResolver,
        observation: CleanupTrashDiagnosticObservation
    ) throws -> CleanupExecutionRuntime {
        let collector = try CleanupPolicyContextCollector
            .phaseCTrashDiagnostic(
                store: store,
                resolver: resolver,
                rootObserver: rootObserver,
                workflowObserver: workflowCoordinator
            )
        let authorizationController = CleanupAuthorizationController()
        return CleanupExecutionRuntime(
            collect: { plan, selection in
                await collector.collect(
                    plan: plan,
                    selection: selection
                )
            },
            authorizationController: authorizationController,
            coordinator: CleanupExecutionCoordinator(
                store: store,
                authorizationController: authorizationController,
                workflowCoordinator: workflowCoordinator,
                itemCollector: collector,
                executor: ActionExecutor(
                    policyGate: ActionPolicyGate(
                        registry: ActionRegistry(definitions: [])
                    ),
                    trashMoving: TrashMoving(
                        adapter: RecordingFileManagerTrashAdapter(
                            observation: observation
                        )
                    ),
                    registeredActionRunner: DenyRegisteredActionRunner()
                ),
                volumeSampler: FoundationCleanupVolumeSampler()
            )
        )
    }
#endif
}

#if DEBUG
private struct RecordingFileManagerTrashAdapter: TrashAdapting {
    let observation: CleanupTrashDiagnosticObservation

    func trashItem(at url: URL) throws -> URL? {
        observation.recordAttempt()
        let result = try FileManagerTrashAdapter().trashItem(at: url)
        observation.record(returnedTrashURL: result)
        return result
    }
}
#endif
