import Darwin

public enum InvestigationMachineDriverSupport {
    package static let completedExitStatus: Int32 = 0
    package static let rootAuthorityRequiredExitStatus: Int32 = 77
    package static let handoffUnavailableExitStatus: Int32 = 78
    package static let installedObservationUnavailableExitStatus: Int32 = 79
    package static let invalidInvocationExitStatus: Int32 = 80
    package static let protocolFailureExitStatus: Int32 = 81
    package static let containmentUncertainExitStatus: Int32 = 82
    package static let cancelledExitStatus: Int32 = 83

    public static func run() async -> Int32 {
        await run(
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
    ) async -> Int32 {
        let entry = InvestigationMachineZeroArgumentEntry.production(
            realUserID: realUserID,
            effectiveUserID: effectiveUserID,
            realGroupID: realGroupID,
            effectiveGroupID: effectiveGroupID,
            argumentCount: argumentCount,
            source: source
        )
        return await run(entry: entry)
    }

    static func run(
        entry: InvestigationMachineZeroArgumentEntry
    ) async -> Int32 {
        do {
            try await entry.run()
            return completedExitStatus
        } catch {
            return status(for: error)
        }
    }

    static func status(for error: any Error) -> Int32 {
        guard let error = error as? InvestigationMachineZeroArgumentEntryError
        else {
            return containmentUncertainExitStatus
        }
        return switch error {
        case .rootAuthorityRequired:
            rootAuthorityRequiredExitStatus
        case .installedObservationUnavailable:
            installedObservationUnavailableExitStatus
        case .invalidInvocation, .invalidInput, .invalidRole,
             .invalidOuterDescriptor:
            invalidInvocationExitStatus
        case .protocolFailure, .outputUnavailable, .invalidCompletion:
            protocolFailureExitStatus
        case .containmentUncertain:
            containmentUncertainExitStatus
        case .cancelled:
            cancelledExitStatus
        }
    }
}
