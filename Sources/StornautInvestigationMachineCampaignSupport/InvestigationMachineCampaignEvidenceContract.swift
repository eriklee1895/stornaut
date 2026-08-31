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
        case .epochL2Projection, .epochResidueProjection: count == 8
        case .attemptEvent: count == 2 || count == 4
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
        case (.privileged, .spawnObservedTerminal),
             (.privileged, .spawnUncertainTerminal): consumed && eventCount == 4
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
                guard count > 0 else {
                    throw InvestigationMachineEvidenceContractError.missingRole
                }
                guard role.admitsCardinality(count) else {
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
        case .terminal where events.dropLast().last?.kind == .spawnObserved:
            .spawnObservedTerminal
        case .terminal where events.dropLast().last?.kind == .spawnUncertain:
            .spawnUncertainTerminal
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
    mutating func uint32() throws -> UInt32 { try decodeUInt32(read(4)) }
}

private func asciiAlphanumeric(_ byte: UInt8) -> Bool {
    (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte)
        || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
}
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
