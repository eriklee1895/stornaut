import Foundation
import Testing
import StornautInvestigation
@testable import StornautInvestigationDiagnostic
@testable import StornautInvestigationHandoffContract
@Suite("Investigation projected cohort author", .serialized)
struct InvestigationProjectedCohortAuthorTests {
    @Test
    func canonicalizesAdversarialScenarioOrderAndProjectsEveryField() throws {
        let fixture = try SignedRuntimeContractFixture(
            now: Date(timeIntervalSince1970: 1_800_000_000.123_456))
        defer { fixture.remove() }
        let configurations = try fixture.machineConfigurations()
        let identifiers = try generatedIdentifiers()
        let probe = ProjectedCohortAuthorProbe(
            now: fixture.now, identifiers: identifiers)
        let author = InvestigationProjectedCohortAuthor(
            now: probe.now, identifiers: probe.identifiers)
        let binding = try installedBinding(fixture.binding())
        let output = try author.author(
            configurationData: configurations.reversed().map {
                try $0.canonicalJSONData()
            },
            installedBinding: binding
        )

        #expect(probe.nowCallCount == 1)
        #expect(probe.identifierCallCount == 1)
        #expect(output.capsule.outerAttemptUUID == identifiers.outerAttemptUUID)
        #expect(output.capsule.epochs.map(\.scenario) == InvestigationHandoffScenario.allCases)
        #expect(output.capsule.epochs.map(\.ordinal) == Array(0...7))
        #expect(output.capsule.epochs.map(\.epochUUID) == identifiers.epochUUIDs)
        let byScenario = Dictionary(
            uniqueKeysWithValues: configurations.map { ($0.scenario, $0) }
        )
        for (index, epoch) in output.capsule.epochs.enumerated() {
            let signedScenario = try #require(
                SignedInvestigationRuntimeDiagnosticScenario(
                    rawValue: epoch.scenario.name
                )
            )
            let configuration = try #require(byScenario[signedScenario])
            let projection = output.projections[index]
            let canonicalConfiguration = try configuration.canonicalJSONData()
            let configurationSHA256 = try configuration.machineConfigurationSHA256()
            let bindingSHA256 = try configuration.capabilityEvidenceBindingSHA256()
            #expect(epoch.configuration == canonicalConfiguration)
            #expect(epoch.configurationNonce == configuration.nonce)
            #expect(epoch.configurationSHA256.lowercaseHex == configurationSHA256)
            #expect(epoch.signedRuntimeBindingSHA256.lowercaseHex == bindingSHA256)
            #expect(projection.epochUUID == epoch.epochUUID)
            #expect(projection.configurationNonce == configuration.nonce)
            #expect(projection.configurationSHA256 == epoch.configurationSHA256)
            #expect(projection.signedRuntimeBindingSHA256 == epoch.signedRuntimeBindingSHA256)
            let expectedValidBefore = try InvestigationHandoffUTCMicroseconds(
                timeIntervalSince1970: configuration.validBefore.timeIntervalSince1970)
            #expect(projection.configurationValidBefore == expectedValidBefore)
            #expect(projection.appExecutableSHA256 == binding.appExecutableSHA256)
            #expect(projection.appBundleIdentifier == binding.appBundleIdentifier)
            #expect(projection.helperExecutableSHA256 == binding.helperExecutableSHA256)
            #expect(projection.helperServiceIdentifier == binding.helperServiceIdentifier)
            #expect(projection.machineDriverExecutableSHA256
                == binding.machineDriverExecutableSHA256)
            #expect(projection.machineDriverSigningIdentifier
                == binding.machineDriverSigningIdentifier)
            #expect(projection.machineDriverDesignatedRequirementSHA256
                == binding.machineDriverDesignatedRequirementSHA256)
            #expect(projection.machineDriverCodeDirectoryHash
                == binding.machineDriverCodeDirectoryHash)
            #expect(projection.machineClaimServiceIdentifier
                == binding.machineClaimServiceIdentifier)
        }
    }

    @Test
    func rejectsInvalidConfigurationsBeforeIdentifierGeneration() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configurations = try fixture.machineConfigurations()
        let valid = try configurations.map { try $0.canonicalJSONData() }
        var duplicate = valid
        duplicate[7] = duplicate[0]
        var duplicateNonce = valid
        duplicateNonce[7] = try configuration(
            replacing: configurations[7],
            binding: configurations[7].binding,
            nonce: configurations[0].nonce,
            now: fixture.now
        ).canonicalJSONData()
        var unknownObject = try jsonObject(valid[0])
        unknownObject["unexpected"] = true
        var missingObject = try jsonObject(valid[0])
        missingObject.removeValue(forKey: "scenario")
        let noncanonical = try JSONSerialization.data(
            withJSONObject: try jsonObject(valid[0]),
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        var zeroNonceObject = try jsonObject(valid[0])
        zeroNonceObject["nonce"] = "00000000-0000-0000-0000-000000000000"
        let expired = try fixture.configuration(
            nonce: try Self.uuid(0x31),
            scenario: .success,
            reuseDefaultPaths: true,
            configurationNow: fixture.now.addingTimeInterval(-120),
            validBefore: fixture.now.addingTimeInterval(-1)
        ).canonicalJSONData()
        let mutations: [[Data]] = [
            Array(valid.dropLast()),
            duplicate,
            duplicateNonce,
            replacingFirst(valid, with: try canonicalJSON(unknownObject)),
            replacingFirst(valid, with: try canonicalJSON(missingObject)),
            replacingFirst(valid, with: noncanonical),
            replacingFirst(valid, with: try canonicalJSON(zeroNonceObject)),
            replacingFirst(valid, with: expired),
            replacingFirst(valid, with: Data(repeating: 0x20, count: 65_537)),
        ]

        for mutation in mutations {
            let probe = ProjectedCohortAuthorProbe(
                now: fixture.now, identifiers: try generatedIdentifiers())
            let author = InvestigationProjectedCohortAuthor(
                now: probe.now, identifiers: probe.identifiers)
            #expect(
                throws: InvestigationProjectedCohortAuthorError
                    .invalidConfiguration
            ) {
                _ = try author.author(
                    configurationData: mutation,
                    installedBinding: try installedBinding(fixture.binding())
                )
            }
            #expect(probe.nowCallCount == 1)
            #expect(probe.identifierCallCount == 0)
        }

        var lateUnknownObject = try jsonObject(valid[7])
        lateUnknownObject["unexpected"] = true
        var invalidLate = valid
        invalidLate[7] = try canonicalJSON(lateUnknownObject)
        let precedenceProbe = ProjectedCohortAuthorProbe(
            now: fixture.now, identifiers: try generatedIdentifiers())
        #expect(
            throws: InvestigationProjectedCohortAuthorError
                .invalidConfiguration
        ) {
            _ = try InvestigationProjectedCohortAuthor(
                now: precedenceProbe.now,
                identifiers: precedenceProbe.identifiers
            ).author(
                configurationData: invalidLate,
                installedBinding: try installedBinding(
                    fixture.binding(), mutation: .appExecutableSHA256
                )
            )
        }
        #expect(precedenceProbe.identifierCallCount == 0)
    }

    @Test
    func rejectsBindingAndIdentifierFailures() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let configurations = try fixture.machineConfigurations()
        let data = try configurations.map { try $0.canonicalJSONData() }
        let mixedBinding = fixture.binding(
            runtimeReceiptSHA256: String(repeating: "9", count: 64)
        )
        var mixedData = data
        mixedData[7] = try configuration(
            replacing: configurations[7],
            binding: mixedBinding,
            now: fixture.now
        ).canonicalJSONData()
        let mixedProbe = ProjectedCohortAuthorProbe(
            now: fixture.now, identifiers: try generatedIdentifiers()
        )
        #expect(throws: InvestigationProjectedCohortAuthorError.bindingMismatch) {
            _ = try InvestigationProjectedCohortAuthor(
                now: mixedProbe.now, identifiers: mixedProbe.identifiers
            ).author(
                configurationData: mixedData,
                installedBinding: try installedBinding(fixture.binding())
            )
        }
        #expect(mixedProbe.identifierCallCount == 0)
        for mutation in InvalidInstalledBindingSHAField.allCases {
            let foreignBinding = try installedBinding(
                fixture.binding(), mutation: mutation
            )
            let bindingProbe = ProjectedCohortAuthorProbe(
                now: fixture.now, identifiers: try generatedIdentifiers())
            #expect(
                throws: InvestigationProjectedCohortAuthorError.bindingMismatch
            ) {
                _ = try InvestigationProjectedCohortAuthor(
                    now: bindingProbe.now,
                    identifiers: bindingProbe.identifiers
                ).author(
                    configurationData: data, installedBinding: foreignBinding
                )
            }
            #expect(bindingProbe.identifierCallCount == 0)
        }

        let validIDs = try generatedIdentifiers()
        let zero = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        let duplicate = try generatedIdentifiers(
            epochUUIDs: Array(repeating: validIDs.epochUUIDs[0], count: 8))
        let zeroed = try generatedIdentifiers(outerAttemptUUID: zero)
        let colliding = try generatedIdentifiers(
            outerAttemptUUID: configurations[0].nonce)
        var zeroEpochs = validIDs.epochUUIDs
        zeroEpochs[0] = zero
        let zeroEpoch = try generatedIdentifiers(epochUUIDs: zeroEpochs)
        let tooFew = try generatedIdentifiers(
            epochUUIDs: Array(validIDs.epochUUIDs.dropLast()))
        let tooMany = try generatedIdentifiers(
            epochUUIDs: validIDs.epochUUIDs + [try Self.uuid(0x90)])
        let outerEpochCollision = try generatedIdentifiers(
            outerAttemptUUID: validIDs.epochUUIDs[0])
        var epochConfigurationCollisionIDs = validIDs.epochUUIDs
        epochConfigurationCollisionIDs[0] = configurations[0].nonce
        let epochConfigurationCollision = try generatedIdentifiers(
            epochUUIDs: epochConfigurationCollisionIDs)
        for generated in [
            duplicate, zeroed, colliding, zeroEpoch, tooFew, tooMany,
            outerEpochCollision, epochConfigurationCollision,
        ] {
            let probe = ProjectedCohortAuthorProbe(
                now: fixture.now, identifiers: generated
            )
            #expect(
                throws: InvestigationProjectedCohortAuthorError
                    .invalidIdentifiers
            ) {
                _ = try InvestigationProjectedCohortAuthor(
                    now: probe.now, identifiers: probe.identifiers
                ).author(
                    configurationData: data,
                    installedBinding: try installedBinding(fixture.binding())
                )
            }
            #expect(probe.identifierCallCount == 1)
        }

        let failure = ProjectedCohortAuthorProbe(
            now: fixture.now,
            identifiers: validIDs,
            identifierError: ProjectedCohortTestError.identifierFailure
        )
        #expect(
            throws: InvestigationProjectedCohortAuthorError
                .identifierGenerationFailed
        ) {
            _ = try InvestigationProjectedCohortAuthor(
                now: failure.now, identifiers: failure.identifiers
            ).author(
                configurationData: data,
                installedBinding: try installedBinding(fixture.binding())
            )
        }
        #expect(failure.identifierCallCount == 1)
    }

    @Test
    func rejectsNonCanonicalDriverCodeDirectoryHashes() throws {
        let fixture = try SignedRuntimeContractFixture(
            now: Date(timeIntervalSince1970: 1_800_000_000))
        defer { fixture.remove() }
        let binding = fixture.binding()
        for invalid in [
            String(repeating: "A", count: 40),
            String(repeating: "a", count: 39),
            String(repeating: "g", count: 40),
            String(repeating: "a", count: 42),
        ] {
            #expect(
                throws: InvestigationProjectedCohortAuthorError
                    .invalidInstalledBinding
            ) {
                _ = try installedBinding(
                    binding, machineDriverCodeDirectoryHash: invalid
                )
            }
        }
        #expect(
            try installedBinding(
                binding, machineDriverCodeDirectoryHash: String(
                    repeating: "a", count: 40
                )
            ).machineDriverCodeDirectoryHash.count == 20
        )
        #expect(
            try installedBinding(
                binding, machineDriverCodeDirectoryHash: String(
                    repeating: "b", count: 64
                )
            ).machineDriverCodeDirectoryHash.count == 32
        )
    }

    @Test
    func rejectsEveryInvalidInstalledBindingField() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        for field in InvalidInstalledBindingSHAField.allCases {
            for invalid in [
                String(repeating: "A", count: 64),
                String(repeating: "a", count: 63),
                String(repeating: "g", count: 64),
            ] {
                #expect(
                    throws: InvestigationProjectedCohortAuthorError
                        .invalidInstalledBinding
                ) {
                    _ = try installedBinding(
                        fixture.binding(), mutation: field, mutationValue: invalid,
                        machineDriverCodeDirectoryHash:
                            field == .machineDriverCodeDirectoryHash ? invalid : nil,
                        invalid: invalid)
                }
            }
        }
        for identifier in InvalidInstalledBindingIdentifier.allCases {
            #expect(
                throws: InvestigationProjectedCohortAuthorError
                    .invalidInstalledBinding
            ) {
                _ = try installedBinding(
                    fixture.binding(), identifier: identifier)
            }
        }
    }

    @Test
    func roundTripsAsCanonicalProjectedCohortInput() throws {
        let fixture = try SignedRuntimeContractFixture()
        defer { fixture.remove() }
        let output = try InvestigationProjectedCohortAuthor(
            now: { fixture.now },
            identifiers: { try generatedIdentifiers() }
        ).author(
            configurationData: try fixture.machineConfigurations().map {
                try $0.canonicalJSONData()
            },
            installedBinding: try installedBinding(fixture.binding())
        )
        let encoded = try output.encoded()
        let decoded = try InvestigationProjectedCohortInput.decode(encoded)
        #expect(decoded == output)
        #expect(try decoded.encoded() == encoded)
    }

    @Test
    func producerSurfaceRemainsPackageOnlyAndAuthorityFree() throws {
        #expect(
            !(InvestigationProjectedCohortInstalledBinding.self
                is any Codable.Type)
        )
        #expect(
            !(InvestigationProjectedCohortGeneratedIdentifiers.self
                is any Codable.Type)
        )
        #expect(!(InvestigationProjectedCohortAuthor.self is any Codable.Type))
    }

    private func installedBinding(
        _ binding: SignedInvestigationRuntimeBinding,
        mutation: InvalidInstalledBindingSHAField? = nil,
        mutationValue: String = String(repeating: "9", count: 64),
        machineDriverCodeDirectoryHash: String? = nil,
        identifier: InvalidInstalledBindingIdentifier? = nil,
        invalid: String = "com.example.foreign"
    ) throws -> InvestigationProjectedCohortInstalledBinding {
        try InvestigationProjectedCohortInstalledBinding(
            appExecutableSHA256: mutation == .appExecutableSHA256
                ? mutationValue
                : binding.appExecutableSHA256,
            appBundleIdentifier: identifier == .appBundleIdentifier
                ? invalid : binding.appBundleIdentifier,
            helperExecutableSHA256: mutation == .helperExecutableSHA256
                ? mutationValue
                : binding.helperExecutableSHA256,
            helperServiceIdentifier: identifier == .helperServiceIdentifier
                ? invalid : binding.helperServiceIdentifier,
            machineDriverExecutableSHA256:
                mutation == .machineDriverExecutableSHA256
                    ? mutationValue
                    : binding.machineDriver.executableSHA256,
            machineDriverSigningIdentifier:
                identifier == .machineDriverSigningIdentifier
                    ? invalid : binding.machineDriver.signingIdentifier,
            machineDriverDesignatedRequirementSHA256:
                mutation == .machineDriverDesignatedRequirementSHA256
                    ? mutationValue
                    : binding.machineDriver.designatedRequirementSHA256,
            machineDriverCodeDirectoryHash:
                machineDriverCodeDirectoryHash
                    ?? (mutation == .machineDriverCodeDirectoryHash
                        ? mutationValue
                        : nil)
                    ?? binding.machineDriver.codeDirectoryHash,
            machineClaimServiceIdentifier:
                identifier == .machineClaimServiceIdentifier
                    ? invalid : binding.machineDriver.machineClaimServiceIdentifier
        )
    }

    private func generatedIdentifiers(
        outerAttemptUUID: UUID? = nil, epochUUIDs: [UUID]? = nil
    ) throws
        -> InvestigationProjectedCohortGeneratedIdentifiers
    {
        try InvestigationProjectedCohortGeneratedIdentifiers(
            outerAttemptUUID: outerAttemptUUID ?? Self.uuid(0x80),
            epochUUIDs: epochUUIDs
                ?? (0..<8).map { try Self.uuid(UInt8(0x81 + $0)) })
    }

    private func configuration(
        replacing source: SignedInvestigationRuntimeDiagnosticConfiguration,
        binding: SignedInvestigationRuntimeBinding,
        nonce: UUID? = nil,
        now: Date
    ) throws -> SignedInvestigationRuntimeDiagnosticConfiguration {
        try SignedInvestigationRuntimeDiagnosticConfiguration(
            nonce: nonce ?? source.nonce,
            scenario: source.scenario,
            optIn: source.optIn,
            diagnosticRootPath: source.diagnosticRootPath,
            sourceRootPath: source.sourceRootPath,
            supportRootPath: source.supportRootPath,
            runtimeRootPath: source.runtimeRootPath,
            reportPath: source.reportPath,
            storePath: source.storePath,
            binding: binding,
            expectedModel: source.expectedModel,
            expectedProvider: source.expectedProvider,
            validBefore: source.validBefore,
            maximumWallClockSeconds: source.maximumWallClockSeconds,
            maximumTurns: source.maximumTurns,
            maximumProbeCalls: source.maximumProbeCalls,
            maximumContextBytes: source.maximumContextBytes,
            now: now
        )
    }

    private func replacingFirst(_ data: [Data], with first: Data) -> [Data] {
        [first] + Array(data.dropFirst())
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func canonicalJSON(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }

    private static func uuid(_ byte: UInt8) throws -> UUID {
        try #require(
            UUID(
                uuidString: "00000000-0000-0000-0000-0000000000"
                    + String(format: "%02x", byte)
            )
        )
    }
}

