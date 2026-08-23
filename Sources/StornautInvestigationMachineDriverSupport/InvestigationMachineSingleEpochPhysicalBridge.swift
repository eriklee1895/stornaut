import Foundation
import StornautInvestigationHandoffContract

package enum InvestigationMachineSingleEpochPhysicalBridgeError:
    Error, Sendable, Equatable
{
    case invalidInvocation
    case invalidPhysicalResult
}

package struct InvestigationMachineSingleEpochInvocation:
    Sendable, Equatable
{
    private static let genesisDomain =
        "stornaut.task39.machine.epoch-invocation.genesis"
    private static let successorDomain =
        "stornaut.task39.machine.epoch-invocation.successor"
    private static let maximumByteCount = 96 * 1_024

    package let selection: InvestigationMachineFixedEpochSelection
    package let previousHelperIdentity: InvestigationMachineProcessIdentity?
    package let predecessorSHA256: InvestigationHandoffSHA256
    package let predecessorTranscript: Data

    package init(
        selection: InvestigationMachineFixedEpochSelection,
        previousHelperIdentity: InvestigationMachineProcessIdentity?,
        predecessorSHA256: InvestigationHandoffSHA256,
        predecessorTranscript: Data
    ) throws {
        try bridgeValidateSelection(selection)
        guard
            bridgeNonzero(predecessorSHA256),
            InvestigationHandoffSHA256.hashing(predecessorTranscript)
                == predecessorSHA256
        else {
            throw InvestigationMachineSingleEpochPhysicalBridgeError
                .invalidInvocation
        }
        try Self.validatePredecessor(
            predecessorTranscript, selection: selection,
            previousHelperIdentity: previousHelperIdentity
        )
        self.selection = selection
        self.previousHelperIdentity = previousHelperIdentity
        self.predecessorSHA256 = predecessorSHA256
        self.predecessorTranscript = predecessorTranscript
    }

    package func encoded() throws -> Data {
        let epoch = try selection.epoch.encoded()
        let projection = try selection.projection.encoded()
        var fields = [
            bridgeData(selection.outerAttemptUUID),
            selection.wholeCapsuleSHA256.rawBytes,
            selection.wholeInputSHA256.rawBytes,
            epoch, projection, predecessorTranscript,
            predecessorSHA256.rawBytes,
        ]
        let domain: String
        if let previousHelperIdentity {
            domain = Self.successorDomain
            fields.append(try previousHelperIdentity.encoded())
        } else {
            domain = Self.genesisDomain
        }
        return try HandoffBinaryTranscript.encode(
            domain: domain, businessFields: fields,
            maximumByteCount: Self.maximumByteCount
        )
    }

    package static func decode(
        _ data: Data,
        expectedSelection: InvestigationMachineFixedEpochSelection
    ) throws -> Self {
        try bridgeValidateSelection(expectedSelection)
        let successor = expectedSelection.epoch.ordinal > 0
        let ranges: [ClosedRange<Int>] = [
            16...16, 32...32, 32...32,
            1...InvestigationCohortEpoch.maximumByteCount,
            1...InvestigationInstalledL2IdentityProjection.maximumByteCount,
            1...8_192, 32...32,
        ] + (successor
            ? [1...InvestigationMachineProcessIdentity.maximumByteCount]
            : [])
        let fields = try HandoffBinaryTranscript.decode(
            data,
            expectedDomain: successor ? successorDomain : genesisDomain,
            expectedBusinessFieldByteCounts: ranges,
            maximumByteCount: maximumByteCount
        )
        let epoch = try InvestigationCohortEpoch.decode(fields[3])
        let projection = try InvestigationInstalledL2IdentityProjection
            .decode(fields[4])
        guard
            try epoch.encoded() == fields[3],
            try projection.encoded() == fields[4],
            try bridgeUUID(fields[0]) == expectedSelection.outerAttemptUUID,
            try InvestigationHandoffSHA256(rawBytes: fields[1])
                == expectedSelection.wholeCapsuleSHA256,
            try InvestigationHandoffSHA256(rawBytes: fields[2])
                == expectedSelection.wholeInputSHA256,
            epoch == expectedSelection.epoch,
            projection == expectedSelection.projection
        else {
            throw InvestigationMachineSingleEpochPhysicalBridgeError
                .invalidInvocation
        }
        let previousHelper: InvestigationMachineProcessIdentity?
        if successor {
            let helper = try InvestigationMachineProcessIdentity.decode(fields[7])
            guard
                helper.role == .helper,
                try helper.encoded() == fields[7]
            else {
                throw InvestigationMachineSingleEpochPhysicalBridgeError
                    .invalidInvocation
            }
            previousHelper = helper
        } else {
            previousHelper = nil
        }
        let value = try Self(
            selection: expectedSelection,
            previousHelperIdentity: previousHelper,
            predecessorSHA256: InvestigationHandoffSHA256(
                rawBytes: fields[6]
            ),
            predecessorTranscript: fields[5]
        )
        guard try value.encoded() == data else {
            throw InvestigationMachineSingleEpochPhysicalBridgeError
                .invalidInvocation
        }
        return value
    }

    private static func validatePredecessor(
        _ data: Data,
        selection: InvestigationMachineFixedEpochSelection,
        previousHelperIdentity: InvestigationMachineProcessIdentity?
    ) throws {
        if selection.epoch.ordinal == 0 {
            guard previousHelperIdentity == nil else {
                throw InvestigationMachineSingleEpochPhysicalBridgeError
                    .invalidInvocation
            }
            let fields = try HandoffBinaryTranscript.decode(
                data,
                expectedDomain:
                    "stornaut.task39.machine.helper-continuity.genesis",
                expectedBusinessFieldByteCounts: [
                    16...16, 32...32, 32...32, 4...4, 16...16,
                ],
                maximumByteCount: 512
            )
            guard
                try bridgeUUID(fields[0]) == selection.outerAttemptUUID,
                try InvestigationHandoffSHA256(rawBytes: fields[1])
                    == selection.wholeCapsuleSHA256,
                try InvestigationHandoffSHA256(rawBytes: fields[2])
                    == selection.wholeInputSHA256,
                try bridgeUInt32(fields[3]) == 0,
                try bridgeUUID(fields[4]) == selection.epoch.epochUUID,
                try HandoffBinaryTranscript.encode(
                    domain:
                        "stornaut.task39.machine.helper-continuity.genesis",
                    businessFields: fields, maximumByteCount: 512
                ) == data
            else {
                throw InvestigationMachineSingleEpochPhysicalBridgeError
                    .invalidInvocation
            }
            return
        }

        guard let previousHelperIdentity else {
            throw InvestigationMachineSingleEpochPhysicalBridgeError
                .invalidInvocation
        }
        let fields = try HandoffBinaryTranscript.decode(
            data,
            expectedDomain:
                "stornaut.task39.machine.helper-continuity.successor",
            expectedBusinessFieldByteCounts: [
                16...16, 32...32, 32...32, 4...4, 16...16,
                1...InvestigationMachineProcessIdentity.maximumByteCount,
                32...32, 32...32, 32...32, 1...1,
            ],
            maximumByteCount: 4_096
        )
        let helper = try InvestigationMachineProcessIdentity.decode(fields[5])
        let completedOrdinal = try bridgeUInt32(fields[3])
        let previousEpochUUID = try bridgeUUID(fields[4])
        let expectedCompleted = selection.epoch.ordinal - 1
        let expectedMode: InvestigationMachineOuterContainmentMode =
            expectedCompleted == InvestigationHandoffScenario
                .lifecycleRecovery.rawValue - 1 ? .parentCrash : .normal
        guard
            try bridgeUUID(fields[0]) == selection.outerAttemptUUID,
            try InvestigationHandoffSHA256(rawBytes: fields[1])
                == selection.wholeCapsuleSHA256,
            try InvestigationHandoffSHA256(rawBytes: fields[2])
                == selection.wholeInputSHA256,
            completedOrdinal == expectedCompleted,
            bridgeUUIDIsNonzero(previousEpochUUID),
            previousEpochUUID != selection.outerAttemptUUID,
            previousEpochUUID != selection.epoch.epochUUID,
            previousEpochUUID != selection.epoch.configurationNonce,
            helper == previousHelperIdentity,
            helper.role == .helper,
            try helper.encoded() == fields[5],
            try bridgeDigest(fields[6]).rawBytes.contains(where: { $0 != 0 }),
            try bridgeDigest(fields[7]).rawBytes.contains(where: { $0 != 0 }),
            try bridgeDigest(fields[8]).rawBytes.contains(where: { $0 != 0 }),
            fields[9] == Data([expectedMode.rawValue]),
            try HandoffBinaryTranscript.encode(
                domain:
                    "stornaut.task39.machine.helper-continuity.successor",
                businessFields: fields, maximumByteCount: 4_096
            ) == data
        else {
            throw InvestigationMachineSingleEpochPhysicalBridgeError
                .invalidInvocation
        }
    }
}

