#if DEBUG
import Darwin
import Foundation
import StornautInvestigationHandoffContract

package enum InvestigationMachineEvidenceContractError:
    Error, Equatable, Sendable
{
    case invalidPath
    case invalidRole
    case invalidEncoding
    case invalidOrdering
    case duplicateArtifact
    case duplicateRole
    case missingRole
    case invalidTransition
    case incompleteInput
    case sizeLimitExceeded
}

package enum InvestigationMachineEvidencePhase:
    UInt32, CaseIterable, Hashable, Sendable
{
    case preflight = 1
    case install = 2
    case authorization = 3
    case driverEpochs = 4
    case uninstall = 5
    case verifier = 6

    package var directoryName: String {
        switch self {
        case .preflight: "01-preflight"
        case .install: "02-install"
        case .authorization: "03-authorization"
        case .driverEpochs: "04-driver-epochs"
        case .uninstall: "05-uninstall"
        case .verifier: "06-verifier"
        }
    }
}

package enum InvestigationMachineEvidenceEncoding:
    UInt32, Hashable, Sendable
{
    case canonicalBinary = 1
    case strictJSON = 2
    case opaqueBytes = 3
    case framedCanonicalBinary = 4
}

package enum InvestigationMachineEvidenceRole:
    UInt32, CaseIterable, Hashable, Sendable
{
    case sourceBuildIdentity = 1
    case builtStagingInstalledIdentity = 2
    case policyProbe = 3
    case humanPromptAttestation = 4
    case noAuthModelNetworkCounters = 5
    case protocolReceipt = 6
    case diagnosticOutput = 7
    case epochL2Projection = 8
    case epochResidueProjection = 9
    case uninstallEvidence = 10
    case globalPostTeardown = 11
    case verifierInput = 12
    case attemptEvent = 13

    package var phase: InvestigationMachineEvidencePhase {
        switch self {
        case .sourceBuildIdentity: .preflight
        case .builtStagingInstalledIdentity: .install
        case .policyProbe, .humanPromptAttestation,
             .noAuthModelNetworkCounters, .attemptEvent: .authorization
        case .protocolReceipt, .diagnosticOutput, .epochL2Projection,
             .epochResidueProjection: .driverEpochs
        case .uninstallEvidence: .uninstall
        case .globalPostTeardown, .verifierInput: .verifier
        }
    }

    package var requiredEncoding: InvestigationMachineEvidenceEncoding {
        switch self {
        case .protocolReceipt: .framedCanonicalBinary
        case .attemptEvent: .canonicalBinary
        case .diagnosticOutput: .opaqueBytes
        default: .strictJSON
        }
    }

    package var allowsMultiple: Bool {
        switch self {
        case .epochL2Projection, .epochResidueProjection, .attemptEvent: true
        default: false
        }
    }

    fileprivate func admitsCardinality(_ count: Int) -> Bool {
        switch self {
        case .epochL2Projection, .epochResidueProjection: (0...8).contains(count)
        case .attemptEvent: (2...4).contains(count)
        default: count == 1
        }
    }

    fileprivate func admitsLeaf(_ leaf: String) -> Bool {
        switch self {
        case .sourceBuildIdentity: return leaf == "source-build.json"
        case .builtStagingInstalledIdentity: return leaf == "installed.json"
        case .policyProbe: return leaf == "policy-probe.json"
        case .humanPromptAttestation: return leaf == "human-attestation.json"
        case .noAuthModelNetworkCounters: return leaf == "capability-counts.json"
        case .protocolReceipt: return leaf == "coordinator-receipt.bin"
        case .diagnosticOutput: return leaf == "diagnostic-output.bin"
        case .epochL2Projection:
            return Self.epochLeaf(leaf, suffix: "-l2.json")
        case .epochResidueProjection:
            return Self.epochLeaf(leaf, suffix: "-residue.json")
        case .uninstallEvidence: return leaf == "uninstall.json"
        case .globalPostTeardown: return leaf == "global-post-teardown.json"
        case .verifierInput: return leaf == "verification-input.json"
        case .attemptEvent:
            guard leaf.hasPrefix("attempt-event-"), leaf.hasSuffix(".bin")
            else { return false }
            let digits = leaf.dropFirst(14).dropLast(4)
            return digits.count == 4 && digits.allSatisfy(\.isNumber)
                && (1...4).contains(Int(digits) ?? 0)
        }
    }

    private static func epochLeaf(_ leaf: String, suffix: String) -> Bool {
        guard leaf.hasPrefix("epoch-"), leaf.hasSuffix(suffix) else {
            return false
        }
        let digits = leaf.dropFirst(6).dropLast(suffix.count)
        return digits.count == 2 && digits.allSatisfy(\.isNumber)
            && (1...8).contains(Int(digits) ?? 0)
    }
}

package struct InvestigationMachineEvidenceRelativePath:
    Hashable, Sendable
{
    package let phase: InvestigationMachineEvidencePhase
    package let leafName: String
    package var relativeValue: String { phase.directoryName + "/" + leafName }

    package init(
        phase: InvestigationMachineEvidencePhase, leafName: String
    ) throws {
        guard Self.validLeaf(leafName) else {
            throw InvestigationMachineEvidenceContractError.invalidPath
        }
        self.phase = phase
        self.leafName = leafName
    }

    package init(relativeValue: String) throws {
        let bytes = Array(relativeValue.utf8)
        guard bytes.count <= 128, !bytes.contains(0),
              let separator = bytes.firstIndex(of: UInt8(ascii: "/")),
              !bytes[(separator + 1)...].contains(UInt8(ascii: "/")),
              let phase = InvestigationMachineEvidencePhase.allCases.first(
                where: { Data($0.directoryName.utf8) == Data(bytes[..<separator]) }
              )
        else { throw InvestigationMachineEvidenceContractError.invalidPath }
        try self.init(
            phase: phase, leafName: String(decoding: bytes[(separator + 1)...], as: UTF8.self)
        )
        guard self.relativeValue == relativeValue else {
            throw InvestigationMachineEvidenceContractError.invalidPath
        }
    }

    private static func validLeaf(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard (1...96).contains(bytes.count),
              bytes.first.map(asciiAlphanumeric) == true,
              bytes.last.map(asciiAlphanumeric) == true,
              !value.contains("pending"), value != "manifest.bin"
        else { return false }
        return bytes.allSatisfy { byte in
            asciiAlphanumeric(byte) || byte == UInt8(ascii: ".")
                || byte == UInt8(ascii: "_") || byte == UInt8(ascii: "-")
        }
    }
}

package struct InvestigationMachineEvidenceArtifact: Hashable, Sendable {
    package static let maximumByteCount: UInt64 = 16 << 20
    package let path: InvestigationMachineEvidenceRelativePath
    package let role: InvestigationMachineEvidenceRole
    package let encoding: InvestigationMachineEvidenceEncoding
    package let byteCount: UInt64
    package let sha256: InvestigationHandoffSHA256

    package init(
        path: InvestigationMachineEvidenceRelativePath,
        role: InvestigationMachineEvidenceRole,
        encoding: InvestigationMachineEvidenceEncoding, byteCount: UInt64,
        sha256: InvestigationHandoffSHA256
    ) throws {
        guard path.phase == role.phase, role.admitsLeaf(path.leafName) else {
            throw InvestigationMachineEvidenceContractError.invalidRole
        }
        guard encoding == role.requiredEncoding else {
            throw InvestigationMachineEvidenceContractError.invalidEncoding
        }
        guard byteCount <= Self.maximumByteCount,
              byteCount > 0 || role == .diagnosticOutput
        else {
            throw InvestigationMachineEvidenceContractError.sizeLimitExceeded
        }
        guard sha256.rawBytes.contains(where: { $0 != 0 }) else {
            throw InvestigationMachineEvidenceContractError.invalidEncoding
        }
        self.path = path
        self.role = role
        self.encoding = encoding
        self.byteCount = byteCount
        self.sha256 = sha256
    }
}

package struct InvestigationMachineCampaignSourceBinding:
    Hashable, Sendable
{
    package let repositoryHEAD: String
    package let repositoryTree: String
    package let canonicalSourceManifestSHA256: InvestigationHandoffSHA256
    package let buildProvenanceSHA256: InvestigationHandoffSHA256
    package let signedRuntimeBindingSHA256: InvestigationHandoffSHA256

    package init(
        repositoryHEAD: String, repositoryTree: String,
        canonicalSourceManifestSHA256: InvestigationHandoffSHA256,
        buildProvenanceSHA256: InvestigationHandoffSHA256,
        signedRuntimeBindingSHA256: InvestigationHandoffSHA256
    ) throws {
        guard validHex(repositoryHEAD, count: 40),
              validHex(repositoryTree, count: 40),
              canonicalSourceManifestSHA256.rawBytes.contains(where: { $0 != 0 }),
              buildProvenanceSHA256.rawBytes.contains(where: { $0 != 0 }),
              signedRuntimeBindingSHA256.rawBytes.contains(where: { $0 != 0 })
        else { throw InvestigationMachineEvidenceContractError.invalidEncoding }
        self.repositoryHEAD = repositoryHEAD
        self.repositoryTree = repositoryTree
        self.canonicalSourceManifestSHA256 = canonicalSourceManifestSHA256
        self.buildProvenanceSHA256 = buildProvenanceSHA256
        self.signedRuntimeBindingSHA256 = signedRuntimeBindingSHA256
    }
}

package enum InvestigationMachineAttemptMode: UInt32, Hashable, Sendable {
    case dryRun = 1
    case privileged = 2
}

package enum InvestigationMachineAttemptOutcome: UInt32, Hashable, Sendable {
    case cancelledBeforeArm = 1
    case spawnObservedTerminal = 2
    case spawnUncertainTerminal = 3
    case transportLoss = 4
}

package struct InvestigationMachineAttemptSummary: Equatable, Sendable {
    package static let domain = "stornaut.task39.iic.attempt-summary.v1"
    package let attemptUUID: UUID
    package let mode: InvestigationMachineAttemptMode
    package let outcome: InvestigationMachineAttemptOutcome
    package let consumed: Bool
    package let eventCount: UInt32
    package let finalEventSHA256: InvestigationHandoffSHA256

    package init(
        attemptUUID: UUID, mode: InvestigationMachineAttemptMode,
        outcome: InvestigationMachineAttemptOutcome, consumed: Bool,
        eventCount: UInt32, finalEventSHA256: InvestigationHandoffSHA256
    ) throws {
        let shapeIsValid = switch (mode, outcome) {
        case (.dryRun, .cancelledBeforeArm): !consumed && eventCount == 2
        case (.privileged, .cancelledBeforeArm): !consumed && eventCount == 2
        case (.privileged, .spawnObservedTerminal), (.privileged, .spawnUncertainTerminal):
            consumed && eventCount == 4
        case (.privileged, .transportLoss): consumed && eventCount == 3
        default: false
        }
        guard nonzero(attemptUUID), shapeIsValid,
              finalEventSHA256.rawBytes.contains(where: { $0 != 0 })
        else { throw InvestigationMachineEvidenceContractError.invalidTransition }
        self.attemptUUID = attemptUUID
        self.mode = mode
        self.outcome = outcome
        self.consumed = consumed
        self.eventCount = eventCount
        self.finalEventSHA256 = finalEventSHA256
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain, businessFields: [
                data(attemptUUID), data(mode.rawValue), data(outcome.rawValue),
                data(consumed), data(eventCount), finalEventSHA256.rawBytes,
            ], maximumByteCount: 256
        )
    }

    package static func decode(_ bytes: Data) throws -> Self {
        do {
            let fields = try HandoffBinaryTranscript.decode(
                bytes, expectedDomain: domain,
                expectedBusinessFieldByteCounts: [
                    16...16, 4...4, 4...4, 1...1, 4...4, 32...32,
                ], maximumByteCount: 256
            )
            guard let mode = InvestigationMachineAttemptMode(
                    rawValue: try decodeUInt32(fields[1])),
                  let outcome = InvestigationMachineAttemptOutcome(
                    rawValue: try decodeUInt32(fields[2]))
            else { throw InvestigationMachineEvidenceContractError.invalidEncoding }
            let value = try Self(
                attemptUUID: try decodeUUID(fields[0]), mode: mode,
                outcome: outcome, consumed: try decodeBool(fields[3]),
                eventCount: try decodeUInt32(fields[4]),
                finalEventSHA256: try .init(rawBytes: fields[5])
            )
            guard try value.encoded() == bytes else {
                throw InvestigationMachineEvidenceContractError.invalidEncoding
            }
            return value
        } catch let error as InvestigationMachineEvidenceContractError { throw error }
        catch { throw InvestigationMachineEvidenceContractError.invalidEncoding }
    }
}

