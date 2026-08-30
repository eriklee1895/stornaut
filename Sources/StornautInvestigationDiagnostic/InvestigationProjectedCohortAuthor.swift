#if DEBUG
import Foundation
import StornautInvestigation
import StornautInvestigationHandoffContract

package enum InvestigationProjectedCohortAuthorError:
    Error,
    Sendable,
    Equatable
{
    case invalidConfiguration
    case invalidInstalledBinding
    case bindingMismatch
    case invalidIdentifiers
    case identifierGenerationFailed
    case constructionFailed
}

package struct InvestigationProjectedCohortInstalledBinding:
    Sendable,
    Equatable
{
    package let appExecutableSHA256: InvestigationHandoffSHA256
    package let appBundleIdentifier: String
    package let helperExecutableSHA256: InvestigationHandoffSHA256
    package let helperServiceIdentifier: String
    package let machineDriverExecutableSHA256: InvestigationHandoffSHA256
    package let machineDriverSigningIdentifier: String
    package let machineDriverDesignatedRequirementSHA256:
        InvestigationHandoffSHA256
    package let machineDriverCodeDirectoryHash: Data
    package let machineClaimServiceIdentifier: String

    package init(
        appExecutableSHA256: String,
        appBundleIdentifier: String,
        helperExecutableSHA256: String,
        helperServiceIdentifier: String,
        machineDriverExecutableSHA256: String,
        machineDriverSigningIdentifier: String,
        machineDriverDesignatedRequirementSHA256: String,
        machineDriverCodeDirectoryHash: String,
        machineClaimServiceIdentifier: String
    ) throws {
        guard
            appBundleIdentifier
                == InvestigationInstalledL2IdentityProjection
                    .fixedAppBundleIdentifier,
            helperServiceIdentifier
                == InvestigationInstalledL2IdentityProjection
                    .fixedHelperServiceIdentifier,
            machineDriverSigningIdentifier
                == InvestigationInstalledL2IdentityProjection
                    .fixedMachineDriverSigningIdentifier,
            machineClaimServiceIdentifier
                == InvestigationInstalledL2IdentityProjection
                    .fixedMachineClaimServiceIdentifier,
            let codeDirectory = Self.decodeCodeDirectoryHash(
                machineDriverCodeDirectoryHash
            )
        else {
            throw InvestigationProjectedCohortAuthorError
                .invalidInstalledBinding
        }
        do {
            self.appExecutableSHA256 = try .init(
                lowercaseHex: appExecutableSHA256
            )
            self.helperExecutableSHA256 = try .init(
                lowercaseHex: helperExecutableSHA256
            )
            self.machineDriverExecutableSHA256 = try .init(
                lowercaseHex: machineDriverExecutableSHA256
            )
            self.machineDriverDesignatedRequirementSHA256 = try .init(
                lowercaseHex: machineDriverDesignatedRequirementSHA256
            )
        } catch {
            throw InvestigationProjectedCohortAuthorError
                .invalidInstalledBinding
        }
        self.appBundleIdentifier = appBundleIdentifier
        self.helperServiceIdentifier = helperServiceIdentifier
        self.machineDriverSigningIdentifier = machineDriverSigningIdentifier
        self.machineDriverCodeDirectoryHash = codeDirectory
        self.machineClaimServiceIdentifier = machineClaimServiceIdentifier
    }

    package func matches(_ binding: SignedInvestigationRuntimeBinding) -> Bool {
        appExecutableSHA256.lowercaseHex == binding.appExecutableSHA256
            && appBundleIdentifier == binding.appBundleIdentifier
            && helperExecutableSHA256.lowercaseHex
                == binding.helperExecutableSHA256
            && helperServiceIdentifier == binding.helperServiceIdentifier
            && machineDriverExecutableSHA256.lowercaseHex
                == binding.machineDriver.executableSHA256
            && machineDriverSigningIdentifier
                == binding.machineDriver.signingIdentifier
            && machineDriverDesignatedRequirementSHA256.lowercaseHex
                == binding.machineDriver.designatedRequirementSHA256
            && machineDriverCodeDirectoryHash.lowercaseHexString
                == binding.machineDriver.codeDirectoryHash
            && machineClaimServiceIdentifier
                == binding.machineDriver.machineClaimServiceIdentifier
    }

    private static func decodeCodeDirectoryHash(_ value: String) -> Data? {
        let bytes = Array(value.utf8)
        guard bytes.count == 40 || bytes.count == 64 else { return nil }
        var decoded = Data()
        decoded.reserveCapacity(bytes.count / 2)
        for index in stride(from: 0, to: bytes.count, by: 2) {
            guard
                let high = lowercaseHexNibble(bytes[index]),
                let low = lowercaseHexNibble(bytes[index + 1])
            else {
                return nil
            }
            decoded.append((high << 4) | low)
        }
        return decoded
    }
}

