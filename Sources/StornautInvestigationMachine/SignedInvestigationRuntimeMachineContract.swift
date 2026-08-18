import CryptoKit
import Darwin
import Foundation
import StornautCodex
import StornautCore
import StornautInvestigation

public enum SignedInvestigationRuntimeMachineCaseOutcome:
    String,
    Codable,
    Sendable,
    Equatable
{
    case succeeded
    case cancelled
    case timedOut
    case invalidEnvelopeBlocked
    case identityMismatchBlocked
    case transportLossBlocked
    case lifecycleRecovered
    case artifactCleanupRecovered
}

public enum SignedInvestigationRuntimeUpstreamErrorCategory:
    String,
    Codable,
    Sendable,
    Equatable
{
    case authentication
    case usageLimit
    case provider
    case transport
    case protocolViolation
    case runtime
}

public enum SignedInvestigationRuntimeNonClaim:
    String,
    Codable,
    Sendable,
    Equatable,
    Hashable,
    CaseIterable
{
    case releaseDistributionOrNotarization
    case arbitraryUserFDATCCBehavior
    case productFirstUseDisclosure
    case ordinaryAppAvailability
    case realUserDataReportQuality
    case cleanupSafetyBeyondNoExecutorBoundary
}

public enum SignedInvestigationRuntimeMachineVerdict:
    String,
    Codable,
    Sendable,
    Equatable
{
    case evidenceContractValidatedMachineAdmissionPending
}

