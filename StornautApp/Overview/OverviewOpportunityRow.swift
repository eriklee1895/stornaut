import StornautCore
import SwiftUI

struct OverviewOpportunityRow: View {
    let opportunity: OverviewOpportunity
    let formatter: StornautByteFormatter

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: opportunity.category.systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(opportunity.producer?.rawValue
                    ?? localized("overview.opportunity.producerUnknown"))
                    .fontWeight(.semibold)
                Text(opportunity.relativePath.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 10) {
                    Text(
                        LocalizedStringKey(
                            opportunity.category.overviewLocalizationKey
                        )
                    )
                    Label(
                        LocalizedStringKey(opportunity.activity.localizationKey),
                        systemImage: opportunity.activity.systemImage
                    )
                    if let recoveryCost = opportunity.recoveryCost {
                        Label(
                            LocalizedStringKey(
                                "overview.recovery.\(recoveryCost.rawValue)"
                            ),
                            systemImage: "arrow.clockwise"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 6) {
                Text(formatter.string(for: opportunity.allocatedBytes))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                ReclaimDispositionLabel(
                    disposition: opportunity.disposition
                )
                .font(.caption)
            }
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }
}

extension OverviewOpportunityActivity {
    var localizationKey: String {
        "overview.activity.\(rawValue)"
    }

    var systemImage: String {
        switch self {
        case .checked:
            "checkmark.circle"
        case .unavailable:
            "exclamationmark.triangle"
        case .unknown:
            "questionmark.circle"
        }
    }
}

extension ArtifactCategory {
    var overviewLocalizationKey: String {
        "overview.category.\(rawValue)"
    }

    var systemImage: String {
        switch self {
        case .packageAndBuildCaches:
            "shippingbox"
        case .rebuildableProjectArtifacts:
            "hammer"
        case .toolRuntimesAndImages:
            "cube"
        case .updatesAndTemporaryFiles:
            "arrow.triangle.2.circlepath"
        case .largeRepositoriesAndHistory:
            "point.3.connected.trianglepath.dotted"
        case .unknownLargeConsumers:
            "questionmark.folder"
        case .protected:
            "lock.shield"
        }
    }
}
