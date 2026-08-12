import Darwin
import Foundation
import StornautLifecycle

do {
    guard geteuid() == 0 else {
        throw LifecycleSpikeError.rootRequired
    }
    let command = try LifecycleSpikeCommand(
        arguments: Array(CommandLine.arguments.dropFirst())
    )
    switch command {
    case let .drain(
        auditSessionID,
        userID,
        protectCurrentProcess
    ):
        let inventory = DarwinLifecycleInventory(
            expectedUserID: userID,
            privilegedProcessID: protectCurrentProcess
                ? getpid()
                : nil
        )
        let protectedIdentity = protectCurrentProcess
            ? try inventory.identity(for: getpid())
            : nil
        let report = try LifecycleSessionDrainer(
            inventory: inventory,
            signaler: DarwinLifecycleSignaler(inventory: inventory)
        ).drain(
            auditSessionID: auditSessionID,
            expectedUserID: userID,
            supervisorIdentity: protectedIdentity
        )
        print("lifecycle.audit_session_id=\(report.auditSessionID)")
        print("lifecycle.freeze_passes=\(report.freezePasses)")
        print("lifecycle.kill_passes=\(report.killPasses)")
        print("lifecycle.unique_member_count=\(report.uniqueMemberCount)")
        print("lifecycle.outcome=\(report.outcome.rawValue)")
    }
} catch {
    FileHandle.standardError.write(
        Data("lifecycle.error=\(String(describing: error))\n".utf8)
    )
    exit(1)
}

private enum LifecycleSpikeError: Error {
    case rootRequired
}
