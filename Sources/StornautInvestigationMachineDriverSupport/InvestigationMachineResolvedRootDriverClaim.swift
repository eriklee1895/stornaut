import Foundation
import StornautInvestigationHandoffContract

package enum InvestigationMachineResolvedRootDriverClaimError:
    Error, Sendable, Equatable
{
    case invalidBinding
    case invalidProcessIdentity
    case unstableProcessIdentity
    case invalidExecutableIdentity
    case invalidClock
    case observationUnavailable
}

/// The already-sealed lineage inputs. L2 will supply these from its closed
/// startup composition; this L1 type grants no authority to read mutable input.
package struct InvestigationMachineResolvedRootDriverClaimBinding:
    Sendable, Equatable
{
    package let outerAttemptUUID: UUID
    package let wholeInputSHA256: InvestigationHandoffSHA256

    package init(
        outerAttemptUUID: UUID,
        wholeInputSHA256: InvestigationHandoffSHA256
    ) {
        self.outerAttemptUUID = outerAttemptUUID
        self.wholeInputSHA256 = wholeInputSHA256
    }
}

/// One complete kernel/audit sample of the root driver. The production reader
/// is deliberately deferred to L2; L1 consumes two independently injected
/// samples so all validation remains deterministic and authority-free.
package struct InvestigationMachineResolvedRootDriverProcessObservation:
    Sendable, Equatable
{
    package var processID: UInt32
    package var processIDVersion: UInt32
    package var startSeconds: Int64
    package var startMicroseconds: Int32
    package var parentProcessID: UInt32
    package var processGroupID: UInt32
    package var sessionID: UInt32
    package var auditSessionID: UInt32
    package var auditTokenWords: [UInt32]
    package var realUserID: UInt32
    package var effectiveUserID: UInt32
    package var savedUserID: UInt32
    package var realGroupID: UInt32
    package var effectiveGroupID: UInt32
    package var savedGroupID: UInt32
    package var supplementaryGroups: [UInt32]

    package init(
        processID: UInt32, processIDVersion: UInt32, startSeconds: Int64,
        startMicroseconds: Int32, parentProcessID: UInt32,
        processGroupID: UInt32, sessionID: UInt32, auditSessionID: UInt32,
        auditTokenWords: [UInt32], realUserID: UInt32,
        effectiveUserID: UInt32, savedUserID: UInt32, realGroupID: UInt32,
        effectiveGroupID: UInt32, savedGroupID: UInt32,
        supplementaryGroups: [UInt32]
    ) {
        self.processID = processID
        self.processIDVersion = processIDVersion
        self.startSeconds = startSeconds
        self.startMicroseconds = startMicroseconds
        self.parentProcessID = parentProcessID
        self.processGroupID = processGroupID
        self.sessionID = sessionID
        self.auditSessionID = auditSessionID
        self.auditTokenWords = auditTokenWords
        self.realUserID = realUserID
        self.effectiveUserID = effectiveUserID
        self.savedUserID = savedUserID
        self.realGroupID = realGroupID
        self.effectiveGroupID = effectiveGroupID
        self.savedGroupID = savedGroupID
        self.supplementaryGroups = supplementaryGroups
    }
}

package struct InvestigationMachineResolvedRootDriverNodeObservation:
    Sendable, Equatable
{
    package var deviceID: UInt64
    package var inode: UInt64
    package var generation: UInt32
    package var isRegularFile: Bool
    package var ownerUserID: UInt32
    package var ownerGroupID: UInt32
    package var mode: UInt32
    package var linkCount: UInt64
    package var size: Int64
    package var flags: UInt32

    package init(
        deviceID: UInt64, inode: UInt64, generation: UInt32,
        isRegularFile: Bool, ownerUserID: UInt32, ownerGroupID: UInt32,
        mode: UInt32, linkCount: UInt64, size: Int64, flags: UInt32
    ) {
        self.deviceID = deviceID
        self.inode = inode
        self.generation = generation
        self.isRegularFile = isRegularFile
        self.ownerUserID = ownerUserID
        self.ownerGroupID = ownerGroupID
        self.mode = mode
        self.linkCount = linkCount
        self.size = size
        self.flags = flags
    }
}

package struct InvestigationMachineResolvedRootDriverSigningObservation:
    Sendable, Equatable
{
    package var signingIdentifier: String
    package var designatedRequirementSHA256: InvestigationHandoffSHA256
    package var codeDirectoryHash: Data
    package var isAdHoc: Bool

    package init(
        signingIdentifier: String,
        designatedRequirementSHA256: InvestigationHandoffSHA256,
        codeDirectoryHash: Data, isAdHoc: Bool
    ) {
        self.signingIdentifier = signingIdentifier
        self.designatedRequirementSHA256 = designatedRequirementSHA256
        self.codeDirectoryHash = codeDirectoryHash
        self.isAdHoc = isAdHoc
    }
}

