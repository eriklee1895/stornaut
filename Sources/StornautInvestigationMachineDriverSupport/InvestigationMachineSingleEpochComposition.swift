import Foundation
import StornautInvestigationHandoffContract
import StornautInvestigationInstalledL2

package struct InvestigationMachineSingleEpochOwnershipCandidate:
    Sendable,
    Equatable
{
    static let domain =
        "stornaut.task39.machine.single-epoch.ownership"
    static let maximumByteCount = 8_192

    let outerAttemptUUID: UUID
    let wholeCapsuleSHA256: InvestigationHandoffSHA256
    let wholeInputSHA256: InvestigationHandoffSHA256
    let epochUUID: UUID
    let configurationNonce: UUID
    let ordinal: UInt32
    let scenario: InvestigationHandoffScenario
    let projectionSHA256: InvestigationHandoffSHA256
    let appIdentity: InvestigationMachineProcessIdentity
    let helperIdentity: InvestigationMachineProcessIdentity
    let claimRequestBindingSHA256: InvestigationHandoffSHA256
    let claimConnectionEpoch: UUID
    let claimEvidenceSHA256: InvestigationHandoffSHA256
    let installedL2ProofBytes: Data
    let installedL2ProofSHA256: InvestigationHandoffSHA256
    let releaseDeadlineNanoseconds: UInt64
    let epochDeadlineNanoseconds: UInt64
    let bindingSHA256: InvestigationHandoffSHA256

    private let installedL2Proof:
        InvestigationMachineSingleEpochInstalledL2Proof
    let claimEvidence: InvestigationMachineClaimEvidence

    init(
        commitment: InvestigationMachineSingleEpochCommitment,
        appIdentity: InvestigationMachineProcessIdentity,
        claimEvidence: InvestigationMachineClaimEvidence,
        semanticObservation: InvestigationInstalledL2SemanticObservation,
        repeatedAppIdentity: InvestigationMachineProcessIdentity,
        installedL2Proof: InvestigationMachineSingleEpochInstalledL2Proof,
        epochDeadlineNanoseconds: UInt64
    ) throws {
        let epoch = commitment.epoch
        let projection = commitment.projection
        guard
            commitment.outerAttemptUUID != UUID(
                uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
            ),
            commitment.wholeCapsuleSHA256.rawBytes.contains(
                where: { $0 != 0 }
            ),
            commitment.wholeInputSHA256.rawBytes.contains(
                where: { $0 != 0 }
            ),
            projection.epochUUID == epoch.epochUUID,
            projection.configurationNonce == epoch.configurationNonce,
            projection.configurationSHA256 == epoch.configurationSHA256,
            projection.signedRuntimeBindingSHA256
                == epoch.signedRuntimeBindingSHA256,
            claimEvidence.appIdentity == appIdentity,
            claimEvidence.helperIdentity.role == .helper,
            claimEvidence.l1Residue.investigationUUID
                == epoch.configurationNonce,
            claimEvidence.l1Residue.auditSessionID
                == claimEvidence.helperIdentity.auditSessionID,
            claimEvidence.l1Residue.userID == appIdentity.effectiveUserID,
            claimEvidence.l1Residue.remainingAuditSessionMembers == 0,
            claimEvidence.l1Residue.matchingLeases == 0,
            claimEvidence.l1Residue.leaseRootEntries == 0,
            claimEvidence.l1Residue.investigationArtifacts == 0,
            claimEvidence.releaseDeadlineNanoseconds > 0,
            claimEvidence.releaseDeadlineNanoseconds
                <= epochDeadlineNanoseconds
        else {
            throw InvestigationMachineSingleEpochError.installedL2Failed
        }
        let validatedSemantic: InvestigationInstalledL2SemanticObservation
        do {
            validatedSemantic = try InvestigationInstalledL2SemanticContract
                .evaluate(
                    projection: projection,
                    artifacts: semanticObservation.artifacts,
                    app: semanticObservation.app,
                    helper: semanticObservation.helper,
                    machineDriver: semanticObservation.machineDriver,
                    service: semanticObservation.service,
                    started: semanticObservation.started,
                    observed: semanticObservation.observed
                )
        } catch {
            throw InvestigationMachineSingleEpochError.installedL2Failed
        }
        guard
            validatedSemantic == semanticObservation,
            semanticObservation.appIdentity == appIdentity,
            semanticObservation.helperIdentity
                == claimEvidence.helperIdentity,
            repeatedAppIdentity == appIdentity
        else {
            throw InvestigationMachineSingleEpochError.installedL2Failed
        }
        let claimEvidenceBytes = try claimEvidence.encoded()
        let claimEvidenceSHA256 = InvestigationHandoffSHA256.hashing(
            claimEvidenceBytes
        )
        let installedL2ProofBytes = try Self.installedL2ProofBytes(
            projection: projection, claimEvidence: claimEvidence,
            semanticObservation: semanticObservation,
            repeatedAppIdentity: repeatedAppIdentity,
            epochDeadlineNanoseconds: epochDeadlineNanoseconds
        )
        let installedL2ProofSHA256 = InvestigationHandoffSHA256.hashing(
            installedL2ProofBytes
        )
        let bindingSHA256 = InvestigationHandoffSHA256.hashing(
            try HandoffBinaryTranscript.encode(
                domain: Self.domain,
                businessFields: [
                    singleEpochData(commitment.outerAttemptUUID),
                    commitment.wholeCapsuleSHA256.rawBytes,
                    commitment.wholeInputSHA256.rawBytes,
                    singleEpochData(epoch.epochUUID),
                    singleEpochData(epoch.ordinal),
                    singleEpochData(epoch.scenario.rawValue),
                    singleEpochData(epoch.configurationNonce),
                    epoch.configurationSHA256.rawBytes,
                    epoch.signedRuntimeBindingSHA256.rawBytes,
                    projection.projectionSHA256.rawBytes,
                    try appIdentity.encoded(),
                    try claimEvidence.helperIdentity.encoded(),
                    claimEvidenceBytes,
                    claimEvidenceSHA256.rawBytes,
                    installedL2ProofSHA256.rawBytes,
                    singleEpochData(
                        claimEvidence.releaseDeadlineNanoseconds
                    ),
                    singleEpochData(epochDeadlineNanoseconds),
                ],
                maximumByteCount: Self.maximumByteCount
            )
        )
        outerAttemptUUID = commitment.outerAttemptUUID
        wholeCapsuleSHA256 = commitment.wholeCapsuleSHA256
        wholeInputSHA256 = commitment.wholeInputSHA256
        epochUUID = epoch.epochUUID
        configurationNonce = epoch.configurationNonce
        ordinal = epoch.ordinal
        scenario = epoch.scenario
        projectionSHA256 = projection.projectionSHA256
        self.appIdentity = appIdentity
        helperIdentity = claimEvidence.helperIdentity
        claimRequestBindingSHA256 = claimEvidence.requestBindingSHA256
        claimConnectionEpoch = claimEvidence.claimConnectionEpoch
        self.claimEvidence = claimEvidence
        self.claimEvidenceSHA256 = claimEvidenceSHA256
        self.installedL2ProofBytes = installedL2ProofBytes
        self.installedL2ProofSHA256 = installedL2ProofSHA256
        releaseDeadlineNanoseconds =
            claimEvidence.releaseDeadlineNanoseconds
        self.epochDeadlineNanoseconds = epochDeadlineNanoseconds
        self.bindingSHA256 = bindingSHA256
        self.installedL2Proof = installedL2Proof
    }

    private static func installedL2ProofBytes(
        projection: InvestigationInstalledL2IdentityProjection,
        claimEvidence: InvestigationMachineClaimEvidence,
        semanticObservation: InvestigationInstalledL2SemanticObservation,
        repeatedAppIdentity: InvestigationMachineProcessIdentity,
        epochDeadlineNanoseconds: UInt64
    ) throws -> Data {
        let artifactBytes = Data(
            InvestigationInstalledL2ArtifactRole.allCases.map { role in
                switch semanticObservation.artifacts[role] {
                case .absent: UInt8(0x01)
                case .presentValid: UInt8(0x02)
                case .invalid: UInt8(0x03)
                case .unavailable: UInt8(0x04)
                case nil: UInt8(0xff)
                }
            }
        )
        let serviceBytes: Data
        switch semanticObservation.service {
        case .absent:
            serviceBytes = Data([0x01])
        case let .loaded(identity):
            serviceBytes = Data([0x02]) + (try identity.encoded())
        case .unavailable:
            serviceBytes = Data([0x03])
        }
        return try HandoffBinaryTranscript.encode(
                domain:
                    "stornaut.task39.machine.single-epoch.installed-l2-proof",
                businessFields: [
                    projection.projectionSHA256.rawBytes,
                    InvestigationHandoffSHA256.hashing(
                        try claimEvidence.encoded()
                    ).rawBytes,
                    singleEpochData(semanticObservation.epochUUID),
                    singleEpochData(semanticObservation.configurationNonce),
                    artifactBytes,
                    try semanticObservation.app.identity.encoded(),
                    semanticObservation.app.executableSHA256.rawBytes,
                    installedL2SigningData(
                        semanticObservation.app.staticSigning
                    ),
                    installedL2SigningData(
                        semanticObservation.app.liveSigning
                    ),
                    try semanticObservation.helper.identity.encoded(),
                    semanticObservation.helper.executableSHA256.rawBytes,
                    installedL2SigningData(
                        semanticObservation.helper.staticSigning
                    ),
                    installedL2SigningData(
                        semanticObservation.helper.liveSigning
                    ),
                    semanticObservation.machineDriver.executableSHA256.rawBytes,
                    installedL2SigningData(
                        semanticObservation.machineDriver.staticSigning
                    ),
                    installedL2SigningData(
                        semanticObservation.machineDriver.liveSigning
                    ),
                    serviceBytes,
                    singleEpochData(
                        semanticObservation.started.wallUTC.rawValue
                    ),
                    singleEpochData(
                        semanticObservation.started.continuousNanoseconds
                    ),
                    singleEpochData(
                        semanticObservation.observed.wallUTC.rawValue
                    ),
                    singleEpochData(
                        semanticObservation.observed.continuousNanoseconds
                    ),
                    try repeatedAppIdentity.encoded(),
                    singleEpochData(epochDeadlineNanoseconds),
                ],
                maximumByteCount: 16_384
            )
    }
}

