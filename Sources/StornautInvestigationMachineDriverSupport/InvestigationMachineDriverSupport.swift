import Darwin

public enum InvestigationMachineDriverSupport {
    package static let rootAuthorityRequiredExitStatus: Int32 = 77
    package static let handoffUnavailableExitStatus: Int32 = 78

    public static func run() async -> Int32 {
        status(effectiveUserID: geteuid())
    }

    static func status(effectiveUserID: uid_t) -> Int32 {
        guard effectiveUserID == 0 else {
            return rootAuthorityRequiredExitStatus
        }
        return handoffUnavailableExitStatus
    }
}