package struct InvestigationMachineEvidenceManifestV1:
    Equatable, Sendable
{
    package static let domain = "stornaut.task39.iic.raw-evidence-manifest.v1"
    package static let maximumByteCount = 512 << 10
    package static let maximumArtifactCount = 256
    package static let maximumTotalByteCount: UInt64 = 64 << 20

    package let campaignUUID: UUID
    package let attemptUUID: UUID
    package let attemptSummary: InvestigationMachineAttemptSummary
    package let sourceBinding: InvestigationMachineCampaignSourceBinding
    package let artifacts: [InvestigationMachineEvidenceArtifact]
    package let totalByteCount: UInt64
    package let manifestSHA256: InvestigationHandoffSHA256
    package let contentRootSHA256: InvestigationHandoffSHA256

    package init(
        campaignUUID: UUID, attemptUUID: UUID,
        sourceBinding: InvestigationMachineCampaignSourceBinding,
        artifacts: some Sequence<InvestigationMachineEvidenceArtifact>,
        attemptSummary: InvestigationMachineAttemptSummary
    ) throws {
        let values = artifacts.sorted {
            $0.path.relativeValue.utf8.lexicographicallyPrecedes(
                $1.path.relativeValue.utf8)
        }
        guard nonzero(campaignUUID), nonzero(attemptUUID),
              campaignUUID != attemptUUID,
              attemptSummary.attemptUUID == attemptUUID, !values.isEmpty,
              values.count <= Self.maximumArtifactCount
        else { throw InvestigationMachineEvidenceContractError.invalidEncoding }
        let pathCount = Set(values.map(\.path)).count
        guard pathCount == values.count else {
            throw InvestigationMachineEvidenceContractError.duplicateArtifact
        }
        try Self.validateRoles(values, summary: attemptSummary)
        let eventArtifacts = values.filter { $0.role == .attemptEvent }
        guard eventArtifacts.count == Int(attemptSummary.eventCount),
              eventArtifacts.last?.sha256 == attemptSummary.finalEventSHA256
        else { throw InvestigationMachineEvidenceContractError.invalidTransition }
        let sum = values.reduce(UInt64(0)) { partial, artifact in
            partial.addingReportingOverflow(artifact.byteCount).overflow
                ? UInt64.max : partial + artifact.byteCount
        }
        guard sum <= Self.maximumTotalByteCount else {
            throw InvestigationMachineEvidenceContractError.sizeLimitExceeded
        }
        self.campaignUUID = campaignUUID
        self.attemptUUID = attemptUUID
        self.attemptSummary = attemptSummary
        self.sourceBinding = sourceBinding
        self.artifacts = values
        totalByteCount = sum
        let bytes = try Self.transcript(
            campaignUUID: campaignUUID, attemptUUID: attemptUUID,
            sourceBinding: sourceBinding, artifacts: values,
            attemptSummary: attemptSummary, totalByteCount: sum
        )
        manifestSHA256 = .hashing(bytes)
        contentRootSHA256 = try Self.contentRoot(manifestSHA256)
    }

    package func encoded() throws -> Data {
        let value = try Self.transcript(
            campaignUUID: campaignUUID, attemptUUID: attemptUUID,
            sourceBinding: sourceBinding, artifacts: artifacts,
            attemptSummary: attemptSummary, totalByteCount: totalByteCount
        )
        guard .hashing(value) == manifestSHA256,
              try Self.contentRoot(manifestSHA256) == contentRootSHA256
        else { throw InvestigationMachineEvidenceContractError.invalidEncoding }
        return value
    }

    package static func decode(_ data: Data) throws -> Self {
        do {
            let fields = try HandoffBinaryTranscript.decode(
                data, expectedDomain: domain,
                expectedBusinessFieldByteCounts: [
                    16...16, 16...16, 1...256, 40...40, 40...40,
                    32...32, 32...32, 32...32, 4...4, 8...8,
                    1...maximumByteCount,
                ], maximumByteCount: maximumByteCount
            )
            let count = Int(try decodeUInt32(fields[8]))
            guard (1...maximumArtifactCount).contains(count) else {
                throw InvestigationMachineEvidenceContractError.invalidEncoding
            }
            let entries = try decodeEntries(fields[10], count: count)
            let value = try Self(
                campaignUUID: try decodeUUID(fields[0]),
                attemptUUID: try decodeUUID(fields[1]),
                sourceBinding: .init(
                    repositoryHEAD: try decodeString(fields[3]),
                    repositoryTree: try decodeString(fields[4]),
                    canonicalSourceManifestSHA256: try .init(rawBytes: fields[5]),
                    buildProvenanceSHA256: try .init(rawBytes: fields[6]),
                    signedRuntimeBindingSHA256: try .init(rawBytes: fields[7])
                ), artifacts: entries,
                attemptSummary: try InvestigationMachineAttemptSummary
                    .decode(fields[2])
            )
            let encodedTotal = try decodeUInt64(fields[9])
            guard value.totalByteCount == encodedTotal,
                  value.artifacts == entries, try value.encoded() == data
            else { throw InvestigationMachineEvidenceContractError.invalidOrdering }
            return value
        } catch let error as InvestigationMachineEvidenceContractError {
            throw error
        } catch { throw InvestigationMachineEvidenceContractError.invalidEncoding }
    }

    private static func transcript(
        campaignUUID: UUID, attemptUUID: UUID,
        sourceBinding: InvestigationMachineCampaignSourceBinding,
        artifacts: [InvestigationMachineEvidenceArtifact],
        attemptSummary: InvestigationMachineAttemptSummary, totalByteCount: UInt64
    ) throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: domain, businessFields: [
                data(campaignUUID), data(attemptUUID), try attemptSummary.encoded(),
                Data(sourceBinding.repositoryHEAD.utf8),
                Data(sourceBinding.repositoryTree.utf8),
                sourceBinding.canonicalSourceManifestSHA256.rawBytes,
                sourceBinding.buildProvenanceSHA256.rawBytes,
                sourceBinding.signedRuntimeBindingSHA256.rawBytes,
                data(UInt32(artifacts.count)), data(totalByteCount),
                try encodeEntries(artifacts),
            ], maximumByteCount: maximumByteCount
        )
    }

    private static func validateRoles(
        _ artifacts: [InvestigationMachineEvidenceArtifact],
        summary: InvestigationMachineAttemptSummary
    ) throws {
        let postArm: Set<InvestigationMachineEvidenceRole> = [
            .protocolReceipt, .diagnosticOutput, .epochL2Projection,
            .epochResidueProjection,
        ]
        for role in InvestigationMachineEvidenceRole.allCases {
            let count = artifacts.count { $0.role == role }
            if summary.consumed {
                let optionalPostArm = role == .protocolReceipt || role == .diagnosticOutput, prefixRole = role == .epochL2Projection || role == .epochResidueProjection
                if !optionalPostArm && !prefixRole && count == 0 {
                    throw InvestigationMachineEvidenceContractError.missingRole
                }
                guard optionalPostArm ? count <= 1 : role.admitsCardinality(count) else {
                    throw InvestigationMachineEvidenceContractError.duplicateRole
                }
            } else if role == .attemptEvent {
                guard count == 2 else {
                    throw InvestigationMachineEvidenceContractError.invalidTransition
                }
            } else if postArm.contains(role) {
                guard count == 0 else {
                    throw InvestigationMachineEvidenceContractError.invalidTransition
                }
            } else if count != 1 {
                throw InvestigationMachineEvidenceContractError.missingRole
            }
        }
        if summary.consumed {
            let l2 = artifacts.filter { $0.role == .epochL2Projection }, residue = artifacts.filter { $0.role == .epochResidueProjection }
            guard l2.count == residue.count, (0...8).contains(l2.count),
                  l2.enumerated().allSatisfy({ $0.element.path.leafName == String(format: "epoch-%02d-l2.json", $0.offset + 1) }),
                  residue.enumerated().allSatisfy({ $0.element.path.leafName == String(format: "epoch-%02d-residue.json", $0.offset + 1) })
            else { throw InvestigationMachineEvidenceContractError.invalidOrdering }
        }
        let eventArtifacts = artifacts.filter { $0.role == .attemptEvent }
        let expectedEventNames = (1...Int(summary.eventCount)).map {
            String(format: "attempt-event-%04d.bin", $0)
        }
        guard eventArtifacts.count == Int(summary.eventCount),
              eventArtifacts.map({ $0.path.leafName }) == expectedEventNames,
              eventArtifacts.last?.sha256 == summary.finalEventSHA256
        else { throw InvestigationMachineEvidenceContractError.invalidTransition }
    }

    private static func encodeEntries(
        _ artifacts: [InvestigationMachineEvidenceArtifact]
    ) throws -> Data {
        var result = Data()
        for artifact in artifacts {
            let entry = try HandoffBinaryTranscript.encode(
                domain: "stornaut.task39.iic.raw-evidence-entry.v1",
                businessFields: [
                    Data(artifact.path.relativeValue.utf8), data(artifact.path.phase.rawValue),
                    data(artifact.role.rawValue), data(artifact.encoding.rawValue),
                    data(artifact.byteCount), artifact.sha256.rawBytes,
                ], maximumByteCount: 512
            )
            result.append(data(UInt32(entry.count)))
            result.append(entry)
        }
        return result
    }

    private static func decodeEntries(
        _ bytes: Data, count: Int
    ) throws -> [InvestigationMachineEvidenceArtifact] {
        var cursor = EvidenceCursor(bytes), result: [InvestigationMachineEvidenceArtifact] = []
        for _ in 0..<count {
            let length = Int(try cursor.uint32())
            let encoded = try cursor.read(length)
            let fields = try HandoffBinaryTranscript.decode(
                encoded, expectedDomain: "stornaut.task39.iic.raw-evidence-entry.v1",
                expectedBusinessFieldByteCounts: [1...128, 4...4, 4...4, 4...4, 8...8, 32...32],
                maximumByteCount: 512
            )
            guard let phase = InvestigationMachineEvidencePhase(
                    rawValue: try decodeUInt32(fields[1])),
                  let role = InvestigationMachineEvidenceRole(
                    rawValue: try decodeUInt32(fields[2])),
                  let encoding = InvestigationMachineEvidenceEncoding(
                    rawValue: try decodeUInt32(fields[3]))
            else { throw InvestigationMachineEvidenceContractError.invalidEncoding }
            result.append(try .init(
                path: .init(relativeValue: try decodeString(fields[0])),
                role: role, encoding: encoding,
                byteCount: try decodeUInt64(fields[4]),
                sha256: .init(rawBytes: fields[5])
            ))
            guard result.last?.path.phase == phase else {
                throw InvestigationMachineEvidenceContractError.invalidEncoding
            }
        }
        guard cursor.isAtEnd else {
            throw InvestigationMachineEvidenceContractError.invalidEncoding
        }
        return result
    }

    private static func contentRoot(
        _ manifest: InvestigationHandoffSHA256
    ) throws -> InvestigationHandoffSHA256 {
        .hashing(try HandoffBinaryTranscript.encode(
            domain: "stornaut.task39.iic.raw-evidence-root.v1",
            businessFields: [manifest.rawBytes], maximumByteCount: 128
        ))
    }
}

package enum InvestigationMachineAttemptEventKind:
    UInt32, CaseIterable, Hashable, Sendable
{
    case prepared = 1
    case cancelledBeforeArm = 2
    case armedConsumed = 3
    case spawnObserved = 4
    case spawnUncertain = 5
    case terminal = 6
}