package struct InvestigationMachineSingleEpochLocalCompletionCandidate:
    Sendable,
    Equatable
{
    static let domain =
        "stornaut.task39.machine.single-epoch.local-completion"
    static let maximumByteCount = 2_048

    let ownership: InvestigationMachineSingleEpochOwnershipCandidate
    let helperIdentity: InvestigationMachineProcessIdentity
    let claimReleaseSHA256: InvestigationHandoffSHA256
    let driverObservationSHA256: InvestigationHandoffSHA256
    let bindingSHA256: InvestigationHandoffSHA256

    private let claimRelease: InvestigationMachineClaimReleased
    private let retirement: InvestigationMachineSingleEpochRetirementProof
    private let driverObservation:
        InvestigationMachineSingleEpochDriverObservation

    init(
        ownership: InvestigationMachineSingleEpochOwnershipCandidate,
        claimRelease: InvestigationMachineClaimReleased,
        retirement: InvestigationMachineSingleEpochRetirementProof,
        initialDriverObservation:
            InvestigationMachineSingleEpochDriverObservation,
        finalDriverObservation:
            InvestigationMachineSingleEpochDriverObservation
    ) throws {
        guard
            initialDriverObservation == finalDriverObservation,
            claimRelease.requestBindingSHA256
                == ownership.claimRequestBindingSHA256,
            claimRelease.claimedHelperIdentitySHA256
                == (try ownership.helperIdentity.helperIdentitySHA256()),
            claimRelease.claimConnectionEpoch
                == ownership.claimConnectionEpoch,
            claimRelease.exitScheduled,
            claimRelease.postReplyExitDeadlineNanoseconds > 0,
            claimRelease.postReplyExitDeadlineNanoseconds
                <= ownership.epochDeadlineNanoseconds
        else {
            throw InvestigationMachineSingleEpochError
                .releaseTerminalUncertain
        }
        let claimReleaseSHA256 = InvestigationHandoffSHA256.hashing(
            try claimRelease.encoded()
        )
        let driverObservationSHA256 = try
            singleEpochDriverObservationSHA256(initialDriverObservation)
        let bindingSHA256 = InvestigationHandoffSHA256.hashing(
            try HandoffBinaryTranscript.encode(
                domain: Self.domain,
                businessFields: [
                    ownership.bindingSHA256.rawBytes,
                    claimReleaseSHA256.rawBytes,
                    driverObservationSHA256.rawBytes,
                    Data([0x01]),
                ],
                maximumByteCount: Self.maximumByteCount
            )
        )
        self.ownership = ownership
        helperIdentity = ownership.helperIdentity
        self.claimReleaseSHA256 = claimReleaseSHA256
        self.driverObservationSHA256 = driverObservationSHA256
        self.bindingSHA256 = bindingSHA256
        self.claimRelease = claimRelease
        self.retirement = retirement
        driverObservation = initialDriverObservation
    }
}

