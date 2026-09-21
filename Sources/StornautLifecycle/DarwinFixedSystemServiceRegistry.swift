import Darwin
import Foundation
import ServiceManagement

package enum LifecycleFixedSystemServiceState: Sendable, Equatable {
    case absent
    case registered(processID: pid_t?)
    case unavailable(reasonKey: String)
}

enum LifecycleFixedSystemServiceRegistrationStatus: Sendable, Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
    case unknown
}

enum LifecycleFixedSystemServiceJobLookup: Sendable, Equatable {
    case missing
    case present(label: String, processID: Int64?, fieldCount: Int)
    case unavailable
}

protocol LifecycleFixedSystemServiceInspecting: Sendable {
    func registrationStatus(
        plistURL: URL
    ) -> LifecycleFixedSystemServiceRegistrationStatus

    func job(
        label: String
    ) -> LifecycleFixedSystemServiceJobLookup
}

struct DarwinLifecycleFixedSystemServiceInspector:
    LifecycleFixedSystemServiceInspecting,
    Sendable
{
    func registrationStatus(
        plistURL: URL
    ) -> LifecycleFixedSystemServiceRegistrationStatus {
        switch SMAppService.statusForLegacyPlist(at: plistURL) {
        case .notRegistered: .notRegistered
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .unknown
        }
    }

    func job(
        label: String
    ) -> LifecycleFixedSystemServiceJobLookup {
        guard let domain = kSMDomainSystemLaunchd else {
            return .unavailable
        }
        guard let unmanaged = SMJobCopyDictionary(
            domain,
            label as CFString
        ) else {
            return .missing
        }
        let dictionary = unmanaged.takeRetainedValue() as NSDictionary
        let processID: Int64?
        if let number = dictionary["PID"] as? NSNumber {
            processID = number.int64Value
        } else if dictionary["PID"] == nil {
            processID = nil
        } else {
            return .unavailable
        }
        guard let observedLabel = dictionary["Label"] as? String else {
            return .unavailable
        }
        return .present(
            label: observedLabel,
            processID: processID,
            fieldCount: dictionary.count
        )
    }
}

package struct DarwinLifecycleFixedSystemServiceRegistry: Sendable {
    private let inspector: any LifecycleFixedSystemServiceInspecting

    package init() {
        inspector = DarwinLifecycleFixedSystemServiceInspector()
    }

    init(inspector: any LifecycleFixedSystemServiceInspecting) {
        self.inspector = inspector
    }

    package func lookup() -> LifecycleFixedSystemServiceState {
        guard let contract = try? LifecycleLocalInstallationContract() else {
            return .unavailable(
                reasonKey: "runtime.topology.service-registry-unavailable"
            )
        }
        let status = inspector.registrationStatus(
            plistURL: contract.launchDaemonPlistURL
        )
        let job = inspector.job(
            label: contract.label
        )
        if job == .missing,
           status == .notRegistered || status == .notFound
        {
            return .absent
        }
        guard
            status == .enabled,
            case let .present(label, rawProcessID, fieldCount) = job,
            label == contract.label,
            fieldCount > 0,
            fieldCount <= 128
        else {
            return .unavailable(
                reasonKey: "runtime.topology.service-registry-unavailable"
            )
        }
        let processID: pid_t?
        if let rawProcessID,
           rawProcessID > 1,
           rawProcessID <= Int64(Int32.max)
        {
            processID = pid_t(rawProcessID)
        } else if rawProcessID == nil {
            processID = nil
        } else {
            return .unavailable(
                reasonKey: "runtime.topology.service-registry-unavailable"
            )
        }
        return .registered(processID: processID)
    }
}
