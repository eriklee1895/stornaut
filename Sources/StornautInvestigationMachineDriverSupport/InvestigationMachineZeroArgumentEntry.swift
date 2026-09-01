import Darwin
import Foundation
import StornautInvestigationHandoffContract

package enum InvestigationMachineZeroArgumentEntryError:
    Error, Sendable, Equatable
{
    case rootAuthorityRequired
    case invalidInvocation
    case installedObservationUnavailable
    case invalidInput
    case invalidRole
    case invalidOuterDescriptor
    case protocolFailure
    case outputUnavailable
    case containmentUncertain
    case cancelled
    case invalidCompletion
}

// This is a terminal transport receipt, not a machine-admission claim. Its
// digest is calculated over the same canonical transcript with a zero digest.
package struct InvestigationMachineDriverCompletionArtifact:
    Sendable, Equatable
{
    private static let domain =
        "stornaut.task39.machine.driver-completion"
    private static let productionDomain = "stornaut.task39.machine.driver-completion-v2"
    package static let maximumByteCount = 512
    private static let completedEpochCount: UInt32 = 8

    package let outerAttemptUUID: UUID
    package let wholeCapsuleSHA256: InvestigationHandoffSHA256
    package let wholeInputSHA256: InvestigationHandoffSHA256
    package let completedEpochCount: UInt32
    package let driverEvidenceBundleSHA256: InvestigationHandoffSHA256?
    package let completionSHA256: InvestigationHandoffSHA256

    package init(
        summary: InvestigationMachineEightEpochCompletionSummary
    ) throws {
        guard
            zeroArgumentUUIDIsNonzero(summary.outerAttemptUUID),
            zeroArgumentDigestIsNonzero(summary.wholeCapsuleSHA256),
            zeroArgumentDigestIsNonzero(summary.wholeInputSHA256),
            summary.completedEpochCount == Self.completedEpochCount
        else {
            throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
        }

        outerAttemptUUID = summary.outerAttemptUUID
        wholeCapsuleSHA256 = summary.wholeCapsuleSHA256
        wholeInputSHA256 = summary.wholeInputSHA256
        completedEpochCount = summary.completedEpochCount
        driverEvidenceBundleSHA256 = nil
        do {
            completionSHA256 = InvestigationHandoffSHA256.hashing(
                try Self.transcript(
                    outerAttemptUUID: summary.outerAttemptUUID,
                    wholeCapsuleSHA256: summary.wholeCapsuleSHA256,
                    wholeInputSHA256: summary.wholeInputSHA256,
                    completedEpochCount: summary.completedEpochCount,
                    completionSHA256Bytes: Data(
                        repeating: 0,
                        count: InvestigationHandoffSHA256.byteCount
                    )
                )
            )
        } catch {
            throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
        }
        guard zeroArgumentDigestIsNonzero(completionSHA256) else {
            throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
        }
    }

    package init(summary: InvestigationMachineEightEpochCompletionSummary,
        driverEvidenceBundleSHA256: InvestigationHandoffSHA256) throws {
        guard
            zeroArgumentUUIDIsNonzero(summary.outerAttemptUUID),
            zeroArgumentDigestIsNonzero(summary.wholeCapsuleSHA256),
            zeroArgumentDigestIsNonzero(summary.wholeInputSHA256),
            summary.completedEpochCount == Self.completedEpochCount,
            zeroArgumentDigestIsNonzero(driverEvidenceBundleSHA256)
        else { throw InvestigationMachineZeroArgumentEntryError.invalidCompletion }
        outerAttemptUUID = summary.outerAttemptUUID
        wholeCapsuleSHA256 = summary.wholeCapsuleSHA256
        wholeInputSHA256 = summary.wholeInputSHA256
        completedEpochCount = summary.completedEpochCount
        self.driverEvidenceBundleSHA256 = driverEvidenceBundleSHA256
        let zero = try InvestigationHandoffSHA256(rawBytes: Data(repeating: 0, count: 32))
        completionSHA256 = .hashing(try Self.transcriptV2(
            summary: summary, bundle: driverEvidenceBundleSHA256,
            completion: zero))
    }

    package func encoded() throws -> Data {
        guard
            zeroArgumentUUIDIsNonzero(outerAttemptUUID),
            zeroArgumentDigestIsNonzero(wholeCapsuleSHA256),
            zeroArgumentDigestIsNonzero(wholeInputSHA256),
            completedEpochCount == Self.completedEpochCount,
            zeroArgumentDigestIsNonzero(completionSHA256)
        else {
            throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
        }
        do {
            let zero = try InvestigationHandoffSHA256(rawBytes: Data(repeating: 0, count: 32))
            let zeroed = try transcript(completion: zero)
            guard InvestigationHandoffSHA256.hashing(zeroed)
                == completionSHA256
            else {
                throw InvestigationMachineZeroArgumentEntryError
                    .invalidCompletion
            }
            return try transcript(completion: completionSHA256)
        } catch let error as InvestigationMachineZeroArgumentEntryError {
            throw error
        } catch {
            throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
        }
    }

    package static func decode(_ data: Data) throws -> Self {
        do {
            if let value = try? decodeV2(data) { return value }
            let fields = try HandoffBinaryTranscript.decode(
                data,
                expectedDomain: domain,
                expectedBusinessFieldByteCounts: [
                    16...16, 32...32, 32...32, 4...4, 32...32,
                ],
                maximumByteCount: maximumByteCount
            )
            let summary = InvestigationMachineEightEpochCompletionSummary(
                outerAttemptUUID: try zeroArgumentUUID(fields[0]),
                wholeCapsuleSHA256: try InvestigationHandoffSHA256(
                    rawBytes: fields[1]
                ),
                wholeInputSHA256: try InvestigationHandoffSHA256(
                    rawBytes: fields[2]
                ),
                completedEpochCount: try zeroArgumentUInt32(fields[3])
            )
            let value = try Self(summary: summary)
            guard
                value.completionSHA256
                    == (try InvestigationHandoffSHA256(rawBytes: fields[4])),
                try value.encoded() == data
            else {
                throw InvestigationMachineZeroArgumentEntryError
                    .invalidCompletion
            }
            return value
        } catch let error as InvestigationMachineZeroArgumentEntryError {
            throw error
        } catch {
            throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
        }
    }

    package static func decodeProduction(_ data: Data) throws -> Self { try decodeV2(data) }

    private static func decodeV2(_ data: Data) throws -> Self {
        let fields = try HandoffBinaryTranscript.decode(
            data, expectedDomain: productionDomain,
            expectedBusinessFieldByteCounts: [
                16...16, 32...32, 32...32, 4...4, 32...32, 32...32,
            ], maximumByteCount: maximumByteCount
        )
        let summary = InvestigationMachineEightEpochCompletionSummary(
            outerAttemptUUID: try zeroArgumentUUID(fields[0]),
            wholeCapsuleSHA256: try .init(rawBytes: fields[1]),
            wholeInputSHA256: try .init(rawBytes: fields[2]),
            completedEpochCount: try zeroArgumentUInt32(fields[3]))
        let value = try Self(summary: summary,
            driverEvidenceBundleSHA256: .init(rawBytes: fields[4]))
        guard value.completionSHA256 == (try .init(rawBytes: fields[5])),
              try value.encoded() == data
        else { throw InvestigationMachineZeroArgumentEntryError.invalidCompletion }
        return value
    }

    private func transcript(completion: InvestigationHandoffSHA256) throws
        -> Data {
        let summary = InvestigationMachineEightEpochCompletionSummary(
            outerAttemptUUID: outerAttemptUUID,
            wholeCapsuleSHA256: wholeCapsuleSHA256,
            wholeInputSHA256: wholeInputSHA256,
            completedEpochCount: completedEpochCount)
        if let bundle = driverEvidenceBundleSHA256 {
            return try Self.transcriptV2(summary: summary, bundle: bundle,
                completion: completion)
        }
        return try Self.transcript(
            outerAttemptUUID: outerAttemptUUID,
            wholeCapsuleSHA256: wholeCapsuleSHA256,
            wholeInputSHA256: wholeInputSHA256,
            completedEpochCount: completedEpochCount,
            completionSHA256Bytes: completion.rawBytes
        )
    }

    private static func transcriptV2(summary: InvestigationMachineEightEpochCompletionSummary,
        bundle: InvestigationHandoffSHA256,
        completion: InvestigationHandoffSHA256) throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: productionDomain, businessFields: [
                zeroArgumentData(summary.outerAttemptUUID),
                summary.wholeCapsuleSHA256.rawBytes,
                summary.wholeInputSHA256.rawBytes,
                zeroArgumentData(summary.completedEpochCount),
                bundle.rawBytes, completion.rawBytes,
            ], maximumByteCount: maximumByteCount
        )
    }

    private static func transcript(
        outerAttemptUUID: UUID,
        wholeCapsuleSHA256: InvestigationHandoffSHA256,
        wholeInputSHA256: InvestigationHandoffSHA256,
        completedEpochCount: UInt32,
        completionSHA256Bytes: Data
    ) throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: domain,
            businessFields: [
                zeroArgumentData(outerAttemptUUID),
                wholeCapsuleSHA256.rawBytes,
                wholeInputSHA256.rawBytes,
                zeroArgumentData(completedEpochCount),
                completionSHA256Bytes,
            ],
            maximumByteCount: maximumByteCount
        )
    }
}

