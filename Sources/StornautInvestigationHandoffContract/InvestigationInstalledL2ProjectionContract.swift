import Foundation

package struct InvestigationInstalledL2IdentityProjection:
    Sendable,
    Equatable
{
    package static let domain =
        "stornaut.task39.installed-l2.identity-projection"
    package static let maximumByteCount = 2_048
    package static let fixedAppBundleIdentifier = "com.eriklee.stornaut"
    package static let fixedHelperServiceIdentifier =
        "com.eriklee.stornaut.lifecycle"
    package static let fixedMachineDriverSigningIdentifier =
        "com.eriklee.stornaut.investigation.machine-driver"
    package static let fixedMachineClaimServiceIdentifier =
        "com.eriklee.stornaut.lifecycle.machine-claim"

    package let epochUUID: UUID
    package let configurationNonce: UUID
    package let configurationValidBefore: InvestigationHandoffUTCMicroseconds
    package let configurationSHA256: InvestigationHandoffSHA256
    package let signedRuntimeBindingSHA256: InvestigationHandoffSHA256
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
    package let projectionSHA256: InvestigationHandoffSHA256

    package init(
        epochUUID: UUID,
        configurationNonce: UUID,
        configurationValidBefore: InvestigationHandoffUTCMicroseconds,
        configurationSHA256: InvestigationHandoffSHA256,
        signedRuntimeBindingSHA256: InvestigationHandoffSHA256,
        appExecutableSHA256: InvestigationHandoffSHA256,
        appBundleIdentifier: String,
        helperExecutableSHA256: InvestigationHandoffSHA256,
        helperServiceIdentifier: String,
        machineDriverExecutableSHA256: InvestigationHandoffSHA256,
        machineDriverSigningIdentifier: String,
        machineDriverDesignatedRequirementSHA256: InvestigationHandoffSHA256,
        machineDriverCodeDirectoryHash: Data,
        machineClaimServiceIdentifier: String
    ) throws {
        guard
            handoffUUIDIsNonzero(epochUUID),
            handoffUUIDIsNonzero(configurationNonce),
            epochUUID != configurationNonce,
            appBundleIdentifier == Self.fixedAppBundleIdentifier,
            helperServiceIdentifier == Self.fixedHelperServiceIdentifier,
            machineDriverSigningIdentifier
                == Self.fixedMachineDriverSigningIdentifier,
            machineClaimServiceIdentifier
                == Self.fixedMachineClaimServiceIdentifier,
            machineDriverCodeDirectoryHash.count == 20
                || machineDriverCodeDirectoryHash.count == 32
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        self.epochUUID = epochUUID
        self.configurationNonce = configurationNonce
        self.configurationValidBefore = configurationValidBefore
        self.configurationSHA256 = configurationSHA256
        self.signedRuntimeBindingSHA256 = signedRuntimeBindingSHA256
        self.appExecutableSHA256 = appExecutableSHA256
        self.appBundleIdentifier = appBundleIdentifier
        self.helperExecutableSHA256 = helperExecutableSHA256
        self.helperServiceIdentifier = helperServiceIdentifier
        self.machineDriverExecutableSHA256 = machineDriverExecutableSHA256
        self.machineDriverSigningIdentifier = machineDriverSigningIdentifier
        self.machineDriverDesignatedRequirementSHA256 =
            machineDriverDesignatedRequirementSHA256
        self.machineDriverCodeDirectoryHash = machineDriverCodeDirectoryHash
        self.machineClaimServiceIdentifier = machineClaimServiceIdentifier
        projectionSHA256 = InvestigationHandoffSHA256.hashing(
            try Self.encode(
                epochUUID: epochUUID,
                configurationNonce: configurationNonce,
                configurationValidBefore: configurationValidBefore,
                configurationSHA256: configurationSHA256,
                signedRuntimeBindingSHA256: signedRuntimeBindingSHA256,
                appExecutableSHA256: appExecutableSHA256,
                appBundleIdentifier: appBundleIdentifier,
                helperExecutableSHA256: helperExecutableSHA256,
                helperServiceIdentifier: helperServiceIdentifier,
                machineDriverExecutableSHA256: machineDriverExecutableSHA256,
                machineDriverSigningIdentifier: machineDriverSigningIdentifier,
                machineDriverDesignatedRequirementSHA256:
                    machineDriverDesignatedRequirementSHA256,
                machineDriverCodeDirectoryHash: machineDriverCodeDirectoryHash,
                machineClaimServiceIdentifier: machineClaimServiceIdentifier,
                projectionSHA256: try InvestigationHandoffSHA256(
                    rawBytes: Data(repeating: 0, count: 32)
                )
            )
        )
    }

    package func encoded() throws -> Data {
        try Self.encode(
            epochUUID: epochUUID,
            configurationNonce: configurationNonce,
            configurationValidBefore: configurationValidBefore,
            configurationSHA256: configurationSHA256,
            signedRuntimeBindingSHA256: signedRuntimeBindingSHA256,
            appExecutableSHA256: appExecutableSHA256,
            appBundleIdentifier: appBundleIdentifier,
            helperExecutableSHA256: helperExecutableSHA256,
            helperServiceIdentifier: helperServiceIdentifier,
            machineDriverExecutableSHA256: machineDriverExecutableSHA256,
            machineDriverSigningIdentifier: machineDriverSigningIdentifier,
            machineDriverDesignatedRequirementSHA256:
                machineDriverDesignatedRequirementSHA256,
            machineDriverCodeDirectoryHash: machineDriverCodeDirectoryHash,
            machineClaimServiceIdentifier: machineClaimServiceIdentifier,
            projectionSHA256: projectionSHA256
        )
    }

    package static func decode(_ data: Data) throws -> Self {
        let fields = try HandoffBinaryTranscript.decode(
            data,
            expectedDomain: domain,
            expectedBusinessFieldByteCounts: [
                16...16, 16...16, 8...8, 32...32, 32...32, 32...32,
                1...256, 32...32, 1...256, 32...32, 1...256, 32...32,
                20...32, 1...256, 32...32,
            ],
            maximumByteCount: maximumByteCount
        )
        let projection = try Self(
            epochUUID: handoffUUID(fields[0]),
            configurationNonce: handoffUUID(fields[1]),
            configurationValidBefore: InvestigationHandoffUTCMicroseconds(
                rawValue: handoffDecodeInt64(fields[2])
            ),
            configurationSHA256: InvestigationHandoffSHA256(
                rawBytes: fields[3]
            ),
            signedRuntimeBindingSHA256: InvestigationHandoffSHA256(
                rawBytes: fields[4]
            ),
            appExecutableSHA256: InvestigationHandoffSHA256(
                rawBytes: fields[5]
            ),
            appBundleIdentifier: try identifier(fields[6]),
            helperExecutableSHA256: InvestigationHandoffSHA256(
                rawBytes: fields[7]
            ),
            helperServiceIdentifier: try identifier(fields[8]),
            machineDriverExecutableSHA256: InvestigationHandoffSHA256(
                rawBytes: fields[9]
            ),
            machineDriverSigningIdentifier: try identifier(fields[10]),
            machineDriverDesignatedRequirementSHA256:
                InvestigationHandoffSHA256(rawBytes: fields[11]),
            machineDriverCodeDirectoryHash: fields[12],
            machineClaimServiceIdentifier: try identifier(fields[13])
        )
        guard
            try InvestigationHandoffSHA256(rawBytes: fields[14])
                == projection.projectionSHA256,
            try projection.encoded() == data
        else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        return projection
    }

    private static func encode(
        epochUUID: UUID,
        configurationNonce: UUID,
        configurationValidBefore: InvestigationHandoffUTCMicroseconds,
        configurationSHA256: InvestigationHandoffSHA256,
        signedRuntimeBindingSHA256: InvestigationHandoffSHA256,
        appExecutableSHA256: InvestigationHandoffSHA256,
        appBundleIdentifier: String,
        helperExecutableSHA256: InvestigationHandoffSHA256,
        helperServiceIdentifier: String,
        machineDriverExecutableSHA256: InvestigationHandoffSHA256,
        machineDriverSigningIdentifier: String,
        machineDriverDesignatedRequirementSHA256: InvestigationHandoffSHA256,
        machineDriverCodeDirectoryHash: Data,
        machineClaimServiceIdentifier: String,
        projectionSHA256: InvestigationHandoffSHA256
    ) throws -> Data {
        try HandoffBinaryTranscript.encode(
            domain: domain,
            businessFields: [
                handoffData(epochUUID), handoffData(configurationNonce),
                handoffData(configurationValidBefore.rawValue),
                configurationSHA256.rawBytes, signedRuntimeBindingSHA256.rawBytes,
                appExecutableSHA256.rawBytes, Data(appBundleIdentifier.utf8),
                helperExecutableSHA256.rawBytes, Data(helperServiceIdentifier.utf8),
                machineDriverExecutableSHA256.rawBytes,
                Data(machineDriverSigningIdentifier.utf8),
                machineDriverDesignatedRequirementSHA256.rawBytes,
                machineDriverCodeDirectoryHash,
                Data(machineClaimServiceIdentifier.utf8), projectionSHA256.rawBytes,
            ],
            maximumByteCount: maximumByteCount
        )
    }

    private static func identifier(_ data: Data) throws -> String {
        guard
            let value = String(data: data, encoding: .utf8),
            Data(value.utf8) == data
        else {
            throw InvestigationHandoffContractError.invalidEncoding
        }
        return value
    }
}

