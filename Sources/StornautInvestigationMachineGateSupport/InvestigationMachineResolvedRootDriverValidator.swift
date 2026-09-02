import Foundation
import StornautInvestigationHandoffContract

package enum InvestigationMachineResolvedRootDriverResolutionKind:
    Sendable, Equatable
{
    case execContinuity
    case containedSuccessor
}

package struct InvestigationMachineInitialSudoLaunchIdentity:
    Sendable, Equatable
{
    package let processID: UInt32
    package let parentProcessID: UInt32
    package let processGroupID: UInt32
    package let sessionID: UInt32
    package let startSeconds: Int64
    package let startMicroseconds: Int32

    package init(
        processID: UInt32, parentProcessID: UInt32,
        processGroupID: UInt32, sessionID: UInt32, startSeconds: Int64,
        startMicroseconds: Int32
    ) throws {
        guard
            processID > 1, parentProcessID > 0, processGroupID > 1,
            sessionID > 0, startSeconds > 0,
            (0...999_999).contains(startMicroseconds)
        else {
            throw InvestigationMachineResolvedRootDriverValidationError
                .invalidInput
        }
        self.processID = processID
        self.parentProcessID = parentProcessID
        self.processGroupID = processGroupID
        self.sessionID = sessionID
        self.startSeconds = startSeconds
        self.startMicroseconds = startMicroseconds
    }
}

package struct InvestigationMachineResolvedRootDriverLineageEdge:
    Sendable, Equatable
{
    package let parent: InvestigationGeneralProcessIdentityV1
    package let child: InvestigationGeneralProcessIdentityV1

    package init(
        parent: InvestigationGeneralProcessIdentityV1,
        child: InvestigationGeneralProcessIdentityV1
    ) {
        self.parent = parent
        self.child = child
    }
}

package struct InvestigationMachineResolvedRootDriverProcessSample:
    Sendable, Equatable
{
    package let identity: InvestigationGeneralProcessIdentityV1
    package let isStopped: Bool
    package let observedAtContinuousNanoseconds: UInt64

    package init(
        identity: InvestigationGeneralProcessIdentityV1, isStopped: Bool,
        observedAtContinuousNanoseconds: UInt64
    ) {
        self.identity = identity
        self.isStopped = isStopped
        self.observedAtContinuousNanoseconds = observedAtContinuousNanoseconds
    }
}

package struct InvestigationMachineResolvedRootDriverValidationInput:
    Sendable, Equatable
{
    package var claim: ResolvedRootDriverClaimV1
    package var expectedOuterAttemptUUID: UUID
    package var expectedWholeInputSHA256: InvestigationHandoffSHA256
    package var initialLaunch: InvestigationMachineInitialSudoLaunchIdentity
    package var recoveryProcessGroupID: UInt32
    package var coordinatorSessionID: UInt32
    package var lineageEdges: [InvestigationMachineResolvedRootDriverLineageEdge]
    package var firstProcessSample:
        InvestigationMachineResolvedRootDriverProcessSample
    package var secondProcessSample:
        InvestigationMachineResolvedRootDriverProcessSample
    package var fixedExecutableNode:
        InvestigationResolvedRootDriverNodeIdentityV1
    package var fixedExecutableSHA256: InvestigationHandoffSHA256
    package var fixedStaticSigning:
        InvestigationResolvedRootDriverSigningIdentityV1
    package var liveSigning: InvestigationResolvedRootDriverSigningIdentityV1
    package var liveSigningAuditTokenWords: [UInt32]
    package var projectedCohortInput: InvestigationProjectedCohortInput

    package init(
        claim: ResolvedRootDriverClaimV1, expectedOuterAttemptUUID: UUID,
        expectedWholeInputSHA256: InvestigationHandoffSHA256,
        initialLaunch: InvestigationMachineInitialSudoLaunchIdentity,
        recoveryProcessGroupID: UInt32, coordinatorSessionID: UInt32,
        lineageEdges: [InvestigationMachineResolvedRootDriverLineageEdge],
        firstProcessSample: InvestigationMachineResolvedRootDriverProcessSample,
        secondProcessSample: InvestigationMachineResolvedRootDriverProcessSample,
        fixedExecutableNode: InvestigationResolvedRootDriverNodeIdentityV1,
        fixedExecutableSHA256: InvestigationHandoffSHA256,
        fixedStaticSigning: InvestigationResolvedRootDriverSigningIdentityV1,
        liveSigning: InvestigationResolvedRootDriverSigningIdentityV1,
        liveSigningAuditTokenWords: [UInt32],
        projectedCohortInput: InvestigationProjectedCohortInput
    ) {
        self.claim = claim
        self.expectedOuterAttemptUUID = expectedOuterAttemptUUID
        self.expectedWholeInputSHA256 = expectedWholeInputSHA256
        self.initialLaunch = initialLaunch
        self.recoveryProcessGroupID = recoveryProcessGroupID
        self.coordinatorSessionID = coordinatorSessionID
        self.lineageEdges = lineageEdges
        self.firstProcessSample = firstProcessSample
        self.secondProcessSample = secondProcessSample
        self.fixedExecutableNode = fixedExecutableNode
        self.fixedExecutableSHA256 = fixedExecutableSHA256
        self.fixedStaticSigning = fixedStaticSigning
        self.liveSigning = liveSigning
        self.liveSigningAuditTokenWords = liveSigningAuditTokenWords
        self.projectedCohortInput = projectedCohortInput
    }
}

