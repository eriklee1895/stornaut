import CryptoKit
import Darwin
import Foundation
import Security

private let lifecycleAdHocCodeSignatureFlag: UInt32 = 0x0002

public enum LifecycleCodeSigningVerification:
    Sendable,
    Equatable
{
    case verified(
        processID: pid_t,
        effectiveUserID: uid_t,
        signingIdentifier: String,
        designatedRequirementSHA256: String,
        codeDirectoryHash: String
    )
    case unresolved
}

public struct LifecycleSigningIdentity:
    Sendable,
    Equatable
{
    public let signingIdentifier: String
    public let designatedRequirementSHA256: String
    public let codeDirectoryHash: String

    public init(
        signingIdentifier: String,
        designatedRequirementSHA256: String,
        codeDirectoryHash: String
    ) throws {
        guard
            !signingIdentifier.isEmpty,
            signingIdentifier.utf8.count <= 256,
            signingIdentifier.unicodeScalars.allSatisfy({
                (0x30...0x39).contains($0.value)
                    || (0x41...0x5A).contains($0.value)
                    || (0x61...0x7A).contains($0.value)
                    || $0.value == 0x2D
                    || $0.value == 0x2E
                    || $0.value == 0x5F
            }),
            validSHA256(designatedRequirementSHA256),
            validCodeDirectoryHash(codeDirectoryHash)
        else {
            throw LifecycleSigningIdentityError.invalidIdentity
        }
        self.signingIdentifier = signingIdentifier
        self.designatedRequirementSHA256 =
            designatedRequirementSHA256
        self.codeDirectoryHash = codeDirectoryHash
    }
}

public struct LifecycleBundleSigningEvidence:
    Sendable,
    Equatable
{
    public let identity: LifecycleSigningIdentity
    public let executableSHA256: String
    public let isAdHoc: Bool

    public init(
        identity: LifecycleSigningIdentity,
        executableSHA256: String,
        isAdHoc: Bool
    ) throws {
        guard validSHA256(executableSHA256) else {
            throw LifecycleSigningIdentityError.invalidIdentity
        }
        self.identity = identity
        self.executableSHA256 = executableSHA256
        self.isAdHoc = isAdHoc
    }
}

package struct LifecycleSignedBundleObservation:
    Sendable,
    Equatable
{
    package let signingEvidence: LifecycleBundleSigningEvidence
    package let mainExecutableURL: URL
    package let bundleIdentifier: String

    package init(
        signingEvidence: LifecycleBundleSigningEvidence,
        mainExecutableURL: URL,
        bundleIdentifier: String
    ) throws {
        guard
            mainExecutableURL.isFileURL,
            mainExecutableURL.path.hasPrefix("/"),
            !mainExecutableURL.lastPathComponent.isEmpty,
            !bundleIdentifier.isEmpty,
            bundleIdentifier.utf8.count <= 256,
            bundleIdentifier
                == signingEvidence.identity.signingIdentifier,
            bundleIdentifier.unicodeScalars.allSatisfy({
                (0x30...0x39).contains($0.value)
                    || (0x41...0x5A).contains($0.value)
                    || (0x61...0x7A).contains($0.value)
                    || $0.value == 0x2D
                    || $0.value == 0x2E
                    || $0.value == 0x5F
            })
        else {
            throw LifecycleSignedBundleObservationError
                .signedMetadataUnavailable
        }
        self.signingEvidence = signingEvidence
        self.mainExecutableURL = mainExecutableURL.standardizedFileURL
        self.bundleIdentifier = bundleIdentifier
    }
}

package enum LifecycleSignedBundleObservationError:
    Error,
    Sendable,
    Equatable
{
    case signingEvidenceUnavailable
    case signedMetadataUnavailable
}

package struct LifecycleSigningEvidenceReadHooks:
    @unchecked Sendable
{
    package let afterDescriptorOpened: @Sendable () throws -> Void
    package let afterSigningInformation: @Sendable () -> Void
    package let afterFinalSigningInformation: @Sendable () throws -> Void

    package init(
        afterDescriptorOpened: @escaping @Sendable () throws -> Void = {},
        afterSigningInformation: @escaping @Sendable () -> Void = {},
        afterFinalSigningInformation: @escaping @Sendable () throws -> Void = {}
    ) {
        self.afterDescriptorOpened = afterDescriptorOpened
        self.afterSigningInformation = afterSigningInformation
        self.afterFinalSigningInformation = afterFinalSigningInformation
    }
}

