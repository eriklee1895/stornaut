import Darwin

enum InvestigationMachineInstalledDriverObservationError:
    Error,
    Sendable,
    Equatable
{
    case rootAuthorityRequired
    case invalidInvocation
    case sourceUnavailable
    case invalidObservation
}

struct InvestigationMachineInstalledDriverNodeIdentity:
    Sendable,
    Equatable
{
    var deviceID: UInt64
    var inode: UInt64
    var generation: UInt32
    var isRegularFile: Bool
    var ownerUserID: uid_t
    var ownerGroupID: gid_t
    var mode: mode_t
    var linkCount: UInt64
    var size: Int64
    var flags: UInt32
    var modificationSeconds: Int64
    var modificationNanoseconds: Int64
    var statusChangeSeconds: Int64
    var statusChangeNanoseconds: Int64
}

struct InvestigationMachineInstalledDriverSigningIdentity:
    Sendable,
    Equatable
{
    var signingIdentifier: String
    var designatedRequirementSHA256: String
    var codeDirectoryHash: String
    var isAdHoc: Bool
}

struct InvestigationMachineInstalledManifestIdentity:
    Sendable,
    Equatable
{
    var path: String
    var node: InvestigationMachineInstalledDriverNodeIdentity
    var sha256: String
    var label: String
    var program: String
    var primaryServiceIdentifier: String
    var machineClaimServiceIdentifier: String
}

struct InvestigationMachineInstalledDriverCandidate:
    Sendable,
    Equatable
{
    var executablePath: String
    var finalExecutablePath: String
    var hasTrustedAncestorChain: Bool
    var finalHasTrustedAncestorChain: Bool
    var initialNode: InvestigationMachineInstalledDriverNodeIdentity
    var descriptorNode: InvestigationMachineInstalledDriverNodeIdentity
    var finalDescriptorNode: InvestigationMachineInstalledDriverNodeIdentity
    var finalNode: InvestigationMachineInstalledDriverNodeIdentity
    var hasExtendedACL: Bool
    var finalHasExtendedACL: Bool
    var hasUnexpectedExtendedAttributes: Bool
    var finalHasUnexpectedExtendedAttributes: Bool
    var executableSHA256: String
    var staticSigning: InvestigationMachineInstalledDriverSigningIdentity
    var liveSigning: InvestigationMachineInstalledDriverSigningIdentity
    var manifest: InvestigationMachineInstalledManifestIdentity
    var finalManifest: InvestigationMachineInstalledManifestIdentity
}

struct InvestigationMachineInstalledDriverObservation:
    Sendable,
    Equatable
{
    static let fixedExecutablePath =
        "/Library/Application Support/Stornaut/"
        + "Stornaut-R5-Diagnostic.app/Contents/MacOS/"
        + "StornautInvestigationMachineDriver"
    static let fixedSigningIdentifier =
        "com.eriklee.stornaut.investigation.machine-driver"
    static let fixedLaunchDaemonManifestPath =
        "/Library/LaunchDaemons/com.eriklee.stornaut.lifecycle.plist"
    static let fixedLaunchDaemonManifestSHA256 =
        "e9a05ea2967be85a114e07a872f7b01db5c3d9bb8063664f4a9322554eb2c4a1"
    static let fixedLifecycleLabel = "com.eriklee.stornaut.lifecycle"
    static let fixedLifecycleProgram =
        "/Library/Application Support/Stornaut/"
        + "Stornaut-R5-Diagnostic.app/Contents/MacOS/"
        + "StornautLifecycleHelper"
    static let fixedMachineClaimServiceIdentifier =
        "com.eriklee.stornaut.lifecycle.machine-claim"
    let executablePath: String
    let node: InvestigationMachineInstalledDriverNodeIdentity
    let executableSHA256: String
    let signing: InvestigationMachineInstalledDriverSigningIdentity
    let manifest: InvestigationMachineInstalledManifestIdentity
    var isAdHoc: Bool { signing.isAdHoc }
}

protocol InvestigationMachineInstalledDriverObservationSource: Sendable {
    func readCandidate() throws
        -> InvestigationMachineInstalledDriverCandidate
}

struct InvestigationMachineInstalledDriverObserver: Sendable {
    static let maximumExecutableBytes: Int64 = 16 * 1_024 * 1_024
    static let maximumManifestBytes: Int64 = 64 * 1_024

    static func hasValidExecutableSize(_ size: Int64) -> Bool {
        size > 0 && size <= maximumExecutableBytes
    }

    static func hasValidManifestSize(_ size: Int64) -> Bool {
        size > 0 && size <= maximumManifestBytes
    }

    private let realUserID: @Sendable () -> uid_t
    private let effectiveUserID: @Sendable () -> uid_t
    private let realGroupID: @Sendable () -> gid_t
    private let effectiveGroupID: @Sendable () -> gid_t
    private let argumentCount: @Sendable () -> Int32
    private let source: any InvestigationMachineInstalledDriverObservationSource

