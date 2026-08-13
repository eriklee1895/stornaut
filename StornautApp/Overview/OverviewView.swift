import AppKit
import SwiftUI

struct OverviewView: View {
    let model: OverviewModel
    let openScan: () -> Void
    let retryLatestSnapshot: () -> Void

    private let byteFormatter = StornautByteFormatter()

    var body: some View {
        Group {
            if model.snapshot == nil {
                snapshotUnavailableContent
            } else {
                snapshotContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(pageBackground)
        .navigationTitle("overview.title")
    }

    @ViewBuilder
    private var snapshotUnavailableContent: some View {
        switch model.presentation {
        case .loading:
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text("overview.status.loading")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("overview.loading")
        case .scanInProgress:
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text("overview.status.scanning")
                    .font(.headline)
                Text("overview.status.scanning.message")
                    .foregroundStyle(.secondary)
                Button("overview.action.viewScan", action: openScan)
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("overview.scanning")
        case .error:
            StornautEmptyStateView(
                titleKey: "overview.status.error",
                messageKey: "app.state.store-unavailable",
                systemImage: "externaldrive.badge.exclamationmark",
                actionTitleKey: "overview.action.retry",
                action: retryLatestSnapshot
            )
            .accessibilityIdentifier("overview.error")
        default:
            StornautEmptyStateView(
                titleKey: "overview.empty.title",
                messageKey: "overview.empty.message",
                systemImage: "externaldrive.badge.plus",
                actionTitleKey: "overview.action.quickScan",
                action: openScan
            )
            .accessibilityIdentifier("overview.empty")
        }
    }

    private var snapshotContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                statusBanner
                metrics
                ledgerWorkspace
                scanModes
                opportunities
            }
            .padding(28)
            .frame(maxWidth: 1_180, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .accessibilityIdentifier("overview.snapshot")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("overview.scope")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(scopeDisplayName)
                    .font(.largeTitle.weight(.semibold))
                Text("overview.subtitle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let snapshot = model.snapshot {
                VStack(alignment: .trailing, spacing: 5) {
                    Label {
                        Text(snapshot.sampledAt, format: .dateTime
                            .year().month().day().hour().minute())
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.callout)

                    Text(snapshot.scopePath.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 340)

                    if let coverage = model.coverage {
                        CoverageBadge(model: coverage)
                            .accessibilityIdentifier("overview.coverage")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let descriptor = statusDescriptor {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: descriptor.systemImage)
                    .foregroundStyle(descriptor.role.color)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(descriptor.titleKey))
                        .font(.headline)
                    Text(LocalizedStringKey(descriptor.messageKey))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if model.presentation == .stale,
                       let sampledAt = model.snapshot?.sampledAt
                    {
                        HStack(spacing: 4) {
                            Text("overview.scannedAt")
                            Text(
                                sampledAt,
                                format: .relative(presentation: .named)
                            )
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                if model.presentation == .limitedPermission {
                    Button("recovery.action.permissions") {}
                        .buttonStyle(.bordered)
                        .disabled(true)
                        .help("overview.status.limited.message")
                }
            }
            .padding(14)
            .background(
                descriptor.role.color.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .accessibilityIdentifier(
                "overview.status.\(model.presentation.rawValue)"
            )
        }
    }

    @ViewBuilder
    private var metrics: some View {
        if let metrics = model.metrics {
            HStack(spacing: 14) {
                MetricTile(
                    title: "overview.metric.free",
                    value: byteFormatter.string(for: metrics.free.bytes),
                    accessibilityValue: byteFormatter.accessibilityString(
                        for: metrics.free.bytes
                    ),
                    systemImage: "internaldrive"
                )
                .accessibilityIdentifier("overview.metric.free")

                MetricTile(
                    title: "overview.metric.explained",
                    value: percent(metrics.explained.fraction),
                    accessibilityValue: [
                        percent(metrics.explained.fraction),
                        byteFormatter.accessibilityString(
                            for: metrics.explained.bytes
                        ),
                    ].joined(separator: ", "),
                    systemImage: "chart.pie"
                )
                .accessibilityIdentifier("overview.metric.explained")

                MetricTile(
                    title: "overview.metric.ready",
                    value: byteFormatter.string(
                        for: metrics.readyToReclaim.bytes
                    ),
                    accessibilityValue: byteFormatter.accessibilityString(
                        for: metrics.readyToReclaim.bytes
                    ),
                    systemImage: "checkmark.circle"
                )
                .accessibilityIdentifier("overview.metric.ready")
            }
        }
    }

    private var ledgerWorkspace: some View {
        HStack(alignment: .top, spacing: 28) {
            StorageOrbitView(
                segments: model.orbitSegments,
                formatter: byteFormatter,
                deepDive: model.deepDive
            )
            .frame(minWidth: 330, idealWidth: 380)

            Divider()

            SpaceLedgerView(
                rows: model.ledgerRows,
                formatter: byteFormatter
            )
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .accessibilityIdentifier("overview.ledger")
    }

    private var scanModes: some View {
        HStack(alignment: .top, spacing: 14) {
            modeCard(
                titleKey: "overview.quickScan.title",
                messageKey: "overview.quickScan.message",
                systemImage: StornautSystemImage.quickScan,
                role: .informational
            ) {
                Button(primaryActionTitle, action: primaryAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(model.primaryAction == nil)
                    .accessibilityIdentifier("overview.action.quickScan")
            }

            modeCard(
                titleKey: "overview.deepDive.title",
                messageKey: "overview.deepDive.message",
                systemImage: "lock.shield",
                role: .protected
            ) {
                Label(
                    "overview.deepDive.implementationUnavailable",
                    systemImage: "pause.circle"
                )
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(
                    "overview.deepDive.implementationUnavailable"
                )
            }
        }
    }

    private var opportunities: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("overview.opportunities.title")
                    .font(.title2.weight(.semibold))
                Text("overview.opportunities.subtitle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if model.opportunities.isEmpty {
                Text("overview.opportunities.empty")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.opportunities) { opportunity in
                        OverviewOpportunityRow(
                            opportunity: opportunity,
                            formatter: byteFormatter
                        )
                        if opportunity.id != model.opportunities.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(
                    .background.secondary,
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
        }
        .accessibilityIdentifier("overview.opportunities")
    }

    private func modeCard<Actions: View>(
        titleKey: String,
        messageKey: String,
        systemImage: String,
        role: SemanticStatusRole,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(role.color)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(titleKey))
                    .font(.headline)
                Text(LocalizedStringKey(messageKey))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                actions()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(16)
        .background(
            role.color.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 14)
        )
    }

    private var scopeDisplayName: String {
        guard let path = model.snapshot?.scopePath.rawValue else {
            return localized("overview.title")
        }
        if path == "/" {
            return "/"
        }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    private var statusDescriptor: OverviewStatusDescriptor? {
        switch model.presentation {
        case .current:
            nil
        case .loading:
            OverviewStatusDescriptor(
                titleKey: "overview.status.loading",
                messageKey: "overview.status.loading.message",
                systemImage: "arrow.clockwise",
                role: .informational
            )
        case .scanInProgress:
            OverviewStatusDescriptor(
                titleKey: "overview.status.scanning",
                messageKey: "overview.status.scanning.message",
                systemImage: "progress.indicator",
                role: .informational
            )
        case .partial:
            OverviewStatusDescriptor(
                titleKey: "overview.status.partial",
                messageKey: "overview.status.partial.message",
                systemImage: "circle.lefthalf.filled",
                role: .limited
            )
        case .cancelled:
            OverviewStatusDescriptor(
                titleKey: "overview.status.cancelled",
                messageKey: "overview.status.cancelled.message",
                systemImage: "stop.circle",
                role: .neutral
            )
        case .limitedPermission:
            OverviewStatusDescriptor(
                titleKey: "overview.status.limited",
                messageKey: "overview.status.limited.message",
                systemImage: "lock.trianglebadge.exclamationmark",
                role: .limited
            )
        case .stale:
            OverviewStatusDescriptor(
                titleKey: "overview.status.stale",
                messageKey: "overview.status.stale.message",
                systemImage: "clock.arrow.circlepath",
                role: .limited
            )
        case .inconsistent:
            OverviewStatusDescriptor(
                titleKey: "overview.status.inconsistent",
                messageKey: "overview.status.inconsistent.message",
                systemImage: "exclamationmark.triangle",
                role: .limited
            )
        case .error:
            OverviewStatusDescriptor(
                titleKey: "overview.status.error",
                messageKey: "overview.status.error.message",
                systemImage: "exclamationmark.octagon",
                role: .failed
            )
        case .empty:
            nil
        }
    }

    private var primaryActionTitle: LocalizedStringKey {
        switch model.primaryAction {
        case .retryLatestSnapshot:
            "overview.action.retry"
        case .openScan:
            model.presentation == .scanInProgress
                ? "overview.action.viewScan"
                : model.presentation == .current
                ? "overview.action.quickScan"
                : "overview.action.scanAgain"
        case nil:
            "overview.action.quickScan"
        }
    }

    private func primaryAction() {
        switch model.primaryAction {
        case .openScan:
            openScan()
        case .retryLatestSnapshot:
            retryLatestSnapshot()
        case nil:
            break
        }
    }

    private func percent(_ value: Double?) -> String {
        guard let value else {
            return "—"
        }
        return value.formatted(
            .percent.precision(.fractionLength(0))
        )
    }

    private var pageBackground: Color {
#if DEBUG
        LaunchAppearanceOverride.backgroundColor
            ?? Color(nsColor: .windowBackgroundColor)
#else
        Color(nsColor: .windowBackgroundColor)
#endif
    }
}

private struct OverviewStatusDescriptor {
    let titleKey: String
    let messageKey: String
    let systemImage: String
    let role: SemanticStatusRole
}
