import Darwin
import CryptoKit
import Foundation
import StornautCodex
import StornautCore

public enum SignedInvestigationRuntimeContractError:
    Error,
    Sendable,
    Equatable
{
    case invalidConfiguration
    case invalidReport
    case bindingMismatch
}

public enum SignedInvestigationRuntimeDiagnosticScenario:
    String,
    Codable,
    Sendable,
    Equatable,
    Hashable,
    CaseIterable
{
    case success
    case cancellation
    case timeout
    case invalidEnvelope
    case identityMismatch
    case transportLoss
    case lifecycleRecovery
    case artifactCleanupFailure
}

public struct SignedInvestigationRuntimeMachineDriverBinding:
    Codable,
    Sendable,
    Equatable
{
    public static let schemaVersion = 1
    public static let requiredSigningIdentifier =
        "com.eriklee.stornaut.investigation.machine-driver"
    public static let requiredMachineClaimServiceIdentifier =
        "com.eriklee.stornaut.lifecycle.machine-claim"

    public let schemaVersion: Int
    public let executableSHA256: String
    public let signingIdentifier: String
    public let designatedRequirementSHA256: String
    public let codeDirectoryHash: String
    public let machineClaimServiceIdentifier: String

    public init(
        executableSHA256: String,
        signingIdentifier: String,
        designatedRequirementSHA256: String,
        codeDirectoryHash: String,
        machineClaimServiceIdentifier: String
    ) throws {
        guard
            lowercaseHex(executableSHA256, count: 64),
            signingIdentifier == Self.requiredSigningIdentifier,
            lowercaseHex(designatedRequirementSHA256, count: 64),
            (lowercaseHex(codeDirectoryHash, count: 40)
                || lowercaseHex(codeDirectoryHash, count: 64)),
            machineClaimServiceIdentifier
                == Self.requiredMachineClaimServiceIdentifier
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        schemaVersion = Self.schemaVersion
        self.executableSHA256 = executableSHA256
        self.signingIdentifier = signingIdentifier
        self.designatedRequirementSHA256 =
            designatedRequirementSHA256
        self.codeDirectoryHash = codeDirectoryHash
        self.machineClaimServiceIdentifier =
            machineClaimServiceIdentifier
    }

    public init(from decoder: Decoder) throws {
        let container = try strictSignedRuntimeContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        guard try container.decode(
            Int.self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.schemaVersion.rawValue
            )
        ) == Self.schemaVersion else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        try self.init(
            executableSHA256: container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.executableSHA256.rawValue
                )
            ),
            signingIdentifier: container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.signingIdentifier.rawValue
                )
            ),
            designatedRequirementSHA256: container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.designatedRequirementSHA256.rawValue
                )
            ),
            codeDirectoryHash: container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.codeDirectoryHash.rawValue
                )
            ),
            machineClaimServiceIdentifier: container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.machineClaimServiceIdentifier.rawValue
                )
            )
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case executableSHA256
        case signingIdentifier
        case designatedRequirementSHA256
        case codeDirectoryHash
        case machineClaimServiceIdentifier
    }
}

public struct SignedInvestigationRuntimeBinding:
    Codable,
    Sendable,
    Equatable
{
    public static let schemaVersion = 2

    public let schemaVersion: Int
    public let repositoryHEAD: String
    public let sourceFingerprintSHA256: String
    public let appExecutableSHA256: String
    public let helperExecutableSHA256: String
    public let runtimeReceiptSHA256: String
    public let promptSHA256: String
    public let envelopeSchemaSHA256: String
    public let facadeSHA256: String
    public let codexExecutableSHA256: String
    public let appBundleIdentifier: String
    public let helperServiceIdentifier: String
    public let machineDriver:
        SignedInvestigationRuntimeMachineDriverBinding

    public init(
        repositoryHEAD: String,
        sourceFingerprintSHA256: String,
        appExecutableSHA256: String,
        helperExecutableSHA256: String,
        runtimeReceiptSHA256: String,
        promptSHA256: String,
        envelopeSchemaSHA256: String,
        facadeSHA256: String,
        codexExecutableSHA256: String,
        appBundleIdentifier: String,
        helperServiceIdentifier: String,
        machineDriver: SignedInvestigationRuntimeMachineDriverBinding
    ) {
        schemaVersion = Self.schemaVersion
        self.repositoryHEAD = repositoryHEAD
        self.sourceFingerprintSHA256 = sourceFingerprintSHA256
        self.appExecutableSHA256 = appExecutableSHA256
        self.helperExecutableSHA256 = helperExecutableSHA256
        self.runtimeReceiptSHA256 = runtimeReceiptSHA256
        self.promptSHA256 = promptSHA256
        self.envelopeSchemaSHA256 = envelopeSchemaSHA256
        self.facadeSHA256 = facadeSHA256
        self.codexExecutableSHA256 = codexExecutableSHA256
        self.appBundleIdentifier = appBundleIdentifier
        self.helperServiceIdentifier = helperServiceIdentifier
        self.machineDriver = machineDriver
    }

    public init(from decoder: Decoder) throws {
        let container = try strictSignedRuntimeContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        guard try container.decode(
            Int.self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.schemaVersion.rawValue
            )
        ) == Self.schemaVersion else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        self.init(
            repositoryHEAD: try container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.repositoryHEAD.rawValue
                )
            ),
            sourceFingerprintSHA256: try container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.sourceFingerprintSHA256.rawValue
                )
            ),
            appExecutableSHA256: try container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.appExecutableSHA256.rawValue
                )
            ),
            helperExecutableSHA256: try container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.helperExecutableSHA256.rawValue
                )
            ),
            runtimeReceiptSHA256: try container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.runtimeReceiptSHA256.rawValue
                )
            ),
            promptSHA256: try container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.promptSHA256.rawValue
                )
            ),
            envelopeSchemaSHA256: try container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.envelopeSchemaSHA256.rawValue
                )
            ),
            facadeSHA256: try container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.facadeSHA256.rawValue
                )
            ),
            codexExecutableSHA256: try container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.codexExecutableSHA256.rawValue
                )
            ),
            appBundleIdentifier: try container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.appBundleIdentifier.rawValue
                )
            ),
            helperServiceIdentifier: try container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.helperServiceIdentifier.rawValue
                )
            ),
            machineDriver: try container.decode(
                SignedInvestigationRuntimeMachineDriverBinding.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.machineDriver.rawValue
                )
            )
        )
        guard isValid else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
    }

    package var isValid: Bool {
        lowercaseHex(repositoryHEAD, count: 40)
            && [
                sourceFingerprintSHA256,
                appExecutableSHA256,
                helperExecutableSHA256,
                runtimeReceiptSHA256,
                promptSHA256,
                envelopeSchemaSHA256,
                facadeSHA256,
                codexExecutableSHA256,
            ].allSatisfy { lowercaseHex($0, count: 64) }
            && appBundleIdentifier == "com.eriklee.stornaut"
            && helperServiceIdentifier
                == "com.eriklee.stornaut.lifecycle"
            && machineDriver.signingIdentifier
                == SignedInvestigationRuntimeMachineDriverBinding
                    .requiredSigningIdentifier
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case repositoryHEAD
        case sourceFingerprintSHA256
        case appExecutableSHA256
        case helperExecutableSHA256
        case runtimeReceiptSHA256
        case promptSHA256
        case envelopeSchemaSHA256
        case facadeSHA256
        case codexExecutableSHA256
        case appBundleIdentifier
        case helperServiceIdentifier
        case machineDriver
    }
}

