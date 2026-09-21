import CInvestigationIdentitySupport
import Darwin
import Foundation
import Security
import StornautInvestigationHandoffContract

private let investigationInstalledL2LiveAdHocFlag: UInt32 = 0x0002

struct InvestigationInstalledL2KernelIdentity: Sendable, Equatable {
    var processID: UInt32
    var processIDVersion: UInt32
    var auditSessionID: UInt32
    var effectiveUserID: UInt32
    var auditTokenWords: [UInt32]
}

struct InvestigationInstalledL2ProcessSystemError:
    Error,
    Sendable,
    Equatable
{
    let errno: Int32
}

protocol InvestigationInstalledL2ProcessIdentityReading: Sendable {
    func read(
        processID: UInt32
    ) -> Result<
        InvestigationInstalledL2KernelIdentity,
        InvestigationInstalledL2ProcessSystemError
    >
}

struct InvestigationInstalledL2DarwinProcessIdentityReader:
    InvestigationInstalledL2ProcessIdentityReading,
    Sendable
{
    init() {}

    func read(
        processID: UInt32
    ) -> Result<
        InvestigationInstalledL2KernelIdentity,
        InvestigationInstalledL2ProcessSystemError
    > {
        guard processID > 1, processID <= UInt32(Int32.max) else {
            return .failure(.init(errno: EINVAL))
        }
        var raw = stornaut_investigation_identity()
        let status = stornaut_investigation_identity_for_pid(
            pid_t(processID),
            &raw
        )
        guard status == 0 else {
            return .failure(.init(errno: status))
        }
        guard
            raw.process_id > 1,
            raw.process_id_version > 0,
            raw.audit_session_id > 0
        else {
            return .failure(.init(errno: EIO))
        }
        let words = withUnsafeBytes(of: raw.audit_token_words) { bytes in
            Array(bytes.bindMemory(to: UInt32.self))
        }
        guard words.count == 8 else {
            return .failure(.init(errno: EIO))
        }
        return .success(.init(
            processID: UInt32(raw.process_id),
            processIDVersion: UInt32(raw.process_id_version),
            auditSessionID: UInt32(raw.audit_session_id),
            effectiveUserID: UInt32(raw.effective_user_id),
            auditTokenWords: words
        ))
    }
}

protocol InvestigationInstalledL2ProcessPathReading: Sendable {
    func read(
        processID: UInt32
    ) -> Result<URL, InvestigationInstalledL2ProcessSystemError>
}

struct InvestigationInstalledL2DarwinProcessPathReader:
    InvestigationInstalledL2ProcessPathReading,
    Sendable
{
    init() {}

    func read(
        processID: UInt32
    ) -> Result<URL, InvestigationInstalledL2ProcessSystemError> {
        guard processID > 1, processID <= UInt32(Int32.max) else {
            return .failure(.init(errno: EINVAL))
        }
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        Darwin.errno = 0
        let count = buffer.withUnsafeMutableBytes { bytes in
            proc_pidpath(pid_t(processID), bytes.baseAddress, UInt32(bytes.count))
        }
        guard count > 0 else {
            let code = Darwin.errno
            return .failure(.init(errno: code == 0 ? EIO : code))
        }
        let returned = buffer.prefix(Int(count))
        let pathBytes: ArraySlice<CChar>
        if let terminator = returned.firstIndex(of: 0) {
            guard returned[terminator...].allSatisfy({ $0 == 0 }) else {
                return .failure(.init(errno: EIO))
            }
            pathBytes = returned[..<terminator]
        } else {
            pathBytes = returned
        }
        let utf8 = pathBytes.map { UInt8(bitPattern: $0) }
        guard
            let path = String(bytes: utf8, encoding: .utf8),
            path.utf8.count == utf8.count,
            path.hasPrefix("/"),
            !path.isEmpty
        else {
            return .failure(.init(errno: EIO))
        }
        return .success(URL(fileURLWithPath: path).standardizedFileURL)
    }
}

struct InvestigationInstalledL2LiveSigningObservation: Sendable, Equatable {
    let processID: UInt32
    let effectiveUserID: UInt32
    let identity: InvestigationInstalledL2SigningIdentity
}

enum InvestigationInstalledL2LiveSigningResult: Sendable, Equatable {
    case observed(InvestigationInstalledL2LiveSigningObservation)
    case invalid
    case unavailable
}

protocol InvestigationInstalledL2LiveSigningReading: Sendable {
    func read(
        auditTokenWords: [UInt32]
    ) -> InvestigationInstalledL2LiveSigningResult
}

