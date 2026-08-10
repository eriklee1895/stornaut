struct SemanticAppPhase: Sendable, Equatable {
    let phase: AppPagePhase
    let localizationKey: String
    let systemImage: String
    let role: SemanticStatusRole

    init(_ phase: AppPagePhase) {
        self.phase = phase
        switch phase {
        case .empty:
            localizationKey = "phase.empty"
            systemImage = "tray"
            role = .neutral
        case .loading:
            localizationKey = "phase.loading"
            systemImage = "progress.indicator"
            role = .informational
        case .partial:
            localizationKey = "phase.partial"
            systemImage = "circle.lefthalf.filled"
            role = .limited
        case .cancelled:
            localizationKey = "phase.cancelled"
            systemImage = "stop.circle"
            role = .neutral
        case .success:
            localizationKey = "phase.success"
            systemImage = "checkmark.circle"
            role = .positive
        case .limitedPermission:
            localizationKey = "phase.limitedPermission"
            systemImage = "lock.trianglebadge.exclamationmark"
            role = .limited
        case .stale:
            localizationKey = "phase.stale"
            systemImage = "clock.arrow.circlepath"
            role = .limited
        case .error:
            localizationKey = "phase.error"
            systemImage = "exclamationmark.octagon"
            role = .failed
        }
    }
}