public struct SignedInvestigationRuntimeUpstreamError:
    Codable,
    Sendable,
    Equatable
{
    public let category: SignedInvestigationRuntimeUpstreamErrorCategory
    public let code: String
    public let willRetry: Bool

    public init(
        category: SignedInvestigationRuntimeUpstreamErrorCategory,
        code: String,
        willRetry: Bool
    ) throws {
        guard machineStableIdentifier(code, maximumBytes: 128) else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        self.category = category
        self.code = code
        self.willRetry = willRetry
    }

    public init(from decoder: Decoder) throws {
        let container = try strictMachineContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        try self.init(
            category: container.decode(
                SignedInvestigationRuntimeUpstreamErrorCategory.self,
                forKey: MachineCodingKey(CodingKeys.category.rawValue)
            ),
            code: container.decode(
                String.self,
                forKey: MachineCodingKey(CodingKeys.code.rawValue)
            ),
            willRetry: container.decode(
                Bool.self,
                forKey: MachineCodingKey(CodingKeys.willRetry.rawValue)
            )
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case category
        case code
        case willRetry
    }
}

public struct SignedInvestigationRuntimeMachineCaseEvidence:
    Codable,
    Sendable,
    Equatable
{
    public static let schemaVersion = 2
    public static let maximumEvidenceAgeSeconds = 3_600

    public let schemaVersion: Int
    public let scenario: SignedInvestigationRuntimeDiagnosticScenario
    public let nonce: UUID
    public let configurationSHA256: String
    public let runtimeArtifactSHA256: String
    public let evidenceStoreSHA256: String
    public let capabilityEvidenceSHA256: String?
    public let binding: SignedInvestigationRuntimeBinding
    public let investigationID: InvestigationID
    public let runID: InvestigationRunID
    public let reportID: InvestigationReportID?
    public let sourceFingerprint: InvestigationFingerprint
    public let planFingerprint: InvestigationFingerprint
    public let targetSetFingerprint: InvestigationFingerprint
    public let outcome: SignedInvestigationRuntimeMachineCaseOutcome
    public let runStarted: Bool
    public let turnAdmitted: Bool
    public let finalEnvelopeAccepted: Bool
    public let terminalBarrierSettled: Bool
    public let artifactsRetired: Bool
    public let localRuntimeDrained: Bool
    public let recoveryAttempted: Bool
    public let recoveryCompleted: Bool
    public let denials: [SignedInvestigationRuntimeDenialEvidence]
    public let finalResidue: SignedInvestigationRuntimeResidue
    public let observationReasonKey: String?
    public let upstreamError: SignedInvestigationRuntimeUpstreamError?
    public let startedAt: Date
    public let completedAt: Date

    public init(
        scenario: SignedInvestigationRuntimeDiagnosticScenario,
        nonce: UUID,
        configurationSHA256: String,
        runtimeArtifactSHA256: String,
        evidenceStoreSHA256: String,
        capabilityEvidenceSHA256: String?,
        binding: SignedInvestigationRuntimeBinding,
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        reportID: InvestigationReportID?,
        sourceFingerprint: InvestigationFingerprint,
        planFingerprint: InvestigationFingerprint,
        targetSetFingerprint: InvestigationFingerprint,
        outcome: SignedInvestigationRuntimeMachineCaseOutcome,
        runStarted: Bool,
        turnAdmitted: Bool,
        finalEnvelopeAccepted: Bool,
        terminalBarrierSettled: Bool,
        artifactsRetired: Bool,
        localRuntimeDrained: Bool,
        recoveryAttempted: Bool,
        recoveryCompleted: Bool,
        denials: [SignedInvestigationRuntimeDenialEvidence],
        finalResidue: SignedInvestigationRuntimeResidue,
        observationReasonKey: String?,
        upstreamError: SignedInvestigationRuntimeUpstreamError?,
        startedAt: Date,
        completedAt: Date
    ) throws {
        schemaVersion = Self.schemaVersion
        self.scenario = scenario
        self.nonce = nonce
        self.configurationSHA256 = configurationSHA256
        self.runtimeArtifactSHA256 = runtimeArtifactSHA256
        self.evidenceStoreSHA256 = evidenceStoreSHA256
        self.capabilityEvidenceSHA256 = capabilityEvidenceSHA256
        self.binding = binding
        self.investigationID = investigationID
        self.runID = runID
        self.reportID = reportID
        self.sourceFingerprint = sourceFingerprint
        self.planFingerprint = planFingerprint
        self.targetSetFingerprint = targetSetFingerprint
        self.outcome = outcome
        self.runStarted = runStarted
        self.turnAdmitted = turnAdmitted
        self.finalEnvelopeAccepted = finalEnvelopeAccepted
        self.terminalBarrierSettled = terminalBarrierSettled
        self.artifactsRetired = artifactsRetired
        self.localRuntimeDrained = localRuntimeDrained
        self.recoveryAttempted = recoveryAttempted
        self.recoveryCompleted = recoveryCompleted
        self.denials = denials.sorted {
            $0.kind.rawValue < $1.kind.rawValue
        }
        self.finalResidue = finalResidue
        self.observationReasonKey = observationReasonKey
        self.upstreamError = upstreamError
        self.startedAt = startedAt
        self.completedAt = completedAt
        try validate()
    }

    public init(from decoder: Decoder) throws {
        let container = try strictMachineContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue)),
            optionalKeys: [
                CodingKeys.capabilityEvidenceSHA256.rawValue,
                CodingKeys.reportID.rawValue,
                CodingKeys.observationReasonKey.rawValue,
                CodingKeys.upstreamError.rawValue,
            ]
        )
        let schemaVersion = try container.decode(
            Int.self,
            forKey: MachineCodingKey(CodingKeys.schemaVersion.rawValue)
        )
        guard schemaVersion == Self.schemaVersion else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        try self.init(
            scenario: container.decode(
                SignedInvestigationRuntimeDiagnosticScenario.self,
                forKey: MachineCodingKey(CodingKeys.scenario.rawValue)
            ),
            nonce: container.decode(
                UUID.self,
                forKey: MachineCodingKey(CodingKeys.nonce.rawValue)
            ),
            configurationSHA256: container.decode(
                String.self,
                forKey: MachineCodingKey(
                    CodingKeys.configurationSHA256.rawValue
                )
            ),
            runtimeArtifactSHA256: container.decode(
                String.self,
                forKey: MachineCodingKey(
                    CodingKeys.runtimeArtifactSHA256.rawValue
                )
            ),
            evidenceStoreSHA256: container.decode(
                String.self,
                forKey: MachineCodingKey(
                    CodingKeys.evidenceStoreSHA256.rawValue
                )
            ),
            capabilityEvidenceSHA256: container.decodeIfPresent(
                String.self,
                forKey: MachineCodingKey(
                    CodingKeys.capabilityEvidenceSHA256.rawValue
                )
            ),
            binding: container.decode(
                SignedInvestigationRuntimeBinding.self,
                forKey: MachineCodingKey(CodingKeys.binding.rawValue)
            ),
            investigationID: container.decode(
                InvestigationID.self,
                forKey: MachineCodingKey(
                    CodingKeys.investigationID.rawValue
                )
            ),
            runID: container.decode(
                InvestigationRunID.self,
                forKey: MachineCodingKey(CodingKeys.runID.rawValue)
            ),
            reportID: container.decodeIfPresent(
                InvestigationReportID.self,
                forKey: MachineCodingKey(CodingKeys.reportID.rawValue)
            ),
            sourceFingerprint: container.decode(
                InvestigationFingerprint.self,
                forKey: MachineCodingKey(
                    CodingKeys.sourceFingerprint.rawValue
                )
            ),
            planFingerprint: container.decode(
                InvestigationFingerprint.self,
                forKey: MachineCodingKey(
                    CodingKeys.planFingerprint.rawValue
                )
            ),
            targetSetFingerprint: container.decode(
                InvestigationFingerprint.self,
                forKey: MachineCodingKey(
                    CodingKeys.targetSetFingerprint.rawValue
                )
            ),
            outcome: container.decode(
                SignedInvestigationRuntimeMachineCaseOutcome.self,
                forKey: MachineCodingKey(CodingKeys.outcome.rawValue)
            ),
            runStarted: container.decode(
                Bool.self,
                forKey: MachineCodingKey(CodingKeys.runStarted.rawValue)
            ),
            turnAdmitted: container.decode(
                Bool.self,
                forKey: MachineCodingKey(CodingKeys.turnAdmitted.rawValue)
            ),
            finalEnvelopeAccepted: container.decode(
                Bool.self,
                forKey: MachineCodingKey(
                    CodingKeys.finalEnvelopeAccepted.rawValue
                )
            ),
            terminalBarrierSettled: container.decode(
                Bool.self,
                forKey: MachineCodingKey(
                    CodingKeys.terminalBarrierSettled.rawValue
                )
            ),
            artifactsRetired: container.decode(
                Bool.self,
                forKey: MachineCodingKey(
                    CodingKeys.artifactsRetired.rawValue
                )
            ),
            localRuntimeDrained: container.decode(
                Bool.self,
                forKey: MachineCodingKey(
                    CodingKeys.localRuntimeDrained.rawValue
                )
            ),
            recoveryAttempted: container.decode(
                Bool.self,
                forKey: MachineCodingKey(
                    CodingKeys.recoveryAttempted.rawValue
                )
            ),
            recoveryCompleted: container.decode(
                Bool.self,
                forKey: MachineCodingKey(
                    CodingKeys.recoveryCompleted.rawValue
                )
            ),
            denials: container.decode(
                [SignedInvestigationRuntimeDenialEvidence].self,
                forKey: MachineCodingKey(CodingKeys.denials.rawValue)
            ),
            finalResidue: container.decode(
                SignedInvestigationRuntimeResidue.self,
                forKey: MachineCodingKey(
                    CodingKeys.finalResidue.rawValue
                )
            ),
            observationReasonKey: container.decodeIfPresent(
                String.self,
                forKey: MachineCodingKey(
                    CodingKeys.observationReasonKey.rawValue
                )
            ),
            upstreamError: container.decodeIfPresent(
                SignedInvestigationRuntimeUpstreamError.self,
                forKey: MachineCodingKey(
                    CodingKeys.upstreamError.rawValue
                )
            ),
            startedAt: container.decode(
                Date.self,
                forKey: MachineCodingKey(CodingKeys.startedAt.rawValue)
            ),
            completedAt: container.decode(
                Date.self,
                forKey: MachineCodingKey(CodingKeys.completedAt.rawValue)
            )
        )
    }

    public var isExpectedOutcome: Bool {
        expectedControls == observedControls
            && outcome == scenario.expectedOutcome
            && finalResidue.isZero
            && sourceFingerprint.hex == binding.sourceFingerprintSHA256
            && investigationID.rawValue
                == "investigation-" + nonce.uuidString.lowercased()
            && runID.rawValue
                == "investigation-run-" + nonce.uuidString.lowercased()
            && reportID?.rawValue
                == (
                    scenario == .success
                        ? "investigation-report-"
                            + nonce.uuidString.lowercased()
                        : nil
                )
    }

    fileprivate func validate(
        configuration:
            SignedInvestigationRuntimeDiagnosticConfiguration,
        cohortRootPath: String,
        cohortRootDescriptor: Int32,
        now: Date
    ) throws -> MachineConfigurationObservation {
        try configuration.validate(
            now: now,
            outputs: .ownerRegularFile
        )
        let observedArtifacts =
            try machineValidateConfigurationPaths(
            configuration,
            cohortRootPath: cohortRootPath,
            cohortRootDescriptor: cohortRootDescriptor
        )
        guard
            configuration.scenario == scenario,
            configuration.nonce == nonce,
            configuration.binding == binding,
            try configuration.machineConfigurationSHA256()
                == configurationSHA256,
            observedArtifacts.runtimeArtifactSHA256
                == runtimeArtifactSHA256,
            observedArtifacts.evidenceStoreSHA256
                == evidenceStoreSHA256,
            completedAt <= configuration.validBefore,
            startedAt <= now,
            completedAt <= now,
            now.timeIntervalSince(completedAt)
                <= Double(Self.maximumEvidenceAgeSeconds),
            completedAt.timeIntervalSince(startedAt)
                <= Double(configuration.maximumWallClockSeconds)
        else {
            throw SignedInvestigationRuntimeContractError.bindingMismatch
        }
        guard
            observedArtifacts.runtimeArtifactCount
                == finalResidue.runtimeArtifactCount,
            observedArtifacts.runtimeArtifactCount == 0
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        return observedArtifacts
    }

    func successProductionEvidence()
        throws -> SignedInvestigationProductionEvidence
    {
        guard
            scenario == .success,
            let reportID,
            isExpectedOutcome
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        return SignedInvestigationProductionEvidence(
            investigationID: investigationID,
            runID: runID,
            reportID: reportID,
            sourceFingerprint: sourceFingerprint,
            planFingerprint: planFingerprint,
            finalEnvelopeAccepted: finalEnvelopeAccepted,
            terminalBarrierSettled: terminalBarrierSettled,
            artifactsRetired: artifactsRetired,
            localRuntimeDrained: localRuntimeDrained,
            failureReasonKey: nil
        )
    }

    private var observedControls: MachineCaseControls {
        MachineCaseControls(
            runStarted: runStarted,
            turnAdmitted: turnAdmitted,
            finalEnvelopeAccepted: finalEnvelopeAccepted,
            terminalBarrierSettled: terminalBarrierSettled,
            artifactsRetired: artifactsRetired,
            localRuntimeDrained: localRuntimeDrained,
            recoveryAttempted: recoveryAttempted,
            recoveryCompleted: recoveryCompleted,
            reportPresent: reportID != nil,
            denialsPresent: !denials.isEmpty,
            observationPresent: observationReasonKey != nil
        )
    }

    private var expectedControls: MachineCaseControls {
        scenario.expectedControls
    }

    private func validate() throws {
        guard
            machineSHA256(configurationSHA256),
            machineSHA256(runtimeArtifactSHA256),
            machineSHA256(evidenceStoreSHA256),
            scenario == .success
                ? capabilityEvidenceSHA256.map(machineSHA256) == true
                : capabilityEvidenceSHA256 == nil,
            binding.isValid,
            machineStableOptionalReasonKey(observationReasonKey),
            startedAt.timeIntervalSince1970.isFinite,
            completedAt.timeIntervalSince1970.isFinite,
            completedAt >= startedAt,
            completedAt.timeIntervalSince(startedAt) <= 3_600,
            machineResidueIsValid(finalResidue),
            denials.count <= SignedInvestigationRuntimeDenialKind
                .required.count,
            Set(denials.map(\.kind)).count == denials.count,
            isExpectedOutcome
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        if scenario == .success {
            guard
                Set(denials.map(\.kind))
                    == SignedInvestigationRuntimeDenialKind.required,
                denials.allSatisfy({
                    $0.attempted
                        && $0.contained
                        && $0.controlReasonKey != nil
                        && $0.failureReasonKey == nil
                }),
                upstreamError == nil
            else {
                throw SignedInvestigationRuntimeContractError.invalidReport
            }
        } else {
            guard denials.isEmpty else {
                throw SignedInvestigationRuntimeContractError.invalidReport
            }
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case scenario
        case nonce
        case configurationSHA256
        case runtimeArtifactSHA256
        case evidenceStoreSHA256
        case capabilityEvidenceSHA256
        case binding
        case investigationID
        case runID
        case reportID
        case sourceFingerprint
        case planFingerprint
        case targetSetFingerprint
        case outcome
        case runStarted
        case turnAdmitted
        case finalEnvelopeAccepted
        case terminalBarrierSettled
        case artifactsRetired
        case localRuntimeDrained
        case recoveryAttempted
        case recoveryCompleted
        case denials
        case finalResidue
        case observationReasonKey
        case upstreamError
        case startedAt
        case completedAt
    }
}