public enum LifecycleSigningIdentityError:
    Error,
    Sendable,
    Equatable
{
    case invalidIdentity
    case unavailable
}

public enum LifecyclePeerCodeSigningRequirement {
    public static func exact(
        identity: LifecycleSigningIdentity
    ) -> String {
        """
        identifier "\(identity.signingIdentifier)" and \
        cdhash H"\(identity.codeDirectoryHash)"
        """
    }
}

public struct LifecycleBundleSigningIdentityReader: Sendable {
    private let hooks: LifecycleSigningEvidenceReadHooks

    public init() {
        hooks = LifecycleSigningEvidenceReadHooks()
    }

    package init(hooks: LifecycleSigningEvidenceReadHooks) {
        self.hooks = hooks
    }

    public func read(
        bundleURL: URL
    ) throws -> LifecycleSigningIdentity {
        try evidence(bundleURL: bundleURL).identity
    }

    public func evidence(
        bundleURL: URL
    ) throws -> LifecycleBundleSigningEvidence {
        let information = try signingInformation(
            bundleURL: bundleURL,
            includePropertyList: false
        )
        let executableURL: URL
        if let signedMainExecutableURL = information.mainExecutableURL {
            guard
                signedMainExecutableURL.isFileURL,
                signedMainExecutableURL.path.hasPrefix("/")
            else {
                throw LifecycleSigningIdentityError.unavailable
            }
            executableURL = signedMainExecutableURL.standardizedFileURL
        } else if let resolved = lifecycleSigningExecutableURL(
            for: bundleURL
        ) {
            executableURL = resolved
        } else {
            throw LifecycleSigningIdentityError.unavailable
        }
        return try observedEvidence(
            codeURL: bundleURL,
            executableURL: executableURL,
            initialInformation: information,
            includesPropertyList: false
        ).signingEvidence
    }

    package func signedBundleObservation(
        bundleURL: URL
    ) throws -> LifecycleSignedBundleObservation {
        let metadata: LifecycleSigningInformation
        let executableURL: URL
        do {
            metadata = try signingInformation(
                bundleURL: bundleURL,
                includePropertyList: true
            )
            guard let mainExecutableURL = metadata.mainExecutableURL else {
                throw LifecycleSignedBundleObservationError
                    .signedMetadataUnavailable
            }
            executableURL = mainExecutableURL.standardizedFileURL
        } catch let error as LifecycleSignedBundleObservationError {
            throw error
        } catch {
            throw LifecycleSignedBundleObservationError
                .signingEvidenceUnavailable
        }
        do {
            let observed = try observedEvidence(
                codeURL: bundleURL,
                executableURL: executableURL,
                initialInformation: metadata,
                includesPropertyList: true
            )
            guard
                observed.mainExecutableURL.deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    == bundleURL.standardizedFileURL,
                let bundleIdentifier = observed.bundleIdentifier,
                let executableName = observed.executableName,
                observed.mainExecutableURL.lastPathComponent
                    == executableName
            else {
                throw LifecycleSignedBundleObservationError
                    .signedMetadataUnavailable
            }
            return try LifecycleSignedBundleObservation(
                signingEvidence: observed.signingEvidence,
                mainExecutableURL: observed.mainExecutableURL,
                bundleIdentifier: bundleIdentifier
            )
        } catch let error as LifecycleSignedBundleObservationError {
            throw error
        } catch {
            throw LifecycleSignedBundleObservationError
                .signingEvidenceUnavailable
        }
    }

