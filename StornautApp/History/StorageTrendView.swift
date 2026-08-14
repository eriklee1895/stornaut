import Charts
import SwiftUI

struct StorageTrendView: View {
    let model: HistoryTrendModel
    let close: () -> Void

    private let byteFormatter = StornautByteFormatter()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("history.trend.title")
                            .font(.title2.weight(.semibold))
                        Text("history.trend.subtitle")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("history.trend.back", action: close)
                        .accessibilityIdentifier("history.trend.back")
                }

                Chart {
                    ForEach(model.events) { event in
                        RuleMark(
                            x: .value(
                                localized("history.trend.event"),
                                event.createdAt
                            )
                        )
                        .foregroundStyle(.secondary.opacity(0.3))
                        .lineStyle(
                            StrokeStyle(lineWidth: 1, dash: [2, 4])
                        )
                    }

                    ForEach(model.samples) { sample in
                        LineMark(
                            x: .value(
                                localized("history.detail.finished"),
                                sample.finishedAt
                            ),
                            y: .value(
                                localized("history.trend.used"),
                                sample.usedBytes.value
                            ),
                            series: .value(
                                localized("history.trend.series"),
                                localized("history.trend.used")
                            )
                        )
                        .foregroundStyle(.indigo)
                        .lineStyle(
                            StrokeStyle(lineWidth: 2, dash: [])
                        )

                        LineMark(
                            x: .value(
                                localized("history.detail.finished"),
                                sample.finishedAt
                            ),
                            y: .value(
                                localized("history.trend.free"),
                                sample.freeBytes.value
                            ),
                            series: .value(
                                localized("history.trend.series"),
                                localized("history.trend.free")
                            )
                        )
                        .foregroundStyle(.cyan)
                        .lineStyle(
                            StrokeStyle(lineWidth: 2, dash: [6, 4])
                        )
                    }

                    if let last = model.samples.last {
                        PointMark(
                            x: .value(
                                localized("history.detail.finished"),
                                last.finishedAt
                            ),
                            y: .value(
                                localized("history.trend.used"),
                                last.usedBytes.value
                            )
                        )
                        .foregroundStyle(.indigo)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("history.trend.used")
                                .font(.caption.weight(.semibold))
                        }

                        PointMark(
                            x: .value(
                                localized("history.detail.finished"),
                                last.finishedAt
                            ),
                            y: .value(
                                localized("history.trend.free"),
                                last.freeBytes.value
                            )
                        )
                        .foregroundStyle(.cyan)
                        .annotation(position: .bottom, alignment: .trailing) {
                            Text("history.trend.free")
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
                .chartForegroundStyleScale([
                    localized("history.trend.used"): Color.indigo,
                    localized("history.trend.free"): Color.cyan,
                ])
                .frame(minHeight: 280)
                .accessibilityLabel("history.trend.accessibility")
                .accessibilityValue(trendAccessibilitySummary)

                HStack(spacing: 18) {
                    Label(
                        "history.trend.used",
                        systemImage: "line.diagonal"
                    )
                    .foregroundStyle(.indigo)
                    Label(
                        "history.trend.free",
                        systemImage: "line.diagonal"
                    )
                    .foregroundStyle(.cyan)
                }
                .font(.callout.weight(.medium))

                Text(LocalizedStringKey(model.causalityDisclaimerKey))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(
                        .background.secondary,
                        in: RoundedRectangle(cornerRadius: 10)
                    )

                DisclosureGroup("history.trend.dataTable") {
                    Grid(alignment: .leading, horizontalSpacing: 24) {
                        GridRow {
                            Text("history.detail.finished")
                            Text("history.trend.used")
                            Text("history.trend.free")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                        ForEach(model.samples) { sample in
                            Divider()
                            GridRow {
                                Text(
                                    sample.finishedAt,
                                    format: .dateTime
                                        .year().month().day().hour().minute()
                                )
                                Text(
                                    byteFormatter.string(
                                        for: sample.usedBytes
                                    )
                                )
                                .monospacedDigit()
                                Text(
                                    byteFormatter.string(
                                        for: sample.freeBytes
                                    )
                                )
                                .monospacedDigit()
                            }
                        }
                    }
                    .padding(.top, 10)
                }
                .accessibilityIdentifier("history.trend.dataTable")
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("history.trend")
    }

    private var trendAccessibilitySummary: String {
        model.samples.map {
            [
                $0.finishedAt.formatted(
                    .dateTime.year().month().day().hour().minute()
                ),
                localized("history.trend.used")
                    + " "
                    + byteFormatter.accessibilityString(for: $0.usedBytes),
                localized("history.trend.free")
                    + " "
                    + byteFormatter.accessibilityString(for: $0.freeBytes),
            ].joined(separator: ", ")
        }.joined(separator: "; ")
    }
}
