import StornautCore
import SwiftUI

enum SemanticStatusRole: String, Sendable {
    case neutral
    case informational
    case positive
    case limited
    case failed
    case protected

    var color: Color {
        switch self {
        case .neutral:
            .secondary
        case .informational:
            .blue
        case .positive:
            .green
        case .limited:
            .orange
        case .failed:
            .red
        case .protected:
            .indigo
        }
    }
}

struct SemanticDisposition: Sendable, Equatable {
    let disposition: ReclaimDisposition
    let localizationKey: String
    let accessibilityLocalizationKey: String
    let systemImage: String
    let role: SemanticStatusRole

    init(_ disposition: ReclaimDisposition) {
        self.disposition = disposition
        switch disposition {
        case .readyToReclaim:
            localizationKey = "disposition.ready"
            accessibilityLocalizationKey = "disposition.ready.accessibility"
            systemImage = "checkmark.circle"
            role = .positive
        case .reviewRecommended:
            localizationKey = "disposition.review"
            accessibilityLocalizationKey = "disposition.review.accessibility"
            systemImage = "eye.circle"
            role = .limited
        case .protected:
            localizationKey = "disposition.protected"
            accessibilityLocalizationKey =
                "disposition.protected.accessibility"
            systemImage = "lock.shield"
            role = .protected
        case .unknown:
            localizationKey = "disposition.unknown"
            accessibilityLocalizationKey = "disposition.unknown.accessibility"
            systemImage = "questionmark.circle"
            role = .neutral
        }
    }
}

enum CoverageState: String, Sendable {
    case complete
    case limited
}

struct CoverageBadgeModel: Sendable, Equatable {
    let state: CoverageState
    let value: ByteCount?
    let gapCount: Int
    let localizationKey: String
    let systemImage: String
    let role: SemanticStatusRole

    init(gapCount: Int, unmeasurableBytes: ByteCount?) {
        let normalizedGapCount = max(0, gapCount)
        self.gapCount = normalizedGapCount
        if normalizedGapCount > 0 || unmeasurableBytes != ByteCount(0) {
            state = .limited
            value = nil
            localizationKey = "coverage.limited"
            systemImage = "exclamationmark.triangle"
            role = .limited
        } else {
            state = .complete
            value = unmeasurableBytes
            localizationKey = "coverage.complete"
            systemImage = "checkmark.circle"
            role = .positive
        }
    }
}

enum RetentionState: String, Sendable {
    case retained
    case expiringSoon
    case expired
}

struct RetentionBadgeModel: Sendable, Equatable {
    let state: RetentionState
    let expiresAt: Date
    let localizationKey: String
    let systemImage: String
    let role: SemanticStatusRole

    init(expiresAt: Date, now: Date = Date()) {
        self.expiresAt = expiresAt
        if expiresAt <= now {
            state = .expired
            localizationKey = "retention.expired"
            systemImage = "clock.badge.xmark"
            role = .neutral
        } else if expiresAt.timeIntervalSince(now) <= 2 * 86_400 {
            state = .expiringSoon
            localizationKey = "retention.expiringSoon"
            systemImage = "clock.badge.exclamationmark"
            role = .limited
        } else {
            state = .retained
            localizationKey = "retention.retained"
            systemImage = "clock"
            role = .informational
        }
    }
}

struct RecoveryStateModel: Sendable, Equatable {
    let titleKey: String
    let messageKey: String
    let systemImage: String
    let role: SemanticStatusRole
    let primaryIntent: SafeRecoveryIntent?
    let secondaryIntent: SafeRecoveryIntent?

    init(
        titleKey: String,
        messageKey: String,
        systemImage: String,
        role: SemanticStatusRole,
        primaryIntent: SafeRecoveryIntent?,
        secondaryIntent: SafeRecoveryIntent?
    ) {
        self.titleKey = titleKey
        self.messageKey = messageKey
        self.systemImage = systemImage
        self.role = role
        self.primaryIntent = primaryIntent
        self.secondaryIntent = primaryIntent == secondaryIntent
            ? nil
            : secondaryIntent
    }
}
