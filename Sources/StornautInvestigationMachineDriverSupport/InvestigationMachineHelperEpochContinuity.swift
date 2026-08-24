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
        if case let .admittedPhysical(admitted) = result {
            guard admitted.isBound(
                to: selection, predecessor: predecessor
            ) else {
                throw InvestigationMachineHelperEpochContinuityError
                    .invalidCompletion
            }
        }
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
    let continuityTranscript: Data
    private let outerAttemptUUID: UUID
    private let wholeCapsuleSHA256: InvestigationHandoffSHA256
    private let wholeInputSHA256: InvestigationHandoffSHA256
    private let ordinal: UInt32
    private let epochUUID: UUID
    private let selection: InvestigationMachineFixedEpochSelection
    private let lock = NSLock()
    private var consumed = false
    private var invocationIssued = false

    fileprivate init(
        previousHelperIdentity: InvestigationMachineProcessIdentity?,
        continuitySHA256: InvestigationHandoffSHA256,
        continuityTranscript: Data,
        selection: InvestigationMachineFixedEpochSelection
    ) {
        self.previousHelperIdentity = previousHelperIdentity
        self.continuitySHA256 = continuitySHA256
        self.continuityTranscript = continuityTranscript
        outerAttemptUUID = selection.outerAttemptUUID
        wholeCapsuleSHA256 = selection.wholeCapsuleSHA256
        wholeInputSHA256 = selection.wholeInputSHA256
        ordinal = selection.epoch.ordinal
        epochUUID = selection.epoch.epochUUID
        self.selection = selection
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

    package func invocation(
        for selection: InvestigationMachineFixedEpochSelection
    ) throws -> InvestigationMachineSingleEpochInvocation {
        try lock.withLock {
            guard !invocationIssued else {
                throw InvestigationMachineHelperEpochContinuityError
                    .alreadyConsumed
            }
            guard self.selection == selection else {
                throw InvestigationMachineHelperEpochContinuityError
                    .invalidPredecessor
            }
            invocationIssued = true
            return try InvestigationMachineSingleEpochInvocation(
                selection: selection,
                previousHelperIdentity: previousHelperIdentity,
                predecessorSHA256: continuitySHA256,
                predecessorTranscript: continuityTranscript
            )
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
    private let completedSelection: InvestigationMachineFixedEpochSelection?
    private let continuitySHA256: InvestigationHandoffSHA256
    private let continuityTranscript: Data
    private let lock = NSLock()
    private var consumed = false

    private init(
        outerAttemptUUID: UUID,
        wholeCapsuleSHA256: InvestigationHandoffSHA256,
        wholeInputSHA256: InvestigationHandoffSHA256,
        kind: Kind,
        completedSelection: InvestigationMachineFixedEpochSelection?,
        continuitySHA256: InvestigationHandoffSHA256,
        continuityTranscript: Data
    ) {
        self.outerAttemptUUID = outerAttemptUUID
        self.wholeCapsuleSHA256 = wholeCapsuleSHA256
        self.wholeInputSHA256 = wholeInputSHA256
        self.kind = kind
        self.completedSelection = completedSelection
        self.continuitySHA256 = continuitySHA256
        self.continuityTranscript = continuityTranscript
    }

    package static func genesis(
        for selection: InvestigationMachineFixedEpochSelection
    ) throws -> InvestigationMachineHelperEpochContinuity {
        guard selection.epoch.ordinal == 0 else {
            throw InvestigationMachineHelperEpochContinuityError
                .invalidPredecessor
        }
        let continuityTranscript = try HandoffBinaryTranscript.encode(
            domain: "stornaut.task39.machine.helper-continuity.genesis",
            businessFields: [
                continuityData(selection.outerAttemptUUID),
                selection.wholeCapsuleSHA256.rawBytes,
                selection.wholeInputSHA256.rawBytes,
                continuityData(selection.epoch.ordinal),
                continuityData(selection.epoch.epochUUID),
            ],
            maximumByteCount: 512
        )
        let continuitySHA256 = InvestigationHandoffSHA256.hashing(
            continuityTranscript
        )
        return Self(
            outerAttemptUUID: selection.outerAttemptUUID,
            wholeCapsuleSHA256: selection.wholeCapsuleSHA256,
            wholeInputSHA256: selection.wholeInputSHA256,
            kind: .genesis, completedSelection: nil,
            continuitySHA256: continuitySHA256,
            continuityTranscript: continuityTranscript
        )
    }

    fileprivate static func successor(
        selection: InvestigationMachineFixedEpochSelection,
        helperIdentity: InvestigationMachineProcessIdentity,
        proof: InvestigationMachineOuterContainmentProof,
        predecessor: InvestigationMachineHelperEpochPredecessor
    ) throws -> InvestigationMachineHelperEpochContinuity {
        let continuityTranscript = try successorTranscript(
            selection: selection, helperIdentity: helperIdentity,
            predecessorSHA256: predecessor.continuitySHA256, proof: proof
        )
        let continuitySHA256 = InvestigationHandoffSHA256.hashing(
            continuityTranscript
        )
        return Self(
            outerAttemptUUID: selection.outerAttemptUUID,
            wholeCapsuleSHA256: selection.wholeCapsuleSHA256,
            wholeInputSHA256: selection.wholeInputSHA256,
            kind: .successor(
                completedOrdinal: selection.epoch.ordinal,
                helperIdentity: helperIdentity, proof: proof
            ),
            completedSelection: selection,
            continuitySHA256: continuitySHA256,
            continuityTranscript: continuityTranscript
        )
    }

    package func destroyAfterFinal(
        selection: InvestigationMachineFixedEpochSelection
    ) throws {
        try lock.withLock {
            guard !consumed else {
                throw InvestigationMachineHelperEpochContinuityError.alreadyConsumed
            }
            consumed = true
            guard
                completedSelection == selection,
                selection.outerAttemptUUID == outerAttemptUUID,
                selection.wholeCapsuleSHA256 == wholeCapsuleSHA256,
                selection.wholeInputSHA256 == wholeInputSHA256,
                Int(selection.epoch.ordinal)
                    == InvestigationCohortCapsule.epochCount - 1,
                selection.epoch.scenario.rawValue
                    == selection.epoch.ordinal + 1,
                selection.projection.epochUUID == selection.epoch.epochUUID,
                selection.projection.configurationNonce
                    == selection.epoch.configurationNonce,
                selection.projection.configurationSHA256
                    == selection.epoch.configurationSHA256,
                selection.projection.signedRuntimeBindingSHA256
                    == selection.epoch.signedRuntimeBindingSHA256,
                selection.projection.projectionSHA256.rawBytes.contains(
                    where: { $0 != 0 }
                )
            else {
                throw InvestigationMachineHelperEpochContinuityError
                    .invalidCompletion
            }
            guard case let .successor(completedOrdinal, helperIdentity, proof) = kind else {
                throw InvestigationMachineHelperEpochContinuityError
                    .invalidCompletion
            }
            let expectedMode: InvestigationMachineOuterContainmentMode =
                switch selection.epoch.scenario {
                case .lifecycleRecovery: .parentCrash
                case .success, .cancellation, .timeout, .invalidEnvelope,
                     .identityMismatch, .transportLoss,
                     .artifactCleanupFailure: .normal
                }
            guard
                Int(completedOrdinal)
                    == InvestigationCohortCapsule.epochCount - 1,
                proof.completedOrdinal == completedOrdinal,
                proof.outerAttemptUUID == outerAttemptUUID,
                proof.wholeCapsuleSHA256 == wholeCapsuleSHA256,
                proof.wholeInputSHA256 == wholeInputSHA256,
                proof.epochUUID == selection.epoch.epochUUID,
                proof.helperIdentity == helperIdentity,
                proof.predecessorSHA256.rawBytes.contains(
                    where: { $0 != 0 }
                ),
                proof.completionBindingSHA256.rawBytes.contains(
                    where: { $0 != 0 }
                ),
                proof.terminalProofSHA256.rawBytes.contains(
                    where: { $0 != 0 }
                ),
                proof.mode == expectedMode,
                continuitySHA256 == (try Self.successorSHA256(
                    selection: selection, helperIdentity: helperIdentity,
                    predecessorSHA256: proof.predecessorSHA256, proof: proof
                ))
            else {
                throw InvestigationMachineHelperEpochContinuityError
                    .invalidCompletion
            }
        }
    }

    private static func successorSHA256(
        selection: InvestigationMachineFixedEpochSelection,
        helperIdentity: InvestigationMachineProcessIdentity,
        predecessorSHA256: InvestigationHandoffSHA256,
        proof: InvestigationMachineOuterContainmentProof
    ) throws -> InvestigationHandoffSHA256 {
        InvestigationHandoffSHA256.hashing(try successorTranscript(
            selection: selection, helperIdentity: helperIdentity,
            predecessorSHA256: predecessorSHA256, proof: proof
        ))
    }

    private static func successorTranscript(
        selection: InvestigationMachineFixedEpochSelection,
        helperIdentity: InvestigationMachineProcessIdentity,
        predecessorSHA256: InvestigationHandoffSHA256,
        proof: InvestigationMachineOuterContainmentProof
    ) throws -> Data {
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
                    predecessorSHA256.rawBytes,
                    proof.completionBindingSHA256.rawBytes,
                    proof.terminalProofSHA256.rawBytes,
                    Data([proof.mode.rawValue]),
                ],
                maximumByteCount: 4_096
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
                    continuityTranscript: continuityTranscript,
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
                    continuityTranscript: continuityTranscript,
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
        case let .admittedPhysical(admitted):
            let expectedMode: InvestigationMachineOuterContainmentMode =
                selection.epoch.scenario == .lifecycleRecovery
                    ? .parentCrash : .normal
            guard
                admitted.mode == expectedMode,
                admitted.isBound(to: selection)
            else {
                throw InvestigationMachineHelperEpochContinuityError
                    .invalidCompletion
            }
            helperIdentity = admitted.helperIdentity
            bindingSHA256 = admitted.bindingSHA256
            mode = admitted.mode
            return
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
