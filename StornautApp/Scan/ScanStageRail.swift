import StornautCore
import SwiftUI

struct ScanStageRail: View {
    let stages: [ScanStageState]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) {
                index,
                item in
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label {
                            Text(
                                LocalizedStringKey(
                                    item.stage.scanLocalizationKey
                                )
                            )
                            .lineLimit(1)
                        } icon: {
                            Image(systemName: item.status.systemImage)
                        }
                        .font(.callout.weight(.medium))
                        .foregroundStyle(item.status.role.color)

                        Text(
                            LocalizedStringKey(
                                item.status.localizationKey
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        Text(
                            LocalizedStringKey(
                                item.stage.scanLocalizationKey
                            )
                        )
                    )
                    .accessibilityValue(
                        Text(
                            LocalizedStringKey(
                                item.status.localizationKey
                            )
                        )
                    )
                    .accessibilityHint(
                        Text(
                            "\(index + 1), \(stages.count)"
                        )
                    )
                    .accessibilityIdentifier(
                        "scan.stage.\(item.stage.rawValue)"
                    )

                    if index < stages.count - 1 {
                        Rectangle()
                            .fill(.separator)
                            .frame(width: 24, height: 1)
                            .padding(.horizontal, 8)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(16)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 14)
        )
    }
}

extension QuickScanStage {
    var scanLocalizationKey: String {
        "scan.stage.\(rawValue)"
    }
}

private extension ScanStageStatus {
    var localizationKey: String {
        "scan.stage.\(rawValue)"
    }

    var systemImage: String {
        switch self {
        case .complete:
            "checkmark.circle.fill"
        case .current:
            "circle.dotted.circle.fill"
        case .incomplete:
            "circle.lefthalf.filled"
        case .unavailable:
            "minus.circle"
        case .pending:
            "circle"
        }
    }

    var role: SemanticStatusRole {
        switch self {
        case .complete:
            .positive
        case .current:
            .informational
        case .incomplete:
            .limited
        case .unavailable:
            .neutral
        case .pending:
            .neutral
        }
    }
}
