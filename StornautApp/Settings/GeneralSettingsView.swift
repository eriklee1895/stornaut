import StornautCore
import SwiftUI

struct GeneralSettingsView: View {
    let model: GeneralSettingsModel
    let updatePreferences: (SettingsPreferences) -> Void
    let preferences: SettingsPreferences

    var body: some View {
        Form {
            SettingsPageHeader(
                titleKey: "settings.section.general",
                messageKey: "settings.general.subtitle",
                systemImage: "gearshape"
            )

            Section("settings.general.preferences") {
                Picker(
                    "settings.general.language",
                    selection: Binding(
                        get: { model.language },
                        set: { value in
                            guard let updated = try? preferences.replacing(
                                language: value
                            ) else {
                                return
                            }
                            updatePreferences(updated)
                        }
                    )
                ) {
                    Text("settings.language.english")
                        .tag(SettingsLanguage.english)
                    Text("settings.language.zhHans")
                        .tag(SettingsLanguage.simplifiedChinese)
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings.general.language")

                Picker(
                    "settings.general.appearance",
                    selection: Binding(
                        get: { model.appearance },
                        set: { value in
                            guard let updated = try? preferences.replacing(
                                appearance: value
                            ) else {
                                return
                            }
                            updatePreferences(updated)
                        }
                    )
                ) {
                    Text("settings.appearance.system")
                        .tag(SettingsAppearance.system)
                        .accessibilityIdentifier(
                            "settings.general.appearance.system"
                        )
                    Text("settings.appearance.light")
                        .tag(SettingsAppearance.light)
                        .accessibilityIdentifier(
                            "settings.general.appearance.light"
                        )
                    Text("settings.appearance.dark")
                        .tag(SettingsAppearance.dark)
                        .accessibilityIdentifier(
                            "settings.general.appearance.dark"
                        )
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings.general.appearance")
            }

            Section("settings.general.setupStatus") {
                SettingsStatusRow(
                    titleKey: "settings.general.diskAccess",
                    valueKey:
                        "settings.status.diskAccess.\(model.diskAccess.rawValue)",
                    messageKey: "settings.general.diskAccess.message",
                    systemImage: "externaldrive.badge.checkmark",
                    role: model.diskAccess == .full
                        ? .positive
                        : model.diskAccess == .checkFailed
                            ? .failed
                            : .limited
                )
                SettingsStatusRow(
                    titleKey: "settings.general.codexInstallation",
                    valueKey:
                        "settings.status.codex.\(model.codexInstallation.rawValue)",
                    messageKey: "settings.general.codex.message",
                    systemImage: "terminal",
                    role: model.codexInstallation == .installed
                        ? .positive
                        : .neutral
                )
                SettingsStatusRow(
                    titleKey: "settings.general.deepDiveSafety",
                    valueKey: "settings.status.safety.pausedRequired",
                    messageKey: "settings.general.deepDive.message",
                    systemImage: "lock.shield",
                    role: .limited
                )
            }

            Section {
                Label(
                    "settings.general.onDemand",
                    systemImage: "power"
                )
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.general.onDemand")
            }
        }
        .formStyle(.grouped)
        .background {
            SettingsPageProbe(identifier: "settings.page.general")
                .allowsHitTesting(false)
        }
    }
}
