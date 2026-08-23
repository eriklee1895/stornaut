import Foundation
import StornautInvestigationHandoffContract
package enum InvestigationMachineHelperEpochContinuityError:
    Error,
    Sendable,
    Equatable
{
    case alreadyConsumed
    case invalidPredecessor
    case invalidCompletion
    case containmentUncertain
    case cancelled
}
package enum InvestigationMachineOuterContainmentMode:
    UInt8,
    Sendable,
    Equatable
{
    case normal = 0x01
    case parentCrash = 0x02
}

package struct InvestigationMachineOuterContainmentProof:
    Sendable,
    Equatable
{
    fileprivate let outerAttemptUUID: UUID
    fileprivate let wholeCapsuleSHA256: InvestigationHandoffSHA256
    fileprivate let wholeInputSHA256: InvestigationHandoffSHA256
    fileprivate let predecessorSHA256: InvestigationHandoffSHA256
    fileprivate let completedOrdinal: UInt32
    fileprivate let epochUUID: UUID
    fileprivate let helperIdentity: InvestigationMachineProcessIdentity
    fileprivate let completionBindingSHA256: InvestigationHandoffSHA256
    fileprivate let terminalProofSHA256: InvestigationHandoffSHA256
    fileprivate let mode: InvestigationMachineOuterContainmentMode

    init(
        selection: InvestigationMachineFixedEpochSelection,
        result: InvestigationMachineSingleEpochResult,
        predecessor: InvestigationMachineHelperEpochPredecessor,
        terminalProofSHA256: InvestigationHandoffSHA256
    ) throws {
        guard terminalProofSHA256.rawBytes.contains(where: { $0 != 0 }) else {
            throw InvestigationMachineHelperEpochContinuityError
                .invalidCompletion
        }
        let material = try InvestigationMachineCompletionMaterial(
            selection: selection, result: result
        )
        outerAttemptUUID = selection.outerAttemptUUID
        wholeCapsuleSHA256 = selection.wholeCapsuleSHA256
        wholeInputSHA256 = selection.wholeInputSHA256
        predecessorSHA256 = predecessor.continuitySHA256
        completedOrdinal = selection.epoch.ordinal
        epochUUID = selection.epoch.epochUUID
        helperIdentity = material.helperIdentity
        completionBindingSHA256 = material.bindingSHA256
        self.terminalProofSHA256 = terminalProofSHA256
        mode = material.mode
    }
}

package enum InvestigationMachineOuterContainmentOutcome:
    Sendable,
    Equatable
{
    case contained(InvestigationMachineOuterContainmentProof)
    case terminalUncertain
}

package protocol InvestigationMachineOuterContainmentProving: Sendable {
    func proveContainment(
        selection: InvestigationMachineFixedEpochSelection,
        result: InvestigationMachineSingleEpochResult,
        predecessor: InvestigationMachineHelperEpochPredecessor
    ) async -> InvestigationMachineOuterContainmentOutcome
}

package final class InvestigationMachineHelperEpochPredecessor:
    @unchecked Sendable
{
    let previousHelperIdentity: InvestigationMachineProcessIdentity?
    let continuitySHA256: InvestigationHandoffSHA256
    private let outerAttemptUUID: UUID
    private let wholeCapsuleSHA256: InvestigationHandoffSHA256
    private let wholeInputSHA256: InvestigationHandoffSHA256
    private let ordinal: UInt32
    private let epochUUID: UUID
    private let lock = NSLock()
    private var consumed = false

    fileprivate init(
        previousHelperIdentity: InvestigationMachineProcessIdentity?,
        continuitySHA256: InvestigationHandoffSHA256,
        selection: InvestigationMachineFixedEpochSelection
    ) {
        self.previousHelperIdentity = previousHelperIdentity
        self.continuitySHA256 = continuitySHA256
        outerAttemptUUID = selection.outerAttemptUUID
        wholeCapsuleSHA256 = selection.wholeCapsuleSHA256
        wholeInputSHA256 = selection.wholeInputSHA256
        ordinal = selection.epoch.ordinal
        epochUUID = selection.epoch.epochUUID
    }

    fileprivate func consume(
        _ selection: InvestigationMachineFixedEpochSelection
    ) throws {
        try lock.withLock {
            guard !consumed else {
                throw InvestigationMachineHelperEpochContinuityError
                    .alreadyConsumed
            }
            consumed = true
            guard
                outerAttemptUUID == selection.outerAttemptUUID,
                wholeCapsuleSHA256 == selection.wholeCapsuleSHA256,
                wholeInputSHA256 == selection.wholeInputSHA256,
                ordinal == selection.epoch.ordinal,
                epochUUID == selection.epoch.epochUUID,
                (ordinal == 0) == (previousHelperIdentity == nil)
            else {
                throw InvestigationMachineHelperEpochContinuityError
                    .invalidPredecessor
            }
        }
    }
}

