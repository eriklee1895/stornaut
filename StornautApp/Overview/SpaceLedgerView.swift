import StornautCore
import SwiftUI

struct SpaceLedgerView: View {
    let rows: [OverviewLedgerRow]
    let formatter: StornautByteFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("overview.ledger.title")
                    .font(.headline)
                Text("overview.ledger.subtitle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                HStack(spacing: 2) {
                    ForEach(measuredRows, id: \.kind) { row in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(OverviewPalette.color(for: row.kind))
                            .frame(
                                width: segmentWidth(
                                    for: row,
                                    available: proxy.size.width
                                )
                            )
                    }
                }
            }
            .frame(height: 12)
            .accessibilityHidden(true)

            VStack(spacing: 0) {
                ForEach(rows, id: \.kind) { row in
                    ledgerRow(row)
                    if row.kind != rows.last?.kind {
                        Divider()
                    }
                }
            }
            .background(
                .background.secondary,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
    }

    private var measuredRows: [OverviewLedgerRow] {
        rows.filter { ($0.bytes?.value ?? 0) > 0 }
    }

    private var totalBytes: Double {
        measuredRows.reduce(0.0) {
            $0 + Double($1.bytes?.value ?? 0)
        }
    }

    private func segmentWidth(
        for row: OverviewLedgerRow,
        available: CGFloat
    ) -> CGFloat {
        guard totalBytes > 0, let bytes = row.bytes else {
            return 0
        }
        let spacing = CGFloat(max(0, measuredRows.count - 1) * 2)
        return max(
            2,
            (available - spacing)
                * CGFloat(Double(bytes.value) / totalBytes)
        )
    }

    private func ledgerRow(
        _ row: OverviewLedgerRow
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(OverviewPalette.color(for: row.kind))
                .frame(width: 6, height: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(LocalizedStringKey(row.kind.localizationKey))
                        .fontWeight(.medium)
                    Text(LocalizedStringKey(row.status.localizationKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(metadata(for: row))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Text(formatter.string(for: row.bytes))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(LocalizedStringKey(row.kind.localizationKey))
        )
        .accessibilityValue(accessibilityValue(for: row))
    }

    private func metadata(for row: OverviewLedgerRow) -> String {
        var parts = row.sources.map { source in
            [
                localized("overview.source.\(source.kind.rawValue)"),
                source.identifier.rawValue,
                source.sampledAt.formatted(
                    date: .abbreviated,
                    time: .shortened
                ),
            ].joined(separator: " · ")
        }
        if row.coverageGapCount > 0 {
            parts.append(
                "\(localized("overview.ledger.coverageGaps")): "
                    + "\(row.coverageGapCount)"
            )
        }
        if row.includesUnmeasurable {
            parts.append(
                localized("overview.ledger.includesUnmeasurable")
            )
        }
        return parts.joined(separator: " · ")
    }

    private func accessibilityValue(
        for row: OverviewLedgerRow
    ) -> String {
        let value = formatter.accessibilityString(for: row.bytes)
        let status = localized(row.status.localizationKey)
        let metadata = metadata(for: row)
        return [value, status, metadata]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

extension OverviewLedgerKind {
    var localizationKey: String {
        "overview.ledger.\(rawValue)"
    }
}

extension AccountingMeasurementStatus {
    var localizationKey: String {
        "overview.measurement.\(rawValue)"
    }
}

func localized(_ key: String) -> String {
    String(localized: String.LocalizationValue(key))
}