    private func signingInformation(
        bundleURL: URL,
        includePropertyList: Bool
    ) throws -> LifecycleSigningInformation {
        guard
            bundleURL.isFileURL,
            bundleURL.path.hasPrefix("/"),
            lifecycleSigningCodeURLHasDirectLeaf(bundleURL)
        else {
            throw LifecycleSigningIdentityError.unavailable
        }
        var staticCode: SecStaticCode?
        guard
            SecStaticCodeCreateWithPath(
                bundleURL as CFURL,
                SecCSFlags(),
                &staticCode
            ) == errSecSuccess,
            let staticCode
        else {
            throw LifecycleSigningIdentityError.unavailable
        }
        if SecStaticCodeCheckValidity(
               staticCode,
               SecCSFlags(rawValue: kSecCSStrictValidate),
               nil
           ) != errSecSuccess
        {
            throw LifecycleSigningIdentityError.unavailable
        }
        var information: CFDictionary?
        var rawFlags = kSecCSSigningInformation
            | kSecCSRequirementInformation
        if includePropertyList {
            rawFlags |= kSecCSContentInformation
        }
        let flags = SecCSFlags(rawValue: rawFlags)
        guard
            SecCodeCopySigningInformation(
                staticCode,
                flags,
                &information
            ) == errSecSuccess,
            let dictionary = information as? [CFString: Any],
            let signingIdentifier =
                dictionary[kSecCodeInfoIdentifier] as? String,
            let codeDirectoryData =
                dictionary[kSecCodeInfoUnique] as? Data,
            let flags = dictionary[kSecCodeInfoFlags] as? NSNumber,
            let requirement = secRequirement(
                dictionary[kSecCodeInfoDesignatedRequirement]
            ),
            let requirementData = requirementData(requirement)
        else {
            throw LifecycleSigningIdentityError.unavailable
        }
        do {
            return LifecycleSigningInformation(
                identity: try LifecycleSigningIdentity(
                    signingIdentifier: signingIdentifier,
                    designatedRequirementSHA256: sha256(requirementData),
                    codeDirectoryHash: codeDirectoryData.hexString
                ),
                isAdHoc: flags.uint32Value
                    & lifecycleAdHocCodeSignatureFlag != 0,
                mainExecutableURL:
                    dictionary[kSecCodeInfoMainExecutable] as? URL,
                bundleIdentifier: (dictionary[kSecCodeInfoPList]
                    as? [String: Any])?["CFBundleIdentifier"]
                    as? String,
                executableName: (dictionary[kSecCodeInfoPList]
                    as? [String: Any])?["CFBundleExecutable"]
                    as? String
            )
        } catch {
            throw LifecycleSigningIdentityError.invalidIdentity
        }
    }

    private func observedEvidence(
        codeURL: URL,
        executableURL: URL,
        initialInformation: LifecycleSigningInformation,
        includesPropertyList: Bool
    ) throws -> LifecycleObservedSigningEvidence {
        let descriptor = Darwin.open(
            executableURL.path,
            O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
        )
        guard descriptor >= 0 else {
            throw LifecycleSigningIdentityError.unavailable
        }
        defer { Darwin.close(descriptor) }
        guard let initialNode = lifecycleSigningFileNode(
            descriptor: descriptor
        ) else {
            throw LifecycleSigningIdentityError.unavailable
        }
        var namedNode = stat()
        guard
            lstat(executableURL.path, &namedNode) == 0,
            lifecycleSigningFileNode(namedNode) == initialNode
        else {
            throw LifecycleSigningIdentityError.unavailable
        }
        try hooks.afterDescriptorOpened()
        let information = try signingInformation(
            bundleURL: codeURL,
            includePropertyList: includesPropertyList
        )
        hooks.afterSigningInformation()
        let digest = try sha256File(descriptor)
        let finalInformation = try signingInformation(
            bundleURL: codeURL,
            includePropertyList: includesPropertyList
        )
        try hooks.afterFinalSigningInformation()
        guard
            lifecycleSigningInformation(
                initialInformation, matches: information
            ),
            lifecycleSigningInformation(
                information, matches: finalInformation
            ),
            lifecycleSigningInformation(
                finalInformation, resolvesTo: executableURL
            ),
            lifecycleSigningFileNode(descriptor: descriptor) == initialNode,
            lstat(executableURL.path, &namedNode) == 0,
            lifecycleSigningFileNode(namedNode) == initialNode
        else {
            throw LifecycleSigningIdentityError.unavailable
        }
        let evidence = try LifecycleBundleSigningEvidence(
            identity: finalInformation.identity,
            executableSHA256: digest,
            isAdHoc: finalInformation.isAdHoc
        )
        return LifecycleObservedSigningEvidence(
            signingEvidence: evidence,
            mainExecutableURL:
                finalInformation.mainExecutableURL?
                    .standardizedFileURL
                    ?? executableURL.standardizedFileURL,
            bundleIdentifier: finalInformation.bundleIdentifier,
            executableName: finalInformation.executableName
        )
    }
}