package final class InvestigationMachineHelperEpochContinuity:
    @unchecked Sendable
{
    private enum Kind {
        case genesis
        case successor(
            completedOrdinal: UInt32,
            helperIdentity: InvestigationMachineProcessIdentity,
            proof: InvestigationMachineOuterContainmentProof
        )
    }

    private let outerAttemptUUID: UUID
    private let wholeCapsuleSHA256: InvestigationHandoffSHA256
    private let wholeInputSHA256: InvestigationHandoffSHA256
    private let kind: Kind
    private let continuitySHA256: InvestigationHandoffSHA256
    private let lock = NSLock()
    private var consumed = false

    private init(
        outerAttemptUUID: UUID,
        wholeCapsuleSHA256: InvestigationHandoffSHA256,
        wholeInputSHA256: InvestigationHandoffSHA256,
        kind: Kind,
        continuitySHA256: InvestigationHandoffSHA256
    ) {
        self.outerAttemptUUID = outerAttemptUUID
        self.wholeCapsuleSHA256 = wholeCapsuleSHA256
        self.wholeInputSHA256 = wholeInputSHA256
        self.kind = kind
        self.continuitySHA256 = continuitySHA256
    }

    package static func genesis(
        for selection: InvestigationMachineFixedEpochSelection
    ) throws -> InvestigationMachineHelperEpochContinuity {
        guard selection.epoch.ordinal == 0 else {
            throw InvestigationMachineHelperEpochContinuityError
                .invalidPredecessor
        }
        let continuitySHA256 = InvestigationHandoffSHA256.hashing(
            try HandoffBinaryTranscript.encode(
                domain:
                    "stornaut.task39.machine.helper-continuity.genesis",
                businessFields: [
                    continuityData(selection.outerAttemptUUID),
                    selection.wholeCapsuleSHA256.rawBytes,
                    selection.wholeInputSHA256.rawBytes,
                    continuityData(selection.epoch.ordinal),
                    continuityData(selection.epoch.epochUUID),
                ],
                maximumByteCount: 512
            )
        )
        return Self(
            outerAttemptUUID: selection.outerAttemptUUID,
            wholeCapsuleSHA256: selection.wholeCapsuleSHA256,
            wholeInputSHA256: selection.wholeInputSHA256,
            kind: .genesis, continuitySHA256: continuitySHA256
        )
    }

    fileprivate static func successor(
        selection: InvestigationMachineFixedEpochSelection,
        helperIdentity: InvestigationMachineProcessIdentity,
        proof: InvestigationMachineOuterContainmentProof,
        predecessor: InvestigationMachineHelperEpochPredecessor
    ) throws -> InvestigationMachineHelperEpochContinuity {
        let continuitySHA256 = InvestigationHandoffSHA256.hashing(
            try HandoffBinaryTranscript.encode(
                domain:
                    "stornaut.task39.machine.helper-continuity.successor",
                businessFields: [
                    continuityData(selection.outerAttemptUUID),
                    selection.wholeCapsuleSHA256.rawBytes,
                    selection.wholeInputSHA256.rawBytes,
                    continuityData(selection.epoch.ordinal),
                    continuityData(selection.epoch.epochUUID),
                    try helperIdentity.encoded(),
                    predecessor.continuitySHA256.rawBytes,
                    proof.completionBindingSHA256.rawBytes,
                    proof.terminalProofSHA256.rawBytes,
                    Data([proof.mode.rawValue]),
                ],
                maximumByteCount: 4_096
            )
        )
        return Self(
            outerAttemptUUID: selection.outerAttemptUUID,
            wholeCapsuleSHA256: selection.wholeCapsuleSHA256,
            wholeInputSHA256: selection.wholeInputSHA256,
            kind: .successor(
                completedOrdinal: selection.epoch.ordinal,
                helperIdentity: helperIdentity, proof: proof
            ),
            continuitySHA256: continuitySHA256
        )
    }

    func consume(
        for selection: InvestigationMachineFixedEpochSelection
    ) throws -> InvestigationMachineHelperEpochPredecessor {
        try lock.withLock {
            guard !consumed else {
                throw InvestigationMachineHelperEpochContinuityError
                    .alreadyConsumed
            }
            consumed = true
            guard
                selection.outerAttemptUUID == outerAttemptUUID,
                selection.wholeCapsuleSHA256 == wholeCapsuleSHA256,
                selection.wholeInputSHA256 == wholeInputSHA256
            else {
                throw InvestigationMachineHelperEpochContinuityError
                    .invalidPredecessor
            }
            switch kind {
            case .genesis:
                guard selection.epoch.ordinal == 0 else {
                    throw InvestigationMachineHelperEpochContinuityError
                        .invalidPredecessor
                }
                return .init(
                    previousHelperIdentity: nil,
                    continuitySHA256: continuitySHA256,
                    selection: selection
                )
            case let .successor(completedOrdinal, helperIdentity, proof):
                let next = completedOrdinal.addingReportingOverflow(1)
                guard
                    !next.overflow,
                    next.partialValue == selection.epoch.ordinal,
                    proof.completedOrdinal == completedOrdinal,
                    proof.epochUUID != selection.epoch.epochUUID,
                    proof.helperIdentity == helperIdentity,
                    proof.outerAttemptUUID == outerAttemptUUID,
                    proof.wholeCapsuleSHA256 == wholeCapsuleSHA256,
                    proof.wholeInputSHA256 == wholeInputSHA256,
                    proof.terminalProofSHA256.rawBytes.contains(
                        where: { $0 != 0 }
                    )
                else {
                    throw InvestigationMachineHelperEpochContinuityError
                        .invalidPredecessor
                }
                return .init(
                    previousHelperIdentity: helperIdentity,
                    continuitySHA256: continuitySHA256,
                    selection: selection
                )
            }
        }
    }
}