struct InvestigationMachineZeroArgumentSystemError:
    Error, Sendable, Equatable
{
    let errno: Int32
}

struct InvestigationMachineZeroArgumentDescriptorSystem: Sendable {
    let descriptorFlags: @Sendable (Int32)
        -> Result<Int32, InvestigationMachineZeroArgumentSystemError>
    let descriptorStatusFlags: @Sendable (Int32)
        -> Result<Int32, InvestigationMachineZeroArgumentSystemError>
    let setDescriptorFlags: @Sendable (Int32, Int32)
        -> Result<Void, InvestigationMachineZeroArgumentSystemError>
    let setStatusFlags: @Sendable (Int32, Int32)
        -> Result<Void, InvestigationMachineZeroArgumentSystemError>
    let noSigpipe: @Sendable (Int32)
        -> Result<Int32, InvestigationMachineZeroArgumentSystemError>
    let setNoSigpipe: @Sendable (Int32)
        -> Result<Void, InvestigationMachineZeroArgumentSystemError>
    let descriptorNode: @Sendable (Int32) -> Result<
        InvestigationMachineDarwinDescriptorNodeObservation,
        InvestigationMachineZeroArgumentSystemError
    >
    let standardErrorObservation:
        @Sendable () throws -> InvestigationMachineDarwinStandardErrorObservation

