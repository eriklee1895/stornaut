import Foundation

public enum DeepDiveSourceReadiness: Sendable, Equatable {
    case ready
    case missing
    case stale
    case partial
}

public enum DeepDiveDisclosureReadiness: Sendable, Equatable {
    case accepted
    case notPresented
    case declined
    case obsolete
}

public enum DeepDiveCodexReadiness: Sendable, Equatable {
    case available
    case notInstalled
    case syntaxUnsupported
    case authenticationUnavailable
    case checkFailed
}

public enum DeepDiveRuntimeReadiness: Sendable, Equatable {
    case admitted
    case stale
    case failed
    case unverified
}

public enum DeepDiveDependencyReadiness: Sendable, Equatable {
    case available
    case task38FacadeUnavailable
    case storeUnavailable
    case lifecycleUnavailable
}

public enum DeepDiveWorkflowReadiness: Sendable, Equatable {
    case idle
    case quickScanRunning
    case cleanupExecuting
    case historyMutationInProgress
    case settingsMutationInProgress
}

public enum DeepDiveBudgetReadiness: Sendable, Equatable {
    case valid(
        preset: InvestigationBudgetPreset,
        limits: InvestigationBudgetLimits
    )
    case invalid
}

public struct DeepDiveAdmissionDimensions: Sendable, Equatable {
    public let source: DeepDiveSourceReadiness
    public let disclosure: DeepDiveDisclosureReadiness
    public let codex: DeepDiveCodexReadiness
    public let runtime: DeepDiveRuntimeReadiness
    public let dependencies: DeepDiveDependencyReadiness
    public let workflow: DeepDiveWorkflowReadiness
    public let budget: DeepDiveBudgetReadiness

    public init(
        source: DeepDiveSourceReadiness,
        disclosure: DeepDiveDisclosureReadiness,
        codex: DeepDiveCodexReadiness,
        runtime: DeepDiveRuntimeReadiness,
        dependencies: DeepDiveDependencyReadiness,
        workflow: DeepDiveWorkflowReadiness,
        budget: DeepDiveBudgetReadiness
    ) {
        self.source = source
        self.disclosure = disclosure
        self.codex = codex
        self.runtime = runtime
        self.dependencies = dependencies
        self.workflow = workflow
        self.budget = budget
    }

    public func replacing(
        source: DeepDiveSourceReadiness? = nil,
        disclosure: DeepDiveDisclosureReadiness? = nil,
        codex: DeepDiveCodexReadiness? = nil,
        runtime: DeepDiveRuntimeReadiness? = nil,
        dependencies: DeepDiveDependencyReadiness? = nil,
        workflow: DeepDiveWorkflowReadiness? = nil,
        budget: DeepDiveBudgetReadiness? = nil
    ) -> Self {
        Self(
            source: source ?? self.source,
            disclosure: disclosure ?? self.disclosure,
            codex: codex ?? self.codex,
            runtime: runtime ?? self.runtime,
            dependencies: dependencies ?? self.dependencies,
            workflow: workflow ?? self.workflow,
            budget: budget ?? self.budget
        )
    }
}

public enum DeepDiveAggregateAvailability:
    String,
    Sendable,
    Equatable
{
    case available
    case needsBaselineScan
    case needsDisclosure
    case disclosureDeclined
    case codexUnavailable
    case runtimeBlocked
    case runtimeStale
    case dependenciesUnavailable
    case workflowBusy
    case invalidBudget
}

public struct DeepDiveAvailabilityProjection: Sendable, Equatable {
    public let dimensions: DeepDiveAdmissionDimensions
    public let aggregate: DeepDiveAggregateAvailability

    public var quickScanAvailable: Bool { true }

    // Task 41 models configuration admission only. Task 44 exclusively owns
    // removal of the final normal-product feature gate.
    public var normalProductStartEnabled: Bool { false }
}

public enum DeepDiveAvailabilityEvaluator {
    public static func evaluate(
        _ dimensions: DeepDiveAdmissionDimensions
    ) -> DeepDiveAvailabilityProjection {
        DeepDiveAvailabilityProjection(
            dimensions: dimensions,
            aggregate: aggregate(dimensions)
        )
    }

    private static func aggregate(
        _ dimensions: DeepDiveAdmissionDimensions
    ) -> DeepDiveAggregateAvailability {
        switch dimensions.runtime {
        case .stale:
            return .runtimeStale
        case .failed, .unverified:
            return .runtimeBlocked
        case .admitted:
            break
        }
        guard dimensions.codex == .available else {
            return .codexUnavailable
        }
        guard dimensions.dependencies == .available else {
            return .dependenciesUnavailable
        }
        guard dimensions.workflow == .idle else {
            return .workflowBusy
        }
        guard case let .valid(preset, limits) = dimensions.budget,
              limits == .forPreset(preset)
        else {
            return .invalidBudget
        }
        guard dimensions.source == .ready else {
            return .needsBaselineScan
        }
        switch dimensions.disclosure {
        case .accepted:
            return .available
        case .notPresented, .obsolete:
            return .needsDisclosure
        case .declined:
            return .disclosureDeclined
        }
    }
}