public struct SignedInvestigationRuntimeFailureMatrix:
    Codable,
    Sendable,
    Equatable
{
    public static let schemaVersion = 2

    public let schemaVersion: Int
    public let cases: [SignedInvestigationRuntimeMachineCaseEvidence]

    public init(
        cases: [SignedInvestigationRuntimeMachineCaseEvidence]
    ) throws {
        let sorted = cases.sorted {
            $0.scenario.rawValue < $1.scenario.rawValue
        }
        guard
            sorted.count
                == SignedInvestigationRuntimeDiagnosticScenario
                .allCases.count,
            Set(sorted.map(\.scenario))
                == Set(
                    SignedInvestigationRuntimeDiagnosticScenario.allCases
                ),
            Set(sorted.map(\.nonce)).count == sorted.count,
            Set(sorted.map(\.configurationSHA256)).count
                == sorted.count,
            sorted.allSatisfy(\.isExpectedOutcome),
            sorted.dropFirst().allSatisfy({
                $0.binding == sorted[0].binding
            }),
            Set(sorted.map(\.planFingerprint)).count == sorted.count,
            sorted.dropFirst().allSatisfy({
                $0.targetSetFingerprint
                    == sorted[0].targetSetFingerprint
            })
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        schemaVersion = Self.schemaVersion
        self.cases = sorted
    }

    public init(from decoder: Decoder) throws {
        let container = try strictMachineContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let schemaVersion = try container.decode(
            Int.self,
            forKey: MachineCodingKey(CodingKeys.schemaVersion.rawValue)
        )
        guard schemaVersion == Self.schemaVersion else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        try self.init(
            cases: container.decode(
                [SignedInvestigationRuntimeMachineCaseEvidence].self,
                forKey: MachineCodingKey(CodingKeys.cases.rawValue)
            )
        )
    }

    public var success:
        SignedInvestigationRuntimeMachineCaseEvidence
    {
        cases.first { $0.scenario == .success }!
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case cases
    }
}

public struct SignedInvestigationRuntimeMachineReport:
    Codable,
    Sendable,
    Equatable
{
    public static let schemaVersion = 2

    public let schemaVersion: Int
    public let successReport: SignedInvestigationRuntimeReport
    public let failureMatrix: SignedInvestigationRuntimeFailureMatrix
    public let matrixSHA256: String
    public let reportSHA256: String
    public let verdict: SignedInvestigationRuntimeMachineVerdict
    public let nonClaims: [SignedInvestigationRuntimeNonClaim]

    init(
        successReport: SignedInvestigationRuntimeReport,
        failureMatrix: SignedInvestigationRuntimeFailureMatrix
    ) throws {
        let success = failureMatrix.success
        guard
            successReport.verdict
                == .evidenceContractValidatedMachineAdmissionPending,
            successReport.nonce == success.nonce,
            successReport.binding == success.binding,
            successReport.production
                == (try success.successProductionEvidence()),
            successReport.denials == success.denials,
            successReport.residue == success.finalResidue,
            successReport.startedAt == success.startedAt,
            successReport.completedAt == success.completedAt,
            try successReport.capabilityEvidence
                .machineEvidenceSHA256()
                == success.capabilityEvidenceSHA256,
            successReport.capabilityEvidence.completedAt
                <= success.startedAt,
            success.startedAt.timeIntervalSince(
                successReport.capabilityEvidence.completedAt
            ) <= 140
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        schemaVersion = Self.schemaVersion
        self.successReport = successReport
        self.failureMatrix = failureMatrix
        matrixSHA256 = try machineCanonicalSHA256(failureMatrix)
        reportSHA256 = try machineCanonicalSHA256(successReport)
        verdict =
            .evidenceContractValidatedMachineAdmissionPending
        nonClaims = SignedInvestigationRuntimeNonClaim.allCases.sorted {
            $0.rawValue < $1.rawValue
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try strictMachineContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let schemaVersion = try container.decode(
            Int.self,
            forKey: MachineCodingKey(CodingKeys.schemaVersion.rawValue)
        )
        guard schemaVersion == Self.schemaVersion else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        let decodedMatrixHash = try container.decode(
            String.self,
            forKey: MachineCodingKey(CodingKeys.matrixSHA256.rawValue)
        )
        let decodedReportHash = try container.decode(
            String.self,
            forKey: MachineCodingKey(CodingKeys.reportSHA256.rawValue)
        )
        let decodedVerdict = try container.decode(
            SignedInvestigationRuntimeMachineVerdict.self,
            forKey: MachineCodingKey(CodingKeys.verdict.rawValue)
        )
        let decodedNonClaims = try container.decode(
            [SignedInvestigationRuntimeNonClaim].self,
            forKey: MachineCodingKey(CodingKeys.nonClaims.rawValue)
        )
        try self.init(
            successReport: container.decode(
                SignedInvestigationRuntimeReport.self,
                forKey: MachineCodingKey(CodingKeys.successReport.rawValue)
            ),
            failureMatrix: container.decode(
                SignedInvestigationRuntimeFailureMatrix.self,
                forKey: MachineCodingKey(CodingKeys.failureMatrix.rawValue)
            )
        )
        guard
            matrixSHA256 == decodedMatrixHash,
            reportSHA256 == decodedReportHash,
            verdict == decodedVerdict,
            nonClaims == decodedNonClaims
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
    }

    public func canonicalJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes,
        ]
        return try encoder.encode(self)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case successReport
        case failureMatrix
        case matrixSHA256
        case reportSHA256
        case verdict
        case nonClaims
    }
}

public struct SignedInvestigationRuntimeLifecycleResidueRecord:
    Codable,
    Sendable,
    Equatable
{
    public static let schemaVersion = 1

    public let schemaVersion: Int
    public let scenario: SignedInvestigationRuntimeDiagnosticScenario
    public let nonce: UUID
    public let binding: SignedInvestigationRuntimeBinding
    public let observedAt: Date
    public let residue: SignedInvestigationRuntimeResidue

    public init(
        scenario: SignedInvestigationRuntimeDiagnosticScenario,
        nonce: UUID,
        binding: SignedInvestigationRuntimeBinding,
        observedAt: Date,
        residue: SignedInvestigationRuntimeResidue
    ) throws {
        guard
            binding.isValid,
            observedAt.timeIntervalSince1970.isFinite,
            machineResidueIsValid(residue)
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        schemaVersion = Self.schemaVersion
        self.scenario = scenario
        self.nonce = nonce
        self.binding = binding
        self.observedAt = observedAt
        self.residue = residue
    }

    public init(from decoder: Decoder) throws {
        let container = try strictMachineContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        guard
            try container.decode(
                Int.self,
                forKey: MachineCodingKey(
                    CodingKeys.schemaVersion.rawValue
                )
            ) == Self.schemaVersion
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        try self.init(
            scenario: container.decode(
                SignedInvestigationRuntimeDiagnosticScenario.self,
                forKey: MachineCodingKey(CodingKeys.scenario.rawValue)
            ),
            nonce: container.decode(
                UUID.self,
                forKey: MachineCodingKey(CodingKeys.nonce.rawValue)
            ),
            binding: container.decode(
                SignedInvestigationRuntimeBinding.self,
                forKey: MachineCodingKey(CodingKeys.binding.rawValue)
            ),
            observedAt: container.decode(
                Date.self,
                forKey: MachineCodingKey(CodingKeys.observedAt.rawValue)
            ),
            residue: container.decode(
                SignedInvestigationRuntimeResidue.self,
                forKey: MachineCodingKey(CodingKeys.residue.rawValue)
            )
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case scenario
        case nonce
        case binding
        case observedAt
        case residue
    }
}

struct SignedInvestigationRuntimeLifecycleResidueObservation:
    Sendable,
    Equatable
{
    let record:
        SignedInvestigationRuntimeLifecycleResidueRecord

    init(
        record: SignedInvestigationRuntimeLifecycleResidueRecord
    ) {
        self.record = record
    }

    fileprivate func validate(
        evidence: SignedInvestigationRuntimeMachineCaseEvidence,
        configuration:
            SignedInvestigationRuntimeDiagnosticConfiguration,
        now: Date
    ) throws {
        guard
            record.scenario == evidence.scenario,
            record.nonce == evidence.nonce,
            record.binding == evidence.binding,
            record.binding == configuration.binding,
            record.residue == evidence.finalResidue,
            record.residue.isZero,
            record.observedAt >= evidence.completedAt,
            record.observedAt <= now,
            record.observedAt <= configuration.validBefore,
            record.observedAt.timeIntervalSince(evidence.completedAt)
                <= Double(configuration.maximumWallClockSeconds),
            now.timeIntervalSince(record.observedAt)
                <= Double(
                    SignedInvestigationRuntimeMachineCaseEvidence
                        .maximumEvidenceAgeSeconds
                )
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
    }
}

public struct SignedInvestigationRuntimeMachineEvidenceBundle:
    Codable,
    Sendable,
    Equatable
{
    public static let schemaVersion = 6

    public let schemaVersion: Int
    public let configurations:
        [SignedInvestigationRuntimeDiagnosticConfiguration]
    public let artifacts:
        [SignedInvestigationRuntimeMachineCaseEvidence]
    public let lifecycleResidueRecords:
        [SignedInvestigationRuntimeLifecycleResidueRecord]
    public let capabilityMetadata: CapabilityRuntimeDiagnosticMetadata
    public let capabilityWorker: CapabilityRuntimeWorkerEvidence
    public let capabilityLifecycleIntegrity:
        [CapabilityRuntimeIntegrityEvidence]
    public let capabilityRepository: CapabilityRuntimeRepositoryEvidence

    public init(
        configurations:
            [SignedInvestigationRuntimeDiagnosticConfiguration],
        artifacts: [SignedInvestigationRuntimeMachineCaseEvidence],
        lifecycleResidueRecords:
            [SignedInvestigationRuntimeLifecycleResidueRecord],
        capabilityMetadata: CapabilityRuntimeDiagnosticMetadata,
        capabilityWorker: CapabilityRuntimeWorkerEvidence,
        capabilityLifecycleIntegrity:
            [CapabilityRuntimeIntegrityEvidence],
        capabilityRepository: CapabilityRuntimeRepositoryEvidence
    ) throws {
        _ = try configurationMap(configurations)
        _ = try SignedInvestigationRuntimeFailureMatrix(cases: artifacts)
        schemaVersion = Self.schemaVersion
        self.configurations = configurations.sorted {
            $0.scenario.rawValue < $1.scenario.rawValue
        }
        self.artifacts = artifacts.sorted {
            $0.scenario.rawValue < $1.scenario.rawValue
        }
        self.lifecycleResidueRecords =
            lifecycleResidueRecords.sorted {
                $0.scenario.rawValue < $1.scenario.rawValue
            }
        self.capabilityMetadata = capabilityMetadata
        self.capabilityWorker = capabilityWorker
        self.capabilityLifecycleIntegrity =
            capabilityLifecycleIntegrity.sorted {
                $0.property.rawValue < $1.property.rawValue
            }
        self.capabilityRepository = capabilityRepository
    }

    public init(from decoder: Decoder) throws {
        do {
            let container = try strictMachineContainer(
                decoder,
                keys: Set(CodingKeys.allCases.map(\.rawValue))
            )
            let schemaVersion = try container.decode(
                Int.self,
                forKey: MachineCodingKey(CodingKeys.schemaVersion.rawValue)
            )
            guard schemaVersion == Self.schemaVersion else {
                throw SignedInvestigationRuntimeContractError.invalidReport
            }
            try self.init(
                configurations: container.decode(
                    [CompletedMachineConfiguration].self,
                    forKey: MachineCodingKey(
                        CodingKeys.configurations.rawValue
                    )
                ).map(\.value),
                artifacts: container.decode(
                    [SignedInvestigationRuntimeMachineCaseEvidence].self,
                    forKey: MachineCodingKey(CodingKeys.artifacts.rawValue)
                ),
                lifecycleResidueRecords: container.decode(
                    [
                        SignedInvestigationRuntimeLifecycleResidueRecord
                    ].self,
                    forKey: MachineCodingKey(
                        CodingKeys.lifecycleResidueRecords.rawValue
                    )
                ),
                capabilityMetadata: container.decode(
                    CapabilityRuntimeDiagnosticMetadata.self,
                    forKey: MachineCodingKey(
                        CodingKeys.capabilityMetadata.rawValue
                    )
                ),
                capabilityWorker: container.decode(
                    CapabilityRuntimeWorkerEvidence.self,
                    forKey: MachineCodingKey(
                        CodingKeys.capabilityWorker.rawValue
                    )
                ),
                capabilityLifecycleIntegrity: container.decode(
                    [CapabilityRuntimeIntegrityEvidence].self,
                    forKey: MachineCodingKey(
                        CodingKeys.capabilityLifecycleIntegrity.rawValue
                    )
                ),
                capabilityRepository: container.decode(
                    CapabilityRuntimeRepositoryEvidence.self,
                    forKey: MachineCodingKey(
                        CodingKeys.capabilityRepository.rawValue
                    )
                )
            )
        } catch {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
    }

    public func canonicalJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes,
        ]
        return try encoder.encode(self)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case configurations
        case artifacts
        case lifecycleResidueRecords
        case capabilityMetadata
        case capabilityWorker
        case capabilityLifecycleIntegrity
        case capabilityRepository
    }
}