public struct SignedInvestigationRuntimeDiagnosticConfiguration:
    Codable,
    Sendable,
    Equatable
{
    public static let schemaVersion = 3
    public static let requiredOptIn =
        "I authorize one bounded disposable read-only Stornaut Investigation diagnostic."

    public let schemaVersion: Int
    public let nonce: UUID
    public let scenario: SignedInvestigationRuntimeDiagnosticScenario
    public let optIn: String
    public let diagnosticRootPath: String
    public let sourceRootPath: String
    public let supportRootPath: String
    public let runtimeRootPath: String
    public let reportPath: String
    public let storePath: String
    public let binding: SignedInvestigationRuntimeBinding
    public let expectedModel: CodexRuntimeModel
    public let expectedProvider: CodexRuntimeProvider
    public let validBefore: Date
    public let maximumWallClockSeconds: Int
    public let maximumTurns: Int
    public let maximumProbeCalls: Int
    public let maximumContextBytes: Int

    public init(
        nonce: UUID,
        scenario: SignedInvestigationRuntimeDiagnosticScenario,
        optIn: String,
        diagnosticRootPath: String,
        sourceRootPath: String,
        supportRootPath: String,
        runtimeRootPath: String,
        reportPath: String,
        storePath: String,
        binding: SignedInvestigationRuntimeBinding,
        expectedModel: CodexRuntimeModel,
        expectedProvider: CodexRuntimeProvider,
        validBefore: Date,
        maximumWallClockSeconds: Int,
        maximumTurns: Int,
        maximumProbeCalls: Int,
        maximumContextBytes: Int,
        now: Date
    ) throws {
        schemaVersion = Self.schemaVersion
        self.nonce = nonce
        self.scenario = scenario
        self.optIn = optIn
        self.diagnosticRootPath = diagnosticRootPath
        self.sourceRootPath = sourceRootPath
        self.supportRootPath = supportRootPath
        self.runtimeRootPath = runtimeRootPath
        self.reportPath = reportPath
        self.storePath = storePath
        self.binding = binding
        self.expectedModel = expectedModel
        self.expectedProvider = expectedProvider
        self.validBefore = validBefore
        self.maximumWallClockSeconds = maximumWallClockSeconds
        self.maximumTurns = maximumTurns
        self.maximumProbeCalls = maximumProbeCalls
        self.maximumContextBytes = maximumContextBytes
        try validate(now: now)
    }

    public static func decodeValidated(
        from data: Data,
        now: Date
    ) throws -> Self {
        guard data.count <= 64 * 1_024 else {
            throw SignedInvestigationRuntimeContractError
                .invalidConfiguration
        }
        let decoder = JSONDecoder()
        do {
            let decoded = try decoder.decode(Self.self, from: data)
            try decoded.validate(now: now)
            return decoded
        } catch {
            throw SignedInvestigationRuntimeContractError
                .invalidConfiguration
        }
    }

    public func canonicalJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    public func capabilityEvidenceBindingSHA256() throws -> String {
        try canonicalCapabilityEvidenceBindingSHA256(
            schemaVersion: schemaVersion,
            nonce: nonce,
            scenario: scenario,
            binding: binding,
            expectedModel: expectedModel,
            expectedProvider: expectedProvider
        )
    }

    public func machineConfigurationSHA256() throws -> String {
        try canonicalSHA256(self)
    }

    public init(from decoder: Decoder) throws {
        try self.init(
            decoder: decoder,
            outputs: .vacant
        )
    }

    package init(
        completedOutputsFrom decoder: Decoder
    ) throws {
        try self.init(
            decoder: decoder,
            outputs: .ownerRegularFile
        )
    }

    private init(
        decoder: Decoder,
        outputs: OutputPathExpectation
    ) throws {
        let container = try strictSignedRuntimeContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue)),
            error: .invalidConfiguration
        )
        let schemaVersion = try container.decode(
            Int.self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.schemaVersion.rawValue
            )
        )
        guard schemaVersion == Self.schemaVersion else {
            throw SignedInvestigationRuntimeContractError
                .invalidConfiguration
        }
        self.schemaVersion = schemaVersion
        nonce = try container.decode(
            UUID.self,
            forKey: SignedRuntimeCodingKey(CodingKeys.nonce.rawValue)
        )
        scenario = try container.decode(
            SignedInvestigationRuntimeDiagnosticScenario.self,
            forKey: SignedRuntimeCodingKey(CodingKeys.scenario.rawValue)
        )
        optIn = try container.decode(
            String.self,
            forKey: SignedRuntimeCodingKey(CodingKeys.optIn.rawValue)
        )
        diagnosticRootPath = try container.decode(
            String.self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.diagnosticRootPath.rawValue
            )
        )
        sourceRootPath = try container.decode(
            String.self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.sourceRootPath.rawValue
            )
        )
        supportRootPath = try container.decode(
            String.self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.supportRootPath.rawValue
            )
        )
        runtimeRootPath = try container.decode(
            String.self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.runtimeRootPath.rawValue
            )
        )
        reportPath = try container.decode(
            String.self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.reportPath.rawValue
            )
        )
        storePath = try container.decode(
            String.self,
            forKey: SignedRuntimeCodingKey(CodingKeys.storePath.rawValue)
        )
        binding = try container.decode(
            SignedInvestigationRuntimeBinding.self,
            forKey: SignedRuntimeCodingKey(CodingKeys.binding.rawValue)
        )
        expectedModel = try container.decode(
            CodexRuntimeModel.self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.expectedModel.rawValue
            )
        )
        expectedProvider = try container.decode(
            CodexRuntimeProvider.self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.expectedProvider.rawValue
            )
        )
        validBefore = try container.decode(
            Date.self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.validBefore.rawValue
            )
        )
        maximumWallClockSeconds = try container.decode(
            Int.self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.maximumWallClockSeconds.rawValue
            )
        )
        maximumTurns = try container.decode(
            Int.self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.maximumTurns.rawValue
            )
        )
        maximumProbeCalls = try container.decode(
            Int.self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.maximumProbeCalls.rawValue
            )
        )
        maximumContextBytes = try container.decode(
            Int.self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.maximumContextBytes.rawValue
            )
        )
        try validate(now: nil, outputs: outputs)
    }

    package func validate(
        now: Date?,
        outputs: OutputPathExpectation = .vacant
    ) throws {
        guard
            schemaVersion == Self.schemaVersion,
            optIn == Self.requiredOptIn,
            binding.isValid,
            expectedModel == .gpt56Luna,
            expectedProvider == .openAI,
            (1...140).contains(maximumWallClockSeconds),
            (1...3).contains(maximumTurns),
            (1...16).contains(maximumProbeCalls),
            (1...1_048_576).contains(maximumContextBytes),
            validBefore.timeIntervalSince1970.isFinite
        else {
            throw SignedInvestigationRuntimeContractError
                .invalidConfiguration
        }
        if let now {
            guard
                validBefore > now,
                validBefore.timeIntervalSince(now) <= 900
            else {
                throw SignedInvestigationRuntimeContractError
                    .invalidConfiguration
            }
        }
        let directoryPaths = [
            diagnosticRootPath,
            sourceRootPath,
            supportRootPath,
            runtimeRootPath,
        ]
        let filePaths = [reportPath, storePath]
        let outputPathsValid = filePaths.allSatisfy { path in
            switch outputs {
            case .vacant:
                return pathDoesNotExistWithoutSymlink(path)
            case .ownerRegularFile:
                return ownerFileWithoutSymlink(path)
            }
        }
        guard
            directoryPaths.allSatisfy(validAbsolutePath),
            filePaths.allSatisfy(validAbsolutePath),
            Set(directoryPaths).count == directoryPaths.count,
            Set(filePaths).count == filePaths.count,
            Set(directoryPaths).isDisjoint(with: Set(filePaths)),
            directoryPaths.allSatisfy(ownerDirectoryWithoutSymlink),
            outputPathsValid,
            sourceRootPath != supportRootPath,
            sourceRootPath != runtimeRootPath,
            supportRootPath != runtimeRootPath,
            containsPath(diagnosticRootPath, sourceRootPath),
            containsPath(diagnosticRootPath, supportRootPath),
            containsPath(diagnosticRootPath, runtimeRootPath),
            containsPath(diagnosticRootPath, reportPath),
            containsPath(diagnosticRootPath, storePath),
            storePath
                == supportRootPath
                    + "/com.eriklee.stornaut/Evidence.sqlite",
            !pathsOverlap(sourceRootPath, supportRootPath),
            !pathsOverlap(sourceRootPath, runtimeRootPath),
            !pathsOverlap(supportRootPath, runtimeRootPath)
        else {
            throw SignedInvestigationRuntimeContractError
                .invalidConfiguration
        }
    }

    package enum OutputPathExpectation {
        case vacant
        case ownerRegularFile
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case nonce
        case scenario
        case optIn
        case diagnosticRootPath
        case sourceRootPath
        case supportRootPath
        case runtimeRootPath
        case reportPath
        case storePath
        case binding
        case expectedModel
        case expectedProvider
        case validBefore
        case maximumWallClockSeconds
        case maximumTurns
        case maximumProbeCalls
        case maximumContextBytes
    }
}

