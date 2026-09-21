import StornautCore
import SwiftUI

struct CleanupAccountingDetails: View {
    let summary: CleanupManifestSummary
    let observation: ManifestSystemObservation?

    private let byteFormatter = StornautByteFormatter()

    var body: some View {
        DisclosureGroup("cleanup.result.accounting.title") {
            VStack(spacing: 0) {
                accountingRow(
                    "cleanup.result.accounting.selected",
                    logical: summary.selectedLogicalBytes,
                    allocated: summary.selectedAllocatedBytes
                )
                Divider()
                accountingRow(
                    "cleanup.result.accounting.processed",
                    logical: summary.processedLogicalBytes,
                    allocated: summary.processedAllocatedBytes
                )
                Divider()
                accountingRow(
                    "cleanup.result.accounting.trash",
                    logical: summary.movedToTrashLogicalBytes,
                    allocated: summary.movedToTrashAllocatedBytes
                )
                Divider()
                accountingRow(
                    "cleanup.result.accounting.permanent",
                    logical: summary.permanentlyReleasedLogicalBytes,
                    allocated:
                        summary.permanentlyReleasedAllocatedBytes
                )
                Divider()
                observationRow
            }
            .padding(.top, 10)
        }
        .padding(14)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityIdentifier("cleanup.result.accounting")
    }

    private func accountingRow(
        _ titleKey: String,
        logical: ByteCount,
        allocated: ByteCount
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(verbatim: localized(titleKey))
                .fontWeight(.medium)
            Spacer()
            value(
                "cleanup.result.accounting.logical",
                bytes: logical
            )
            value(
                "cleanup.result.accounting.allocated",
                bytes: allocated
            )
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var observationRow: some View {
        if let observation {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("cleanup.result.accounting.system")
                        .fontWeight(.medium)
                    Spacer()
                    Text(
                        CleanupResultFormatting.signedBytes(
                            observation.freeSpaceDelta,
                            formatter: byteFormatter
                        )
                    )
                    .monospacedDigit()
                }
                Text("cleanup.result.system.nonCausal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        } else {
            HStack {
                Text("cleanup.result.accounting.system")
                    .fontWeight(.medium)
                Spacer()
                Text("cleanup.result.system.unavailable")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
    }

    private func value(
        _ titleKey: String,
        bytes: ByteCount
    ) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(verbatim: localized(titleKey))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(byteFormatter.string(for: bytes))
                .monospacedDigit()
        }
        .frame(minWidth: 100, alignment: .trailing)
    }
}
