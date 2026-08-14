import StornautCore
import SwiftUI

private func historyLocalized(_ key: String) -> String {
    StornautLocalization.string(key)
}

struct HistoryNavigator: View {
    let groups: [HistoryDateGroup]
    let corruptRecords: [HistoryCorruptRecord]
    let now: Date
    @Binding var selection: HistoryRecordID?

    private let byteFormatter = StornautByteFormatter()

    var body: some View {
        List(selection: $selection) {
            ForEach(groups) { group in
                Section {
                    ForEach(group.items) { item in
                        switch item {
                        case let .quickScan(record):
                            HistoryNavigatorRow(
                                record: record,
                                byteFormatter: byteFormatter,
                                now: now
                            )
                            .tag(item.id)
                        case let .cleanupManifest(record):
                            HistoryManifestNavigatorRow(
                                record: record,
                                byteFormatter: byteFormatter,
                                now: now
                            )
                            .tag(item.id)
                        }
                    }
                } header: {
                    Text(
                        historyLocalized(
                            "history.group.\(group.kind.rawValue)"
                        )
                    )
                }
            }

            if !corruptRecords.isEmpty {
                Section("history.group.unreadable") {
                    ForEach(corruptRecords) { record in
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("history.corrupt.title")
                                    .font(.callout.weight(.medium))
                                Text(
                                    historyLocalized(
                                        "history.record."
                                            + record.source.rawValue
                                    )
                                )
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                Text(record.rawID)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier(
                            "history.corrupt.\(record.rawID)"
                        )
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("history.navigator")
    }
}

private struct HistoryNavigatorRow: View {
    let record: HistoryRecordModel
    let byteFormatter: StornautByteFormatter
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Label(
                    "history.record.quickScan",
                    systemImage: StornautSystemImage.quickScan
                )
                .font(.callout.weight(.medium))

                Spacer()

                HistoryTerminalLabel(state: record.terminalState)
            }

            Text(
                record.scopePath?.rawValue
                    ?? historyLocalized("history.scope.unavailable")
            )
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 8) {
                Text(
                    record.finishedAt,
                    format: .dateTime.hour().minute()
                )
                .monospacedDigit()

                if let known = record.ledgerRows.first(
                    where: { $0.kind == .known }
                )?.bytes {
                    HStack(spacing: 3) {
                        Text("history.ledger.known")
                        Text(byteFormatter.string(for: known))
                            .monospacedDigit()
                    }
                } else {
                    Text("—")
                        .accessibilityLabel("history.ledger.unavailable")
                }

                Spacer()

                HistoryRetentionLabel(
                    retention: record.retention
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(
            "history.record.\(record.sessionID.rawValue)"
        )
    }

    private var retentionText: String {
        HistoryRetentionLabel.text(for: record.retention)
    }
}

private struct HistoryManifestNavigatorRow: View {
    let record: HistoryManifestRecordModel
    let byteFormatter: StornautByteFormatter
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Label(
                    "history.record.cleanupManifest",
                    systemImage: "doc.text.magnifyingglass"
                )
                .font(.callout.weight(.medium))

                Spacer()

                HistoryManifestTerminalLabel(outcome: record.outcome)
            }

            Text(record.manifestID.rawValue)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 8) {
                Text(
                    record.createdAt,
                    format: .dateTime.hour().minute()
                )
                .monospacedDigit()

                HStack(spacing: 3) {
                    Text("history.manifest.movedToTrash")
                    Text(
                        byteFormatter.string(
                            for: record.summary
                                .movedToTrashAllocatedBytes
                        )
                    )
                    .monospacedDigit()
                }

                Spacer()

                HistoryRetentionLabel(retention: record.retention)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(
            "history.manifest.\(record.manifestID.rawValue)"
        )
        .accessibilityLabel("history.record.cleanupManifest")
        .accessibilityValue(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        [
            historyLocalized(
                HistoryManifestTerminalDescriptor(record.outcome)
                    .localizationKey
            ),
            historyLocalized("history.manifest.movedToTrash")
                + " "
                + byteFormatter.accessibilityString(
                    for: record.summary.movedToTrashAllocatedBytes
                ),
            HistoryRetentionLabel.text(for: record.retention),
        ].joined(separator: ", ")
    }
}

struct HistoryManifestTerminalLabel: View {
    let outcome: HistoryManifestOutcome

    var body: some View {
        let descriptor = HistoryManifestTerminalDescriptor(outcome)
        Label(
            LocalizedStringKey(descriptor.localizationKey),
            systemImage: descriptor.systemImage
        )
        .font(.caption.weight(.medium))
        .foregroundStyle(descriptor.role.color)
        .accessibilityLabel(
            Text(LocalizedStringKey(descriptor.localizationKey))
        )
    }
}

struct HistoryManifestTerminalDescriptor {
    let localizationKey: String
    let systemImage: String
    let role: SemanticStatusRole

    init(_ outcome: HistoryManifestOutcome) {
        switch outcome {
        case .completed:
            localizationKey = "history.manifest.status.completed"
            systemImage = "checkmark.circle"
            role = .positive
        case .completedWithIssues:
            localizationKey = "history.manifest.status.completedWithIssues"
            systemImage = "exclamationmark.circle"
            role = .limited
        case .stopped:
            localizationKey = "history.manifest.status.stopped"
            systemImage = "stop.circle"
            role = .neutral
        case .failed:
            localizationKey = "history.manifest.status.failed"
            systemImage = "xmark.octagon"
            role = .failed
        case .outcomeUnknown:
            localizationKey = "history.manifest.status.outcomeUnknown"
            systemImage = "questionmark.diamond"
            role = .limited
        }
    }
}

private struct HistoryRetentionLabel: View {
    let retention: HistoryRetention

    var body: some View {
        Label(
            Self.text(for: retention),
            systemImage: Self.image(for: retention)
        )
        .foregroundStyle(Self.color(for: retention))
    }

    static func text(for retention: HistoryRetention) -> String {
        switch retention.state {
        case .expired:
            return historyLocalized("retention.expired")
        case .expiringSoon, .retained:
            return String(
                format: historyLocalized(
                    "history.retention.daysRemaining"
                ),
                max(
                    1,
                    Int(ceil(retention.remaining / 86_400))
                )
            )
        }
    }

    static func image(for retention: HistoryRetention) -> String {
        switch retention.state {
        case .expired:
            return "clock.badge.xmark"
        case .expiringSoon:
            return "clock.badge.exclamationmark"
        case .retained:
            return "clock"
        }
    }

    static func color(for retention: HistoryRetention) -> Color {
        switch retention.state {
        case .expired:
            return .secondary
        case .expiringSoon:
            return .orange
        case .retained:
            return .secondary
        }
    }
}

struct HistoryTerminalLabel: View {
    let state: ScanTerminalState

    var body: some View {
        let descriptor = HistoryTerminalDescriptor(state)
        Label(
            LocalizedStringKey(descriptor.localizationKey),
            systemImage: descriptor.systemImage
        )
        .font(.caption.weight(.medium))
        .foregroundStyle(descriptor.role.color)
        .accessibilityLabel(
            Text(LocalizedStringKey(descriptor.localizationKey))
        )
    }
}

struct HistoryTerminalDescriptor {
    let localizationKey: String
    let systemImage: String
    let role: SemanticStatusRole

    init(_ state: ScanTerminalState) {
        switch state {
        case .completed:
            localizationKey = "history.status.completed"
            systemImage = "checkmark.circle"
            role = .positive
        case .partial:
            localizationKey = "history.status.partial"
            systemImage = "circle.lefthalf.filled"
            role = .limited
        case .cancelled:
            localizationKey = "history.status.cancelled"
            systemImage = "stop.circle"
            role = .neutral
        case .failed:
            localizationKey = "history.status.failed"
            systemImage = "xmark.octagon"
            role = .failed
        }
    }
}
