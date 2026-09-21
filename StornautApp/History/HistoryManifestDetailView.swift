import StornautCore
import SwiftUI

struct HistoryManifestDetailView: View {
    let record: HistoryManifestRecordModel
    let now: Date
    let requestExport: () -> Void
    let requestDelete: () -> Void

    private let byteFormatter = StornautByteFormatter()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                evidenceStatus
                accounting
                systemObservation
                actions
                lineage
                footer
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("history.manifest.detail")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("history.record.cleanupManifest")
                    .font(.title2.weight(.semibold))
                Text(record.manifestID.rawValue)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                HistoryManifestTerminalLabel(outcome: record.outcome)
                RetentionBadge(
                    model: RetentionBadgeModel(
                        expiresAt: record.expiresAt,
                        now: now
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var evidenceStatus: some View {
        if record.evidenceAvailability == .expired {
            Label(
                "history.manifest.evidenceExpired",
                systemImage: "clock.badge.exclamationmark"
            )
            .font(.callout.weight(.medium))
            .foregroundStyle(SemanticStatusRole.limited.color)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                SemanticStatusRole.limited.color.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .accessibilityIdentifier("history.manifest.evidenceExpired")
        }
    }

    private var accounting: some View {
        historySection("history.manifest.accounting") {
            metric(
                "history.manifest.selected",
                value: record.summary.selectedAllocatedBytes
            )
            metric(
                "history.manifest.processed",
                value: record.summary.processedAllocatedBytes
            )
            metric(
                "history.manifest.movedToTrash",
                value: record.summary.movedToTrashAllocatedBytes
            )
            metric(
                "history.manifest.permanentlyReleased",
                value: record.summary.permanentlyReleasedAllocatedBytes
            )
            Divider()
            fact(
                "history.manifest.succeeded",
                value: String(record.summary.succeededCount)
            )
            fact(
                "history.manifest.failed",
                value: String(record.summary.failedCount)
            )
            fact(
                "history.manifest.cancelled",
                value: String(record.summary.cancelledCount)
            )
            fact(
                "history.manifest.unknown",
                value: String(record.summary.unknownCount)
            )
        }
    }

    private var systemObservation: some View {
        historySection("history.manifest.systemObservation") {
            if let observation = record.systemObservation {
                fact(
                    "history.manifest.freeSpaceChanged",
                    value: CleanupResultFormatting.signedBytes(
                        observation.freeSpaceDelta
                    )
                )
                fact(
                    "history.manifest.unexplainedDelta",
                    value: observation.unexplainedDelta.map {
                        CleanupResultFormatting.signedBytes($0)
                    } ?? localized("history.manifest.unavailable")
                )
                Text("history.manifest.nonCausal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label(
                    "history.manifest.observationUnavailable",
                    systemImage: "minus.circle"
                )
                .foregroundStyle(.secondary)
            }
        }
    }

    private var actions: some View {
        historySection("history.manifest.actions") {
            ForEach(record.items) { item in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(
                            item.itemName
                                ?? item.planItemID.rawValue
                        )
                        .font(.callout.weight(.medium))
                        Spacer()
                        Text(
                            byteFormatter.string(
                                for: item.measures
                                    .movedToTrashAllocatedBytes
                            )
                        )
                        .monospacedDigit()
                    }
                    if let relativePath = item.relativePath {
                        Text(relativePath.rawValue)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    } else {
                        Text(item.actionID.rawValue)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    HStack(spacing: 12) {
                        Label(
                            localized(
                                "history.manifest.result."
                                    + item.result.rawValue
                            ),
                            systemImage: resultImage(item.result)
                        )
                        Text(
                            localized(
                                "history.manifest.recovery."
                                    + item.recovery.rawValue
                            )
                        )
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    if let error = item.error {
                        let descriptor = HistoryManifestFailureDescriptor(error)
                        Text(
                            localized(descriptor.stageKey)
                                + " · "
                                + localized(descriptor.failureKey)
                        )
                        .font(.caption)
                        .foregroundStyle(SemanticStatusRole.failed.color)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(
                    "history.manifest.action.\(item.actionID.rawValue)"
                )

                if item.id != record.items.last?.id {
                    Divider()
                }
            }
        }
    }

    private var lineage: some View {
        historySection("history.detail.related") {
            Label(
                "history.manifest.lineage",
                systemImage: "link"
            )
            Text(record.planID.rawValue)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("history.trend.nonCausal")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            Text("history.delete.filesUnaffected")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(
                "history.action.export",
                action: requestExport
            )
            .accessibilityIdentifier("history.action.export")
            Button(
                "history.action.delete",
                role: .destructive,
                action: requestDelete
            )
            .accessibilityIdentifier("history.action.delete")
        }
        .padding(.top, 4)
    }

    private func historySection<Content: View>(
        _ titleKey: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey(titleKey))
                .font(.headline)
            VStack(alignment: .leading, spacing: 9) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
    }

    private func metric(
        _ titleKey: String,
        value: ByteCount
    ) -> some View {
        fact(titleKey, value: byteFormatter.string(for: value))
    }

    private func fact(
        _ titleKey: String,
        value: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(LocalizedStringKey(titleKey))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func resultImage(_ result: ManifestActionResult) -> String {
        switch result {
        case .succeeded:
            "checkmark.circle"
        case .failed:
            "xmark.octagon"
        case .partiallyFailed:
            "exclamationmark.circle"
        case .cancelled:
            "stop.circle"
        case .outcomeUnknown:
            "questionmark.diamond"
        }
    }
}