public enum SignedInvestigationRuntimeDenialKind:
    String,
    Codable,
    Sendable,
    Equatable,
    Hashable,
    CaseIterable
{
    case userDataWrite
    case descendantUserDataWrite
    case userDataRename
    case userDataRemove
    case ipv4LoopbackBypass
    case ipv6LoopbackBypass
    case privateLinkLocalReservedNetwork
    case localPrivateDNS
    case unixSocket
    case cleanupAuthority
    case policyExecutorXPC
    case managedProxyBypass

    public static let required = Set(allCases)
}

public struct SignedInvestigationRuntimeDenialEvidence:
    Codable,
    Sendable,
    Equatable
{
    public let kind: SignedInvestigationRuntimeDenialKind
    public let attempted: Bool
    public let contained: Bool
    public let controlReasonKey: String?
    public let failureReasonKey: String?

    public init(
        kind: SignedInvestigationRuntimeDenialKind,
        attempted: Bool,
        contained: Bool,
        controlReasonKey: String?,
        failureReasonKey: String?
    ) throws {
        guard
            !contained || attempted,
            stableReasonKey(controlReasonKey),
            stableReasonKey(failureReasonKey),
            contained == (controlReasonKey != nil),
            contained == (failureReasonKey == nil)
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        self.kind = kind
        self.attempted = attempted
        self.contained = contained
        self.controlReasonKey = controlReasonKey
        self.failureReasonKey = failureReasonKey
    }

    public init(from decoder: Decoder) throws {
        let container = try strictSignedRuntimeContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue)),
            optionalKeys: [
                CodingKeys.controlReasonKey.rawValue,
                CodingKeys.failureReasonKey.rawValue,
            ]
        )
        try self.init(
            kind: container.decode(
                SignedInvestigationRuntimeDenialKind.self,
                forKey: SignedRuntimeCodingKey(CodingKeys.kind.rawValue)
            ),
            attempted: container.decode(
                Bool.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.attempted.rawValue
                )
            ),
            contained: container.decode(
                Bool.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.contained.rawValue
                )
            ),
            controlReasonKey: container.decodeIfPresent(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.controlReasonKey.rawValue
                )
            ),
            failureReasonKey: container.decodeIfPresent(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.failureReasonKey.rawValue
                )
            )
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case attempted
        case contained
        case controlReasonKey
        case failureReasonKey
    }
}

public struct SignedInvestigationProductionEvidence:
    Codable,
    Sendable,
    Equatable
{
    public let investigationID: InvestigationID
    public let runID: InvestigationRunID
    public let reportID: InvestigationReportID
    public let sourceFingerprint: InvestigationFingerprint
    public let planFingerprint: InvestigationFingerprint
    public let finalEnvelopeAccepted: Bool
    public let terminalBarrierSettled: Bool
    public let artifactsRetired: Bool
    public let localRuntimeDrained: Bool
    public let failureReasonKey: String?

    public init(
        investigationID: InvestigationID,
        runID: InvestigationRunID,
        reportID: InvestigationReportID,
        sourceFingerprint: InvestigationFingerprint,
        planFingerprint: InvestigationFingerprint,
        finalEnvelopeAccepted: Bool,
        terminalBarrierSettled: Bool,
        artifactsRetired: Bool,
        localRuntimeDrained: Bool,
        failureReasonKey: String?
    ) {
        self.investigationID = investigationID
        self.runID = runID
        self.reportID = reportID
        self.sourceFingerprint = sourceFingerprint
        self.planFingerprint = planFingerprint
        self.finalEnvelopeAccepted = finalEnvelopeAccepted
        self.terminalBarrierSettled = terminalBarrierSettled
        self.artifactsRetired = artifactsRetired
        self.localRuntimeDrained = localRuntimeDrained
        self.failureReasonKey = failureReasonKey
    }

    public init(from decoder: Decoder) throws {
        let container = try strictSignedRuntimeContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue)),
            optionalKeys: [CodingKeys.failureReasonKey.rawValue]
        )
        self.init(
            investigationID: try container.decode(
                InvestigationID.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.investigationID.rawValue
                )
            ),
            runID: try container.decode(
                InvestigationRunID.self,
                forKey: SignedRuntimeCodingKey(CodingKeys.runID.rawValue)
            ),
            reportID: try container.decode(
                InvestigationReportID.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.reportID.rawValue
                )
            ),
            sourceFingerprint: try container.decode(
                InvestigationFingerprint.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.sourceFingerprint.rawValue
                )
            ),
            planFingerprint: try container.decode(
                InvestigationFingerprint.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.planFingerprint.rawValue
                )
            ),
            finalEnvelopeAccepted: try container.decode(
                Bool.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.finalEnvelopeAccepted.rawValue
                )
            ),
            terminalBarrierSettled: try container.decode(
                Bool.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.terminalBarrierSettled.rawValue
                )
            ),
            artifactsRetired: try container.decode(
                Bool.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.artifactsRetired.rawValue
                )
            ),
            localRuntimeDrained: try container.decode(
                Bool.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.localRuntimeDrained.rawValue
                )
            ),
            failureReasonKey: try container.decodeIfPresent(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.failureReasonKey.rawValue
                )
            )
        )
        guard isValid else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
    }

    package var isReady: Bool {
        finalEnvelopeAccepted
            && terminalBarrierSettled
            && artifactsRetired
            && localRuntimeDrained
            && failureReasonKey == nil
    }

    package var isValid: Bool {
        let controlsReady = finalEnvelopeAccepted
            && terminalBarrierSettled
            && artifactsRetired
            && localRuntimeDrained
        return stableReasonKey(failureReasonKey)
            && controlsReady == (failureReasonKey == nil)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case investigationID
        case runID
        case reportID
        case sourceFingerprint
        case planFingerprint
        case finalEnvelopeAccepted
        case terminalBarrierSettled
        case artifactsRetired
        case localRuntimeDrained
        case failureReasonKey
    }
}