    static let system = Self(
        descriptorFlags: zeroArgumentDescriptorFlags,
        descriptorStatusFlags: zeroArgumentDescriptorStatusFlags,
        setDescriptorFlags: zeroArgumentSetDescriptorFlags,
        setStatusFlags: zeroArgumentSetStatusFlags,
        noSigpipe: zeroArgumentNoSigpipe,
        setNoSigpipe: zeroArgumentSetNoSigpipe,
        descriptorNode: zeroArgumentDescriptorNode,
        standardErrorObservation: zeroArgumentStandardErrorObservation
    )
}

enum InvestigationMachineZeroArgumentRoleKind: Sendable, Equatable {
    case outer
    case inner
}

struct InvestigationMachineZeroArgumentOuterDescriptorObservation:
    Sendable, Equatable
{
    let standardOutputNode:
        InvestigationMachineDarwinDescriptorNodeObservation
    let standardOutputDescriptorFlags: Int32
    let standardOutputStatusFlags: Int32
    let standardError: InvestigationMachineDarwinStandardErrorObservation
}

enum InvestigationMachineZeroArgumentRole: Sendable, Equatable {
    case inner
    case outer(InvestigationMachineZeroArgumentOuterDescriptorObservation)

    var outerObservation:
        InvestigationMachineZeroArgumentOuterDescriptorObservation?
    {
        guard case let .outer(value) = self else { return nil }
        return value
    }
}

struct InvestigationMachineZeroArgumentRoleSelector: Sendable {
    private let system: InvestigationMachineZeroArgumentDescriptorSystem

    init(system: InvestigationMachineZeroArgumentDescriptorSystem) {
        self.system = system
    }

    func select() throws -> InvestigationMachineZeroArgumentRole {
        let descriptorEight = system.descriptorFlags(8)
        let descriptorNine = system.descriptorFlags(9)
        switch (descriptorEight, descriptorNine) {
        case (.success, .success):
            return .inner
        case let (.failure(eight), .failure(nine))
            where eight.errno == EBADF && nine.errno == EBADF:
            return .outer(try prepareOuter())
        default:
            throw InvestigationMachineZeroArgumentEntryError.invalidRole
        }
    }

    func revalidate(
        _ expected:
            InvestigationMachineZeroArgumentOuterDescriptorObservation
    ) throws {
        do {
            try requireAbsent(7)
            try requireAbsent(8)
            try requireAbsent(9)
            let outputFlags = try system.descriptorFlags(
                STDOUT_FILENO
            ).get()
            let outputStatus = try system.descriptorStatusFlags(
                STDOUT_FILENO
            ).get()
            let outputNode = try system.descriptorNode(STDOUT_FILENO).get()
            let errorFlags = try system.descriptorFlags(STDERR_FILENO).get()
            let errorStatus = try system.descriptorStatusFlags(
                STDERR_FILENO
            ).get()
            let errorNode = try system.descriptorNode(STDERR_FILENO).get()
            let errorObservation = try system.standardErrorObservation()
            guard
                outputFlags == expected.standardOutputDescriptorFlags,
                outputStatus == expected.standardOutputStatusFlags,
                try system.noSigpipe(STDOUT_FILENO).get() == 1,
                outputNode == expected.standardOutputNode,
                errorFlags & FD_CLOEXEC == 0,
                zeroArgumentWritable(errorStatus),
                errorStatus == errorObservation.statusFlags,
                zeroArgumentStandardErrorIsValid(errorObservation),
                zeroArgumentErrorNode(errorNode, matches: errorObservation),
                errorObservation == expected.standardError,
                outputNode != errorNode
            else {
                throw InvestigationMachineZeroArgumentEntryError
                    .invalidOuterDescriptor
            }
        } catch let error as InvestigationMachineZeroArgumentEntryError {
            throw error
        } catch {
            throw InvestigationMachineZeroArgumentEntryError
                .invalidOuterDescriptor
        }
    }