private struct CompletedMachineConfiguration: Decodable {
    let value: SignedInvestigationRuntimeDiagnosticConfiguration

    init(from decoder: Decoder) throws {
        value = try SignedInvestigationRuntimeDiagnosticConfiguration(
            completedOutputsFrom: decoder
        )
    }
}

enum SignedInvestigationRuntimeMachineObservationPhase:
    Sendable,
    Equatable
{
    case beforeFinalRevalidation
    case afterFinalRevalidation(
        SignedInvestigationRuntimeDiagnosticScenario
    )
}

protocol SignedInvestigationRuntimeSealedCohortAuthority:
    Sendable
{
    func withSealedCohort<Result: Sendable>(
        configurations:
            [SignedInvestigationRuntimeDiagnosticConfiguration],
        expectedLifecycleResidueRecords:
            [SignedInvestigationRuntimeLifecycleResidueRecord],
        _ operation:
            @Sendable (
                [
                    SignedInvestigationRuntimeLifecycleResidueObservation
                ]
            ) throws -> Result
    ) throws -> Result
}

private final class SignedInvestigationRuntimeMachineInvocationState:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var invocationCount = 0

    func begin() throws {
        let count = lock.withLock {
            invocationCount += 1
            return invocationCount
        }
        guard count == 1 else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
    }

    func validateCompleted() throws {
        try lock.withLock {
            guard invocationCount == 1 else {
                throw SignedInvestigationRuntimeContractError.invalidReport
            }
        }
    }
}

struct SignedInvestigationRuntimeMachineAssembler: Sendable {
    private let observationHook:
        (@Sendable (
            SignedInvestigationRuntimeMachineObservationPhase
        ) throws -> Void)?

    init() {
        observationHook = nil
    }

    init(
        observationHook:
            @escaping @Sendable (
                SignedInvestigationRuntimeMachineObservationPhase
            ) throws -> Void
    ) {
        self.observationHook = observationHook
    }

    func assemble<Authority>(
        evidence: SignedInvestigationRuntimeMachineEvidenceBundle,
        sealedCohortAuthority: Authority,
        now: Date
    ) throws -> SignedInvestigationRuntimeMachineReport
    where Authority: SignedInvestigationRuntimeSealedCohortAuthority {
        try assemble(
            configurations: evidence.configurations,
            artifacts: evidence.artifacts,
            lifecycleResidueRecords:
                evidence.lifecycleResidueRecords,
            capabilityMetadata: evidence.capabilityMetadata,
            capabilityWorker: evidence.capabilityWorker,
            capabilityLifecycleIntegrity:
                evidence.capabilityLifecycleIntegrity,
            capabilityRepository: evidence.capabilityRepository,
            sealedCohortAuthority: sealedCohortAuthority,
            now: now
        )
    }

    func assemble<Authority>(
        configurations:
            [SignedInvestigationRuntimeDiagnosticConfiguration],
        artifacts: [SignedInvestigationRuntimeMachineCaseEvidence],
        lifecycleResidueRecords:
            [SignedInvestigationRuntimeLifecycleResidueRecord],
        capabilityMetadata: CapabilityRuntimeDiagnosticMetadata,
        capabilityWorker: CapabilityRuntimeWorkerEvidence,
        capabilityLifecycleIntegrity:
            [CapabilityRuntimeIntegrityEvidence],
        capabilityRepository: CapabilityRuntimeRepositoryEvidence,
        sealedCohortAuthority: Authority,
        now: Date
    ) throws -> SignedInvestigationRuntimeMachineReport
    where Authority: SignedInvestigationRuntimeSealedCohortAuthority {
        let invocationState =
            SignedInvestigationRuntimeMachineInvocationState()
        let report = try sealedCohortAuthority.withSealedCohort(
            configurations: configurations,
            expectedLifecycleResidueRecords:
                lifecycleResidueRecords
        ) { observations in
            try invocationState.begin()
            let authoritativeRecords =
                observations.map(\.record).sorted {
                    $0.scenario.rawValue < $1.scenario.rawValue
                }
            let expectedRecords =
                lifecycleResidueRecords.sorted {
                    $0.scenario.rawValue < $1.scenario.rawValue
                }
            guard authoritativeRecords == expectedRecords else {
                throw SignedInvestigationRuntimeContractError
                    .invalidReport
            }
            return try assembleWithinSealedCohort(
                configurations: configurations,
                artifacts: artifacts,
                lifecycleResidueObservations: observations,
                capabilityMetadata: capabilityMetadata,
                capabilityWorker: capabilityWorker,
                capabilityLifecycleIntegrity:
                    capabilityLifecycleIntegrity,
                capabilityRepository: capabilityRepository,
                now: now
            )
        }
        try invocationState.validateCompleted()
        return report
    }

