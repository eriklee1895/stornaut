import Foundation

package struct InvestigationHistoricalGateCapsule: Sendable, Equatable {
    package let outerAttemptUUID: UUID
    package let wholeInputSHA256: InvestigationHandoffSHA256
    package let byteCount: Int64
    package let fileSHA256: InvestigationHandoffSHA256

    package init(
        outerAttemptUUID: UUID,
        wholeInputSHA256: InvestigationHandoffSHA256,
        byteCount: Int64,
        fileSHA256: InvestigationHandoffSHA256
    ) throws {
        guard
            outerAttemptUUID.uuidString.lowercased()
                != "00000000-0000-0000-0000-000000000000",
            byteCount > 0,
            byteCount <= Int64(InvestigationProjectedCohortInput.maximumByteCount),
            wholeInputSHA256.rawBytes.contains(where: { $0 != 0 }),
            fileSHA256.rawBytes.contains(where: { $0 != 0 })
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        self.outerAttemptUUID = outerAttemptUUID
        self.wholeInputSHA256 = wholeInputSHA256
        self.byteCount = byteCount
        self.fileSHA256 = fileSHA256
    }

    package var attemptName: String {
        "attempt-" + outerAttemptUUID.uuidString.lowercased()
    }

    package var capsuleName: String {
        "projected-cohort-" + wholeInputSHA256.lowercaseHex + ".bin"
    }

    package static func retainedV11() throws -> Self {
        guard let attempt = UUID(
            uuidString: "18a85048-5e1c-40c5-99e4-3785185070d3"
        ) else {
            throw InvestigationHandoffContractError.invalidValue
        }
        return try Self(
            outerAttemptUUID: attempt,
            wholeInputSHA256: .init(lowercaseHex:
                "a2cf07a731ffe2bb02a98cd61a9240cf93d514d97071f7c83ba6fb9bf56d6104"),
            byteCount: 28_997,
            fileSHA256: .init(lowercaseHex:
                "f656a28ec6ac77c65b89b73b28932c716c74427acaa1ef14fedab4e816140e72")
        )
    }

    package static func retainedV13() throws -> Self {
        guard let attempt = UUID(
            uuidString: "a77c4d21-9bba-46f6-b694-3d1d1e55209d"
        ) else {
            throw InvestigationHandoffContractError.invalidValue
        }
        return try Self(
            outerAttemptUUID: attempt,
            wholeInputSHA256: .init(lowercaseHex:
                "c484b8c14a5e70a4ee4364584013f864af30738c52494ebb727ac4fb326dfdc0"),
            byteCount: 28_997,
            fileSHA256: .init(lowercaseHex:
                "1567a7fc8f13da51b69c134bb79ac132d383ae30496bb5ae86674ac3fa9f8a17")
        )
    }
}

package struct InvestigationProjectedCohortSelection:
    Sendable,
    Equatable
{
    package let epoch: InvestigationCohortEpoch
    package let projection: InvestigationInstalledL2IdentityProjection
}

package struct InvestigationProjectedCohortInput:
    Sendable,
    Equatable
{
    package static let domain =
        "stornaut.task39.l3c3cii.projected-cohort-input"
    package static let projectionCount = InvestigationCohortCapsule.epochCount
    package static let maximumByteCount = 1_069_056

    package let capsule: InvestigationCohortCapsule
    package let projections: [InvestigationInstalledL2IdentityProjection]
    package let wholeInputSHA256: InvestigationHandoffSHA256

    package init(
        capsule: InvestigationCohortCapsule,
        projections: [InvestigationInstalledL2IdentityProjection]
    ) throws {
        try Self.validate(capsule: capsule, projections: projections)
        self.capsule = capsule
        self.projections = projections
        wholeInputSHA256 = InvestigationHandoffSHA256.hashing(
            try Self.encode(
                capsule: capsule,
                projections: projections,
                wholeInputSHA256: try InvestigationHandoffSHA256(
                    rawBytes: Data(repeating: 0, count: 32)
                )
            )
        )
    }

    package func encoded() throws -> Data {
        try Self.encode(
            capsule: capsule,
            projections: projections,
            wholeInputSHA256: wholeInputSHA256
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let projectionBounds = Array(
            repeating: 1...InvestigationInstalledL2IdentityProjection
                .maximumByteCount,
            count: projectionCount
        )
        let fields = try HandoffBinaryTranscript.decode(
            data,
            expectedDomain: domain,
            expectedBusinessFieldByteCounts: [
                1...InvestigationCohortCapsule.maximumByteCount,
                4...4,
                32...32,
            ] + projectionBounds,
            maximumByteCount: maximumByteCount
        )
        guard try handoffDecodeUInt32(fields[1]) == UInt32(projectionCount) else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        let capsule = try InvestigationCohortCapsule.decode(fields[0])
        let projections = try fields.dropFirst(3).map {
            try InvestigationInstalledL2IdentityProjection.decode($0)
        }
        let input = try Self(capsule: capsule, projections: projections)
        guard
            try InvestigationHandoffSHA256(rawBytes: fields[2])
                == input.wholeInputSHA256,
            try input.encoded() == data
        else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        return input
    }

    package func selection(at index: Int) throws
        -> InvestigationProjectedCohortSelection
    {
        guard capsule.epochs.indices.contains(index) else {
            throw InvestigationHandoffContractError.invalidValue
        }
        return InvestigationProjectedCohortSelection(
            epoch: capsule.epochs[index],
            projection: projections[index]
        )
    }

    private static func encode(
        capsule: InvestigationCohortCapsule,
        projections: [InvestigationInstalledL2IdentityProjection],
        wholeInputSHA256: InvestigationHandoffSHA256
    ) throws -> Data {
        var fields = [
            try capsule.encoded(),
            handoffData(UInt32(projectionCount)),
            wholeInputSHA256.rawBytes,
        ]
        fields.append(contentsOf: try projections.map { try $0.encoded() })
        return try HandoffBinaryTranscript.encode(
            domain: domain,
            businessFields: fields,
            maximumByteCount: maximumByteCount
        )
    }

    private static func validate(
        capsule: InvestigationCohortCapsule,
        projections: [InvestigationInstalledL2IdentityProjection]
    ) throws {
        guard
            capsule.epochs.count == projectionCount,
            projections.count == projectionCount
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        for (epoch, projection) in zip(capsule.epochs, projections) {
            guard
                projection.epochUUID == epoch.epochUUID,
                projection.configurationNonce == epoch.configurationNonce,
                projection.configurationSHA256 == epoch.configurationSHA256,
                projection.signedRuntimeBindingSHA256
                    == epoch.signedRuntimeBindingSHA256
            else {
                throw InvestigationHandoffContractError.invalidValue
            }
        }
    }
}
