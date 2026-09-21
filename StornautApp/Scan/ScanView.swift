import StornautCore
import SwiftUI

struct ScanView: View {
    @Environment(StornautAppModel.self) private var appModel
    @State private var query = ""
    @State private var filter = ScanResultFilter.all
    @State private var selection: SnapshotID?
    @State private var inspectorIsPresented = false
    @State private var didApplyDebugSelection = false

    private let byteFormatter = StornautByteFormatter()

    @ViewBuilder
    var body: some View {
        if appModel.scanWorkspaceRoute == .review {
            ReviewView()
        } else if appModel.scanWorkspaceRoute == .cleanupResult {
            CleanupResultView()
        } else {
            scanResultsBody
        }
    }

    private var scanResultsBody: some View {
        let model = ScanModel(
            flowState: appModel.scanState,
            pageState: appModel.pageState,
            query: query,
            filter: filter
        )

        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                header(model)
                metricStrip(model)
                ScanStageRail(stages: model.stageStates)
                currentScope(model)
                resultControls(model)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider()

            results(model)

            Divider()

            footer(model)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(pageBackground)
        .navigationTitle("scan.title")
        .inspector(
            isPresented: $inspectorIsPresented
        ) {
            if inspectorIsPresented,
               let selection,
               let inspector = model.inspector(for: selection)
            {
                ScanEvidenceInspector(
                    model: inspector,
                    close: {
                        inspectorIsPresented = false
                        self.selection = nil
                    }
                )
            }
        }
        .onChange(of: selection) { _, selection in
            inspectorIsPresented = selection != nil
        }
        .onChange(of: inspectorIsPresented) { _, isPresented in
            if !isPresented {
                selection = nil
            }
        }
        .onChange(of: model.rows.map(\.id)) { _, IDs in
            if let selection, !IDs.contains(selection) {
                inspectorIsPresented = false
                self.selection = nil
            }
        }
#if DEBUG
        .task {
            guard !didApplyDebugSelection,
                  DebugScanInspectorSelection.isRequested(
                      arguments: CommandLine.arguments
                  ),
                  let first = model.rows.first
            else {
                return
            }
            didApplyDebugSelection = true
            selection = first.id
        }
#endif
        .accessibilityIdentifier(
            "scan.presentation.\(model.presentation.rawValue)"
        )
    }

    private func header(_ model: ScanModel) -> some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("scan.title")
                    .font(.largeTitle.weight(.semibold))
                Text("scan.subtitle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Label(
                    "scan.localOnly",
                    systemImage: "checkmark.shield"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }

            Spacer()

