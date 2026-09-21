import Foundation

public enum DeepDiveFirstUseRequest: Sendable, Equatable {
    case normalStart
    case settingsReview
    case backgroundRefresh
}

public enum DeepDiveDisclosurePresentationReason: Sendable, Equatable {
    case firstUse
    case obsolete
    case reviewAgain
}

public enum DeepDiveFirstUseEvaluation: Sendable, Equatable {
    case presentDisclosure(DeepDiveDisclosurePresentationReason)
    case readyRequiresFreshAdmission
    case blocked(DeepDiveAggregateAvailability)
    case operationInProgress
    case notApplicable
}

public enum DeepDiveFirstUseDecision: Sendable, Equatable {
    case accept
    case notNow
}

public enum DeepDiveFirstUseDecisionResult: Sendable, Equatable {
    case acceptedRequiresFreshAdmission
    case declined
    case presentationRequired
    case persistenceFailed
    case operationInProgress
}

public enum DeepDiveForgetAcceptanceResult: Sendable, Equatable {
    case forgotten
    case operationInProgress
    case persistenceFailed
}

public actor DeepDiveFirstUseDecisionOwner {
    private let store: any DeepDiveDisclosureRecordStoring
    private let descriptor: DeepDiveDisclosureDescriptor
    private var presentationInFlight = false
    private var mutationInFlight = false

    public init(
        configuration: LocalStoreConfiguration,
        descriptor: DeepDiveDisclosureDescriptor = .current
    ) throws {
        store = try DeepDiveDisclosurePreferenceStore(
            configuration: configuration
        )
        self.descriptor = descriptor
    }

    init(
        store: any DeepDiveDisclosureRecordStoring,
        descriptor: DeepDiveDisclosureDescriptor = .current
    ) {
        self.store = store
        self.descriptor = descriptor
    }

    public func evaluate(
        request: DeepDiveFirstUseRequest,
        dimensions: DeepDiveAdmissionDimensions
    ) -> DeepDiveFirstUseEvaluation {
        if request == .settingsReview {
            guard !presentationInFlight else {
                return .operationInProgress
            }
            presentationInFlight = true
            return dimensions.disclosure == .obsolete
                ? .presentDisclosure(.obsolete)
                : .presentDisclosure(.reviewAgain)
        }
        guard request == .normalStart else {
            return .notApplicable
        }
        let withoutDisclosure = dimensions.replacing(
            disclosure: .accepted
        )
        let nonDisclosureAggregate = DeepDiveAvailabilityEvaluator.evaluate(
            withoutDisclosure
        ).aggregate
        guard nonDisclosureAggregate == .available else {
            return .blocked(nonDisclosureAggregate)
        }
        switch dimensions.disclosure {
        case .notPresented:
            guard !presentationInFlight else {
                return .operationInProgress
            }
            presentationInFlight = true
            return .presentDisclosure(.firstUse)
        case .obsolete:
            guard !presentationInFlight else {
                return .operationInProgress
            }
            presentationInFlight = true
            return .presentDisclosure(.obsolete)
        case .declined:
            return .blocked(.disclosureDeclined)
        case .accepted:
            return .readyRequiresFreshAdmission
        }
    }

    public func disclosureReadiness() async throws
        -> DeepDiveDisclosureReadiness
    {
        switch descriptor.state(for: try await store.load()) {
        case .notPresented:
            return .notPresented
        case .accepted:
            return .accepted
        case .declined:
            return .declined
        case .obsolete:
            return .obsolete
        }
    }

    public func forgetAcceptance() async -> DeepDiveForgetAcceptanceResult {
        guard !mutationInFlight else {
            return .operationInProgress
        }
        mutationInFlight = true
        defer { mutationInFlight = false }
        do {
            try await store.forget()
            presentationInFlight = false
            return .forgotten
        } catch {
            return .persistenceFailed
        }
    }

    public func submit(
        _ decision: DeepDiveFirstUseDecision,
        decidedAt: Date
    ) async -> DeepDiveFirstUseDecisionResult {
        guard presentationInFlight else {
            return .presentationRequired
        }
        guard !mutationInFlight else {
            return .operationInProgress
        }
        mutationInFlight = true
        defer { mutationInFlight = false }
        do {
            let record = try descriptor.record(
                decision: decision == .accept ? .accepted : .declined,
                decidedAt: decidedAt
            )
            try await store.save(record)
            presentationInFlight = false
            switch decision {
            case .accept:
                return .acceptedRequiresFreshAdmission
            case .notNow:
                return .declined
            }
        } catch {
            return .persistenceFailed
        }
    }
}
