import AppKit
import SwiftUI

struct RootView: View {
    @Environment(StornautAppModel.self) private var appModel
    @State private var selection: AppDestination?

    init() {
#if DEBUG
        _selection = State(
            initialValue: DebugInitialDestination.selection(
                arguments: CommandLine.arguments
            )
        )
#else
        _selection = State(initialValue: .overview)
#endif
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(AppDestination.allCases, selection: $selection) { destination in
                    Label(destination.title, systemImage: destination.systemImage)
                        .tag(destination)
                        .accessibilityIdentifier("sidebar.\(destination.rawValue)")
                }
                .listStyle(.sidebar)

                Divider()

                SettingsLink {
                    Label("settings.title", systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sidebar.settings")
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .navigationTitle("app.name")
            .navigationSplitViewColumnWidth(min: 210, ideal: 224, max: 240)
        } detail: {
            destinationContent(selection ?? .overview)
        }
        .frame(minWidth: 960, minHeight: 640)
        .task {
            await appModel.refreshIfNeeded()
        }
#if DEBUG
        .background {
            ZStack {
                if let color = LaunchAppearanceOverride.backgroundColor {
                    color.ignoresSafeArea()
                }
                DebugAppStateProbe(phase: appModel.pageState.phase)
                    .frame(width: 1, height: 1)
                DebugScanStateProbe(phase: appModel.scanState.phase)
                    .frame(width: 1, height: 1)
                DebugHistoryStateProbe(
                    phase: appModel.historyState.phase
                )
                .frame(width: 1, height: 1)
            }
        }
#endif
    }

    @ViewBuilder
    private func destinationContent(
        _ destination: AppDestination
    ) -> some View {
        switch destination {
        case .overview:
            OverviewView(
                model: OverviewModel(
                    pageState: appModel.pageState,
                    scanActivity: appModel.scanActivity
                ),
                openScan: {
                    selection = .scan
                },
                retryLatestSnapshot: {
                    Task {
                        await appModel.refresh()
                    }
                }
            )
        case .scan:
            ScanView()
        case .history:
            HistoryView {
                selection = .scan
            }
        case .investigations:
            DestinationPlaceholder(destination: destination)
        }
    }
}

private struct DestinationPlaceholder: View {
    let destination: AppDestination

    var body: some View {
        ContentUnavailableView {
            Label(destination.title, systemImage: destination.systemImage)
        } description: {
            Text("placeholder.foundation")
        }
        .navigationTitle(destination.title)
    }
}
