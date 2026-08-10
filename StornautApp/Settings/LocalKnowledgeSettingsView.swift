import StornautCore
import SwiftUI

struct LocalKnowledgeSettingsView: View {
    let model: LocalKnowledgeSettingsModel
    @Binding var selection: LocalKnowledgeID?
    let requestForget: () -> Void
    let requestForgetAll: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                SettingsPageHeader(
                    titleKey: "settings.section.knowledge",
                    messageKey: "settings.knowledge.subtitle",
                    systemImage: "brain.head.profile"
                )

                Section("settings.knowledge.records") {
                    if model.records.isEmpty {
                        ContentUnavailableView(
                            "settings.knowledge.empty",
                            systemImage: "brain.head.profile",
                            description: Text(
                                "settings.knowledge.empty.message"
                            )
                        )
                    } else {
                        List(model.records, selection: $selection) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Label(
                                        LocalizedStringKey(
                                            "settings.knowledge.kind."
                                                + record.fact.kind.rawValue
                                        ),
                                        systemImage: knowledgeImage(
                                            record.fact.kind
                                        )
                                    )
                                    .font(.callout.weight(.medium))
                                    Spacer()
                                    Text(
                                        LocalizedStringKey(
                                            "settings.knowledge.status."
                                                + record.status.rawValue
                                        )
                                    )
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(
                                        record.status == .stale
                                            ? .orange
                                            : .secondary
                                    )
                                }
                                Text(record.fact.scope.rawValue)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(
                                    record.fact.updatedAt,
                                    format: .dateTime
                                        .year().month().day().hour().minute()
                                )
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            }
                            .tag(record.id)
                            .padding(.vertical, 4)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier(
                                "settings.knowledge.\(record.id.rawValue)"
                            )
                        }
                        .frame(minHeight: 180)
                    }

                    ForEach(model.corruptRecordIDs, id: \.self) { rawID in
                        Label {
                            Text(
                                String(
                                    format: localized(
                                        "settings.knowledge.corrupt"
                                    ),
                                    rawID
                                )
                            )
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                        .accessibilityIdentifier(
                            "settings.knowledge.corrupt.\(rawID)"
                        )
                    }
                }

                if let selected = selectedRecord {
                    Section("settings.knowledge.review") {
                        LabeledContent("settings.knowledge.scope") {
                            Text(selected.fact.scope.rawValue)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("settings.knowledge.provenance") {
                            Text("settings.knowledge.userConfirmed")
                        }
                        LabeledContent("settings.knowledge.status") {
                            Text(
                                LocalizedStringKey(
                                    "settings.knowledge.status."
                                        + selected.status.rawValue
                                )
                            )
                        }
                    }
                }

                Section {
                    HStack {
                        Button(
                            "settings.action.forget",
                            role: .destructive,
                            action: requestForget
                        )
                        .disabled(selectedRecord == nil)
                        .accessibilityIdentifier(
                            "settings.action.forgetKnowledge"
                        )
                        Spacer()
                        Button(
                            "settings.action.forgetAll",
                            role: .destructive,
                            action: requestForgetAll
                        )
                        .disabled(
                            model.records.isEmpty
                                && model.corruptRecordIDs.isEmpty
                        )
                        .accessibilityIdentifier(
                            "settings.action.forgetAllKnowledge"
                        )
                    }
                    Text("settings.knowledge.policy.message")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .background {
            SettingsPageProbe(
                identifier: "settings.page.localKnowledge"
            )
            .allowsHitTesting(false)
        }
    }

    private var selectedRecord: SettingsKnowledgeRecord? {
        selection.flatMap { id in
            model.records.first { $0.id == id }
        }
    }

    private func knowledgeImage(_ kind: LocalKnowledgeKind) -> String {
        switch kind {
        case .producerMapping:
            "shippingbox"
        case .pathPreference:
            "folder.badge.gearshape"
        case .keepDecision:
            "hand.raised"
        case .recoveryMethod:
            "arrow.trianglehead.2.clockwise.rotate.90"
        }
    }
}
