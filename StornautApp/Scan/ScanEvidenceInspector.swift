import StornautCore
import SwiftUI

struct ScanEvidenceInspector: View {
    let model: ScanEvidenceInspectorModel
    let close: () -> Void

    private let byteFormatter = StornautByteFormatter()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("scan.inspector.title")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("scan.inspector.close")
                }

                inspectorSection("scan.inspector.classification") {
                    detailRow(
                        "scan.results.producer",
                        value: model.producer?.rawValue
                            ?? localized(
                                "scan.results.producerUnknown"
                            )
                    )
                    detailRow(
                        "scan.inspector.lifecycle",
                        valueKey: model.category.overviewLocalizationKey
                    )
                    HStack {
                        Text("scan.results.disposition")
                            .foregroundStyle(.secondary)
                        Spacer()
                        ReclaimDispositionLabel(
                            disposition: model.disposition
                        )
                    }
                }

                inspectorSection("scan.inspector.exactPath") {
                    Text(model.exactPath.rawValue)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(model.relativePath.rawValue)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                inspectorSection("scan.inspector.measurement") {
                    detailRow(
                        "scan.results.allocated",
                        value: byteFormatter.string(
                            for: model.allocatedBytes
                        ),
                        accessibilityValue:
                            byteFormatter.accessibilityString(
                                for: model.allocatedBytes
                            )
                    )
                    detailRow(
                        "scan.results.lastActive",
                        value: model.modifiedAt.map {
                            $0.formatted(
                                .dateTime.year().month().day()
                                    .hour().minute()
                            )
                        } ?? "—"
                    )
                    detailRow(
                        "scan.results.recovery",
                        valueKey: model.recoveryCost?
                            .scanLocalizationKey
                            ?? "scan.recovery.unavailable"
                    )
                    if let recoveryMethodKey = model.recoveryMethodKey {
                        detailRow(
                            "scan.inspector.recoveryMethod",
                            value: recoveryMethodKey.rawValue
                        )
                    }
                }

                inspectorSection(
                    "scan.inspector.supportingEvidence"
                ) {
                    if model.supportingEvidence.isEmpty {
                        Text("scan.inspector.noEvidence")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.supportingEvidence, id: \.id) {
                            evidence in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(evidence.summaryKey.rawValue)
                                    Text(
                                        "\(evidence.source.kind.rawValue) · "
                                            + evidence.freshness.rawValue
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "checkmark.seal")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                inspectorSection("scan.inspector.missingEvidence") {
                    if model.missingEvidence.isEmpty {
                        Label(
                            "scan.inspector.noneMissing",
                            systemImage: "checkmark.circle"
                        )
                        .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.missingEvidence, id: \.rawValue) {
                            key in
                            Label(
                                key.rawValue,
                                systemImage: "questionmark.circle"
                            )
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Label {
                    Text("scan.deepDive.paused")
                } icon: {
                    Image(systemName: "lock.shield")
                }
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    .background.secondary,
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .accessibilityIdentifier("scan.inspector.deepDivePaused")
            }
            .padding(20)
        }
        .inspectorColumnWidth(min: 280, ideal: 330, max: 420)
        .accessibilityIdentifier("scan.inspector")
    }

    private func inspectorSection<Content: View>(
        _ titleKey: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(titleKey))
                .font(.headline)
            content()
        }
    }

    private func detailRow(
        _ titleKey: String,
        value: String? = nil,
        valueKey: String? = nil,
        accessibilityValue: String? = nil
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(LocalizedStringKey(titleKey))
                .foregroundStyle(.secondary)
            Spacer()
            if let valueKey {
                Text(LocalizedStringKey(valueKey))
                    .multilineTextAlignment(.trailing)
            } else {
                Text(value ?? "—")
                    .multilineTextAlignment(.trailing)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityValue ?? value ?? "")
    }
}