package struct InvestigationMachineAttemptEventV1: Equatable, Sendable {
    package static let domain = "stornaut.task39.iic.attempt-event.v1"
    package static let maximumByteCount = 4_608
    package static let maximumPayloadByteCount = 4_096
    package let sequence: UInt32
    package let attemptUUID: UUID
    package let kind: InvestigationMachineAttemptEventKind
    package let previousEventSHA256: InvestigationHandoffSHA256
    package let observedAt: InvestigationHandoffUTCMicroseconds
    package let payload: Data
    package let payloadSHA256: InvestigationHandoffSHA256

    package init(
        sequence: UInt32, attemptUUID: UUID,
        kind: InvestigationMachineAttemptEventKind,
        previousEventSHA256: InvestigationHandoffSHA256,
        observedAt: InvestigationHandoffUTCMicroseconds,
        payload: Data
    ) throws {
        guard sequence > 0, nonzero(attemptUUID), observedAt.rawValue > 0,
              (1...Self.maximumPayloadByteCount).contains(payload.count)
        else { throw InvestigationMachineEvidenceContractError.invalidEncoding }
        do {
            guard try canonicalJSONObject(payload) == payload else {
                throw InvestigationMachineEvidenceContractError.invalidEncoding
            }
            try InvestigationMachineEvidenceJSON.validateEvent(
                payload, kind: kind, attemptUUID: attemptUUID
            )
        } catch let error as InvestigationMachineEvidenceContractError {
            throw error
        } catch {
            throw InvestigationMachineEvidenceContractError.invalidEncoding
        }
        self.sequence = sequence
        self.attemptUUID = attemptUUID
        self.kind = kind
        self.previousEventSHA256 = previousEventSHA256
        self.observedAt = observedAt
        self.payload = payload
        payloadSHA256 = .hashing(payload)
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain, businessFields: [
                data(sequence), data(attemptUUID), data(kind.rawValue),
                previousEventSHA256.rawBytes,
                data(UInt64(bitPattern: observedAt.rawValue)),
                payload,
                payloadSHA256.rawBytes,
            ], maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(_ bytes: Data) throws -> Self {
        do {
            let fields = try HandoffBinaryTranscript.decode(
                bytes, expectedDomain: domain,
                expectedBusinessFieldByteCounts: [
                    4...4, 16...16, 4...4, 32...32, 8...8,
                    1...maximumPayloadByteCount, 32...32,
                ],
                maximumByteCount: maximumByteCount
            )
            guard let kind = InvestigationMachineAttemptEventKind(
                rawValue: try decodeUInt32(fields[2]))
            else { throw InvestigationMachineEvidenceContractError.invalidEncoding }
            let rawTime = Int64(bitPattern: try decodeUInt64(fields[4]))
            let value = try Self(
                sequence: try decodeUInt32(fields[0]),
                attemptUUID: try decodeUUID(fields[1]), kind: kind,
                previousEventSHA256: try .init(rawBytes: fields[3]),
                observedAt: try .init(rawValue: rawTime),
                payload: fields[5]
            )
            let encodedPayloadSHA256 = try InvestigationHandoffSHA256(
                rawBytes: fields[6]
            )
            guard value.payloadSHA256 == encodedPayloadSHA256,
                  try value.encoded() == bytes else {
                throw InvestigationMachineEvidenceContractError.invalidEncoding
            }
            return value
        } catch let error as InvestigationMachineEvidenceContractError { throw error }
        catch { throw InvestigationMachineEvidenceContractError.invalidEncoding }
    }
}

package enum InvestigationMachineEvidenceJSON {
    package static let schemaVersion = 1
    package static let prompt = "Stornaut Task 39 ii-c administrator authorization: "
    package static let scenarios = [
        "success", "cancellation", "timeout", "invalidEnvelope", "identityMismatch",
        "transportLoss", "lifecycleRecovery", "artifactCleanupFailure",
    ]
    package static func canonicalData(_ object: [String: Any]) throws -> Data {
        guard JSONSerialization.isValidJSONObject(object)
        else { throw InvestigationMachineEvidenceContractError.invalidEncoding }
        let data = try JSONSerialization.data(withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes])
        guard try canonicalJSONObject(data) == data
        else { throw InvestigationMachineEvidenceContractError.invalidEncoding }
        return data
    }
    package static func validateIfTyped(
        _ bytes: Data, role: InvestigationMachineEvidenceRole,
        path: InvestigationMachineEvidenceRelativePath,
        campaignUUID: UUID, attemptUUID: UUID,
        sourceBinding: InvestigationMachineCampaignSourceBinding
    ) throws {
        guard role.requiredEncoding == .strictJSON, path.phase == role.phase,
              role.admitsLeaf(path.leafName)
        else { throw invalid() }
        let object = try object(bytes)
        guard object["schemaVersion"] != nil || object["role"] != nil
        else { return }
        try validateObject(object, role: role, path: path,
            campaignUUID: campaignUUID, attemptUUID: attemptUUID,
            sourceBinding: sourceBinding)
    }
    package static func validate(
        _ bytes: Data, role: InvestigationMachineEvidenceRole,
        path: InvestigationMachineEvidenceRelativePath,
        campaignUUID: UUID, attemptUUID: UUID,
        sourceBinding: InvestigationMachineCampaignSourceBinding
    ) throws {
        try validateObject(object(bytes), role: role, path: path, campaignUUID: campaignUUID,
            attemptUUID: attemptUUID, sourceBinding: sourceBinding)
    }
    private static func validateObject(
        _ object: [String: Any], role: InvestigationMachineEvidenceRole,
        path: InvestigationMachineEvidenceRelativePath,
        campaignUUID: UUID, attemptUUID: UUID,
        sourceBinding: InvestigationMachineCampaignSourceBinding
    ) throws {
        try exactCommon(object, role: roleName(role), campaignUUID: campaignUUID,
            attemptUUID: attemptUUID)
        switch role {
        case .sourceBuildIdentity:
            try exact(object, commonKeys.union([
                "repositoryHEAD", "repositoryTree",
                "canonicalSourceManifestSHA256", "buildProvenanceSHA256",
                "signedRuntimeBindingSHA256", "preArmFrameSHA256",
            ]))
            guard string(object, "repositoryHEAD") == sourceBinding.repositoryHEAD,
                  string(object, "repositoryTree") == sourceBinding.repositoryTree,
                  digest(object, "canonicalSourceManifestSHA256")
                    == sourceBinding.canonicalSourceManifestSHA256.lowercaseHex,
                  digest(object, "buildProvenanceSHA256")
                    == sourceBinding.buildProvenanceSHA256.lowercaseHex,
                  digest(object, "signedRuntimeBindingSHA256")
                    == sourceBinding.signedRuntimeBindingSHA256.lowercaseHex,
                  digest(object, "preArmFrameSHA256") != nil
            else { throw invalid() }
        case .builtStagingInstalledIdentity:
            try exact(object, commonKeys.union([
                "buildProvenanceSHA256", "signedRuntimeBindingSHA256",
                "transactionReceiptSHA256", "builtIdentitySHA256",
                "stagingIdentitySHA256", "installedIdentitySHA256",
                "plistSHA256", "serviceLoaded", "appExecutableSHA256",
                "helperExecutableSHA256", "machineDriverExecutableSHA256",
                "gateExecutableSHA256", "coordinatorExecutableSHA256",
            ]))
            let built = digest(object, "builtIdentitySHA256")
            guard digest(object, "buildProvenanceSHA256")
                    == sourceBinding.buildProvenanceSHA256.lowercaseHex,
                  digest(object, "signedRuntimeBindingSHA256")
                    == sourceBinding.signedRuntimeBindingSHA256.lowercaseHex,
                  digest(object, "transactionReceiptSHA256") != nil,
                  built != nil, built == digest(object, "stagingIdentitySHA256"),
                  built == digest(object, "installedIdentitySHA256"),
                  digest(object, "plistSHA256") != nil,
                  ["appExecutableSHA256", "helperExecutableSHA256",
                   "machineDriverExecutableSHA256", "gateExecutableSHA256",
                   "coordinatorExecutableSHA256"].allSatisfy({
                    digest(object, $0) != nil
                  }),
                  boolean(object, "serviceLoaded") == true
            else { throw invalid() }
        case .policyProbe:
            try exact(object, commonKeys.union([
                "command", "exitStatus", "stdoutByteCount", "stdoutSHA256",
                "stderrByteCount", "stderrSHA256",
            ]))
            guard string(object, "command") == "/usr/bin/sudo -knv",
                  let status = integer(object, "exitStatus"), status != 0,
                  nonnegativeInteger(object, "stdoutByteCount") != nil,
                  digest(object, "stdoutSHA256") != nil,
                  nonnegativeInteger(object, "stderrByteCount") != nil,
                  digest(object, "stderrSHA256") != nil
            else { throw invalid() }
        case .humanPromptAttestation:
            try exact(object, commonKeys.union([
                "prompt", "machinePromptObserved", "attestationKind",
                "humanActionObserved", "credentialRetainedByteCount",
            ]))
            let kind = string(object, "attestationKind"),
                machineObserved = boolean(object, "machinePromptObserved"),
                humanObserved = boolean(object, "humanActionObserved")
            guard string(object, "prompt") == prompt,
                  integer(object, "credentialRetainedByteCount") == 0,
                  (kind == "trustedOperatorInteractiveAction"
                    && machineObserved == true && humanObserved == true
                    || kind == "operatorCancellationBeforeCredential"
                    && humanObserved == false)
            else { throw invalid() }
        case .noAuthModelNetworkCounters:
            try exact(object, commonKeys.union([
                "authInvocationCount", "modelInvocationCount",
                "networkInvocationCount", "credentialTranscriptByteCount",
            ]))
            guard ["authInvocationCount", "modelInvocationCount",
                   "networkInvocationCount", "credentialTranscriptByteCount"]
                .allSatisfy({ integer(object, $0) == 0 })
            else { throw invalid() }
        case .epochL2Projection:
            try exact(object, commonKeys.union([
                "ordinal", "scenario", "epochUUID", "configurationNonce",
                "configurationSHA256", "signedRuntimeBindingSHA256",
                "wholeProjectedInputSHA256", "projectionBase64",
                "projectionSHA256", "installedL2ProofBase64",
                "installedL2ProofSHA256", "claimEvidenceSHA256",
                "physicalOwnershipSHA256",
            ]))
            try validateEpoch(object, path: path, suffix: "-l2.json")
            guard let projectionText = string(object, "projectionBase64"),
                  let projectionBytes = Data(base64Encoded: projectionText),
                  let projection = try? InvestigationInstalledL2IdentityProjection
                    .decode(projectionBytes),
                  uuid(object, "epochUUID") == projection.epochUUID,
                  uuid(object, "configurationNonce")
                    == projection.configurationNonce,
                  digest(object, "configurationSHA256")
                    == projection.configurationSHA256.lowercaseHex,
                  digest(object, "signedRuntimeBindingSHA256")
                    == projection.signedRuntimeBindingSHA256.lowercaseHex,
                  projection.signedRuntimeBindingSHA256
                    == sourceBinding.signedRuntimeBindingSHA256,
                  digest(object, "wholeProjectedInputSHA256") != nil,
                  digest(object, "projectionSHA256")
                    == projection.projectionSHA256.lowercaseHex,
                  base64Digest(object, bytes: "installedL2ProofBase64",
                    digest: "installedL2ProofSHA256"),
                  digest(object, "claimEvidenceSHA256") != nil,
                  digest(object, "physicalOwnershipSHA256") != nil
            else { throw invalid() }
        case .epochResidueProjection:
            try exact(object, commonKeys.union([
                "ordinal", "scenario", "epochUUID", "l2ArtifactSHA256",
                "helperIdentitySHA256", "completionBindingSHA256",
                "terminalEvidenceBase64", "terminalEvidenceSHA256",
                "childCount", "descendantCount", "openChannelCount",
                "ownedProcessGroupMemberCount", "helperExitObserved",
                "artifactsRetired",
            ]))
            try validateEpoch(object, path: path, suffix: "-residue.json")
            guard digest(object, "l2ArtifactSHA256") != nil,
                  digest(object, "helperIdentitySHA256") != nil,
                  digest(object, "completionBindingSHA256") != nil,
                  base64Digest(object, bytes: "terminalEvidenceBase64",
                    digest: "terminalEvidenceSHA256"),
                  ["childCount", "descendantCount", "openChannelCount",
                   "ownedProcessGroupMemberCount"]
                    .allSatisfy({ integer(object, $0) == 0 }),
                  boolean(object, "helperExitObserved") == true,
                  boolean(object, "artifactsRetired") == true
            else { throw invalid() }
        case .uninstallEvidence:
            try exact(object, commonKeys.union([
                "transactionReceiptSHA256", "bootoutCompleted",
                "installedRootRemoved", "installedAppRemoved",
                "plistRemoved", "runtimeRootRemoved", "leaseRootRemoved",
                "installedIdentitySHA256", "plistSHA256",
                "appExecutableSHA256", "helperExecutableSHA256",
                "machineDriverExecutableSHA256", "gateExecutableSHA256",
                "coordinatorExecutableSHA256",
            ]))
            guard digest(object, "transactionReceiptSHA256") != nil,
                  ["installedIdentitySHA256", "plistSHA256",
                   "appExecutableSHA256", "helperExecutableSHA256",
                   "machineDriverExecutableSHA256", "gateExecutableSHA256",
                   "coordinatorExecutableSHA256"].allSatisfy({ digest(object, $0) != nil }),
                  ["bootoutCompleted", "installedRootRemoved",
                   "installedAppRemoved", "plistRemoved",
                   "runtimeRootRemoved", "leaseRootRemoved"]
                    .allSatisfy({ boolean(object, $0) == true })
            else { throw invalid() }
        case .globalPostTeardown:
            try exact(object, commonKeys.union([
                "observationReceiptSHA256", "appProcessCount",
                "helperProcessCount", "driverProcessCount", "gateProcessCount",
                "coordinatorProcessCount", "childCount", "descendantCount",
                "openChannelCount", "ownedProcessGroupMemberCount",
                "serviceAbsent", "gateOwnerLockRevalidated",
                "gateAttemptEntryCount", "gateCapsuleEntryCount",
            ]))
            guard digest(object, "observationReceiptSHA256") != nil,
                  ["appProcessCount", "helperProcessCount", "driverProcessCount",
                   "gateProcessCount", "coordinatorProcessCount", "childCount",
                   "descendantCount", "openChannelCount",
                   "ownedProcessGroupMemberCount", "gateAttemptEntryCount",
                   "gateCapsuleEntryCount"]
                    .allSatisfy({ integer(object, $0) == 0 }),
                  boolean(object, "serviceAbsent") == true,
                  boolean(object, "gateOwnerLockRevalidated") == true
            else { throw invalid() }
        case .verifierInput:
            try exact(object, commonKeys.union([
                "expectedConsumed", "expectedEpochCount", "evidenceSetSHA256",
                "verifierExecutableSHA256",
            ]))
            guard boolean(object, "expectedConsumed") != nil,
                  let count = integer(object, "expectedEpochCount"),
                  (0...8).contains(count),
                  digest(object, "evidenceSetSHA256") != nil,
                  digest(object, "verifierExecutableSHA256") != nil
            else { throw invalid() }
        case .protocolReceipt, .diagnosticOutput, .attemptEvent:
            throw invalid()
        }
    }

    package static func validateEventIfTyped(
        _ bytes: Data, kind: InvestigationMachineAttemptEventKind,
        attemptUUID: UUID
    ) throws {
        let object = try object(bytes)
        guard object["schemaVersion"] != nil || object["kind"] != nil else {
            return
        }
        try validateEventObject(object, kind: kind, attemptUUID: attemptUUID)
    }

    package static func validateEvent(
        _ bytes: Data, kind: InvestigationMachineAttemptEventKind,
        attemptUUID: UUID
    ) throws {
        try validateEventObject(
            object(bytes), kind: kind, attemptUUID: attemptUUID
        )
    }

    private static func validateEventObject(
        _ object: [String: Any], kind: InvestigationMachineAttemptEventKind,
        attemptUUID: UUID
    ) throws {
        let base: Set<String> = [
            "schemaVersion", "kind", "attemptUUID", "evidenceSetSHA256",
        ]
        let keys: Set<String> = switch kind {
        case .prepared, .armedConsumed, .terminal: base
        case .cancelledBeforeArm, .spawnUncertain: base.union(["reason"])
        case .spawnObserved:
            base.union(["processID", "processGroupID", "sessionID"])
        }
        try exact(object, keys)
        guard integer(object, "schemaVersion") == schemaVersion,
              string(object, "kind") == eventName(kind),
              uuid(object, "attemptUUID") == attemptUUID,
              digest(object, "evidenceSetSHA256") != nil
        else { throw invalid() }
        if kind == .spawnObserved {
            guard let pid = integer(object, "processID"), pid > 1,
                  integer(object, "processGroupID") == pid,
                  let sid = integer(object, "sessionID"), sid > 1
            else { throw invalid() }
        }
        if kind == .cancelledBeforeArm || kind == .spawnUncertain {
            guard let reason = string(object, "reason"), !reason.isEmpty,
                  reason.utf8.count <= 96 else { throw invalid() }
        }
    }

    private static let commonKeys: Set<String> = [
        "schemaVersion", "role", "campaignUUID", "attemptUUID",
    ]
    private static func object(_ data: Data) throws -> [String: Any] {
        guard try canonicalJSONObject(data) == data,
              let value = try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { throw invalid() }
        return value
    }
    private static func exactCommon(
        _ value: [String: Any], role: String, campaignUUID: UUID,
        attemptUUID: UUID
    ) throws {
        guard integer(value, "schemaVersion") == schemaVersion,
              string(value, "role") == role,
              uuid(value, "campaignUUID") == campaignUUID,
              uuid(value, "attemptUUID") == attemptUUID
        else { throw invalid() }
    }
    private static func exact(_ value: [String: Any], _ keys: Set<String>) throws {
        guard Set(value.keys) == keys else { throw invalid() }
    }
    private static func string(_ value: [String: Any], _ key: String) -> String? {
        value[key] as? String
    }
    private static func integer(_ value: [String: Any], _ key: String) -> Int? {
        guard let number = value[key] as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let result = number.intValue
        return NSNumber(value: result) == number ? result : nil
    }
    private static func nonnegativeInteger(
        _ value: [String: Any], _ key: String
    ) -> Int? { integer(value, key).flatMap { $0 >= 0 ? $0 : nil } }
    private static func boolean(_ value: [String: Any], _ key: String) -> Bool? {
        guard let number = value[key] as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }
    private static func uuid(_ value: [String: Any], _ key: String) -> UUID? {
        guard let text = string(value, key), text == text.lowercased(),
              let result = UUID(uuidString: text), nonzero(result)
        else { return nil }
        return result
    }
    private static func digest(_ value: [String: Any], _ key: String) -> String? {
        guard let text = string(value, key), validHex(text, count: 64)
        else { return nil }
        return text
    }
    private static func base64Digest(
        _ value: [String: Any], bytes: String, digest name: String
    ) -> Bool {
        guard let text = string(value, bytes), !text.isEmpty,
              let decoded = Data(base64Encoded: text), !decoded.isEmpty,
              digest(value, name) == InvestigationHandoffSHA256.hashing(decoded)
                .lowercaseHex else { return false }
        return true
    }
    private static func validateEpoch(
        _ value: [String: Any], path: InvestigationMachineEvidenceRelativePath,
        suffix: String
    ) throws {
        guard let ordinal = integer(value, "ordinal"), (1...8).contains(ordinal),
              path.leafName == String(format: "epoch-%02d%@", ordinal, suffix),
              string(value, "scenario") == scenarios[ordinal - 1],
              uuid(value, "epochUUID") != nil
        else { throw invalid() }
    }
    private static func roleName(_ role: InvestigationMachineEvidenceRole) -> String {
        switch role {
        case .sourceBuildIdentity: "sourceBuildIdentity"
        case .builtStagingInstalledIdentity: "builtStagingInstalledIdentity"
        case .policyProbe: "policyProbe"
        case .humanPromptAttestation: "humanPromptAttestation"
        case .noAuthModelNetworkCounters: "noAuthModelNetworkCounters"
        case .protocolReceipt: "protocolReceipt"
        case .diagnosticOutput: "diagnosticOutput"
        case .epochL2Projection: "epochL2Projection"
        case .epochResidueProjection: "epochResidueProjection"
        case .uninstallEvidence: "uninstallEvidence"
        case .globalPostTeardown: "globalPostTeardown"
        case .verifierInput: "verifierInput"
        case .attemptEvent: "attemptEvent"
        }
    }
    private static func eventName(_ kind: InvestigationMachineAttemptEventKind) -> String {
        switch kind {
        case .prepared: "prepared"
        case .cancelledBeforeArm: "cancelledBeforeArm"
        case .armedConsumed: "armedConsumed"
        case .spawnObserved: "spawnObserved"
        case .spawnUncertain: "spawnUncertain"
        case .terminal: "terminal"
        }
    }
    private static func invalid() -> InvestigationMachineEvidenceContractError {
        .invalidEncoding
    }
}