package actor InvestigationMachineOuterCompletionJoin {
    private let prover: any InvestigationMachineOuterContainmentProving
    private var consumed = false

    package init(
        prover: any InvestigationMachineOuterContainmentProving
    ) {
        self.prover = prover
    }

    package func seal(
        selection: InvestigationMachineFixedEpochSelection,
        result: InvestigationMachineSingleEpochResult,
        predecessor: InvestigationMachineHelperEpochPredecessor
    ) async throws -> InvestigationMachineHelperEpochContinuity {
        guard !consumed else {
            throw InvestigationMachineHelperEpochContinuityError
                .alreadyConsumed
        }
        consumed = true
        try predecessor.consume(selection)
        let material = try InvestigationMachineCompletionMaterial(
            selection: selection, result: result
        )
        let prover = prover
        let outcome = await Task.detached {
            await prover.proveContainment(
                selection: selection, result: result,
                predecessor: predecessor
            )
        }.value
        guard case let .contained(proof) = outcome else {
            throw InvestigationMachineHelperEpochContinuityError
                .containmentUncertain
        }
        let expected = try InvestigationMachineOuterContainmentProof(
            selection: selection, result: result,
            predecessor: predecessor,
            terminalProofSHA256: proof.terminalProofSHA256
        )
        guard proof == expected else {
            throw InvestigationMachineHelperEpochContinuityError
                .invalidCompletion
        }
        guard !Task.isCancelled else {
            throw InvestigationMachineHelperEpochContinuityError.cancelled
        }
        return try InvestigationMachineHelperEpochContinuity.successor(
            selection: selection, helperIdentity: material.helperIdentity,
            proof: proof, predecessor: predecessor
        )
    }
}

private func continuityData(_ value: UInt32) -> Data {
    Data([
        UInt8(truncatingIfNeeded: value >> 24),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
    ])
}

private func continuityData(_ value: UUID) -> Data {
    var bytes = value.uuid
    return withUnsafeBytes(of: &bytes) { Data($0) }
}

private struct InvestigationMachineCompletionMaterial {
    let helperIdentity: InvestigationMachineProcessIdentity
    let bindingSHA256: InvestigationHandoffSHA256
    let mode: InvestigationMachineOuterContainmentMode

    init(
        selection: InvestigationMachineFixedEpochSelection,
        result: InvestigationMachineSingleEpochResult
    ) throws {
        let ownership: InvestigationMachineSingleEpochOwnershipCandidate
        switch result {
        case let .localCompletion(completion):
            guard selection.epoch.scenario != .lifecycleRecovery else {
                throw InvestigationMachineHelperEpochContinuityError
                    .invalidCompletion
            }
            ownership = completion.ownership
            helperIdentity = completion.helperIdentity
            bindingSHA256 = completion.bindingSHA256
            mode = .normal
        case let .ownershipTransferred(candidate):
            guard selection.epoch.scenario == .lifecycleRecovery else {
                throw InvestigationMachineHelperEpochContinuityError
                    .invalidCompletion
            }
            ownership = candidate
            helperIdentity = candidate.helperIdentity
            bindingSHA256 = candidate.bindingSHA256
            mode = .parentCrash
        }
        guard
            ownership.outerAttemptUUID == selection.outerAttemptUUID,
            ownership.wholeCapsuleSHA256
                == selection.wholeCapsuleSHA256,
            ownership.wholeInputSHA256 == selection.wholeInputSHA256,
            ownership.epochUUID == selection.epoch.epochUUID,
            ownership.ordinal == selection.epoch.ordinal,
            ownership.scenario == selection.epoch.scenario,
            ownership.projectionSHA256
                == selection.projection.projectionSHA256,
            ownership.helperIdentity == helperIdentity
        else {
            throw InvestigationMachineHelperEpochContinuityError
                .invalidCompletion
        }
    }
}