package struct InvestigationMachineSingleEpochPhysicalResult:
    Sendable, Equatable
{
    private static let ownershipDomain =
        "stornaut.task39.machine.physical-ownership"
    private static let completionDomain =
        "stornaut.task39.machine.physical-completion"
    private static let maximumOwnershipByteCount = 8_192
    private static let maximumCompletionByteCount = 12_288

    private let ownership: Ownership
    private let completion: Completion?

    package var helperIdentity: InvestigationMachineProcessIdentity {
        ownership.helperIdentity
    }
    package var mode: InvestigationMachineOuterContainmentMode {
        completion == nil ? .parentCrash : .normal
    }
    package var bindingSHA256: InvestigationHandoffSHA256 {
        completion?.bindingSHA256 ?? ownership.bindingSHA256
    }

    package init(projecting result: InvestigationMachineSingleEpochResult) throws {
        switch result {
        case let .ownershipTransferred(candidate):
            guard candidate.scenario == .lifecycleRecovery else {
                throw InvestigationMachineSingleEpochPhysicalBridgeError
                    .invalidPhysicalResult
            }
            ownership = try Ownership(projecting: candidate)
            completion = nil
        case let .localCompletion(candidate):
            guard candidate.ownership.scenario != .lifecycleRecovery else {
                throw InvestigationMachineSingleEpochPhysicalBridgeError
                    .invalidPhysicalResult
            }
            ownership = try Ownership(projecting: candidate.ownership)
            completion = try Completion(projecting: candidate)
        }
    }

    private init(ownership: Ownership, completion: Completion?) {
        self.ownership = ownership
        self.completion = completion
    }

    package func encoded() throws -> Data {
        if let completion {
            return try HandoffBinaryTranscript.encode(
                domain: Self.completionDomain,
                businessFields: [
                    try ownership.encoded(),
                    completion.claimReleaseSHA256.rawBytes,
                    completion.driverObservationSHA256.rawBytes,
                    completion.bindingSHA256.rawBytes,
                ],
                maximumByteCount: Self.maximumCompletionByteCount
            )
        }
        return try ownership.encoded()
    }

    package static func decode(
        _ data: Data,
        expectedSelection: InvestigationMachineFixedEpochSelection
    ) throws -> Self {
        try bridgeValidateSelection(expectedSelection)
        if expectedSelection.epoch.scenario == .lifecycleRecovery {
            let ownership = try Ownership.decode(
                data, expectedSelection: expectedSelection
            )
            let value = Self(ownership: ownership, completion: nil)
            guard try value.encoded() == data else {
                throw InvestigationMachineSingleEpochPhysicalBridgeError
                    .invalidPhysicalResult
            }
            return value
        }
        let fields = try HandoffBinaryTranscript.decode(
            data, expectedDomain: completionDomain,
            expectedBusinessFieldByteCounts: [
                1...maximumOwnershipByteCount,
                32...32, 32...32, 32...32,
            ],
            maximumByteCount: maximumCompletionByteCount
        )
        let ownership = try Ownership.decode(
            fields[0], expectedSelection: expectedSelection
        )
        let claimRelease = try bridgeDigest(fields[1])
        let driverObservation = try bridgeDigest(fields[2])
        let binding = try bridgeDigest(fields[3])
        guard
            bridgeNonzero(claimRelease),
            bridgeNonzero(driverObservation),
            bridgeNonzero(binding),
            binding == InvestigationHandoffSHA256.hashing(
                try HandoffBinaryTranscript.encode(
                    domain: InvestigationMachineSingleEpochLocalCompletionCandidate
                        .domain,
                    businessFields: [
                        ownership.bindingSHA256.rawBytes,
                        claimRelease.rawBytes, driverObservation.rawBytes,
                        Data([0x01]),
                    ],
                    maximumByteCount:
                        InvestigationMachineSingleEpochLocalCompletionCandidate
                            .maximumByteCount
                )
            )
        else {
            throw InvestigationMachineSingleEpochPhysicalBridgeError
                .invalidPhysicalResult
        }
        let value = Self(
            ownership: ownership,
            completion: Completion(
                claimReleaseSHA256: claimRelease,
                driverObservationSHA256: driverObservation,
                bindingSHA256: binding
            )
        )
        guard try value.encoded() == data else {
            throw InvestigationMachineSingleEpochPhysicalBridgeError
                .invalidPhysicalResult
        }
        return value
    }

    package func isBound(
        to selection: InvestigationMachineFixedEpochSelection
    ) -> Bool {
        guard (try? bridgeValidateSelection(selection)) != nil else {
            return false
        }
        let expectedMode: InvestigationMachineOuterContainmentMode =
            selection.epoch.scenario == .lifecycleRecovery
                ? .parentCrash : .normal
        return mode == expectedMode && ownership.isBound(to: selection)
    }

    private struct Completion: Sendable, Equatable {
        let claimReleaseSHA256: InvestigationHandoffSHA256
        let driverObservationSHA256: InvestigationHandoffSHA256
        let bindingSHA256: InvestigationHandoffSHA256

        init(
            projecting candidate:
                InvestigationMachineSingleEpochLocalCompletionCandidate
        ) throws {
            guard
                bridgeNonzero(candidate.claimReleaseSHA256),
                bridgeNonzero(candidate.driverObservationSHA256),
                bridgeNonzero(candidate.bindingSHA256)
            else {
                throw InvestigationMachineSingleEpochPhysicalBridgeError
                    .invalidPhysicalResult
            }
            claimReleaseSHA256 = candidate.claimReleaseSHA256
            driverObservationSHA256 = candidate.driverObservationSHA256
            bindingSHA256 = candidate.bindingSHA256
        }

        init(
            claimReleaseSHA256: InvestigationHandoffSHA256,
            driverObservationSHA256: InvestigationHandoffSHA256,
            bindingSHA256: InvestigationHandoffSHA256
        ) {
            self.claimReleaseSHA256 = claimReleaseSHA256
            self.driverObservationSHA256 = driverObservationSHA256
            self.bindingSHA256 = bindingSHA256
        }
    }

    private struct Ownership: Sendable, Equatable {
        let outerAttemptUUID: UUID
        let wholeCapsuleSHA256: InvestigationHandoffSHA256
        let wholeInputSHA256: InvestigationHandoffSHA256
        let epochUUID: UUID
        let ordinal: UInt32
        let scenario: InvestigationHandoffScenario
        let projectionSHA256: InvestigationHandoffSHA256
        let appIdentity: InvestigationMachineProcessIdentity
        let helperIdentity: InvestigationMachineProcessIdentity
        let claimEvidenceSHA256: InvestigationHandoffSHA256
        let installedL2ProofSHA256: InvestigationHandoffSHA256
        let releaseDeadlineNanoseconds: UInt64
        let epochDeadlineNanoseconds: UInt64
        let bindingSHA256: InvestigationHandoffSHA256

        init(
            projecting candidate:
                InvestigationMachineSingleEpochOwnershipCandidate
        ) throws {
            guard
                bridgeUUIDIsNonzero(candidate.outerAttemptUUID),
                bridgeNonzero(candidate.wholeCapsuleSHA256),
                bridgeNonzero(candidate.wholeInputSHA256),
                bridgeUUIDIsNonzero(candidate.epochUUID),
                candidate.scenario.rawValue == candidate.ordinal + 1,
                bridgeNonzero(candidate.projectionSHA256),
                candidate.appIdentity.role == .app,
                candidate.helperIdentity.role == .helper,
                bridgeNonzero(candidate.claimEvidenceSHA256),
                bridgeNonzero(candidate.installedL2ProofSHA256),
                candidate.releaseDeadlineNanoseconds > 0,
                candidate.releaseDeadlineNanoseconds
                    <= candidate.epochDeadlineNanoseconds,
                bridgeNonzero(candidate.bindingSHA256)
            else {
                throw InvestigationMachineSingleEpochPhysicalBridgeError
                    .invalidPhysicalResult
            }
            outerAttemptUUID = candidate.outerAttemptUUID
            wholeCapsuleSHA256 = candidate.wholeCapsuleSHA256
            wholeInputSHA256 = candidate.wholeInputSHA256
            epochUUID = candidate.epochUUID
            ordinal = candidate.ordinal
            scenario = candidate.scenario
            projectionSHA256 = candidate.projectionSHA256
            appIdentity = candidate.appIdentity
            helperIdentity = candidate.helperIdentity
            claimEvidenceSHA256 = candidate.claimEvidenceSHA256
            installedL2ProofSHA256 = candidate.installedL2ProofSHA256
            releaseDeadlineNanoseconds = candidate.releaseDeadlineNanoseconds
            epochDeadlineNanoseconds = candidate.epochDeadlineNanoseconds
            bindingSHA256 = candidate.bindingSHA256
        }

        func encoded() throws -> Data {
            try HandoffBinaryTranscript.encode(
                domain: InvestigationMachineSingleEpochPhysicalResult
                    .ownershipDomain,
                businessFields: [
                    bridgeData(outerAttemptUUID),
                    wholeCapsuleSHA256.rawBytes, wholeInputSHA256.rawBytes,
                    bridgeData(epochUUID), bridgeData(ordinal),
                    bridgeData(scenario.rawValue), projectionSHA256.rawBytes,
                    try appIdentity.encoded(), try helperIdentity.encoded(),
                    claimEvidenceSHA256.rawBytes,
                    installedL2ProofSHA256.rawBytes,
                    bridgeData(releaseDeadlineNanoseconds),
                    bridgeData(epochDeadlineNanoseconds),
                    bindingSHA256.rawBytes,
                ],
                maximumByteCount: InvestigationMachineSingleEpochPhysicalResult
                    .maximumOwnershipByteCount
            )
        }

        static func decode(
            _ data: Data,
            expectedSelection: InvestigationMachineFixedEpochSelection
        ) throws -> Self {
            let fields = try HandoffBinaryTranscript.decode(
                data,
                expectedDomain: InvestigationMachineSingleEpochPhysicalResult
                    .ownershipDomain,
                expectedBusinessFieldByteCounts: [
                    16...16, 32...32, 32...32, 16...16, 4...4,
                    4...4, 32...32,
                    1...InvestigationMachineProcessIdentity.maximumByteCount,
                    1...InvestigationMachineProcessIdentity.maximumByteCount,
                    32...32, 32...32, 8...8, 8...8, 32...32,
                ],
                maximumByteCount: InvestigationMachineSingleEpochPhysicalResult
                    .maximumOwnershipByteCount
            )
            guard let scenario = InvestigationHandoffScenario(
                rawValue: try bridgeUInt32(fields[5])
            ) else {
                throw InvestigationMachineSingleEpochPhysicalBridgeError
                    .invalidPhysicalResult
            }
            let value = Self(
                outerAttemptUUID: try bridgeUUID(fields[0]),
                wholeCapsuleSHA256: try bridgeDigest(fields[1]),
                wholeInputSHA256: try bridgeDigest(fields[2]),
                epochUUID: try bridgeUUID(fields[3]),
                ordinal: try bridgeUInt32(fields[4]), scenario: scenario,
                projectionSHA256: try bridgeDigest(fields[6]),
                appIdentity: try InvestigationMachineProcessIdentity
                    .decode(fields[7]),
                helperIdentity: try InvestigationMachineProcessIdentity
                    .decode(fields[8]),
                claimEvidenceSHA256: try bridgeDigest(fields[9]),
                installedL2ProofSHA256: try bridgeDigest(fields[10]),
                releaseDeadlineNanoseconds: try bridgeUInt64(fields[11]),
                epochDeadlineNanoseconds: try bridgeUInt64(fields[12]),
                bindingSHA256: try bridgeDigest(fields[13])
            )
            guard
                try value.appIdentity.encoded() == fields[7],
                try value.helperIdentity.encoded() == fields[8],
                value.isBound(to: expectedSelection),
                try value.encoded() == data
            else {
                throw InvestigationMachineSingleEpochPhysicalBridgeError
                    .invalidPhysicalResult
            }
            return value
        }

        func isBound(
            to selection: InvestigationMachineFixedEpochSelection
        ) -> Bool {
            guard
                outerAttemptUUID == selection.outerAttemptUUID,
                wholeCapsuleSHA256 == selection.wholeCapsuleSHA256,
                wholeInputSHA256 == selection.wholeInputSHA256,
                epochUUID == selection.epoch.epochUUID,
                ordinal == selection.epoch.ordinal,
                scenario == selection.epoch.scenario,
                projectionSHA256 == selection.projection.projectionSHA256,
                appIdentity.role == .app, helperIdentity.role == .helper,
                bridgeNonzero(claimEvidenceSHA256),
                bridgeNonzero(installedL2ProofSHA256),
                releaseDeadlineNanoseconds > 0,
                releaseDeadlineNanoseconds <= epochDeadlineNanoseconds,
                bridgeNonzero(bindingSHA256)
            else { return false }
            let expected = try? InvestigationHandoffSHA256.hashing(
                HandoffBinaryTranscript.encode(
                    domain: InvestigationMachineSingleEpochOwnershipCandidate
                        .domain,
                    businessFields: [
                        bridgeData(outerAttemptUUID),
                        wholeCapsuleSHA256.rawBytes, wholeInputSHA256.rawBytes,
                        bridgeData(epochUUID), bridgeData(ordinal),
                        bridgeData(scenario.rawValue),
                        bridgeData(selection.epoch.configurationNonce),
                        selection.epoch.configurationSHA256.rawBytes,
                        selection.epoch.signedRuntimeBindingSHA256.rawBytes,
                        projectionSHA256.rawBytes,
                        appIdentity.encoded(), helperIdentity.encoded(),
                        claimEvidenceSHA256.rawBytes,
                        installedL2ProofSHA256.rawBytes,
                        bridgeData(releaseDeadlineNanoseconds),
                        bridgeData(epochDeadlineNanoseconds),
                    ],
                    maximumByteCount:
                        InvestigationMachineSingleEpochOwnershipCandidate
                            .maximumByteCount
                )
            )
            return expected == bindingSHA256
        }

        private init(
            outerAttemptUUID: UUID,
            wholeCapsuleSHA256: InvestigationHandoffSHA256,
            wholeInputSHA256: InvestigationHandoffSHA256,
            epochUUID: UUID, ordinal: UInt32,
            scenario: InvestigationHandoffScenario,
            projectionSHA256: InvestigationHandoffSHA256,
            appIdentity: InvestigationMachineProcessIdentity,
            helperIdentity: InvestigationMachineProcessIdentity,
            claimEvidenceSHA256: InvestigationHandoffSHA256,
            installedL2ProofSHA256: InvestigationHandoffSHA256,
            releaseDeadlineNanoseconds: UInt64,
            epochDeadlineNanoseconds: UInt64,
            bindingSHA256: InvestigationHandoffSHA256
        ) {
            self.outerAttemptUUID = outerAttemptUUID
            self.wholeCapsuleSHA256 = wholeCapsuleSHA256
            self.wholeInputSHA256 = wholeInputSHA256
            self.epochUUID = epochUUID
            self.ordinal = ordinal
            self.scenario = scenario
            self.projectionSHA256 = projectionSHA256
            self.appIdentity = appIdentity
            self.helperIdentity = helperIdentity
            self.claimEvidenceSHA256 = claimEvidenceSHA256
            self.installedL2ProofSHA256 = installedL2ProofSHA256
            self.releaseDeadlineNanoseconds = releaseDeadlineNanoseconds
            self.epochDeadlineNanoseconds = epochDeadlineNanoseconds
            self.bindingSHA256 = bindingSHA256
        }
    }
}

