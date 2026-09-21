import Foundation
import Testing
@testable import StornautCore

@Suite("Deep Dive first-use decision owner")
struct DeepDiveFirstUseTests {
    @Test
    func normalReadyRequestPresentsMissingOrObsoleteDisclosure() async throws {
        let firstUseOwner = DeepDiveFirstUseDecisionOwner(
            store: TestDisclosureStore()
        )
        let obsoleteOwner = DeepDiveFirstUseDecisionOwner(
            store: TestDisclosureStore()
        )
        let backgroundOwner = DeepDiveFirstUseDecisionOwner(
            store: TestDisclosureStore()
        )

        #expect(
            await firstUseOwner.evaluate(
                request: .normalStart,
                dimensions: firstUseDimensions(disclosure: .notPresented)
            ) == .presentDisclosure(.firstUse)
        )
        #expect(
            await obsoleteOwner.evaluate(
                request: .normalStart,
                dimensions: firstUseDimensions(disclosure: .obsolete)
            ) == .presentDisclosure(.obsolete)
        )
        #expect(
            await backgroundOwner.evaluate(
                request: .backgroundRefresh,
                dimensions: firstUseDimensions(disclosure: .notPresented)
            ) == .notApplicable
        )
    }

    @Test
    func concurrentFirstUsePresentationIsSingleFlight() async {
        let owner = DeepDiveFirstUseDecisionOwner(
            store: TestDisclosureStore()
        )
        let dimensions = firstUseDimensions(disclosure: .notPresented)

        #expect(
            await owner.evaluate(
                request: .normalStart,
                dimensions: dimensions
            ) == .presentDisclosure(.firstUse)
        )
        #expect(
            await owner.evaluate(
                request: .normalStart,
                dimensions: dimensions
            ) == .operationInProgress
        )
    }

    @Test
    func settingsReviewPresentsCurrentDisclosureWithoutRuntimeAdmission() async {
        let owner = DeepDiveFirstUseDecisionOwner(
            store: TestDisclosureStore()
        )
        let blockedDimensions = firstUseDimensions(
            disclosure: .declined
        ).replacing(
            source: .missing,
            runtime: .unverified,
            dependencies: .task38FacadeUnavailable
        )

        #expect(
            await owner.evaluate(
                request: .settingsReview,
                dimensions: blockedDimensions
            ) == .presentDisclosure(.reviewAgain)
        )
    }

    @Test
    func nonDisclosureFailureBlocksWithoutPresentingConsent() async throws {
        let store = TestDisclosureStore()
        let owner = DeepDiveFirstUseDecisionOwner(store: store)
        let dimensions = firstUseDimensions(
            disclosure: .notPresented
        ).replacing(runtime: .stale)

        #expect(
            await owner.evaluate(
                request: .normalStart,
                dimensions: dimensions
            ) == .blocked(.runtimeStale)
        )
        #expect(await store.saveCount == 0)
    }

    @Test
    func acceptPersistsThenRequiresFreshFullAdmission() async throws {
        let store = TestDisclosureStore()
        let owner = DeepDiveFirstUseDecisionOwner(store: store)
        let decidedAt = Date(timeIntervalSince1970: 1_789_700_000)
        #expect(
            await owner.evaluate(
                request: .normalStart,
                dimensions: firstUseDimensions(disclosure: .notPresented)
            ) == .presentDisclosure(.firstUse)
        )

        let result = await owner.submit(
            .accept,
            decidedAt: decidedAt
        )

        #expect(result == .acceptedRequiresFreshAdmission)
        let record = try #require(await store.record)
        #expect(record.decision == .accepted)
        #expect(record.decidedAt == decidedAt)
        #expect(await store.saveCount == 1)
    }

    @Test
    func notNowPersistsDeclineAndNeverReturnsAdmission() async throws {
        let store = TestDisclosureStore()
        let owner = DeepDiveFirstUseDecisionOwner(store: store)
        #expect(
            await owner.evaluate(
                request: .normalStart,
                dimensions: firstUseDimensions(disclosure: .notPresented)
            ) == .presentDisclosure(.firstUse)
        )

        let result = await owner.submit(
            .notNow,
            decidedAt: Date(timeIntervalSince1970: 1_789_700_000)
        )

        #expect(result == .declined)
        #expect(await store.record?.decision == .declined)
        #expect(await store.saveCount == 1)
    }

    @Test
    func persistenceFailureReturnsTypedFailureAndKeepsNoAcceptance() async {
        let store = TestDisclosureStore(failSaves: true)
        let owner = DeepDiveFirstUseDecisionOwner(store: store)
        #expect(
            await owner.evaluate(
                request: .normalStart,
                dimensions: firstUseDimensions(disclosure: .notPresented)
            ) == .presentDisclosure(.firstUse)
        )

        let result = await owner.submit(
            .accept,
            decidedAt: Date(timeIntervalSince1970: 1_789_700_000)
        )

        #expect(result == .persistenceFailed)
        #expect(await store.record == nil)
        #expect(await store.saveCount == 1)
        #expect(
            await owner.evaluate(
                request: .normalStart,
                dimensions: firstUseDimensions(disclosure: .notPresented)
            ) == .operationInProgress
        )
    }

    @Test
    func concurrentAcceptanceIsSingleFlight() async throws {
        let store = SuspendingDisclosureStore()
        let owner = DeepDiveFirstUseDecisionOwner(store: store)
        let decidedAt = Date(timeIntervalSince1970: 1_789_700_000)
        #expect(
            await owner.evaluate(
                request: .normalStart,
                dimensions: firstUseDimensions(disclosure: .notPresented)
            ) == .presentDisclosure(.firstUse)
        )
        let first = Task {
            await owner.submit(.accept, decidedAt: decidedAt)
        }
        while await store.saveCount == 0 {
            await Task.yield()
        }

        let second = await owner.submit(
            .accept,
            decidedAt: decidedAt.addingTimeInterval(1)
        )
        await store.release()
        let firstResult = await first.value

        #expect(second == .operationInProgress)
        #expect(firstResult == .acceptedRequiresFreshAdmission)
        #expect(await store.saveCount == 1)
    }

    @Test
    func directDecisionWithoutCurrentPresentationCannotPersist() async {
        let store = TestDisclosureStore()
        let owner = DeepDiveFirstUseDecisionOwner(store: store)

        #expect(
            await owner.submit(
                .accept,
                decidedAt: Date(timeIntervalSince1970: 1_789_700_000)
            ) == .presentationRequired
        )
        #expect(await store.record == nil)
        #expect(await store.saveCount == 0)
    }

    @Test
    func publicOwnerReadsAndForgetsWithoutExposingRawRecord() async throws {
        let owner = try DeepDiveFirstUseDecisionOwner(
            configuration: .memory
        )
        #expect(try await owner.disclosureReadiness() == .notPresented)
        #expect(
            await owner.evaluate(
                request: .normalStart,
                dimensions: firstUseDimensions(disclosure: .notPresented)
            ) == .presentDisclosure(.firstUse)
        )
        #expect(
            await owner.submit(
                .accept,
                decidedAt: Date(timeIntervalSince1970: 1_789_700_000)
            ) == .acceptedRequiresFreshAdmission
        )
        #expect(try await owner.disclosureReadiness() == .accepted)
        #expect(await owner.forgetAcceptance() == .forgotten)
        #expect(try await owner.disclosureReadiness() == .notPresented)
    }
}

