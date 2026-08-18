#if DEBUG
import CryptoKit
#endif
import Foundation

public enum LifecycleLocalInstallationContractError:
    Error,
    Sendable,
    Equatable
{
    case invalidFixedTopology
    case invalidDiagnosticIdentity
}

#if DEBUG
public struct LifecycleWorkerEvidenceFileIdentity:
    Sendable,
    Equatable
{
    public let deviceID: UInt64
    public let inode: UInt64
    public let ownerUserID: uid_t
    public let mode: mode_t
    public let linkCount: UInt64
    public let size: Int64

    public init(
        deviceID: UInt64,
        inode: UInt64,
        ownerUserID: uid_t,
        mode: mode_t,
        linkCount: UInt64,
        size: Int64
    ) {
        self.deviceID = deviceID
        self.inode = inode
        self.ownerUserID = ownerUserID
        self.mode = mode
        self.linkCount = linkCount
        self.size = size
    }

    public func matches(
        _ current: Self,
        expectedOwnerUserID: uid_t,
        maximumSize: Int64
    ) -> Bool {
        self == current
            && ownerUserID == expectedOwnerUserID
            && mode == 0o600
            && linkCount == 1
            && size > 0
            && size <= maximumSize
    }
}

public enum LifecycleWorkerEvidenceReceiptError:
    Error,
    Sendable,
    Equatable
{
    case invalidValue
}

public struct LifecycleWorkerEvidenceReceipt:
    Sendable,
    Equatable
{
    private static let prefix = "stornaut-r5-evidence"
    public let fileIdentity: LifecycleWorkerEvidenceFileIdentity
    public let sha256: String

    public init(
        fileIdentity: LifecycleWorkerEvidenceFileIdentity,
        sha256: String
    ) throws {
        guard
            fileIdentity.deviceID > 0,
            fileIdentity.inode > 0,
            fileIdentity.ownerUserID > 0,
            fileIdentity.mode == 0o600,
            fileIdentity.linkCount == 1,
            fileIdentity.size > 0,
            fileIdentity.size <= 1_024 * 1_024,
            sha256.count == 64,
            sha256.unicodeScalars.allSatisfy({
                (0x30...0x39).contains($0.value)
                    || (0x61...0x66).contains($0.value)
            })
        else {
            throw LifecycleWorkerEvidenceReceiptError.invalidValue
        }
        self.fileIdentity = fileIdentity
        self.sha256 = sha256
    }

    public init(
        fileIdentity: LifecycleWorkerEvidenceFileIdentity,
        data: Data
    ) throws {
        try self.init(
            fileIdentity: fileIdentity,
            sha256: Self.digest(data)
        )
    }

    public func encodedLine() -> Data {
        Data(
            [
                Self.prefix,
                String(fileIdentity.deviceID),
                String(fileIdentity.inode),
                String(fileIdentity.ownerUserID),
                String(fileIdentity.mode),
                String(fileIdentity.linkCount),
                String(fileIdentity.size),
                sha256,
            ].joined(separator: ":").appending("\n").utf8
        )
    }

    public static func decodeLine(_ data: Data) throws -> Self {
        guard
            data.count <= 256,
            data.last == 0x0A,
            let line = String(
                data: data.dropLast(),
                encoding: .utf8
            )
        else {
            throw LifecycleWorkerEvidenceReceiptError.invalidValue
        }
        let fields = line.split(
            separator: ":",
            omittingEmptySubsequences: false
        )
        guard
            fields.count == 8,
            fields[0] == Substring(prefix),
            let deviceID = UInt64(fields[1]),
            let inode = UInt64(fields[2]),
            let ownerUserID = uid_t(fields[3]),
            let mode = mode_t(fields[4]),
            let linkCount = UInt64(fields[5]),
            let size = Int64(fields[6])
        else {
            throw LifecycleWorkerEvidenceReceiptError.invalidValue
        }
        let receipt = try Self(
            fileIdentity: LifecycleWorkerEvidenceFileIdentity(
                deviceID: deviceID,
                inode: inode,
                ownerUserID: ownerUserID,
                mode: mode,
                linkCount: linkCount,
                size: size
            ),
            sha256: String(fields[7])
        )
        guard receipt.encodedLine() == data else {
            throw LifecycleWorkerEvidenceReceiptError.invalidValue
        }
        return receipt
    }

    public func matches(
        data: Data,
        currentIdentity: LifecycleWorkerEvidenceFileIdentity,
        expectedOwnerUserID: uid_t,
        maximumSize: Int64 = 1_024 * 1_024
    ) -> Bool {
        fileIdentity.matches(
            currentIdentity,
            expectedOwnerUserID: expectedOwnerUserID,
            maximumSize: maximumSize
        ) && Self.digest(data) == sha256
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map {
            String(format: "%02x", $0)
        }.joined()
    }
}
#endif

public struct LifecycleLocalDiagnosticPaths: Sendable, Equatable {
    public let userRootURL: URL
    public let rootURL: URL
    public let workerEvidenceURL: URL
    public let reportURL: URL
    public let recoveryURL: URL
}

public struct LifecycleRecoveredInvestigationPolicy: Sendable {
    public init() {}

