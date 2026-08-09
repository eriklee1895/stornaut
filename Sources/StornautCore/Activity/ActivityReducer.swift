import Foundation

public struct ActivityReducer: Sendable {
    public init() {}

    public func reduce(
        _ input: ActivityReductionInput
    ) -> ActivityReductionResult {
        let required = Set(input.requiredKeys)
        let applicable = input.observations.filter {
            required.contains($0.key)
        }
        let statesByKey = Dictionary(grouping: applicable, by: \.key)
        let contradicted = input.requiredKeys.filter { key in
            statesByKey[key, default: []].contains {
                $0.state == .contradicted
            }
        }
        let missing = input.requiredKeys.filter { key in
            let states = statesByKey[key, default: []]
            return states.isEmpty || states.contains {
                $0.state == .unavailable
            }
        }
        let hasRecentExternalActivity = input.recentActivityCutoffIsValid
            && input.timestamps.contains {
                $0.origin == .external
                    && $0.observedAt >= input.recentActivityCutoff
            }

        let disposition: ReclaimDisposition
        if input.baseDisposition == .protected {
            disposition = .protected
        } else if !contradicted.isEmpty || hasRecentExternalActivity {
            disposition = .protected
        } else if input.baseDisposition == .unknown
                    || !missing.isEmpty
                    || !input.recentActivityCutoffIsValid
        {
            disposition = .unknown
        } else {
            disposition = input.baseDisposition
        }

        let risk = conservativeRisk(
            input.baseRisk,
            protecting: disposition == .protected
                && input.baseDisposition != .protected
        )
        return ActivityReductionResult(
            disposition: disposition,
            risk: risk,
            missingKeys: missing,
            observations: input.observations,
            timestamps: input.timestamps,
            activityFingerprint: activityFingerprint(
                observations: input.observations,
                timestamps: input.timestamps
            )
        )
    }
}

private func conservativeRisk(
    _ risk: RiskLevel,
    protecting: Bool
) -> RiskLevel {
    guard protecting else {
        return risk
    }
    switch risk {
    case .low, .medium:
        return .high
    case .high, .critical:
        return risk
    }
}
