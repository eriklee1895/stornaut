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

/// Identity fields the unprivileged Gate can independently observe through
/// public Darwin process APIs. The driver claim's pidversion and audit-token
/// words deliberately do not appear here: those remain sealed, self-reported
/// compatibility fields in the fixed 1,006-byte claim.
package struct InvestigationMachineGateObservedProcessIdentity:
    Sendable, Equatable
{
    package let processID: UInt32
    package let startSeconds: Int64
    package let startMicroseconds: Int32
    package let parentProcessID: UInt32
    package let processGroupID: UInt32
    package let sessionID: UInt32
    package let auditUserID: UInt32
    package let auditSessionID: UInt32
    package let realUserID: UInt32
    package let effectiveUserID: UInt32
    package let savedUserID: UInt32
    package let realGroupID: UInt32
    package let effectiveGroupID: UInt32
    package let savedGroupID: UInt32
    package let supplementaryGroups: [UInt32]

    package init(
        processID: UInt32, startSeconds: Int64, startMicroseconds: Int32,
        parentProcessID: UInt32, processGroupID: UInt32, sessionID: UInt32,
        auditUserID: UInt32, auditSessionID: UInt32, realUserID: UInt32,
        effectiveUserID: UInt32,
        savedUserID: UInt32, realGroupID: UInt32, effectiveGroupID: UInt32,
        savedGroupID: UInt32, supplementaryGroups: [UInt32]
    ) throws {
        guard
            processID > 1, startSeconds > 0,
            (0...999_999).contains(startMicroseconds), parentProcessID > 0,
            processGroupID > 1, sessionID > 0, auditSessionID > 0,
            (1...InvestigationGeneralProcessIdentityV1.supplementaryGroupCapacity)
                .contains(supplementaryGroups.count),
            supplementaryGroups == supplementaryGroups.sorted(),
            Set(supplementaryGroups).count == supplementaryGroups.count,
            supplementaryGroups.contains(effectiveGroupID)
        else {
            throw InvestigationMachineResolvedRootDriverValidationError
                .invalidInput
        }
        self.processID = processID
        self.startSeconds = startSeconds
        self.startMicroseconds = startMicroseconds
        self.parentProcessID = parentProcessID
        self.processGroupID = processGroupID
        self.sessionID = sessionID
        self.auditUserID = auditUserID
        self.auditSessionID = auditSessionID
        self.realUserID = realUserID
        self.effectiveUserID = effectiveUserID
        self.savedUserID = savedUserID
        self.realGroupID = realGroupID
        self.effectiveGroupID = effectiveGroupID
        self.savedGroupID = savedGroupID
        self.supplementaryGroups = supplementaryGroups
    }
}

package struct InvestigationMachineResolvedRootDriverLineageEdge:
    Sendable, Equatable
{
    package let parent: InvestigationMachineGateObservedProcessIdentity
    package let child: InvestigationMachineGateObservedProcessIdentity

    package init(
        parent: InvestigationMachineGateObservedProcessIdentity,
        child: InvestigationMachineGateObservedProcessIdentity
    ) {
        self.parent = parent
        self.child = child
    }
}

package struct InvestigationMachineResolvedRootDriverProcessSample:
    Sendable, Equatable
{
    package let identity: InvestigationMachineGateObservedProcessIdentity
    package let isStopped: Bool
    package let observedAtContinuousNanoseconds: UInt64

    package init(
        identity: InvestigationMachineGateObservedProcessIdentity, isStopped: Bool,
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
    package var liveSigningProcessID: UInt32
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
        liveSigningProcessID: UInt32,
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
        self.liveSigningProcessID = liveSigningProcessID
        self.projectedCohortInput = projectedCohortInput
    }
}

package struct InvestigationMachineResolvedRootDriverValidationResult:
    Sendable, Equatable
{
    package let resolutionKind:
        InvestigationMachineResolvedRootDriverResolutionKind
    package let resolvedProcess: InvestigationMachineGateObservedProcessIdentity
    package let lineage: [InvestigationMachineGateObservedProcessIdentity]
    package let claimSHA256: InvestigationHandoffSHA256
}

package enum InvestigationMachineResolvedRootDriverRetirementState:
    Sendable, Equatable
{
    case absent
    case present(InvestigationMachineGateObservedProcessIdentity)
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
            let resolved = lineage.last,
            claimMatchesObservedCore(claim.process, observed: resolved),
            input.firstProcessSample.identity == resolved,
            input.secondProcessSample.identity == resolved,
            input.firstProcessSample.isStopped, input.secondProcessSample.isStopped,
            claim.observedAtContinuousNanoseconds
                <= input.firstProcessSample.observedAtContinuousNanoseconds,
            input.firstProcessSample.observedAtContinuousNanoseconds
                < input.secondProcessSample.observedAtContinuousNanoseconds,
            resolved.processGroupID == input.recoveryProcessGroupID,
            resolved.sessionID == input.coordinatorSessionID,
            resolved.processID == input.liveSigningProcessID
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
    ) throws -> [InvestigationMachineGateObservedProcessIdentity] {
        if input.lineageEdges.isEmpty {
            let resolved = input.firstProcessSample.identity
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
            lineage.allSatisfy({ identity in
                identity.auditSessionID == input.claim.process.auditSessionID
            }),
            lineage.last == input.firstProcessSample.identity
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
        _ lhs: InvestigationMachineGateObservedProcessIdentity,
        _ rhs: InvestigationMachineGateObservedProcessIdentity
    ) -> Bool {
        lhs.processID == rhs.processID
            && lhs.startSeconds == rhs.startSeconds
            && lhs.startMicroseconds == rhs.startMicroseconds
    }

    private static func identityKey(
        _ value: InvestigationMachineGateObservedProcessIdentity
    ) -> String {
        "\(value.processID):\(value.startSeconds):\(value.startMicroseconds)"
    }

    private static func claimMatchesObservedCore(
        _ claim: InvestigationGeneralProcessIdentityV1,
        observed: InvestigationMachineGateObservedProcessIdentity
    ) -> Bool {
        claim.processID == observed.processID
            && claim.auditTokenWords[0] == observed.auditUserID
            && claim.startSeconds == observed.startSeconds
            && claim.startMicroseconds == observed.startMicroseconds
            && claim.parentProcessID == observed.parentProcessID
            && claim.processGroupID == observed.processGroupID
            && claim.sessionID == observed.sessionID
            && claim.auditSessionID == observed.auditSessionID
            && claim.realUserID == observed.realUserID
            && claim.effectiveUserID == observed.effectiveUserID
            && claim.savedUserID == observed.savedUserID
            && claim.realGroupID == observed.realGroupID
            && claim.effectiveGroupID == observed.effectiveGroupID
            && claim.savedGroupID == observed.savedGroupID
            && claim.supplementaryGroups == observed.supplementaryGroups
    }

    private typealias Error =
        InvestigationMachineResolvedRootDriverValidationError
}
