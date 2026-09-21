import Foundation
import ServiceManagement
import StornautInvestigationHandoffContract

enum InvestigationInstalledL2ServiceRegistrationStatus:
    Sendable,
    Equatable
{
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
    case unknown
}

enum InvestigationInstalledL2ServiceJobLookup: Sendable, Equatable {
    case missing
    case present(label: String, processID: Int64?, fieldCount: Int)
    case unavailable
}

protocol InvestigationInstalledL2FixedServiceInspecting: Sendable {
    func registrationStatus(
        plistURL: URL
    ) -> InvestigationInstalledL2ServiceRegistrationStatus

    func job(label: String) -> InvestigationInstalledL2ServiceJobLookup
}

struct InvestigationInstalledL2DarwinFixedServiceInspector:
    InvestigationInstalledL2FixedServiceInspecting,
    Sendable
{
    init() {}

    func registrationStatus(
        plistURL: URL
    ) -> InvestigationInstalledL2ServiceRegistrationStatus {
        switch SMAppService.statusForLegacyPlist(at: plistURL) {
        case .notRegistered: .notRegistered
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .unknown
        }
    }

    func job(label: String) -> InvestigationInstalledL2ServiceJobLookup {
        guard let domain = kSMDomainSystemLaunchd else { return .unavailable }
        guard let unmanaged = SMJobCopyDictionary(
            domain,
            label as CFString
        ) else {
            return .missing
        }
        let dictionary = unmanaged.takeRetainedValue() as NSDictionary
        let processID: Int64?
        if let value = dictionary["PID"] {
            guard let exact = investigationInstalledL2ExactPID(value) else {
                return .unavailable
            }
            processID = exact
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

func investigationInstalledL2ExactPID(_ value: Any) -> Int64? {
    let object = value as AnyObject
    guard
        CFGetTypeID(object) == CFNumberGetTypeID(),
        CFGetTypeID(object) != CFBooleanGetTypeID()
    else {
        return nil
    }
    let number = unsafeDowncast(object, to: CFNumber.self)
    guard !CFNumberIsFloatType(number) else { return nil }
    var exact: Int64 = 0
    guard CFNumberGetValue(number, .sInt64Type, &exact) else { return nil }
    return exact
}

enum InvestigationInstalledL2FixedServiceSample: Sendable, Equatable {
    case absent
    case registered(processID: UInt32)
    case unavailable
}

protocol InvestigationInstalledL2FixedServiceRegistryReading: Sendable {
    func sample() -> InvestigationInstalledL2FixedServiceSample
}

struct InvestigationInstalledL2FixedServiceRegistry:
    InvestigationInstalledL2FixedServiceRegistryReading,
    Sendable
{
    private static let label = "com.eriklee.stornaut.lifecycle"

    private let inspector: any InvestigationInstalledL2FixedServiceInspecting
    private let paths = InvestigationInstalledL2FixedPaths()

    init() {
        inspector = InvestigationInstalledL2DarwinFixedServiceInspector()
    }

    init(inspector: any InvestigationInstalledL2FixedServiceInspecting) {
        self.inspector = inspector
    }

    func sample() -> InvestigationInstalledL2FixedServiceSample {
        let status = inspector.registrationStatus(
            plistURL: paths.launchDaemonPlist
        )
        let job = inspector.job(label: Self.label)
        if job == .missing,
           status == .notRegistered || status == .notFound
        {
            return .absent
        }
        guard
            status == .enabled,
            case let .present(label, rawProcessID, fieldCount) = job,
            label == Self.label,
            fieldCount > 0,
            fieldCount <= 128,
            let rawProcessID,
            rawProcessID > 1,
            rawProcessID <= Int64(Int32.max)
        else {
            return .unavailable
        }
        return .registered(processID: UInt32(rawProcessID))
    }
}

struct InvestigationInstalledL2FixedServiceReader: Sendable {
    private let registry: any InvestigationInstalledL2FixedServiceRegistryReading
    private let identityReader: any InvestigationInstalledL2ProcessIdentityReading

    init() {
        self.init(
            registry: InvestigationInstalledL2FixedServiceRegistry(),
            identityReader: InvestigationInstalledL2DarwinProcessIdentityReader()
        )
    }

    init(
        registry: any InvestigationInstalledL2FixedServiceRegistryReading,
        identityReader: any InvestigationInstalledL2ProcessIdentityReading
    ) {
        self.registry = registry
        self.identityReader = identityReader
    }

    func observe(
        expectedHelper: InvestigationMachineProcessIdentity
    ) -> InvestigationInstalledL2ServiceObservation {
        guard expectedHelper.role == .helper else { return .unavailable }

        switch registry.sample() {
        case .absent:
            return registry.sample() == .absent ? .absent : .unavailable
        case .unavailable:
            return .unavailable
        case .registered(let processID):
            guard processID == expectedHelper.processID else {
                return .unavailable
            }
        }

        guard
            readExpectedIdentity(expectedHelper),
            readExpectedIdentity(expectedHelper),
            registry.sample()
                == .registered(processID: expectedHelper.processID)
        else {
            return .unavailable
        }
        return .loaded(identity: expectedHelper)
    }

    private func readExpectedIdentity(
        _ expected: InvestigationMachineProcessIdentity
    ) -> Bool {
        guard case let .success(kernel) = identityReader.read(
            processID: expected.processID
        ) else {
            return false
        }
        return kernel.processID == expected.processID
            && kernel.processIDVersion == expected.processIDVersion
            && kernel.auditSessionID == expected.auditSessionID
            && kernel.effectiveUserID == expected.effectiveUserID
            && kernel.auditTokenWords == expected.auditTokenWords
            && kernel.auditTokenWords.count == 8
            && kernel.auditTokenWords[1] == kernel.effectiveUserID
            && kernel.auditTokenWords[5] == kernel.processID
            && kernel.auditTokenWords[6] == kernel.auditSessionID
            && kernel.auditTokenWords[7] == kernel.processIDVersion
    }
}