    private func prepareOuter() throws
        -> InvestigationMachineZeroArgumentOuterDescriptorObservation
    {
        do {
            try requireAbsent(7)

            let initialInputFlags = try system.descriptorFlags(
                STDIN_FILENO
            ).get()
            let initialOutputFlags = try system.descriptorFlags(
                STDOUT_FILENO
            ).get()
            let initialErrorFlags = try system.descriptorFlags(
                STDERR_FILENO
            ).get()
            let inputStatus = try system.descriptorStatusFlags(
                STDIN_FILENO
            ).get()
            let outputStatus = try system.descriptorStatusFlags(
                STDOUT_FILENO
            ).get()
            let errorStatus = try system.descriptorStatusFlags(
                STDERR_FILENO
            ).get()
            let initialNodes = try [
                system.descriptorNode(STDIN_FILENO).get(),
                system.descriptorNode(STDOUT_FILENO).get(),
                system.descriptorNode(STDERR_FILENO).get(),
            ]
            let initialError = try system.standardErrorObservation()

            guard
                initialInputFlags >= 0,
                initialOutputFlags >= 0,
                initialErrorFlags & FD_CLOEXEC == 0,
                inputStatus & O_ACCMODE == O_RDONLY,
                zeroArgumentWritable(outputStatus),
                zeroArgumentWritable(errorStatus),
                initialNodes.allSatisfy(zeroArgumentNodeIsValid),
                Set(initialNodes).count == initialNodes.count,
                initialNodes[1].fileType == mode_t(S_IFIFO),
                errorStatus == initialError.statusFlags,
                zeroArgumentStandardErrorIsValid(initialError),
                zeroArgumentErrorNode(initialNodes[2], matches: initialError)
            else {
                throw InvestigationMachineZeroArgumentEntryError
                    .invalidOuterDescriptor
            }

            let requestedOutputFlags = initialOutputFlags | FD_CLOEXEC
            let requestedOutputStatus = outputStatus | O_NONBLOCK
            try system.setDescriptorFlags(
                STDOUT_FILENO, requestedOutputFlags
            ).get()
            try system.setStatusFlags(
                STDOUT_FILENO, requestedOutputStatus
            ).get()
            try system.setNoSigpipe(STDOUT_FILENO).get()

            let finalOutputFlags = try system.descriptorFlags(
                STDOUT_FILENO
            ).get()
            let finalOutputStatus = try system.descriptorStatusFlags(
                STDOUT_FILENO
            ).get()
            let finalNodes = try [
                system.descriptorNode(STDIN_FILENO).get(),
                system.descriptorNode(STDOUT_FILENO).get(),
                system.descriptorNode(STDERR_FILENO).get(),
            ]
            let finalError = try system.standardErrorObservation()
            try requireAbsent(7)
            try requireAbsent(8)
            try requireAbsent(9)

            guard
                finalOutputFlags == requestedOutputFlags,
                finalOutputFlags & FD_CLOEXEC == FD_CLOEXEC,
                finalOutputStatus == requestedOutputStatus,
                finalOutputStatus & O_NONBLOCK == O_NONBLOCK,
                try system.noSigpipe(STDOUT_FILENO).get() == 1,
                finalNodes == initialNodes,
                finalError == initialError,
                zeroArgumentStandardErrorIsValid(finalError),
                zeroArgumentErrorNode(finalNodes[2], matches: finalError)
            else {
                throw InvestigationMachineZeroArgumentEntryError
                    .invalidOuterDescriptor
            }

            return .init(
                standardOutputNode: finalNodes[1],
                standardOutputDescriptorFlags: finalOutputFlags,
                standardOutputStatusFlags: finalOutputStatus,
                standardError: finalError
            )
        } catch let error as InvestigationMachineZeroArgumentEntryError {
            throw error
        } catch {
            throw InvestigationMachineZeroArgumentEntryError
                .invalidOuterDescriptor
        }
    }

    private func requireAbsent(_ descriptor: Int32) throws {
        switch system.descriptorFlags(descriptor) {
        case .failure(let error) where error.errno == EBADF:
            return
        default:
            throw InvestigationMachineZeroArgumentEntryError
                .invalidOuterDescriptor
        }
    }
}

struct InvestigationMachineZeroArgumentOutputSystem: Sendable {
    let continuousNanoseconds: @Sendable () -> UInt64
    let waitWritable: @Sendable (Int32, UInt64)
        -> Result<Void, InvestigationMachineZeroArgumentSystemError>
    let write: @Sendable (Int32, Data)
        -> Result<Int, InvestigationMachineZeroArgumentSystemError>

    static let system = Self(
        continuousNanoseconds: { DispatchTime.now().uptimeNanoseconds },
        waitWritable: zeroArgumentWaitWritable,
        write: zeroArgumentWrite
    )
}

struct InvestigationMachineZeroArgumentOutputWriter: Sendable {
    private static let maximumOutputWindowNanoseconds: UInt64 = 5_000_000_000
    private let system: InvestigationMachineZeroArgumentOutputSystem

    init(system: InvestigationMachineZeroArgumentOutputSystem) {
        self.system = system
    }

    func write(_ data: Data) throws {
        try write(
            data, descriptor: STDOUT_FILENO,
            maximumByteCount:
                InvestigationMachineDriverCompletionArtifact.maximumByteCount
        )
    }

    func write(_ data: Data, descriptor: Int32, maximumByteCount: Int) throws {
        guard
            !data.isEmpty,
            data.count <= maximumByteCount,
            descriptor == STDOUT_FILENO || descriptor == STDERR_FILENO
        else {
            throw InvestigationMachineZeroArgumentEntryError.outputUnavailable
        }
        let deadline = system.continuousNanoseconds().addingReportingOverflow(
            Self.maximumOutputWindowNanoseconds
        )
        guard !deadline.overflow else {
            throw InvestigationMachineZeroArgumentEntryError.outputUnavailable
        }

        var offset = 0
        while offset < data.count {
            let waitResult = system.waitWritable(
                descriptor, deadline.partialValue
            )
            try requireBeforeDeadline(deadline.partialValue)
            switch waitResult {
            case .failure(let error) where error.errno == EINTR:
                continue
            case .failure:
                throw InvestigationMachineZeroArgumentEntryError
                    .outputUnavailable
            case .success:
                break
            }
            let remaining = data.subdata(in: offset..<data.count)
            let writeResult = system.write(descriptor, remaining)
            switch writeResult {
            case .failure(let error) where error.errno == EINTR:
                continue
            case .failure:
                throw InvestigationMachineZeroArgumentEntryError
                    .outputUnavailable
            case .success(let count):
                guard count > 0, count <= remaining.count else {
                    throw InvestigationMachineZeroArgumentEntryError
                        .outputUnavailable
                }
                offset += count
                // A complete canonical artifact is already irrevocably
                // committed. Do not reclassify that success because of a
                // later clock sample or cancellation.
                if offset == data.count { return }
                try requireBeforeDeadline(deadline.partialValue)
            }
        }
    }

    private func requireBeforeDeadline(_ deadlineNanoseconds: UInt64) throws {
        guard system.continuousNanoseconds() < deadlineNanoseconds else {
            throw InvestigationMachineZeroArgumentEntryError.outputUnavailable
        }
    }
}

