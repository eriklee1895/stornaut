import StornautCore
import SwiftUI

struct HistoryDetailView: View {
    let record: HistoryRecordModel
    let now: Date
    let requestExport: () -> Void
    let requestDelete: () -> Void

    private let byteFormatter = StornautByteFormatter()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                sessionFacts
                ledger
                lineage
                footer
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("history.detail")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("history.record.quickScan")
                    .font(.title2.weight(.semibold))
                Text(
                    record.scopePath?.rawValue
                        ?? localized("history.scope.unavailable")
                )
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                HistoryTerminalLabel(state: record.terminalState)
                RetentionBadge(
                    model: RetentionBadgeModel(
                        expiresAt: record.expiresAt,
                        now: now
                    )
                )
            }
        }
    }

    private var sessionFacts: some View {
        historySection("history.detail.session") {
            fact(
                "history.detail.started",
                value: record.startedAt.formatted(
                    .dateTime.year().month().day().hour().minute().second()
                )
            )
            fact(
                "history.detail.finished",
                value: record.finishedAt.formatted(
                    .dateTime.year().month().day().hour().minute().second()
                )
            )
            fact(
                "history.detail.duration",
                value: Duration.seconds(record.duration).formatted(
                    .time(pattern: .minuteSecond)
                )
            )
            fact(
                "history.detail.coverage",
                valueKey: "history.coverage.\(record.coverage.rawValue)"
            )
            if let unfinishedReason = record.unfinishedReason {
                fact(
                    "history.detail.unfinishedReason",
                    valueKey:
                        "history.unfinished.\(unfinishedReason.rawValue)"
                )
            }
            fact(
                "history.detail.expires",
                value: record.expiresAt.formatted(
                    .dateTime.year().month().day().hour().minute()
                )
            )
        }
    }

    @ViewBuilder
    private var ledger: some View {
        historySection("history.detail.ledger") {
            switch record.ledgerStatus {
            case .available:
                ForEach(record.ledgerRows, id: \.kind) { row in
                    let title = localized(
                        "history.ledger.\(row.kind.rawValue)"
                    )
                    HStack {
                        Text(title)
                        Spacer()
                        Text(byteFormatter.string(for: row.bytes))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(title)
                    .accessibilityValue(
                        byteFormatter.accessibilityString(for: row.bytes)
                    )
                    .accessibilityIdentifier(
                        "history.ledger.metric.\(row.kind.rawValue)"
                    )
                }
                if let capacity = record.volumeCapacity {
                    Divider()
                    fact(
                        "history.ledger.capacity",
                        value: byteFormatter.string(for: capacity)
                    )
                }
                ForEach(
                    Array(record.volumeSources.enumerated()),
                    id: \.offset
                ) { _, source in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            localized(
                                "history.source.\(source.kind.rawValue)"
                            )
                                + " · "
                                + source.identifier.rawValue
                        )
                        Text(
                            source.sampledAt,
                            format: .dateTime
                                .year().month().day().hour().minute().second()
                        )
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                }
                if !record.caveats.isEmpty {
                    Divider()
                    ForEach(record.caveats, id: \.rawValue) { caveat in
                        Label(
                            localized(
                                "history.caveat.\(caveat.rawValue)"
                            ),
                            systemImage: "info.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            case .unavailable:
                unavailableLedger("history.ledger.unavailable")
            case .corrupt:
                unavailableLedger("history.ledger.corrupt")
            }
        }
    }

    private var lineage: some View {
        historySection("history.detail.related") {
            Label(
                "history.detail.lineage",
                systemImage: "link"
            )
            .font(.callout)
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

    private func fact(
        _ titleKey: String,
        value: String? = nil,
        valueKey: String? = nil
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(LocalizedStringKey(titleKey))
                .foregroundStyle(.secondary)
            Spacer()
            if let valueKey {
                Text(LocalizedStringKey(valueKey))
            } else {
                Text(value ?? "—")
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func unavailableLedger(
        _ key: String
    ) -> some View {
        Label(
            LocalizedStringKey(key),
            systemImage: "exclamationmark.triangle"
        )
        .foregroundStyle(.orange)
    }
}