    private func assembleWithinSealedCohort(
        configurations:
            [SignedInvestigationRuntimeDiagnosticConfiguration],
        artifacts: [SignedInvestigationRuntimeMachineCaseEvidence],
        lifecycleResidueObservations:
            [SignedInvestigationRuntimeLifecycleResidueObservation],
        capabilityMetadata: CapabilityRuntimeDiagnosticMetadata,
        capabilityWorker: CapabilityRuntimeWorkerEvidence,
        capabilityLifecycleIntegrity:
            [CapabilityRuntimeIntegrityEvidence],
        capabilityRepository: CapabilityRuntimeRepositoryEvidence,
        now: Date
    ) throws -> SignedInvestigationRuntimeMachineReport {
        let configurationByScenario = try configurationMap(
            configurations
        )
        let matrix = try SignedInvestigationRuntimeFailureMatrix(
            cases: artifacts
        )
        let lifecycleObservationByScenario =
            try machineLifecycleObservationMap(
                lifecycleResidueObservations
            )
        let cohortRootPath = try machineCohortRootPath(
            configurations
        )
        let cohortRootDescriptor = try machineOpenAbsoluteDirectory(
            cohortRootPath,
            requireOwnerPrivate: true
        )
        defer { close(cohortRootDescriptor) }
        var observedObjectIdentities = Set<MachineObjectIdentity>()
        var observations:
            [
                SignedInvestigationRuntimeDiagnosticScenario:
                    MachineConfigurationObservation
            ] = [:]
        for evidence in matrix.cases {
            guard
                let configuration =
                    configurationByScenario[evidence.scenario]
            else {
                throw SignedInvestigationRuntimeContractError
                    .bindingMismatch
            }
            let observation = try evidence.validate(
                configuration: configuration,
                cohortRootPath: cohortRootPath,
                cohortRootDescriptor: cohortRootDescriptor,
                now: now
            )
            guard
                let lifecycleObservation =
                    lifecycleObservationByScenario[evidence.scenario]
            else {
                throw SignedInvestigationRuntimeContractError.invalidReport
            }
            try lifecycleObservation.validate(
                evidence: evidence,
                configuration: configuration,
                now: now
            )
            observations[evidence.scenario] = observation
            for identity in observation.objectIdentities {
                guard observedObjectIdentities.insert(identity).inserted
                else {
                    throw SignedInvestigationRuntimeContractError
                        .invalidConfiguration
                }
            }
        }
        try machineValidateCohortRoot(
            descriptor: cohortRootDescriptor,
            path: cohortRootPath,
            configurations: configurations,
            observations: observations
        )
        let successConfiguration = configurationByScenario[.success]!
        let success = matrix.success
        let capabilityEvidence =
            try SignedInvestigationCapabilityEvidenceReceipt(
                configuration: successConfiguration,
                metadata: capabilityMetadata,
                worker: capabilityWorker,
                lifecycleIntegrity: capabilityLifecycleIntegrity,
                repository: capabilityRepository
            )
        guard
            capabilityEvidence.report.outcome
                == .signedRuntimeReady,
            try capabilityEvidence.machineEvidenceSHA256()
                == success.capabilityEvidenceSHA256
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        try machineValidateCapabilityObservation(
            completedAt: capabilityEvidence.completedAt,
            success: success,
            configuration: successConfiguration,
            now: now
        )
        let successReport = try SignedInvestigationRuntimeReport(
            nonce: success.nonce,
            binding: success.binding,
            model: successConfiguration.expectedModel,
            provider: successConfiguration.expectedProvider,
            capabilityEvidence: capabilityEvidence,
            production: try success.successProductionEvidence(),
            denials: success.denials,
            residue: success.finalResidue,
            startedAt: success.startedAt,
            completedAt: success.completedAt,
            verdictMode: .machineAdmissionPending
        )
        let report = try SignedInvestigationRuntimeMachineReport(
            successReport: successReport,
            failureMatrix: matrix
        )
        try observationHook?(.beforeFinalRevalidation)
        for evidence in matrix.cases {
            guard
                let configuration =
                    configurationByScenario[evidence.scenario],
                let initial = observations[evidence.scenario],
                try evidence.validate(
                    configuration: configuration,
                    cohortRootPath: cohortRootPath,
                    cohortRootDescriptor: cohortRootDescriptor,
                    now: now
                ) == initial
            else {
                throw SignedInvestigationRuntimeContractError.invalidReport
            }
            try observationHook?(
                .afterFinalRevalidation(evidence.scenario)
            )
        }
        for evidence in matrix.cases {
            guard
                let configuration =
                    configurationByScenario[evidence.scenario],
                let initial = observations[evidence.scenario],
                try evidence.validate(
                    configuration: configuration,
                    cohortRootPath: cohortRootPath,
                    cohortRootDescriptor: cohortRootDescriptor,
                    now: now
                ) == initial
            else {
                throw SignedInvestigationRuntimeContractError.invalidReport
            }
        }
        try machineValidateCohortRoot(
            descriptor: cohortRootDescriptor,
            path: cohortRootPath,
            configurations: configurations,
            observations: observations
        )
        return report
    }
}

struct SignedInvestigationRuntimeMachineVerifier: Sendable {
    init() {}

    func verifyCandidate<Authority>(
        _ report: SignedInvestigationRuntimeMachineReport,
        evidence: SignedInvestigationRuntimeMachineEvidenceBundle,
        sealedCohortAuthority: Authority,
        now: Date
    ) throws -> SignedInvestigationRuntimeMachineReport
    where Authority: SignedInvestigationRuntimeSealedCohortAuthority {
        try verifyCandidate(
            report,
            configurations: evidence.configurations,
            artifacts: evidence.artifacts,
            lifecycleResidueRecords:
                evidence.lifecycleResidueRecords,
            capabilityMetadata: evidence.capabilityMetadata,
            capabilityWorker: evidence.capabilityWorker,
            capabilityLifecycleIntegrity:
                evidence.capabilityLifecycleIntegrity,
            capabilityRepository: evidence.capabilityRepository,
            sealedCohortAuthority: sealedCohortAuthority,
            now: now
        )
    }

    func verifyCandidate<Authority>(
        _ report: SignedInvestigationRuntimeMachineReport,
        configurations:
            [SignedInvestigationRuntimeDiagnosticConfiguration],
        artifacts: [SignedInvestigationRuntimeMachineCaseEvidence],
        lifecycleResidueRecords:
            [SignedInvestigationRuntimeLifecycleResidueRecord],
        capabilityMetadata: CapabilityRuntimeDiagnosticMetadata,
        capabilityWorker: CapabilityRuntimeWorkerEvidence,
        capabilityLifecycleIntegrity:
            [CapabilityRuntimeIntegrityEvidence],
        capabilityRepository: CapabilityRuntimeRepositoryEvidence,
        sealedCohortAuthority: Authority,
        now: Date
    ) throws -> SignedInvestigationRuntimeMachineReport
    where Authority: SignedInvestigationRuntimeSealedCohortAuthority {
        let rebuilt = try SignedInvestigationRuntimeMachineAssembler()
            .assemble(
                configurations: configurations,
                artifacts: artifacts,
                lifecycleResidueRecords:
                    lifecycleResidueRecords,
                capabilityMetadata: capabilityMetadata,
                capabilityWorker: capabilityWorker,
                capabilityLifecycleIntegrity:
                    capabilityLifecycleIntegrity,
                capabilityRepository: capabilityRepository,
                sealedCohortAuthority: sealedCohortAuthority,
                now: now
            )
        guard
            rebuilt == report,
            report.verdict
                == .evidenceContractValidatedMachineAdmissionPending
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        return rebuilt
    }
}

private struct MachineCaseControls: Equatable {
    let runStarted: Bool
    let turnAdmitted: Bool
    let finalEnvelopeAccepted: Bool
    let terminalBarrierSettled: Bool
    let artifactsRetired: Bool
    let localRuntimeDrained: Bool
    let recoveryAttempted: Bool
    let recoveryCompleted: Bool
    let reportPresent: Bool
    let denialsPresent: Bool
    let observationPresent: Bool
}

private func machineValidateCapabilityObservation(
    completedAt: Date,
    success: SignedInvestigationRuntimeMachineCaseEvidence,
    configuration:
        SignedInvestigationRuntimeDiagnosticConfiguration,
    now: Date
) throws {
    let completedTimestamp = completedAt.timeIntervalSince1970
    let nowTimestamp = now.timeIntervalSince1970
    guard
        completedTimestamp.isFinite,
        nowTimestamp.isFinite
    else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    guard
        completedAt <= success.startedAt,
        success.startedAt.timeIntervalSince(completedAt)
            <= Double(configuration.maximumWallClockSeconds),
        completedAt <= configuration.validBefore,
        completedAt <= now,
        now.timeIntervalSince(completedAt)
            <= Double(
                SignedInvestigationRuntimeMachineCaseEvidence
                    .maximumEvidenceAgeSeconds
            )
    else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
}

private extension SignedInvestigationRuntimeDiagnosticScenario {
    var expectedOutcome: SignedInvestigationRuntimeMachineCaseOutcome {
        switch self {
        case .success:
            .succeeded
        case .cancellation:
            .cancelled
        case .timeout:
            .timedOut
        case .invalidEnvelope:
            .invalidEnvelopeBlocked
        case .identityMismatch:
            .identityMismatchBlocked
        case .transportLoss:
            .transportLossBlocked
        case .lifecycleRecovery:
            .lifecycleRecovered
        case .artifactCleanupFailure:
            .artifactCleanupRecovered
        }
    }

