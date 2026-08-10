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

            Section("settings.codex.safety") {
                SettingsStatusRow(
                    titleKey: "settings.codex.safety",
                    valueKey: "settings.status.safety.pausedRequired",
                    messageKey: "settings.codex.safety.message",
                    systemImage: "lock.shield",
                    role: .limited
                )
                Text("settings.codex.quickScanUnaffected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
}