public struct SignedInvestigationRuntimeResidue:
    Codable,
    Sendable,
    Equatable
{
    public let appProcessCount: Int
    public let helperProcessCount: Int
    public let workerProcessCount: Int
    public let proxyProcessCount: Int
    public let leaseCount: Int
    public let runtimeArtifactCount: Int

    public init(
        appProcessCount: Int,
        helperProcessCount: Int,
        workerProcessCount: Int,
        proxyProcessCount: Int,
        leaseCount: Int,
        runtimeArtifactCount: Int
    ) {
        self.appProcessCount = appProcessCount
        self.helperProcessCount = helperProcessCount
        self.workerProcessCount = workerProcessCount
        self.proxyProcessCount = proxyProcessCount
        self.leaseCount = leaseCount
        self.runtimeArtifactCount = runtimeArtifactCount
    }

    public init(from decoder: Decoder) throws {
        let container = try strictSignedRuntimeContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        self.init(
            appProcessCount: try container.decode(
                Int.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.appProcessCount.rawValue
                )
            ),
            helperProcessCount: try container.decode(
                Int.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.helperProcessCount.rawValue
                )
            ),
            workerProcessCount: try container.decode(
                Int.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.workerProcessCount.rawValue
                )
            ),
            proxyProcessCount: try container.decode(
                Int.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.proxyProcessCount.rawValue
                )
            ),
            leaseCount: try container.decode(
                Int.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.leaseCount.rawValue
                )
            ),
            runtimeArtifactCount: try container.decode(
                Int.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.runtimeArtifactCount.rawValue
                )
            )
        )
        guard isValid else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
    }

    public var isZero: Bool {
        counts.allSatisfy { $0 == 0 }
    }

    package var isValid: Bool {
        counts.allSatisfy { (0...1_000_000).contains($0) }
    }

    private var counts: [Int] {
        [
            appProcessCount,
            helperProcessCount,
            workerProcessCount,
            proxyProcessCount,
            leaseCount,
            runtimeArtifactCount,
        ]
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case appProcessCount
        case helperProcessCount
        case workerProcessCount
        case proxyProcessCount
        case leaseCount
        case runtimeArtifactCount
    }
}

public enum SignedInvestigationRuntimeVerdict:
    Codable,
    Sendable,
    Equatable
{
    case signedInvestigationRuntimeReady
    case evidenceContractValidatedMachineAdmissionPending
    case signedInvestigationRuntimeBlocked(reasonKeys: [String])
    case signedInvestigationRuntimeFailed(reasonKeys: [String])
}

package enum SignedInvestigationRuntimeVerdictMode: Sendable {
    case evaluate
    case machineAdmissionPending
}

public struct SignedInvestigationCapabilityEvidenceReceipt:
    Codable,
    Sendable,
    Equatable
{
    public static let schemaVersion = 4

    public let schemaVersion: Int
    public let nonce: UUID
    public let scenario: SignedInvestigationRuntimeDiagnosticScenario
    public let binding: SignedInvestigationRuntimeBinding
    public let completedAt: Date
    public let metadataSHA256: String
    public let workerSHA256: String
    public let lifecycleSHA256: String
    public let repositorySHA256: String
    public let reportSHA256: String
    public let report: CapabilityRuntimeDiagnosticReport

    package init(
        configuration:
            SignedInvestigationRuntimeDiagnosticConfiguration,
        metadata: CapabilityRuntimeDiagnosticMetadata,
        worker: CapabilityRuntimeWorkerEvidence,
        lifecycleIntegrity: [CapabilityRuntimeIntegrityEvidence],
        repository: CapabilityRuntimeRepositoryEvidence
    ) throws {
        guard
            worker.investigationID == configuration.nonce,
            worker.evidenceBindingSHA256
                == (try configuration.capabilityEvidenceBindingSHA256())
        else {
            throw SignedInvestigationRuntimeContractError.bindingMismatch
        }
        let lifecycle = try CapabilityRuntimeLifecycleEvidence(
            integrity: lifecycleIntegrity
        )
        let report = try CapabilityRuntimeDiagnosticVerifier()
            .assembleSignedRuntimeReport(
                metadata: metadata,
                worker: worker,
                lifecycleIntegrity: lifecycle.integrity,
                repository: repository
            )
        try self.init(
            nonce: configuration.nonce,
            scenario: configuration.scenario,
            binding: configuration.binding,
            completedAt: worker.completedAt,
            metadataSHA256: try canonicalSHA256(metadata),
            workerSHA256: try canonicalSHA256(worker),
            lifecycleSHA256: try canonicalSHA256(lifecycle),
            repositorySHA256: try canonicalSHA256(repository),
            report: report
        )
    }

    private init(
        nonce: UUID,
        scenario: SignedInvestigationRuntimeDiagnosticScenario,
        binding: SignedInvestigationRuntimeBinding,
        completedAt: Date,
        metadataSHA256: String,
        workerSHA256: String,
        lifecycleSHA256: String,
        repositorySHA256: String,
        report: CapabilityRuntimeDiagnosticReport
    ) throws {
        let report = try revalidatedCapabilityReport(report)
        let expectedComponentHashes = try Self.componentHashes(
            nonce: nonce,
            scenario: scenario,
            binding: binding,
            completedAt: completedAt,
            report: report
        )
        guard
            binding.isValid,
            completedAt.timeIntervalSince1970.isFinite,
            metadataSHA256 == expectedComponentHashes.metadata,
            workerSHA256 == expectedComponentHashes.worker,
            lifecycleSHA256 == expectedComponentHashes.lifecycle,
            repositorySHA256 == expectedComponentHashes.repository,
            report.metadata.appBundleIdentifier
                == binding.appBundleIdentifier,
            report.metadata.appExecutableSHA256
                == binding.appExecutableSHA256,
            report.metadata.codexExecutableSHA256
                == binding.codexExecutableSHA256,
            report.metadata.model == .gpt56Luna,
            report.metadata.provider == .openAI
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        schemaVersion = Self.schemaVersion
        self.nonce = nonce
        self.scenario = scenario
        self.binding = binding
        self.completedAt = completedAt
        self.metadataSHA256 = metadataSHA256
        self.workerSHA256 = workerSHA256
        self.lifecycleSHA256 = lifecycleSHA256
        self.repositorySHA256 = repositorySHA256
        reportSHA256 = try capabilityReportSHA256(report)
        self.report = report
    }

    private static func componentHashes(
        nonce: UUID,
        scenario: SignedInvestigationRuntimeDiagnosticScenario,
        binding: SignedInvestigationRuntimeBinding,
        completedAt: Date,
        report: CapabilityRuntimeDiagnosticReport
    ) throws -> (
        metadata: String,
        worker: String,
        lifecycle: String,
        repository: String
    ) {
        let worker = try CapabilityRuntimeWorkerEvidence(
            investigationID: nonce,
            evidenceBindingSHA256:
                canonicalCapabilityEvidenceBindingSHA256(
                    schemaVersion:
                        SignedInvestigationRuntimeDiagnosticConfiguration
                            .schemaVersion,
                    nonce: nonce,
                    scenario: scenario,
                    binding: binding,
                    expectedModel: report.metadata.model,
                    expectedProvider: report.metadata.provider
                ),
            codexVersion: report.metadata.codexVersion,
            codexExecutableSHA256:
                report.metadata.codexExecutableSHA256,
            provider: report.metadata.provider,
            publicEndpointHosts: report.metadata.publicEndpointHosts,
            syntheticFixtureSHA256s:
                report.metadata.syntheticFixtureSHA256s,
            sanitizedEventCategories:
                report.metadata.sanitizedEventCategories,
            durationMilliseconds: report.metadata.durationMilliseconds,
            completedAt: completedAt,
            capabilities: report.capabilities,
            integrity: report.integrity.filter {
                CapabilityRuntimeWorkerEvidence
                    .allowedIntegrityProperties
                    .contains($0.property)
            }
        )
        let lifecycle = try CapabilityRuntimeLifecycleEvidence(
            integrity: report.integrity.filter {
                CapabilityRuntimeLifecycleEvidence
                    .allowedIntegrityProperties
                    .contains($0.property)
            }
        )
        let repository = try CapabilityRuntimeRepositoryEvidence(
            integrity: report.integrity.filter {
                $0.property == .noExecutorReachability
            }
        )
        return (
            metadata: try canonicalSHA256(report.metadata),
            worker: try canonicalSHA256(worker),
            lifecycle: try canonicalSHA256(lifecycle),
            repository: try canonicalSHA256(repository)
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try strictSignedRuntimeContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let schemaVersion = try container.decode(
            Int.self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.schemaVersion.rawValue
            )
        )
        guard schemaVersion == Self.schemaVersion else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        let decodedHash = try container.decode(
            String.self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.reportSHA256.rawValue
            )
        )
        try self.init(
            nonce: container.decode(
                UUID.self,
                forKey: SignedRuntimeCodingKey(CodingKeys.nonce.rawValue)
            ),
            scenario: container.decode(
                SignedInvestigationRuntimeDiagnosticScenario.self,
                forKey: SignedRuntimeCodingKey(CodingKeys.scenario.rawValue)
            ),
            binding: container.decode(
                SignedInvestigationRuntimeBinding.self,
                forKey: SignedRuntimeCodingKey(CodingKeys.binding.rawValue)
            ),
            completedAt: container.decode(
                Date.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.completedAt.rawValue
                )
            ),
            metadataSHA256: container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.metadataSHA256.rawValue
                )
            ),
            workerSHA256: container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.workerSHA256.rawValue
                )
            ),
            lifecycleSHA256: container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.lifecycleSHA256.rawValue
                )
            ),
            repositorySHA256: container.decode(
                String.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.repositorySHA256.rawValue
                )
            ),
            report: container.decode(
                StrictSignedCapabilityRuntimeReport.self,
                forKey: SignedRuntimeCodingKey(CodingKeys.report.rawValue)
            ).value
        )
        guard reportSHA256 == decodedHash else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case nonce
        case scenario
        case binding
        case completedAt
        case metadataSHA256
        case workerSHA256
        case lifecycleSHA256
        case repositorySHA256
        case reportSHA256
        case report
    }
}