private func firstUseDimensions(
    disclosure: DeepDiveDisclosureReadiness
) -> DeepDiveAdmissionDimensions {
    DeepDiveAdmissionDimensions(
        source: .ready,
        disclosure: disclosure,
        codex: .available,
        runtime: .admitted,
        dependencies: .available,
        workflow: .idle,
        budget: .valid(
            preset: .balanced,
            limits: .forPreset(.balanced)
        )
    )
}

private enum TestDisclosureStoreFailure: Error {
    case failed
}

private actor TestDisclosureStore: DeepDiveDisclosureRecordStoring {
    private(set) var record: DeepDiveDisclosureRecord?
    private(set) var saveCount = 0
    private let failSaves: Bool

    init(failSaves: Bool = false) {
        self.failSaves = failSaves
    }

    func load() throws -> DeepDiveDisclosureRecord? {
        record
    }

    func save(_ record: DeepDiveDisclosureRecord) throws {
        saveCount += 1
        if failSaves {
            throw TestDisclosureStoreFailure.failed
        }
        self.record = record
    }

    func forget() throws {
        record = nil
    }
}

private actor SuspendingDisclosureStore: DeepDiveDisclosureRecordStoring {
    private(set) var saveCount = 0
    private var continuation: CheckedContinuation<Void, Never>?

    func load() throws -> DeepDiveDisclosureRecord? { nil }

    func save(_ record: DeepDiveDisclosureRecord) async throws {
        saveCount += 1
        await withCheckedContinuation { continuation = $0 }
    }

    func forget() throws {}

    func release() {
        continuation?.resume()
        continuation = nil
    }
}