struct InvestigationMachineZeroArgumentEntryDependencies: Sendable {
    let validateInvocation: @Sendable () throws -> Void
    let selectRole: @Sendable () throws -> InvestigationMachineZeroArgumentRole
    let runInner: @Sendable () async throws -> Void
    let observeInstalledDriver: @Sendable () throws -> Void
    let readPlan: @Sendable () throws -> any InvestigationMachineEightEpochPlan
    let runCohort: @Sendable (any InvestigationMachineEightEpochPlan) async throws
        -> InvestigationMachineEightEpochCompletionSummary
    let checkCancellation: @Sendable () throws -> Void
    let revalidateOuter: @Sendable (
        InvestigationMachineZeroArgumentOuterDescriptorObservation
    ) throws -> Void
    let writeArtifact: @Sendable (Data) throws -> Void
    let prepareEvidencePlan: @Sendable (any InvestigationMachineEightEpochPlan) async throws
        -> any InvestigationMachineEightEpochPlan
    let finishEvidenceCollection: @Sendable
        (InvestigationMachineEightEpochCompletionSummary) throws -> Data?
    let abortEvidenceCollection: @Sendable () -> Void
    let writeEvidence: @Sendable (Data) throws -> Void

    init(
        validateInvocation: @escaping @Sendable () throws -> Void = {},
        selectRole: @escaping @Sendable () throws
            -> InvestigationMachineZeroArgumentRole,
        runInner: @escaping @Sendable () async throws -> Void,
        observeInstalledDriver: @escaping @Sendable () throws -> Void,
        readPlan: @escaping @Sendable () throws
            -> any InvestigationMachineEightEpochPlan,
        runCohort: @escaping @Sendable (
            any InvestigationMachineEightEpochPlan
        ) async throws -> InvestigationMachineEightEpochCompletionSummary,
        checkCancellation: @escaping @Sendable () throws -> Void,
        revalidateOuter: @escaping @Sendable (
            InvestigationMachineZeroArgumentOuterDescriptorObservation
        ) throws -> Void,
        writeArtifact: @escaping @Sendable (Data) throws -> Void,
        prepareEvidencePlan: @escaping @Sendable
            (any InvestigationMachineEightEpochPlan) async throws
            -> any InvestigationMachineEightEpochPlan = { $0 },
        finishEvidenceCollection: @escaping @Sendable
            (InvestigationMachineEightEpochCompletionSummary) throws -> Data? = { _ in nil },
        abortEvidenceCollection: @escaping @Sendable () -> Void = {},
        writeEvidence: @escaping @Sendable (Data) throws -> Void = { _ in }
    ) {
        self.validateInvocation = validateInvocation
        self.selectRole = selectRole
        self.runInner = runInner
        self.observeInstalledDriver = observeInstalledDriver
        self.readPlan = readPlan
        self.runCohort = runCohort
        self.checkCancellation = checkCancellation
        self.revalidateOuter = revalidateOuter
        self.writeArtifact = writeArtifact
        self.prepareEvidencePlan = prepareEvidencePlan
        self.finishEvidenceCollection = finishEvidenceCollection
        self.abortEvidenceCollection = abortEvidenceCollection
        self.writeEvidence = writeEvidence
    }
}

struct InvestigationMachineZeroArgumentEntry: Sendable {
    private let dependencies: InvestigationMachineZeroArgumentEntryDependencies

    init(dependencies: InvestigationMachineZeroArgumentEntryDependencies) {
        self.dependencies = dependencies
    }

    static func production(
        realUserID: @escaping @Sendable () -> uid_t,
        effectiveUserID: @escaping @Sendable () -> uid_t,
        realGroupID: @escaping @Sendable () -> gid_t,
        effectiveGroupID: @escaping @Sendable () -> gid_t,
        argumentCount: @escaping @Sendable () -> Int32,
        source: any InvestigationMachineInstalledDriverObservationSource
    ) -> Self {
        let roleSelector = InvestigationMachineZeroArgumentRoleSelector(
            system: .system
        )
        let installedObserver = InvestigationMachineInstalledDriverObserver(
            realUserID: realUserID, effectiveUserID: effectiveUserID,
            realGroupID: realGroupID, effectiveGroupID: effectiveGroupID,
            argumentCount: argumentCount, source: source
        )
        let writer = InvestigationMachineZeroArgumentOutputWriter(
            system: .system
        )
        return Self(dependencies: .init(
            validateInvocation: {
                let identities = (
                    realUserID(), effectiveUserID(),
                    realGroupID(), effectiveGroupID()
                )
                guard
                    identities.0 == 0, identities.1 == 0,
                    identities.2 == 0, identities.3 == 0
                else {
                    throw InvestigationMachineZeroArgumentEntryError
                        .rootAuthorityRequired
                }
                guard argumentCount() == 1 else {
                    throw InvestigationMachineZeroArgumentEntryError
                        .invalidInvocation
                }
            },
            selectRole: { try roleSelector.select() },
            runInner: {
                _ = try await InvestigationMachineDarwinOuterInnerComposition()
                    .runInner()
            },
            observeInstalledDriver: {
                _ = try installedObserver.observe()
            },
            readPlan: {
                try InvestigationMachineFixedCapsuleIntake().read()
            },
            runCohort: { plan in
                try await InvestigationMachineEightEpochCohort(
                    plan: plan,
                    executionFactory:
                        InvestigationMachineDarwinOuterInnerExecutionFactory()
                ).run()
            },
            checkCancellation: {
                guard !Task.isCancelled else {
                    throw InvestigationMachineZeroArgumentEntryError.cancelled
                }
            },
            revalidateOuter: { try roleSelector.revalidate($0) },
            writeArtifact: { try writer.write($0) },
            prepareEvidencePlan: { plan in
                let first = try await plan.takeNext()
                try InvestigationMachineEpochEvidenceCollection.begin(
                    attemptUUID: first.outerAttemptUUID
                )
                return InvestigationMachinePreboundEpochPlan(
                    first: first, remainder: plan)
            },
            finishEvidenceCollection: {
                try InvestigationMachineEpochEvidenceCollection.finish(summary: $0)
            },
            abortEvidenceCollection:
                InvestigationMachineEpochEvidenceCollection.abort,
            writeEvidence: { bytes in
                let line = Data(
                    ("STORNAUT_TASK39_IIC_EPOCH_BUNDLE_V1 "
                        + bytes.base64EncodedString() + "\n").utf8
                )
                try writer.write(
                    line, descriptor: STDERR_FILENO,
                    maximumByteCount: 1 << 20
                )
            }
        ))
    }