package struct InvestigationMachineResolvedRootDriverValidationResult:
    Sendable, Equatable
{
    package let resolutionKind:
        InvestigationMachineResolvedRootDriverResolutionKind
    package let resolvedProcess: InvestigationGeneralProcessIdentityV1
    package let lineage: [InvestigationGeneralProcessIdentityV1]
    package let claimSHA256: InvestigationHandoffSHA256
}

package enum InvestigationMachineResolvedRootDriverRetirementState:
    Sendable, Equatable
{
    case absent
    case present(InvestigationGeneralProcessIdentityV1)
}

package struct InvestigationMachineResolvedRootDriverRetirementObservation:
    Sendable, Equatable
{
    package let processID: UInt32
    package let state: InvestigationMachineResolvedRootDriverRetirementState

    package init(
        processID: UInt32,
        state: InvestigationMachineResolvedRootDriverRetirementState
    ) {
        self.processID = processID
        self.state = state
    }
}

package struct InvestigationMachineResolvedRootDriverRetirementEnumeration:
    Sendable, Equatable
{
    package let isComplete: Bool
    package let observations:
        [InvestigationMachineResolvedRootDriverRetirementObservation]

    package init(
        isComplete: Bool,
        observations: [InvestigationMachineResolvedRootDriverRetirementObservation]
    ) {
        self.isComplete = isComplete
        self.observations = observations
    }
}

package struct InvestigationMachineResolvedRootDriverRetirementResult:
    Sendable, Equatable
{
    package let reusedProcessIDs: [UInt32]
}

package enum InvestigationMachineResolvedRootDriverValidationError:
    Error, Sendable, Equatable
{
    case invalidInput
    case claimBindingMismatch
    case processIdentityMismatch
    case lineageUnproved
    case executableIdentityMismatch
    case installedProjectionMismatch
    case retirementUnproved
    case liveResidue
}