package enum InvestigationMachineSingleEpochOwnershipResolution:
    Sendable,
    Equatable
{
    case resumeLocal(InvestigationMachineSingleEpochOwnershipCandidate)
    case outerOwnsTerminal(
        InvestigationMachineSingleEpochOwnershipCandidate
    )
    case terminalUncertain
}

package protocol InvestigationMachineSingleEpochOwnershipSuspending:
    Sendable
{
    func suspend(
        _ candidate: InvestigationMachineSingleEpochOwnershipCandidate
    ) async -> InvestigationMachineSingleEpochOwnershipResolution
}

protocol InvestigationMachineSingleEpochComposing: Sendable {
    func isBound(
        to selection: InvestigationMachineFixedEpochSelection
    ) -> Bool
    func run(
        previousHelperIdentity: InvestigationMachineProcessIdentity?
    ) async throws -> InvestigationMachineSingleEpochResult
    func run(
        invocation: InvestigationMachineSingleEpochInvocation
    ) async throws -> InvestigationMachineSingleEpochResult
}

protocol InvestigationMachinePhysicalSingleEpochComposing:
    InvestigationMachineSingleEpochComposing
{
    func run(
        invocation: InvestigationMachineSingleEpochInvocation,
        epochDeadlineNanoseconds: UInt64
    ) async throws -> InvestigationMachineSingleEpochResult
}

