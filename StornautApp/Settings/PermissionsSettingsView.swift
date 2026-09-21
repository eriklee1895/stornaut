import SwiftUI

struct PermissionsSettingsView: View {
    let model: PermissionsSettingsModel
    let openSystemSettings: () -> Void
    let checkAgain: () -> Void

    var body: some View {
        Form {
            SettingsPageHeader(
                titleKey: "settings.section.permissions",
                messageKey: "settings.permissions.subtitle",
                systemImage: "lock.shield"
            )

            Section("settings.permissions.fullDiskAccess") {
                SettingsStatusRow(
                    titleKey: "settings.permissions.fullDiskAccess",
                    valueKey:
                        "settings.status.diskAccess.\(model.diskAccess.rawValue)",
                    messageKey: "settings.permissions.limited.message",
                    systemImage: "externaldrive.badge.exclamationmark",
                    role: model.diskAccess == .full
                        ? .positive
                        : model.diskAccess == .checkFailed
                            ? .failed
                            : .limited
                )
                HStack {
                    Button(
                        "settings.action.openSystemSettings",
                        action: openSystemSettings
                    )
                    Button(
                        "settings.action.checkAgain",
                        action: checkAgain
                    )
                    Spacer()
                    Text(
                        String(
                            format: localized(
                                "settings.permissions.coverageGaps"
                            ),
                            model.coverageGapCount
                        )
                    )
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }

            Section("settings.permissions.scope") {
                if let primaryRoot = model.primaryRoot {
                    LabeledContent("settings.scanning.primaryRoot") {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(primaryRoot.path.rawValue)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(
                                LocalizedStringKey(
                                    "settings.status.root."
                                        + primaryRoot.availability.rawValue
                                )
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                Text("settings.permissions.scope.message")
                    .foregroundStyle(.secondary)
                Label(
                    model.quickScanRemainsAvailable
                        ? "settings.permissions.quickScanAvailable"
                        : "settings.permissions.quickScanBlocked",
                    systemImage: model.quickScanRemainsAvailable
                        ? "checkmark.circle"
                        : "exclamationmark.octagon"
                )
                .foregroundStyle(
                    model.quickScanRemainsAvailable ? .green : .orange
                )
            }

            Section("settings.permissions.protected") {
                Label(
                    "settings.permissions.protected.message",
                    systemImage: "lock.fill"
                )
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .background {
            SettingsPageProbe(identifier: "settings.page.permissions")
                .allowsHitTesting(false)
        }
    }
}
