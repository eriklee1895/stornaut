import StornautCore
import SwiftUI

struct ScanningSettingsView: View {
    let model: ScanningSettingsModel
    let chooseRoot: () -> Void
    let resetRoot: () -> Void
    let chooseExclusion: () -> Void
    let removeExclusion: (ScanExclusion) -> Void

    var body: some View {
        Form {
            SettingsPageHeader(
                titleKey: "settings.section.scanning",
                messageKey: "settings.scanning.subtitle",
                systemImage: StornautSystemImage.quickScan
            )

            Section("settings.scanning.primaryRoot") {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            model.primaryRoot?.path.rawValue
                                ?? localized("settings.value.unavailable")
                        )
                        .font(.callout.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                        Text(
                            LocalizedStringKey(
                                "settings.status.root."
                                    + (
                                        model.primaryRoot?.availability
                                            .rawValue ?? "unavailable"
                                    )
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("settings.action.chooseRoot", action: chooseRoot)
                    Button("settings.action.resetRoot", action: resetRoot)
                        .disabled(
                            model.primaryRoot?.availability == .fallbackHome
                        )
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("settings.scanning.primaryRoot")
                Text("settings.scanning.singleRoot.message")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("settings.scanning.exclusions") {
                if model.exclusions.isEmpty {
                    Text("settings.scanning.exclusions.empty")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.exclusions, id: \.rawValue) { exclusion in
                        HStack {
                            Label(
                                exclusion.rawValue,
                                systemImage: "folder.badge.minus"
                            )
                            .font(.callout.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                            Spacer()
                            Button {
                                removeExclusion(exclusion)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(
                                Text("settings.action.removeExclusion")
                            )
                        }
                        .accessibilityIdentifier(
                            "settings.exclusion.\(exclusion.rawValue)"
                        )
                    }
                }
                Button(
                    "settings.action.addExclusion",
                    action: chooseExclusion
                )
                .disabled(!model.canAddExclusion)
            }

            Section("settings.scanning.catalog") {
                SettingsPolicyRow(
                    titleKey: "settings.scanning.builtInRules",
                    value: String(model.catalogRuleCount),
                    messageKey: "settings.scanning.builtInRules.message",
                    systemImage: "list.bullet.clipboard"
                )
                SettingsPolicyRow(
                    titleKey: "settings.scanning.adapters",
                    value: localized("settings.value.notConfigured"),
                    messageKey: "settings.scanning.adapters.message",
                    systemImage: "puzzlepiece.extension"
                )
            }

            Section("settings.scanning.protected") {
                Label(
                    "settings.scanning.protected.message",
                    systemImage: "lock.shield"
                )
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .background {
            SettingsPageProbe(identifier: "settings.page.scanning")
                .allowsHitTesting(false)
        }
    }
}
