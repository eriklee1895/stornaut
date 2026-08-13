import StornautCore
import SwiftUI

struct ReviewTable: View {
    let groups: [ReviewGroup]
    @Binding var focus: ClassificationID?
    let compactColumns: Bool
    let setSelection: (ClassificationID, Bool) -> Void

    private let byteFormatter = StornautByteFormatter()

    var body: some View {
        Table(of: ReviewRow.self, selection: $focus) {
            TableColumn("review.column.item") { row in
                ReviewItemCell(
                    row: row,
                    setSelection: setSelection
                )
            }
            .width(
                min: compactColumns ? 160 : 230,
                ideal: compactColumns ? 190 : 330,
                max: compactColumns ? 220 : 440
            )

            TableColumn("review.column.lastActive") { row in
                if let modifiedAt = row.modifiedAt {
                    Text(
                        modifiedAt,
                        format: .dateTime.year().month().day()
                    )
                } else {
                    missingValue("review.value.unavailable")
                }
            }
            .width(
                min: compactColumns ? 76 : 100,
                ideal: compactColumns ? 86 : 120,
                max: compactColumns ? 96 : 150
            )

            TableColumn("review.column.recovery") { row in
                if let recoveryCost = row.recoveryCost {
                    Label(
                        LocalizedStringKey(
                            recoveryCost.scanLocalizationKey
                        ),
                        systemImage: "arrow.clockwise"
                    )
                    .lineLimit(1)
                } else {
                    missingValue("review.value.unavailable")
                }
            }
            .width(
                min: compactColumns ? 82 : 110,
                ideal: compactColumns ? 92 : 135,
                max: compactColumns ? 102 : 175
            )

            TableColumn("review.column.action") { row in
                if row.action == .moveToTrash {
                    Label(
                        "review.action.moveToTrash",
                        systemImage: "trash"
                    )
                } else {
                    missingValue(
                        row.disabledReasonKey
                            ?? "review.value.notApplicable"
                    )
                }
            }
            .width(
                min: compactColumns ? 88 : 110,
                ideal: compactColumns ? 98 : 138,
                max: compactColumns ? 108 : 175
            )

            TableColumn("review.column.size") { row in
                if let allocatedBytes = row.allocatedBytes {
                    Text(byteFormatter.string(for: allocatedBytes))
                        .monospacedDigit()
                        .accessibilityLabel(
                            byteFormatter.accessibilityString(
                                for: allocatedBytes
                            )
                        )
                } else {
                    missingValue("review.value.unmeasurable")
                }
            }
            .width(
                min: compactColumns ? 66 : 90,
                ideal: compactColumns ? 76 : 110,
                max: compactColumns ? 86 : 140
            )
        } rows: {
            ForEach(groups) { group in
                Section {
                    ForEach(group.rows) { row in
                        TableRow(row)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(LocalizedStringKey(group.kind.titleKey))
                                .fontWeight(.semibold)
                            Spacer()
                            Text(group.rows.count, format: .number)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Text(LocalizedStringKey(group.kind.helpKey))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(
                        "review.group.\(group.kind.rawValue)"
                    )
                }
            }
        }
        .accessibilityIdentifier("review.table")
    }

    private func missingValue(_ reasonKey: String) -> some View {
        Text("—")
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text(LocalizedStringKey(reasonKey)))
            .help(LocalizedStringKey(reasonKey))
    }
}

private struct ReviewItemCell: View {
    let row: ReviewRow
    let setSelection: (ClassificationID, Bool) -> Void

    private var selectionLabel: String {
        let state = localized(
            row.isSelected
                ? "review.selection.selected"
                : "review.selection.notSelected"
        )
        return "\(row.itemName), \(state)"
    }

    private var selectionHelp: LocalizedStringKey {
        LocalizedStringKey(
            row.disabledReasonKey
                ?? "review.selection.available"
        )
    }

    private var selectionHint: LocalizedStringKey {
        LocalizedStringKey(
            row.disabledReasonKey
                ?? "review.selection.toggleHint"
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            Toggle(
                "",
                isOn: Binding(
                    get: { row.isSelected },
                    set: {
                        setSelection(row.classificationID, $0)
                    }
                )
            )
            .labelsHidden()
            .disabled(!row.isSelectionEnabled)
            .help(selectionHelp)
            .accessibilityLabel(selectionLabel)
            .accessibilityAddTraits(
                row.isSelected ? .isSelected : []
            )
            .accessibilityHint(selectionHint)
            .accessibilityIdentifier(
                "review.selection.\(row.classificationID.rawValue)"
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(row.itemName)
                    .fontWeight(.medium)
                Text(row.relativePath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(
                "review.row.\(row.classificationID.rawValue)"
            )
        }
    }
}