    init(
        realUserID: @escaping @Sendable () -> uid_t,
        effectiveUserID: @escaping @Sendable () -> uid_t,
        realGroupID: @escaping @Sendable () -> gid_t,
        effectiveGroupID: @escaping @Sendable () -> gid_t,
        argumentCount: @escaping @Sendable () -> Int32,
        source: any InvestigationMachineInstalledDriverObservationSource
    ) {
        self.realUserID = realUserID
        self.effectiveUserID = effectiveUserID
        self.realGroupID = realGroupID
        self.effectiveGroupID = effectiveGroupID
        self.argumentCount = argumentCount
        self.source = source
    }

    func observe() throws -> InvestigationMachineInstalledDriverObservation {
        guard
            realUserID() == 0,
            effectiveUserID() == 0,
            realGroupID() == 0,
            effectiveGroupID() == 0
        else {
            throw InvestigationMachineInstalledDriverObservationError
                .rootAuthorityRequired
        }
        guard argumentCount() == 1 else {
            throw InvestigationMachineInstalledDriverObservationError
                .invalidInvocation
        }

        let candidate = try source.readCandidate()
        guard Self.valid(candidate) else {
            throw InvestigationMachineInstalledDriverObservationError
                .invalidObservation
        }
        return InvestigationMachineInstalledDriverObservation(
            executablePath: candidate.executablePath,
            node: candidate.initialNode,
            executableSHA256: candidate.executableSHA256,
            signing: candidate.staticSigning,
            manifest: candidate.manifest
        )
    }

    private static func valid(
        _ candidate: InvestigationMachineInstalledDriverCandidate
    ) -> Bool {
        let node = candidate.initialNode
        return candidate.executablePath
            == InvestigationMachineInstalledDriverObservation
                .fixedExecutablePath
            && candidate.finalExecutablePath == candidate.executablePath
            && candidate.hasTrustedAncestorChain
            && candidate.finalHasTrustedAncestorChain
            && node == candidate.descriptorNode
            && node == candidate.finalDescriptorNode
            && node == candidate.finalNode
            && node.deviceID > 0
            && node.inode > 0
            && node.isRegularFile
            && node.ownerUserID == 0
            && node.ownerGroupID == 0
            && node.mode == 0o755
            && node.linkCount == 1
            && hasValidExecutableSize(node.size)
            && node.flags == 0
            && !candidate.hasExtendedACL
            && !candidate.finalHasExtendedACL
            && !candidate.hasUnexpectedExtendedAttributes
            && !candidate.finalHasUnexpectedExtendedAttributes
            && lowercaseHex(candidate.executableSHA256, count: 64)
            && valid(candidate.staticSigning)
            && candidate.liveSigning == candidate.staticSigning
            && candidate.staticSigning.isAdHoc
            && valid(candidate.manifest)
            && candidate.finalManifest == candidate.manifest
    }

    private static func valid(
        _ manifest: InvestigationMachineInstalledManifestIdentity
    ) -> Bool {
        let node = manifest.node
        return manifest.path
            == InvestigationMachineInstalledDriverObservation
                .fixedLaunchDaemonManifestPath
            && node.deviceID > 0
            && node.inode > 0
            && node.isRegularFile
            && node.ownerUserID == 0
            && node.ownerGroupID == 0
            && node.mode == 0o644
            && node.linkCount == 1
            && hasValidManifestSize(node.size)
            && node.flags == 0
            && manifest.sha256
                == InvestigationMachineInstalledDriverObservation
                    .fixedLaunchDaemonManifestSHA256
            && manifest.label
                == InvestigationMachineInstalledDriverObservation
                    .fixedLifecycleLabel
            && manifest.program
                == InvestigationMachineInstalledDriverObservation
                    .fixedLifecycleProgram
            && manifest.primaryServiceIdentifier == manifest.label
            && manifest.machineClaimServiceIdentifier
                == InvestigationMachineInstalledDriverObservation
                    .fixedMachineClaimServiceIdentifier
    }

    private static func valid(
        _ signing: InvestigationMachineInstalledDriverSigningIdentity
    ) -> Bool {
        signing.signingIdentifier
            == InvestigationMachineInstalledDriverObservation
                .fixedSigningIdentifier
            && lowercaseHex(
                signing.designatedRequirementSHA256,
                count: 64
            )
            && (lowercaseHex(signing.codeDirectoryHash, count: 40)
                || lowercaseHex(signing.codeDirectoryHash, count: 64))
    }

    private static func lowercaseHex(
        _ value: String,
        count: Int
    ) -> Bool {
        value.utf8.count == count
            && value.utf8.allSatisfy { byte in
                (0x30...0x39).contains(byte)
                    || (0x61...0x66).contains(byte)
            }
    }
}