extension InvestigationMachineSingleEpochComposing {
    func run(
        invocation: InvestigationMachineSingleEpochInvocation
    ) async throws -> InvestigationMachineSingleEpochResult {
        try await run(
            previousHelperIdentity: invocation.previousHelperIdentity
        )
    }
}

package actor InvestigationMachineSingleEpochComposition {
    private let selection: InvestigationMachineFixedEpochSelection
    private let predecessor: InvestigationMachineHelperEpochContinuity
    private let composer: any InvestigationMachineSingleEpochComposing
    private let outerJoin: InvestigationMachineOuterCompletionJoin
    private var consumed = false

    init(
        selection: InvestigationMachineFixedEpochSelection,
        predecessor: InvestigationMachineHelperEpochContinuity,
        composer: any InvestigationMachineSingleEpochComposing,
        outerJoin: InvestigationMachineOuterCompletionJoin
    ) {
        self.selection = selection
        self.predecessor = predecessor
        self.composer = composer
        self.outerJoin = outerJoin
    }

    package func run() async throws
        -> InvestigationMachineHelperEpochContinuity
    {
        guard !consumed else {
            throw InvestigationMachineHelperEpochContinuityError
                .alreadyConsumed
        }
        consumed = true
        guard composer.isBound(to: selection) else {
            throw InvestigationMachineHelperEpochContinuityError
                .invalidCompletion
        }
        let predecessorMaterial = try predecessor.consume(
            for: selection
        )
        let invocation = try predecessorMaterial.invocation(for: selection)
        let result = try await composer.run(invocation: invocation)
        let currentHelper: InvestigationMachineProcessIdentity
        switch result {
        case let .localCompletion(completion):
            currentHelper = completion.helperIdentity
        case let .ownershipTransferred(ownership):
            currentHelper = ownership.helperIdentity
        case let .admittedPhysical(admitted):
            currentHelper = admitted.helperIdentity
        }
        guard
            predecessorMaterial.previousHelperIdentity == nil
                || predecessorMaterial.previousHelperIdentity != currentHelper
        else {
            throw InvestigationMachineHelperEpochContinuityError
                .invalidCompletion
        }
        return try await outerJoin.seal(
            selection: selection, result: result,
            predecessor: predecessorMaterial
        )
    }
}

