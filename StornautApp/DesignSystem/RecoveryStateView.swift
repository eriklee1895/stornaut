import SwiftUI

struct RecoveryStateView<Content: View>: View {
    let model: RecoveryStateModel
    let primaryAction: (() -> Void)?
    let secondaryAction: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content()

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: model.systemImage)
                    .foregroundStyle(model.role.color)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(model.titleKey))
                        .font(.headline)
                    Text(LocalizedStringKey(model.messageKey))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if let primaryIntent = model.primaryIntent,
                   let primaryAction
                {
                    Button(
                        LocalizedStringKey(primaryIntent.localizationKey),
                        action: primaryAction
                    )
                    .buttonStyle(.borderedProminent)
                }

                if let secondaryIntent = model.secondaryIntent,
                   let secondaryAction
                {
                    Button(
                        LocalizedStringKey(secondaryIntent.localizationKey),
                        action: secondaryAction
                    )
                    .buttonStyle(.bordered)
                }
            }
            .padding(16)
            .background(
                model.role.color.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
    }
}

extension SafeRecoveryIntent {
    var localizationKey: String {
        switch self {
        case .retryLatestSnapshot:
            "recovery.action.retry"
        case .refreshLatestSnapshot:
            "recovery.action.refresh"
        case .reviewPermissions:
            "recovery.action.permissions"
        }
    }
}
