import SwiftUI

struct StorageOrbitView: View {
    let segments: [OverviewOrbitSegment]
    let formatter: StornautByteFormatter
    let deepDive: OverviewDeepDiveState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("overview.orbit.title")
                .font(.headline)

            HStack(alignment: .center, spacing: 24) {
                ZStack {
                    Canvas { context, size in
                        let diameter = min(size.width, size.height) - 28
                        let rect = CGRect(
                            x: (size.width - diameter) / 2,
                            y: (size.height - diameter) / 2,
                            width: diameter,
                            height: diameter
                        )
                        let path = Path(ellipseIn: rect)
                        let total = totalBytes
                        var start = 0.0

                        context.stroke(
                            path,
                            with: .color(.secondary.opacity(0.12)),
                            style: StrokeStyle(lineWidth: 24)
                        )

                        for segment in segments {
                            let fraction = Double(segment.bytes.value) / total
                            let end = min(1, start + fraction)
                            context.stroke(
                                path.trimmedPath(
                                    from: start,
                                    to: max(start, end - 0.003)
                                ),
                                with: .color(
                                    OverviewPalette.color(for: segment.kind)
                                ),
                                style: StrokeStyle(
                                    lineWidth: 24,
                                    lineCap: .butt
                                )
                            )
                            start = end
                        }
                    }
                    .frame(width: 184, height: 184)

                    VStack(spacing: 3) {
                            Image(systemName: "externaldrive")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("overview.orbit.accessibility")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)

                    if let point = probePoint {
                        Image(systemName: "scope")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(.indigo, in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(.background, lineWidth: 2)
                            }
                            .offset(x: point.x, y: point.y)
                            .accessibilityHidden(true)
                            .help("overview.probe.implementationUnavailable")
                    }
                }
                .frame(width: 184, height: 184)
                .accessibilityLabel("overview.orbit.accessibility")
                .accessibilityChildren {
                    ForEach(segments) { segment in
                        Circle()
                            .accessibilityLabel(
                                Text(
                                    LocalizedStringKey(
                                        segment.kind.localizationKey
                                    )
                                )
                            )
                            .accessibilityValue(
                                formatter.accessibilityString(
                                    for: segment.bytes
                                )
                            )
                    }
                    if probePoint != nil {
                        Circle()
                            .accessibilityLabel(
                                "overview.probe.implementationUnavailable"
                            )
                            .accessibilityIdentifier(
                                "overview.probe.implementationUnavailable"
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(segments) { segment in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(OverviewPalette.color(for: segment.kind))
                                .frame(width: 8, height: 8)
                                .accessibilityHidden(true)
                            Text(
                                LocalizedStringKey(
                                    segment.kind.localizationKey
                                )
                            )
                            .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(formatter.string(for: segment.bytes))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            }
        }
    }

    private var totalBytes: Double {
        max(1, segments.reduce(0.0) {
            $0 + Double($1.bytes.value)
        })
    }

    private var probePoint: CGPoint? {
        guard deepDive == .implementationUnavailable,
              let unknownIndex = segments.firstIndex(where: {
                  $0.kind == .unknown
              })
        else {
            return nil
        }
        let before = segments[..<unknownIndex].reduce(0.0) {
            $0 + Double($1.bytes.value)
        }
        let fraction = before / totalBytes
        let angle = fraction * 2 * Double.pi - Double.pi / 2
        let radius = 78.0
        return CGPoint(
            x: cos(angle) * radius,
            y: sin(angle) * radius
        )
    }
}

enum OverviewPalette {
    static func color(for kind: OverviewOrbitKind) -> Color {
        switch kind {
        case .packageAndBuildCaches:
            .indigo
        case .rebuildableProjectArtifacts:
            .blue
        case .toolRuntimesAndImages:
            .cyan
        case .updatesAndTemporaryFiles:
            .teal
        case .largeRepositoriesAndHistory:
            .mint
        case .protected:
            .purple
        case .unknown:
            .orange
        case .free:
            .secondary
        }
    }

    static func color(for kind: OverviewLedgerKind) -> Color {
        switch kind {
        case .known:
            .indigo
        case .unknown:
            .orange
        case .unmeasurable:
            .secondary
        case .free:
            .teal
        }
    }
}

extension OverviewOrbitKind {
    var localizationKey: String {
        "overview.orbit.\(rawValue)"
    }
}
