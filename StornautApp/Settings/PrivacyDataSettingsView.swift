import SwiftUI

enum SettingsConfirmation: String, Identifiable {
    case clearEvidence
    case clearManifests
    case forgetKnowledge
    case forgetAllKnowledge

    var id: String { rawValue }
}

struct PrivacyDataSettingsView: View {
    let model: PrivacySettingsModel
    let requestConfirmation: (SettingsConfirmation) -> Void

    var body: some View {
        Form {
            SettingsPageHeader(
                titleKey: "settings.section.privacy",
                messageKey: "settings.privacy.subtitle",
                systemImage: "hand.raised"
            )

            Section("settings.privacy.retention") {
                SettingsPolicyRow(
                    titleKey: "settings.privacy.evidence",
                    value: String(
                        format: localized("settings.value.days"),
                        model.evidenceRetentionDays
                    ),
                    messageKey: "settings.privacy.evidence.message",
                    systemImage: "clock.arrow.circlepath"
                )
                SettingsPolicyRow(
                    titleKey: "settings.privacy.manifests",
                    value: String(
                        format: localized("settings.value.days"),
                        model.manifestRetentionDays
                    ),
                    messageKey: "settings.privacy.manifests.message",
                    systemImage: "doc.text"
                )
                SettingsPolicyRow(
                    titleKey: "settings.privacy.jsonl",
                    value: localized("settings.value.notPersisted"),
                    messageKey: "settings.privacy.jsonl.message",
                    systemImage: "memorychip"
                )
            }

            Section("settings.privacy.localRecords") {
                LabeledContent("settings.privacy.evidenceCount") {
                    Text(model.evidenceCount, format: .number)
                        .monospacedDigit()
                }
                LabeledContent("settings.privacy.manifestCount") {
                    Text(model.manifestCount, format: .number)
                        .monospacedDigit()
                }
            }

            Section("settings.privacy.clear") {
                Button(
                    "settings.action.clearEvidence",
                    role: .destructive
                ) {
                    requestConfirmation(.clearEvidence)
                }
                .disabled(model.evidenceCount == 0)
                .accessibilityIdentifier("settings.action.clearEvidence")

                Button(
                    "settings.action.clearManifests",
                    role: .destructive
                ) {
                    requestConfirmation(.clearManifests)
                }
                .disabled(model.manifestCount == 0)
                .accessibilityIdentifier("settings.action.clearManifests")

                Text("settings.privacy.clear.message")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .background {
            SettingsPageProbe(
                identifier: "settings.page.privacyAndData"
            )
            .allowsHitTesting(false)
        }
    }
}
