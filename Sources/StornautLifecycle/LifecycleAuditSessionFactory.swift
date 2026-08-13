import Darwin
import Foundation

public struct LifecycleAuditSessionLaunchRequest:
    Sendable,
    Equatable
{
    public let userID: uid_t
    public let groupID: gid_t
    public let username: String

    public init(
        userID: uid_t,
        groupID: gid_t,
        username: String
    ) {
        self.userID = userID
        self.groupID = groupID
        self.username = username
    }
}

public enum LifecycleAuditSessionFactoryError:
    Error,
    Sendable,
    Equatable
{
    case invalidRequest
    case operationFailed
    case invalidAuditSession
}

public struct LifecycleInheritedSessionAdmission: Sendable {
    public init() {}

    public func validate(
        expectedProcessID: pid_t,
        expectedUserID: uid_t,
        helperIdentity: LifecycleProcessIdentity,
        childIdentity: LifecycleProcessIdentity
    ) -> Bool {
        expectedProcessID > 1
            && expectedUserID > 0
            && helperIdentity.processID > 1
            && helperIdentity.processIDVersion > 0
            && helperIdentity.effectiveUserID == 0
            && helperIdentity.auditSessionID > 0
            && childIdentity.processID == expectedProcessID
            && childIdentity.processIDVersion > 0
            && childIdentity.effectiveUserID == expectedUserID
            && childIdentity.auditSessionID
                == helperIdentity.auditSessionID
    }
}

public protocol LifecycleAuditSessionOperating: Sendable {
    func assignAuditSession() throws
    func currentAuditSessionID() throws -> Int32
    func initializeGroups(username: String, groupID: gid_t) throws
    func setGroupID(_ groupID: gid_t) throws
    func setUserID(_ userID: uid_t) throws
    func verifyIdentity(userID: uid_t, groupID: gid_t) throws
}

public struct LifecycleAuditSessionFactory: Sendable {
    private let operations: any LifecycleAuditSessionOperating

    public init(
        operations: any LifecycleAuditSessionOperating
            = DarwinLifecycleAuditSessionOperations()
    ) {
        self.operations = operations
    }

    public func prepareChild(
        _ request: LifecycleAuditSessionLaunchRequest
    ) throws -> Int32 {
        guard
            request.userID > 0,
            request.groupID > 0,
            !request.username.isEmpty,
            request.username.utf8.count <= 256,
            request.username.unicodeScalars.allSatisfy({
                $0.value >= 0x21 && $0.value != 0x7F
            })
        else {
            throw LifecycleAuditSessionFactoryError.invalidRequest
        }
        do {
            try operations.assignAuditSession()
            let auditSessionID = try operations.currentAuditSessionID()
            guard auditSessionID > 0 else {
                throw LifecycleAuditSessionFactoryError.invalidAuditSession
            }
            try operations.initializeGroups(
                username: request.username,
                groupID: request.groupID
            )
            try operations.setGroupID(request.groupID)
            try operations.setUserID(request.userID)
            try operations.verifyIdentity(
                userID: request.userID,
                groupID: request.groupID
            )
            return auditSessionID
        } catch let error as LifecycleAuditSessionFactoryError {
            throw error
        } catch {
            throw LifecycleAuditSessionFactoryError.operationFailed
        }
    }
}

public struct DarwinLifecycleAuditSessionOperations:
    LifecycleAuditSessionOperating,
    Sendable
{
    public init() {}

    public func assignAuditSession() throws {
        guard geteuid() == 0 else {
            throw LifecycleAuditSessionFactoryError.operationFailed
        }
        var information = auditinfo_addr_t()
        guard
            getaudit_addr(
                &information,
                Int32(MemoryLayout.size(ofValue: information))
            ) == 0
        else {
            throw LifecycleAuditSessionFactoryError.operationFailed
        }
        information.ai_asid = au_asid_t(AU_ASSIGN_ASID)
        guard
            setaudit_addr(
                &information,
                Int32(MemoryLayout.size(ofValue: information))
            ) == 0,
            information.ai_asid > 0
        else {
            throw LifecycleAuditSessionFactoryError.operationFailed
        }
    }

    public func currentAuditSessionID() throws -> Int32 {
        try currentLifecycleAuditSessionID()
    }

    public func initializeGroups(
        username: String,
        groupID: gid_t
    ) throws {
        guard
            groupID <= gid_t(Int32.max),
            initgroups(username, Int32(groupID)) == 0
        else {
            throw LifecycleAuditSessionFactoryError.operationFailed
        }
    }

    public func setGroupID(_ groupID: gid_t) throws {
        guard Darwin.setgid(groupID) == 0 else {
            throw LifecycleAuditSessionFactoryError.operationFailed
        }
    }

    public func setUserID(_ userID: uid_t) throws {
        guard Darwin.setuid(userID) == 0 else {
            throw LifecycleAuditSessionFactoryError.operationFailed
        }
    }

    public func verifyIdentity(
        userID: uid_t,
        groupID: gid_t
    ) throws {
        guard
            geteuid() == userID,
            getuid() == userID,
            getegid() == groupID,
            getgid() == groupID
        else {
            throw LifecycleAuditSessionFactoryError.operationFailed
        }
    }
}