public struct SignedInvestigationRuntimeReport:
    Codable,
    Sendable,
    Equatable
{
    public static let schemaVersion = 4

    public let schemaVersion: Int
    public let nonce: UUID
    public let binding: SignedInvestigationRuntimeBinding
    public let model: CodexRuntimeModel
    public let provider: CodexRuntimeProvider
    public let capabilityEvidence:
        SignedInvestigationCapabilityEvidenceReceipt
    public let production: SignedInvestigationProductionEvidence
    public let denials: [SignedInvestigationRuntimeDenialEvidence]
    public let residue: SignedInvestigationRuntimeResidue
    public let startedAt: Date
    public let completedAt: Date
    public let verdict: SignedInvestigationRuntimeVerdict

    public var capabilityReport: CapabilityRuntimeDiagnosticReport {
        capabilityEvidence.report
    }

    package init(
        nonce: UUID,
        binding: SignedInvestigationRuntimeBinding,
        model: CodexRuntimeModel,
        provider: CodexRuntimeProvider,
        capabilityEvidence:
            SignedInvestigationCapabilityEvidenceReceipt,
        production: SignedInvestigationProductionEvidence,
        denials: [SignedInvestigationRuntimeDenialEvidence],
        residue: SignedInvestigationRuntimeResidue,
        startedAt: Date,
        completedAt: Date,
        verdictMode: SignedInvestigationRuntimeVerdictMode = .evaluate
    ) throws {
        let capabilityReport = capabilityEvidence.report
        guard
            binding.isValid,
            model == .gpt56Luna,
            provider == .openAI,
            capabilityEvidence.nonce == nonce,
            capabilityEvidence.binding == binding,
            try capabilityReportSHA256(capabilityReport)
                == capabilityEvidence.reportSHA256,
            capabilityReport.metadata.model == model,
            capabilityReport.metadata.provider == provider,
            capabilityReport.metadata.appExecutableSHA256
                == binding.appExecutableSHA256,
            capabilityReport.metadata.codexExecutableSHA256
                == binding.codexExecutableSHA256,
            production.isValid,
            residue.isValid,
            startedAt.timeIntervalSince1970.isFinite,
            completedAt.timeIntervalSince1970.isFinite,
            completedAt >= startedAt,
            completedAt.timeIntervalSince(startedAt) <= 3_600,
            denials.count
                == SignedInvestigationRuntimeDenialKind.required.count,
            Set(denials.map(\.kind))
                == SignedInvestigationRuntimeDenialKind.required
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        let revalidatedDenials = try denials.map {
            try SignedInvestigationRuntimeDenialEvidence(
                kind: $0.kind,
                attempted: $0.attempted,
                contained: $0.contained,
                controlReasonKey: $0.controlReasonKey,
                failureReasonKey: $0.failureReasonKey
            )
        }
        schemaVersion = Self.schemaVersion
        self.nonce = nonce
        self.binding = binding
        self.model = model
        self.provider = provider
        self.capabilityEvidence = capabilityEvidence
        self.production = production
        self.denials = revalidatedDenials.sorted {
            $0.kind.rawValue < $1.kind.rawValue
        }
        self.residue = residue
        self.startedAt = startedAt
        self.completedAt = completedAt
        let evaluatedVerdict = Self.verdict(
            capabilityReport: capabilityReport,
            production: production,
            denials: revalidatedDenials,
            residue: residue
        )
        if verdictMode == .machineAdmissionPending {
            guard
                capabilityEvidence.scenario == .success,
                evaluatedVerdict == .signedInvestigationRuntimeReady
            else {
                throw SignedInvestigationRuntimeContractError.invalidReport
            }
            verdict =
                .evidenceContractValidatedMachineAdmissionPending
        } else {
            guard
                capabilityEvidence.scenario == .success
                    || evaluatedVerdict
                        != .signedInvestigationRuntimeReady
            else {
                throw SignedInvestigationRuntimeContractError.invalidReport
            }
            verdict = evaluatedVerdict
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try strictSignedRuntimeContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let schemaVersion = try container.decode(
            Int.self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.schemaVersion.rawValue
            )
        )
        guard schemaVersion == Self.schemaVersion else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        let decodedVerdict = try container.decode(
            StrictSignedInvestigationRuntimeVerdict.self,
            forKey: SignedRuntimeCodingKey(CodingKeys.verdict.rawValue)
        ).value
        try self.init(
            nonce: container.decode(
                UUID.self,
                forKey: SignedRuntimeCodingKey(CodingKeys.nonce.rawValue)
            ),
            binding: container.decode(
                SignedInvestigationRuntimeBinding.self,
                forKey: SignedRuntimeCodingKey(CodingKeys.binding.rawValue)
            ),
            model: container.decode(
                CodexRuntimeModel.self,
                forKey: SignedRuntimeCodingKey(CodingKeys.model.rawValue)
            ),
            provider: container.decode(
                CodexRuntimeProvider.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.provider.rawValue
                )
            ),
            capabilityEvidence: container.decode(
                SignedInvestigationCapabilityEvidenceReceipt.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.capabilityEvidence.rawValue
                )
            ),
            production: container.decode(
                SignedInvestigationProductionEvidence.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.production.rawValue
                )
            ),
            denials: container.decode(
                [SignedInvestigationRuntimeDenialEvidence].self,
                forKey: SignedRuntimeCodingKey(CodingKeys.denials.rawValue)
            ),
            residue: container.decode(
                SignedInvestigationRuntimeResidue.self,
                forKey: SignedRuntimeCodingKey(CodingKeys.residue.rawValue)
            ),
            startedAt: container.decode(
                Date.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.startedAt.rawValue
                )
            ),
            completedAt: container.decode(
                Date.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.completedAt.rawValue
                )
            ),
            verdictMode: decodedVerdict
                == .evidenceContractValidatedMachineAdmissionPending
                ? .machineAdmissionPending
                : .evaluate
        )
        guard verdict == decodedVerdict else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
    }

    private static func verdict(
        capabilityReport: CapabilityRuntimeDiagnosticReport,
        production: SignedInvestigationProductionEvidence,
        denials: [SignedInvestigationRuntimeDenialEvidence],
        residue: SignedInvestigationRuntimeResidue
    ) -> SignedInvestigationRuntimeVerdict {
        if let failureReasonKey = production.failureReasonKey {
            return .signedInvestigationRuntimeFailed(
                reasonKeys: [failureReasonKey]
            )
        }
        var blocked: [String] = []
        switch capabilityReport.outcome {
        case .signedRuntimeReady:
            break
        case let .signedRuntimeBlocked(reasonKeys),
             let .externalStateBlocked(reasonKeys):
            blocked.append(contentsOf: reasonKeys)
        }
        blocked.append(contentsOf: denials.compactMap {
            guard !$0.attempted || !$0.contained else {
                return nil
            }
            return $0.failureReasonKey
                ?? "runtime.denial.\($0.kind.rawValue).not-attempted"
        })
        if !production.isReady {
            blocked.append(
                "runtime.production.investigation.not-ready"
            )
        }
        if !residue.isZero {
            blocked.append("runtime.residue.nonzero")
        }
        let reasons = Array(Set(blocked)).sorted()
        return reasons.isEmpty
            ? .signedInvestigationRuntimeReady
            : .signedInvestigationRuntimeBlocked(
                reasonKeys: reasons
            )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case nonce
        case binding
        case model
        case provider
        case capabilityEvidence
        case production
        case denials
        case residue
        case startedAt
        case completedAt
        case verdict
    }
}

