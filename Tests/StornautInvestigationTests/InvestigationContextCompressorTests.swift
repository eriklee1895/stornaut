import Foundation
import Testing
import StornautCore
@testable import StornautInvestigation

@Suite("Investigation context and prompt")
struct InvestigationContextCompressorTests {
    @Test
    func equalPlanProducesDeterministicBoundedContextWithEveryTargetOnce()
        throws
    {
        let fixture = try InvestigationCoordinatorFixture()
        let compressor = InvestigationContextCompressor()

        let first = try compressor.compress(
            plan: fixture.plan,
            runID: fixture.session.runID,
            receipt: fixture.receipt,
            priorPartialSummary: nil
        )
        let second = try compressor.compress(
            plan: fixture.plan,
            runID: fixture.session.runID,
            receipt: fixture.receipt,
            priorPartialSummary: nil
        )

        #expect(first == second)
        #expect(
            first.contextBytes.count
                <= Int(InvestigationBudgetLimits.singleContextInputByteLimit)
        )
        for targetID in fixture.plan.targets.map(\.id.rawValue) {
            #expect(first.contextText.components(separatedBy: targetID).count == 2)
        }
        #expect(!first.contextText.contains("/Users/"))
        #expect(
            first.protocolContext.targetIDs
                == Set(fixture.plan.targets.map(\.id.rawValue))
        )
        let targetID = try #require(fixture.plan.targets.first?.id.rawValue)
        let candidateID = try #require(
            first.protocolContext.candidateTargetIDs.first?.key
        )
        #expect(
            first.protocolContext.candidateTargetIDs[candidateID] == targetID
        )
        #expect(candidateID.hasPrefix("candidate-"))
        #expect(first.contextText.contains("candidate-proposal-id: \(candidateID)"))
    }

    @Test
    func candidateProposalIDsAreSwiftOwnedAndDeterministic() throws {
        let fixture = try InvestigationCoordinatorFixture()
        let compressor = InvestigationContextCompressor()

        let first = try compressor.compress(
            plan: fixture.plan,
            runID: fixture.session.runID,
            receipt: fixture.receipt,
            priorPartialSummary: nil
        )
        let second = try compressor.compress(
            plan: fixture.plan,
            runID: fixture.session.runID,
            receipt: fixture.receipt,
            priorPartialSummary: nil
        )

        #expect(
            first.protocolContext.candidateTargetIDs
                == second.protocolContext.candidateTargetIDs
        )
        #expect(
            first.protocolContext.candidateTargetIDs.count
                == min(fixture.plan.targets.count, 256)
        )
        #expect(!first.contextText.contains("snapshot-task38-fixture"))
        #expect(!first.contextText.contains("/"))
    }

    @Test
    func exactSingleAndCumulativeContextBoundsAreClosed() throws {
        let limits = InvestigationBudgetLimits.forPreset(.focused)
        let maximum = limits.singleContextInputBytes

        #expect(
            InvestigationContextCompressor.admission(
                inputByteCount: maximum - 1,
                cumulativeConsumed: 0,
                limits: limits
            ) == .admitted
        )
        #expect(
            InvestigationContextCompressor.admission(
                inputByteCount: maximum,
                cumulativeConsumed: 0,
                limits: limits
            ) == .admitted
        )
        #expect(
            InvestigationContextCompressor.admission(
                inputByteCount: maximum + 1,
                cumulativeConsumed: 0,
                limits: limits
            ) == .wouldExceed
        )
        #expect(
            InvestigationContextCompressor.admission(
                inputByteCount: 1,
                cumulativeConsumed: limits.cumulativeContextBytes,
                limits: limits
            ) == .wouldExceed
        )
    }

    @Test
    func versionedPromptDeclaresInvestigatorAndRejectsExecutionAuthority()
        throws
    {
        let prompt = try InvestigationPromptV1.load()

        #expect(prompt.contains("read-only investigator"))
        #expect(prompt.contains("untrusted evidence"))
        #expect(prompt.contains("every admitted target"))
        #expect(prompt.contains("Envelope v2"))
        #expect(prompt.contains("not an executor"))
        #expect(prompt.contains("Do not write, delete, move, clean"))
        #expect(!prompt.contains("containment is enforced by this prompt"))
    }
}
