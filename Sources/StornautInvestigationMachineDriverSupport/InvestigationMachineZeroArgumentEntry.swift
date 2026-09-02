import CInvestigationIdentitySupport
import Darwin
import Foundation
import Security
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

// This is a terminal transport receipt, not a machine-admission claim.
// Production v3 is a fixed 180-byte binary payload:
// attempt16 + capsule32 + whole32 + epochCount4 + claimSHA32 + bundleSHA32
// + selfSHA32, where selfSHA is SHA256(first148Bytes + 32 zero bytes).
package struct InvestigationMachineDriverCompletionArtifact:
    Sendable, Equatable
{
    package static let encodedByteCount = 180
    package static let maximumByteCount = encodedByteCount
    private static let completedEpochCount: UInt32 = 8

    package let outerAttemptUUID: UUID
    package let wholeCapsuleSHA256: InvestigationHandoffSHA256
    package let wholeInputSHA256: InvestigationHandoffSHA256
    package let completedEpochCount: UInt32
    package let lineageClaimSHA256: InvestigationHandoffSHA256
    package let driverEvidenceBundleSHA256: InvestigationHandoffSHA256
    package let selfSHA256: InvestigationHandoffSHA256

    package init(
        summary: InvestigationMachineEightEpochCompletionSummary,
        lineageClaimSHA256: InvestigationHandoffSHA256,
        driverEvidenceBundleSHA256: InvestigationHandoffSHA256
    ) throws {
        guard
            zeroArgumentUUIDIsNonzero(summary.outerAttemptUUID),
            zeroArgumentDigestIsNonzero(summary.wholeCapsuleSHA256),
            zeroArgumentDigestIsNonzero(summary.wholeInputSHA256),
            summary.completedEpochCount == Self.completedEpochCount,
            zeroArgumentDigestIsNonzero(lineageClaimSHA256),
            zeroArgumentDigestIsNonzero(driverEvidenceBundleSHA256)
        else {
            throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
        }

        outerAttemptUUID = summary.outerAttemptUUID
        wholeCapsuleSHA256 = summary.wholeCapsuleSHA256
        wholeInputSHA256 = summary.wholeInputSHA256
        completedEpochCount = summary.completedEpochCount
        self.lineageClaimSHA256 = lineageClaimSHA256
        self.driverEvidenceBundleSHA256 = driverEvidenceBundleSHA256
        do {
            let zero = try InvestigationHandoffSHA256(
                rawBytes: Data(
                    repeating: 0,
                    count: InvestigationHandoffSHA256.byteCount
                )
            )
            selfSHA256 = InvestigationHandoffSHA256.hashing(
                try Self.businessFields(
                    outerAttemptUUID: summary.outerAttemptUUID,
                    wholeCapsuleSHA256: summary.wholeCapsuleSHA256,
                    wholeInputSHA256: summary.wholeInputSHA256,
                    completedEpochCount: summary.completedEpochCount,
                    lineageClaimSHA256: lineageClaimSHA256,
                    driverEvidenceBundleSHA256: driverEvidenceBundleSHA256
                ) + zero.rawBytes
            )
        } catch {
            throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
        }
        guard zeroArgumentDigestIsNonzero(selfSHA256) else {
            throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
        }
    }

    package func encoded() throws -> Data {
        guard
            zeroArgumentUUIDIsNonzero(outerAttemptUUID),
            zeroArgumentDigestIsNonzero(wholeCapsuleSHA256),
            zeroArgumentDigestIsNonzero(wholeInputSHA256),
            completedEpochCount == Self.completedEpochCount,
            zeroArgumentDigestIsNonzero(lineageClaimSHA256),
            zeroArgumentDigestIsNonzero(driverEvidenceBundleSHA256),
            zeroArgumentDigestIsNonzero(selfSHA256)
        else {
            throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
        }
        do {
            let business = try Self.businessFields(
                outerAttemptUUID: outerAttemptUUID,
                wholeCapsuleSHA256: wholeCapsuleSHA256,
                wholeInputSHA256: wholeInputSHA256,
                completedEpochCount: completedEpochCount,
                lineageClaimSHA256: lineageClaimSHA256,
                driverEvidenceBundleSHA256: driverEvidenceBundleSHA256
            )
            let zero = try InvestigationHandoffSHA256(
                rawBytes: Data(repeating: 0, count: 32)
            )
            guard InvestigationHandoffSHA256.hashing(business + zero.rawBytes)
                == selfSHA256
            else {
                throw InvestigationMachineZeroArgumentEntryError
                    .invalidCompletion
            }
            return business + selfSHA256.rawBytes
        } catch let error as InvestigationMachineZeroArgumentEntryError {
            throw error
        } catch {
            throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
        }
    }

    package static func decode(_ data: Data) throws -> Self {
        guard data.count == encodedByteCount else {
            throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
        }
        do {
            let summary = InvestigationMachineEightEpochCompletionSummary(
                outerAttemptUUID: try zeroArgumentUUID(
                    data.subdata(in: 0..<16)
                ),
                wholeCapsuleSHA256: try .init(rawBytes: data.subdata(in: 16..<48)),
                wholeInputSHA256: try .init(rawBytes: data.subdata(in: 48..<80)),
                completedEpochCount: try zeroArgumentUInt32(
                    data.subdata(in: 80..<84)
                )
            )
            let value = try Self(
                summary: summary,
                lineageClaimSHA256: .init(rawBytes: data.subdata(in: 84..<116)),
                driverEvidenceBundleSHA256: .init(
                    rawBytes: data.subdata(in: 116..<148)
                )
            )
            guard
                value.selfSHA256 == (try .init(rawBytes: data.subdata(in: 148..<180))),
                try value.encoded() == data
            else {
                throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
            }
            return value
        } catch let error as InvestigationMachineZeroArgumentEntryError {
            throw error
        } catch {
            throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
        }
    }

    package static func decodeProduction(_ data: Data) throws -> Self {
        try decode(data)
    }

    private static func businessFields(
        outerAttemptUUID: UUID,
        wholeCapsuleSHA256: InvestigationHandoffSHA256,
        wholeInputSHA256: InvestigationHandoffSHA256,
        completedEpochCount: UInt32,
        lineageClaimSHA256: InvestigationHandoffSHA256,
        driverEvidenceBundleSHA256: InvestigationHandoffSHA256
    ) throws -> Data {
        let fields = [
            zeroArgumentData(outerAttemptUUID),
            wholeCapsuleSHA256.rawBytes,
            wholeInputSHA256.rawBytes,
            zeroArgumentData(completedEpochCount),
            lineageClaimSHA256.rawBytes,
            driverEvidenceBundleSHA256.rawBytes,
        ]
        guard fields.reduce(0, { $0 + $1.count }) == 148 else {
            throw InvestigationMachineZeroArgumentEntryError.invalidCompletion
        }
        return fields.reduce(into: Data()) { $0.append($1) }
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
    let descriptorStatusFlags: @Sendable (Int32)
        -> Result<Int32, InvestigationMachineZeroArgumentSystemError>
    let setStatusFlags: @Sendable (Int32, Int32)
        -> Result<Void, InvestigationMachineZeroArgumentSystemError>
    let waitWritable: @Sendable (Int32, UInt64)
        -> Result<Void, InvestigationMachineZeroArgumentSystemError>
    let write: @Sendable (Int32, Data)
        -> Result<Int, InvestigationMachineZeroArgumentSystemError>

    static let system = Self(
        continuousNanoseconds: { DispatchTime.now().uptimeNanoseconds },
        descriptorStatusFlags: zeroArgumentDescriptorStatusFlags,
        setStatusFlags: zeroArgumentSetStatusFlags,
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

    func beginDeadline() throws -> UInt64 {
        let deadline = system.continuousNanoseconds().addingReportingOverflow(
            Self.maximumOutputWindowNanoseconds
        )
        guard !deadline.overflow else {
            throw InvestigationMachineZeroArgumentEntryError.outputUnavailable
        }
        return deadline.partialValue
    }

    func write(_ data: Data) throws {
        try write(
            data, descriptor: STDOUT_FILENO,
            maximumByteCount:
                InvestigationMachineDriverCompletionArtifact.maximumByteCount
        )
    }

    func write(_ data: Data, descriptor: Int32, maximumByteCount: Int) throws {
        try write(
            data,
            descriptor: descriptor,
            maximumByteCount: maximumByteCount,
            deadlineNanoseconds: try beginDeadline()
        )
    }

    func write(
        _ data: Data,
        descriptor: Int32,
        maximumByteCount: Int,
        deadlineNanoseconds: UInt64
    ) throws {
        guard
            !data.isEmpty,
            data.count <= maximumByteCount,
            descriptor == STDOUT_FILENO || descriptor == STDERR_FILENO
        else {
            throw InvestigationMachineZeroArgumentEntryError.outputUnavailable
        }
        try requireBeforeDeadline(deadlineNanoseconds)
        let restoreFlags = try prepareDeadlineSafeDescriptor(descriptor)
        do {
            try writeLoop(
                data,
                descriptor: descriptor,
                deadlineNanoseconds: deadlineNanoseconds
            )
        } catch {
            do {
                try restoreDescriptorFlagsIfNeeded(
                    restoreFlags,
                    descriptor: descriptor
                )
            } catch {
                throw InvestigationMachineZeroArgumentEntryError
                    .containmentUncertain
            }
            throw error
        }
        do {
            try restoreDescriptorFlagsIfNeeded(
                restoreFlags,
                descriptor: descriptor
            )
        } catch {
            throw InvestigationMachineZeroArgumentEntryError
                .containmentUncertain
        }
    }

    private func writeLoop(
        _ data: Data,
        descriptor: Int32,
        deadlineNanoseconds: UInt64
    ) throws {
        var offset = 0
        while offset < data.count {
            let waitResult = system.waitWritable(
                descriptor,
                deadlineNanoseconds
            )
            try requireBeforeDeadline(deadlineNanoseconds)
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
            case .failure(let error)
                where error.errno == EINTR
                    || error.errno == EAGAIN
                    || error.errno == EWOULDBLOCK:
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
                try requireBeforeDeadline(deadlineNanoseconds)
            }
        }
    }

    private func prepareDeadlineSafeDescriptor(
        _ descriptor: Int32
    ) throws -> Int32? {
        let flags = try system.descriptorStatusFlags(descriptor).get()
        guard flags & O_NONBLOCK == 0 else { return nil }
        let requested = flags | O_NONBLOCK
        try system.setStatusFlags(descriptor, requested).get()
        do {
            guard try system.descriptorStatusFlags(descriptor).get() == requested
            else {
                do {
                    try restoreDescriptorFlagsIfNeeded(
                        flags,
                        descriptor: descriptor
                    )
                } catch {
                    throw InvestigationMachineZeroArgumentEntryError
                        .containmentUncertain
                }
                throw InvestigationMachineZeroArgumentEntryError
                    .containmentUncertain
            }
        } catch let error as InvestigationMachineZeroArgumentEntryError {
            throw error
        } catch {
            do {
                try restoreDescriptorFlagsIfNeeded(
                    flags,
                    descriptor: descriptor
                )
            } catch {
                throw InvestigationMachineZeroArgumentEntryError
                    .containmentUncertain
            }
            throw InvestigationMachineZeroArgumentEntryError
                .containmentUncertain
        }
        return flags
    }

    private func restoreDescriptorFlagsIfNeeded(
        _ originalFlags: Int32?,
        descriptor: Int32
    ) throws {
        guard let originalFlags else { return }
        try system.setStatusFlags(descriptor, originalFlags).get()
        guard try system.descriptorStatusFlags(descriptor).get() == originalFlags
        else {
            throw InvestigationMachineZeroArgumentEntryError.outputUnavailable
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
    let prebindPlan: @Sendable (any InvestigationMachineEightEpochPlan) async throws
        -> InvestigationMachineZeroArgumentPreboundPlan
    let collectLineageClaim: @Sendable (
        InvestigationMachineFixedEpochSelection
    ) throws -> ResolvedRootDriverClaimV1
    let writeFramedClaim: @Sendable (ResolvedRootDriverClaimV1) throws -> Void
    let stopForGate: @Sendable () throws -> Void
    let beginEvidenceCollection: @Sendable (UUID) throws -> Void
    let runCohort: @Sendable (any InvestigationMachineEightEpochPlan) async throws
        -> InvestigationMachineEightEpochCompletionSummary
    let checkCancellation: @Sendable () throws -> Void
    let revalidateOuter: @Sendable (
        InvestigationMachineZeroArgumentOuterDescriptorObservation
    ) throws -> Void
    let beginTerminalOutputDeadline: @Sendable () throws -> UInt64
    let writeArtifact: @Sendable (Data, UInt64) throws -> Void
    let finishEvidenceCollection: @Sendable
        (InvestigationMachineEightEpochCompletionSummary) throws -> Data?
    let abortEvidenceCollection: @Sendable () -> Void
    let writeEvidence: @Sendable
        (ResolvedRootDriverClaimV1, Data, UInt64) throws -> Void

    init(
        validateInvocation: @escaping @Sendable () throws -> Void = {},
        selectRole: @escaping @Sendable () throws
            -> InvestigationMachineZeroArgumentRole,
        runInner: @escaping @Sendable () async throws -> Void,
        observeInstalledDriver: @escaping @Sendable () throws -> Void,
        readPlan: @escaping @Sendable () throws
            -> any InvestigationMachineEightEpochPlan,
        prebindPlan: @escaping @Sendable
            (any InvestigationMachineEightEpochPlan) async throws
            -> InvestigationMachineZeroArgumentPreboundPlan = {
                let first = try await $0.takeNext()
                return InvestigationMachineZeroArgumentPreboundPlan(
                    firstSelection: first,
                    plan: InvestigationMachinePreboundEpochPlan(
                        first: first,
                        remainder: $0
                    )
                )
            },
        collectLineageClaim: @escaping @Sendable (
            InvestigationMachineFixedEpochSelection
        ) throws -> ResolvedRootDriverClaimV1 = { _ in
            throw InvestigationMachineZeroArgumentEntryError.protocolFailure
        },
        writeFramedClaim: @escaping @Sendable
            (ResolvedRootDriverClaimV1) throws -> Void = { _ in
            throw InvestigationMachineZeroArgumentEntryError.protocolFailure
        },
        stopForGate: @escaping @Sendable () throws -> Void = {
            throw InvestigationMachineZeroArgumentEntryError.protocolFailure
        },
        beginEvidenceCollection: @escaping @Sendable (UUID) throws -> Void = { _ in
            throw InvestigationMachineZeroArgumentEntryError.protocolFailure
        },
        runCohort: @escaping @Sendable (
            any InvestigationMachineEightEpochPlan
        ) async throws -> InvestigationMachineEightEpochCompletionSummary,
        checkCancellation: @escaping @Sendable () throws -> Void,
        revalidateOuter: @escaping @Sendable (
            InvestigationMachineZeroArgumentOuterDescriptorObservation
        ) throws -> Void,
        beginTerminalOutputDeadline: @escaping @Sendable () throws -> UInt64 = {
            throw InvestigationMachineZeroArgumentEntryError.outputUnavailable
        },
        writeArtifact: @escaping @Sendable (Data, UInt64) throws -> Void = { _, _ in
            throw InvestigationMachineZeroArgumentEntryError.protocolFailure
        },
        finishEvidenceCollection: @escaping @Sendable
            (InvestigationMachineEightEpochCompletionSummary) throws -> Data? = { _ in nil },
        abortEvidenceCollection: @escaping @Sendable () -> Void = {},
        writeEvidence: @escaping @Sendable (
            ResolvedRootDriverClaimV1, Data, UInt64
        ) throws -> Void = { _, _, _ in }
    ) {
        self.validateInvocation = validateInvocation
        self.selectRole = selectRole
        self.runInner = runInner
        self.observeInstalledDriver = observeInstalledDriver
        self.readPlan = readPlan
        self.prebindPlan = prebindPlan
        self.collectLineageClaim = collectLineageClaim
        self.writeFramedClaim = writeFramedClaim
        self.stopForGate = stopForGate
        self.beginEvidenceCollection = beginEvidenceCollection
        self.runCohort = runCohort
        self.checkCancellation = checkCancellation
        self.revalidateOuter = revalidateOuter
        self.beginTerminalOutputDeadline = beginTerminalOutputDeadline
        self.writeArtifact = writeArtifact
        self.finishEvidenceCollection = finishEvidenceCollection
        self.abortEvidenceCollection = abortEvidenceCollection
        self.writeEvidence = writeEvidence
    }

    init(
        validateInvocation: @escaping @Sendable () throws -> Void = {},
        selectRole: @escaping @Sendable () throws
            -> InvestigationMachineZeroArgumentRole,
        runInner: @escaping @Sendable () async throws -> Void,
        observeInstalledDriver: @escaping @Sendable () throws -> Void,
        readPlan: @escaping @Sendable () throws
            -> any InvestigationMachineEightEpochPlan,
        prebindPlan: @escaping @Sendable
            (any InvestigationMachineEightEpochPlan) async throws
            -> InvestigationMachineZeroArgumentPreboundPlan = {
                let first = try await $0.takeNext()
                return InvestigationMachineZeroArgumentPreboundPlan(
                    firstSelection: first,
                    plan: InvestigationMachinePreboundEpochPlan(
                        first: first,
                        remainder: $0
                    )
                )
            },
        collectLineageClaim: @escaping @Sendable (
            InvestigationMachineFixedEpochSelection
        ) throws -> ResolvedRootDriverClaimV1 = { _ in
            throw InvestigationMachineZeroArgumentEntryError.protocolFailure
        },
        writeFramedClaim: @escaping @Sendable
            (ResolvedRootDriverClaimV1) throws -> Void = { _ in
            throw InvestigationMachineZeroArgumentEntryError.protocolFailure
        },
        stopForGate: @escaping @Sendable () throws -> Void = {
            throw InvestigationMachineZeroArgumentEntryError.protocolFailure
        },
        beginEvidenceCollection: @escaping @Sendable (UUID) throws -> Void = { _ in
            throw InvestigationMachineZeroArgumentEntryError.protocolFailure
        },
        runCohort: @escaping @Sendable (
            any InvestigationMachineEightEpochPlan
        ) async throws -> InvestigationMachineEightEpochCompletionSummary,
        checkCancellation: @escaping @Sendable () throws -> Void,
        revalidateOuter: @escaping @Sendable (
            InvestigationMachineZeroArgumentOuterDescriptorObservation
        ) throws -> Void,
        writeArtifact: @escaping @Sendable (Data) throws -> Void,
        finishEvidenceCollection: @escaping @Sendable
            (InvestigationMachineEightEpochCompletionSummary) throws -> Data? = { _ in nil },
        abortEvidenceCollection: @escaping @Sendable () -> Void = {},
        writeEvidence: @escaping @Sendable (
            ResolvedRootDriverClaimV1, Data
        ) throws -> Void = { _, _ in }
    ) {
        self.init(
            validateInvocation: validateInvocation,
            selectRole: selectRole,
            runInner: runInner,
            observeInstalledDriver: observeInstalledDriver,
            readPlan: readPlan,
            prebindPlan: prebindPlan,
            collectLineageClaim: collectLineageClaim,
            writeFramedClaim: writeFramedClaim,
            stopForGate: stopForGate,
            beginEvidenceCollection: beginEvidenceCollection,
            runCohort: runCohort,
            checkCancellation: checkCancellation,
            revalidateOuter: revalidateOuter,
            beginTerminalOutputDeadline: { UInt64.max },
            writeArtifact: { data, _ in
                try writeArtifact(data)
            },
            finishEvidenceCollection: finishEvidenceCollection,
            abortEvidenceCollection: abortEvidenceCollection,
            writeEvidence: { claim, data, _ in
                try writeEvidence(claim, data)
            }
        )
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
            collectLineageClaim: { selection in
                do {
                    let installedObservation = try installedObserver.observe()
                    return try InvestigationMachineResolvedRootDriverClaimCollector(
                        source: try zeroArgumentResolvedRootDriverClaimSource(
                            installedObservation: installedObservation
                        )
                    ).collect(binding: .init(
                        outerAttemptUUID: selection.outerAttemptUUID,
                        wholeInputSHA256: selection.wholeInputSHA256
                    ))
                } catch let error as InvestigationMachineZeroArgumentEntryError {
                    throw error
                } catch {
                    throw InvestigationMachineZeroArgumentEntryError
                        .protocolFailure
                }
            },
            writeFramedClaim: { claim in
                try writer.write(
                    try zeroArgumentFramedClaimData(claim),
                    descriptor: STDOUT_FILENO,
                    maximumByteCount: 4 + ResolvedRootDriverClaimV1.maximumByteCount
                )
            },
            stopForGate: {
                guard Darwin.raise(SIGSTOP) == 0 else {
                    throw InvestigationMachineZeroArgumentEntryError
                        .protocolFailure
                }
            },
            beginEvidenceCollection: { attemptUUID in
                try InvestigationMachineEpochEvidenceCollection.begin(
                    attemptUUID: attemptUUID
                )
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
            beginTerminalOutputDeadline: { try writer.beginDeadline() },
            writeArtifact: { data, deadlineNanoseconds in
                try writer.write(
                    data,
                    descriptor: STDOUT_FILENO,
                    maximumByteCount:
                        InvestigationMachineDriverCompletionArtifact
                        .maximumByteCount,
                    deadlineNanoseconds: deadlineNanoseconds
                )
            },
            finishEvidenceCollection: {
                try InvestigationMachineEpochEvidenceCollection.finish(summary: $0)
            },
            abortEvidenceCollection:
                InvestigationMachineEpochEvidenceCollection.abort,
            writeEvidence: { claim, bytes, deadlineNanoseconds in
                try writer.write(
                    try zeroArgumentEvidenceData(
                        claim: claim,
                        bundle: bytes
                    ),
                    descriptor: STDERR_FILENO,
                    maximumByteCount: 4 * 1_024 * 1_024
                        + ResolvedRootDriverClaimV1.maximumByteCount * 2
                        + 256,
                    deadlineNanoseconds: deadlineNanoseconds
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

            let boundPlan: InvestigationMachineZeroArgumentPreboundPlan
            do { boundPlan = try await dependencies.prebindPlan(plan) }
            catch { throw Self.knownOrUncertain(error) }

            let lineageClaim: ResolvedRootDriverClaimV1
            do {
                lineageClaim = try dependencies.collectLineageClaim(
                    boundPlan.firstSelection
                )
                try dependencies.writeFramedClaim(lineageClaim)
                try dependencies.stopForGate()
                try dependencies.beginEvidenceCollection(
                    boundPlan.firstSelection.outerAttemptUUID
                )
            } catch {
                throw Self.knownOrUncertain(error)
            }

            let summary: InvestigationMachineEightEpochCompletionSummary
            do {
                summary = try await dependencies.runCohort(boundPlan.plan)
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
                guard let evidence else {
                    throw InvestigationMachineZeroArgumentEntryError
                        .invalidCompletion
                }
                let claimBytes = try lineageClaim.encoded()
                let terminalDeadline = try dependencies
                    .beginTerminalOutputDeadline()
                try dependencies.writeEvidence(
                    lineageClaim,
                    evidence,
                    terminalDeadline
                )
                let artifact = try InvestigationMachineDriverCompletionArtifact(
                    summary: summary,
                    lineageClaimSHA256: .hashing(claimBytes),
                    driverEvidenceBundleSHA256: .hashing(evidence)
                )
                let encoded = try artifact.encoded()
                try dependencies.writeArtifact(encoded, terminalDeadline)
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

struct InvestigationMachineZeroArgumentPreboundPlan: Sendable {
    let firstSelection: InvestigationMachineFixedEpochSelection
    let plan: any InvestigationMachineEightEpochPlan
}

private func zeroArgumentFramedClaimData(
    _ claim: ResolvedRootDriverClaimV1
) throws -> Data {
    let encoded = try claim.encoded()
    guard let count = UInt32(exactly: encoded.count) else {
        throw InvestigationMachineZeroArgumentEntryError.outputUnavailable
    }
    var data = zeroArgumentData(count)
    data.append(encoded)
    return data
}

private func zeroArgumentEvidenceData(
    claim: ResolvedRootDriverClaimV1,
    bundle: Data
) throws -> Data {
    let encodedClaim = try claim.encoded()
    let claimLine = Data(
        ("STORNAUT_TASK39_IIC_ROOT_DRIVER_CLAIM_V1 "
            + encodedClaim.base64EncodedString()
            + "\n").utf8
    )
    let bundleLine = Data(
        ("STORNAUT_TASK39_IIC_EPOCH_BUNDLE_V1 "
            + bundle.base64EncodedString()
            + "\n").utf8
    )
    var data = Data()
    data.reserveCapacity(claimLine.count + bundleLine.count)
    data.append(claimLine)
    data.append(bundleLine)
    return data
}

private func zeroArgumentResolvedRootDriverClaimSource(
    installedObservation: InvestigationMachineInstalledDriverObservation
) throws -> InvestigationMachineResolvedRootDriverClaimSource {
    let executable = try zeroArgumentResolvedRootDriverExecutableObservation(
        installedObservation: installedObservation
    )
    return .init(
        selfProcessID: {
            let value = getpid()
            guard value > 1 else {
                throw InvestigationMachineResolvedRootDriverClaimError
                    .observationUnavailable
            }
            return UInt32(value)
        },
        processSnapshot1: { try zeroArgumentResolvedRootDriverProcessObservation() },
        executableObservation: { executable },
        liveSigning: { try zeroArgumentResolvedRootDriverLiveSigning($0) },
        processSnapshot2: { try zeroArgumentResolvedRootDriverProcessObservation() },
        continuousNanoseconds: {
            let now = DispatchTime.now().uptimeNanoseconds
            guard now > 0 else {
                throw InvestigationMachineResolvedRootDriverClaimError
                    .invalidClock
            }
            return now
        }
    )
}

private func zeroArgumentResolvedRootDriverProcessObservation() throws
    -> InvestigationMachineResolvedRootDriverProcessObservation
{
    let processID = getpid()
    guard processID > 1 else {
        throw InvestigationMachineResolvedRootDriverClaimError
            .observationUnavailable
    }

    var rawIdentity = stornaut_investigation_identity()
    guard stornaut_investigation_identity_for_pid(processID, &rawIdentity) == 0
    else {
        throw InvestigationMachineResolvedRootDriverClaimError
            .observationUnavailable
    }
    var rawSnapshot = stornaut_investigation_process_snapshot()
    guard stornaut_investigation_process_snapshot_for_pid(
        processID,
        &rawSnapshot
    ) == 0 else {
        throw InvestigationMachineResolvedRootDriverClaimError
            .observationUnavailable
    }

    let sessionID = getsid(processID)
    let words = withUnsafeBytes(of: rawIdentity.audit_token_words) { bytes in
        Array(bytes.bindMemory(to: UInt32.self))
    }
    let groupCount = Int(rawSnapshot.supplementary_group_count)
    let groupsStorage = withUnsafeBytes(of: rawSnapshot.supplementary_groups) {
        bytes in
        Array(bytes.bindMemory(to: gid_t.self))
    }
    guard groupCount <= groupsStorage.count else {
        throw InvestigationMachineResolvedRootDriverClaimError
            .observationUnavailable
    }
    let groups = Array(groupsStorage[0..<groupCount])
        .map { UInt32($0) }
        .sorted()

    guard
        rawIdentity.process_id == processID,
        rawIdentity.process_id_version > 0,
        rawSnapshot.process_id == processID,
        rawSnapshot.parent_process_id > 0,
        rawSnapshot.process_group_id > 1,
        sessionID > 0,
        rawSnapshot.audit_session_id > 0,
        rawSnapshot.start_time_seconds > 0,
        rawSnapshot.start_time_microseconds < 1_000_000,
        words.count == 8,
        (1...InvestigationGeneralProcessIdentityV1
            .supplementaryGroupCapacity).contains(groupCount)
    else {
        throw InvestigationMachineResolvedRootDriverClaimError
            .observationUnavailable
    }

    return .init(
        processID: UInt32(processID),
        processIDVersion: UInt32(rawIdentity.process_id_version),
        startSeconds: Int64(rawSnapshot.start_time_seconds),
        startMicroseconds: Int32(rawSnapshot.start_time_microseconds),
        parentProcessID: UInt32(rawSnapshot.parent_process_id),
        processGroupID: UInt32(rawSnapshot.process_group_id),
        sessionID: UInt32(sessionID),
        auditSessionID: UInt32(rawSnapshot.audit_session_id),
        auditTokenWords: words,
        realUserID: UInt32(rawSnapshot.real_user_id),
        effectiveUserID: UInt32(rawSnapshot.effective_user_id),
        savedUserID: UInt32(rawSnapshot.saved_user_id),
        realGroupID: UInt32(rawSnapshot.real_group_id),
        effectiveGroupID: UInt32(rawSnapshot.effective_group_id),
        savedGroupID: UInt32(rawSnapshot.saved_group_id),
        supplementaryGroups: groups
    )
}

private func zeroArgumentResolvedRootDriverExecutableObservation(
    installedObservation: InvestigationMachineInstalledDriverObservation
) throws -> InvestigationMachineResolvedRootDriverExecutableObservation {
    .init(
        path: installedObservation.executablePath,
        node: .init(
            deviceID: installedObservation.node.deviceID,
            inode: installedObservation.node.inode,
            generation: installedObservation.node.generation,
            isRegularFile: installedObservation.node.isRegularFile,
            ownerUserID: UInt32(installedObservation.node.ownerUserID),
            ownerGroupID: UInt32(installedObservation.node.ownerGroupID),
            mode: UInt32(installedObservation.node.mode),
            linkCount: installedObservation.node.linkCount,
            size: installedObservation.node.size,
            flags: installedObservation.node.flags
        ),
        sha256: try zeroArgumentSHA256(hex: installedObservation.executableSHA256),
        staticSigning: try zeroArgumentResolvedRootDriverSigningObservation(
            signingIdentifier: installedObservation.signing.signingIdentifier,
            designatedRequirementSHA256:
                installedObservation.signing.designatedRequirementSHA256,
            codeDirectoryHash: installedObservation.signing.codeDirectoryHash,
            isAdHoc: installedObservation.signing.isAdHoc
        )
    )
}

private func zeroArgumentResolvedRootDriverLiveSigning(
    _ auditTokenWords: [UInt32]
) throws -> InvestigationMachineResolvedRootDriverSigningObservation {
    guard auditTokenWords.count == 8 else {
        throw InvestigationMachineResolvedRootDriverClaimError
            .observationUnavailable
    }
    var rawToken = audit_token_t()
    let didCopy = withUnsafeMutableBytes(of: &rawToken) { destination in
        auditTokenWords.withUnsafeBytes { source in
            guard destination.count == source.count else { return false }
            destination.copyBytes(from: source)
            return true
        }
    }
    guard didCopy else {
        throw InvestigationMachineResolvedRootDriverClaimError
            .observationUnavailable
    }

    let tokenData = withUnsafeBytes(of: rawToken) { Data($0) }
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
        throw InvestigationMachineResolvedRootDriverClaimError
            .observationUnavailable
    }
    guard SecCodeCheckValidity(
        dynamicCode,
        SecCSFlags(rawValue: kSecCSStrictValidate),
        nil
    ) == errSecSuccess else {
        throw InvestigationMachineResolvedRootDriverClaimError
            .observationUnavailable
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
        throw InvestigationMachineResolvedRootDriverClaimError
            .observationUnavailable
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
        let requirement = zeroArgumentSecRequirement(
            dictionary[kSecCodeInfoDesignatedRequirement]
        ),
        let requirementData = zeroArgumentRequirementData(requirement)
    else {
        throw InvestigationMachineResolvedRootDriverClaimError
            .observationUnavailable
    }

    return .init(
        signingIdentifier: identifier,
        designatedRequirementSHA256: .hashing(requirementData),
        codeDirectoryHash: codeDirectoryHash,
        isAdHoc: signatureFlags.uint32Value & 0x0002 != 0
    )
}

private func zeroArgumentResolvedRootDriverSigningObservation(
    signingIdentifier: String,
    designatedRequirementSHA256: String,
    codeDirectoryHash: String,
    isAdHoc: Bool
) throws -> InvestigationMachineResolvedRootDriverSigningObservation {
    try .init(
        signingIdentifier: signingIdentifier,
        designatedRequirementSHA256: zeroArgumentSHA256(
            hex: designatedRequirementSHA256
        ),
        codeDirectoryHash: try zeroArgumentHexData(codeDirectoryHash),
        isAdHoc: isAdHoc
    )
}

private func zeroArgumentSHA256(
    hex: String
) throws -> InvestigationHandoffSHA256 {
    try .init(rawBytes: try zeroArgumentHexData(hex))
}

private func zeroArgumentHexData(_ hex: String) throws -> Data {
    let utf8 = Array(hex.utf8)
    guard !utf8.isEmpty, utf8.count.isMultiple(of: 2) else {
        throw InvestigationMachineZeroArgumentEntryError.protocolFailure
    }
    var result = Data()
    result.reserveCapacity(utf8.count / 2)
    var index = 0
    while index < utf8.count {
        guard
            let high = zeroArgumentHexNibble(utf8[index]),
            let low = zeroArgumentHexNibble(utf8[index + 1])
        else {
            throw InvestigationMachineZeroArgumentEntryError.protocolFailure
        }
        result.append(high << 4 | low)
        index += 2
    }
    return result
}

private func zeroArgumentHexNibble(_ byte: UInt8) -> UInt8? {
    switch byte {
    case 0x30...0x39:
        return byte - 0x30
    case 0x61...0x66:
        return byte - 0x61 + 10
    default:
        return nil
    }
}

private func zeroArgumentSecRequirement(_ value: Any?) -> SecRequirement? {
    guard let value else { return nil }
    let object = value as AnyObject
    guard CFGetTypeID(object) == SecRequirementGetTypeID() else { return nil }
    return unsafeDowncast(object, to: SecRequirement.self)
}

private func zeroArgumentRequirementData(_ requirement: SecRequirement) -> Data? {
    var data: CFData?
    guard SecRequirementCopyData(requirement, SecCSFlags(), &data)
            == errSecSuccess,
          let data
    else { return nil }
    return data as Data
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