private struct LifecycleSigningInformation: Equatable {
    let identity: LifecycleSigningIdentity
    let isAdHoc: Bool
    let mainExecutableURL: URL?
    let bundleIdentifier: String?
    let executableName: String?
}

private struct LifecycleObservedSigningEvidence {
    let signingEvidence: LifecycleBundleSigningEvidence
    let mainExecutableURL: URL
    let bundleIdentifier: String?
    let executableName: String?
}

private func lifecycleSigningInformation(
    _ lhs: LifecycleSigningInformation,
    matches rhs: LifecycleSigningInformation
) -> Bool {
    lhs.identity == rhs.identity
        && lhs.isAdHoc == rhs.isAdHoc
        && lhs.mainExecutableURL?.standardizedFileURL
            == rhs.mainExecutableURL?.standardizedFileURL
        && lhs.bundleIdentifier == rhs.bundleIdentifier
        && lhs.executableName == rhs.executableName
}

private func lifecycleSigningInformation(
    _ information: LifecycleSigningInformation,
    resolvesTo executableURL: URL
) -> Bool {
    information.mainExecutableURL.map {
        $0.standardizedFileURL == executableURL.standardizedFileURL
    } ?? true
}

private struct LifecycleSigningFileNode: Equatable {
    let device: dev_t
    let inode: ino_t
    let size: off_t
    let mode: mode_t
    let ownerUserID: uid_t
    let ownerGroupID: gid_t
    let flags: UInt32
    let modificationSeconds: Int64
    let modificationNanoseconds: Int64
    let changeSeconds: Int64
    let changeNanoseconds: Int64
}

private func lifecycleSigningFileNode(
    descriptor: Int32
) -> LifecycleSigningFileNode? {
    var information = stat()
    guard fstat(descriptor, &information) == 0 else { return nil }
    return lifecycleSigningFileNode(information)
}

private func lifecycleSigningCodeURLHasDirectLeaf(_ codeURL: URL) -> Bool {
    var information = stat()
    guard lstat(codeURL.path, &information) == 0 else { return false }
    if information.st_mode & S_IFMT == S_IFDIR {
        return true
    }
    return lifecycleSigningFileNode(information) != nil
}

private func lifecycleSigningFileNode(
    _ information: stat
) -> LifecycleSigningFileNode? {
    guard
        information.st_mode & S_IFMT == S_IFREG,
        information.st_nlink == 1,
        information.st_mode & 0o111 != 0,
        information.st_size > 0
    else {
        return nil
    }
    return LifecycleSigningFileNode(
        device: information.st_dev,
        inode: information.st_ino,
        size: information.st_size,
        mode: information.st_mode,
        ownerUserID: information.st_uid,
        ownerGroupID: information.st_gid,
        flags: information.st_flags,
        modificationSeconds: Int64(information.st_mtimespec.tv_sec),
        modificationNanoseconds: Int64(information.st_mtimespec.tv_nsec),
        changeSeconds: Int64(information.st_ctimespec.tv_sec),
        changeNanoseconds: Int64(information.st_ctimespec.tv_nsec)
    )
}

func lifecycleSigningExecutableURL(
    for codeURL: URL
) -> URL? {
    guard
        codeURL.isFileURL,
        codeURL.path.hasPrefix("/")
    else {
        return nil
    }
    var information = stat()
    guard
        lstat(codeURL.path, &information) == 0,
        information.st_mode & S_IFMT == S_IFREG,
        information.st_nlink == 1,
        information.st_mode & 0o111 != 0
    else {
        return nil
    }
    return codeURL.standardizedFileURL
}

public protocol LifecycleCodeSigningVerifying: Sendable {
    func verify(
        auditToken: LifecycleAuditToken
    ) -> LifecycleCodeSigningVerification
}

public protocol LifecycleProcessCodeSigningVerifying: Sendable {
    func verify(
        processID: pid_t,
        effectiveUserID: uid_t
    ) -> LifecycleCodeSigningVerification
}

public struct LifecyclePeerAdmissionPolicy: Sendable {
    private let expectedIdentity: LifecycleSigningIdentity
    private let verifier: any LifecycleProcessCodeSigningVerifying

