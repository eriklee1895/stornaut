#if DEBUG
import Darwin
import Foundation
import StornautInvestigationHandoffContract

package enum InvestigationMachineEvidenceFileType: Equatable, Sendable {
    case directory
    case regularFile
    case other
}

package struct InvestigationMachineEvidenceNodeIdentity:
    Equatable, Hashable, Sendable
{
    package let device: UInt64
    package let inode: UInt64
    package let generation: UInt64
    package let size: Int64
}

package struct InvestigationMachineEvidenceNodeMetadata:
    Equatable, Sendable
{
    package let identity: InvestigationMachineEvidenceNodeIdentity
    package let fileType: InvestigationMachineEvidenceFileType
    package let ownerUserID: uid_t
    package let ownerGroupID: gid_t
    package let permissions: mode_t
    package let linkCount: UInt64
    package let flags: UInt32
}

package struct InvestigationMachineEvidenceOwnerIdentity:
    Equatable, Sendable
{
    package let userID: uid_t
    package let groupID: gid_t
}

package struct InvestigationMachineEvidenceInventory: Equatable, Sendable {
    package let names: [String]
    package let reachedEnd: Bool
}

package enum InvestigationMachineRawEvidenceSystemError:
    Error, Equatable, Sendable
{
    case errno(Int32)
}

package protocol InvestigationMachineRawEvidenceSystem:
    AnyObject, Sendable
{
    func effectiveIdentity() -> InvestigationMachineEvidenceOwnerIdentity
    func inventory(
        descriptor: Int32, maximumEntryCount: Int
    ) throws -> InvestigationMachineEvidenceInventory
    func createDirectory(
        parentDescriptor: Int32, name: String, mode: mode_t
    ) throws
    func openComponent(
        parentDescriptor: Int32, name: String, flags: Int32, mode: mode_t?
    ) throws -> Int32
    func metadata(
        descriptor: Int32
    ) throws -> InvestigationMachineEvidenceNodeMetadata
    func namedMetadata(
        parentDescriptor: Int32, name: String, flags: Int32
    ) throws -> InvestigationMachineEvidenceNodeMetadata
    func descriptorFlags(_ descriptor: Int32) throws -> Int32
    func descriptorStatusFlags(_ descriptor: Int32) throws -> Int32
    func setPermissions(descriptor: Int32, mode: mode_t) throws
    func extendedACLIsEmpty(descriptor: Int32) throws -> Bool
    func extendedAttributeNames(descriptor: Int32) throws -> [String]
    func synchronize(descriptor: Int32) throws
    func write(
        descriptor: Int32, bytes: Data, offset: Int64
    ) throws -> Int
    func rename(
        parentDescriptor: Int32, oldName: String, newName: String, flags: Int32
    ) throws
    func read(
        descriptor: Int32, maximumByteCount: Int, offset: Int64
    ) throws -> Data
    func close(descriptor: Int32) throws
}

package enum InvestigationMachineRawEvidenceFailureStage:
    Equatable, Sendable
{
    case validateParent
    case createRoot
    case openRoot
    case createPhase
    case openPhase
    case validateDirectory
    case createPending
    case writePending
    case validatePending
    case synchronizeFile
    case publish
    case synchronizeDirectory
    case reopenFinal
    case readFinal
    case validateFinal
    case inventory
    case closeDescriptor
}

package enum InvestigationMachineRawEvidenceError:
    Error, Equatable, Sendable
{
    case rootCollision
    case alreadyTerminal
    case dryRunAuthorityViolation
    case duplicateArtifact
    case uncertain(stage: InvestigationMachineRawEvidenceFailureStage)
}

package struct InvestigationMachineRawEvidenceSeal:
    Equatable, Sendable
{
    package let campaignUUID: UUID
    package let attemptUUID: UUID
    package let rootIdentity: InvestigationMachineEvidenceNodeIdentity
    package let manifestSHA256: InvestigationHandoffSHA256
    package let contentRootSHA256: InvestigationHandoffSHA256
    package let artifactCount: Int
    package let totalByteCount: UInt64
    package let attemptSummary: InvestigationMachineAttemptSummary
}

