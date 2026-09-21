import Darwin
import Testing
@testable import StornautLifecycle

@Suite("R5 per-investigation audit session")
struct LifecycleAuditSessionFactoryTests {
    @Test
    func createsSessionBeforeIdentityDropAndExecution() throws {
        let operations = RecordingLifecycleAuditSessionOperations(
            assignedAuditSessionID: 44_101
        )
        let request = LifecycleAuditSessionLaunchRequest(
            userID: 501,
            groupID: 20,
            username: "synthetic-user"
        )

        let sessionID = try LifecycleAuditSessionFactory(
            operations: operations
        ).prepareChild(request)

        #expect(sessionID == 44_101)
        #expect(operations.calls == [
            .assignAuditSession,
            .readAuditSession,
            .initializeGroups(username: "synthetic-user", groupID: 20),
            .setGroupID(20),
            .setUserID(501),
            .verifyIdentity(userID: 501, groupID: 20),
        ])
    }

    @Test
    func twoInvestigationsRequireDistinctKernelAssignedSessions() throws {
        let first = RecordingLifecycleAuditSessionOperations(
            assignedAuditSessionID: 44_101
        )
        let second = RecordingLifecycleAuditSessionOperations(
            assignedAuditSessionID: 44_102
        )
        let request = LifecycleAuditSessionLaunchRequest(
            userID: 501,
            groupID: 20,
            username: "synthetic-user"
        )

        let firstID = try LifecycleAuditSessionFactory(
            operations: first
        ).prepareChild(request)
        let secondID = try LifecycleAuditSessionFactory(
            operations: second
        ).prepareChild(request)

        #expect(firstID != secondID)
    }

    @Test(arguments: LifecycleAuditSessionOperationCall.failurePoints)
    fileprivate func anyPreparationFailureStopsBeforeLaterAuthority(
        failingCall: LifecycleAuditSessionOperationCall
    ) {
        let operations = RecordingLifecycleAuditSessionOperations(
            assignedAuditSessionID: 44_101,
            failingCall: failingCall
        )
        let request = LifecycleAuditSessionLaunchRequest(
            userID: 501,
            groupID: 20,
            username: "synthetic-user"
        )

        #expect(throws: LifecycleAuditSessionFactoryError.self) {
            _ = try LifecycleAuditSessionFactory(
                operations: operations
            ).prepareChild(request)
        }
        let failureIndex = LifecycleAuditSessionOperationCall.order
            .firstIndex(of: failingCall)!
        #expect(
            operations.calls
                == Array(
                    LifecycleAuditSessionOperationCall.order
                        .prefix(failureIndex + 1)
                )
        )
    }

    @Test
    func rejectsRootAndMalformedUserIdentityBeforeSyscalls() {
        for request in [
            LifecycleAuditSessionLaunchRequest(
                userID: 0,
                groupID: 20,
                username: "root"
            ),
            LifecycleAuditSessionLaunchRequest(
                userID: 501,
                groupID: 0,
                username: "synthetic-user"
            ),
            LifecycleAuditSessionLaunchRequest(
                userID: 501,
                groupID: 20,
                username: "synthetic\nuser"
            ),
        ] {
            let operations = RecordingLifecycleAuditSessionOperations(
                assignedAuditSessionID: 44_101
            )
            #expect(throws: LifecycleAuditSessionFactoryError.self) {
                _ = try LifecycleAuditSessionFactory(
                    operations: operations
                ).prepareChild(request)
            }
            #expect(operations.calls.isEmpty)
        }
    }

    @Test
    func inheritedSessionAdmissionBindsChildToHelperSessionAndUser() {
        let helper = inheritedProcessIdentity(
            processID: 700,
            auditSessionID: 44_101,
            effectiveUserID: 0
        )
        let child = inheritedProcessIdentity(
            processID: 701,
            auditSessionID: 44_101,
            effectiveUserID: 501
        )

        #expect(
            LifecycleInheritedSessionAdmission().validate(
                expectedProcessID: 701,
                expectedUserID: 501,
                helperIdentity: helper,
                childIdentity: child
            )
        )
        #expect(
            !LifecycleInheritedSessionAdmission().validate(
                expectedProcessID: 701,
                expectedUserID: 502,
                helperIdentity: helper,
                childIdentity: child
            )
        )
        #expect(
            !LifecycleInheritedSessionAdmission().validate(
                expectedProcessID: 701,
                expectedUserID: 501,
                helperIdentity: helper,
                childIdentity: inheritedProcessIdentity(
                    processID: 701,
                    auditSessionID: 44_102,
                    effectiveUserID: 501
                )
            )
        )
    }

}

private func inheritedProcessIdentity(
    processID: pid_t,
    auditSessionID: Int32,
    effectiveUserID: uid_t
) -> LifecycleProcessIdentity {
    LifecycleProcessIdentity(
        processID: processID,
        processIDVersion: 1,
        auditSessionID: auditSessionID,
        effectiveUserID: effectiveUserID,
        auditToken: try! LifecycleAuditToken(
            words: [
                effectiveUserID,
                20,
                effectiveUserID,
                effectiveUserID,
                effectiveUserID,
                UInt32(processID),
                UInt32(auditSessionID),
                1,
            ]
        )
    )
}

private final class RecordingLifecycleAuditSessionOperations:
    LifecycleAuditSessionOperating,
    @unchecked Sendable
{
    let assignedAuditSessionID: Int32
    let failingCall: LifecycleAuditSessionOperationCall?
    private(set) var calls: [LifecycleAuditSessionOperationCall] = []

    init(
        assignedAuditSessionID: Int32,
        failingCall: LifecycleAuditSessionOperationCall? = nil
    ) {
        self.assignedAuditSessionID = assignedAuditSessionID
        self.failingCall = failingCall
    }

    func assignAuditSession() throws {
        try record(.assignAuditSession)
    }

    func currentAuditSessionID() throws -> Int32 {
        try record(.readAuditSession)
        return assignedAuditSessionID
    }

    func initializeGroups(username: String, groupID: gid_t) throws {
        try record(
            .initializeGroups(
                username: username,
                groupID: groupID
            )
        )
    }

    func setGroupID(_ groupID: gid_t) throws {
        try record(.setGroupID(groupID))
    }

    func setUserID(_ userID: uid_t) throws {
        try record(.setUserID(userID))
    }

    func verifyIdentity(userID: uid_t, groupID: gid_t) throws {
        try record(
            .verifyIdentity(userID: userID, groupID: groupID)
        )
    }

    private func record(
        _ call: LifecycleAuditSessionOperationCall
    ) throws {
        calls.append(call)
        if failingCall == call {
            throw LifecycleAuditSessionFactoryError.operationFailed
        }
    }
}

private enum LifecycleAuditSessionOperationCall:
    Sendable,
    Equatable,
    CustomTestStringConvertible
{
    case assignAuditSession
    case readAuditSession
    case initializeGroups(username: String, groupID: gid_t)
    case setGroupID(gid_t)
    case setUserID(uid_t)
    case verifyIdentity(userID: uid_t, groupID: gid_t)

    static let order: [Self] = [
        .assignAuditSession,
        .readAuditSession,
        .initializeGroups(username: "synthetic-user", groupID: 20),
        .setGroupID(20),
        .setUserID(501),
        .verifyIdentity(userID: 501, groupID: 20),
    ]

    static let failurePoints = order

    var testDescription: String {
        String(describing: self)
    }
}