public struct SignedInvestigationRuntimeAdmissionReceipt:
    Sendable,
    Equatable
{
    fileprivate let reportSHA256: String
    fileprivate let nonce: UUID
    fileprivate let runtimeReceiptSHA256: String
    fileprivate let investigationID: InvestigationID
    fileprivate let runID: InvestigationRunID
    fileprivate let sourceFingerprint: InvestigationFingerprint
    fileprivate let planFingerprint: InvestigationFingerprint

    package init(
        report: SignedInvestigationRuntimeReport
    ) throws {
        guard report.verdict == .signedInvestigationRuntimeReady else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        reportSHA256 = try report.canonicalSHA256()
        nonce = report.nonce
        runtimeReceiptSHA256 = report.binding.runtimeReceiptSHA256
        investigationID = report.production.investigationID
        runID = report.production.runID
        sourceFingerprint = report.production.sourceFingerprint
        planFingerprint = report.production.planFingerprint
    }
}

public struct SignedInvestigationRuntimeReportVerifier: Sendable {
    public init() {}

    public func verifyReady(
        _ report: SignedInvestigationRuntimeReport,
        configuration:
            SignedInvestigationRuntimeDiagnosticConfiguration,
        capabilityMetadata: CapabilityRuntimeDiagnosticMetadata,
        capabilityWorker: CapabilityRuntimeWorkerEvidence,
        capabilityLifecycleIntegrity:
            [CapabilityRuntimeIntegrityEvidence],
        capabilityRepository: CapabilityRuntimeRepositoryEvidence,
        admission: SignedInvestigationRuntimeAdmissionReceipt,
        now: Date
    ) throws -> SignedInvestigationRuntimeReport {
        try configuration.validate(
            now: now,
            outputs: .ownerRegularFile
        )
        let capabilityEvidence =
            try SignedInvestigationCapabilityEvidenceReceipt(
                configuration: configuration,
                metadata: capabilityMetadata,
                worker: capabilityWorker,
                lifecycleIntegrity: capabilityLifecycleIntegrity,
                repository: capabilityRepository
            )
        guard
            configuration.scenario == .success,
            report.nonce == configuration.nonce,
            report.binding == configuration.binding,
            report.model == configuration.expectedModel,
            report.provider == configuration.expectedProvider,
            report.capabilityEvidence == capabilityEvidence,
            capabilityEvidence.nonce == configuration.nonce,
            capabilityEvidence.binding == configuration.binding,
            report.nonce == admission.nonce,
            report.binding.runtimeReceiptSHA256
                == admission.runtimeReceiptSHA256,
            report.production.investigationID
                == admission.investigationID,
            report.production.runID == admission.runID,
            report.production.sourceFingerprint
                == admission.sourceFingerprint,
            report.production.planFingerprint
                == admission.planFingerprint,
            report.production.investigationID.rawValue
                == "investigation-"
                    + configuration.nonce.uuidString.lowercased(),
            report.production.runID.rawValue
                == "investigation-run-"
                    + configuration.nonce.uuidString.lowercased(),
            report.production.reportID.rawValue
                == "investigation-report-"
                    + configuration.nonce.uuidString.lowercased(),
            report.production.sourceFingerprint.hex
                == configuration.binding.sourceFingerprintSHA256,
            try report.canonicalSHA256() == admission.reportSHA256
        else {
            throw SignedInvestigationRuntimeContractError.bindingMismatch
        }
        let validated = try SignedInvestigationRuntimeReport(
            nonce: report.nonce,
            binding: report.binding,
            model: report.model,
            provider: report.provider,
            capabilityEvidence: report.capabilityEvidence,
            production: report.production,
            denials: report.denials,
            residue: report.residue,
            startedAt: report.startedAt,
            completedAt: report.completedAt
        )
        guard
            validated == report,
            validated.verdict
                == .signedInvestigationRuntimeReady,
            capabilityEvidence.completedAt <= report.startedAt,
            report.startedAt.timeIntervalSince(
                capabilityEvidence.completedAt
            ) <= Double(configuration.maximumWallClockSeconds),
            capabilityEvidence.completedAt
                <= configuration.validBefore,
            capabilityEvidence.completedAt <= now,
            report.startedAt <= now,
            report.completedAt <= now,
            report.completedAt <= configuration.validBefore,
            report.completedAt.timeIntervalSince(report.startedAt)
                <= Double(configuration.maximumWallClockSeconds)
        else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        return validated
    }
}

private extension SignedInvestigationRuntimeReport {
    func canonicalSHA256() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let digest = SHA256.hash(data: try encoder.encode(self))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private func capabilityReportSHA256(
    _ report: CapabilityRuntimeDiagnosticReport
) throws -> String {
    try canonicalSHA256(report)
}

private func canonicalCapabilityEvidenceBindingSHA256(
    schemaVersion: Int,
    nonce: UUID,
    scenario: SignedInvestigationRuntimeDiagnosticScenario,
    binding: SignedInvestigationRuntimeBinding,
    expectedModel: CodexRuntimeModel,
    expectedProvider: CodexRuntimeProvider
) throws -> String {
    struct CapabilityEvidenceBinding: Encodable {
        let schemaVersion: Int
        let nonce: UUID
        let scenario: SignedInvestigationRuntimeDiagnosticScenario
        let binding: SignedInvestigationRuntimeBinding
        let expectedModel: CodexRuntimeModel
        let expectedProvider: CodexRuntimeProvider
    }
    return try canonicalSHA256(
        CapabilityEvidenceBinding(
            schemaVersion: schemaVersion,
            nonce: nonce,
            scenario: scenario,
            binding: binding,
            expectedModel: expectedModel,
            expectedProvider: expectedProvider
        )
    )
}

private func canonicalSHA256<T: Encodable>(
    _ value: T
) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let digest = SHA256.hash(data: try encoder.encode(value))
    return digest.map { String(format: "%02x", $0) }.joined()
}

