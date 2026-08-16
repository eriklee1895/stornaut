import Foundation

package protocol CleanupActionExecuting: Sendable {
    func preflight(
        _ action: CleanupAction,
        context: ActionPolicyContext
    ) throws -> ActionPreflightToken
    func execute(
        _ token: ActionPreflightToken,
        context: ActionPolicyContext
    ) async throws -> ActionExecution
    func postflight(_ execution: ActionExecution) throws -> ActionResult
}

package enum CleanupActionExecutionFailure:
    Error,
    Sendable,
    Equatable
{
    case permissionDenied
    case missingItem
    case identityChanged
    case postconditionFailed
    case operationFailed(String)
}
