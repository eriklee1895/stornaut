import CryptoKit
import Darwin
import Foundation
import Security

struct DarwinInvestigationMachineInstalledDriverSystem:
    InvestigationMachineInstalledDriverSystem,
    Sendable
{
    private static let path =
        InvestigationMachineInstalledDriverObservation.fixedExecutablePath
    private static let manifestPath =
        InvestigationMachineInstalledDriverObservation
            .fixedLaunchDaemonManifestPath
    private static let ancestorPaths = [
        "/",
        "/Library",
        "/Library/Application Support",
        "/Library/Application Support/Stornaut",
        "/Library/Application Support/Stornaut/"
            + "Stornaut-R5-Diagnostic.app",
        "/Library/Application Support/Stornaut/"
            + "Stornaut-R5-Diagnostic.app/Contents",
        "/Library/Application Support/Stornaut/"
            + "Stornaut-R5-Diagnostic.app/Contents/MacOS",
    ]
    private static let manifestAncestorPaths = [
        "/",
        "/Library",
        "/Library/LaunchDaemons",
    ]
    private static let allowedAncestorFlags = UInt32(SF_NOUNLINK)
    private static let allowedExtendedAttributeNames = [
        "com.apple.provenance",
    ]
    private static let maximumExtendedAttributeListBytes = 4 * 1_024

    func installedManifestIdentity() throws
        -> InvestigationMachineInstalledManifestIdentity
    {
        guard try hasTrustedAncestorChain(Self.manifestAncestorPaths) else {
            throw SystemError()
        }
        var initialStatus = stat()
        guard lstat(Self.manifestPath, &initialStatus) == 0 else {
            throw SystemError()
        }
        let initialNode = Self.node(initialStatus)
        guard
            initialNode.isRegularFile,
            initialNode.ownerUserID == 0,
            initialNode.ownerGroupID == 0,
            initialNode.mode == 0o644,
            initialNode.linkCount == 1,
            InvestigationMachineInstalledDriverObserver
                .hasValidManifestSize(initialNode.size),
            initialNode.flags == 0
        else {
            throw SystemError()
        }
        let descriptor = open(
            Self.manifestPath,
            O_RDONLY | O_CLOEXEC | O_NOFOLLOW_ANY | O_UNIQUE | O_NONBLOCK
        )
        guard descriptor >= 0 else { throw SystemError() }
        let outcome: Result<InvestigationMachineInstalledManifestIdentity, Error>
        do {
            let initialDescriptorNode = try descriptorNode(descriptor)
            guard initialDescriptorNode == initialNode else {
                throw SystemError()
            }
            guard try !hasExtendedACL(descriptor) else { throw SystemError() }
            guard try !hasAnyExtendedAttributes(descriptor) else {
                throw SystemError()
            }
            let data = try readData(
                descriptor,
                size: initialDescriptorNode.size
            )
            let digest = SHA256.hash(data: data)
                .map { String(format: "%02x", $0) }
                .joined()
            guard digest
                == InvestigationMachineInstalledDriverObservation
                    .fixedLaunchDaemonManifestSHA256
            else {
                throw SystemError()
            }
            let manifest = try Self.parseManifest(data)
            guard try hasTrustedAncestorChain(Self.manifestAncestorPaths) else {
                throw SystemError()
            }
            guard
                try !hasExtendedACL(descriptor),
                try !hasAnyExtendedAttributes(descriptor)
            else {
                throw SystemError()
            }
            var finalStatus = stat()
            guard lstat(Self.manifestPath, &finalStatus) == 0 else {
                throw SystemError()
            }
            let finalNode = Self.node(finalStatus)
            let finalDescriptorNode = try descriptorNode(descriptor)
            guard
                finalNode == initialNode,
                finalDescriptorNode == initialNode
            else {
                throw SystemError()
            }
            outcome = .success(
                InvestigationMachineInstalledManifestIdentity(
                    path: Self.manifestPath,
                    node: initialNode,
                    sha256: digest,
                    label: manifest.label,
                    program: manifest.program,
                    primaryServiceIdentifier:
                        manifest.primaryServiceIdentifier,
                    machineClaimServiceIdentifier:
                        manifest.machineClaimServiceIdentifier
                )
            )
        } catch {
            outcome = .failure(error)
        }
        guard close(descriptor) else { throw SystemError() }
        return try outcome.get()
    }

    func processExecutablePath() throws -> String {
        var buffer = [CChar](
            repeating: 0,
            count: 4 * Int(MAXPATHLEN)
        )
        let count = buffer.withUnsafeMutableBytes { bytes in
            proc_pidpath(
                getpid(),
                bytes.baseAddress,
                UInt32(bytes.count)
            )
        }
        guard count > 0 else { throw SystemError() }
        return try strictPath(buffer, count: Int(count))
    }

    func hasTrustedAncestorChain() throws -> Bool {
        try hasTrustedAncestorChain(Self.ancestorPaths)
    }

    private func hasTrustedAncestorChain(_ paths: [String]) throws -> Bool {
        for path in paths {
            var status = stat()
            guard
                lstat(path, &status) == 0,
                status.st_mode & S_IFMT == S_IFDIR,
                status.st_uid == 0,
                status.st_mode & 0o022 == 0,
                Self.hasOnlyAllowedAncestorFlags(status.st_flags),
                try !hasExtendedACL(path)
            else {
                return false
            }
        }
        return true
    }

    func pathNode() throws
        -> InvestigationMachineInstalledDriverNodeIdentity
    {
        var status = stat()
        guard lstat(Self.path, &status) == 0 else { throw SystemError() }
        return Self.node(status)
    }

    func openExecutable() throws -> Int32 {
        let descriptor = open(
            Self.path,
            O_RDONLY | O_CLOEXEC | O_NOFOLLOW_ANY | O_UNIQUE | O_NONBLOCK
        )
        guard descriptor >= 0 else { throw SystemError() }
        return descriptor
    }

    func descriptorNode(
        _ descriptor: Int32
    ) throws -> InvestigationMachineInstalledDriverNodeIdentity {
        var status = stat()
        guard fstat(descriptor, &status) == 0 else { throw SystemError() }
        return Self.node(status)
    }

    func hasExtendedACL(_ descriptor: Int32) throws -> Bool {
        Darwin.errno = 0
        guard let acl = acl_get_fd_np(descriptor, ACL_TYPE_EXTENDED) else {
            if Darwin.errno == ENOENT { return false }
            throw SystemError()
        }
        defer { acl_free(UnsafeMutableRawPointer(acl)) }
        var entry: acl_entry_t?
        let result = acl_get_entry(
            acl,
            Int32(ACL_FIRST_ENTRY.rawValue),
            &entry
        )
        guard result >= 0 else { throw SystemError() }
        return result == 1
    }

    func hasUnexpectedExtendedAttributes(_ descriptor: Int32) throws -> Bool {
        try hasUnexpectedExtendedAttributes(
            descriptor,
            allowedNames: Self.allowedExtendedAttributeNames
        )
    }

    private func hasAnyExtendedAttributes(_ descriptor: Int32) throws -> Bool {
        try hasUnexpectedExtendedAttributes(descriptor, allowedNames: [])
    }

    private func hasUnexpectedExtendedAttributes(
        _ descriptor: Int32,
        allowedNames: [String]
    ) throws -> Bool {
        let capacity = flistxattr(descriptor, nil, 0, 0)
        guard
            capacity >= 0,
            capacity <= Self.maximumExtendedAttributeListBytes
        else {
            throw SystemError()
        }
        guard capacity > 0 else { return false }
        var buffer = [UInt8](repeating: 0, count: capacity)
        let count = buffer.withUnsafeMutableBytes { bytes in
            flistxattr(
                descriptor,
                bytes.baseAddress?.assumingMemoryBound(to: CChar.self),
                bytes.count,
                0
            )
        }
        guard count >= 0, count <= capacity else { throw SystemError() }
        return try Self.hasUnexpectedExtendedAttributes(
            Array(buffer.prefix(count)),
            allowedNames: allowedNames
        )
    }

    func sha256(_ descriptor: Int32, size: Int64) throws -> String {
        guard size > 0 else { throw SystemError() }
        var hash = SHA256()
        var offset: Int64 = 0
        var buffer = [UInt8](repeating: 0, count: 16 * 1_024)
        while offset < size {
            let requested = min(Int64(buffer.count), size - offset)
            let count = buffer.withUnsafeMutableBytes { bytes in
                pread(
                    descriptor,
                    bytes.baseAddress,
                    Int(requested),
                    off_t(offset)
                )
            }
            if count < 0, Darwin.errno == EINTR { continue }
            guard count > 0, count <= requested else { throw SystemError() }
            hash.update(data: Data(buffer.prefix(count)))
            offset += Int64(count)
        }
        let trailing = buffer.withUnsafeMutableBytes { bytes in
            pread(descriptor, bytes.baseAddress, 1, off_t(size))
        }
        guard trailing == 0 else { throw SystemError() }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    func staticSigning() throws
        -> InvestigationMachineInstalledDriverSigningIdentity
    {
        var code: SecStaticCode?
        guard
            SecStaticCodeCreateWithPath(
                URL(filePath: Self.path) as CFURL,
                SecCSFlags(),
                &code
            ) == errSecSuccess,
            let code,
            SecStaticCodeCheckValidity(
                code,
                SecCSFlags(rawValue: kSecCSStrictValidate),
                nil
            ) == errSecSuccess
        else {
            throw SystemError()
        }
        return try Self.signing(code)
    }

    func liveSigning() throws
        -> InvestigationMachineInstalledDriverSigningIdentity
    {
        var liveCode: SecCode?
        guard
            SecCodeCopySelf(SecCSFlags(), &liveCode) == errSecSuccess,
            let liveCode,
            SecCodeCheckValidity(
                liveCode,
                SecCSFlags(rawValue: kSecCSStrictValidate),
                nil
            ) == errSecSuccess
        else {
            throw SystemError()
        }
        var staticCode: SecStaticCode?
        guard
            SecCodeCopyStaticCode(
                liveCode,
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
            throw SystemError()
        }
        return try Self.signing(staticCode)
    }

    func close(_ descriptor: Int32) -> Bool {
        Darwin.close(descriptor) == 0
    }

    private static func node(
        _ status: stat
    ) -> InvestigationMachineInstalledDriverNodeIdentity {
        InvestigationMachineInstalledDriverNodeIdentity(
            deviceID: UInt64(status.st_dev),
            inode: UInt64(status.st_ino),
            generation: status.st_gen,
            isRegularFile: status.st_mode & S_IFMT == S_IFREG,
            ownerUserID: status.st_uid,
            ownerGroupID: status.st_gid,
            mode: status.st_mode & 0o7777,
            linkCount: UInt64(status.st_nlink),
            size: status.st_size,
            flags: status.st_flags,
            modificationSeconds: Int64(status.st_mtimespec.tv_sec),
            modificationNanoseconds: Int64(status.st_mtimespec.tv_nsec),
            statusChangeSeconds: Int64(status.st_ctimespec.tv_sec),
            statusChangeNanoseconds: Int64(status.st_ctimespec.tv_nsec)
        )
    }

    static func hasOnlyAllowedAncestorFlags(_ flags: UInt32) -> Bool {
        flags & ~allowedAncestorFlags == 0
    }

    static func hasUnexpectedExtendedAttributes(
        _ bytes: [UInt8],
        allowedNames: [String] = allowedExtendedAttributeNames
    ) throws -> Bool {
        guard !bytes.isEmpty else { return false }
        guard bytes.last == 0 else { throw SystemError() }
        var start = bytes.startIndex
        while start < bytes.endIndex {
            guard
                let terminator = bytes[start...].firstIndex(of: 0),
                terminator > start,
                let name = String(
                    bytes: bytes[start..<terminator],
                    encoding: .utf8
                ),
                name.utf8.count == terminator - start
            else {
                throw SystemError()
            }
            if !allowedNames.contains(name) {
                return true
            }
            start = bytes.index(after: terminator)
        }
        return false
    }

    private func readData(_ descriptor: Int32, size: Int64) throws -> Data {
        guard InvestigationMachineInstalledDriverObserver
            .hasValidManifestSize(size)
        else {
            throw SystemError()
        }
        var result = Data()
        result.reserveCapacity(Int(size))
        var offset: Int64 = 0
        var buffer = [UInt8](repeating: 0, count: 4 * 1_024)
        while offset < size {
            let requested = min(Int64(buffer.count), size - offset)
            let count = buffer.withUnsafeMutableBytes { bytes in
                pread(
                    descriptor,
                    bytes.baseAddress,
                    Int(requested),
                    off_t(offset)
                )
            }
            if count < 0, Darwin.errno == EINTR { continue }
            guard count > 0, count <= requested else { throw SystemError() }
            result.append(buffer, count: count)
            offset += Int64(count)
        }
        let trailing = buffer.withUnsafeMutableBytes { bytes in
            pread(descriptor, bytes.baseAddress, 1, off_t(size))
        }
        guard trailing == 0 else { throw SystemError() }
        return result
    }

    static func parseManifest(_ data: Data) throws -> (
        label: String,
        program: String,
        primaryServiceIdentifier: String,
        machineClaimServiceIdentifier: String
    ) {
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard
            let manifest = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: &format
            ) as? [String: Any],
            format == .xml,
            Set(manifest.keys) == [
                "AbandonProcessGroup",
                "AssociatedBundleIdentifiers",
                "KeepAlive",
                "Label",
                "MachServices",
                "ProcessType",
                "Program",
                "RunAtLoad",
                "SessionCreate",
                "ThrottleInterval",
            ],
            manifest["AbandonProcessGroup"] as? Bool == false,
            manifest["AssociatedBundleIdentifiers"] as? [String]
                == ["com.eriklee.stornaut"],
            manifest["KeepAlive"] as? [String: Bool]
                == ["SuccessfulExit": false],
            let label = manifest["Label"] as? String,
            label
                == InvestigationMachineInstalledDriverObservation
                    .fixedLifecycleLabel,
            let services = manifest["MachServices"] as? [String: Bool],
            services == [
                label: true,
                InvestigationMachineInstalledDriverObservation
                    .fixedMachineClaimServiceIdentifier: true,
            ],
            manifest["ProcessType"] as? String == "Interactive",
            let program = manifest["Program"] as? String,
            program
                == InvestigationMachineInstalledDriverObservation
                    .fixedLifecycleProgram,
            manifest["RunAtLoad"] as? Bool == false,
            manifest["SessionCreate"] as? Bool == true,
            manifest["ThrottleInterval"] as? Int == 1
        else {
            throw SystemError()
        }
        return (
            label,
            program,
            label,
            InvestigationMachineInstalledDriverObservation
                .fixedMachineClaimServiceIdentifier
        )
    }

    private func strictPath(
        _ buffer: [CChar],
        count: Int
    ) throws -> String {
        guard count > 0, count <= buffer.count else { throw SystemError() }
        let returned = buffer.prefix(count)
        let pathBytes: ArraySlice<CChar>
        if let terminator = returned.firstIndex(of: 0) {
            guard returned[terminator...].allSatisfy({ $0 == 0 }) else {
                throw SystemError()
            }
            pathBytes = returned[..<terminator]
        } else {
            pathBytes = returned[...]
        }
        let bytes = pathBytes.map { UInt8(bitPattern: $0) }
        guard
            let path = String(bytes: bytes, encoding: .utf8),
            path.utf8.count == bytes.count,
            path.hasPrefix("/")
        else {
            throw SystemError()
        }
        return path
    }

    private func hasExtendedACL(_ path: String) throws -> Bool {
        Darwin.errno = 0
        guard let acl = acl_get_link_np(path, ACL_TYPE_EXTENDED) else {
            if Darwin.errno == ENOENT { return false }
            throw SystemError()
        }
        defer { acl_free(UnsafeMutableRawPointer(acl)) }
        var entry: acl_entry_t?
        let result = acl_get_entry(
            acl,
            Int32(ACL_FIRST_ENTRY.rawValue),
            &entry
        )
        guard result >= 0 else { throw SystemError() }
        return result == 1
    }

    private static func signing(
        _ code: SecStaticCode
    ) throws -> InvestigationMachineInstalledDriverSigningIdentity {
        var information: CFDictionary?
        let flags = SecCSFlags(
            rawValue: kSecCSSigningInformation | kSecCSRequirementInformation
        )
        guard
            SecCodeCopySigningInformation(
                code,
                flags,
                &information
            ) == errSecSuccess,
            let dictionary = information as? [CFString: Any],
            let identifier = dictionary[kSecCodeInfoIdentifier] as? String,
            let codeDirectory = dictionary[kSecCodeInfoUnique] as? Data,
            let signatureFlags = dictionary[kSecCodeInfoFlags] as? NSNumber,
            let requirement = requirement(
                dictionary[kSecCodeInfoDesignatedRequirement]
            ),
            let requirementData = requirementData(requirement)
        else {
            throw SystemError()
        }
        return InvestigationMachineInstalledDriverSigningIdentity(
            signingIdentifier: identifier,
            designatedRequirementSHA256:
                SHA256.hash(data: requirementData)
                    .map { String(format: "%02x", $0) }
                    .joined(),
            codeDirectoryHash: codeDirectory
                .map { String(format: "%02x", $0) }
                .joined(),
            isAdHoc: signatureFlags.uint32Value & 0x0002 != 0
        )
    }

    private static func requirement(_ value: Any?) -> SecRequirement? {
        guard let value else { return nil }
        let object = value as AnyObject
        guard CFGetTypeID(object) == SecRequirementGetTypeID() else {
            return nil
        }
        return unsafeDowncast(object, to: SecRequirement.self)
    }

    private static func requirementData(
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
}

private struct SystemError: Error {}
