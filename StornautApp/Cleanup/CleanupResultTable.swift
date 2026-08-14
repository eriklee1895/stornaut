import StornautCore
import SwiftUI

struct CleanupResultTable: View {
    let rows: [CleanupResultRow]

    private let byteFormatter = StornautByteFormatter()

    var body: some View {
        Table(rows) {
            TableColumn("cleanup.result.column.item") { row in
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        row.itemName
                            ?? localized(
                                "cleanup.result.item.evidenceExpired"
                            )
                    )
                        .fontWeight(.medium)
                    if let path = row.exactOriginalPath {
                        Text(path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("cleanup.result.evidence.expired")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    Text(
                        row.itemName
                            ?? localized(
                                "cleanup.result.item.evidenceExpired"
                            )
                    )
                )
                .accessibilityIdentifier(
                    "cleanup.result.row.item.\(row.actionID.rawValue)"
                )
            }
            .width(min: 180, ideal: 220, max: 260)

            TableColumn("cleanup.result.column.action") { row in
                Label(
                    "review.action.moveToTrash",
                    systemImage: "trash"
                )
            }
            .width(min: 85, ideal: 95, max: 105)

            TableColumn("cleanup.result.column.result") { row in
                let resultLabel = localizedResult(row.result)
                Label(
                    title: { Text(verbatim: resultLabel) },
                    icon: {
                        Image(systemName: resultImage(row.result))
                    }
                )
                .foregroundStyle(resultRole(row.result).color)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: resultLabel))
                .accessibilityIdentifier(
                    "cleanup.result.row.status.\(row.actionID.rawValue)"
                )
            }
            .width(min: 100, ideal: 115, max: 130)

            TableColumn("cleanup.result.column.size") { row in
                Text(
                    byteFormatter.string(
                        for: row.measures.movedToTrashAllocatedBytes
                            .value > 0
                            ? row.measures.movedToTrashAllocatedBytes
                            : row.measures.candidateAllocatedBytes
                    )
                )
                .monospacedDigit()
            }
            .width(min: 65, ideal: 75, max: 85)

            TableColumn("cleanup.result.column.recovery") { row in
                let recoveryLabel = localizedRecovery(
                    row.recoveryPresentation
                )
                Label(
                    title: { Text(verbatim: recoveryLabel) },
                    icon: {
                        Image(
                            systemName: recoveryImage(
                                row.recoveryPresentation
                            )
                        )
                    }
                )
                .foregroundStyle(
                    recoveryRole(row.recoveryPresentation).color
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    Text(verbatim: recoveryLabel)
                )
                .accessibilityIdentifier(
                    "cleanup.result.row.recovery."
                        + row.actionID.rawValue
                )
            }
            .width(min: 115, ideal: 135, max: 165)
        }
        .frame(minHeight: 180)
        .accessibilityIdentifier("cleanup.result.table")
    }

    private func resultImage(_ result: ManifestActionResult) -> String {
        switch result {
        case .succeeded:
            "checkmark.circle"
        case .failed, .partiallyFailed:
            "xmark.octagon"
        case .cancelled:
            "stop.circle"
        case .outcomeUnknown:
            "questionmark.diamond"
        }
    }

    private func localizedResult(
        _ result: ManifestActionResult
    ) -> String {
        switch result {
        case .succeeded:
            localized("cleanup.result.row.result.succeeded")
        case .failed:
            localized("cleanup.result.row.result.failed")
        case .partiallyFailed:
            localized("cleanup.result.row.result.partiallyFailed")
        case .cancelled:
            localized("cleanup.result.row.result.cancelled")
        case .outcomeUnknown:
            localized("cleanup.result.row.result.outcomeUnknown")
        }
    }

    private func resultRole(
        _ result: ManifestActionResult
    ) -> SemanticStatusRole {
        switch result {
        case .succeeded:
            .positive
        case .failed, .partiallyFailed:
            .failed
        case .cancelled, .outcomeUnknown:
            .limited
        }
    }

    private func recoveryImage(
        _ recovery: CleanupRecoveryPresentation
    ) -> String {
        switch recovery {
        case .recoverableFromTrash:
            "arrow.uturn.backward.circle"
        case .originalRemains, .notStarted:
            "doc.badge.checkmark"
        case .outcomeUnknown:
            "questionmark.folder"
        }
    }

    private func localizedRecovery(
        _ recovery: CleanupRecoveryPresentation
    ) -> String {
        switch recovery {
        case .recoverableFromTrash:
            localized("cleanup.result.recovery.recoverableFromTrash")
        case .originalRemains:
            localized("cleanup.result.recovery.originalRemains")
        case .notStarted:
            localized("cleanup.result.recovery.notStarted")
        case .outcomeUnknown:
            localized("cleanup.result.recovery.outcomeUnknown")
        }
    }

    private func recoveryRole(
        _ recovery: CleanupRecoveryPresentation
    ) -> SemanticStatusRole {
        switch recovery {
        case .recoverableFromTrash:
            .positive
        case .originalRemains, .notStarted:
            .neutral
        case .outcomeUnknown:
            .limited
        }
    }
}