    func run() async throws {
        do {
            try dependencies.validateInvocation()
        } catch {
            throw Self.knownOrUncertain(error)
        }

        let role: InvestigationMachineZeroArgumentRole
        do {
            role = try dependencies.selectRole()
        } catch {
            throw Self.knownOrUncertain(error)
        }

        switch role {
        case .inner:
            do {
                try await dependencies.runInner()
            } catch {
                throw Self.normalizedInner(error)
            }

        case .outer(let observation):
            var evidenceCollectionCompleted = false
            defer { if !evidenceCollectionCompleted {
                dependencies.abortEvidenceCollection() } }
            do {
                try dependencies.observeInstalledDriver()
            } catch let error as InvestigationMachineInstalledDriverObservationError {
                switch error {
                case .rootAuthorityRequired:
                    throw InvestigationMachineZeroArgumentEntryError
                        .rootAuthorityRequired
                case .invalidInvocation:
                    throw InvestigationMachineZeroArgumentEntryError
                        .invalidInvocation
                case .sourceUnavailable, .invalidObservation:
                    throw InvestigationMachineZeroArgumentEntryError
                        .installedObservationUnavailable
                }
            } catch {
                throw Self.knownOrUncertain(error)
            }

            let plan: any InvestigationMachineEightEpochPlan
            do {
                plan = try dependencies.readPlan()
            } catch {
                if error is InvestigationMachineFixedCapsuleIntakeError {
                    throw InvestigationMachineZeroArgumentEntryError
                        .invalidInput
                }
                throw Self.knownOrUncertain(error)
            }

            let boundPlan: any InvestigationMachineEightEpochPlan
            do { boundPlan = try await dependencies.prepareEvidencePlan(plan) }
            catch { throw Self.knownOrUncertain(error) }

            let summary: InvestigationMachineEightEpochCompletionSummary
            do {
                summary = try await dependencies.runCohort(boundPlan)
            } catch {
                throw Self.normalizedCohort(error)
            }

            let evidence: Data?
            do {
                evidence = try dependencies.finishEvidenceCollection(summary)
                evidenceCollectionCompleted = true
            } catch {
                throw Self.knownOrUncertain(error)
            }

            do {
                try dependencies.checkCancellation()
            } catch {
                throw Self.knownOrUncertain(error)
            }
            do {
                try dependencies.revalidateOuter(observation)
            } catch {
                throw Self.knownOrUncertain(error)
            }
            do {
                if let evidence { try dependencies.writeEvidence(evidence) }
                let artifact = if let evidence {
                    try InvestigationMachineDriverCompletionArtifact(
                        summary: summary, driverEvidenceBundleSHA256: .hashing(evidence))
                } else {
                    try InvestigationMachineDriverCompletionArtifact(summary: summary)
                }
                let encoded = try artifact.encoded()
                try dependencies.writeArtifact(encoded)
            } catch {
                throw Self.knownOrUncertain(error)
            }
        }
    }

    private static func knownOrUncertain(
        _ error: any Error
    ) -> InvestigationMachineZeroArgumentEntryError {
        if let error = error as? InvestigationMachineZeroArgumentEntryError {
            return error
        }
        // An untyped cancellation does not prove that all owned descendants
        // reached a terminal state. Only a subsystem's typed `.cancelled`
        // outcome, or the post-cohort check above, is safe to classify as 83.
        if error is CancellationError { return .containmentUncertain }
        return .containmentUncertain
    }

    private static func normalizedInner(
        _ error: any Error
    ) -> InvestigationMachineZeroArgumentEntryError {
        if let error = error as? InvestigationMachineZeroArgumentEntryError {
            return error
        }
        if error is CancellationError { return .containmentUncertain }
        if let error = error as?
            InvestigationMachineDarwinOuterInnerCompositionError
        {
            switch error {
            case .terminalUncertain: return .containmentUncertain
            // The composition currently may report cancellation after a
            // terminal-observer or exit-classification uncertainty. It does
            // not carry enough precedence information for exit 83.
            case .cancelled: return .containmentUncertain
            case .alreadyConsumed, .invalidSelection, .deadlineInvalid,
                 .protocolInvalid:
                return .protocolFailure
            }
        }
        if let error = error as? InvestigationMachineDarwinOuterInnerSessionError {
            switch error {
            case .descriptorInvalid, .identityInvalid:
                return .invalidRole
            case .retirementUncertain:
                return .containmentUncertain
            case .alreadyConsumed, .operationInFlight, .deadlineInvalid,
                 .spawnFailed, .transportUnavailable:
                return .protocolFailure
            }
        }
        return .containmentUncertain
    }