private enum ProjectedCohortTestError: Error {
    case identifierFailure
}

private enum InvalidInstalledBindingSHAField: CaseIterable {
    case appExecutableSHA256, helperExecutableSHA256
    case machineDriverExecutableSHA256, machineDriverDesignatedRequirementSHA256
    case machineDriverCodeDirectoryHash
}

private enum InvalidInstalledBindingIdentifier: CaseIterable {
    case appBundleIdentifier, helperServiceIdentifier
    case machineDriverSigningIdentifier, machineClaimServiceIdentifier
}

private final class ProjectedCohortAuthorProbe: @unchecked Sendable {
    private let lock = NSLock()
    private let value: Date
    private let generated: InvestigationProjectedCohortGeneratedIdentifiers
    private let identifierError: (any Error)?
    private var nowCalls = 0
    private var identifierCalls = 0

    init(
        now: Date,
        identifiers: InvestigationProjectedCohortGeneratedIdentifiers,
        identifierError: (any Error)? = nil
    ) {
        value = now
        generated = identifiers
        self.identifierError = identifierError
    }

    var now: @Sendable () -> Date {
        { [self] in
            lock.withLock { nowCalls += 1 }
            return value
        }
    }

    var identifiers: @Sendable () throws
        -> InvestigationProjectedCohortGeneratedIdentifiers
    {
        { [self] in
            lock.withLock { identifierCalls += 1 }
            if let identifierError { throw identifierError }
            return generated
        }
    }

    var nowCallCount: Int { lock.withLock { nowCalls } }
    var identifierCallCount: Int { lock.withLock { identifierCalls } }
}