package struct InvestigationInstalledL2ClockSample: Sendable, Equatable {
    package let wallUTC: InvestigationHandoffUTCMicroseconds
    package let continuousNanoseconds: UInt64

    package init(
        wallUTC: InvestigationHandoffUTCMicroseconds,
        continuousNanoseconds: UInt64
    ) throws {
        guard continuousNanoseconds > 0 else {
            throw InvestigationHandoffContractError.invalidValue
        }
        self.wallUTC = wallUTC
        self.continuousNanoseconds = continuousNanoseconds
    }
}

package struct InvestigationInstalledL2TemporalWindow: Sendable, Equatable {
    package let projectionSHA256: InvestigationHandoffSHA256
    package let claimEvidenceSHA256: InvestigationHandoffSHA256
    package let epochUUID: UUID
    package let configurationNonce: UUID
    package let claimedAt: InvestigationHandoffUTCMicroseconds
    package let started: InvestigationInstalledL2ClockSample
    package let observed: InvestigationInstalledL2ClockSample
    package let configurationValidBefore: InvestigationHandoffUTCMicroseconds
    package let releaseDeadlineNanoseconds: UInt64
    package let epochDeadlineNanoseconds: UInt64

    package init(
        projection: InvestigationInstalledL2IdentityProjection,
        claimEvidence: InvestigationMachineClaimEvidence,
        epochBootstrap: InvestigationHandoffEpochBootstrap,
        started: InvestigationInstalledL2ClockSample,
        observed: InvestigationInstalledL2ClockSample
    ) throws {
        guard
            projection.epochUUID == epochBootstrap.epochUUID,
            claimEvidence.l1Residue.investigationUUID
                == projection.configurationNonce,
            claimEvidence.claimedAt <= started.wallUTC,
            started.wallUTC <= observed.wallUTC,
            observed.wallUTC < projection.configurationValidBefore,
            started.continuousNanoseconds <= observed.continuousNanoseconds,
            observed.continuousNanoseconds
                < claimEvidence.releaseDeadlineNanoseconds,
            claimEvidence.releaseDeadlineNanoseconds
                <= epochBootstrap.epochDeadlineNanoseconds
        else {
            throw InvestigationHandoffContractError.invalidValue
        }
        projectionSHA256 = projection.projectionSHA256
        claimEvidenceSHA256 = InvestigationHandoffSHA256.hashing(
            try claimEvidence.encoded()
        )
        epochUUID = projection.epochUUID
        configurationNonce = projection.configurationNonce
        claimedAt = claimEvidence.claimedAt
        self.started = started
        self.observed = observed
        configurationValidBefore = projection.configurationValidBefore
        releaseDeadlineNanoseconds = claimEvidence.releaseDeadlineNanoseconds
        epochDeadlineNanoseconds = epochBootstrap.epochDeadlineNanoseconds
    }
}