private func revalidatedCapabilityReport(
    _ report: CapabilityRuntimeDiagnosticReport
) throws -> CapabilityRuntimeDiagnosticReport {
    let metadata = try CapabilityRuntimeDiagnosticMetadata(
        appBundleIdentifier: report.metadata.appBundleIdentifier,
        appExecutableSHA256: report.metadata.appExecutableSHA256,
        appDesignatedRequirementSHA256:
            report.metadata.appDesignatedRequirementSHA256,
        signatureKind: report.metadata.signatureKind,
        codexVersion: report.metadata.codexVersion,
        codexExecutableSHA256: report.metadata.codexExecutableSHA256,
        model: report.metadata.model,
        provider: report.metadata.provider,
        publicEndpointHosts: report.metadata.publicEndpointHosts,
        syntheticFixtureSHA256s:
            report.metadata.syntheticFixtureSHA256s,
        sanitizedEventCategories:
            report.metadata.sanitizedEventCategories,
        durationMilliseconds: report.metadata.durationMilliseconds
    )
    let capabilities = try report.capabilities.map {
        try CapabilityRuntimeCapabilityEvidence(
            capability: $0.capability,
            advertised: $0.advertised,
            configured: $0.configured,
            invoked: $0.invoked,
            observed: $0.observed,
            reasonKey: $0.reasonKey
        )
    }
    let integrity = try report.integrity.map {
        try CapabilityRuntimeIntegrityEvidence(
            property: $0.property,
            verdict: $0.verdict,
            reasonKey: $0.reasonKey
        )
    }
    let validated = try CapabilityRuntimeDiagnosticReport(
        metadata: metadata,
        capabilities: capabilities,
        integrity: integrity,
        externalStateReasonKeys: report.externalStateReasonKeys
    )
    guard validated == report else {
        throw SignedInvestigationRuntimeContractError.invalidReport
    }
    return validated
}

private struct StrictSignedCapabilityRuntimeReport: Decodable {
    let value: CapabilityRuntimeDiagnosticReport

    init(from decoder: Decoder) throws {
        do {
            let container = try strictSignedRuntimeContainer(
                decoder,
                keys: Set(CodingKeys.allCases.map(\.rawValue))
            )
            let schemaVersion = try container.decode(
                Int.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.schemaVersion.rawValue
                )
            )
            guard
                schemaVersion
                    == CapabilityRuntimeDiagnosticReport.schemaVersion
            else {
                throw SignedInvestigationRuntimeContractError.invalidReport
            }
            let metadata = try container.decode(
                StrictSignedCapabilityRuntimeMetadata.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.metadata.rawValue
                )
            ).value
            let capabilities = try container.decode(
                [StrictSignedCapabilityEvidence].self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.capabilities.rawValue
                )
            ).map(\.value)
            let integrity = try container.decode(
                [StrictSignedIntegrityEvidence].self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.integrity.rawValue
                )
            ).map(\.value)
            let externalStateReasonKeys = try container.decode(
                [String].self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.externalStateReasonKeys.rawValue
                )
            )
            let outcome = try container.decode(
                StrictSignedCapabilityRuntimeOutcome.self,
                forKey: SignedRuntimeCodingKey(
                    CodingKeys.outcome.rawValue
                )
            ).value
            let rebuilt = try CapabilityRuntimeDiagnosticReport(
                metadata: metadata,
                capabilities: capabilities,
                integrity: integrity,
                externalStateReasonKeys: externalStateReasonKeys
            )
            guard
                rebuilt.metadata == metadata,
                rebuilt.capabilities == capabilities,
                rebuilt.integrity == integrity,
                rebuilt.externalStateReasonKeys
                    == externalStateReasonKeys,
                rebuilt.outcome == outcome
            else {
                throw SignedInvestigationRuntimeContractError.invalidReport
            }
            value = rebuilt
        } catch {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case metadata
        case capabilities
        case integrity
        case externalStateReasonKeys
        case outcome
    }
}

private struct StrictSignedCapabilityRuntimeMetadata: Decodable {
    let value: CapabilityRuntimeDiagnosticMetadata

    init(from decoder: Decoder) throws {
        let container = try strictSignedRuntimeContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue))
        )
        do {
            value = try CapabilityRuntimeDiagnosticMetadata(
                appBundleIdentifier: container.decode(
                    String.self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.appBundleIdentifier.rawValue
                    )
                ),
                appExecutableSHA256: container.decode(
                    String.self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.appExecutableSHA256.rawValue
                    )
                ),
                appDesignatedRequirementSHA256: container.decode(
                    String.self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.appDesignatedRequirementSHA256.rawValue
                    )
                ),
                signatureKind: container.decode(
                    CapabilityRuntimeSignatureKind.self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.signatureKind.rawValue
                    )
                ),
                codexVersion: container.decode(
                    String.self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.codexVersion.rawValue
                    )
                ),
                codexExecutableSHA256: container.decode(
                    String.self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.codexExecutableSHA256.rawValue
                    )
                ),
                model: container.decode(
                    CodexRuntimeModel.self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.model.rawValue
                    )
                ),
                provider: container.decode(
                    CodexRuntimeProvider.self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.provider.rawValue
                    )
                ),
                publicEndpointHosts: container.decode(
                    [String].self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.publicEndpointHosts.rawValue
                    )
                ),
                syntheticFixtureSHA256s: container.decode(
                    [String].self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.syntheticFixtureSHA256s.rawValue
                    )
                ),
                sanitizedEventCategories: container.decode(
                    [String].self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.sanitizedEventCategories.rawValue
                    )
                ),
                durationMilliseconds: container.decode(
                    Int.self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.durationMilliseconds.rawValue
                    )
                )
            )
        } catch {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case appBundleIdentifier
        case appExecutableSHA256
        case appDesignatedRequirementSHA256
        case signatureKind
        case codexVersion
        case codexExecutableSHA256
        case model
        case provider
        case publicEndpointHosts
        case syntheticFixtureSHA256s
        case sanitizedEventCategories
        case durationMilliseconds
    }
}

private struct StrictSignedInvestigationRuntimeVerdict: Decodable {
    let value: SignedInvestigationRuntimeVerdict

    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: SignedRuntimeCodingKey.self
        )
        let keys = container.allKeys
        guard keys.count == 1, let key = keys.first else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        let payload = try container.superDecoder(forKey: key)
        switch key.stringValue {
        case "signedInvestigationRuntimeReady":
            try requireEmptySignedRuntimePayload(payload)
            value = .signedInvestigationRuntimeReady
        case "evidenceContractValidatedMachineAdmissionPending":
            try requireEmptySignedRuntimePayload(payload)
            value =
                .evidenceContractValidatedMachineAdmissionPending
        case "signedInvestigationRuntimeBlocked":
            value = .signedInvestigationRuntimeBlocked(
                reasonKeys: try StrictSignedReasonKeysPayload(
                    from: payload
                ).reasonKeys
            )
        case "signedInvestigationRuntimeFailed":
            value = .signedInvestigationRuntimeFailed(
                reasonKeys: try StrictSignedReasonKeysPayload(
                    from: payload
                ).reasonKeys
            )
        default:
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
    }
}

