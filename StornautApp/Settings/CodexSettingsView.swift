import StornautCore
import SwiftUI

struct CodexSettingsView: View {
    let model: CodexSettingsModel
    let preferences: SettingsPreferences
    let updatePreferences: (SettingsPreferences) -> Void
    let checkAgain: () -> Void

    var body: some View {
        Form {
            SettingsPageHeader(
                titleKey: "settings.section.codex",
                messageKey: "settings.codex.subtitle",
                systemImage: "scope"
            )

            Section("settings.codex.runtime") {
                SettingsStatusRow(
                    titleKey: "settings.codex.evidence",
                    valueKey:
                        "settings.status.evidence."
                        + model.runtimeEvidence.status.rawValue,
                    messageKey: evidenceMessageKey,
                    systemImage: "checkmark.seal",
                    role: evidenceRole,
                    identifier: "settings.codex.evidence"
                )
                SettingsStatusRow(
                    titleKey: "settings.codex.runtimeGate",
                    valueKey:
                        "settings.status.runtimeGate."
                        + model.runtimeGate.rawValue,
                    messageKey: runtimeGateMessageKey,
                    systemImage: "lock.shield",
                    role: runtimeGateRole,
                    identifier: "settings.codex.runtimeGate"
                )
                SettingsStatusRow(
                    titleKey: "settings.codex.deepDiveAvailability",
                    valueKey:
                        "settings.status.deepDive."
                        + model.deepDiveAvailability.rawValue,
                    messageKey:
                        "settings.codex.deepDiveAvailability.message",
                    systemImage: "hammer",
                    role: .neutral,
                    identifier: "settings.codex.deepDiveAvailability"
                )
                Text("settings.codex.quickScanUnaffected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("settings.codex.disclosure") {
                DisclosureGroup("settings.codex.disclosure.summary") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(model.disclosure.items, id: \.self) { item in
                            Label(
                                LocalizedStringKey(item.localizationKey),
                                systemImage: item.systemImage
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 8)
                }
                .accessibilityIdentifier("settings.codex.disclosure")
            }

            Section("settings.codex.installation") {
                SettingsStatusRow(
                    titleKey: "settings.codex.installation",
                    valueKey:
                        "settings.status.codex.\(model.installationStatus.rawValue)",
                    messageKey: "settings.codex.installation.message",
                    systemImage: "terminal",
                    role: model.installationStatus == .installed
                        ? .positive
                        : .neutral
                )
                if let path = model.executablePath {
                    LabeledContent("settings.codex.path") {
                        Text(path.rawValue)
                            .font(.caption.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }
                if let version = model.version {
                    LabeledContent("settings.codex.version") {
                        Text(version)
                            .monospaced()
                    }
                }
                LabeledContent("settings.codex.syntax") {
                    Text(
                        LocalizedStringKey(
                            "settings.status.syntax."
                                + model.syntaxStatus.rawValue
                        )
                    )
                }
                Button("settings.action.checkAgain", action: checkAgain)
            }

            Section("settings.codex.budget") {
                Picker(
                    "settings.codex.defaultBudget",
                    selection: Binding(
                        get: { model.budget },
                        set: { value in
                            guard let updated = try? preferences.replacing(
                                investigationBudget: value
                            ) else {
                                return
                            }
                            updatePreferences(updated)
                        }
                    )
                ) {
                    Text("settings.budget.focused")
                        .tag(InvestigationBudgetPreset.focused)
                    Text("settings.budget.balanced")
                        .tag(InvestigationBudgetPreset.balanced)
                    Text("settings.budget.thorough")
                        .tag(InvestigationBudgetPreset.thorough)
                }
                .pickerStyle(.segmented)

                DisclosureGroup("settings.codex.advanced") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(
                            LocalizedStringKey(
                                "settings.budget.\(model.budget.rawValue).details"
                            )
                        )
                        Text("settings.codex.advanced.message")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .padding(.top, 8)
                }
            }
        }
        .formStyle(.grouped)
        .background {
            SettingsPageProbe(
                identifier: "settings.page.codexAndDeepDive"
            )
            .allowsHitTesting(false)
        }
    }

    private var evidenceMessageKey: String {
        switch model.runtimeEvidence.status {
        case .passed:
            "settings.codex.evidence.passed.message"
        case .stale:
            "settings.codex.evidence.stale.message"
        case .failed:
            "settings.codex.evidence.failed.message"
        case .unverified:
            "settings.codex.evidence.unverified.message"
        }
    }

    private var evidenceRole: SemanticStatusRole {
        switch model.runtimeEvidence.status {
        case .passed:
            .positive
        case .stale, .unverified:
            .limited
        case .failed:
            .failed
        }
    }

    private var runtimeGateMessageKey: String {
        guard let reason = model.runtimeGateReason else {
            return "settings.codex.runtimeGate.verified.message"
        }
        return "settings.runtimeGate.reason.\(reason.rawValue)"
    }

    private var runtimeGateRole: SemanticStatusRole {
        switch model.runtimeGate {
        case .verified:
            .positive
        case .blocked:
            .failed
        case .unverified:
            .limited
        }
    }
}
