import StornautCore
import SwiftUI

struct ReclaimDispositionLabel: View {
    let disposition: ReclaimDisposition

    var body: some View {
        let semantic = SemanticDisposition(disposition)
        Label {
            Text(LocalizedStringKey(semantic.localizationKey))
        } icon: {
            Image(systemName: semantic.systemImage)
        }
        .foregroundStyle(semantic.role.color)
        .accessibilityLabel(
            Text(
                LocalizedStringKey(
                    semantic.accessibilityLocalizationKey
                )
            )
        )
    }
}
