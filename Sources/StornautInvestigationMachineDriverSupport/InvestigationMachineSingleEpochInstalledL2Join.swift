import Foundation
import StornautInvestigationHandoffContract
import StornautInvestigationInstalledL2

package struct InvestigationMachineSingleEpochInstalledL2Proof:
    Sendable,
    Equatable
{
    private let projectionSHA256: InvestigationHandoffSHA256
    private let claimEvidenceSHA256: InvestigationHandoffSHA256
    private let semanticObservation: InvestigationInstalledL2SemanticObservation
    private let repeatedAppIdentity: InvestigationMachineProcessIdentity
    private let epochUUID: UUID
    private let deadlineNanoseconds: UInt64

    fileprivate init(
        projectionSHA256: InvestigationHandoffSHA256,
        claimEvidenceSHA256: InvestigationHandoffSHA256,
        semanticObservation: InvestigationInstalledL2SemanticObservation,
        repeatedAppIdentity: InvestigationMachineProcessIdentity,
        epochUUID: UUID,
        deadlineNanoseconds: UInt64
    ) {
        self.projectionSHA256 = projectionSHA256
        self.claimEvidenceSHA256 = claimEvidenceSHA256
        self.semanticObservation = semanticObservation
        self.repeatedAppIdentity = repeatedAppIdentity
        self.epochUUID = epochUUID
        self.deadlineNanoseconds = deadlineNanoseconds
    }
}

package protocol InvestigationMachineSingleEpochInstalledL2SemanticObserving:
    Sendable
{
    func observe(
        projection: InvestigationInstalledL2IdentityProjection,
        expectedApp: InvestigationMachineProcessIdentity,
        expectedHelper: InvestigationMachineProcessIdentity
    ) throws -> InvestigationInstalledL2SemanticObservation
}

extension InvestigationInstalledL2Observer:
    InvestigationMachineSingleEpochInstalledL2SemanticObserving {}

package protocol InvestigationMachineSingleEpochInstalledL2Observing: Sendable {
    func observe(
        projection: InvestigationInstalledL2IdentityProjection,
        appIdentity: InvestigationMachineProcessIdentity,
        claimEvidence: InvestigationMachineClaimEvidence,
        epochUUID: UUID,
        deadlineNanoseconds: UInt64
    ) async throws -> InvestigationInstalledL2SemanticObservation
}

struct InvestigationMachineSingleEpochInstalledL2Join:
    InvestigationMachineSingleEpochInstalledL2Observing,
    Sendable
{
    private let observer:
        any InvestigationMachineSingleEpochInstalledL2SemanticObserving

    package init() {
        observer = InvestigationInstalledL2Observer()
    }

    init(
        observer:
            any InvestigationMachineSingleEpochInstalledL2SemanticObserving
    ) {
        self.observer = observer
    }

    func observe(
        projection: InvestigationInstalledL2IdentityProjection,
        appIdentity: InvestigationMachineProcessIdentity,
        claimEvidence: InvestigationMachineClaimEvidence,
        epochUUID: UUID,
        deadlineNanoseconds: UInt64
    ) async throws -> InvestigationInstalledL2SemanticObservation {
        try Task.checkCancellation()
        guard
            projection.epochUUID == epochUUID,
            claimEvidence.appIdentity == appIdentity,
            claimEvidence.helperIdentity.role == .helper,
            claimEvidence.l1Residue.investigationUUID
                == projection.configurationNonce,
            claimEvidence.releaseDeadlineNanoseconds > 0,
            claimEvidence.releaseDeadlineNanoseconds <= deadlineNanoseconds
        else {
            throw InvestigationMachineSingleEpochError.installedL2Failed
        }
        let semantic: InvestigationInstalledL2SemanticObservation
        do {
            semantic = try observer.observe(
                projection: projection,
                expectedApp: appIdentity,
                expectedHelper: claimEvidence.helperIdentity
            )
        } catch {
            throw InvestigationMachineSingleEpochError.installedL2Failed
        }
        try Task.checkCancellation()
        guard Self.matches(
            semantic, projection: projection, claimEvidence: claimEvidence,
            appIdentity: appIdentity, epochUUID: epochUUID,
            deadlineNanoseconds: deadlineNanoseconds
        ) else {
            throw InvestigationMachineSingleEpochError.installedL2Failed
        }
        return semantic
    }

    static func prove(
        projection: InvestigationInstalledL2IdentityProjection,
        claimEvidence: InvestigationMachineClaimEvidence,
        semanticObservation: InvestigationInstalledL2SemanticObservation,
        repeatedAppIdentity: InvestigationMachineProcessIdentity,
        epochUUID: UUID,
        deadlineNanoseconds: UInt64
    ) throws -> InvestigationMachineSingleEpochInstalledL2Proof {
        guard
            repeatedAppIdentity == claimEvidence.appIdentity,
            Self.matches(
                semanticObservation, projection: projection,
                claimEvidence: claimEvidence,
                appIdentity: repeatedAppIdentity, epochUUID: epochUUID,
                deadlineNanoseconds: deadlineNanoseconds
            )
        else {
            throw InvestigationMachineSingleEpochError.installedL2Failed
        }
        return InvestigationMachineSingleEpochInstalledL2Proof(
            projectionSHA256: projection.projectionSHA256,
            claimEvidenceSHA256: .hashing(try claimEvidence.encoded()),
            semanticObservation: semanticObservation,
            repeatedAppIdentity: repeatedAppIdentity,
            epochUUID: epochUUID,
            deadlineNanoseconds: deadlineNanoseconds
        )
    }

    private static func matches(
        _ semantic: InvestigationInstalledL2SemanticObservation,
        projection: InvestigationInstalledL2IdentityProjection,
        claimEvidence: InvestigationMachineClaimEvidence,
        appIdentity: InvestigationMachineProcessIdentity,
        epochUUID: UUID,
        deadlineNanoseconds: UInt64
    ) -> Bool {
        projection.epochUUID == epochUUID
            && semantic.projectionSHA256 == projection.projectionSHA256
            && semantic.epochUUID == epochUUID
            && semantic.configurationNonce == projection.configurationNonce
            && semantic.appIdentity == appIdentity
            && semantic.helperIdentity == claimEvidence.helperIdentity
            && claimEvidence.appIdentity == appIdentity
            && claimEvidence.l1Residue.investigationUUID
                == projection.configurationNonce
            && claimEvidence.claimedAt <= semantic.started.wallUTC
            && semantic.observed.continuousNanoseconds
                < claimEvidence.releaseDeadlineNanoseconds
            && claimEvidence.releaseDeadlineNanoseconds <= deadlineNanoseconds
    }
}