package enum InvestigationMachineAttemptEventChain {
    package static func summary(
        _ events: [InvestigationMachineAttemptEventV1],
        mode: InvestigationMachineAttemptMode
    ) throws -> InvestigationMachineAttemptSummary {
        try validateComplete(events, mode: mode)
        guard let last = events.last else {
            throw InvestigationMachineEvidenceContractError.invalidTransition
        }
        let outcome: InvestigationMachineAttemptOutcome = switch last.kind {
        case .cancelledBeforeArm: .cancelledBeforeArm
        case .terminal where events.dropLast().last?.kind == .spawnObserved: .spawnObservedTerminal
        case .terminal where events.dropLast().last?.kind == .spawnUncertain: .spawnUncertainTerminal
        case .spawnUncertain: .transportLoss
        default: throw InvestigationMachineEvidenceContractError.invalidTransition
        }
        return try .init(
            attemptUUID: last.attemptUUID, mode: mode, outcome: outcome,
            consumed: outcome != .cancelledBeforeArm,
            eventCount: UInt32(events.count),
            finalEventSHA256: .hashing(try last.encoded())
        )
    }

    package static func validatePrefix(
        _ events: [InvestigationMachineAttemptEventV1],
        mode: InvestigationMachineAttemptMode
    ) throws {
        try validateLinks(events)
        let kinds = events.map(\.kind)
        let admitted: [[InvestigationMachineAttemptEventKind]] = switch mode {
        case .dryRun:
            [[], [.prepared], [.prepared, .cancelledBeforeArm]]
        case .privileged:
            [
                [], [.prepared], [.prepared, .cancelledBeforeArm],
                [.prepared, .armedConsumed],
                [.prepared, .armedConsumed, .spawnObserved],
                [.prepared, .armedConsumed, .spawnUncertain],
                [.prepared, .armedConsumed, .spawnObserved, .terminal],
                [.prepared, .armedConsumed, .spawnUncertain, .terminal],
            ]
        }
        guard admitted.contains(kinds) else {
            throw InvestigationMachineEvidenceContractError.invalidTransition
        }
    }

    package static func validateComplete(
        _ events: [InvestigationMachineAttemptEventV1],
        mode: InvestigationMachineAttemptMode
    ) throws {
        try validatePrefix(events, mode: mode)
        let kinds = events.map(\.kind)
        let complete: [[InvestigationMachineAttemptEventKind]] = switch mode {
        case .dryRun: [[.prepared, .cancelledBeforeArm]]
        case .privileged: [
            [.prepared, .cancelledBeforeArm],
            [.prepared, .armedConsumed, .spawnObserved, .terminal],
            [.prepared, .armedConsumed, .spawnUncertain, .terminal],
            [.prepared, .armedConsumed, .spawnUncertain],
        ]
        }
        guard complete.contains(kinds) else {
            throw InvestigationMachineEvidenceContractError.invalidTransition
        }
    }

    private static func validateLinks(
        _ events: [InvestigationMachineAttemptEventV1]
    ) throws {
        guard !events.isEmpty else { return }
        guard let first = events.first, first.sequence == 1,
              first.kind == .prepared, first.previousEventSHA256.rawBytes
                == Data(repeating: 0, count: InvestigationHandoffSHA256.byteCount)
        else { throw InvestigationMachineEvidenceContractError.invalidTransition }
        for index in events.indices.dropFirst() {
            let current = events[index], previous = events[index - 1]
            guard current.sequence == previous.sequence + 1,
                  current.attemptUUID == first.attemptUUID,
                  current.observedAt > previous.observedAt,
                  current.previousEventSHA256 == .hashing(try previous.encoded())
            else { throw InvestigationMachineEvidenceContractError.invalidTransition }
        }
    }
}

package enum InvestigationMachineCoordinatorRawWait:
    Equatable, Sendable
{
    case exited(status: Int32)
    case signaled(signal: Int32)
    case stopped(signal: Int32)
}

package struct InvestigationMachineCoordinatorRawNode:
    Equatable, Sendable
{
    package let device, inode, generation: UInt64
    package let size: Int64
    package init(device: UInt64, inode: UInt64, generation: UInt64, size: Int64) {
        self.device = device; self.inode = inode; self.generation = generation
        self.size = size
    }
}

