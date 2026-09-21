import StornautCore
import SwiftUI

struct ReviewInspector: View {
    let model: ReviewInspectorModel
    let close: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("review.inspector.title")
                        .font(.title2.weight(.semibold))
                        .accessibilityIdentifier("review.inspector")
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("review.inspector.close")
                }

                section("review.inspector.item") {
                    Text(model.itemName)
                        .font(.headline)
                    ReclaimDispositionLabel(
                        disposition: model.disposition
                    )
                    Label(
                        model.isSelected
                            ? "review.selection.selected"
                            : "review.selection.notSelected",
                        systemImage: model.isSelected
                            ? "checkmark.square"
                            : "square"
                    )
                    .foregroundStyle(.secondary)
                }

                section("review.inspector.why") {
                    ForEach(model.reasonKeys, id: \.rawValue) { reason in
                        Label(
                            LocalizedStringKey(reason.rawValue),
                            systemImage: "checkmark.seal"
                        )
                    }
                }

                section("review.inspector.activity") {
                    detailRow(
                        "review.column.lastActive",
                        value: model.modifiedAt.map {
                            $0.formatted(
                                .dateTime.year().month().day()
                                    .hour().minute()
                            )
                        } ?? localized("review.value.unavailable")
                    )
                    detailRow(
                        "scan.results.producer",
                        value: model.producer?.rawValue
                            ?? localized(
                                "scan.results.producerUnknown"
                            )
                    )
                }

                section("review.inspector.recovery") {
                    detailRow(
                        "review.column.recovery",
                        valueKey: model.recoveryCost?.scanLocalizationKey
                            ?? "review.value.unavailable"
                    )
                }

                section("review.inspector.evidence") {
                    if model.supportingEvidence.isEmpty {
                        Text("review.inspector.noEvidence")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.supportingEvidence, id: \.id) {
                            evidence in
                            Label(
                                LocalizedStringKey(
                                    supportingEvidenceKey(
                                        evidence.summaryKey
                                    )
                                ),
                                systemImage: "checkmark.circle"
                            )
                        }
                    }
                    ForEach(model.missingEvidence, id: \.rawValue) { key in
                        Label(
                            LocalizedStringKey(missingEvidenceKey(key)),
                            systemImage: "questionmark.circle"
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                section("review.inspector.exactPath") {
                    Text(model.exactPath)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Label(
                    "review.inspector.readOnly",
                    systemImage: "lock.shield"
                )
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("review.inspector.readOnly")
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    .background.secondary,
                    in: RoundedRectangle(cornerRadius: 10)
                )
            }
            .padding(20)
        }
        .inspectorColumnWidth(min: 300, ideal: 350, max: 420)
    }

    private func section<Content: View>(
        _ key: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(key))
                .font(.headline)
            content()
        }
    }

    private func missingEvidenceKey(_ key: DomainToken) -> String {
        switch key.rawValue {
        case "activity.process.inactive":
            "review.inspector.missing.activity.process.inactive"
        case "activity.git.clean":
            "review.inspector.missing.activity.git.clean"
        case "activity.git.upstream-synced":
            "review.inspector.missing.activity.git.upstream-synced"
        default:
            "review.inspector.missing.unknown"
        }
    }

    private func supportingEvidenceKey(_ key: DomainToken) -> String {
        switch key.rawValue {
        case "activity.process.inactive":
            "review.inspector.supporting.activity.process.inactive"
        case "activity.process.related-running":
            "review.inspector.supporting.activity.process.related-running"
        case "activity.git.clean":
            "review.inspector.supporting.activity.git.clean"
        case "activity.git.changed":
            "review.inspector.supporting.activity.git.changed"
        case "activity.git.upstream-synced":
            "review.inspector.supporting.activity.git.upstream-synced"
        case "activity.git.upstream-not-synced":
            "review.inspector.supporting.activity.git.upstream-not-synced"
        case "quick-scan.activity.provider-failure":
            "review.inspector.supporting.activity.provider-failure"
        default:
            "review.inspector.supporting.unknown"
        }
    }

    private func detailRow(
        _ key: String,
        value: String? = nil,
        valueKey: String? = nil
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(LocalizedStringKey(key))
                .foregroundStyle(.secondary)
            Spacer()
            if let valueKey {
                Text(LocalizedStringKey(valueKey))
            } else {
                Text(value ?? "—")
            }
        }
        .accessibilityElement(children: .combine)
    }
}
