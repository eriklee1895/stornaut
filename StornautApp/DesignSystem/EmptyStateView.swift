import SwiftUI

struct StornautEmptyStateView: View {
    let titleKey: String
    let messageKey: String
    let systemImage: String
    let actionTitleKey: String?
    let action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(
                LocalizedStringKey(titleKey),
                systemImage: systemImage
            )
        } description: {
            Text(LocalizedStringKey(messageKey))
        } actions: {
            if let actionTitleKey, let action {
                Button(
                    LocalizedStringKey(actionTitleKey),
                    action: action
                )
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
