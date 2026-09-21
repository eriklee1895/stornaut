import StornautCore
import Testing

@Suite("Investigation report App model")
struct InvestigationReportModelTests {
    @Test
    func consumesOnlyThePublicCoreFacade_BitsUT() async throws {
        let store = try EvidenceStore(configuration: .memory)

        _ = try InvestigationReviewProjector(store: store)
        _ = InvestigationContinuationPlanner(store: store)

        #expect(InvestigationReviewProjectionState.ready.rawValue == "ready")
        #expect(
            InvestigationReviewRowClass.agentAssistedReviewRecommended.rawValue
                == "agentAssistedReviewRecommended"
        )
    }
}