    public init(
        expectedIdentity: LifecycleSigningIdentity,
        verifier: any LifecycleProcessCodeSigningVerifying
            = SecurityLifecycleCodeSigningVerifier()
    ) {
        self.expectedIdentity = expectedIdentity
        self.verifier = verifier
    }

    public func authorize(
        processID: pid_t,
        effectiveUserID: uid_t
    ) -> Bool {
        guard processID > 1, effectiveUserID > 0 else {
            return false
        }
        guard case let .verified(
            verifiedProcessID,
            verifiedUserID,
            signingIdentifier,
            designatedRequirementSHA256,
            codeDirectoryHash
        ) = verifier.verify(
            processID: processID,
            effectiveUserID: effectiveUserID
        ) else {
            return false
        }
        return verifiedProcessID == processID
            && verifiedUserID == effectiveUserID
            && signingIdentifier == expectedIdentity.signingIdentifier
            && designatedRequirementSHA256
                == expectedIdentity.designatedRequirementSHA256
            && codeDirectoryHash == expectedIdentity.codeDirectoryHash
    }
}

protocol LifecycleMachineDriverClaimAdmitting: Sendable {
    func authorize(_ identity: LifecycleProcessIdentity) -> Bool
}

package struct LifecycleMachineDriverPeerAdmissionEvidence:
    Sendable,
    Equatable
{
    package let processIdentity: LifecycleProcessIdentity
    package let signingEvidence: LifecycleBundleSigningEvidence

    package init(
        processIdentity: LifecycleProcessIdentity,
        signingEvidence: LifecycleBundleSigningEvidence
    ) {
        self.processIdentity = processIdentity
        self.signingEvidence = signingEvidence
    }
}

public struct LifecycleMachineDriverAdmissionPolicy:
    LifecycleMachineDriverClaimAdmitting,
    Sendable
{
    private let processIdentity:
        @Sendable (pid_t) -> LifecycleProcessIdentity?
    private let processExecutableURL: @Sendable (pid_t) -> URL?
    private let signingEvidence:
        @Sendable (URL) -> LifecycleBundleSigningEvidence?
    private let codeSigningVerifier:
        any LifecycleCodeSigningVerifying

    public init() {
        processIdentity = { processID in
            try? DarwinLifecycleInventory(
                privilegedProcessID: processID
            ).identity(for: processID)
        }
        processExecutableURL = lifecycleProcessExecutableURL
        signingEvidence = { url in
            try? LifecycleBundleSigningIdentityReader().evidence(
                bundleURL: url
            )
        }
        codeSigningVerifier = SecurityLifecycleCodeSigningVerifier()
    }

    init(
        processIdentity:
            @escaping @Sendable (pid_t) -> LifecycleProcessIdentity?,
        processExecutableURL:
            @escaping @Sendable (pid_t) -> URL?,
        signingEvidence:
            @escaping @Sendable (URL)
                -> LifecycleBundleSigningEvidence?,
        codeSigningVerifier: any LifecycleCodeSigningVerifying
    ) {
        self.processIdentity = processIdentity
        self.processExecutableURL = processExecutableURL
        self.signingEvidence = signingEvidence
        self.codeSigningVerifier = codeSigningVerifier
    }

    public func authorize(
        _ identity: LifecycleProcessIdentity
    ) -> Bool {
        authorizeAndObserveStableEvidence(identity) != nil
    }

    /// Admits one fixed root peer and returns its stable observed evidence.
    /// This is current-peer evidence, not installer-authenticated provenance.
    package func authorizeAndObserveStableEvidence(
        _ identity: LifecycleProcessIdentity
    ) -> LifecycleMachineDriverPeerAdmissionEvidence? {
        guard
            lifecycleMachineIdentityMatchesAuditToken(identity),
            identity.processID > 1,
            identity.processIDVersion > 0,
            identity.auditSessionID > 0,
            identity.effectiveUserID == 0,
            let contract = try? LifecycleLocalInstallationContract(),
            let initialIdentity = processIdentity(identity.processID),
            initialIdentity == identity,
            let initialExecutableURL =
                processExecutableURL(identity.processID)?
                    .standardizedFileURL,
            initialExecutableURL
                == contract.machineDriverExecutableURL,
            let staticEvidence = signingEvidence(
                contract.machineDriverExecutableURL
            ),
            staticEvidence.isAdHoc,
            staticEvidence.identity.signingIdentifier
                == contract.machineDriverSigningIdentifier,
            case let .verified(
                verifiedProcessID,
                verifiedEffectiveUserID,
                signingIdentifier,
                designatedRequirementSHA256,
                codeDirectoryHash
            ) = codeSigningVerifier.verify(
                auditToken: identity.auditToken
            ),
            verifiedProcessID == identity.processID,
            verifiedEffectiveUserID == 0,
            signingIdentifier
                == staticEvidence.identity.signingIdentifier,
            designatedRequirementSHA256
                == staticEvidence.identity.designatedRequirementSHA256,
            codeDirectoryHash
                == staticEvidence.identity.codeDirectoryHash,
            processIdentity(identity.processID) == identity,
            processExecutableURL(identity.processID)?
                .standardizedFileURL
                == contract.machineDriverExecutableURL,
            signingEvidence(contract.machineDriverExecutableURL)
                == staticEvidence,
            codeSigningVerifier.verify(
                auditToken: identity.auditToken
            ) == .verified(
                processID: identity.processID,
                effectiveUserID: 0,
                signingIdentifier:
                    staticEvidence.identity.signingIdentifier,
                designatedRequirementSHA256:
                    staticEvidence.identity
                        .designatedRequirementSHA256,
                codeDirectoryHash:
                    staticEvidence.identity.codeDirectoryHash
            )
        else {
            return nil
        }
        return LifecycleMachineDriverPeerAdmissionEvidence(
            processIdentity: identity,
            signingEvidence: staticEvidence
        )
    }
}