    var expectedControls: MachineCaseControls {
        switch self {
        case .success:
            MachineCaseControls(
                runStarted: true,
                turnAdmitted: true,
                finalEnvelopeAccepted: true,
                terminalBarrierSettled: true,
                artifactsRetired: true,
                localRuntimeDrained: true,
                recoveryAttempted: false,
                recoveryCompleted: false,
                reportPresent: true,
                denialsPresent: true,
                observationPresent: false
            )
        case .cancellation, .timeout, .invalidEnvelope:
            MachineCaseControls(
                runStarted: true,
                turnAdmitted: true,
                finalEnvelopeAccepted: false,
                terminalBarrierSettled: true,
                artifactsRetired: true,
                localRuntimeDrained: true,
                recoveryAttempted: false,
                recoveryCompleted: false,
                reportPresent: false,
                denialsPresent: false,
                observationPresent: true
            )
        case .identityMismatch:
            MachineCaseControls(
                runStarted: false,
                turnAdmitted: false,
                finalEnvelopeAccepted: false,
                terminalBarrierSettled: false,
                artifactsRetired: true,
                localRuntimeDrained: true,
                recoveryAttempted: false,
                recoveryCompleted: false,
                reportPresent: false,
                denialsPresent: false,
                observationPresent: true
            )
        case .transportLoss:
            MachineCaseControls(
                runStarted: true,
                turnAdmitted: true,
                finalEnvelopeAccepted: false,
                terminalBarrierSettled: false,
                artifactsRetired: true,
                localRuntimeDrained: true,
                recoveryAttempted: false,
                recoveryCompleted: false,
                reportPresent: false,
                denialsPresent: false,
                observationPresent: true
            )
        case .lifecycleRecovery, .artifactCleanupFailure:
            MachineCaseControls(
                runStarted: true,
                turnAdmitted: true,
                finalEnvelopeAccepted: false,
                terminalBarrierSettled: true,
                artifactsRetired: true,
                localRuntimeDrained: true,
                recoveryAttempted: true,
                recoveryCompleted: true,
                reportPresent: false,
                denialsPresent: false,
                observationPresent: true
            )
        }
    }
}

private func configurationMap(
    _ configurations:
        [SignedInvestigationRuntimeDiagnosticConfiguration]
) throws -> [
    SignedInvestigationRuntimeDiagnosticScenario:
        SignedInvestigationRuntimeDiagnosticConfiguration
] {
    guard
        configurations.count
            == SignedInvestigationRuntimeDiagnosticScenario
            .allCases.count,
        Set(configurations.map(\.scenario))
            == Set(
                SignedInvestigationRuntimeDiagnosticScenario.allCases
            ),
        Set(configurations.map(\.nonce)).count == configurations.count,
        configurationPathsAreUnique(configurations)
    else {
        throw SignedInvestigationRuntimeContractError
            .invalidConfiguration
    }
    return Dictionary(
        uniqueKeysWithValues: configurations.map {
            ($0.scenario, $0)
        }
    )
}

private func machineLifecycleObservationMap(
    _ observations:
        [SignedInvestigationRuntimeLifecycleResidueObservation]
) throws -> [
    SignedInvestigationRuntimeDiagnosticScenario:
        SignedInvestigationRuntimeLifecycleResidueObservation
] {
    guard
        observations.count
            == SignedInvestigationRuntimeDiagnosticScenario
                .allCases.count,
        Set(observations.map(\.record.scenario))
            == Set(
                SignedInvestigationRuntimeDiagnosticScenario.allCases
            )
    else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    return Dictionary(
        uniqueKeysWithValues: observations.map {
            ($0.record.scenario, $0)
        }
    )
}

private func configurationPathsAreUnique(
    _ configurations:
        [SignedInvestigationRuntimeDiagnosticConfiguration]
) -> Bool {
    let diagnosticRoots = configurations.map(\.diagnosticRootPath)
    let pathGroups = [
        diagnosticRoots,
        configurations.map(\.sourceRootPath),
        configurations.map(\.supportRootPath),
        configurations.map(\.runtimeRootPath),
        configurations.map(\.reportPath),
        configurations.map(\.storePath),
    ]
    let cohortRoots = Set(diagnosticRoots.map {
        URL(filePath: $0)
            .deletingLastPathComponent()
            .path
    })
    return pathGroups.allSatisfy {
        Set($0).count == configurations.count
    } && cohortRoots.count == 1
        && pairwiseMachinePathsDoNotOverlap(diagnosticRoots)
}

private func machineCohortRootPath(
    _ configurations:
        [SignedInvestigationRuntimeDiagnosticConfiguration]
) throws -> String {
    guard
        let first = configurations.first
    else {
        throw SignedInvestigationRuntimeContractError
            .invalidConfiguration
    }
    let cohortRoot = URL(filePath: first.diagnosticRootPath)
        .deletingLastPathComponent()
        .path
    guard configurations.allSatisfy({
        URL(filePath: $0.diagnosticRootPath)
            .deletingLastPathComponent()
            .path == cohortRoot
    }) else {
        throw SignedInvestigationRuntimeContractError
            .invalidConfiguration
    }
    return cohortRoot
}

private func pairwiseMachinePathsDoNotOverlap(
    _ paths: [String]
) -> Bool {
    for leftIndex in paths.indices {
        for rightIndex in paths.indices
        where rightIndex > leftIndex {
            let left = paths[leftIndex]
            let right = paths[rightIndex]
            if left == right
                || right.hasPrefix(left + "/")
                || left.hasPrefix(right + "/")
            {
                return false
            }
        }
    }
    return true
}

private struct MachineCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int? = nil

    init(_ value: String) {
        stringValue = value
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

private func strictMachineContainer(
    _ decoder: Decoder,
    keys: Set<String>,
    optionalKeys: Set<String> = []
) throws -> KeyedDecodingContainer<MachineCodingKey> {
    let container = try decoder.container(
        keyedBy: MachineCodingKey.self
    )
    let actualKeys = Set(container.allKeys.map(\.stringValue))
    guard
        optionalKeys.isSubset(of: keys),
        actualKeys.isSubset(of: keys),
        keys.subtracting(optionalKeys).isSubset(of: actualKeys)
    else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    return container
}

private func machineCanonicalSHA256<T: Encodable>(
    _ value: T
) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let digest = SHA256.hash(data: try encoder.encode(value))
    return digest.map { String(format: "%02x", $0) }.joined()
}

package extension SignedInvestigationCapabilityEvidenceReceipt {
    func machineEvidenceSHA256() throws -> String {
        try machineCanonicalSHA256(self)
    }
}

private func machineSHA256(_ value: String) -> Bool {
    value.utf8.count == 64
        && value.unicodeScalars.allSatisfy {
            (0x30...0x39).contains($0.value)
                || (0x61...0x66).contains($0.value)
        }
}

private func machineStableOptionalReasonKey(
    _ value: String?
) -> Bool {
    value.map {
        machineStableIdentifier($0, maximumBytes: 256)
    } ?? true
}

private func machineStableIdentifier(
    _ value: String,
    maximumBytes: Int
) -> Bool {
    !value.isEmpty
        && value.utf8.count <= maximumBytes
        && value.unicodeScalars.allSatisfy {
            (0x30...0x39).contains($0.value)
                || (0x41...0x5A).contains($0.value)
                || (0x61...0x7A).contains($0.value)
                || $0.value == 0x2D
                || $0.value == 0x2E
                || $0.value == 0x3A
                || $0.value == 0x5F
        }
}

private func machineResidueIsValid(
    _ residue: SignedInvestigationRuntimeResidue
) -> Bool {
    [
        residue.appProcessCount,
        residue.helperProcessCount,
        residue.workerProcessCount,
        residue.proxyProcessCount,
        residue.leaseCount,
        residue.runtimeArtifactCount,
    ].allSatisfy { (0...1_000_000).contains($0) }
}

func machineOwnerRegularFileSHA256(
    _ path: String,
    didRead: ((Int) throws -> Void)? = nil
) throws -> String {
    let descriptor = try machineOpenAbsoluteRegularFile(path)
    defer { close(descriptor) }
    return try machineOwnerRegularFileSHA256(
        descriptor: descriptor,
        didRead: didRead
    )
}

