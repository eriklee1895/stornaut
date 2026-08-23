import Foundation

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
