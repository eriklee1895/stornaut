import StornautCore
import SwiftUI

struct ScanResultsTable: View {
    let groups: [ScanResultGroup]
    @Binding var selection: SnapshotID?

    private let byteFormatter = StornautByteFormatter()

    var body: some View {
        Table(of: ScanResultRow.self, selection: $selection) {
            TableColumn("scan.results.item") { row in
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.itemName)
                        .fontWeight(.medium)
                    Text(row.relativePath.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(
                    "scan.row.\(row.id.rawValue)"
                )
            }
            .width(min: 220, ideal: 320, max: 440)

            TableColumn("scan.results.lastActive") { row in
                if let modifiedAt = row.modifiedAt {
                    Text(
                        modifiedAt,
                        format: .dateTime.year().month().day()
                    )
                    .help("scan.results.lastActive.help")
                } else {
                    missingValue(reasonKey: "scan.activity.unknown")
                }
            }
            .width(min: 100, ideal: 118, max: 150)

            TableColumn("scan.results.producer") { row in
                Text(
                    row.producer?.rawValue
                        ?? scanLocalized("scan.results.producerUnknown")
                )
                .lineLimit(1)
            }
            .width(min: 100, ideal: 132, max: 180)

            TableColumn("scan.results.recovery") { row in
                if let cost = row.recoveryCost {
                    Label(
                        LocalizedStringKey(cost.scanLocalizationKey),
                        systemImage: "arrow.clockwise"
                    )
                    .lineLimit(1)
                } else {
                    missingValue(reasonKey: "scan.recovery.unavailable")
                }
            }
            .width(min: 110, ideal: 136, max: 180)

            TableColumn("scan.results.allocated") { row in
                if let bytes = row.allocatedBytes {
                    Text(byteFormatter.string(for: bytes))
                        .monospacedDigit()
                        .accessibilityLabel(
                            byteFormatter.accessibilityString(for: bytes)
                        )
                } else {
                    missingValue(
                        reasonKey: row.measurementReasonKey
                            ?? "scan.measurement.unavailable"
                    )
                }
            }
            .width(min: 100, ideal: 116, max: 140)

            TableColumn("scan.results.disposition") { row in
                ReclaimDispositionLabel(disposition: row.disposition)
                    .lineLimit(1)
            }
            .width(min: 130, ideal: 154, max: 190)
        } rows: {
            ForEach(groups) { group in
                Section {
                    ForEach(group.rows) { row in
                        TableRow(row)
                    }
                } header: {
                    HStack {
                        Label(
                            LocalizedStringKey(
                                group.category.overviewLocalizationKey
                            ),
                            systemImage: group.category.systemImage
                        )
                        Spacer()
                        Text(group.rows.count, format: .number)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier(
                        "scan.group.\(group.category.rawValue)"
                    )
                }
            }
        }
        .accessibilityIdentifier("scan.results.table")
    }

    private func missingValue(reasonKey: String) -> some View {
        Text("—")
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text(LocalizedStringKey(reasonKey)))
            .help(LocalizedStringKey(reasonKey))
    }
}

extension RebuildCost {
    var scanLocalizationKey: String {
        "scan.recovery.\(rawValue)"
    }
}

private func scanLocalized(_ key: String) -> String {
    localized(key)
}