private func singleEpochData(_ value: UInt32) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 24),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}

private func singleEpochData(_ value: UInt16) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}

private func singleEpochData(_ value: UInt64) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 56),
        UInt8(truncatingIfNeeded: value >> 48),
        UInt8(truncatingIfNeeded: value >> 40),
        UInt8(truncatingIfNeeded: value >> 32),
        UInt8(truncatingIfNeeded: value >> 24),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}

private func singleEpochData(_ value: Int64) -> Data {
    singleEpochData(UInt64(bitPattern: value))
}

private func singleEpochData(_ value: UUID) -> Data {
    var bytes = value.uuid
    return withUnsafeBytes(of: &bytes) { Data($0) }
}

private func installedL2SigningData(
    _ value: InvestigationInstalledL2SigningIdentity
) throws -> Data {
    try HandoffBinaryTranscript.encode(
        domain: "stornaut.task39.machine.single-epoch.installed-l2-signing",
        businessFields: [
            Data(value.signingIdentifier.utf8),
            value.designatedRequirementSHA256.rawBytes,
            value.codeDirectoryHash,
            Data([value.isAdHoc ? 0x01 : 0x00]),
        ],
        maximumByteCount: 1_024
    )
}

func singleEpochDriverObservationSHA256(
    _ value: InvestigationMachineSingleEpochDriverObservation
) throws -> InvestigationHandoffSHA256 {
    let observation = value.value
    return InvestigationHandoffSHA256.hashing(
        try HandoffBinaryTranscript.encode(
            domain:
                "stornaut.task39.machine.single-epoch.driver-observation",
            businessFields: [
                Data(observation.executablePath.utf8),
                singleEpochDriverNodeData(observation.node),
                Data(observation.executableSHA256.utf8),
                singleEpochDriverSigningData(observation.signing),
                singleEpochDriverManifestData(observation.manifest),
            ],
            maximumByteCount: 8_192
        )
    )
}

private func singleEpochDriverNodeData(
    _ value: InvestigationMachineInstalledDriverNodeIdentity
) throws -> Data {
    try HandoffBinaryTranscript.encode(
        domain: "stornaut.task39.machine.single-epoch.driver-node",
        businessFields: [
            singleEpochData(value.deviceID),
            singleEpochData(value.inode),
            singleEpochData(value.generation),
            Data([value.isRegularFile ? 0x01 : 0x00]),
            singleEpochData(value.ownerUserID),
            singleEpochData(value.ownerGroupID),
            singleEpochData(UInt16(value.mode)),
            singleEpochData(value.linkCount),
            singleEpochData(value.size),
            singleEpochData(value.flags),
            singleEpochData(value.modificationSeconds),
            singleEpochData(value.modificationNanoseconds),
            singleEpochData(value.statusChangeSeconds),
            singleEpochData(value.statusChangeNanoseconds),
        ],
        maximumByteCount: 2_048
    )
}

private func singleEpochDriverSigningData(
    _ value: InvestigationMachineInstalledDriverSigningIdentity
) throws -> Data {
    try HandoffBinaryTranscript.encode(
        domain: "stornaut.task39.machine.single-epoch.driver-signing",
        businessFields: [
            Data(value.signingIdentifier.utf8),
            Data(value.designatedRequirementSHA256.utf8),
            Data(value.codeDirectoryHash.utf8),
            Data([value.isAdHoc ? 0x01 : 0x00]),
        ],
        maximumByteCount: 1_024
    )
}

private func singleEpochDriverManifestData(
    _ value: InvestigationMachineInstalledManifestIdentity
) throws -> Data {
    try HandoffBinaryTranscript.encode(
        domain: "stornaut.task39.machine.single-epoch.driver-manifest",
        businessFields: [
            Data(value.path.utf8),
            try singleEpochDriverNodeData(value.node),
            Data(value.sha256.utf8),
            Data(value.label.utf8),
            Data(value.program.utf8),
            Data(value.primaryServiceIdentifier.utf8),
            Data(value.machineClaimServiceIdentifier.utf8),
        ],
        maximumByteCount: 4_096
    )
}