public struct LifecycleAppAuthorizationPolicy: Sendable {
    private let expectedSigningIdentifier: String
    private let expectedDesignatedRequirementSHA256: String
    private let expectedCodeDirectoryHash: String
    private let verifier: any LifecycleCodeSigningVerifying

    public init(
        expectedSigningIdentifier: String,
        expectedDesignatedRequirementSHA256: String,
        expectedCodeDirectoryHash: String,
        verifier: any LifecycleCodeSigningVerifying
    ) {
        self.expectedSigningIdentifier = expectedSigningIdentifier
        self.expectedDesignatedRequirementSHA256 =
            expectedDesignatedRequirementSHA256
        self.expectedCodeDirectoryHash = expectedCodeDirectoryHash
        self.verifier = verifier
    }

    public func authorize(
        _ caller: LifecycleCallerIdentity,
        auditToken: LifecycleAuditToken
    ) -> Bool {
        guard
            caller.processID > 1,
            caller.effectiveUserID > 0,
            caller.signingIdentifier == expectedSigningIdentifier,
            validSHA256(expectedDesignatedRequirementSHA256),
            validCodeDirectoryHash(expectedCodeDirectoryHash)
        else {
            return false
        }
        guard case let .verified(
            processID,
            effectiveUserID,
            signingIdentifier,
            designatedRequirementSHA256,
            codeDirectoryHash
        ) = verifier.verify(auditToken: auditToken) else {
            return false
        }
        return processID == caller.processID
            && effectiveUserID == caller.effectiveUserID
            && signingIdentifier == expectedSigningIdentifier
            && designatedRequirementSHA256
                == expectedDesignatedRequirementSHA256
            && codeDirectoryHash == expectedCodeDirectoryHash
    }
}

public struct SecurityLifecycleCodeSigningVerifier: Sendable {
    public init() {}
}