package enum InvestigationMachineResolvedRootDriverValidator {
    package static let maximumLineageNodeCount = 4

    package static func validate(
        _ input: InvestigationMachineResolvedRootDriverValidationInput
    ) throws -> InvestigationMachineResolvedRootDriverValidationResult {
        let claim = input.claim
        guard
            claim.outerAttemptUUID == input.expectedOuterAttemptUUID,
            claim.wholeInputSHA256 == input.expectedWholeInputSHA256,
            input.projectedCohortInput.capsule.outerAttemptUUID
                == input.expectedOuterAttemptUUID,
            input.projectedCohortInput.wholeInputSHA256
                == input.expectedWholeInputSHA256
        else { throw Error.claimBindingMismatch }
        guard
            input.recoveryProcessGroupID > 1,
            input.coordinatorSessionID > 0,
            input.initialLaunch.processGroupID == input.recoveryProcessGroupID,
            input.initialLaunch.sessionID == input.coordinatorSessionID
        else { throw Error.processIdentityMismatch }

        let lineage = try resolveLineage(input)
        guard
            let resolved = lineage.last, resolved == claim.process,
            input.firstProcessSample.identity == resolved,
            input.secondProcessSample.identity == resolved,
            input.firstProcessSample.isStopped, input.secondProcessSample.isStopped,
            input.firstProcessSample.observedAtContinuousNanoseconds
                <= claim.observedAtContinuousNanoseconds,
            claim.observedAtContinuousNanoseconds
                <= input.secondProcessSample.observedAtContinuousNanoseconds,
            input.firstProcessSample.observedAtContinuousNanoseconds
                < input.secondProcessSample.observedAtContinuousNanoseconds,
            resolved.processGroupID == input.recoveryProcessGroupID,
            resolved.sessionID == input.coordinatorSessionID,
            resolved.auditTokenWords == input.liveSigningAuditTokenWords
        else { throw Error.processIdentityMismatch }

        try validateExecutable(input)
        let kind: InvestigationMachineResolvedRootDriverResolutionKind =
            lineage.count == 1 ? .execContinuity : .containedSuccessor
        return .init(
            resolutionKind: kind, resolvedProcess: resolved, lineage: lineage,
            claimSHA256: claim.selfSHA256
        )
    }

    package static func verifyRetirement(
        _ result: InvestigationMachineResolvedRootDriverValidationResult,
        enumeration: InvestigationMachineResolvedRootDriverRetirementEnumeration
    ) throws -> InvestigationMachineResolvedRootDriverRetirementResult {
        guard enumeration.isComplete else { throw Error.retirementUnproved }
        let expected = Dictionary(
            uniqueKeysWithValues: result.lineage.map { ($0.processID, $0) }
        )
        guard
            enumeration.observations.count == expected.count,
            Set(enumeration.observations.map(\.processID)) == Set(expected.keys)
        else { throw Error.retirementUnproved }

        var reused: [UInt32] = []
        for observation in enumeration.observations {
            guard let original = expected[observation.processID] else {
                throw Error.retirementUnproved
            }
            switch observation.state {
            case .absent:
                break
            case let .present(current):
                guard
                    current.processID == observation.processID,
                    !sameInstance(current, original)
                else {
                    throw Error.liveResidue
                }
                guard
                    current.processGroupID != original.processGroupID,
                    current.sessionID != original.sessionID
                else { throw Error.liveResidue }
                reused.append(current.processID)
            }
        }
        return .init(reusedProcessIDs: reused.sorted())
    }

    private static func resolveLineage(
        _ input: InvestigationMachineResolvedRootDriverValidationInput
    ) throws -> [InvestigationGeneralProcessIdentityV1] {
        if input.lineageEdges.isEmpty {
            let resolved = input.claim.process
            guard
                resolved.processID == input.initialLaunch.processID,
                resolved.startSeconds == input.initialLaunch.startSeconds,
                resolved.startMicroseconds == input.initialLaunch.startMicroseconds,
                resolved.parentProcessID == input.initialLaunch.parentProcessID
            else { throw Error.lineageUnproved }
            return [resolved]
        }
        guard
            input.lineageEdges.count < maximumLineageNodeCount,
            let first = input.lineageEdges.first?.parent,
            first.processID == input.initialLaunch.processID,
            first.startSeconds == input.initialLaunch.startSeconds,
            first.startMicroseconds == input.initialLaunch.startMicroseconds,
            first.parentProcessID == input.initialLaunch.parentProcessID
        else { throw Error.lineageUnproved }

        var lineage = [first]
        for edge in input.lineageEdges {
            guard
                lineage.last == edge.parent,
                edge.child.parentProcessID == edge.parent.processID,
                edge.parent.processGroupID == input.recoveryProcessGroupID,
                edge.child.processGroupID == input.recoveryProcessGroupID,
                edge.parent.sessionID == input.coordinatorSessionID,
                edge.child.sessionID == input.coordinatorSessionID
            else { throw Error.lineageUnproved }
            lineage.append(edge.child)
        }
        let keys = lineage.map(identityKey)
        guard
            lineage.count <= maximumLineageNodeCount,
            Set(keys).count == keys.count,
            Set(lineage.map(\.processID)).count == lineage.count,
            lineage.allSatisfy({
                $0.auditSessionID == input.claim.process.auditSessionID
            }),
            lineage.last == input.claim.process
        else { throw Error.lineageUnproved }
        return lineage
    }

    private static func validateExecutable(
        _ input: InvestigationMachineResolvedRootDriverValidationInput
    ) throws {
        let executable = input.claim.executable
        guard
            executable.path == ResolvedRootDriverClaimV1.fixedExecutablePath,
            executable.node == input.fixedExecutableNode,
            executable.sha256 == input.fixedExecutableSHA256,
            executable.staticSigning == input.fixedStaticSigning,
            executable.liveSigning == input.liveSigning,
            input.fixedStaticSigning == input.liveSigning
        else { throw Error.executableIdentityMismatch }
        guard
            input.projectedCohortInput.projections.count
                == InvestigationProjectedCohortInput.projectionCount,
            input.projectedCohortInput.projections.allSatisfy({ projection in
                projection.machineDriverExecutableSHA256 == executable.sha256
                    && projection.machineDriverSigningIdentifier
                        == executable.staticSigning.signingIdentifier
                    && projection.machineDriverDesignatedRequirementSHA256
                        == executable.staticSigning.designatedRequirementSHA256
                    && projection.machineDriverCodeDirectoryHash
                        == executable.staticSigning.codeDirectoryHash
            })
        else { throw Error.installedProjectionMismatch }
    }

    private static func sameInstance(
        _ lhs: InvestigationGeneralProcessIdentityV1,
        _ rhs: InvestigationGeneralProcessIdentityV1
    ) -> Bool {
        lhs.processID == rhs.processID
            && lhs.processIDVersion == rhs.processIDVersion
            && lhs.startSeconds == rhs.startSeconds
            && lhs.startMicroseconds == rhs.startMicroseconds
    }

    private static func identityKey(
        _ value: InvestigationGeneralProcessIdentityV1
    ) -> String {
        "\(value.processID):\(value.processIDVersion):"
            + "\(value.startSeconds):\(value.startMicroseconds)"
    }

    private typealias Error =
        InvestigationMachineResolvedRootDriverValidationError
}