package struct InvestigationMachineResolvedRootDriverExecutableObservation:
    Sendable, Equatable
{
    package var path: String
    package var node: InvestigationMachineResolvedRootDriverNodeObservation
    package var sha256: InvestigationHandoffSHA256
    package var staticSigning:
        InvestigationMachineResolvedRootDriverSigningObservation

    package init(
        path: String,
        node: InvestigationMachineResolvedRootDriverNodeObservation,
        sha256: InvestigationHandoffSHA256,
        staticSigning: InvestigationMachineResolvedRootDriverSigningObservation
    ) {
        self.path = path
        self.node = node
        self.sha256 = sha256
        self.staticSigning = staticSigning
    }
}

/// Every closure is injected. In particular, live signing must be resolved from
/// the supplied audit-token words; a PID-only fallback is not represented.
package struct InvestigationMachineResolvedRootDriverClaimSource: Sendable {
    package let selfProcessID: @Sendable () throws -> UInt32
    package let processSnapshot1: @Sendable () throws
        -> InvestigationMachineResolvedRootDriverProcessObservation
    package let executableObservation: @Sendable () throws
        -> InvestigationMachineResolvedRootDriverExecutableObservation
    package let liveSigning: @Sendable ([UInt32]) throws
        -> InvestigationMachineResolvedRootDriverSigningObservation
    package let processSnapshot2: @Sendable () throws
        -> InvestigationMachineResolvedRootDriverProcessObservation
    package let continuousNanoseconds: @Sendable () throws -> UInt64

    package init(
        selfProcessID: @escaping @Sendable () throws -> UInt32,
        processSnapshot1: @escaping @Sendable () throws
            -> InvestigationMachineResolvedRootDriverProcessObservation,
        executableObservation: @escaping @Sendable () throws
            -> InvestigationMachineResolvedRootDriverExecutableObservation,
        liveSigning: @escaping @Sendable ([UInt32]) throws
            -> InvestigationMachineResolvedRootDriverSigningObservation,
        processSnapshot2: @escaping @Sendable () throws
            -> InvestigationMachineResolvedRootDriverProcessObservation,
        continuousNanoseconds: @escaping @Sendable () throws -> UInt64
    ) {
        self.selfProcessID = selfProcessID
        self.processSnapshot1 = processSnapshot1
        self.executableObservation = executableObservation
        self.liveSigning = liveSigning
        self.processSnapshot2 = processSnapshot2
        self.continuousNanoseconds = continuousNanoseconds
    }
}

