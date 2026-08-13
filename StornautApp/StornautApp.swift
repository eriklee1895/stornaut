import AppKit
import StornautCore
import SwiftUI

@main
struct StornautApp: App {
    private let launchColorScheme = LaunchAppearanceOverride.colorScheme
    @State private var appModel: StornautAppModel

    init() {
        LaunchAppearanceOverride.apply()
        _appModel = State(
            initialValue: Self.makeComposition().model
        )
#if DEBUG
        IsolationProbeHarness.startIfRequested()
        CapabilityRuntimeProbeHarness.startIfRequested()
#endif
    }

    var body: some Scene {
        Window("app.name", id: "main") {
            RootView()
                .environment(appModel)
                .environment(\.locale, preferredLocale)
                .preferredColorScheme(
                    launchColorScheme ?? preferredColorScheme
                )
                .background {
                    WindowAppearanceProbe(identifier: "app.appearance")
                        .frame(width: 1, height: 1)
                }
#if DEBUG
                .overlay(alignment: .topLeading) {
                    DebugLaunchAppearanceProbe()
                        .frame(width: 1, height: 1)
                }
#endif
        }
        .defaultSize(width: 1_180, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            ZStack {
#if DEBUG
                if let color = LaunchAppearanceOverride.backgroundColor {
                    color.ignoresSafeArea()
                }
#endif
                StornautSettingsView()
            }
            .environment(appModel)
            .environment(\.locale, preferredLocale)
            .preferredColorScheme(
                launchColorScheme ?? preferredColorScheme
            )
            .background {
                WindowAppearanceProbe(identifier: "settings.appearance")
                    .frame(width: 1, height: 1)
            }
        }
        .keyboardShortcut(",", modifiers: .command)
    }

    private var preferredColorScheme: ColorScheme? {
        switch appModel.settingsState.snapshot?
            .preferences.appearance ?? .system
        {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    private var preferredLocale: Locale {
        switch appModel.settingsState.snapshot?
            .preferences.language ?? .english
        {
        case .english:
            Locale(identifier: "en")
        case .simplifiedChinese:
            Locale(identifier: "zh-Hans")
        }
    }

    @MainActor
    private static func makeComposition() -> AppComposition {
#if DEBUG
        if let selection = DebugAppFixtureSelection(
            arguments: CommandLine.arguments
        ) {
            do {
                return try AppComposition.debugFixture(
                    selection: selection,
                    historySelection: DebugHistoryFixtureSelection(
                        arguments: CommandLine.arguments
                    ),
                    settingsSelection: DebugSettingsFixtureSelection(
                        arguments: CommandLine.arguments
                    ),
                    settingsLanguage: DebugSettingsLanguage.selection(
                        arguments: CommandLine.arguments
                    )
                )
            } catch {
                return failedComposition(error)
            }
        }
#endif
        return AppComposition.production()
    }

    @MainActor
    private static func failedComposition(
        _ error: any Error
    ) -> AppComposition {
        let reason = DomainToken(
            rawValue: "app.state.store-unavailable"
        )!
        let state = try! AppPageState(
            phase: .error,
            projection: nil,
            reasonKey: reason,
            recoveryIntent: .retryLatestSnapshot,
            refreshedAt: Date()
        )
        return AppComposition(
            model: StornautAppModel(
                dependencies: AppDependencies {
                    throw error
                },
                initialState: state
            )
        )
    }
}

enum LaunchAppearanceOverride {
    static var colorScheme: ColorScheme? {
#if DEBUG
        switch value {
        case "light":
            .light
        case "dark":
            .dark
        default:
            nil
        }
#else
        nil
#endif
    }

    static var appearance: NSAppearance? {
#if DEBUG
        switch value {
        case "light":
            NSAppearance(named: .aqua)
        case "dark":
            NSAppearance(named: .darkAqua)
        default:
            nil
        }
#else
        nil
#endif
    }

#if DEBUG
    static var backgroundColor: Color? {
        switch value {
        case "light":
            Color(red: 0.96, green: 0.96, blue: 0.97)
        case "dark":
            Color(red: 0.10, green: 0.11, blue: 0.13)
        default:
            nil
        }
    }

    static var windowBackgroundColor: NSColor? {
        switch value {
        case "light":
            NSColor(calibratedWhite: 0.96, alpha: 1)
        case "dark":
            NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.13, alpha: 1)
        default:
            nil
        }
    }
#endif

    @MainActor
    static func apply() {
#if DEBUG
        NSApplication.shared.appearance = appearance
#endif
    }

    private static var value: Substring? {
        let prefix = "--stornaut-ui-test-appearance="
        return CommandLine.arguments
            .first { $0.hasPrefix(prefix) }?
            .dropFirst(prefix.count)
    }

#if DEBUG
    static var requestedValue: String {
        value.map(String.init) ?? "system"
    }
#endif
}

#if DEBUG
struct DebugLaunchAppearanceProbe: NSViewRepresentable {
    func makeNSView(context: Context) -> DebugLaunchAppearanceProbeView {
        DebugLaunchAppearanceProbeView()
    }

    func updateNSView(
        _ nsView: DebugLaunchAppearanceProbeView,
        context: Context
    ) {
        nsView.apply()
    }
}

final class DebugLaunchAppearanceProbeView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityIdentifier("app.appearance.requested")
        setAccessibilityRole(.staticText)
        apply()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply() {
        setAccessibilityLabel(LaunchAppearanceOverride.requestedValue)
    }
}
#endif

struct WindowAppearanceProbe: NSViewRepresentable {
    let identifier: String

    func makeNSView(context: Context) -> WindowAppearanceView {
        WindowAppearanceView(identifier: identifier)
    }

    func updateNSView(
        _ nsView: WindowAppearanceView,
        context: Context
    ) {
        nsView.identifier = NSUserInterfaceItemIdentifier(identifier)
        nsView.apply()
    }
}

final class WindowAppearanceView: NSView {
    init(identifier: String) {
        super.init(frame: .zero)
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
        setAccessibilityElement(true)
        setAccessibilityIdentifier(identifier)
        setAccessibilityRole(.staticText)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        apply()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        apply()
    }

    func apply() {
        #if DEBUG
        if let appearance = LaunchAppearanceOverride.appearance {
            window?.appearance = appearance
            self.appearance = appearance
        }
        if let backgroundColor = LaunchAppearanceOverride.windowBackgroundColor {
            window?.backgroundColor = backgroundColor
        }
        #endif
        guard let window else {
            return
        }
        let label = window.effectiveAppearance
            .bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? "dark"
            : "light"
        setAccessibilityLabel(label)
    }
}