struct InvestigationProjectedCohortGeneratedIdentifiers: Sendable, Equatable {
    let outerAttemptUUID: UUID
    let epochUUIDs: [UUID]

    init(outerAttemptUUID: UUID, epochUUIDs: [UUID]) {
        self.outerAttemptUUID = outerAttemptUUID
        self.epochUUIDs = epochUUIDs
    }
}

package struct InvestigationProjectedCohortAuthor: Sendable {
    typealias Clock = @Sendable () -> Date
    typealias IdentifierProvider = @Sendable () throws
        -> InvestigationProjectedCohortGeneratedIdentifiers

    private let now: Clock
    private let identifiers: IdentifierProvider

    package init() {
        self.init(now: Date.init, identifiers: {
            InvestigationProjectedCohortGeneratedIdentifiers(
                outerAttemptUUID: UUID(),
                epochUUIDs: (0..<InvestigationCohortCapsule.epochCount)
                    .map { _ in UUID() }
            )
        })
    }

    init(now: @escaping Clock, identifiers: @escaping IdentifierProvider) {
        self.now = now
        self.identifiers = identifiers
    }

    package func author(
        configurationData: [Data],
        installedBinding: InvestigationProjectedCohortInstalledBinding
    ) throws -> InvestigationProjectedCohortInput {
        let validationTime = now()
        let validated = try validateConfigurations(
            configurationData,
            now: validationTime
        )
        guard installedBinding.matches(validated.binding) else {
            throw InvestigationProjectedCohortAuthorError.bindingMismatch
        }

        let generated: InvestigationProjectedCohortGeneratedIdentifiers
        do {
            generated = try identifiers()
        } catch {
            throw InvestigationProjectedCohortAuthorError
                .identifierGenerationFailed
        }
        try validateIdentifiers(
            generated,
            configurationNonces: validated.rows.map(\.configuration.nonce)
        )

        do {
            var epochs: [InvestigationCohortEpoch] = []
            var projections: [InvestigationInstalledL2IdentityProjection] = []
            epochs.reserveCapacity(InvestigationCohortCapsule.epochCount)
            projections.reserveCapacity(InvestigationCohortCapsule.epochCount)
            for (index, row) in validated.rows.enumerated() {
                let epochUUID = generated.epochUUIDs[index]
                let configurationSHA256 =
                    InvestigationHandoffSHA256.hashing(row.data)
                let bindingSHA256 = try InvestigationHandoffSHA256(
                    lowercaseHex: row.configuration
                        .capabilityEvidenceBindingSHA256()
                )
                let epoch = try InvestigationCohortEpoch(
                    ordinal: UInt32(index),
                    epochUUID: epochUUID,
                    scenario: row.scenario,
                    configurationNonce: row.configuration.nonce,
                    configuration: row.data,
                    configurationSHA256: configurationSHA256,
                    signedRuntimeBindingSHA256: bindingSHA256
                )
                let projection = try InvestigationInstalledL2IdentityProjection(
                    epochUUID: epochUUID,
                    configurationNonce: row.configuration.nonce,
                    configurationValidBefore: try .init(
                        timeIntervalSince1970:
                            row.configuration.validBefore.timeIntervalSince1970
                    ),
                    configurationSHA256: configurationSHA256,
                    signedRuntimeBindingSHA256: bindingSHA256,
                    appExecutableSHA256: installedBinding.appExecutableSHA256,
                    appBundleIdentifier: installedBinding.appBundleIdentifier,
                    helperExecutableSHA256:
                        installedBinding.helperExecutableSHA256,
                    helperServiceIdentifier:
                        installedBinding.helperServiceIdentifier,
                    machineDriverExecutableSHA256:
                        installedBinding.machineDriverExecutableSHA256,
                    machineDriverSigningIdentifier:
                        installedBinding.machineDriverSigningIdentifier,
                    machineDriverDesignatedRequirementSHA256:
                        installedBinding
                            .machineDriverDesignatedRequirementSHA256,
                    machineDriverCodeDirectoryHash:
                        installedBinding.machineDriverCodeDirectoryHash,
                    machineClaimServiceIdentifier:
                        installedBinding.machineClaimServiceIdentifier
                )
                epochs.append(epoch)
                projections.append(projection)
            }
            return try InvestigationProjectedCohortInput(
                capsule: InvestigationCohortCapsule(
                    outerAttemptUUID: generated.outerAttemptUUID,
                    epochs: epochs
                ),
                projections: projections
            )
        } catch let error as InvestigationProjectedCohortAuthorError {
            throw error
        } catch {
            throw InvestigationProjectedCohortAuthorError.constructionFailed
        }
    }

    private func validateConfigurations(
        _ data: [Data],
        now: Date
    ) throws -> (
        rows: [(
            scenario: InvestigationHandoffScenario,
            configuration: SignedInvestigationRuntimeDiagnosticConfiguration,
            data: Data
        )],
        binding: SignedInvestigationRuntimeBinding
    ) {
        guard data.count == InvestigationCohortCapsule.epochCount else {
            throw InvestigationProjectedCohortAuthorError.invalidConfiguration
        }
        var byOrdinal: [UInt32: (
            SignedInvestigationRuntimeDiagnosticConfiguration, Data
        )] = [:]
        for bytes in data {
            let configuration: SignedInvestigationRuntimeDiagnosticConfiguration
            do {
                configuration = try .decodeMachineCohortValidated(
                    from: bytes, now: now
                )
                guard
                    try configuration.canonicalJSONData() == bytes,
                    try configuration.machineConfigurationSHA256()
                        == InvestigationHandoffSHA256.hashing(bytes).lowercaseHex
                else {
                    throw InvestigationProjectedCohortAuthorError
                        .invalidConfiguration
                }
            } catch {
                throw InvestigationProjectedCohortAuthorError
                    .invalidConfiguration
            }
            let scenario = InvestigationHandoffScenarioMapping.handoffScenario(
                configuration.scenario
            )
            guard byOrdinal[scenario.rawValue] == nil else {
                throw InvestigationProjectedCohortAuthorError
                    .invalidConfiguration
            }
            byOrdinal[scenario.rawValue] = (configuration, bytes)
        }
        guard
            Set(byOrdinal.values.map { $0.0.nonce }).count
                == InvestigationCohortCapsule.epochCount,
            byOrdinal.values.allSatisfy({ !Self.isZero($0.0.nonce) }),
            let first = byOrdinal[InvestigationHandoffScenario.success.rawValue]
        else {
            throw InvestigationProjectedCohortAuthorError.invalidConfiguration
        }
        let binding = first.0.binding
        let validBefore = first.0.validBefore
        guard byOrdinal.values.allSatisfy({ $0.0.binding == binding }) else {
            throw InvestigationProjectedCohortAuthorError.bindingMismatch
        }
        guard byOrdinal.values.allSatisfy({ $0.0.validBefore == validBefore })
        else {
            throw InvestigationProjectedCohortAuthorError.invalidConfiguration
        }
        let rows = try InvestigationHandoffScenario.allCases.map { scenario in
            guard let row = byOrdinal[scenario.rawValue] else {
                throw InvestigationProjectedCohortAuthorError
                    .invalidConfiguration
            }
            return (scenario, row.0, row.1)
        }
        return (rows, binding)
    }

    private func validateIdentifiers(
        _ generated: InvestigationProjectedCohortGeneratedIdentifiers,
        configurationNonces: [UUID]
    ) throws {
        let identifiers = [generated.outerAttemptUUID]
            + generated.epochUUIDs
            + configurationNonces
        guard
            generated.epochUUIDs.count == InvestigationCohortCapsule.epochCount,
            identifiers.allSatisfy({ !Self.isZero($0) }),
            Set(identifiers).count == 17
        else {
            throw InvestigationProjectedCohortAuthorError.invalidIdentifiers
        }
    }

    private static func isZero(_ value: UUID) -> Bool {
        value == UUID(
            uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        )
    }
}

private func lowercaseHexNibble(_ byte: UInt8) -> UInt8? {
    switch byte {
    case 48...57: byte - 48
    case 97...102: byte - 87
    default: nil
    }
}

private extension Data {
    var lowercaseHexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
#endif