private func machineOwnerRegularFileSHA256(
    descriptor: Int32,
    maximumBytes: Int64 = 16 * 1_024 * 1_024,
    didRead: ((Int) throws -> Void)? = nil
) throws -> String {
    var initialInformation = stat()
    guard
        fstat(descriptor, &initialInformation) == 0,
        initialInformation.st_mode & S_IFMT == S_IFREG,
        initialInformation.st_uid == getuid(),
        initialInformation.st_mode & 0o777 == 0o600,
        initialInformation.st_nlink == 1,
        initialInformation.st_size > 0,
        initialInformation.st_size <= maximumBytes
    else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    let expectedBytes = Int(initialInformation.st_size)
    var hasher = SHA256()
    var buffer = [UInt8](repeating: 0, count: 16 * 1_024)
    var totalBytes = 0
    while totalBytes < expectedBytes {
        let requestedBytes = min(
            buffer.count,
            expectedBytes - totalBytes
        )
        let count = buffer.withUnsafeMutableBytes {
            Darwin.read(
                descriptor,
                $0.baseAddress,
                requestedBytes
            )
        }
        if count < 0 {
            if errno == EINTR {
                continue
            }
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        guard count > 0 else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        totalBytes += count
        hasher.update(data: Data(buffer.prefix(count)))
        try didRead?(totalBytes)
    }
    var extraByte: UInt8 = 0
    while true {
        let count = Darwin.read(descriptor, &extraByte, 1)
        if count < 0, errno == EINTR {
            continue
        }
        guard count == 0 else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        break
    }
    var finalInformation = stat()
    guard
        fstat(descriptor, &finalInformation) == 0,
        machineSameReadSnapshot(
            initialInformation,
            finalInformation
        )
    else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    return hasher.finalize()
        .map { String(format: "%02x", $0) }
        .joined()
}

private func machineSameReadSnapshot(
    _ initial: stat,
    _ final: stat
) -> Bool {
    initial.st_dev == final.st_dev
        && initial.st_ino == final.st_ino
        && initial.st_mode == final.st_mode
        && initial.st_nlink == final.st_nlink
        && initial.st_uid == final.st_uid
        && initial.st_gid == final.st_gid
        && initial.st_size == final.st_size
        && initial.st_mtimespec.tv_sec
            == final.st_mtimespec.tv_sec
        && initial.st_mtimespec.tv_nsec
            == final.st_mtimespec.tv_nsec
        && initial.st_ctimespec.tv_sec
            == final.st_ctimespec.tv_sec
        && initial.st_ctimespec.tv_nsec
            == final.st_ctimespec.tv_nsec
}

private struct MachineConfigurationObservation: Equatable {
    let runtimeArtifactSHA256: String
    let evidenceStoreSHA256: String
    let runtimeArtifactCount: Int
    let diagnosticRootIdentity: MachineObjectIdentity
    let objectIdentities: [MachineObjectIdentity]
}

private struct MachineObjectIdentity: Hashable {
    let device: UInt64
    let inode: UInt64
}

private let machineMaximumEvidenceStoreBytes: Int64 =
    1_073_741_824
private let machineMaximumObservedDirectoryEntries = 64

private func machineValidateConfigurationPaths(
    _ configuration:
        SignedInvestigationRuntimeDiagnosticConfiguration,
    cohortRootPath: String,
    cohortRootDescriptor: Int32
) throws -> MachineConfigurationObservation {
    let diagnosticRootDescriptor = try machineOpenDirectory(
        configuration.diagnosticRootPath,
        beneath: cohortRootPath,
        rootDescriptor: cohortRootDescriptor
    )
    defer { close(diagnosticRootDescriptor) }
    try machineValidatePrivateDirectory(diagnosticRootDescriptor)
    guard
        configuration.sourceRootPath
            == configuration.diagnosticRootPath + "/source",
        configuration.supportRootPath
            == configuration.diagnosticRootPath + "/support",
        configuration.runtimeRootPath
            == configuration.diagnosticRootPath + "/runtime",
        configuration.reportPath
            == configuration.diagnosticRootPath + "/report.json",
        configuration.storePath
            == configuration.supportRootPath
                + "/com.eriklee.stornaut/Evidence.sqlite"
    else {
        throw SignedInvestigationRuntimeContractError
            .invalidConfiguration
    }

    let sourceDescriptor = try machineOpenDirectoryComponent(
        "source",
        parentDescriptor: diagnosticRootDescriptor
    )
    defer { close(sourceDescriptor) }
    try machineValidatePrivateDirectory(sourceDescriptor)
    let supportDescriptor = try machineOpenDirectoryComponent(
        "support",
        parentDescriptor: diagnosticRootDescriptor
    )
    defer { close(supportDescriptor) }
    try machineValidatePrivateDirectory(supportDescriptor)
    let runtimeDescriptor = try machineOpenDirectoryComponent(
        "runtime",
        parentDescriptor: diagnosticRootDescriptor
    )
    defer { close(runtimeDescriptor) }
    try machineValidatePrivateDirectory(runtimeDescriptor)

    let reportDescriptor = try machineOpenRegularFileComponent(
        "report.json",
        parentDescriptor: diagnosticRootDescriptor
    )
    defer { close(reportDescriptor) }
    let runtimeArtifactSHA256 =
        try machineOwnerRegularFileSHA256(
            descriptor: reportDescriptor
        )

    let applicationSupportDescriptor =
        try machineOpenDirectoryComponent(
            "com.eriklee.stornaut",
            parentDescriptor: supportDescriptor
        )
    defer { close(applicationSupportDescriptor) }
    try machineValidatePrivateDirectory(
        applicationSupportDescriptor
    )
    let storeDescriptor = try machineOpenRegularFileComponent(
        "Evidence.sqlite",
        parentDescriptor: applicationSupportDescriptor
    )
    defer { close(storeDescriptor) }
    let evidenceStoreSHA256 =
        try machineOwnerRegularFileSHA256(
            descriptor: storeDescriptor,
            maximumBytes: machineMaximumEvidenceStoreBytes
        )
    let diagnosticRootIdentity =
        try machineObjectIdentity(
            descriptor: diagnosticRootDescriptor,
            expectedType: S_IFDIR
        )
    let sourceIdentity = try machineObjectIdentity(
        descriptor: sourceDescriptor,
        expectedType: S_IFDIR
    )
    let supportIdentity = try machineObjectIdentity(
        descriptor: supportDescriptor,
        expectedType: S_IFDIR
    )
    let runtimeIdentity = try machineObjectIdentity(
        descriptor: runtimeDescriptor,
        expectedType: S_IFDIR
    )
    let reportIdentity = try machineObjectIdentity(
        descriptor: reportDescriptor,
        expectedType: S_IFREG
    )
    let applicationSupportIdentity =
        try machineObjectIdentity(
            descriptor: applicationSupportDescriptor,
            expectedType: S_IFDIR
        )
    let storeIdentity = try machineObjectIdentity(
        descriptor: storeDescriptor,
        expectedType: S_IFREG
    )
    let diagnosticEntries = try machineDirectoryEntries(
        descriptor: diagnosticRootDescriptor
    )
    let sourceEntries = try machineDirectoryEntries(
        descriptor: sourceDescriptor
    )
    let supportEntries = try machineDirectoryEntries(
        descriptor: supportDescriptor
    )
    let runtimeEntries = try machineDirectoryEntries(
        descriptor: runtimeDescriptor
    )
    let applicationSupportEntries = try machineDirectoryEntries(
        descriptor: applicationSupportDescriptor
    )
    guard
        diagnosticEntries["source"] == sourceIdentity,
        diagnosticEntries["support"] == supportIdentity,
        diagnosticEntries["runtime"] == runtimeIdentity,
        diagnosticEntries["report.json"] == reportIdentity,
        supportEntries["com.eriklee.stornaut"]
            == applicationSupportIdentity,
        applicationSupportEntries["Evidence.sqlite"]
            == storeIdentity
    else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    let residueCounts = [
        diagnosticEntries.keys.filter {
            ![
                "source",
                "support",
                "runtime",
                "report.json",
            ].contains($0)
        }.count,
        sourceEntries.count,
        supportEntries.keys.filter {
            $0 != "com.eriklee.stornaut"
        }.count,
        runtimeEntries.count,
        applicationSupportEntries.keys.filter {
            $0 != "Evidence.sqlite"
        }.count,
    ]
    let runtimeArtifactCount = try residueCounts.reduce(0) {
        let result = $0.addingReportingOverflow($1)
        guard
            !result.overflow,
            result.partialValue
                <= machineMaximumObservedDirectoryEntries
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        return result.partialValue
    }
    return MachineConfigurationObservation(
        runtimeArtifactSHA256: runtimeArtifactSHA256,
        evidenceStoreSHA256: evidenceStoreSHA256,
        runtimeArtifactCount: runtimeArtifactCount,
        diagnosticRootIdentity: diagnosticRootIdentity,
        objectIdentities: [
            diagnosticRootIdentity,
            sourceIdentity,
            supportIdentity,
            runtimeIdentity,
            reportIdentity,
            applicationSupportIdentity,
            storeIdentity,
        ]
    )
}

private func machineValidateCohortRoot(
    descriptor: Int32,
    path: String,
    configurations:
        [SignedInvestigationRuntimeDiagnosticConfiguration],
    observations: [
        SignedInvestigationRuntimeDiagnosticScenario:
            MachineConfigurationObservation
    ]
) throws {
    let entries = try machineDirectoryEntries(descriptor: descriptor)
    var expected: [String: MachineObjectIdentity] = [:]
    for configuration in configurations {
        let components = try machineRelativePathComponents(
            configuration.diagnosticRootPath,
            beneath: path
        )
        guard
            components.count == 1,
            let observation = observations[configuration.scenario],
            expected.updateValue(
                observation.diagnosticRootIdentity,
                forKey: components[0]
            ) == nil
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
    }
    guard entries == expected else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
}

private func machineDirectoryEntries(
    descriptor: Int32
) throws -> [String: MachineObjectIdentity] {
    var initialInformation = stat()
    guard
        fstat(descriptor, &initialInformation) == 0,
        initialInformation.st_mode & S_IFMT == S_IFDIR
    else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    let enumerationDescriptor = openat(
        descriptor,
        ".",
        O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
    )
    guard enumerationDescriptor >= 0 else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    guard let directory = fdopendir(enumerationDescriptor) else {
        close(enumerationDescriptor)
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    defer { closedir(directory) }
    let directoryDescriptor = dirfd(directory)
    var entries: [String: MachineObjectIdentity] = [:]
    while true {
        errno = 0
        guard let entry = readdir(directory) else {
            guard errno == 0 else {
                throw SignedInvestigationRuntimeContractError
                    .invalidReport
            }
            break
        }
        let name = try machineDirectoryEntryName(entry)
        if name == "." || name == ".." {
            continue
        }
        guard
            entries.count < machineMaximumObservedDirectoryEntries
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        var information = stat()
        let result = name.withCString {
            fstatat(
                directoryDescriptor,
                $0,
                &information,
                AT_SYMLINK_NOFOLLOW
            )
        }
        guard
            result == 0,
            entries.updateValue(
                machineObjectIdentity(information),
                forKey: name
            ) == nil
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
    }
    var finalInformation = stat()
    guard
        fstat(descriptor, &finalInformation) == 0,
        machineSameReadSnapshot(
            initialInformation,
            finalInformation
        )
    else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    return entries
}

private func machineDirectoryEntryName(
    _ entry: UnsafePointer<dirent>
) throws -> String {
    guard
        let recordLengthOffset = MemoryLayout<dirent>.offset(
            of: \.d_reclen
        ),
        let nameLengthOffset = MemoryLayout<dirent>.offset(
            of: \.d_namlen
        ),
        let nameOffset = MemoryLayout<dirent>.offset(of: \.d_name)
    else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    let rawEntry = UnsafeRawPointer(entry)
    let recordLength = Int(
        rawEntry.load(
            fromByteOffset: recordLengthOffset,
            as: UInt16.self
        )
    )
    let nameLength = Int(
        rawEntry.load(
            fromByteOffset: nameLengthOffset,
            as: UInt16.self
        )
    )
    let nameCapacity = MemoryLayout.size(ofValue: dirent().d_name)
    guard
        nameLength > 0,
        nameLength < nameCapacity,
        recordLength <= MemoryLayout<dirent>.size,
        nameOffset + nameLength + 1 <= recordLength
    else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    let bytes = UnsafeBufferPointer(
        start: rawEntry
            .advanced(by: nameOffset)
            .assumingMemoryBound(to: UInt8.self),
        count: nameLength
    )
    guard
        !bytes.contains(0),
        rawEntry.load(
            fromByteOffset: nameOffset + nameLength,
            as: UInt8.self
        ) == 0,
        let name = String(validating: bytes, as: UTF8.self)
    else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    return name
}

private func machineObjectIdentity(
    descriptor: Int32,
    expectedType: mode_t
) throws -> MachineObjectIdentity {
    var information = stat()
    guard
        fstat(descriptor, &information) == 0,
        information.st_mode & S_IFMT == expectedType
    else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    return machineObjectIdentity(information)
}

private func machineObjectIdentity(
    _ information: stat
) -> MachineObjectIdentity {
    MachineObjectIdentity(
        device: UInt64(bitPattern: Int64(information.st_dev)),
        inode: UInt64(information.st_ino)
    )
}

private func machineOpenAbsoluteDirectory(
    _ path: String,
    requireOwnerPrivate: Bool
) throws -> Int32 {
    let components = try machineAbsolutePathComponents(path)
    var descriptor = open(
        "/",
        O_RDONLY | O_DIRECTORY | O_CLOEXEC
    )
    guard descriptor >= 0 else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    var privateOwnerRootObserved: Bool
    do {
        privateOwnerRootObserved =
            try machineValidateOpenedDirectory(
                descriptor,
                privateOwnerRootObserved: false
            )
    } catch {
        close(descriptor)
        throw error
    }
    for component in components {
        let next = component.withCString {
            openat(
                descriptor,
                $0,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard next >= 0 else {
            close(descriptor)
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        do {
            privateOwnerRootObserved =
                try machineValidateOpenedDirectory(
                    next,
                    privateOwnerRootObserved:
                        privateOwnerRootObserved
                )
        } catch {
            close(next)
            close(descriptor)
            throw error
        }
        close(descriptor)
        descriptor = next
    }
    guard
        !requireOwnerPrivate || privateOwnerRootObserved
    else {
        close(descriptor)
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    return descriptor
}

private func machineValidateOpenedDirectory(
    _ descriptor: Int32,
    privateOwnerRootObserved: Bool
) throws -> Bool {
    var information = stat()
    guard
        fstat(descriptor, &information) == 0,
        information.st_mode & S_IFMT == S_IFDIR
    else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    let isCurrentOwner = information.st_uid == getuid()
    let isPrivate = information.st_mode & 0o077 == 0
    if privateOwnerRootObserved {
        guard isCurrentOwner, isPrivate else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        return true
    }
    guard
        information.st_uid == 0 || isCurrentOwner,
        information.st_mode & 0o022 == 0
    else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    return isCurrentOwner && isPrivate
}

private func machineOpenAbsoluteRegularFile(
    _ path: String
) throws -> Int32 {
    let components = try machineAbsolutePathComponents(path)
    guard let fileName = components.last else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    let parentPath = "/"
        + components.dropLast().joined(separator: "/")
    let parentDescriptor = try machineOpenAbsoluteDirectory(
        parentPath.isEmpty ? "/" : parentPath,
        requireOwnerPrivate: false
    )
    defer { close(parentDescriptor) }
    let descriptor = fileName.withCString {
        openat(
            parentDescriptor,
            $0,
            O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW
        )
    }
    guard descriptor >= 0 else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    return descriptor
}

private func machineOpenDirectory(
    _ path: String,
    beneath rootPath: String,
    rootDescriptor: Int32
) throws -> Int32 {
    let components = try machineRelativePathComponents(
        path,
        beneath: rootPath
    )
    var descriptor = rootDescriptor
    var ownsDescriptor = false
    for component in components {
        let next = component.withCString {
            openat(
                descriptor,
                $0,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard next >= 0 else {
            if ownsDescriptor { close(descriptor) }
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        if ownsDescriptor { close(descriptor) }
        descriptor = next
        ownsDescriptor = true
    }
    guard ownsDescriptor else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    return descriptor
}

private func machineOpenDirectoryComponent(
    _ component: String,
    parentDescriptor: Int32
) throws -> Int32 {
    guard machineSafePathComponent(component) else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    let descriptor = component.withCString {
        openat(
            parentDescriptor,
            $0,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
    }
    guard descriptor >= 0 else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    return descriptor
}

private func machineOpenRegularFileComponent(
    _ component: String,
    parentDescriptor: Int32
) throws -> Int32 {
    guard machineSafePathComponent(component) else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    let descriptor = component.withCString {
        openat(
            parentDescriptor,
            $0,
            O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW
        )
    }
    guard descriptor >= 0 else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    return descriptor
}

private func machineValidatePrivateDirectory(
    _ descriptor: Int32
) throws {
    var information = stat()
    guard
        fstat(descriptor, &information) == 0,
        information.st_mode & S_IFMT == S_IFDIR,
        information.st_uid == getuid(),
        information.st_mode & 0o077 == 0
    else {
        throw SignedInvestigationRuntimeContractError
            .invalidConfiguration
    }
}

private func machineSafePathComponent(_ value: String) -> Bool {
    !value.isEmpty
        && value != "."
        && value != ".."
        && !value.contains("/")
        && !value.contains("\n")
        && !value.contains("\r")
        && !value.contains("\0")
        && value.utf8.count <= 255
}

private func machineAbsolutePathComponents(
    _ path: String
) throws -> [String] {
    guard
        path.hasPrefix("/"),
        path != "/",
        !path.hasSuffix("/"),
        !path.contains("//"),
        !path.contains("\n"),
        !path.contains("\r"),
        !path.contains("\0"),
        path.utf8.count <= 4_096
    else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    let components = (path as NSString).pathComponents
    guard
        components.first == "/",
        components.dropFirst().allSatisfy({
            !$0.isEmpty && $0 != "." && $0 != ".."
        })
    else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    return Array(components.dropFirst())
}

private func machineRelativePathComponents(
    _ path: String,
    beneath rootPath: String
) throws -> [String] {
    _ = try machineAbsolutePathComponents(rootPath)
    _ = try machineAbsolutePathComponents(path)
    guard path.hasPrefix(rootPath + "/") else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    let relative = String(path.dropFirst(rootPath.count + 1))
    let components = relative.split(separator: "/").map(String.init)
    guard
        !components.isEmpty,
        components.allSatisfy({
            !$0.isEmpty && $0 != "." && $0 != ".."
        })
    else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    return components
}
