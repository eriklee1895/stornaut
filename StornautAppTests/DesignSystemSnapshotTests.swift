import Foundation
import StornautCore
import SwiftUI
import Testing

@testable import StornautApp

/// Pixel-level contracts for the shared design system.
///
/// The luminance heuristics in `scripts/verify-ui-screenshots` only prove a
/// window is not blank and that Light and Dark differ. These snapshots prove
/// the components actually lay out, wrap and translate the way they did when
/// the golden was recorded.
@MainActor
@Suite("Design system snapshots")
struct DesignSystemSnapshotTests {
    private static let referenceDate = Date(timeIntervalSince1970: 1_786_320_000)

    @Test(arguments: SnapshotAppearance.allCases, SnapshotLanguage.allCases)
    func statusBadgeGallery(
        appearance: SnapshotAppearance,
        language: SnapshotLanguage
    ) throws {
        let gallery = VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                CoverageBadge(
                    model: CoverageBadgeModel(
                        gapCount: 0,
                        unmeasurableBytes: ByteCount(0)
                    )
                )
                CoverageBadge(
                    model: CoverageBadgeModel(
                        gapCount: 2,
                        unmeasurableBytes: nil
                    )
                )
            }

            HStack(spacing: 12) {
                RetentionBadge(
                    model: RetentionBadgeModel(
                        expiresAt: Self.referenceDate.addingTimeInterval(
                            8 * 86_400
                        ),
                        now: Self.referenceDate
                    )
                )
                RetentionBadge(
                    model: RetentionBadgeModel(
                        expiresAt: Self.referenceDate.addingTimeInterval(
                            86_400
                        ),
                        now: Self.referenceDate
                    )
                )
                RetentionBadge(
                    model: RetentionBadgeModel(
                        expiresAt: Self.referenceDate.addingTimeInterval(-1),
                        now: Self.referenceDate
                    )
                )
            }

            ForEach(ReclaimDisposition.allCases, id: \.self) { disposition in
                ReclaimDispositionLabel(disposition: disposition)
            }
        }
        .padding(16)

        try SnapshotHarness.verify(
            gallery,
            named: "design-system.status-badges",
            size: CGSize(width: 420, height: 260),
            appearance: appearance,
            language: language
        )
    }

    @Test(arguments: SnapshotAppearance.allCases, SnapshotLanguage.allCases)
    func metricTile(
        appearance: SnapshotAppearance,
        language: SnapshotLanguage
    ) throws {
        let tiles = HStack(spacing: 12) {
            MetricTile(
                title: "overview.metric.ready",
                value: "128 GB",
                accessibilityValue: "128 GB (128,000,000,000 bytes)",
                systemImage: "internaldrive"
            )
            MetricTile(
                title: "overview.metric.explained",
                value: "—",
                accessibilityValue: "Unknown",
                systemImage: "questionmark.circle"
            )
        }
        .padding(16)

        try SnapshotHarness.verify(
            tiles,
            named: "design-system.metric-tile",
            size: CGSize(width: 480, height: 140),
            appearance: appearance,
            language: language
        )
    }

    @Test(arguments: SnapshotAppearance.allCases, SnapshotLanguage.allCases)
    func emptyState(
        appearance: SnapshotAppearance,
        language: SnapshotLanguage
    ) throws {
        let view = StornautEmptyStateView(
            titleKey: "empty.snapshot.title",
            messageKey: "empty.snapshot.message",
            systemImage: "tray",
            actionTitleKey: nil,
            action: nil
        )

        try SnapshotHarness.verify(
            view,
            named: "design-system.empty-state",
            size: CGSize(width: 480, height: 280),
            appearance: appearance,
            language: language
        )
    }

    @Test(arguments: SnapshotAppearance.allCases, SnapshotLanguage.allCases)
    func recoveryState(
        appearance: SnapshotAppearance,
        language: SnapshotLanguage
    ) throws {
        let view = RecoveryStateView(
            model: RecoveryStateModel(
                titleKey: "recovery.partial.title",
                messageKey: "recovery.partial.message",
                systemImage: "exclamationmark.triangle",
                role: .limited,
                primaryIntent: .retryLatestSnapshot,
                secondaryIntent: .reviewPermissions
            ),
            primaryAction: {},
            secondaryAction: {},
            content: { EmptyView() }
        )
        .padding(16)

        try SnapshotHarness.verify(
            view,
            named: "design-system.recovery-state",
            size: CGSize(width: 620, height: 200),
            appearance: appearance,
            language: language
        )
    }
}