package struct InvestigationMachineCoordinatorRawReceiptV1:
    Equatable, Sendable
{
    package static let domain = "stornaut.task39.machine.gate-coordinator-receipt.v1"
    package static let maximumByteCount = 4_096
    package let buildProvenanceSHA256: String
    package let signedBindingSHA256: InvestigationHandoffSHA256
    package let outerAttemptUUID: UUID
    package let wholeProjectedInputSHA256: InvestigationHandoffSHA256
    package let capsule: InvestigationMachineCoordinatorRawNode
    package let gateExecutableSHA256: InvestigationHandoffSHA256
    package let gateTransportReceiptSHA256: InvestigationHandoffSHA256
    package let gateProcessID, gateProcessGroupID, gateSessionID: pid_t
    package let exactGateWaitClassification: InvestigationMachineCoordinatorRawWait
    package let receiptReachedEOF, receiptOverflowObserved: Bool
    package let receiptDeadlineExpired, capsuleSettlementRemoved: Bool
    package let attemptBaseRetired, runtimeArtifactsRetired: Bool
    package let monotonicStartedNanoseconds, monotonicCompletedNanoseconds: UInt64
    package private(set) var receiptSHA256: InvestigationHandoffSHA256

    package init(
        buildProvenanceSHA256: String,
        signedBindingSHA256: InvestigationHandoffSHA256, outerAttemptUUID: UUID,
        wholeProjectedInputSHA256: InvestigationHandoffSHA256,
        capsule: InvestigationMachineCoordinatorRawNode,
        gateExecutableSHA256: InvestigationHandoffSHA256,
        gateTransportReceiptSHA256: InvestigationHandoffSHA256,
        gateProcessID: pid_t, gateProcessGroupID: pid_t, gateSessionID: pid_t,
        exactGateWaitClassification: InvestigationMachineCoordinatorRawWait,
        receiptReachedEOF: Bool, receiptOverflowObserved: Bool,
        receiptDeadlineExpired: Bool, capsuleSettlementRemoved: Bool,
        attemptBaseRetired: Bool, runtimeArtifactsRetired: Bool,
        monotonicStartedNanoseconds: UInt64, monotonicCompletedNanoseconds: UInt64
    ) throws {
        guard validHex(buildProvenanceSHA256, count: 64), nonzero(outerAttemptUUID),
              [signedBindingSHA256, wholeProjectedInputSHA256, gateExecutableSHA256,
               gateTransportReceiptSHA256].allSatisfy({ $0.rawBytes.contains { $0 != 0 } }),
              capsule.device > 0, capsule.inode > 0,
              (1...Int64(InvestigationProjectedCohortInput.maximumByteCount))
                .contains(capsule.size),
              gateProcessID > 1, gateProcessGroupID == gateProcessID,
              gateSessionID > 1, gateSessionID != gateProcessGroupID,
              exactGateWaitClassification == .exited(status: 0),
              receiptReachedEOF, !receiptOverflowObserved, !receiptDeadlineExpired,
              capsuleSettlementRemoved, attemptBaseRetired, runtimeArtifactsRetired,
              monotonicStartedNanoseconds > 0,
              monotonicCompletedNanoseconds > monotonicStartedNanoseconds
        else { throw InvestigationMachineEvidenceContractError.invalidEncoding }
        self.buildProvenanceSHA256 = buildProvenanceSHA256
        self.signedBindingSHA256 = signedBindingSHA256
        self.outerAttemptUUID = outerAttemptUUID
        self.wholeProjectedInputSHA256 = wholeProjectedInputSHA256
        self.capsule = capsule
        self.gateExecutableSHA256 = gateExecutableSHA256
        self.gateTransportReceiptSHA256 = gateTransportReceiptSHA256
        self.gateProcessID = gateProcessID
        self.gateProcessGroupID = gateProcessGroupID
        self.gateSessionID = gateSessionID
        self.exactGateWaitClassification = exactGateWaitClassification
        self.receiptReachedEOF = receiptReachedEOF
        self.receiptOverflowObserved = receiptOverflowObserved
        self.receiptDeadlineExpired = receiptDeadlineExpired
        self.capsuleSettlementRemoved = capsuleSettlementRemoved
        self.attemptBaseRetired = attemptBaseRetired
        self.runtimeArtifactsRetired = runtimeArtifactsRetired
        self.monotonicStartedNanoseconds = monotonicStartedNanoseconds
        self.monotonicCompletedNanoseconds = monotonicCompletedNanoseconds
        receiptSHA256 = try zeroDigest()
        receiptSHA256 = .hashing(try transcript(receiptSHA256: receiptSHA256))
    }

    package func encoded() throws -> Data {
        guard .hashing(try transcript(receiptSHA256: zeroDigest())) == receiptSHA256
        else { throw InvestigationMachineEvidenceContractError.invalidEncoding }
        return try transcript(receiptSHA256: receiptSHA256)
    }

    package static func decodeFrame(
        _ frame: Data, reachedEOF: Bool
    ) throws -> Self {
        guard reachedEOF else { throw InvestigationMachineEvidenceContractError.incompleteInput }
        guard frame.count >= 4 else { throw InvestigationMachineEvidenceContractError.incompleteInput }
        let declared = Int(try decodeUInt32(Data(frame.prefix(4))))
        guard (1...maximumByteCount).contains(declared) else {
            throw InvestigationMachineEvidenceContractError.sizeLimitExceeded
        }
        guard frame.count == declared + 4 else {
            throw InvestigationMachineEvidenceContractError.invalidEncoding
        }
        return try decode(Data(frame.dropFirst(4)))
    }

    package static func decode(_ bytes: Data) throws -> Self {
        do {
            let fields = try HandoffBinaryTranscript.decode(
                bytes, expectedDomain: domain, expectedBusinessFieldByteCounts: [
                    64...64, 32...32, 16...16, 32...32, 8...8, 8...8, 8...8,
                    8...8, 32...32, 32...32, 4...4, 4...4, 4...4, 5...5,
                    1...1, 1...1, 1...1, 1...1, 1...1, 1...1, 8...8, 8...8, 32...32,
                ], maximumByteCount: maximumByteCount
            )
            let value = try Self(
                buildProvenanceSHA256: try decodeString(fields[0]),
                signedBindingSHA256: try .init(rawBytes: fields[1]),
                outerAttemptUUID: try decodeUUID(fields[2]),
                wholeProjectedInputSHA256: try .init(rawBytes: fields[3]),
                capsule: .init(
                    device: try decodeUInt64(fields[4]), inode: try decodeUInt64(fields[5]),
                    generation: try decodeUInt64(fields[6]),
                    size: Int64(bitPattern: try decodeUInt64(fields[7]))),
                gateExecutableSHA256: try .init(rawBytes: fields[8]),
                gateTransportReceiptSHA256: try .init(rawBytes: fields[9]),
                gateProcessID: try decodePID(fields[10]),
                gateProcessGroupID: try decodePID(fields[11]),
                gateSessionID: try decodePID(fields[12]),
                exactGateWaitClassification: try decodeWait(fields[13]),
                receiptReachedEOF: try decodeBool(fields[14]),
                receiptOverflowObserved: try decodeBool(fields[15]),
                receiptDeadlineExpired: try decodeBool(fields[16]),
                capsuleSettlementRemoved: try decodeBool(fields[17]),
                attemptBaseRetired: try decodeBool(fields[18]),
                runtimeArtifactsRetired: try decodeBool(fields[19]),
                monotonicStartedNanoseconds: try decodeUInt64(fields[20]),
                monotonicCompletedNanoseconds: try decodeUInt64(fields[21])
            )
            let encodedSHA256 = try InvestigationHandoffSHA256(
                rawBytes: fields[22]
            )
            guard value.receiptSHA256 == encodedSHA256,
                  try value.encoded() == bytes
            else { throw InvestigationMachineEvidenceContractError.invalidEncoding }
            return value
        } catch let error as InvestigationMachineEvidenceContractError { throw error }
        catch { throw InvestigationMachineEvidenceContractError.invalidEncoding }
    }

    private func transcript(
        receiptSHA256: InvestigationHandoffSHA256
    ) throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain, businessFields: [
                Data(buildProvenanceSHA256.utf8), signedBindingSHA256.rawBytes,
                data(outerAttemptUUID), wholeProjectedInputSHA256.rawBytes,
                data(capsule.device), data(capsule.inode), data(capsule.generation),
                data(UInt64(bitPattern: capsule.size)), gateExecutableSHA256.rawBytes,
                gateTransportReceiptSHA256.rawBytes, data(gateProcessID),
                data(gateProcessGroupID), data(gateSessionID), data(exactGateWaitClassification),
                data(receiptReachedEOF), data(receiptOverflowObserved),
                data(receiptDeadlineExpired), data(capsuleSettlementRemoved),
                data(attemptBaseRetired), data(runtimeArtifactsRetired),
                data(monotonicStartedNanoseconds), data(monotonicCompletedNanoseconds),
                receiptSHA256.rawBytes,
            ], maximumByteCount: Self.maximumByteCount
        )
    }
}

package struct InvestigationMachineCampaignVerifiedEpoch:
    Sendable, Equatable
{
    package let ordinal: UInt32
    package let scenario: InvestigationHandoffScenario
    package let epochUUID: UUID
    package let configurationNonce: UUID
    package let installedL2ProofBytes: Data
    package let claimEvidenceSHA256: InvestigationHandoffSHA256
    package let physicalOwnershipSHA256: InvestigationHandoffSHA256
    package let helperIdentitySHA256: InvestigationHandoffSHA256
    package let completionBindingSHA256: InvestigationHandoffSHA256
    package let outerDriverProcessID: UInt32
    package let terminalEvidenceBytes: Data
    package let admissionSHA256: InvestigationHandoffSHA256

    fileprivate let helperIdentity: InvestigationMachineProcessIdentity
    fileprivate let requestPredecessorSHA256: InvestigationHandoffSHA256
}

package struct InvestigationMachineCampaignVerifiedBundle:
    Sendable, Equatable
{
    package let bytes: Data
    package let epochs: [InvestigationMachineCampaignVerifiedEpoch]
    package let completionBytes: Data
}