struct InvestigationInstalledL2SecurityLiveSigningReader:
    InvestigationInstalledL2LiveSigningReading,
    Sendable
{
    init() {}

    func read(
        auditTokenWords: [UInt32]
    ) -> InvestigationInstalledL2LiveSigningResult {
        guard auditTokenWords.count == 8 else { return .invalid }
        var token = audit_token_t()
        let copied = withUnsafeMutableBytes(of: &token) { destination in
            auditTokenWords.withUnsafeBytes { source in
                guard destination.count == source.count else { return false }
                destination.copyBytes(from: source)
                return true
            }
        }
        guard copied else { return .invalid }
        let processID = audit_token_to_pid(token)
        let effectiveUserID = audit_token_to_euid(token)
        guard processID > 1 else { return .invalid }

        let tokenData = withUnsafeBytes(of: token) { Data($0) }
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
            return .unavailable
        }
        guard
            SecCodeCheckValidity(
                dynamicCode,
                SecCSFlags(rawValue: kSecCSStrictValidate),
                nil
            ) == errSecSuccess
        else {
            return .invalid
        }
        var staticCode: SecStaticCode?
        guard
            SecCodeCopyStaticCode(dynamicCode, SecCSFlags(), &staticCode)
                == errSecSuccess,
            let staticCode,
            SecStaticCodeCheckValidity(
                staticCode,
                SecCSFlags(rawValue: kSecCSStrictValidate),
                nil
            ) == errSecSuccess
        else {
            return .invalid
        }

        var information: CFDictionary?
        let flags = SecCSFlags(
            rawValue: kSecCSSigningInformation | kSecCSRequirementInformation
        )
        guard
            SecCodeCopySigningInformation(staticCode, flags, &information)
                == errSecSuccess,
            let dictionary = information as? [CFString: Any],
            let identifier = dictionary[kSecCodeInfoIdentifier] as? String,
            let codeDirectoryHash = dictionary[kSecCodeInfoUnique] as? Data,
            let signatureFlags = dictionary[kSecCodeInfoFlags] as? NSNumber,
            let requirement = investigationInstalledL2LiveRequirement(
                dictionary[kSecCodeInfoDesignatedRequirement]
            ),
            let requirementData = investigationInstalledL2LiveRequirementData(
                requirement
            )
        else {
            return .invalid
        }
        do {
            return .observed(.init(
                processID: UInt32(processID),
                effectiveUserID: UInt32(effectiveUserID),
                identity: try .init(
                    signingIdentifier: identifier,
                    designatedRequirementSHA256:
                        InvestigationHandoffSHA256.hashing(requirementData),
                    codeDirectoryHash: codeDirectoryHash,
                    isAdHoc: signatureFlags.uint32Value
                        & investigationInstalledL2LiveAdHocFlag != 0
                )
            ))
        } catch {
            return .invalid
        }
    }
}

struct InvestigationInstalledL2ObservedProcess: Sendable, Equatable {
    let identity: InvestigationMachineProcessIdentity
    let executableURL: URL
    let liveSigning: InvestigationInstalledL2SigningIdentity
}

enum InvestigationInstalledL2ProcessReadResult: Sendable, Equatable {
    case absent
    case observed(InvestigationInstalledL2ObservedProcess)
    case identityReused
    case unavailable
}

enum InvestigationInstalledL2CurrentProcessSigningResult: Sendable, Equatable {
    case observed(InvestigationInstalledL2SigningIdentity)
    case unavailable
}

struct InvestigationInstalledL2ProcessReader: Sendable {
    private let identityReader: any InvestigationInstalledL2ProcessIdentityReading
    private let pathReader: any InvestigationInstalledL2ProcessPathReading
    private let signingReader: any InvestigationInstalledL2LiveSigningReading
    private let currentProcessID: @Sendable () -> UInt32
    private let paths = InvestigationInstalledL2FixedPaths()

    init() {
        self.init(
            identityReader: InvestigationInstalledL2DarwinProcessIdentityReader(),
            pathReader: InvestigationInstalledL2DarwinProcessPathReader(),
            signingReader: InvestigationInstalledL2SecurityLiveSigningReader(),
            currentProcessID: { UInt32(getpid()) }
        )
    }

    init(
        identityReader: any InvestigationInstalledL2ProcessIdentityReading,
        pathReader: any InvestigationInstalledL2ProcessPathReading,
        signingReader: any InvestigationInstalledL2LiveSigningReading,
        currentProcessID: @escaping @Sendable () -> UInt32 = { UInt32(getpid()) }
    ) {
        self.identityReader = identityReader
        self.pathReader = pathReader
        self.signingReader = signingReader
        self.currentProcessID = currentProcessID
    }

    func observeApp(
        expected: InvestigationMachineProcessIdentity
    ) -> InvestigationInstalledL2ProcessReadResult {
        guard expected.role == .app else { return .unavailable }
        return observe(expected: expected, executableURL: paths.appExecutable)
    }