package struct InvestigationMachineResolvedRootDriverClaimCollector: Sendable {
    private static let maximumExecutableBytes: Int64 = 16 * 1_024 * 1_024
    private let source: InvestigationMachineResolvedRootDriverClaimSource

    package init(source: InvestigationMachineResolvedRootDriverClaimSource) {
        self.source = source
    }

    package func collect(
        binding: InvestigationMachineResolvedRootDriverClaimBinding
    ) throws -> ResolvedRootDriverClaimV1 {
        guard Self.valid(binding) else {
            throw InvestigationMachineResolvedRootDriverClaimError.invalidBinding
        }
        let selfProcessID: UInt32
        let first: InvestigationMachineResolvedRootDriverProcessObservation
        do {
            selfProcessID = try source.selfProcessID()
            first = try source.processSnapshot1()
        } catch {
            throw InvestigationMachineResolvedRootDriverClaimError
                .observationUnavailable
        }
        guard
            selfProcessID == first.processID,
            Self.valid(first)
        else {
            throw InvestigationMachineResolvedRootDriverClaimError
                .invalidProcessIdentity
        }

        let observedExecutable:
            InvestigationMachineResolvedRootDriverExecutableObservation
        let liveSigning:
            InvestigationMachineResolvedRootDriverSigningObservation
        let second: InvestigationMachineResolvedRootDriverProcessObservation
        let observedAt: UInt64
        do {
            observedExecutable = try source.executableObservation()
            liveSigning = try source.liveSigning(first.auditTokenWords)
            second = try source.processSnapshot2()
            observedAt = try source.continuousNanoseconds()
        } catch {
            throw InvestigationMachineResolvedRootDriverClaimError
                .observationUnavailable
        }
        guard first == second else {
            throw InvestigationMachineResolvedRootDriverClaimError
                .unstableProcessIdentity
        }
        guard Self.valid(observedExecutable, liveSigning: liveSigning) else {
            throw InvestigationMachineResolvedRootDriverClaimError
                .invalidExecutableIdentity
        }
        guard observedAt > 0 else {
            throw InvestigationMachineResolvedRootDriverClaimError.invalidClock
        }

        do {
            let process = try Self.canonicalProcess(first)
            let executable = try Self.canonicalExecutable(
                observedExecutable, liveSigning: liveSigning
            )
            return try ResolvedRootDriverClaimV1(
                outerAttemptUUID: binding.outerAttemptUUID,
                wholeInputSHA256: binding.wholeInputSHA256,
                process: process, executable: executable,
                observedAtContinuousNanoseconds: observedAt
            )
        } catch {
            throw InvestigationMachineResolvedRootDriverClaimError
                .invalidExecutableIdentity
        }
    }

    private static func valid(
        _ binding: InvestigationMachineResolvedRootDriverClaimBinding
    ) -> Bool {
        binding.outerAttemptUUID != UUID(
            uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        ) && binding.wholeInputSHA256.rawBytes.contains(where: { $0 != 0 })
    }

    private static func valid(
        _ value: InvestigationMachineResolvedRootDriverProcessObservation
    ) -> Bool {
        let token = value.auditTokenWords
        let groups = value.supplementaryGroups
        return value.processID > 1 && value.processIDVersion > 0
            && value.startSeconds > 0
            && (0...999_999).contains(value.startMicroseconds)
            && value.parentProcessID > 0 && value.processGroupID > 1
            && value.sessionID > 0 && value.auditSessionID > 0
            && value.realUserID == 0 && value.effectiveUserID == 0
            && value.savedUserID == 0 && value.realGroupID == 0
            && value.effectiveGroupID == 0 && value.savedGroupID == 0
            && (1...InvestigationGeneralProcessIdentityV1
                .supplementaryGroupCapacity).contains(groups.count)
            && groups == groups.sorted()
            && Set(groups).count == groups.count && groups.contains(0)
            && token.count == 8 && token[1] == value.effectiveUserID
            && token[2] == value.effectiveGroupID
            && token[3] == value.realUserID && token[4] == value.realGroupID
            && token[5] == value.processID
            && token[6] == value.auditSessionID
            && token[7] == value.processIDVersion
    }

    private static func valid(
        _ value: InvestigationMachineResolvedRootDriverExecutableObservation,
        liveSigning: InvestigationMachineResolvedRootDriverSigningObservation
    ) -> Bool {
        let node = value.node
        return value.path == ResolvedRootDriverClaimV1.fixedExecutablePath
            && node.deviceID > 0 && node.inode > 0 && node.isRegularFile
            && node.ownerUserID == 0 && node.ownerGroupID == 0
            && node.mode == 0o755 && node.linkCount == 1
            && (1...maximumExecutableBytes).contains(node.size)
            && node.flags == 0
            && value.sha256.rawBytes.contains(where: { $0 != 0 })
            && valid(value.staticSigning)
            && liveSigning == value.staticSigning
    }

    private static func valid(
        _ value: InvestigationMachineResolvedRootDriverSigningObservation
    ) -> Bool {
        value.signingIdentifier == ResolvedRootDriverClaimV1.fixedSigningIdentifier
            && value.designatedRequirementSHA256.rawBytes
                .contains(where: { $0 != 0 })
            && (value.codeDirectoryHash.count == 20
                || value.codeDirectoryHash.count == 32)
            && value.codeDirectoryHash.contains(where: { $0 != 0 })
            && value.isAdHoc
    }

    private static func canonicalProcess(
        _ p: InvestigationMachineResolvedRootDriverProcessObservation
    ) throws -> InvestigationGeneralProcessIdentityV1 {
        try .init(
            processID: p.processID, processIDVersion: p.processIDVersion,
            startSeconds: p.startSeconds, startMicroseconds: p.startMicroseconds,
            parentProcessID: p.parentProcessID, processGroupID: p.processGroupID,
            sessionID: p.sessionID, auditSessionID: p.auditSessionID,
            auditTokenWords: p.auditTokenWords, realUserID: p.realUserID,
            effectiveUserID: p.effectiveUserID, savedUserID: p.savedUserID,
            realGroupID: p.realGroupID, effectiveGroupID: p.effectiveGroupID,
            savedGroupID: p.savedGroupID,
            supplementaryGroups: p.supplementaryGroups
        )
    }

    private static func canonicalExecutable(
        _ e: InvestigationMachineResolvedRootDriverExecutableObservation,
        liveSigning: InvestigationMachineResolvedRootDriverSigningObservation
    ) throws -> InvestigationResolvedRootDriverExecutableIdentityV1 {
        let node = try InvestigationResolvedRootDriverNodeIdentityV1(
            deviceID: e.node.deviceID, inode: e.node.inode,
            generation: e.node.generation, isRegularFile: e.node.isRegularFile,
            ownerUserID: e.node.ownerUserID, ownerGroupID: e.node.ownerGroupID,
            mode: e.node.mode, linkCount: e.node.linkCount, size: e.node.size,
            flags: e.node.flags
        )
        func signing(
            _ s: InvestigationMachineResolvedRootDriverSigningObservation
        ) throws -> InvestigationResolvedRootDriverSigningIdentityV1 {
            try .init(
                signingIdentifier: s.signingIdentifier,
                designatedRequirementSHA256: s.designatedRequirementSHA256,
                codeDirectoryHash: s.codeDirectoryHash, isAdHoc: s.isAdHoc
            )
        }
        return try .init(
            path: e.path, node: node, sha256: e.sha256,
            staticSigning: signing(e.staticSigning),
            liveSigning: signing(liveSigning)
        )
    }
}