package enum InvestigationMachineCampaignEpochEvidenceValidator {
    private static let epochMaximumByteCount = 256 * 1_024
    package static let bundleMaximumByteCount = 3 * 1_024 * 1_024

    private struct Request {
        let deadline: UInt64
        let mode: UInt8
        let predecessorSHA256: InvestigationHandoffSHA256
    }
    private struct Ownership {
        let appIdentity: InvestigationMachineProcessIdentity
        let helperIdentity: InvestigationMachineProcessIdentity
        let claimSHA256: InvestigationHandoffSHA256
        let proofBytes: Data
        let bindingSHA256: InvestigationHandoffSHA256
        let installedL2ObservedAtNanoseconds: UInt64
    }
    private struct Result {
        let completionBindingSHA256: InvestigationHandoffSHA256
        let driverObservationSHA256: InvestigationHandoffSHA256
    }

    package static func validate(
        bundle: Data, projectedInput: InvestigationProjectedCohortInput
    ) throws -> InvestigationMachineCampaignVerifiedBundle {
        let fields = try evidenceDecode(
            bundle, domain: "stornaut.task39.machine.driver-evidence-bundle.v1",
            ranges: [16...16, 32...32, 32...32, 4...4]
                + Array(repeating: 1...epochMaximumByteCount, count: 8),
            maximum: bundleMaximumByteCount)
        guard
            try decodeUUID(fields[0]) == projectedInput.capsule.outerAttemptUUID,
            try InvestigationHandoffSHA256(rawBytes: fields[1])
                == projectedInput.capsule.wholeCapsuleSHA256,
            try InvestigationHandoffSHA256(rawBytes: fields[2])
                == projectedInput.wholeInputSHA256,
            try decodeUInt32(fields[3]) == 8
        else { throw evidenceInvalid() }

        var epochs: [InvestigationMachineCampaignVerifiedEpoch] = []
        for index in 0..<InvestigationCohortCapsule.epochCount {
            epochs.append(try validateEpoch(
                fields[index + 4], index: index,
                projectedInput: projectedInput,
                previous: epochs.last))
        }
        guard Set(epochs.map(\.outerDriverProcessID)).count == 1 else {
            throw evidenceInvalid()
        }
        let zero = Data(repeating: 0, count: 32)
        let completionFields = [
            fields[0], fields[1], fields[2], fields[3],
            InvestigationHandoffSHA256.hashing(bundle).rawBytes,
        ]
        let unsigned = try HandoffBinaryTranscript.encode(
            domain: "stornaut.task39.machine.driver-completion-v2",
            businessFields: completionFields + [zero], maximumByteCount: 512)
        let completion = try HandoffBinaryTranscript.encode(
            domain: "stornaut.task39.machine.driver-completion-v2",
            businessFields: completionFields
                + [InvestigationHandoffSHA256.hashing(unsigned).rawBytes],
            maximumByteCount: 512)
        return .init(bytes: bundle, epochs: epochs, completionBytes: completion)
    }

    private static func validateEpoch(
        _ bytes: Data, index: Int,
        projectedInput: InvestigationProjectedCohortInput,
        previous: InvestigationMachineCampaignVerifiedEpoch?
    ) throws -> InvestigationMachineCampaignVerifiedEpoch {
        let row = try evidenceDecode(
            bytes, domain: "stornaut.task39.machine.epoch-evidence.v1",
            ranges: [
                4...4, 4...4, 16...16, 16...16, 1...(128 << 10),
                1...(64 << 10), 1...2_048, 1...(50 << 10), 32...32,
            ], maximum: epochMaximumByteCount)
        let selection = try projectedInput.selection(at: index)
        guard
            try decodeUInt32(row[0]) == UInt32(index),
            try decodeUInt32(row[1]) == selection.epoch.scenario.rawValue,
            try decodeUUID(row[2]) == selection.epoch.epochUUID,
            try decodeUUID(row[3]) == selection.epoch.configurationNonce
        else { throw evidenceInvalid() }
        let request = try parseRequest(
            row[4], selection: selection, projectedInput: projectedInput,
            previous: previous)
        let normal = request.mode == 1
        let physical = try evidenceDecode(
            row[5], domain:
                "stornaut.task39.machine.epoch-physical-evidence.v1",
            ranges: normal
                ? [1...(32 << 10), 1...(48 << 10)]
                : [1...(32 << 10)],
            maximum: 64 << 10)
        let ownership = try parseOwnership(
            physical[0], selection: selection, projectedInput: projectedInput,
            deadline: request.deadline)
        if let previous {
            guard ownership.helperIdentity != previous.helperIdentity else {
                throw evidenceInvalid()
            }
        }
        let material = try parseAdmissionMaterial(
            row[7], requestBytes: row[4], physicalOwnershipBytes: physical[0],
            expectedAppIdentity: ownership.appIdentity,
            expectedMode: request.mode)
        let result = normal ? try parseNormalResult(
            physical[1], requestBytes: row[4], material: material,
            physicalOwnershipBytes: physical[0], ownership: ownership) : nil
        try validateTerminal(
            row[6], material: material,
            helperIdentity: ownership.helperIdentity, normal: normal,
            driverObservationSHA256: result?.driverObservationSHA256,
            installedL2ObservedAtNanoseconds:
                ownership.installedL2ObservedAtNanoseconds,
            deadline: request.deadline)
        let admission = try HandoffBinaryTranscript.encode(
            domain: "stornaut.task39.machine.outer-inner.admission",
            businessFields: [
                row[4], material.ownershipRecordBytes,
                material.acknowledgementBytes, material.decisionBytes,
                InvestigationHandoffSHA256.hashing(
                    normal ? physical[1] : Data()).rawBytes,
                InvestigationHandoffSHA256.hashing(row[6]).rawBytes,
                material.ownerBytes,
            ], maximumByteCount: 192 << 10)
        let admissionSHA256 = try InvestigationHandoffSHA256(rawBytes: row[8])
        guard admissionSHA256 == .hashing(admission) else { throw evidenceInvalid() }
        return .init(
            ordinal: UInt32(index), scenario: selection.epoch.scenario,
            epochUUID: selection.epoch.epochUUID,
            configurationNonce: selection.epoch.configurationNonce,
            installedL2ProofBytes: ownership.proofBytes,
            claimEvidenceSHA256: ownership.claimSHA256,
            physicalOwnershipSHA256: .hashing(physical[0]),
            helperIdentitySHA256: try ownership.helperIdentity.helperIdentitySHA256(),
            completionBindingSHA256:
                result?.completionBindingSHA256 ?? ownership.bindingSHA256,
            outerDriverProcessID: material.driverChild.parentProcessID,
            terminalEvidenceBytes: row[6], admissionSHA256: admissionSHA256,
            helperIdentity: ownership.helperIdentity,
            requestPredecessorSHA256: request.predecessorSHA256)
    }

    private struct AdmissionMaterial {
        let ownershipRecordBytes: Data
        let ownershipRecord: [Data]
        let driverChild: DriverChild
        let appChild: AppChild
        let acknowledgementBytes: Data
        let decisionBytes: Data
        let ownerBytes: Data
    }
    private struct DriverChild: Equatable {
        let processID: UInt32
        let processIDVersion: UInt32
        let parentProcessID: UInt32
        let processGroupID: UInt32
        let auditSessionID: UInt32
        let effectiveUserID: UInt32
        let auditTokenWords: [UInt32]
    }
    private struct AppChild: Equatable {
        let identity: InvestigationMachineProcessIdentity
        let parentProcessID: UInt32
        let processGroupID: UInt32
    }

    private static func parseRequest(
        _ bytes: Data, selection: InvestigationProjectedCohortSelection,
        projectedInput: InvestigationProjectedCohortInput,
        previous: InvestigationMachineCampaignVerifiedEpoch?
    ) throws -> Request {
        let fields = try evidenceDecode(bytes, domain:
            "stornaut.task39.machine.outer-inner.epoch-request", ranges:
            [1...(96<<10),32...32,8...8,1...1], maximum:128<<10)
        let mode: UInt8 = selection.epoch.scenario == .lifecycleRecovery ? 2 : 1
        guard fields[1] == InvestigationHandoffSHA256.hashing(fields[0]).rawBytes,
            fields[3] == Data([mode]), try decodeUInt64(fields[2]) > 0
        else { throw evidenceInvalid() }
        let successor = selection.epoch.ordinal > 0
        let invocation = try evidenceDecode(fields[0], domain: successor
            ? "stornaut.task39.machine.epoch-invocation.successor"
            : "stornaut.task39.machine.epoch-invocation.genesis", ranges:
            [16...16,32...32,32...32,1...66_048,1...2_048,1...8_192,32...32]
                + (successor ? [1...InvestigationMachineProcessIdentity.maximumByteCount] : []),
            maximum:96<<10)
        guard try decodeUUID(invocation[0]) == projectedInput.capsule.outerAttemptUUID,
            try InvestigationHandoffSHA256(rawBytes: invocation[1])
                == projectedInput.capsule.wholeCapsuleSHA256,
            try InvestigationHandoffSHA256(rawBytes: invocation[2])
                == projectedInput.wholeInputSHA256,
            try InvestigationCohortEpoch.decode(invocation[3]) == selection.epoch,
            try InvestigationInstalledL2IdentityProjection.decode(invocation[4])
                == selection.projection,
            invocation[6] == InvestigationHandoffSHA256.hashing(invocation[5]).rawBytes
        else { throw evidenceInvalid() }
        let predecessorSHA256 = try InvestigationHandoffSHA256(rawBytes: invocation[6])
        if let previous {
            let helper = try InvestigationMachineProcessIdentity.decode(invocation[7])
            let predecessor = try evidenceDecode(invocation[5], domain:
                "stornaut.task39.machine.helper-continuity.successor", ranges:
                [16...16,32...32,32...32,4...4,16...16,1...1_024,
                 32...32,32...32,32...32,1...1], maximum:4_096)
            guard helper.role == .helper,
                try helper.helperIdentitySHA256() == previous.helperIdentitySHA256,
                try decodeUUID(predecessor[0]) == projectedInput.capsule.outerAttemptUUID,
                try InvestigationHandoffSHA256(rawBytes: predecessor[1])
                    == projectedInput.capsule.wholeCapsuleSHA256,
                try InvestigationHandoffSHA256(rawBytes: predecessor[2])
                    == projectedInput.wholeInputSHA256,
                try decodeUInt32(predecessor[3]) == selection.epoch.ordinal - 1,
                try decodeUUID(predecessor[4]) == previous.epochUUID,
                predecessor[5] == (try helper.encoded()),
                try InvestigationHandoffSHA256(rawBytes: predecessor[6])
                    == previous.requestPredecessorSHA256,
                try InvestigationHandoffSHA256(rawBytes: predecessor[7])
                    == previous.completionBindingSHA256,
                try InvestigationHandoffSHA256(rawBytes: predecessor[8])
                    == previous.admissionSHA256,
                predecessor[9] == Data([
                    previous.scenario == .lifecycleRecovery ? 2 : 1])
            else { throw evidenceInvalid() }
        } else {
            let predecessor = try evidenceDecode(invocation[5], domain:
                "stornaut.task39.machine.helper-continuity.genesis", ranges:
                [16...16,32...32,32...32,4...4,16...16], maximum:512)
            guard !successor, try decodeUUID(predecessor[0])
                    == projectedInput.capsule.outerAttemptUUID,
                try InvestigationHandoffSHA256(rawBytes: predecessor[1])
                    == projectedInput.capsule.wholeCapsuleSHA256,
                try InvestigationHandoffSHA256(rawBytes: predecessor[2])
                    == projectedInput.wholeInputSHA256,
                try decodeUInt32(predecessor[3]) == 0,
                try decodeUUID(predecessor[4]) == selection.epoch.epochUUID
            else { throw evidenceInvalid() }
        }
        return .init(deadline: try decodeUInt64(fields[2]), mode: mode,
            predecessorSHA256: predecessorSHA256)
    }

    private static func parseOwnership(
        _ bytes: Data, selection: InvestigationProjectedCohortSelection,
        projectedInput: InvestigationProjectedCohortInput, deadline: UInt64
    ) throws -> Ownership {
        let fields = try evidenceDecode(bytes, domain:
            "stornaut.task39.machine.physical-ownership.evidence-v1", ranges:
            [16...16,32...32,32...32,16...16,4...4,4...4,32...32,
             1...4_096,1...4_096,1...4_096,32...32,32...32,1...16_384,
             8...8,8...8,32...32], maximum:32<<10)
        let app = try InvestigationMachineProcessIdentity.decode(fields[7])
        let helper = try InvestigationMachineProcessIdentity.decode(fields[8])
        let claim = try InvestigationMachineClaimEvidence.decode(fields[9])
        let claimSHA = InvestigationHandoffSHA256.hashing(fields[9])
        let proofSHA = InvestigationHandoffSHA256.hashing(fields[12])
        guard try decodeUUID(fields[0])
                == projectedInput.capsule.outerAttemptUUID,
            try InvestigationHandoffSHA256(rawBytes: fields[1])
                == projectedInput.capsule.wholeCapsuleSHA256,
            try InvestigationHandoffSHA256(rawBytes: fields[2])
                == projectedInput.wholeInputSHA256,
            try decodeUUID(fields[3]) == selection.epoch.epochUUID,
            try decodeUInt32(fields[4]) == selection.epoch.ordinal,
            try decodeUInt32(fields[5]) == selection.epoch.scenario.rawValue,
            try InvestigationHandoffSHA256(rawBytes: fields[6])
                == selection.projection.projectionSHA256,
            try app.encoded() == fields[7], try helper.encoded() == fields[8],
            try claim.encoded() == fields[9],
            app.role == .app, helper.role == .helper, app != helper,
            app.processID != helper.processID,
            claim.requestBindingSHA256.rawBytes.contains(where: { $0 != 0 }),
            claim.appIdentity == app, claim.helperIdentity == helper,
            claim.l1Residue.investigationUUID == selection.epoch.configurationNonce,
            claim.l1Residue.auditSessionID == helper.auditSessionID,
            claim.l1Residue.userID == 501,
            try InvestigationHandoffSHA256(rawBytes: fields[10]) == claimSHA,
            try InvestigationHandoffSHA256(rawBytes: fields[11]) == proofSHA,
            try decodeUInt64(fields[13]) == claim.releaseDeadlineNanoseconds,
            try decodeUInt64(fields[14]) == deadline,
            claim.releaseDeadlineNanoseconds <= deadline
        else { throw evidenceInvalid() }
        let installedL2ObservedAtNanoseconds = try validateInstalledL2(
            fields[12], selection: selection, claim: claim,
            app: app, helper: helper, deadline: deadline)
        let bindingFields = [
            fields[0], fields[1], fields[2], fields[3], fields[4], fields[5],
            data(selection.epoch.configurationNonce),
            selection.epoch.configurationSHA256.rawBytes,
            selection.epoch.signedRuntimeBindingSHA256.rawBytes, fields[6],
            fields[7], fields[8], fields[9], fields[10], fields[11],
            fields[13], fields[14],
        ]
        guard try InvestigationHandoffSHA256(rawBytes: fields[15]) == .hashing(
            HandoffBinaryTranscript.encode(domain:
                "stornaut.task39.machine.single-epoch.ownership",
                businessFields: bindingFields, maximumByteCount:8_192))
        else { throw evidenceInvalid() }
        return .init(appIdentity: app, helperIdentity: helper, claimSHA256: claimSHA,
            proofBytes: fields[12],
            bindingSHA256: try InvestigationHandoffSHA256(rawBytes: fields[15]),
            installedL2ObservedAtNanoseconds:
                installedL2ObservedAtNanoseconds)
    }

    private static func parseAdmissionMaterial(
        _ bytes: Data, requestBytes: Data, physicalOwnershipBytes: Data,
        expectedAppIdentity: InvestigationMachineProcessIdentity,
        expectedMode: UInt8
    ) throws -> AdmissionMaterial {
        let fields = try evidenceDecode(bytes, domain:
            "stornaut.task39.machine.outer-inner.admission-material",
            ranges:[1...(48<<10),1...512,1...512,16...16], maximum:50<<10)
        guard fields[3].contains(where: { $0 != 0 }) else { throw evidenceInvalid() }
        let ownership = try evidenceDecode(fields[0], domain:
            "stornaut.task39.machine.outer-inner.ownership-record", ranges:
            [32...32,1...1_024,1...2_048,1...(32<<10),32...32], maximum:48<<10)
        let requestSHA = InvestigationHandoffSHA256.hashing(requestBytes)
        let ownershipSHA = InvestigationHandoffSHA256.hashing(fields[0])
        let driverChild = try parseDriverChild(ownership[1])
        let appChild = try parseAppChild(ownership[2])
        guard ownership[0] == requestSHA.rawBytes,
            ownership[3] == physicalOwnershipBytes,
            ownership[4] == InvestigationHandoffSHA256.hashing(
                physicalOwnershipBytes).rawBytes,
            appChild.identity == expectedAppIdentity,
            appChild.parentProcessID == driverChild.processID,
            appChild.processGroupID == driverChild.processGroupID
        else { throw evidenceInvalid() }
        let acknowledgement = try evidenceDecode(fields[1], domain:
            "stornaut.task39.machine.outer-inner.acknowledgement",
            ranges:[32...32,32...32,32...32], maximum:512)
        guard acknowledgement == [requestSHA.rawBytes, ownershipSHA.rawBytes,
            InvestigationHandoffSHA256.hashing(physicalOwnershipBytes).rawBytes]
        else { throw evidenceInvalid() }
        let decision = try evidenceDecode(fields[2], domain:
            "stornaut.task39.machine.outer-inner.decision",
            ranges:[32...32,32...32,32...32,1...1], maximum:512)
        guard decision == [requestSHA.rawBytes, ownershipSHA.rawBytes,
            InvestigationHandoffSHA256.hashing(fields[1]).rawBytes,
            Data([expectedMode == 1 ? 1 : 2])]
        else { throw evidenceInvalid() }
        return .init(ownershipRecordBytes: fields[0], ownershipRecord: ownership,
            driverChild: driverChild, appChild: appChild,
            acknowledgementBytes: fields[1], decisionBytes: fields[2],
            ownerBytes: fields[3])
    }

    private static func parseDriverChild(_ bytes: Data) throws -> DriverChild {
        let fields = try evidenceDecode(bytes, domain:
            "stornaut.task39.machine.outer-inner.driver-child", ranges:
            [4...4,4...4,4...4,4...4,4...4,4...4,32...32], maximum:1_024)
        let words = try decodeUInt32Words(fields[6], expectedCount: 8)
        let value = DriverChild(
            processID: try decodeUInt32(fields[0]),
            processIDVersion: try decodeUInt32(fields[1]),
            parentProcessID: try decodeUInt32(fields[2]),
            processGroupID: try decodeUInt32(fields[3]),
            auditSessionID: try decodeUInt32(fields[4]),
            effectiveUserID: try decodeUInt32(fields[5]),
            auditTokenWords: words)
        guard value.processID > 1, value.processIDVersion > 0,
            value.parentProcessID > 1,
            value.processGroupID == value.processID,
            value.auditSessionID > 0, value.effectiveUserID == 0,
            words[1] == value.effectiveUserID, words[2] == 0,
            words[3] == 0, words[4] == 0,
            words[5] == value.processID,
            words[6] == value.auditSessionID,
            words[7] == value.processIDVersion
        else { throw evidenceInvalid() }
        return value
    }

    private static func parseAppChild(_ bytes: Data) throws -> AppChild {
        let fields = try evidenceDecode(bytes, domain:
            "stornaut.task39.machine.outer-inner.app-child", ranges:
            [1...InvestigationMachineProcessIdentity.maximumByteCount,4...4,4...4],
            maximum:2_048)
        let value = AppChild(
            identity: try InvestigationMachineProcessIdentity.decode(fields[0]),
            parentProcessID: try decodeUInt32(fields[1]),
            processGroupID: try decodeUInt32(fields[2]))
        guard value.identity.role == .app, value.parentProcessID > 1,
            value.processGroupID > 1,
            try value.identity.encoded() == fields[0]
        else { throw evidenceInvalid() }
        return value
    }

    private static func parseNormalResult(
        _ bytes: Data, requestBytes: Data, material: AdmissionMaterial,
        physicalOwnershipBytes: Data, ownership: Ownership
    ) throws -> Result {
        let fields = try evidenceDecode(bytes, domain:
            "stornaut.task39.machine.outer-inner.normal-result", ranges:
            [32...32,32...32,32...32,32...32,1...(48<<10),32...32],
            maximum:48<<10)
        let completion = try evidenceDecode(fields[4], domain:
            "stornaut.task39.machine.physical-completion.evidence-v1", ranges:
            [1...(32<<10),32...32,32...32,32...32], maximum:48<<10)
        let completionBinding = InvestigationHandoffSHA256.hashing(
            try HandoffBinaryTranscript.encode(domain:
                "stornaut.task39.machine.single-epoch.local-completion",
                businessFields:[ownership.bindingSHA256.rawBytes,completion[1],
                    completion[2],Data([1])], maximumByteCount:2_048))
        guard fields[0] == InvestigationHandoffSHA256.hashing(requestBytes).rawBytes,
            fields[1] == InvestigationHandoffSHA256.hashing(
                material.ownershipRecordBytes).rawBytes,
            fields[2] == InvestigationHandoffSHA256.hashing(
                material.acknowledgementBytes).rawBytes,
            fields[3] == InvestigationHandoffSHA256.hashing(
                material.decisionBytes).rawBytes,
            fields[5] == InvestigationHandoffSHA256.hashing(fields[4]).rawBytes,
            completion[0] == physicalOwnershipBytes,
            completion[3] == completionBinding.rawBytes,
            completion[1].contains(where: { $0 != 0 }),
            completion[2].contains(where: { $0 != 0 })
        else { throw evidenceInvalid() }
        return .init(completionBindingSHA256: completionBinding,
            driverObservationSHA256: try InvestigationHandoffSHA256(
                rawBytes: completion[2]))
    }

    private static func validateTerminal(
        _ bytes: Data, material: AdmissionMaterial,
        helperIdentity: InvestigationMachineProcessIdentity, normal: Bool,
        driverObservationSHA256: InvestigationHandoffSHA256?,
        installedL2ObservedAtNanoseconds: UInt64, deadline: UInt64
    ) throws {
        let fields = try evidenceDecode(bytes, domain:
            "stornaut.task39.machine.outer-inner.terminal-evidence", ranges:
            [1...1,1...1,1...1_024,1...2_048,1...1_024,1...1,1...1,
             1...1,1...1,1...1,1...1,32...32,32...32,8...8],maximum:2_048)
        let helper = try InvestigationMachineProcessIdentity.decode(fields[4])
        let absenceIndexes = [0, 1, 6, 7, 8, 9, 10]
        let allAbsent = try absenceIndexes.allSatisfy({
            try decodeBool(fields[$0])
        })
        let driverChild = try parseDriverChild(fields[2])
        let appChild = try parseAppChild(fields[3])
        guard driverChild == material.driverChild, appChild == material.appChild,
            helper == helperIdentity,
            allAbsent,
            try decodeBool(fields[5]) == normal, fields[11] == fields[12],
            fields[11].contains(where: { $0 != 0 }),
            try decodeUInt64(fields[13]) > 0,
            try installedL2ObservedAtNanoseconds <= decodeUInt64(fields[13]),
            try decodeUInt64(fields[13]) < deadline,
            !normal || fields[11] == driverObservationSHA256?.rawBytes
        else { throw evidenceInvalid() }
    }

    private static func validateInstalledL2(
        _ bytes: Data, selection: InvestigationProjectedCohortSelection,
        claim: InvestigationMachineClaimEvidence,
        app: InvestigationMachineProcessIdentity,
        helper: InvestigationMachineProcessIdentity, deadline: UInt64
    ) throws -> UInt64 {
        let fields = try evidenceDecode(bytes, domain:
            "stornaut.task39.machine.single-epoch.installed-l2-proof", ranges:
            [32...32,32...32,16...16,16...16,8...8,1...1_024,32...32,
             1...1_024,1...1_024,1...1_024,32...32,1...1_024,1...1_024,
             32...32,1...1_024,1...1_024,1...2_048,8...8,8...8,8...8,8...8,
             1...1_024,8...8], maximum:16_384)
        let repeatedApp = try InvestigationMachineProcessIdentity.decode(fields[21])
        let service = fields[16]
        let appStatic = try parseSigning(fields[7])
        let appLive = try parseSigning(fields[8])
        let helperStatic = try parseSigning(fields[11])
        let helperLive = try parseSigning(fields[12])
        let driverStatic = try parseSigning(fields[14])
        let driverLive = try parseSigning(fields[15])
        let artifactStates = Array(fields[4])
        guard fields[0] == selection.projection.projectionSHA256.rawBytes,
            fields[1] == InvestigationHandoffSHA256.hashing(
                try claim.encoded()).rawBytes,
            try decodeUUID(fields[2]) == selection.epoch.epochUUID,
            try decodeUUID(fields[3]) == selection.epoch.configurationNonce,
            artifactStates.count == 8,
            artifactStates.prefix(6).allSatisfy({ $0 == 2 }),
            artifactStates.suffix(2).allSatisfy({ $0 == 1 || $0 == 2 }),
            fields[5] == (try app.encoded()), fields[9] == (try helper.encoded()),
            fields[6] == selection.projection.appExecutableSHA256.rawBytes,
            fields[10] == selection.projection.helperExecutableSHA256.rawBytes,
            fields[13] == selection.projection.machineDriverExecutableSHA256.rawBytes,
            appStatic == appLive, helperStatic == helperLive,
            driverStatic == driverLive,
            appStatic.identifier == selection.projection.appBundleIdentifier,
            helperStatic.identifier
                == selection.projection.helperServiceIdentifier + ".helper",
            driverStatic.identifier
                == selection.projection.machineDriverSigningIdentifier,
            driverStatic.requirementSHA256
                == selection.projection.machineDriverDesignatedRequirementSHA256,
            driverStatic.codeDirectoryHash
                == selection.projection.machineDriverCodeDirectoryHash,
            driverStatic.isAdHoc, service == Data([2]) + (try helper.encoded()),
            claim.claimedAt.rawValue <= Int64(bitPattern: try decodeUInt64(fields[17])),
            try decodeUInt64(fields[17]) <= decodeUInt64(fields[19]),
            try decodeUInt64(fields[18]) > 0,
            try decodeUInt64(fields[20]) > 0,
            try decodeUInt64(fields[18]) <= decodeUInt64(fields[20]),
            try decodeUInt64(fields[20]) < claim.releaseDeadlineNanoseconds,
            Int64(bitPattern: try decodeUInt64(fields[19]))
                < selection.projection.configurationValidBefore.rawValue,
            repeatedApp == app, try decodeUInt64(fields[22]) == deadline
        else { throw evidenceInvalid() }
        return try decodeUInt64(fields[20])
    }

    private struct Signing: Equatable {
        let identifier: String
        let requirementSHA256: InvestigationHandoffSHA256
        let codeDirectoryHash: Data
        let isAdHoc: Bool
    }

    private static func parseSigning(_ bytes: Data) throws -> Signing {
        let fields = try evidenceDecode(bytes, domain:
            "stornaut.task39.machine.single-epoch.installed-l2-signing",
            ranges:[1...256,32...32,20...32,1...1], maximum:1_024)
        let identifier = try decodeString(fields[0])
        let allowed = identifier.unicodeScalars.allSatisfy { scalar in
            (0x30...0x39).contains(scalar.value)
                || (0x41...0x5a).contains(scalar.value)
                || (0x61...0x7a).contains(scalar.value)
                || scalar.value == 0x2d || scalar.value == 0x2e
                || scalar.value == 0x5f
        }
        guard !identifier.isEmpty, allowed,
            fields[2].count == 20 || fields[2].count == 32
        else { throw evidenceInvalid() }
        return .init(identifier: identifier,
            requirementSHA256: try .init(rawBytes: fields[1]),
            codeDirectoryHash: fields[2], isAdHoc: try decodeBool(fields[3]))
    }

    private static func evidenceDecode(_ bytes: Data, domain: String,
        ranges: [ClosedRange<Int>], maximum: Int) throws -> [Data] {
        do {
            let fields = try HandoffBinaryTranscript.decode(bytes,
                expectedDomain: domain, expectedBusinessFieldByteCounts: ranges,
                maximumByteCount: maximum)
            guard try HandoffBinaryTranscript.encode(
                domain: domain, businessFields: fields,
                maximumByteCount: maximum) == bytes else { throw evidenceInvalid() }
            return fields
        } catch { throw evidenceInvalid() }
    }

    private static func evidenceInvalid()
        -> InvestigationMachineEvidenceContractError { .invalidEncoding }
}

