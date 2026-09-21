import Testing
@testable import StornautLifecycle

@Suite("Lifecycle Spike command")
struct LifecycleSpikeCommandTests {
    @Test
    func parsesOnlyTheClosedDrainCommand() throws {
        let command = try LifecycleSpikeCommand(arguments: [
            "drain",
            "--audit-session-id",
            "44001",
            "--user-id",
            "501",
            "--protect-current-process",
        ])

        #expect(command == .drain(
            auditSessionID: 44_001,
            userID: 501,
            protectCurrentProcess: true
        ))
    }

    @Test(arguments: [
        [],
        ["spawn", "/bin/sh"],
        ["drain", "--pid", "123"],
        ["drain", "--signal", "9"],
        ["drain", "--audit-session-id", "0", "--user-id", "501"],
        ["drain", "--audit-session-id", "44001", "--user-id", "0"],
        [
            "drain",
            "--audit-session-id",
            "44001",
            "--audit-session-id",
            "44002",
            "--user-id",
            "501",
        ],
        [
            "drain",
            "--audit-session-id",
            "44001",
            "--user-id",
            "501",
            "--unknown",
        ],
    ])
    func rejectsEveryOtherSurface(arguments: [String]) {
        #expect(throws: LifecycleSpikeCommandError.self) {
            _ = try LifecycleSpikeCommand(arguments: arguments)
        }
    }
}
