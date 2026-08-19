import Darwin

public enum InvestigationMachineDriverSupport {
    package static let rootAuthorityRequiredExitStatus: Int32 = 77
    package static let handoffUnavailableExitStatus: Int32 = 78
    package static let installedObservationUnavailableExitStatus: Int32 = 79

    public static func run() async -> Int32 {
        run(
            realUserID: getuid,
            effectiveUserID: geteuid,
            realGroupID: getgid,
            effectiveGroupID: getegid,
            argumentCount: { Int32(CommandLine.argc) },
            source: InvestigationMachineInstalledDriverSystemSource(
                system: DarwinInvestigationMachineInstalledDriverSystem()
            )
        )
    }

    static func status(effectiveUserID: uid_t) -> Int32 {
        guard effectiveUserID == 0 else {
            return rootAuthorityRequiredExitStatus
        }
        return handoffUnavailableExitStatus
    }

    static func run(
        realUserID: @escaping @Sendable () -> uid_t,
        effectiveUserID: @escaping @Sendable () -> uid_t,
        realGroupID: @escaping @Sendable () -> gid_t,
        effectiveGroupID: @escaping @Sendable () -> gid_t,
        argumentCount: @escaping @Sendable () -> Int32,
        source: any InvestigationMachineInstalledDriverObservationSource
    ) -> Int32 {
        let observer = InvestigationMachineInstalledDriverObserver(
            realUserID: realUserID,
            effectiveUserID: effectiveUserID,
            realGroupID: realGroupID,
            effectiveGroupID: effectiveGroupID,
            argumentCount: argumentCount,
            source: source
        )
        do {
            _ = try observer.observe()
            return handoffUnavailableExitStatus
        } catch InvestigationMachineInstalledDriverObservationError
            .rootAuthorityRequired
        {
            return rootAuthorityRequiredExitStatus
        } catch {
            return installedObservationUnavailableExitStatus
        }
    }
}