package struct InvestigationMachineCampaignVerifiedGateReceipt:
    Sendable, Equatable
{
    package let launcherExecutableSHA256: InvestigationHandoffSHA256
    package let outerAttemptUUID: UUID
    package let wholeInputSHA256: InvestigationHandoffSHA256
    package let preparedFrameSHA256: InvestigationHandoffSHA256
    package let outputByteCount: Int
    package let outputSHA256: InvestigationHandoffSHA256
}

package enum InvestigationMachineCampaignRawGateReceiptValidator {
    package static func validate(
        _ bytes: Data, expectedAttemptUUID: UUID,
        expectedWholeInputSHA256: InvestigationHandoffSHA256,
        expectedOuterIdentity: InvestigationMachineCampaignOuterIdentity,
        finalReceipt: InvestigationMachineCoordinatorRawReceiptV1
    ) throws -> InvestigationMachineCampaignVerifiedGateReceipt {
        guard bytes.count == 422 else { throw campaignEvidenceInvalid() }
        var cursor = EvidenceCursor(bytes)
        guard try cursor.uint32() == 0x5354_4e47,
            try cursor.uint16() == 1, try cursor.uint8() == 2,
            try cursor.uint8() == 2, try cursor.uint32() == 410
        else { throw campaignEvidenceInvalid() }
        let launcher = try InvestigationHandoffSHA256(rawBytes: cursor.read(32))
        let attempt = try decodeUUID(cursor.read(16))
        let whole = try InvestigationHandoffSHA256(rawBytes: cursor.read(32))
        let prepared = try InvestigationHandoffSHA256(rawBytes: cursor.read(32))
        let capsule = (try cursor.uint64(), try cursor.uint64(),
            try cursor.uint64(), try cursor.int64())
        let gatePID = try cursor.pid(), coordinatorPID = try cursor.pid()
        let sessionID = try cursor.pid(), recoveryPGID = try cursor.pid()
        let savedPGID = try cursor.pid()
        let child = (try cursor.pid(), try cursor.pid(), try cursor.pid(),
            try cursor.pid(), try cursor.uint64(), try cursor.uint64())
        let input = (try cursor.uint64(), try cursor.uint64(),
            try cursor.uint64(), try cursor.int64(), try cursor.int64(),
            try cursor.int64(), try cursor.boolean(),
            try InvestigationHandoffSHA256(rawBytes: cursor.read(32)))
        let initialTTY = (try cursor.uint64(), try cursor.uint64(), try cursor.pid())
        let childTTY = (try cursor.uint64(), try cursor.uint64(), try cursor.pid())
        let finalTTY = (try cursor.uint64(), try cursor.uint64(), try cursor.pid())
        let outputCount = Int(try cursor.uint32())
        let outputSHA = try InvestigationHandoffSHA256(rawBytes: cursor.read(32))
        let overflow = try cursor.boolean(), eof = try cursor.boolean()
        let expired = try cursor.boolean(), wait = try cursor.read(5)
        let forwarded = try cursor.uint32(), started = try cursor.uint64()
        let completed = try cursor.uint64(), progression = try cursor.uint8()
        let groupEmpty = try cursor.boolean(), childReaped = try cursor.boolean()
        let restored = try cursor.boolean(), borrowed = try cursor.read(5)
        let preparedDeadline = started.addingReportingOverflow(
            1_200_000_000_000)
        guard !preparedDeadline.overflow else {
            throw campaignEvidenceInvalid()
        }
        let preparedFrame = try encodeRawGatePreparedFrame(
            gateProcessID: gatePID, coordinatorProcessID: coordinatorPID,
            sessionID: sessionID, child: child, recoveryProcessGroupID: recoveryPGID,
            savedForegroundProcessGroupID: savedPGID, attemptUUID: attempt,
            wholeInputSHA256: whole, capsule: capsule, terminal: initialTTY,
            absoluteDeadlineNanoseconds: preparedDeadline.partialValue)
        guard cursor.isAtEnd, launcher.rawBytes.contains(where:{$0 != 0}),
            attempt == expectedAttemptUUID,
            attempt == finalReceipt.outerAttemptUUID,
            whole == expectedWholeInputSHA256,
            whole == finalReceipt.wholeProjectedInputSHA256,
            launcher == finalReceipt.gateExecutableSHA256,
            InvestigationHandoffSHA256.hashing(bytes)
                == finalReceipt.gateTransportReceiptSHA256,
            prepared == .hashing(preparedFrame),
            capsule.0 > 0, capsule.1 > 0,
            (1...Int64(InvestigationProjectedCohortInput.maximumByteCount))
                .contains(capsule.3),
            capsule.0 == finalReceipt.capsule.device,
            capsule.1 == finalReceipt.capsule.inode,
            capsule.2 == finalReceipt.capsule.generation,
            capsule.3 == finalReceipt.capsule.size,
            gatePID == finalReceipt.gateProcessID,
            coordinatorPID > 1, coordinatorPID == sessionID,
            coordinatorPID == expectedOuterIdentity.processID,
            sessionID == expectedOuterIdentity.sessionID,
            recoveryPGID == gatePID,
            recoveryPGID == finalReceipt.gateProcessGroupID,
            savedPGID == sessionID, savedPGID == finalReceipt.gateSessionID,
            savedPGID == expectedOuterIdentity.processGroupID,
            savedPGID > 1, savedPGID != recoveryPGID,
            child.0 > 1, child.1 == gatePID, child.2 == recoveryPGID,
            child.0 != child.2, child.3 == sessionID, child.4 > 0,
            child.5 < 1_000_000,
            input.0 == capsule.0, input.1 == capsule.1, input.2 == capsule.2,
            input.3 == capsule.3, input.4 == 0, input.5 == capsule.3,
            input.6, input.7 == whole,
            initialTTY.0 > 0, initialTTY.1 > 0, initialTTY.2 == savedPGID,
            childTTY.0 == initialTTY.0, childTTY.1 == initialTTY.1,
            childTTY.2 == recoveryPGID, finalTTY.0 == initialTTY.0,
            finalTTY.1 == initialTTY.1, finalTTY.2 == savedPGID,
            (0...512).contains(outputCount),
            outputSHA.rawBytes.contains(where: { $0 != 0 }),
            !overflow, eof, !expired,
            wait == Data([1,0,0,0,0]), forwarded == 0, started > 0,
            finalReceipt.monotonicStartedNanoseconds < started,
            completed < finalReceipt.monotonicCompletedNanoseconds,
            completed >= started, completed - started <= 1_200_000_000_000,
            progression == 1, groupEmpty, childReaped, restored,
            borrowed == Data([1,0,0,0,0])
        else { throw campaignEvidenceInvalid() }
        return .init(launcherExecutableSHA256: launcher,
            outerAttemptUUID: attempt, wholeInputSHA256: whole,
            preparedFrameSHA256: prepared,
            outputByteCount: outputCount,
            outputSHA256: outputSHA)
    }

    private static func encodeRawGatePreparedFrame(
        gateProcessID: pid_t, coordinatorProcessID: pid_t, sessionID: pid_t,
        child: (pid_t, pid_t, pid_t, pid_t, UInt64, UInt64),
        recoveryProcessGroupID: pid_t, savedForegroundProcessGroupID: pid_t,
        attemptUUID: UUID, wholeInputSHA256: InvestigationHandoffSHA256,
        capsule: (UInt64, UInt64, UInt64, Int64),
        terminal: (UInt64, UInt64, pid_t),
        absoluteDeadlineNanoseconds: UInt64
    ) throws -> Data {
        var payload = Data()
        for process in [gateProcessID, coordinatorProcessID, sessionID, child.0,
            recoveryProcessGroupID, savedForegroundProcessGroupID, child.1, child.3] {
            payload.append(data(process))
        }
        payload.append(data(child.4)); payload.append(data(child.5))
        payload.append(data(UInt32(0x7f))); payload.append(data(attemptUUID))
        payload.append(wholeInputSHA256.rawBytes)
        payload.append(data(capsule.0)); payload.append(data(capsule.1))
        payload.append(data(capsule.2))
        payload.append(data(UInt64(bitPattern: capsule.3)))
        payload.append(data(terminal.0)); payload.append(data(terminal.1))
        payload.append(data(terminal.2)); payload.append(data(absoluteDeadlineNanoseconds))
        guard payload.count == 160 else { throw campaignEvidenceInvalid() }
        var frame = Data()
        frame.append(data(UInt32(0x5354_4e47)))
        frame.append(Data([0, 1, 1, 1]))
        frame.append(data(UInt32(payload.count)))
        frame.append(payload)
        return frame
    }
}