            switch model.primaryAction {
            case .start:
                Button(action: appModel.startQuickScan) {
                    Label(
                        model.projection == nil
                            ? "scan.action.run"
                            : "scan.action.runAgain",
                        systemImage: "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("scan.action.start")
            case .stop:
                VStack(alignment: .trailing, spacing: 5) {
                    Button(action: appModel.stopQuickScan) {
                        Label(
                            "scan.action.stop",
                            systemImage: "stop.circle"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.presentation == .stopping)
                    .accessibilityIdentifier("scan.action.stop")
                    Text("scan.stop.retainsPartial")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func metricStrip(_ model: ScanModel) -> some View {
        HStack(spacing: 12) {
            MetricTile(
                title: "scan.metric.scope",
                value: model.metrics.scopeScanned.formatted(),
                accessibilityValue:
                    model.metrics.scopeScanned.formatted(),
                systemImage: "folder"
            )
            .accessibilityIdentifier("scan.metric.scope")

            MetricTile(
                title: "scan.metric.candidates",
                value: model.metrics.candidatesFound.formatted(),
                accessibilityValue:
                    model.metrics.candidatesFound.formatted(),
                systemImage: "square.stack.3d.up"
            )
            .accessibilityIdentifier("scan.metric.candidates")

            MetricTile(
                title: "scan.metric.measured",
                value: byteFormatter.string(
                    for: model.metrics.measuredBytes
                ),
                accessibilityValue:
                    byteFormatter.accessibilityString(
                        for: model.metrics.measuredBytes
                    ),
                systemImage: "internaldrive"
            )
            .accessibilityIdentifier("scan.metric.measured")

            MetricTile(
                title: "scan.metric.elapsed",
                value: duration(model.metrics.elapsed),
                accessibilityValue: duration(model.metrics.elapsed),
                systemImage: "timer"
            )
            .accessibilityIdentifier("scan.metric.elapsed")
        }
    }

    @ViewBuilder
    private func currentScope(_ model: ScanModel) -> some View {
        if model.presentation == .active
            || model.presentation == .stopping
        {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(
                    LocalizedStringKey(
                        statusKey(for: model.presentation)
                    )
                )
                    .font(.callout.weight(.medium))
                Text(model.currentRelativePath?.rawValue ?? "—")
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Color.accentColor.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("scan.currentScope")
        } else if model.presentation != .idle {
            Label(
                LocalizedStringKey(statusKey(for: model.presentation)),
                systemImage: statusImage(for: model.presentation)
            )
            .font(.callout.weight(.medium))
            .foregroundStyle(statusRole(for: model.presentation).color)
            .accessibilityIdentifier("scan.terminalStatus")
        }
    }

    private func resultControls(_ model: ScanModel) -> some View {
        HStack(spacing: 12) {
            TextField("scan.search", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)
                .accessibilityIdentifier("scan.search")

            Picker("scan.filter", selection: $filter) {
                ForEach(ScanResultFilter.allCases) { value in
                    Text(
                        LocalizedStringKey(
                            "scan.filter.\(value.rawValue)"
                        )
                    )
                    .tag(value)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 470)
            .accessibilityIdentifier("scan.filter")

            Spacer()

            if !model.rows.isEmpty {
                Text(
                    String(
                        format: localized("scan.results.count"),
                        model.rows.count
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private func results(_ model: ScanModel) -> some View {
        if model.rows.isEmpty {
            ContentUnavailableView {
                Label(
                    model.presentation == .idle
                        ? "scan.empty.title"
                        : "scan.results.empty",
                    systemImage: model.presentation == .idle
                        ? "externaldrive"
                        : "line.3.horizontal.decrease.circle"
                )
            } description: {
                Text(
                    model.presentation == .idle
                        ? "scan.empty.message"
                        : "scan.results.empty.message"
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("scan.results.empty")
        } else {
            ScanResultsTable(
                groups: model.groups,
                selection: $selection
            )
        }
    }

    private func footer(_ model: ScanModel) -> some View {
        HStack(spacing: 20) {
            summaryValue(
                "scan.filter.ready",
                value: model.summary.readyCount,
                role: .positive
            )
            .accessibilityIdentifier("scan.summary")
            summaryValue(
                "scan.filter.review",
                value: model.summary.reviewCount,
                role: .limited
            )
            summaryValue(
                "scan.filter.unknown",
                value: model.summary.unknownCount,
                role: .neutral
            )
            summaryValue(
                "scan.filter.protected",
                value: model.summary.protectedCount,
                role: .protected
            )

            Spacer()

            Label(
                "scan.deepDive.implementationUnavailable",
                systemImage: "lock.shield"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)

            Button("scan.review.action", action: appModel.openReview)
                .buttonStyle(.borderedProminent)
                .disabled(
                    model.summary.readyCount == 0
                        || model.presentation == .active
                        || model.presentation == .stopping
                        || model.presentation == .failed
                )
                .help("scan.review.action.help")
                .accessibilityIdentifier("scan.review.action")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func summaryValue(
        _ key: String,
        value: Int,
        role: SemanticStatusRole
    ) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(role.color)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(LocalizedStringKey(key))
                .foregroundStyle(.secondary)
            Text(value, format: .number)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
    }

    private func duration(_ interval: TimeInterval) -> String {
        Duration.seconds(max(0, interval)).formatted(
            .time(pattern: .minuteSecond)
        )
    }

    private func statusKey(
        for presentation: ScanPresentation
    ) -> String {
        "scan.status.\(presentation.rawValue)"
    }

    private func statusImage(
        for presentation: ScanPresentation
    ) -> String {
        switch presentation {
        case .completed:
            "checkmark.circle"
        case .partial, .limitedPermission:
            "exclamationmark.triangle"
        case .cancelled:
            "stop.circle"
        case .failed:
            "xmark.octagon"
        case .idle:
            "circle"
        case .active, .stopping:
            "progress.indicator"
        }
    }

    private func statusRole(
        for presentation: ScanPresentation
    ) -> SemanticStatusRole {
        switch presentation {
        case .completed:
            .positive
        case .partial, .limitedPermission:
            .limited
        case .failed:
            .failed
        case .idle, .cancelled:
            .neutral
        case .active, .stopping:
            .informational
        }
    }

    private var pageBackground: Color {
#if DEBUG
        LaunchAppearanceOverride.backgroundColor
            ?? Color(nsColor: .windowBackgroundColor)
#else
        Color(nsColor: .windowBackgroundColor)
#endif
    }
}

#if DEBUG
private enum DebugScanInspectorSelection {
    static func isRequested(arguments: [String]) -> Bool {
        arguments.filter {
            $0 == "--stornaut-debug-scan-inspector=first"
        }.count == 1
    }
}
#endif
