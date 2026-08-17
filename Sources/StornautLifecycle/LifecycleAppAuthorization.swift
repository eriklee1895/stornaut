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
    public init() {}

    public func read(
        bundleURL: URL
    ) throws -> LifecycleSigningIdentity {
        try evidence(bundleURL: bundleURL).identity
    }

    public func evidence(
        bundleURL: URL
    ) throws -> LifecycleBundleSigningEvidence {
        guard
            bundleURL.isFileURL,
            bundleURL.path.hasPrefix("/")
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
            let staticCode,
            SecStaticCodeCheckValidity(
                staticCode,
                SecCSFlags(rawValue: kSecCSStrictValidate),
                nil
            ) == errSecSuccess
        else {
            throw LifecycleSigningIdentityError.unavailable
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
            let flags = dictionary[kSecCodeInfoFlags] as? NSNumber,
            let requirement = secRequirement(
                dictionary[kSecCodeInfoDesignatedRequirement]
            ),
            let requirementData = requirementData(requirement),
            let executableURL = lifecycleSigningExecutableURL(
                for: bundleURL
            )
        else {
            throw LifecycleSigningIdentityError.unavailable
        }
        do {
            let identity = try LifecycleSigningIdentity(
                signingIdentifier: signingIdentifier,
                designatedRequirementSHA256: sha256(requirementData),
                codeDirectoryHash: codeDirectoryData.hexString
            )
            return try LifecycleBundleSigningEvidence(
                identity: identity,
                executableSHA256: try sha256File(executableURL),
                isAdHoc: flags.uint32Value
                    & lifecycleAdHocCodeSignatureFlag != 0
            )
        } catch {
            throw LifecycleSigningIdentityError.invalidIdentity
        }
    }
}

func lifecycleSigningExecutableURL(for codeURL: URL) -> URL? {
    guard
        codeURL.isFileURL,
        codeURL.path.hasPrefix("/")
    else {
        return nil
    }
    if let executableURL = Bundle(url: codeURL)?.executableURL {
        return executableURL.standardizedFileURL
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

private func sha256File(_ url: URL) throws -> String {
    let handle: FileHandle
    do {
        handle = try FileHandle(forReadingFrom: url)
    } catch {
        throw LifecycleSigningIdentityError.unavailable
    }
    defer { try? handle.close() }
    var hasher = SHA256()
    do {
        while let data = try handle.read(upToCount: 64 * 1_024),
              !data.isEmpty
        {
            hasher.update(data: data)
        }
    } catch {
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