    private static func normalizedCohort(
        _ error: any Error
    ) -> InvestigationMachineZeroArgumentEntryError {
        if let error = error as? InvestigationMachineZeroArgumentEntryError {
            return error
        }
        if error is CancellationError { return .containmentUncertain }
        if error is InvestigationMachineFixedCapsuleIntakeError {
            return .invalidInput
        }
        if error is InvestigationMachineSingleEpochPhysicalBridgeError {
            return .protocolFailure
        }
        if let error = error as? InvestigationMachineEightEpochCohortError {
            return error == .cancelled ? .cancelled : .protocolFailure
        }
        if let error = error as? InvestigationMachineHelperEpochContinuityError {
            switch error {
            case .containmentUncertain: return .containmentUncertain
            case .cancelled: return .cancelled
            case .alreadyConsumed, .invalidPredecessor, .invalidCompletion:
                return .protocolFailure
            }
        }
        if let error = error as?
            InvestigationMachineDarwinOuterInnerCompositionError
        {
            switch error {
            case .terminalUncertain: return .containmentUncertain
            // The composition currently may report cancellation after a
            // terminal-observer or exit-classification uncertainty. It does
            // not carry enough precedence information for exit 83.
            case .cancelled: return .containmentUncertain
            case .alreadyConsumed, .invalidSelection, .deadlineInvalid,
                 .protocolInvalid:
                return .protocolFailure
            }
        }
        if let error = error as? InvestigationMachineSingleEpochError {
            switch error {
            case .claimTerminalUncertain, .releaseTerminalUncertain,
                 .abortTerminalUncertain, .retirementUncertain,
                 .ownershipTerminalUncertain:
                return .containmentUncertain
            case .cancelled:
                return .cancelled
            default:
                return .protocolFailure
            }
        }
        return .containmentUncertain
    }
}

private actor InvestigationMachinePreboundEpochPlan: InvestigationMachineEightEpochPlan {
    private var first: InvestigationMachineFixedEpochSelection?
    private let remainder: any InvestigationMachineEightEpochPlan

    init(first: InvestigationMachineFixedEpochSelection,
        remainder: any InvestigationMachineEightEpochPlan) {
        self.first = first
        self.remainder = remainder
    }

    func takeNext() async throws -> InvestigationMachineFixedEpochSelection {
        if let first { self.first = nil; return first }
        return try await remainder.takeNext()
    }
}

private func zeroArgumentUUIDIsNonzero(_ value: UUID) -> Bool {
    value != UUID(
        uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    )
}

private func zeroArgumentDigestIsNonzero(
    _ value: InvestigationHandoffSHA256
) -> Bool {
    value.rawBytes.contains(where: { $0 != 0 })
}

private func zeroArgumentData(_ value: UUID) -> Data {
    var bytes = value.uuid
    return withUnsafeBytes(of: &bytes) { Data($0) }
}

private func zeroArgumentData(_ value: UInt32) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 24),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}

private func zeroArgumentUInt32(_ data: Data) throws -> UInt32 {
    guard data.count == 4 else {
        throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
    }
    return data.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
}

private func zeroArgumentUUID(_ data: Data) throws -> UUID {
    guard data.count == 16 else {
        throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
    }
    var bytes: uuid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    let copied = withUnsafeMutableBytes(of: &bytes) { target in
        data.copyBytes(to: target)
    }
    guard copied == 16 else {
        throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
    }
    return UUID(uuid: bytes)
}

private func zeroArgumentWritable(_ flags: Int32) -> Bool {
    let access = flags & O_ACCMODE
    return access == O_WRONLY || access == O_RDWR
}

private func zeroArgumentNodeIsValid(
    _ node: InvestigationMachineDarwinDescriptorNodeObservation
) -> Bool {
    // Darwin anonymous pipes report st_dev == 0. Their stable identity is the
    // nonzero kernel inode plus S_IFIFO; FD 0's stronger regular-file/device
    // provenance remains owned by InvestigationMachineFixedCapsuleIntake.
    node.inode > 0 && node.fileType != 0
}

private func zeroArgumentStandardErrorIsValid(
    _ observation: InvestigationMachineDarwinStandardErrorObservation
) -> Bool {
    observation.inode > 0
        && zeroArgumentWritable(observation.statusFlags)
        && observation.isTTY
        && (observation.foregroundProcessGroup ?? 0) > 1
        && observation.mode & mode_t(S_IFMT) == mode_t(S_IFCHR)
}

private func zeroArgumentErrorNode(
    _ node: InvestigationMachineDarwinDescriptorNodeObservation,
    matches observation: InvestigationMachineDarwinStandardErrorObservation
) -> Bool {
    node.deviceID == observation.deviceID
        && node.inode == observation.inode
        && node.fileType == observation.mode & mode_t(S_IFMT)
}

private func zeroArgumentDescriptorFlags(
    _ descriptor: Int32
) -> Result<Int32, InvestigationMachineZeroArgumentSystemError> {
    Darwin.errno = 0
    let value = fcntl(descriptor, F_GETFD)
    guard value >= 0 else {
        return .failure(.init(errno: Darwin.errno == 0 ? EIO : Darwin.errno))
    }
    return .success(value)
}

