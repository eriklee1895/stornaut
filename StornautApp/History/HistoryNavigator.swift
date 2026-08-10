import StornautCore
import SwiftUI

private func historyLocalized(_ key: String) -> String {
    String(localized: String.LocalizationValue(key))
}

struct HistoryNavigator: View {
    let groups: [HistoryDateGroup]
    let corruptRecords: [HistoryCorruptRecord]
    let now: Date
    @Binding var selection: ScanSessionID?

    private let byteFormatter = StornautByteFormatter()

    var body: some View {
        List(selection: $selection) {
            ForEach(groups) { group in
                Section {
                    ForEach(group.records) { record in
                        HistoryNavigatorRow(
                            record: record,
                            byteFormatter: byteFormatter,
                            now: now
                        )
                        .tag(record.id)
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
                    systemImage: "externaldrive.badge.magnifyingglass"
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

                Label(
                    retentionText,
                    systemImage: retentionImage
                )
                .foregroundStyle(retentionColor)
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
        switch record.retention.state {
        case .expired:
            historyLocalized("retention.expired")
        case .expiringSoon, .retained:
            String(
                format: historyLocalized(
                    "history.retention.daysRemaining"
                ),
                max(
                    1,
                    Int(ceil(record.retention.remaining / 86_400))
                )
            )
        }
    }

    private var retentionImage: String {
        switch record.retention.state {
        case .expired:
            "clock.badge.xmark"
        case .expiringSoon:
            "clock.badge.exclamationmark"
        case .retained:
            "clock"
        }
    }

    private var retentionColor: Color {
        switch record.retention.state {
        case .expired:
            .secondary
        case .expiringSoon:
            .orange
        case .retained:
            .secondary
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