    public func permitsStart(
        _ investigationID: LifecycleInvestigationID,
        recovered: Set<LifecycleInvestigationID>
    ) -> Bool {
        !recovered.contains(investigationID)
    }

    public func confirmsRecovery(
        _ investigationID: LifecycleInvestigationID,
        recovered: Set<LifecycleInvestigationID>,
        activeInvestigationID: LifecycleInvestigationID?
    ) -> Bool {
        activeInvestigationID == nil
            && recovered.contains(investigationID)
    }
}

public struct LifecycleLocalInstallationContract: Sendable {
    public let installedRootURL: URL
    public let installedAppURL: URL
    package let appExecutableURL: URL
    public let helperExecutableURL: URL
    public let machineDriverExecutableURL: URL
    public let launchDaemonPlistURL: URL
    package let runtimeRootURL: URL
    package let leaseRootURL: URL
    public let label: String
    public let machServiceName: String
    public let machineClaimMachServiceName: String
    public let appBundleIdentifier: String
    package let helperSigningIdentifier: String
    public let machineDriverSigningIdentifier: String
    public let appOwnerUserID: uid_t
    public let appOwnerGroupID: gid_t
    public let appMode: mode_t
    public let plistMode: mode_t

    public init() throws {
        let installedRootURL = URL(
            filePath: "/Library/Application Support/Stornaut",
            directoryHint: .isDirectory
        ).standardizedFileURL
        let installedAppURL = URL(
            filePath:
                "/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app",
            directoryHint: .isDirectory
        ).standardizedFileURL
        let helperExecutableURL = installedAppURL.appending(
            path: "Contents/MacOS/StornautLifecycleHelper",
            directoryHint: .notDirectory
        )
        let appExecutableURL = installedAppURL.appending(
            path: "Contents/MacOS/StornautInvestigationDiagnostic",
            directoryHint: .notDirectory
        )
        let machineDriverExecutableURL = installedAppURL.appending(
            path: "Contents/MacOS/StornautInvestigationMachineDriver",
            directoryHint: .notDirectory
        )
        let launchDaemonPlistURL = URL(
            filePath:
                "/Library/LaunchDaemons/com.eriklee.stornaut.lifecycle.plist",
            directoryHint: .notDirectory
        ).standardizedFileURL
        let runtimeRootURL = URL(
            filePath: "/Library/Application Support/Stornaut/R5Runtime",
            directoryHint: .isDirectory
        ).standardizedFileURL
        let leaseRootURL = URL(
            filePath: "/private/var/db/com.eriklee.stornaut.r5",
            directoryHint: .isDirectory
        ).standardizedFileURL
        let label = "com.eriklee.stornaut.lifecycle"
        let machineClaimMachServiceName =
            "com.eriklee.stornaut.lifecycle.machine-claim"
        let appBundleIdentifier = "com.eriklee.stornaut"
        let helperSigningIdentifier =
            "com.eriklee.stornaut.lifecycle.helper"
        let machineDriverSigningIdentifier =
            "com.eriklee.stornaut.investigation.machine-driver"
        guard
            installedRootURL.path
                == "/Library/Application Support/Stornaut",
            installedAppURL.path
                == "/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app",
            installedAppURL.deletingLastPathComponent()
                == installedRootURL,
            helperExecutableURL.path
                == "/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautLifecycleHelper",
            appExecutableURL.path
                == "/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationDiagnostic",
            machineDriverExecutableURL.path
                == "/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationMachineDriver",
            launchDaemonPlistURL.path
                == "/Library/LaunchDaemons/com.eriklee.stornaut.lifecycle.plist",
            runtimeRootURL.path
                == "/Library/Application Support/Stornaut/R5Runtime",
            leaseRootURL.path
                == "/private/var/db/com.eriklee.stornaut.r5",
            boundedLifecycleIdentifier(label),
            boundedLifecycleIdentifier(machineClaimMachServiceName),
            boundedLifecycleIdentifier(appBundleIdentifier),
            boundedLifecycleIdentifier(helperSigningIdentifier),
            boundedLifecycleIdentifier(machineDriverSigningIdentifier),
            machineClaimMachServiceName != label
        else {
            throw LifecycleLocalInstallationContractError
                .invalidFixedTopology
        }
        self.installedRootURL = installedRootURL
        self.installedAppURL = installedAppURL
        self.appExecutableURL = appExecutableURL
        self.helperExecutableURL = helperExecutableURL
        self.machineDriverExecutableURL = machineDriverExecutableURL
        self.launchDaemonPlistURL = launchDaemonPlistURL
        self.runtimeRootURL = runtimeRootURL
        self.leaseRootURL = leaseRootURL
        self.label = label
        machServiceName = label
        self.machineClaimMachServiceName = machineClaimMachServiceName
        self.appBundleIdentifier = appBundleIdentifier
        self.helperSigningIdentifier = helperSigningIdentifier
        self.machineDriverSigningIdentifier =
            machineDriverSigningIdentifier
        appOwnerUserID = 0
        appOwnerGroupID = 0
        appMode = 0o755
        plistMode = 0o644
    }