private func zeroArgumentDescriptorStatusFlags(
    _ descriptor: Int32
) -> Result<Int32, InvestigationMachineZeroArgumentSystemError> {
    Darwin.errno = 0
    let value = fcntl(descriptor, F_GETFL)
    guard value >= 0 else {
        return .failure(.init(errno: Darwin.errno == 0 ? EIO : Darwin.errno))
    }
    return .success(value)
}

private func zeroArgumentSetDescriptorFlags(
    _ descriptor: Int32, _ flags: Int32
) -> Result<Void, InvestigationMachineZeroArgumentSystemError> {
    Darwin.errno = 0
    guard fcntl(descriptor, F_SETFD, flags) == 0 else {
        return .failure(.init(errno: Darwin.errno == 0 ? EIO : Darwin.errno))
    }
    return .success(())
}

private func zeroArgumentSetStatusFlags(
    _ descriptor: Int32, _ flags: Int32
) -> Result<Void, InvestigationMachineZeroArgumentSystemError> {
    Darwin.errno = 0
    guard fcntl(descriptor, F_SETFL, flags) == 0 else {
        return .failure(.init(errno: Darwin.errno == 0 ? EIO : Darwin.errno))
    }
    return .success(())
}

private func zeroArgumentNoSigpipe(
    _ descriptor: Int32
) -> Result<Int32, InvestigationMachineZeroArgumentSystemError> {
    Darwin.errno = 0
    let value = fcntl(descriptor, F_GETNOSIGPIPE)
    guard value >= 0 else {
        return .failure(.init(errno: Darwin.errno == 0 ? EIO : Darwin.errno))
    }
    return .success(value)
}

private func zeroArgumentSetNoSigpipe(
    _ descriptor: Int32
) -> Result<Void, InvestigationMachineZeroArgumentSystemError> {
    Darwin.errno = 0
    guard fcntl(descriptor, F_SETNOSIGPIPE, 1) == 0 else {
        return .failure(.init(errno: Darwin.errno == 0 ? EIO : Darwin.errno))
    }
    return .success(())
}

private func zeroArgumentDescriptorNode(
    _ descriptor: Int32
) -> Result<
    InvestigationMachineDarwinDescriptorNodeObservation,
    InvestigationMachineZeroArgumentSystemError
> {
    Darwin.errno = 0
    var status = stat()
    guard fstat(descriptor, &status) == 0 else {
        return .failure(.init(errno: Darwin.errno == 0 ? EIO : Darwin.errno))
    }
    return .success(.init(
        deviceID: UInt64(bitPattern: Int64(status.st_dev)),
        inode: UInt64(status.st_ino),
        fileType: status.st_mode & mode_t(S_IFMT)
    ))
}

private func zeroArgumentStandardErrorObservation() throws
    -> InvestigationMachineDarwinStandardErrorObservation
{
    Darwin.errno = 0
    var status = stat()
    guard fstat(STDERR_FILENO, &status) == 0 else {
        throw InvestigationMachineZeroArgumentEntryError
            .invalidOuterDescriptor
    }
    let flags = try zeroArgumentDescriptorStatusFlags(STDERR_FILENO).get()
    let tty = isatty(STDERR_FILENO) == 1
    let foreground: Int32?
    if tty {
        let value = tcgetpgrp(STDERR_FILENO)
        guard value > 1 else {
            throw InvestigationMachineZeroArgumentEntryError
                .invalidOuterDescriptor
        }
        foreground = value
    } else {
        foreground = nil
    }
    return .init(
        deviceID: UInt64(bitPattern: Int64(status.st_dev)),
        inode: UInt64(status.st_ino), mode: status.st_mode,
        statusFlags: flags, isTTY: tty,
        foregroundProcessGroup: foreground
    )
}

private func zeroArgumentWaitWritable(
    _ descriptor: Int32, _ deadlineNanoseconds: UInt64
) -> Result<Void, InvestigationMachineZeroArgumentSystemError> {
    while true {
        let now = DispatchTime.now().uptimeNanoseconds
        guard now < deadlineNanoseconds else {
            return .failure(.init(errno: ETIMEDOUT))
        }
        let remaining = deadlineNanoseconds - now
        let milliseconds = Int32(
            min(max(1, remaining / 1_000_000), UInt64(50))
        )
        var event = pollfd(fd: descriptor, events: Int16(POLLOUT), revents: 0)
        Darwin.errno = 0
        let result = poll(&event, 1, milliseconds)
        if result == 0 { continue }
        if result < 0 {
            let value = Darwin.errno == 0 ? EIO : Darwin.errno
            if value == EINTR { continue }
            return .failure(.init(errno: value))
        }
        let failures = Int16(POLLERR | POLLHUP | POLLNVAL)
        guard
            event.revents & Int16(POLLOUT) != 0,
            event.revents & failures == 0
        else {
            return .failure(.init(errno: EIO))
        }
        return .success(())
    }
}

private func zeroArgumentWrite(
    _ descriptor: Int32, _ data: Data
) -> Result<Int, InvestigationMachineZeroArgumentSystemError> {
    Darwin.errno = 0
    let count = data.withUnsafeBytes { bytes in
        Darwin.write(descriptor, bytes.baseAddress, bytes.count)
    }
    guard count >= 0 else {
        return .failure(.init(errno: Darwin.errno == 0 ? EIO : Darwin.errno))
    }
    return .success(count)
}