extension SecurityLifecycleCodeSigningVerifier:
    LifecycleCodeSigningVerifying
{
    public func verify(
        auditToken: LifecycleAuditToken
    ) -> LifecycleCodeSigningVerification {
        guard auditToken.words.count == LifecycleAuditToken.wordCount else {
            return .unresolved
        }
        var rawToken = audit_token_t()
        let didCopy = withUnsafeMutableBytes(of: &rawToken) { destination in
            auditToken.words.withUnsafeBytes { source in
                guard destination.count == source.count else {
                    return false
                }
                destination.copyBytes(from: source)
                return true
            }
        }
        guard didCopy else {
            return .unresolved
        }
        let processID = audit_token_to_pid(rawToken)
        let effectiveUserID = audit_token_to_euid(rawToken)
        guard processID > 1 else {
            return .unresolved
        }

        let tokenData = withUnsafeBytes(of: rawToken) {
            Data($0)
        }
        let attributes: [CFString: Any] = [
            kSecGuestAttributeAudit: tokenData as CFData,
        ]
        var dynamicCode: SecCode?
        guard
            SecCodeCopyGuestWithAttributes(
                nil,
                attributes as CFDictionary,
                SecCSFlags(),
                &dynamicCode
            ) == errSecSuccess,
            let dynamicCode
        else {
            return .unresolved
        }
        var staticCode: SecStaticCode?
        guard
            SecCodeCopyStaticCode(
                dynamicCode,
                SecCSFlags(),
                &staticCode
            ) == errSecSuccess,
            let staticCode,
            SecStaticCodeCheckValidity(
                staticCode,
                SecCSFlags(rawValue: kSecCSStrictValidate),
                nil
            ) == errSecSuccess
        else {
            return .unresolved
        }

        var information: CFDictionary?
        let flags = SecCSFlags(
            rawValue:
                kSecCSSigningInformation
                | kSecCSRequirementInformation
        )
        guard
            SecCodeCopySigningInformation(
                staticCode,
                flags,
                &information
            ) == errSecSuccess,
            let dictionary = information as? [CFString: Any],
            let signingIdentifier =
                dictionary[kSecCodeInfoIdentifier] as? String,
            let codeDirectoryData =
                dictionary[kSecCodeInfoUnique] as? Data,
            let requirement = secRequirement(
                dictionary[kSecCodeInfoDesignatedRequirement]
            ),
            let requirementData = requirementData(requirement)
        else {
            return .unresolved
        }
        let codeDirectoryHash = codeDirectoryData.hexString
        guard validCodeDirectoryHash(codeDirectoryHash) else {
            return .unresolved
        }
        return .verified(
            processID: processID,
            effectiveUserID: effectiveUserID,
            signingIdentifier: signingIdentifier,
            designatedRequirementSHA256: sha256(requirementData),
            codeDirectoryHash: codeDirectoryHash
        )
    }
}

extension SecurityLifecycleCodeSigningVerifier:
    LifecycleProcessCodeSigningVerifying
{
    public func verify(
        processID: pid_t,
        effectiveUserID: uid_t
    ) -> LifecycleCodeSigningVerification {
        guard processID > 1, effectiveUserID > 0 else {
            return .unresolved
        }
        let attributes: [CFString: Any] = [
            kSecGuestAttributePid: NSNumber(value: processID),
        ]
        var dynamicCode: SecCode?
        guard
            SecCodeCopyGuestWithAttributes(
                nil,
                attributes as CFDictionary,
                SecCSFlags(),
                &dynamicCode
            ) == errSecSuccess,
            let dynamicCode,
            let result = lifecycleCodeSigningVerification(
                dynamicCode: dynamicCode,
                processID: processID,
                effectiveUserID: effectiveUserID
            )
        else {
            return .unresolved
        }
        return result
    }
}

private func lifecycleCodeSigningVerification(
    dynamicCode: SecCode,
    processID: pid_t,
    effectiveUserID: uid_t
) -> LifecycleCodeSigningVerification? {
    var staticCode: SecStaticCode?
    guard
        SecCodeCopyStaticCode(
            dynamicCode,
            SecCSFlags(),
            &staticCode
        ) == errSecSuccess,
        let staticCode,
        SecStaticCodeCheckValidity(
            staticCode,
            SecCSFlags(rawValue: kSecCSStrictValidate),
            nil
        ) == errSecSuccess
    else {
        return nil
    }
    var information: CFDictionary?
    let flags = SecCSFlags(
        rawValue:
            kSecCSSigningInformation
            | kSecCSRequirementInformation
    )
    guard
        SecCodeCopySigningInformation(
            staticCode,
            flags,
            &information
        ) == errSecSuccess,
        let dictionary = information as? [CFString: Any],
        let signingIdentifier =
            dictionary[kSecCodeInfoIdentifier] as? String,
        let codeDirectoryData =
            dictionary[kSecCodeInfoUnique] as? Data,
        let requirement = secRequirement(
            dictionary[kSecCodeInfoDesignatedRequirement]
        ),
        let requirementData = requirementData(requirement)
    else {
        return nil
    }
    let codeDirectoryHash = codeDirectoryData.hexString
    guard validCodeDirectoryHash(codeDirectoryHash) else {
        return nil
    }
    return .verified(
        processID: processID,
        effectiveUserID: effectiveUserID,
        signingIdentifier: signingIdentifier,
        designatedRequirementSHA256: sha256(requirementData),
        codeDirectoryHash: codeDirectoryHash
    )
}