    public func launchDaemonManifest() -> [String: Any] {
        [
            "AbandonProcessGroup": false,
            "AssociatedBundleIdentifiers": [appBundleIdentifier],
            "KeepAlive": ["SuccessfulExit": false],
            "Label": label,
            "MachServices": [
                machServiceName: true,
                machineClaimMachServiceName: true,
            ],
            "ProcessType": "Interactive",
            "Program": helperExecutableURL.path,
            "RunAtLoad": false,
            "SessionCreate": true,
            "ThrottleInterval": 1,
        ]
    }

    public func validateLaunchDaemonManifest(
        _ manifest: [String: Any]
    ) throws -> Bool {
        guard
            Set(manifest.keys) == Set(launchDaemonManifest().keys),
            manifest["AbandonProcessGroup"] as? Bool == false,
            manifest["AssociatedBundleIdentifiers"] as? [String]
                == [appBundleIdentifier],
            manifest["KeepAlive"] as? [String: Bool]
                == ["SuccessfulExit": false],
            manifest["Label"] as? String == label,
            manifest["MachServices"] as? [String: Bool]
                == [
                    machServiceName: true,
                    machineClaimMachServiceName: true,
                ],
            manifest["ProcessType"] as? String == "Interactive",
            manifest["Program"] as? String
                == helperExecutableURL.path,
            manifest["RunAtLoad"] as? Bool == false,
            manifest["SessionCreate"] as? Bool == true,
            manifest["ThrottleInterval"] as? Int == 1
        else {
            throw LifecycleLocalInstallationContractError
                .invalidFixedTopology
        }
        return true
    }

    public func diagnosticPaths(
        userID: uid_t,
        investigationID: LifecycleInvestigationID
    ) throws -> LifecycleLocalDiagnosticPaths {
        guard userID > 0 else {
            throw LifecycleLocalInstallationContractError
                .invalidDiagnosticIdentity
        }
        let userRoot = runtimeRootURL.appending(
            path: String(userID),
            directoryHint: .isDirectory
        )
        .standardizedFileURL
        let root = userRoot.appending(
            path: investigationID.rawValue.uuidString.lowercased(),
            directoryHint: .isDirectory
        )
        .standardizedFileURL
        let expectedPrefix = "\(runtimeRootURL.path)/\(userID)/"
        guard
            root.path.hasPrefix(expectedPrefix),
            root.lastPathComponent
                == investigationID.rawValue.uuidString.lowercased()
        else {
            throw LifecycleLocalInstallationContractError
                .invalidDiagnosticIdentity
        }
        return LifecycleLocalDiagnosticPaths(
            userRootURL: userRoot,
            rootURL: root,
            workerEvidenceURL: root.appending(path: "worker.json"),
            reportURL: root.appending(path: "report.json"),
            recoveryURL: root.appending(path: "recovery.json")
        )
    }
}

public enum LifecycleLocalArtifactObservation:
    Sendable,
    Equatable
{
    case absent
    case valid
    case invalid(reasonKey: String)
}

public enum LifecycleLocalServiceObservation:
    Sendable,
    Equatable
{
    case absent
    case loaded
    case mismatched
}

public struct LifecycleLocalInstallationObservation:
    Sendable,
    Equatable
{
    public let app: LifecycleLocalArtifactObservation
    public let plist: LifecycleLocalArtifactObservation
    public let service: LifecycleLocalServiceObservation

    public init(
        app: LifecycleLocalArtifactObservation,
        plist: LifecycleLocalArtifactObservation,
        service: LifecycleLocalServiceObservation
    ) {
        self.app = app
        self.plist = plist
        self.service = service
    }
}

public enum LifecycleLocalInstallationState:
    Sendable,
    Equatable
{
    case installed
    case administratorInstallRequired
    case administratorCleanupRequired
    case inconsistentInstallation
}

public struct LifecycleLocalInstallationPlanner: Sendable {
    public init() {}

    public func state(
        for observation: LifecycleLocalInstallationObservation
    ) -> LifecycleLocalInstallationState {
        if observation.app.isInvalid
            || observation.plist.isInvalid
            || observation.service == .mismatched
        {
            return .inconsistentInstallation
        }
        if observation.service == .loaded,
           observation.app != .valid || observation.plist != .valid
        {
            return .administratorCleanupRequired
        }
        if observation.app == .absent, observation.plist == .valid {
            return .administratorCleanupRequired
        }
        if
            observation.app == .valid,
            observation.plist == .valid,
            observation.service == .loaded
        {
            return .installed
        }
        return .administratorInstallRequired
    }
}

private extension LifecycleLocalArtifactObservation {
    var isInvalid: Bool {
        if case .invalid = self {
            return true
        }
        return false
    }
}

private func boundedLifecycleIdentifier(_ value: String) -> Bool {
    !value.isEmpty
        && value.utf8.count <= 256
        && value.unicodeScalars.allSatisfy {
            (0x30...0x39).contains($0.value)
                || (0x41...0x5A).contains($0.value)
                || (0x61...0x7A).contains($0.value)
                || $0.value == 0x2D
                || $0.value == 0x2E
                || $0.value == 0x5F
        }
}