private func bridgeValidateSelection(
    _ selection: InvestigationMachineFixedEpochSelection
) throws {
    guard
        bridgeUUIDIsNonzero(selection.outerAttemptUUID),
        bridgeNonzero(selection.wholeCapsuleSHA256),
        bridgeNonzero(selection.wholeInputSHA256),
        selection.epoch.ordinal < UInt32(InvestigationCohortCapsule.epochCount),
        selection.epoch.scenario.rawValue == selection.epoch.ordinal + 1,
        selection.projection.epochUUID == selection.epoch.epochUUID,
        selection.projection.configurationNonce
            == selection.epoch.configurationNonce,
        selection.projection.configurationSHA256
            == selection.epoch.configurationSHA256,
        selection.projection.signedRuntimeBindingSHA256
            == selection.epoch.signedRuntimeBindingSHA256,
        bridgeNonzero(selection.projection.projectionSHA256)
    else {
        throw InvestigationMachineSingleEpochPhysicalBridgeError
            .invalidInvocation
    }
}

private func bridgeNonzero(_ value: InvestigationHandoffSHA256) -> Bool {
    value.rawBytes.contains(where: { $0 != 0 })
}

private func bridgeUUIDIsNonzero(_ value: UUID) -> Bool {
    bridgeData(value).contains(where: { $0 != 0 })
}