    func observeHelper(
        expected: InvestigationMachineProcessIdentity
    ) -> InvestigationInstalledL2ProcessReadResult {
        guard expected.role == .helper else { return .unavailable }
        return observe(expected: expected, executableURL: paths.helperExecutable)
    }

    func observeCurrentMachineDriverSigning()
        -> InvestigationInstalledL2CurrentProcessSigningResult
    {
        let processID = currentProcessID()
        guard case let .success(kernel) = identityReader.read(processID: processID),
              kernelIsSelfConsistent(kernel),
              kernel.processID == processID,
              kernel.effectiveUserID == 0
        else {
            return .unavailable
        }
        guard case let .observed(signing) = signingReader.read(
            auditTokenWords: kernel.auditTokenWords
        ),
              signing.processID == processID,
              signing.effectiveUserID == 0
        else {
            return .unavailable
        }
        return .observed(signing.identity)
    }

    private func observe(
        expected: InvestigationMachineProcessIdentity,
        executableURL: URL
    ) -> InvestigationInstalledL2ProcessReadResult {
        let initialKernel: InvestigationInstalledL2KernelIdentity
        switch identityReader.read(processID: expected.processID) {
        case .success(let identity):
            initialKernel = identity
        case .failure(let error) where error.errno == ESRCH:
            return .absent
        case .failure:
            return .unavailable
        }
        guard kernelIsSelfConsistent(initialKernel) else { return .unavailable }
        guard kernelMatches(initialKernel, expected: expected) else {
            return .identityReused
        }

        let initialPath: URL
        switch pathReader.read(processID: expected.processID) {
        case .success(let value): initialPath = value.standardizedFileURL
        case .failure: return .unavailable
        }
        guard initialPath == executableURL.standardizedFileURL else {
            return .unavailable
        }

        let signing: InvestigationInstalledL2LiveSigningObservation
        switch signingReader.read(auditTokenWords: expected.auditTokenWords) {
        case .observed(let value): signing = value
        case .invalid, .unavailable: return .unavailable
        }
        guard
            signing.processID == expected.processID,
            signing.effectiveUserID == expected.effectiveUserID
        else {
            return .unavailable
        }

        let finalPath: URL
        switch pathReader.read(processID: expected.processID) {
        case .success(let value): finalPath = value.standardizedFileURL
        case .failure: return .unavailable
        }
        guard finalPath == initialPath,
              finalPath == executableURL.standardizedFileURL
        else {
            return .unavailable
        }

        let finalKernel: InvestigationInstalledL2KernelIdentity
        switch identityReader.read(processID: expected.processID) {
        case .success(let identity): finalKernel = identity
        case .failure: return .unavailable
        }
        guard kernelIsSelfConsistent(finalKernel) else { return .unavailable }
        guard finalKernel == initialKernel,
              kernelMatches(finalKernel, expected: expected)
        else {
            return .identityReused
        }
        return .observed(.init(
            identity: expected,
            executableURL: finalPath,
            liveSigning: signing.identity
        ))
    }

    private func kernelMatches(
        _ kernel: InvestigationInstalledL2KernelIdentity,
        expected: InvestigationMachineProcessIdentity
    ) -> Bool {
        kernel.processID == expected.processID
            && kernel.processIDVersion == expected.processIDVersion
            && kernel.auditSessionID == expected.auditSessionID
            && kernel.effectiveUserID == expected.effectiveUserID
            && kernel.auditTokenWords == expected.auditTokenWords
    }

    private func kernelIsSelfConsistent(
        _ kernel: InvestigationInstalledL2KernelIdentity
    ) -> Bool {
        kernel.processID > 1
            && kernel.processIDVersion > 0
            && kernel.auditSessionID > 0
            && kernel.auditTokenWords.count == 8
            && kernel.auditTokenWords[1] == kernel.effectiveUserID
            && kernel.auditTokenWords[5] == kernel.processID
            && kernel.auditTokenWords[6] == kernel.auditSessionID
            && kernel.auditTokenWords[7] == kernel.processIDVersion
    }
}

private func investigationInstalledL2LiveRequirement(
    _ value: Any?
) -> SecRequirement? {
    guard let value else { return nil }
    let object = value as AnyObject
    guard CFGetTypeID(object) == SecRequirementGetTypeID() else { return nil }
    return unsafeDowncast(object, to: SecRequirement.self)
}

private func investigationInstalledL2LiveRequirementData(
    _ requirement: SecRequirement
) -> Data? {
    var data: CFData?
    guard
        SecRequirementCopyData(requirement, SecCSFlags(), &data) == errSecSuccess,
        let data
    else {
        return nil
    }
    return data as Data
}