func lifecycleProcessExecutableURL(
    _ processID: pid_t
) -> URL? {
    guard processID > 1 else { return nil }
    var buffer = [CChar](
        repeating: 0,
        count: 4 * Int(MAXPATHLEN)
    )
    Darwin.errno = 0
    let count = buffer.withUnsafeMutableBytes { bytes in
        proc_pidpath(
            processID,
            bytes.baseAddress,
            UInt32(bytes.count)
        )
    }
    guard count > 0 else { return nil }
    let returned = buffer.prefix(Int(count))
    let pathBytes: ArraySlice<CChar>
    if let terminator = returned.firstIndex(of: 0) {
        guard returned[terminator...].allSatisfy({ $0 == 0 }) else {
            return nil
        }
        pathBytes = returned[..<terminator]
    } else {
        pathBytes = returned[...]
    }
    let utf8 = pathBytes.map { UInt8(bitPattern: $0) }
    guard
        let path = String(bytes: utf8, encoding: .utf8),
        path.utf8.count == utf8.count,
        path.hasPrefix("/")
    else {
        return nil
    }
    return URL(filePath: path).standardizedFileURL
}

private func lifecycleMachineIdentityMatchesAuditToken(
    _ identity: LifecycleProcessIdentity
) -> Bool {
    guard identity.auditToken.words.count == LifecycleAuditToken.wordCount
    else { return false }
    var token = audit_token_t()
    let copied = withUnsafeMutableBytes(of: &token) { destination in
        identity.auditToken.words.withUnsafeBytes { source in
            guard destination.count == source.count else { return false }
            destination.copyBytes(from: source)
            return true
        }
    }
    return copied
        && audit_token_to_pid(token) == identity.processID
        && audit_token_to_pidversion(token)
            == identity.processIDVersion
        && audit_token_to_asid(token) == identity.auditSessionID
        && audit_token_to_euid(token) == identity.effectiveUserID
}

private func requirementData(
    _ requirement: SecRequirement
) -> Data? {
    var data: CFData?
    guard
        SecRequirementCopyData(
            requirement,
            SecCSFlags(),
            &data
        ) == errSecSuccess,
        let data
    else {
        return nil
    }
    return data as Data
}

private func secRequirement(_ value: Any?) -> SecRequirement? {
    guard let value else {
        return nil
    }
    let object = value as AnyObject
    guard CFGetTypeID(object) == SecRequirementGetTypeID() else {
        return nil
    }
    return unsafeDowncast(object, to: SecRequirement.self)
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map {
        String(format: "%02x", $0)
    }.joined()
}

private func sha256File(_ descriptor: Int32) throws -> String {
    guard lseek(descriptor, 0, SEEK_SET) == 0 else {
        throw LifecycleSigningIdentityError.unavailable
    }
    var hasher = SHA256()
    var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
    while true {
        let count = buffer.withUnsafeMutableBytes { bytes in
            Darwin.read(descriptor, bytes.baseAddress, bytes.count)
        }
        if count > 0 {
            hasher.update(data: Data(buffer.prefix(count)))
            continue
        }
        if count == 0 { break }
        if errno == EINTR { continue }
        throw LifecycleSigningIdentityError.unavailable
    }
    return hasher.finalize().map {
        String(format: "%02x", $0)
    }.joined()
}

private func validSHA256(_ value: String) -> Bool {
    value.utf8.count == 64 && hexadecimal(value)
}

private func validCodeDirectoryHash(_ value: String) -> Bool {
    (value.utf8.count == 40 || value.utf8.count == 64)
        && hexadecimal(value)
}

private func hexadecimal(_ value: String) -> Bool {
    value.unicodeScalars.allSatisfy {
        (0x30...0x39).contains($0.value)
            || (0x61...0x66).contains($0.value)
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