private struct StrictSignedCapabilityRuntimeOutcome: Decodable {
    let value: CapabilityRuntimeDiagnosticOutcome

    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: SignedRuntimeCodingKey.self
        )
        let keys = container.allKeys
        guard keys.count == 1, let key = keys.first else {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
        let payload = try container.superDecoder(forKey: key)
        switch key.stringValue {
        case "signedRuntimeReady":
            try requireEmptySignedRuntimePayload(payload)
            value = .signedRuntimeReady
        case "signedRuntimeBlocked":
            value = .signedRuntimeBlocked(
                reasonKeys: try StrictSignedReasonKeysPayload(
                    from: payload
                ).reasonKeys
            )
        case "externalStateBlocked":
            value = .externalStateBlocked(
                reasonKeys: try StrictSignedReasonKeysPayload(
                    from: payload
                ).reasonKeys
            )
        default:
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
    }
}

private struct StrictSignedReasonKeysPayload: Decodable {
    let reasonKeys: [String]

    init(from decoder: Decoder) throws {
        let container = try strictSignedRuntimeContainer(
            decoder,
            keys: [CodingKeys.reasonKeys.rawValue]
        )
        reasonKeys = try container.decode(
            [String].self,
            forKey: SignedRuntimeCodingKey(
                CodingKeys.reasonKeys.rawValue
            )
        )
    }

    private enum CodingKeys: String, CodingKey {
        case reasonKeys
    }
}

private struct StrictSignedCapabilityEvidence: Decodable {
    let value: CapabilityRuntimeCapabilityEvidence

    init(from decoder: Decoder) throws {
        let container = try strictSignedRuntimeContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue)),
            optionalKeys: [CodingKeys.reasonKey.rawValue]
        )
        do {
            value = try CapabilityRuntimeCapabilityEvidence(
                capability: container.decode(
                    CapabilityRuntimeCapability.self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.capability.rawValue
                    )
                ),
                advertised: container.decode(
                    Bool.self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.advertised.rawValue
                    )
                ),
                configured: container.decode(
                    Bool.self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.configured.rawValue
                    )
                ),
                invoked: container.decode(
                    Bool.self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.invoked.rawValue
                    )
                ),
                observed: container.decode(
                    Bool.self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.observed.rawValue
                    )
                ),
                reasonKey: container.decodeIfPresent(
                    String.self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.reasonKey.rawValue
                    )
                )
            )
        } catch {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case capability
        case advertised
        case configured
        case invoked
        case observed
        case reasonKey
    }
}

private struct StrictSignedIntegrityEvidence: Decodable {
    let value: CapabilityRuntimeIntegrityEvidence

    init(from decoder: Decoder) throws {
        let container = try strictSignedRuntimeContainer(
            decoder,
            keys: Set(CodingKeys.allCases.map(\.rawValue)),
            optionalKeys: [CodingKeys.reasonKey.rawValue]
        )
        do {
            value = try CapabilityRuntimeIntegrityEvidence(
                property: container.decode(
                    CapabilityRuntimeIntegrityProperty.self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.property.rawValue
                    )
                ),
                verdict: container.decode(
                    CapabilityRuntimeIntegrityVerdict.self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.verdict.rawValue
                    )
                ),
                reasonKey: container.decodeIfPresent(
                    String.self,
                    forKey: SignedRuntimeCodingKey(
                        CodingKeys.reasonKey.rawValue
                    )
                )
            )
        } catch {
            throw SignedInvestigationRuntimeContractError.invalidReport
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case property
        case verdict
        case reasonKey
    }
}

private func requireEmptySignedRuntimePayload(
    _ decoder: Decoder
) throws {
    _ = try strictSignedRuntimeContainer(decoder, keys: [])
}

private struct SignedRuntimeCodingKey: CodingKey, Hashable {
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

private func strictSignedRuntimeContainer(
    _ decoder: Decoder,
    keys: Set<String>,
    optionalKeys: Set<String> = [],
    error: SignedInvestigationRuntimeContractError = .invalidReport
) throws -> KeyedDecodingContainer<SignedRuntimeCodingKey> {
    let container = try decoder.container(
        keyedBy: SignedRuntimeCodingKey.self
    )
    let actualKeys = Set(container.allKeys.map(\.stringValue))
    guard
        optionalKeys.isSubset(of: keys),
        actualKeys.isSubset(of: keys),
        keys.subtracting(optionalKeys).isSubset(of: actualKeys)
    else {
        throw error
    }
    return container
}

private func validAbsolutePath(_ path: String) -> Bool {
    guard
        path.hasPrefix("/"),
        path != "/",
        !path.hasSuffix("/"),
        !path.contains("//"),
        !path.contains("\n"),
        !path.contains("\r"),
        path.utf8.count <= 4_096
    else {
        return false
    }
    return (path as NSString).pathComponents
        .dropFirst()
        .allSatisfy { $0 != "." && $0 != ".." && !$0.isEmpty }
}

private func ownerDirectoryWithoutSymlink(_ path: String) -> Bool {
    var information = stat()
    guard
        pathHasNoSymlinkComponents(path),
        lstat(path, &information) == 0,
        information.st_mode & S_IFMT == S_IFDIR,
        information.st_uid == geteuid(),
        information.st_mode & 0o077 == 0
    else {
        return false
    }
    return true
}

private func pathDoesNotExistWithoutSymlink(_ path: String) -> Bool {
    var information = stat()
    if lstat(path, &information) == 0 {
        return false
    }
    let parent = URL(filePath: path).deletingLastPathComponent().path
    return errno == ENOENT
        && pathHasNoSymlinkComponents(parent)
        && ownerDirectoryWithoutSymlink(parent)
}

private func ownerFileWithoutSymlink(_ path: String) -> Bool {
    var information = stat()
    guard
        pathHasNoSymlinkComponents(path),
        lstat(path, &information) == 0,
        information.st_mode & S_IFMT == S_IFREG,
        information.st_uid == geteuid(),
        information.st_mode & 0o077 == 0,
        information.st_nlink == 1
    else {
        return false
    }
    return true
}

private func pathHasNoSymlinkComponents(_ path: String) -> Bool {
    let components = (path as NSString).pathComponents
    guard components.first == "/" else {
        return false
    }
    var current = "/"
    for component in components.dropFirst() {
        current = URL(filePath: current, directoryHint: .isDirectory)
            .appending(path: component)
            .path
        var information = stat()
        guard
            lstat(current, &information) == 0,
            information.st_mode & S_IFMT != S_IFLNK
        else {
            return false
        }
    }
    return true
}

private func containsPath(_ root: String, _ child: String) -> Bool {
    let prefix = root.hasSuffix("/") ? root : root + "/"
    return child.hasPrefix(prefix)
}

private func pathsOverlap(_ lhs: String, _ rhs: String) -> Bool {
    lhs == rhs || containsPath(lhs, rhs) || containsPath(rhs, lhs)
}

private func lowercaseHex(_ value: String, count: Int) -> Bool {
    value.utf8.count == count
        && value.unicodeScalars.allSatisfy {
            (0x30...0x39).contains($0.value)
                || (0x61...0x66).contains($0.value)
        }
}

private func stableReasonKey(_ value: String?) -> Bool {
    guard let value else {
        return true
    }
    return !value.isEmpty
        && value.utf8.count <= 256
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