private struct EvidenceCursor {
    private let bytes: Data
    private var offset = 0
    init(_ bytes: Data) { self.bytes = bytes }
    var isAtEnd: Bool { offset == bytes.count }
    mutating func read(_ count: Int) throws -> Data {
        guard count >= 0, offset <= bytes.count, count <= bytes.count - offset
        else { throw InvestigationMachineEvidenceContractError.incompleteInput }
        defer { offset += count }
        return bytes.subdata(in: offset..<(offset + count))
    }
    mutating func uint8() throws -> UInt8 {
        let value = try read(1)
        guard let byte = value.first else { throw campaignEvidenceInvalid() }
        return byte
    }
    mutating func uint16() throws -> UInt16 {
        try read(2).reduce(UInt16(0)) { ($0 << 8) | UInt16($1) }
    }
    mutating func uint32() throws -> UInt32 { try decodeUInt32(read(4)) }
    mutating func uint64() throws -> UInt64 { try decodeUInt64(read(8)) }
    mutating func int64() throws -> Int64 { Int64(bitPattern: try uint64()) }
    mutating func pid() throws -> pid_t { Int32(bitPattern: try uint32()) }
    mutating func boolean() throws -> Bool { try decodeBool(read(1)) }
}

private func asciiAlphanumeric(_ byte: UInt8) -> Bool {
    (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte)
        || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
}
private func campaignEvidenceInvalid()
    -> InvestigationMachineEvidenceContractError { .invalidEncoding }
private func validHex(_ value: String, count: Int) -> Bool {
    let bytes = Array(value.utf8)
    return bytes.count == count && bytes.contains { $0 != UInt8(ascii: "0") }
        && bytes.allSatisfy {
            (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0)
                || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains($0)
        }
}
private func nonzero(_ value: UUID) -> Bool {
    var raw = value.uuid
    return withUnsafeBytes(of: &raw) { $0.contains { $0 != 0 } }
}
private func data(_ value: UInt32) -> Data {
    Data([UInt8(value >> 24), UInt8(truncatingIfNeeded: value >> 16),
          UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)])
}
private func data(_ value: UInt64) -> Data {
    Data((0..<8).map { UInt8(truncatingIfNeeded: value >> UInt64(56 - 8 * $0)) })
}
private func data(_ value: UUID) -> Data {
    var raw = value.uuid
    return withUnsafeBytes(of: &raw) { Data($0) }
}
private func data(_ value: Bool) -> Data { Data([value ? 1 : 0]) }
private func data(_ value: pid_t) -> Data { data(UInt32(bitPattern: value)) }
private func data(_ value: InvestigationMachineCoordinatorRawWait) -> Data {
    switch value {
    case .exited(let status): data(UInt8(1)) + data(status)
    case .signaled(let signal): data(UInt8(2)) + data(signal)
    case .stopped(let signal): data(UInt8(3)) + data(signal)
    }
}
private func data(_ value: UInt8) -> Data { Data([value]) }
private func decodeString(_ bytes: Data) throws -> String {
    guard let value = String(data: bytes, encoding: .utf8), Data(value.utf8) == bytes
    else { throw InvestigationMachineEvidenceContractError.invalidEncoding }
    return value
}
private func decodeUInt32(_ bytes: Data) throws -> UInt32 {
    guard bytes.count == 4 else { throw InvestigationMachineEvidenceContractError.invalidEncoding }
    return bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
}
private func decodeUInt32Words(
    _ bytes: Data, expectedCount: Int
) throws -> [UInt32] {
    guard bytes.count == expectedCount * MemoryLayout<UInt32>.size else {
        throw InvestigationMachineEvidenceContractError.invalidEncoding
    }
    return try stride(from: 0, to: bytes.count, by: 4).map { offset in
        try decodeUInt32(bytes.subdata(in: offset..<(offset + 4)))
    }
}
private func decodeUInt64(_ bytes: Data) throws -> UInt64 {
    guard bytes.count == 8 else { throw InvestigationMachineEvidenceContractError.invalidEncoding }
    return bytes.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
}
private func decodeUUID(_ bytes: Data) throws -> UUID {
    guard bytes.count == 16 else { throw InvestigationMachineEvidenceContractError.invalidEncoding }
    let b = Array(bytes)
    return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                       b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
}
private func decodeBool(_ bytes: Data) throws -> Bool {
    guard bytes.count == 1 else { throw InvestigationMachineEvidenceContractError.invalidEncoding }
    switch bytes[bytes.startIndex] {
    case 0: return false
    case 1: return true
    default: throw InvestigationMachineEvidenceContractError.invalidEncoding
    }
}
private func decodePID(_ bytes: Data) throws -> pid_t {
    Int32(bitPattern: try decodeUInt32(bytes))
}
private func decodeWait(_ bytes: Data) throws -> InvestigationMachineCoordinatorRawWait {
    guard bytes.count == 5 else { throw InvestigationMachineEvidenceContractError.invalidEncoding }
    let value = Int32(bitPattern: try decodeUInt32(Data(bytes.dropFirst())))
    switch bytes[bytes.startIndex] {
    case 1: return .exited(status: value)
    case 2: return .signaled(signal: value)
    case 3: return .stopped(signal: value)
    default: throw InvestigationMachineEvidenceContractError.invalidEncoding
    }
}
private func zeroDigest() throws -> InvestigationHandoffSHA256 {
    try .init(rawBytes: Data(repeating: 0, count: InvestigationHandoffSHA256.byteCount))
}
private func canonicalJSONObject(_ bytes: Data) throws -> Data {
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
#endif
