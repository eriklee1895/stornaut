import SwiftUI

struct CoverageBadge: View {
    let model: CoverageBadgeModel

    var body: some View {
        Label {
            Text(LocalizedStringKey(model.localizationKey))
        } icon: {
            Image(systemName: model.systemImage)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(model.role.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            model.role.color.opacity(0.12),
            in: Capsule()
        )
    }
}