package final class InvestigationMachineRawEvidenceWriter:
    @unchecked Sendable
{
    private static let maximumInventoryCount =
        InvestigationMachineEvidenceManifestV1.maximumArtifactCount + 8
    private static let maximumIOByteCount = 16 * 1_024
    private static let maximumInterruptCount = 64
    private static let directoryFlags = Int32(
        O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NONBLOCK | O_NOFOLLOW_ANY
            | O_RESOLVE_BENEATH | O_UNIQUE
    )
    private static let pendingWriterFlags = Int32(
        O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NONBLOCK
            | O_NOFOLLOW_ANY | O_RESOLVE_BENEATH | O_UNIQUE
    )
    private static let finalReaderFlags = Int32(
        O_RDONLY | O_CLOEXEC | O_NONBLOCK | O_NOFOLLOW_ANY
            | O_RESOLVE_BENEATH | O_UNIQUE
    )
    private static let namedFlags = Int32(
        AT_SYMLINK_NOFOLLOW_ANY | AT_RESOLVE_BENEATH | AT_UNIQUE
    )
    private static let renameFlags = Int32(
        RENAME_EXCL | RENAME_NOFOLLOW_ANY | RENAME_RESOLVE_BENEATH
    )

    private enum State { case active, finalized, uncertain }
    private let lock = NSLock()
    private let system: any InvestigationMachineRawEvidenceSystem
    private let parentDescriptor: Int32
    private let parentIdentity: InvestigationMachineEvidenceNodeIdentity
    private let owner: InvestigationMachineEvidenceOwnerIdentity
    private let campaignUUID: UUID
    private let attemptUUID: UUID
    private let mode: InvestigationMachineAttemptMode
    private let sourceBinding: InvestigationMachineCampaignSourceBinding
    private let rootDescriptor: Int32
    private let initialRootMetadata: InvestigationMachineEvidenceNodeMetadata
    private var phaseDescriptors: [InvestigationMachineEvidencePhase: Int32]
    private var artifacts: [InvestigationMachineEvidenceArtifact] = []
    private var events: [InvestigationMachineAttemptEventV1] = []
    private var state = State.active
    private var descriptorsClosed = false

    package static func rootName(campaignUUID: UUID) -> String {
        "stornaut-task39-iic-" + campaignUUID.uuidString.lowercased()
    }

    package init(
        system: any InvestigationMachineRawEvidenceSystem,
        parentDescriptor: Int32,
        expectedParentIdentity: InvestigationMachineEvidenceNodeIdentity,
        campaignUUID: UUID, attemptUUID: UUID,
        mode: InvestigationMachineAttemptMode = .dryRun,
        sourceBinding: InvestigationMachineCampaignSourceBinding
    ) throws {
        self.system = system
        self.parentDescriptor = parentDescriptor
        parentIdentity = expectedParentIdentity
        let expectedOwner = system.effectiveIdentity()
        owner = expectedOwner
        self.campaignUUID = campaignUUID
        self.attemptUUID = attemptUUID
        self.mode = mode
        self.sourceBinding = sourceBinding
        guard Self.nonzero(campaignUUID), Self.nonzero(attemptUUID),
              campaignUUID != attemptUUID
        else { throw InvestigationMachineEvidenceContractError.invalidEncoding }

        var openedRoot = Int32(-1)
        var openedPhases: [InvestigationMachineEvidencePhase: Int32] = [:]
        do {
            try Self.atInitialization(.validateParent) { try Self.validateParent(
                descriptor: parentDescriptor, expected: expectedParentIdentity,
                owner: expectedOwner, system: system
            ) }
            do {
                try system.createDirectory(
                    parentDescriptor: parentDescriptor,
                    name: Self.rootName(campaignUUID: campaignUUID), mode: 0o700
                )
            } catch InvestigationMachineRawEvidenceSystemError.errno(let value)
                where value == EEXIST
            {
                throw InvestigationMachineRawEvidenceError.rootCollision
            } catch {
                throw InvestigationMachineRawEvidenceError
                    .uncertain(stage: .createRoot)
            }
            openedRoot = try Self.atInitialization(.openRoot) {
                try system.openComponent(
                parentDescriptor: parentDescriptor,
                name: Self.rootName(campaignUUID: campaignUUID),
                flags: Self.directoryFlags, mode: nil
                )
            }
            guard openedRoot >= 3, openedRoot != parentDescriptor else {
                let closeCertain = openedRoot < 0
                    || openedRoot == parentDescriptor
                    || Self.closeBestEffort([openedRoot], system: system)
                openedRoot = -1
                guard closeCertain else {
                    throw InvestigationMachineRawEvidenceError
                        .uncertain(stage: .closeDescriptor)
                }
                throw InvestigationMachineRawEvidenceError
                    .uncertain(stage: .openRoot)
            }
            try Self.atInitialization(.validateDirectory) {
                try system.setPermissions(descriptor: openedRoot, mode: 0o700)
            }
            let rootMetadata = try Self.atInitialization(.validateDirectory) {
                try Self.validateDirectory(
                descriptor: openedRoot, parent: parentDescriptor,
                name: Self.rootName(campaignUUID: campaignUUID),
                baseDevice: expectedParentIdentity.device, owner: expectedOwner,
                system: system
                )
            }
            try Self.atInitialization(.synchronizeDirectory) {
                try system.synchronize(descriptor: parentDescriptor)
            }
            for phase in InvestigationMachineEvidencePhase.allCases {
                try Self.atInitialization(.createPhase) {
                    try system.createDirectory(
                    parentDescriptor: openedRoot, name: phase.directoryName,
                    mode: 0o700
                    )
                }
                let descriptor = try Self.atInitialization(.openPhase) {
                    try system.openComponent(
                    parentDescriptor: openedRoot, name: phase.directoryName,
                    flags: Self.directoryFlags, mode: nil
                    )
                }
                guard descriptor >= 3, descriptor != parentDescriptor,
                      descriptor != openedRoot,
                      !openedPhases.values.contains(descriptor)
                else {
                    let isAlias = descriptor == parentDescriptor
                        || descriptor == openedRoot
                        || openedPhases.values.contains(descriptor)
                    guard descriptor < 0 || isAlias
                        || Self.closeBestEffort([descriptor], system: system)
                    else {
                        throw InvestigationMachineRawEvidenceError
                            .uncertain(stage: .closeDescriptor)
                    }
                    throw InvestigationMachineRawEvidenceError
                        .uncertain(stage: .openPhase)
                }
                openedPhases[phase] = descriptor
                try Self.atInitialization(.validateDirectory) {
                    try system.setPermissions(descriptor: descriptor, mode: 0o700)
                }
                _ = try Self.atInitialization(.validateDirectory) {
                    try Self.validateDirectory(
                    descriptor: descriptor, parent: openedRoot,
                    name: phase.directoryName, baseDevice: rootMetadata.identity.device,
                    owner: expectedOwner, system: system
                    )
                }
            }
            try Self.atInitialization(.synchronizeDirectory) {
                try system.synchronize(descriptor: openedRoot)
            }
            initialRootMetadata = rootMetadata
        } catch let error as InvestigationMachineRawEvidenceError {
            guard Self.closeBestEffort(
                Array(openedPhases.values) + [openedRoot], system: system
            ) else {
                throw InvestigationMachineRawEvidenceError
                    .uncertain(stage: .closeDescriptor)
            }
            throw error
        } catch {
            guard Self.closeBestEffort(
                Array(openedPhases.values) + [openedRoot], system: system
            ) else {
                throw InvestigationMachineRawEvidenceError
                    .uncertain(stage: .closeDescriptor)
            }
            throw InvestigationMachineRawEvidenceError
                .uncertain(stage: openedRoot >= 0 ? .createPhase : .openRoot)
        }
        rootDescriptor = openedRoot
        phaseDescriptors = openedPhases
    }

    deinit {
        lock.withLock {
            guard !descriptorsClosed else { return }
            descriptorsClosed = true
            Self.closeBestEffort(
                Array(phaseDescriptors.values) + [rootDescriptor], system: system
            )
        }
    }

    @discardableResult
    package func writeArtifact(
        path: InvestigationMachineEvidenceRelativePath,
        role: InvestigationMachineEvidenceRole,
        encoding: InvestigationMachineEvidenceEncoding, bytes: Data
    ) throws -> InvestigationMachineEvidenceArtifact {
        try lock.withLock {
            try requireActive()
            guard role != .attemptEvent else {
                throw InvestigationMachineEvidenceContractError.invalidRole
            }
            return try publishChecked(
                path: path, role: role, encoding: encoding, bytes: bytes
            )
        }
    }

    @discardableResult
    package func appendAttemptEvent(
        kind: InvestigationMachineAttemptEventKind, payload: Data,
        observedAt: InvestigationHandoffUTCMicroseconds
    ) throws -> InvestigationMachineAttemptEventV1 {
        try lock.withLock {
            try requireActive()
            guard try Self.canonicalJSON(payload) == payload else {
                throw InvestigationMachineEvidenceContractError.invalidEncoding
            }
            let previous = try events.last.map {
                InvestigationHandoffSHA256.hashing(try $0.encoded())
            } ?? Self.zeroDigest()
            let event = try InvestigationMachineAttemptEventV1(
                sequence: UInt32(events.count + 1), attemptUUID: attemptUUID,
                kind: kind, previousEventSHA256: previous,
                observedAt: observedAt, payload: payload
            )
            if let last = events.last, event.observedAt <= last.observedAt {
                throw InvestigationMachineEvidenceContractError.invalidTransition
            }
            do {
                try InvestigationMachineAttemptEventChain.validatePrefix(
                    events + [event], mode: mode
                )
            } catch {
                if mode == .dryRun && [
                    InvestigationMachineAttemptEventKind.armedConsumed,
                    .spawnObserved, .spawnUncertain, .terminal,
                ].contains(kind) {
                    throw InvestigationMachineRawEvidenceError
                        .dryRunAuthorityViolation
                }
                throw error
            }
            let leaf = String(format: "attempt-event-%04d.bin", event.sequence)
            _ = try publish(
                path: .init(phase: .authorization, leafName: leaf),
                role: .attemptEvent, encoding: .canonicalBinary,
                bytes: try event.encoded()
            )
            events.append(event)
            return event
        }
    }

    package func finalize() throws -> InvestigationMachineRawEvidenceSeal {
        try lock.withLock {
            try requireActive()
            do {
                try at(.validateParent) { try Self.validateParent(
                    descriptor: parentDescriptor, expected: parentIdentity,
                    owner: owner, system: system
                ) }
                let attemptSummary = try InvestigationMachineAttemptEventChain.summary(
                    events, mode: mode
                )
                try validateCompleteTree()
                let manifest = try InvestigationMachineEvidenceManifestV1(
                    campaignUUID: campaignUUID, attemptUUID: attemptUUID,
                    sourceBinding: sourceBinding, artifacts: artifacts,
                    attemptSummary: attemptSummary
                )
                let manifestBytes = try manifest.encoded()
                try publishManifest(manifestBytes)
                for phase in InvestigationMachineEvidencePhase.allCases {
                    guard let descriptor = phaseDescriptors[phase] else {
                        throw InvestigationMachineRawEvidenceError
                            .uncertain(stage: .validateDirectory)
                    }
                    try at(.synchronizeDirectory) {
                        try system.synchronize(descriptor: descriptor)
                    }
                }
                try at(.synchronizeDirectory) {
                    try system.synchronize(descriptor: rootDescriptor)
                }
                try validateCompleteTree(
                    expectedManifest: manifest, expectedBytes: manifestBytes
                )
                let finalRoot = try at(.validateDirectory) {
                    try Self.validateDirectory(
                        descriptor: rootDescriptor, parent: parentDescriptor,
                        name: Self.rootName(campaignUUID: campaignUUID),
                        baseDevice: parentIdentity.device, owner: owner, system: system
                    )
                }
                guard Self.sameDirectoryNode(
                    finalRoot.identity, initialRootMetadata.identity
                ) else {
                    throw InvestigationMachineRawEvidenceError
                        .uncertain(stage: .validateDirectory)
                }
                try closeOwnedDescriptors()
                state = .finalized
                return .init(
                    campaignUUID: campaignUUID, attemptUUID: attemptUUID,
                    rootIdentity: finalRoot.identity,
                    manifestSHA256: manifest.manifestSHA256,
                    contentRootSHA256: manifest.contentRootSHA256,
                    artifactCount: manifest.artifacts.count,
                    totalByteCount: manifest.totalByteCount,
                    attemptSummary: attemptSummary
                )
            } catch let error as InvestigationMachineEvidenceContractError {
                state = .uncertain
                throw error
            } catch let error as InvestigationMachineRawEvidenceError {
                state = .uncertain
                throw error
            } catch {
                state = .uncertain
                throw InvestigationMachineRawEvidenceError
                    .uncertain(stage: .inventory)
            }
        }
    }

    private func requireActive() throws {
        guard state == .active else {
            throw InvestigationMachineRawEvidenceError.alreadyTerminal
        }
    }

    private func publishChecked(
        path: InvestigationMachineEvidenceRelativePath,
        role: InvestigationMachineEvidenceRole,
        encoding: InvestigationMachineEvidenceEncoding, bytes: Data
    ) throws -> InvestigationMachineEvidenceArtifact {
        guard (!bytes.isEmpty || role == .diagnosticOutput),
              UInt64(bytes.count) <= InvestigationMachineEvidenceArtifact.maximumByteCount
        else { throw InvestigationMachineEvidenceContractError.sizeLimitExceeded }
        switch encoding {
        case .strictJSON:
            guard try Self.canonicalJSON(bytes) == bytes else {
                throw InvestigationMachineEvidenceContractError.invalidEncoding
            }
        case .canonicalBinary:
            guard role == .attemptEvent else {
                throw InvestigationMachineEvidenceContractError.invalidEncoding
            }
        case .framedCanonicalBinary:
            guard role == .protocolReceipt else {
                throw InvestigationMachineEvidenceContractError.invalidEncoding
            }
            let receipt = try InvestigationMachineCoordinatorRawReceiptV1
                .decodeFrame(bytes, reachedEOF: true)
            guard receipt.outerAttemptUUID == attemptUUID,
                  receipt.buildProvenanceSHA256
                    == sourceBinding.buildProvenanceSHA256.lowercaseHex,
                  receipt.signedBindingSHA256
                    == sourceBinding.signedRuntimeBindingSHA256
            else {
                throw InvestigationMachineEvidenceContractError.invalidEncoding
            }
        case .opaqueBytes: break
        }
        let candidate = try InvestigationMachineEvidenceArtifact(
            path: path, role: role, encoding: encoding,
            byteCount: UInt64(bytes.count), sha256: .hashing(bytes)
        )
        guard !artifacts.contains(where: { $0.path == path }) else {
            throw InvestigationMachineRawEvidenceError.duplicateArtifact
        }
        guard role.allowsMultiple || !artifacts.contains(where: { $0.role == role })
        else { throw InvestigationMachineEvidenceContractError.duplicateRole }
        return try publish(
            path: path, role: role, encoding: encoding, bytes: bytes,
            artifact: candidate
        )
    }

    private func publish(
        path: InvestigationMachineEvidenceRelativePath,
        role: InvestigationMachineEvidenceRole,
        encoding: InvestigationMachineEvidenceEncoding, bytes: Data,
        artifact supplied: InvestigationMachineEvidenceArtifact? = nil
    ) throws -> InvestigationMachineEvidenceArtifact {
        guard let parent = phaseDescriptors[path.phase] else {
            return try poison(.validateDirectory)
        }
        let artifact = try supplied ?? InvestigationMachineEvidenceArtifact(
            path: path, role: role, encoding: encoding,
            byteCount: UInt64(bytes.count), sha256: .hashing(bytes)
        )
        do {
            try publishFile(
                parent: parent, name: path.leafName, bytes: bytes,
                baseDevice: initialRootMetadata.identity.device
            )
            artifacts.append(artifact)
            return artifact
        } catch let error as InvestigationMachineEvidenceContractError {
            throw error
        } catch let error as InvestigationMachineRawEvidenceError {
            state = .uncertain
            throw error
        } catch {
            state = .uncertain
            throw InvestigationMachineRawEvidenceError
                .uncertain(stage: .publish)
        }
    }

    private func publishManifest(_ bytes: Data) throws {
        try publishFile(
            parent: rootDescriptor, name: "manifest.bin", bytes: bytes,
            baseDevice: initialRootMetadata.identity.device
        )
    }

    private func publishFile(
        parent: Int32, name: String, bytes: Data, baseDevice: UInt64
    ) throws {
        let pending = ".pending-" + name
        var writer = Int32(-1)
        var reader = Int32(-1)
        do {
            writer = try at(.createPending) { try system.openComponent(
                parentDescriptor: parent, name: pending,
                flags: Self.pendingWriterFlags, mode: 0o600
            ) }
            try admitOpenedDescriptor(&writer, stage: .createPending)
            try at(.validatePending) {
                try system.setPermissions(descriptor: writer, mode: 0o600)
            }
            try writeAll(bytes, descriptor: writer)
            let pendingMetadata = try at(.validatePending) { try Self.validateFile(
                descriptor: writer, parent: parent, name: pending,
                baseDevice: baseDevice, owner: owner,
                expectedSize: Int64(bytes.count), accessMode: O_WRONLY,
                system: system
            ) }
            try at(.synchronizeFile) {
                try system.synchronize(descriptor: writer)
            }
            try at(.publish) { try system.rename(
                parentDescriptor: parent, oldName: pending, newName: name,
                flags: Self.renameFlags
            ) }
            try at(.synchronizeDirectory) {
                try system.synchronize(descriptor: parent)
            }
            reader = try at(.reopenFinal) { try system.openComponent(
                parentDescriptor: parent, name: name,
                flags: Self.finalReaderFlags, mode: nil
            ) }
            try admitOpenedDescriptor(
                &reader, stage: .reopenFinal, additionalAliases: [writer]
            )
            let finalMetadata = try at(.validateFinal) { try Self.validateFile(
                descriptor: reader, parent: parent, name: name,
                baseDevice: baseDevice, owner: owner,
                expectedSize: Int64(bytes.count), accessMode: O_RDONLY,
                system: system
            ) }
            let verifiedBytes = try at(.readFinal) {
                try readExactly(reader, count: bytes.count)
            }
            let reachedEOF = try at(.readFinal) {
                try system.read(
                    descriptor: reader, maximumByteCount: 1,
                    offset: Int64(bytes.count)
                ).isEmpty
            }
            let postReadMetadata = try at(.validateFinal) { try Self.validateFile(
                descriptor: reader, parent: parent, name: name,
                baseDevice: baseDevice, owner: owner,
                expectedSize: Int64(bytes.count), accessMode: O_RDONLY,
                system: system
            ) }
            guard finalMetadata.identity == pendingMetadata.identity,
                  verifiedBytes == bytes, reachedEOF,
                  postReadMetadata == finalMetadata
            else { return try poison(.validateFinal) }
            try closeLocal(&writer)
            try closeLocal(&reader)
        } catch let error as InvestigationMachineRawEvidenceError {
            let writerCloseCertain = closeBestEffort(&writer)
            let readerCloseCertain = closeBestEffort(&reader)
            guard writerCloseCertain && readerCloseCertain else {
                throw InvestigationMachineRawEvidenceError
                    .uncertain(stage: .closeDescriptor)
            }
            throw error
        } catch let error as InvestigationMachineEvidenceContractError {
            let writerCloseCertain = closeBestEffort(&writer)
            let readerCloseCertain = closeBestEffort(&reader)
            guard writerCloseCertain && readerCloseCertain else {
                throw InvestigationMachineRawEvidenceError
                    .uncertain(stage: .closeDescriptor)
            }
            throw error
        } catch {
            let writerCloseCertain = closeBestEffort(&writer)
            let readerCloseCertain = closeBestEffort(&reader)
            guard writerCloseCertain && readerCloseCertain else {
                throw InvestigationMachineRawEvidenceError
                    .uncertain(stage: .closeDescriptor)
            }
            throw InvestigationMachineRawEvidenceError.uncertain(stage: .publish)
        }
    }

    private func validateCompleteTree(
        expectedManifest: InvestigationMachineEvidenceManifestV1? = nil,
        expectedBytes: Data? = nil
    ) throws {
        guard (expectedManifest == nil) == (expectedBytes == nil) else {
            return try poison(.validateFinal)
        }
        let includeManifest = expectedManifest != nil
        let expectedRoot = Set(
            InvestigationMachineEvidencePhase.allCases.map(\.directoryName)
                + (includeManifest ? ["manifest.bin"] : [])
        )
        let rootInventory = try at(.inventory) { try system.inventory(
            descriptor: rootDescriptor, maximumEntryCount: Self.maximumInventoryCount
        ) }
        guard rootInventory.reachedEnd, Set(rootInventory.names) == expectedRoot,
              rootInventory.names.count == expectedRoot.count
        else { return try poison(.inventory) }
        for phase in InvestigationMachineEvidencePhase.allCases {
            guard let descriptor = phaseDescriptors[phase] else {
                return try poison(.validateDirectory)
            }
            _ = try at(.validateDirectory) { try Self.validateDirectory(
                descriptor: descriptor, parent: rootDescriptor,
                name: phase.directoryName,
                baseDevice: initialRootMetadata.identity.device, owner: owner,
                system: system
            ) }
            let expected = artifacts.filter { $0.path.phase == phase }
            let inventory = try at(.inventory) { try system.inventory(
                descriptor: descriptor,
                maximumEntryCount: Self.maximumInventoryCount
            ) }
            guard inventory.reachedEnd,
                  inventory.names == inventory.names.sorted(),
                  Set(inventory.names) == Set(expected.map { $0.path.leafName }),
                  inventory.names.count == expected.count
            else { return try poison(.inventory) }
            for artifact in expected {
                var local = try at(.reopenFinal) { try system.openComponent(
                    parentDescriptor: descriptor, name: artifact.path.leafName,
                    flags: Self.finalReaderFlags, mode: nil
                ) }
                try admitOpenedDescriptor(&local, stage: .reopenFinal)
                let reader = local
                do {
                    let metadata = try at(.validateFinal) { try Self.validateFile(
                        descriptor: reader, parent: descriptor,
                        name: artifact.path.leafName,
                        baseDevice: initialRootMetadata.identity.device, owner: owner,
                        expectedSize: Int64(artifact.byteCount), accessMode: O_RDONLY,
                        system: system
                    ) }
                    let bytes = try readExactly(
                        reader, count: Int(artifact.byteCount)
                    )
                    let reachedEOF = try at(.readFinal) { try system.read(
                        descriptor: reader, maximumByteCount: 1,
                        offset: Int64(artifact.byteCount)).isEmpty }
                    let postReadMetadata = try at(.validateFinal) {
                        try Self.validateFile(
                            descriptor: reader, parent: descriptor,
                            name: artifact.path.leafName,
                            baseDevice: initialRootMetadata.identity.device,
                            owner: owner, expectedSize: Int64(artifact.byteCount),
                            accessMode: O_RDONLY, system: system)
                    }
                    guard reachedEOF,
                          InvestigationHandoffSHA256.hashing(bytes) == artifact.sha256,
                          postReadMetadata == metadata
                    else { return try poison(.validateFinal) }
                    try closeLocal(&local)
                } catch {
                    let saved = error
                    guard closeBestEffort(&local) else {
                        throw InvestigationMachineRawEvidenceError
                            .uncertain(stage: .closeDescriptor)
                    }
                    throw saved
                }
            }
        }
        if includeManifest {
            var local = try at(.reopenFinal) { try system.openComponent(
                parentDescriptor: rootDescriptor, name: "manifest.bin",
                flags: Self.finalReaderFlags, mode: nil
            ) }
            try admitOpenedDescriptor(&local, stage: .reopenFinal)
            let reader = local
            do {
                let expectedManifest = try expectedManifest
                    .unwrapped(or: InvestigationMachineRawEvidenceError
                        .uncertain(stage: .validateFinal))
                let expectedBytes = try expectedBytes
                    .unwrapped(or: InvestigationMachineRawEvidenceError
                        .uncertain(stage: .validateFinal))
                let metadata = try at(.validateFinal) { try Self.validateFile(
                    descriptor: reader, parent: rootDescriptor,
                    name: "manifest.bin",
                    baseDevice: initialRootMetadata.identity.device, owner: owner,
                    expectedSize: Int64(expectedBytes.count),
                    accessMode: O_RDONLY, system: system
                ) }
                guard metadata.identity.size > 0, expectedBytes.count <=
                        InvestigationMachineEvidenceManifestV1.maximumByteCount
                else { return try poison(.validateFinal) }
                let bytes = try readExactly(reader, count: expectedBytes.count)
                let reachedEOF = try at(.readFinal) { try system.read(
                    descriptor: reader, maximumByteCount: 1,
                    offset: Int64(expectedBytes.count)
                ).isEmpty }
                let decoded = try InvestigationMachineEvidenceManifestV1.decode(bytes)
                let postReadMetadata = try at(.validateFinal) { try Self.validateFile(
                    descriptor: reader, parent: rootDescriptor, name: "manifest.bin",
                    baseDevice: initialRootMetadata.identity.device, owner: owner,
                    expectedSize: Int64(expectedBytes.count), accessMode: O_RDONLY,
                    system: system
                ) }
                guard bytes == expectedBytes, reachedEOF,
                      decoded == expectedManifest, postReadMetadata == metadata
                else { return try poison(.validateFinal) }
                try closeLocal(&local)
            } catch {
                let saved = error
                guard closeBestEffort(&local) else {
                    throw InvestigationMachineRawEvidenceError
                        .uncertain(stage: .closeDescriptor)
                }
                throw saved
            }
        }
    }

    private func writeAll(_ bytes: Data, descriptor: Int32) throws {
        var offset = 0
        var interrupts = 0
        while offset < bytes.count {
            let end = min(bytes.count, offset + Self.maximumIOByteCount)
            do {
                let count = try system.write(
                    descriptor: descriptor, bytes: Data(bytes[offset..<end]),
                    offset: Int64(offset)
                )
                guard count > 0, count <= end - offset else {
                    return try poison(.writePending)
                }
                offset += count
            } catch InvestigationMachineRawEvidenceSystemError.errno(let value)
                where value == EINTR
            {
                interrupts += 1
                guard interrupts <= Self.maximumInterruptCount else {
                    return try poison(.writePending)
                }
            } catch { return try poison(.writePending) }
        }
    }

    private func readExactly(_ descriptor: Int32, count: Int) throws -> Data {
        var output = Data()
        var interrupts = 0
        output.reserveCapacity(count)
        while output.count < count {
            do {
                let bytes = try system.read(
                    descriptor: descriptor,
                    maximumByteCount: min(
                        Self.maximumIOByteCount, count - output.count),
                    offset: Int64(output.count)
                )
                guard !bytes.isEmpty, bytes.count <= count - output.count else {
                    return try poison(.readFinal)
                }
                output.append(bytes)
            } catch InvestigationMachineRawEvidenceSystemError.errno(let value)
                where value == EINTR
            {
                interrupts += 1
                guard interrupts <= Self.maximumInterruptCount else {
                    return try poison(.readFinal)
                }
            } catch { return try poison(.readFinal) }
        }
        return output
    }

    private func closeLocal(_ descriptor: inout Int32) throws {
        guard descriptor >= 0 else { return }
        let value = descriptor
        descriptor = -1
        do { try system.close(descriptor: value) }
        catch { return try poison(.closeDescriptor) }
    }

    private func closeLocalBestEffort(_ descriptor: inout Int32) {
        guard descriptor >= 0 else { return }
        let value = descriptor
        descriptor = -1
        try? system.close(descriptor: value)
    }

    private func closeBestEffort(_ descriptor: inout Int32) -> Bool {
        guard descriptor >= 0 else { return true }
        let value = descriptor
        descriptor = -1
        do { try system.close(descriptor: value); return true }
        catch { return false }
    }

    private func admitOpenedDescriptor(
        _ descriptor: inout Int32,
        stage: InvestigationMachineRawEvidenceFailureStage,
        additionalAliases: [Int32] = []
    ) throws {
        let value = descriptor
        let isAlias = value == parentDescriptor || value == rootDescriptor
            || phaseDescriptors.values.contains(value)
            || additionalAliases.contains(value)
        guard value >= 3, !isAlias else {
            let closeCertain = value < 0 || isAlias
                || closeBestEffort(&descriptor)
            descriptor = -1
            guard closeCertain else { return try poison(.closeDescriptor) }
            return try poison(stage)
        }
    }

    private func closeOwnedDescriptors() throws {
        guard !descriptorsClosed else { return }
        descriptorsClosed = true
        var failure = false
        let values = Array(phaseDescriptors.values) + [rootDescriptor]
        phaseDescriptors.removeAll()
        for descriptor in values {
            do { try system.close(descriptor: descriptor) }
            catch { failure = true }
        }
        if failure { return try poison(.closeDescriptor) }
    }

    private func poison<T>(
        _ stage: InvestigationMachineRawEvidenceFailureStage
    ) throws -> T {
        state = .uncertain
        throw InvestigationMachineRawEvidenceError.uncertain(stage: stage)
    }

    private func at<T>(
        _ stage: InvestigationMachineRawEvidenceFailureStage,
        _ body: () throws -> T
    ) throws -> T {
        do { return try body() }
        catch let error as InvestigationMachineEvidenceContractError { throw error }
        catch is InvestigationMachineRawEvidenceError {
            throw InvestigationMachineRawEvidenceError.uncertain(stage: stage)
        }
        catch { throw InvestigationMachineRawEvidenceError.uncertain(stage: stage) }
    }

    private static func canonicalJSON(_ bytes: Data) throws -> Data {
        let object = try JSONSerialization.jsonObject(
            with: bytes, options: [.fragmentsAllowed]
        )
        guard object is [String: Any] else {
            throw InvestigationMachineEvidenceContractError.invalidEncoding
        }
        return try JSONSerialization.data(
            withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }

    private static func validateParent(
        descriptor: Int32, expected: InvestigationMachineEvidenceNodeIdentity,
        owner: InvestigationMachineEvidenceOwnerIdentity,
        system: any InvestigationMachineRawEvidenceSystem
    ) throws {
        let metadata = try system.metadata(descriptor: descriptor)
        guard sameDirectoryNode(metadata.identity, expected),
              metadata.fileType == .directory,
              metadata.ownerUserID == owner.userID,
              metadata.ownerGroupID == owner.groupID,
              metadata.permissions == 0o700, metadata.linkCount > 0,
              metadata.flags == 0,
              try system.descriptorFlags(descriptor) & FD_CLOEXEC == FD_CLOEXEC,
              try system.descriptorStatusFlags(descriptor) & O_ACCMODE == O_RDONLY,
              try system.extendedACLIsEmpty(descriptor: descriptor),
              try system.extendedAttributeNames(descriptor: descriptor).isEmpty
        else { throw InvestigationMachineRawEvidenceError.uncertain(stage: .validateParent) }
    }

    @discardableResult
    private static func validateDirectory(
        descriptor: Int32, parent: Int32, name: String, baseDevice: UInt64,
        owner: InvestigationMachineEvidenceOwnerIdentity,
        system: any InvestigationMachineRawEvidenceSystem
    ) throws -> InvestigationMachineEvidenceNodeMetadata {
        let held = try system.metadata(descriptor: descriptor)
        let named = try system.namedMetadata(
            parentDescriptor: parent, name: name, flags: namedFlags
        )
        guard held == named, held.identity.device == baseDevice,
              held.identity.inode > 0, held.fileType == .directory,
              held.ownerUserID == owner.userID, held.ownerGroupID == owner.groupID,
              held.permissions == 0o700, held.linkCount > 0, held.flags == 0,
              try system.descriptorFlags(descriptor) & FD_CLOEXEC == FD_CLOEXEC,
              try system.descriptorStatusFlags(descriptor) & O_ACCMODE == O_RDONLY,
              try system.extendedACLIsEmpty(descriptor: descriptor),
              try system.extendedAttributeNames(descriptor: descriptor).isEmpty
        else { throw InvestigationMachineRawEvidenceError.uncertain(stage: .validateDirectory) }
        return held
    }

    private static func validateFile(
        descriptor: Int32, parent: Int32, name: String, baseDevice: UInt64,
        owner: InvestigationMachineEvidenceOwnerIdentity, expectedSize: Int64,
        accessMode: Int32, system: any InvestigationMachineRawEvidenceSystem
    ) throws -> InvestigationMachineEvidenceNodeMetadata {
        let held = try system.metadata(descriptor: descriptor)
        let named = try system.namedMetadata(
            parentDescriptor: parent, name: name, flags: namedFlags
        )
        guard held == named, held.identity.device == baseDevice,
              held.identity.inode > 0, held.identity.size == expectedSize,
              held.fileType == .regularFile, held.ownerUserID == owner.userID,
              held.ownerGroupID == owner.groupID, held.permissions == 0o600,
              held.linkCount == 1, held.flags == 0,
              try system.descriptorFlags(descriptor) & FD_CLOEXEC == FD_CLOEXEC,
              try system.descriptorStatusFlags(descriptor) & O_ACCMODE == accessMode,
              try system.extendedACLIsEmpty(descriptor: descriptor),
              try system.extendedAttributeNames(descriptor: descriptor).isEmpty
        else { throw InvestigationMachineRawEvidenceError.uncertain(stage: .validateFinal) }
        return held
    }

    private static func zeroDigest() throws -> InvestigationHandoffSHA256 {
        try .init(rawBytes: Data(repeating: 0, count: InvestigationHandoffSHA256.byteCount))
    }

    private static func sameDirectoryNode(
        _ lhs: InvestigationMachineEvidenceNodeIdentity,
        _ rhs: InvestigationMachineEvidenceNodeIdentity
    ) -> Bool {
        lhs.device == rhs.device && lhs.inode == rhs.inode
            && lhs.generation == rhs.generation
    }

    private static func nonzero(_ value: UUID) -> Bool {
        var raw = value.uuid
        return withUnsafeBytes(of: &raw) { $0.contains { $0 != 0 } }
    }

    @discardableResult
    private static func closeBestEffort(
        _ descriptors: [Int32], system: any InvestigationMachineRawEvidenceSystem
    ) -> Bool {
        var certain = true
        var seen = Set<Int32>()
        for descriptor in descriptors where descriptor >= 0
            && seen.insert(descriptor).inserted
        {
            do { try system.close(descriptor: descriptor) }
            catch { certain = false }
        }
        return certain
    }

    private static func atInitialization<T>(
        _ stage: InvestigationMachineRawEvidenceFailureStage,
        _ body: () throws -> T
    ) throws -> T {
        do { return try body() }
        catch let error as InvestigationMachineRawEvidenceError { throw error }
        catch { throw InvestigationMachineRawEvidenceError.uncertain(stage: stage) }
    }
}

private extension Optional {
    func unwrapped(or error: @autoclosure () -> any Error) throws -> Wrapped {
        guard let self else { throw error() }
        return self
    }
}

package final class DarwinInvestigationMachineRawEvidenceSystem:
    InvestigationMachineRawEvidenceSystem, @unchecked Sendable
{
    private static let maximumXattrBytes = 4 * 1_024

    package init() {}

    package func effectiveIdentity() -> InvestigationMachineEvidenceOwnerIdentity {
        .init(userID: geteuid(), groupID: getegid())
    }

    package func inventory(
        descriptor: Int32, maximumEntryCount: Int
    ) throws -> InvestigationMachineEvidenceInventory {
        let duplicate = openat(
            descriptor, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NONBLOCK
                | O_NOFOLLOW_ANY | O_RESOLVE_BENEATH
        )
        guard duplicate >= 0 else { throw lastError() }
        guard let directory = fdopendir(duplicate) else {
            let saved = errno
            _ = Darwin.close(duplicate)
            throw InvestigationMachineRawEvidenceSystemError.errno(saved)
        }
        var values: [String] = []
        var reachedEnd = false
        do {
            while values.count <= maximumEntryCount {
                errno = 0
                guard let entry = readdir(directory) else {
                    guard errno == 0 else { throw lastError() }
                    reachedEnd = true
                    break
                }
                let name = try Self.name(entry)
                if name != "." && name != ".." { values.append(name) }
            }
        } catch {
            let saved = error
            guard closedir(directory) == 0 else { throw lastError() }
            throw saved
        }
        guard closedir(directory) == 0 else { throw lastError() }
        return .init(names: values.sorted(), reachedEnd: reachedEnd)
    }

    package func createDirectory(
        parentDescriptor: Int32, name: String, mode: mode_t
    ) throws {
        guard mkdirat(parentDescriptor, name, mode) == 0 else { throw lastError() }
    }

    package func openComponent(
        parentDescriptor: Int32, name: String, flags: Int32, mode: mode_t?
    ) throws -> Int32 {
        let descriptor = mode.map { openat(parentDescriptor, name, flags, $0) }
            ?? openat(parentDescriptor, name, flags)
        guard descriptor >= 0 else { throw lastError() }
        return descriptor
    }

    package func metadata(
        descriptor: Int32
    ) throws -> InvestigationMachineEvidenceNodeMetadata {
        var value = stat()
        guard fstat(descriptor, &value) == 0 else { throw lastError() }
        return Self.snapshot(value)
    }

    package func namedMetadata(
        parentDescriptor: Int32, name: String, flags: Int32
    ) throws -> InvestigationMachineEvidenceNodeMetadata {
        var value = stat()
        guard fstatat(parentDescriptor, name, &value, flags) == 0 else {
            throw lastError()
        }
        return Self.snapshot(value)
    }

    package func descriptorFlags(_ descriptor: Int32) throws -> Int32 {
        let value = fcntl(descriptor, F_GETFD)
        guard value >= 0 else { throw lastError() }
        return value
    }

    package func descriptorStatusFlags(_ descriptor: Int32) throws -> Int32 {
        let value = fcntl(descriptor, F_GETFL)
        guard value >= 0 else { throw lastError() }
        return value
    }

    package func setPermissions(descriptor: Int32, mode: mode_t) throws {
        guard fchmod(descriptor, mode) == 0 else { throw lastError() }
    }

    package func extendedACLIsEmpty(descriptor: Int32) throws -> Bool {
        errno = 0
        guard let acl = acl_get_fd_np(descriptor, ACL_TYPE_EXTENDED) else {
            if errno == ENOENT { return true }
            throw lastError()
        }
        var entry: acl_entry_t?
        let result = acl_get_entry(acl, Int32(ACL_FIRST_ENTRY.rawValue), &entry)
        let saved = errno
        guard acl_free(UnsafeMutableRawPointer(acl)) == 0 else { throw lastError() }
        guard result >= 0 else {
            throw InvestigationMachineRawEvidenceSystemError.errno(saved)
        }
        return result != 0
    }

    package func extendedAttributeNames(descriptor: Int32) throws -> [String] {
        let count = flistxattr(descriptor, nil, 0, 0)
        guard count >= 0, count <= Self.maximumXattrBytes else {
            throw InvestigationMachineRawEvidenceSystemError.errno(
                count < 0 ? errno : EOVERFLOW
            )
        }
        guard count > 0 else { return [] }
        var bytes = [UInt8](repeating: 0, count: count)
        let observed = bytes.withUnsafeMutableBytes { buffer in
            flistxattr(
                descriptor,
                buffer.baseAddress?.assumingMemoryBound(to: CChar.self),
                buffer.count, 0
            )
        }
        guard observed == count, bytes.last == 0 else {
            throw InvestigationMachineRawEvidenceSystemError.errno(EIO)
        }
        return try bytes.split(separator: 0).map { raw in
            guard let value = String(bytes: raw, encoding: .utf8), !value.isEmpty
            else { throw InvestigationMachineRawEvidenceSystemError.errno(EILSEQ) }
            return value
        }.sorted()
    }

    package func synchronize(descriptor: Int32) throws {
        guard fsync(descriptor) == 0 else { throw lastError() }
    }

    package func write(
        descriptor: Int32, bytes: Data, offset: Int64
    ) throws -> Int {
        let count = bytes.withUnsafeBytes { buffer in
            pwrite(descriptor, buffer.baseAddress, buffer.count, off_t(offset))
        }
        guard count >= 0 else { throw lastError() }
        return count
    }

    package func rename(
        parentDescriptor: Int32, oldName: String, newName: String, flags: Int32
    ) throws {
        guard renameatx_np(
            parentDescriptor, oldName, parentDescriptor, newName, UInt32(flags)
        ) == 0 else { throw lastError() }
    }

    package func read(
        descriptor: Int32, maximumByteCount: Int, offset: Int64
    ) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: maximumByteCount)
        let count = bytes.withUnsafeMutableBytes { buffer in
            pread(descriptor, buffer.baseAddress, buffer.count, off_t(offset))
        }
        guard count >= 0 else { throw lastError() }
        return Data(bytes.prefix(count))
    }

    package func close(descriptor: Int32) throws {
        guard Darwin.close(descriptor) == 0 else { throw lastError() }
    }

    private static func snapshot(_ value: stat)
        -> InvestigationMachineEvidenceNodeMetadata
    {
        let fileType: InvestigationMachineEvidenceFileType =
            switch value.st_mode & S_IFMT {
            case S_IFDIR: .directory
            case S_IFREG: .regularFile
            default: .other
            }
        return .init(
            identity: .init(
                device: UInt64(value.st_dev), inode: UInt64(value.st_ino),
                generation: UInt64(value.st_gen), size: value.st_size
            ), fileType: fileType, ownerUserID: value.st_uid,
            ownerGroupID: value.st_gid, permissions: value.st_mode & 0o7777,
            linkCount: UInt64(value.st_nlink), flags: value.st_flags
        )
    }

    private static func name(_ entry: UnsafePointer<dirent>) throws -> String {
        guard let recordOffset = MemoryLayout<dirent>.offset(of: \.d_reclen),
              let lengthOffset = MemoryLayout<dirent>.offset(of: \.d_namlen),
              let nameOffset = MemoryLayout<dirent>.offset(of: \.d_name)
        else { throw InvestigationMachineRawEvidenceSystemError.errno(EIO) }
        let raw = UnsafeRawPointer(entry)
        let recordLength = Int(raw.load(
            fromByteOffset: recordOffset, as: UInt16.self))
        let nameLength = Int(raw.load(
            fromByteOffset: lengthOffset, as: UInt16.self))
        guard nameLength > 0, nameLength < MemoryLayout.size(ofValue: dirent().d_name),
              recordLength <= MemoryLayout<dirent>.size,
              nameOffset + nameLength + 1 <= recordLength
        else { throw InvestigationMachineRawEvidenceSystemError.errno(EIO) }
        let bytes = UnsafeBufferPointer(
            start: raw.advanced(by: nameOffset).assumingMemoryBound(to: UInt8.self),
            count: nameLength
        )
        guard let name = String(bytes: bytes, encoding: .utf8),
              name.utf8.count == nameLength
        else { throw InvestigationMachineRawEvidenceSystemError.errno(EILSEQ) }
        return name
    }

    private func lastError() -> InvestigationMachineRawEvidenceSystemError {
        .errno(errno)
    }
}
#endif
