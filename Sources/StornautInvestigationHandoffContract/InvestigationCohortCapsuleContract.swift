import Foundation

package struct InvestigationCohortEpoch:
    Sendable,
    Equatable
{
    package static let domain =
        "stornaut.task39.l3c3cii.cohort.epoch"
    package static let maximumByteCount = 66_048
    package static let maximumConfigurationByteCount = 65_536

    package let ordinal: UInt32
    package let epochUUID: UUID
    package let scenario: InvestigationHandoffScenario
    package let configurationNonce: UUID
    package let configuration: Data
    package let configurationSHA256: InvestigationHandoffSHA256
    package let signedRuntimeBindingSHA256: InvestigationHandoffSHA256

    package init(
        ordinal: UInt32,
        epochUUID: UUID,
        scenario: InvestigationHandoffScenario,
        configurationNonce: UUID,
        configuration: Data,
        configurationSHA256: InvestigationHandoffSHA256,
        signedRuntimeBindingSHA256: InvestigationHandoffSHA256
    ) throws {
        guard
            ordinal < 8,
            scenario.rawValue == ordinal + 1,
            handoffUUIDIsNonzero(epochUUID),
            handoffUUIDIsNonzero(configurationNonce),
            epochUUID != configurationNonce,
            (1...Self.maximumConfigurationByteCount).contains(
                configuration.count
            ),
            configurationSHA256
                == InvestigationHandoffSHA256.hashing(configuration)
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        self.ordinal = ordinal
        self.epochUUID = epochUUID
        self.scenario = scenario
        self.configurationNonce = configurationNonce
        self.configuration = configuration
        self.configurationSHA256 = configurationSHA256
        self.signedRuntimeBindingSHA256 =
            signedRuntimeBindingSHA256
    }

    package func encoded() throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: Self.domain,
            businessFields: [
                handoffData(ordinal),
                handoffData(epochUUID),
                handoffData(scenario.rawValue),
                handoffData(configurationNonce),
                handoffData(UInt32(configuration.count)),
                configurationSHA256.rawBytes,
                signedRuntimeBindingSHA256.rawBytes,
                configuration,
            ],
            maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let fields = try HandoffBinaryTranscript.decode(
            data,
            expectedDomain: domain,
            expectedBusinessFieldByteCounts: [
                4...4, 16...16, 4...4, 16...16, 4...4,
                32...32, 32...32,
                1...maximumConfigurationByteCount,
            ],
            maximumByteCount: maximumByteCount
        )
        let ordinal = try handoffDecodeUInt32(fields[0])
        guard let scenario = InvestigationHandoffScenario(
            rawValue: try handoffDecodeUInt32(fields[2])
        ) else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        guard
            let declaredByteCount = Int(
                exactly: try handoffDecodeUInt32(fields[4])
            ),
            declaredByteCount == fields[7].count
        else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        return try Self(
            ordinal: ordinal,
            epochUUID: handoffUUID(fields[1]),
            scenario: scenario,
            configurationNonce: handoffUUID(fields[3]),
            configuration: fields[7],
            configurationSHA256: InvestigationHandoffSHA256(
                rawBytes: fields[5]
            ),
            signedRuntimeBindingSHA256: InvestigationHandoffSHA256(
                rawBytes: fields[6]
            )
        )
    }

    package func validate(
        configurationAcknowledgement:
            InvestigationHandoffConfigurationAcknowledgement,
        retirementHandle: InvestigationHandoffRetirementHandle
    ) throws {
        guard
            configurationAcknowledgement.epochUUID == epochUUID,
            configurationAcknowledgement.ordinal == ordinal,
            configurationAcknowledgement.configurationNonce
                == configurationNonce,
            configurationAcknowledgement.scenario == scenario,
            configurationAcknowledgement.configurationSHA256
                == configurationSHA256,
            configurationAcknowledgement.signedRuntimeBindingSHA256
                == signedRuntimeBindingSHA256,
            retirementHandle.investigationUUID == configurationNonce,
            retirementHandle.configurationSHA256 == configurationSHA256
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
    }
}

package struct InvestigationCohortCapsule:
    Sendable,
    Equatable
{
    package static let domain = "stornaut.task39.l3c3cii.cohort"
    package static let maximumByteCount = 1_048_576
    package static let epochCount = 8

    package let outerAttemptUUID: UUID
    package let epochs: [InvestigationCohortEpoch]
    package let wholeCapsuleSHA256: InvestigationHandoffSHA256

    package init(
        outerAttemptUUID: UUID,
        epochs: [InvestigationCohortEpoch]
    ) throws {
        try Self.validate(
            outerAttemptUUID: outerAttemptUUID,
            epochs: epochs
        )
        self.outerAttemptUUID = outerAttemptUUID
        self.epochs = epochs
        wholeCapsuleSHA256 = InvestigationHandoffSHA256.hashing(
            try Self.encode(
                outerAttemptUUID: outerAttemptUUID,
                epochs: epochs,
                capsuleSHA256: try InvestigationHandoffSHA256(
                    rawBytes: Data(repeating: 0, count: 32)
                )
            )
        )
    }

    package func encoded() throws -> Data {
        try Self.encode(
            outerAttemptUUID: outerAttemptUUID,
            epochs: epochs,
            capsuleSHA256: wholeCapsuleSHA256
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let epochBounds = Array(
            repeating: 1...InvestigationCohortEpoch.maximumByteCount,
            count: epochCount
        )
        let fields = try HandoffBinaryTranscript.decode(
            data,
            expectedDomain: domain,
            expectedBusinessFieldByteCounts:
                [16...16, 4...4, 32...32] + epochBounds,
            maximumByteCount: maximumByteCount
        )
        guard
            try handoffDecodeUInt32(fields[1]) == UInt32(epochCount)
        else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        let encodedDigest = try InvestigationHandoffSHA256(
            rawBytes: fields[2]
        )
        let epochs = try fields.dropFirst(3).map {
            try InvestigationCohortEpoch.decode($0)
        }
        let capsule = try Self(
            outerAttemptUUID: handoffUUID(fields[0]),
            epochs: epochs
        )
        guard
            encodedDigest == capsule.wholeCapsuleSHA256,
            try capsule.encoded() == data
        else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        return capsule
    }

    private static func encode(
        outerAttemptUUID: UUID,
        epochs: [InvestigationCohortEpoch],
        capsuleSHA256: InvestigationHandoffSHA256
    ) throws -> Data {
        var fields = [
            handoffData(outerAttemptUUID),
            handoffData(UInt32(epochCount)),
            capsuleSHA256.rawBytes,
        ]
        fields.append(contentsOf: try epochs.map { try $0.encoded() })
        return try HandoffBinaryTranscript.encode(
            domain: domain,
            businessFields: fields,
            maximumByteCount: maximumByteCount
        )
    }

    private static func validate(
        outerAttemptUUID: UUID,
        epochs: [InvestigationCohortEpoch]
    ) throws {
        guard
            handoffUUIDIsNonzero(outerAttemptUUID),
            epochs.count == epochCount,
            epochs.map(\.ordinal) == Array(UInt32(0)...UInt32(7)),
            epochs.map(\.scenario) == InvestigationHandoffScenario.allCases
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        let identifiers = [outerAttemptUUID]
            + epochs.map(\.epochUUID)
            + epochs.map(\.configurationNonce)
        guard
            identifiers.allSatisfy(handoffUUIDIsNonzero),
            Set(identifiers).count == 17
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
    }
}