private func bridgeData(_ value: UInt32) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 24),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}

private func bridgeData(_ value: UInt64) -> Data {
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

private func bridgeData(_ value: UUID) -> Data {
    var bytes = value.uuid
    return withUnsafeBytes(of: &bytes) { Data($0) }
}

private func bridgeUInt32(_ data: Data) throws -> UInt32 {
    guard data.count == 4 else {
        throw InvestigationMachineSingleEpochPhysicalBridgeError
            .invalidPhysicalResult
    }
    return data.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
}

private func bridgeUInt64(_ data: Data) throws -> UInt64 {
    guard data.count == 8 else {
        throw InvestigationMachineSingleEpochPhysicalBridgeError
            .invalidPhysicalResult
    }
    return data.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
}

private func bridgeUUID(_ data: Data) throws -> UUID {
    guard data.count == 16 else {
        throw InvestigationMachineSingleEpochPhysicalBridgeError
            .invalidPhysicalResult
    }
    var bytes: uuid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    let copied = withUnsafeMutableBytes(of: &bytes) { target in
        data.copyBytes(to: target)
    }
    guard copied == 16 else {
        throw InvestigationMachineSingleEpochPhysicalBridgeError
            .invalidPhysicalResult
    }
    return UUID(uuid: bytes)
}

private func bridgeDigest(_ data: Data) throws -> InvestigationHandoffSHA256 {
    try InvestigationHandoffSHA256(rawBytes: data)
}
