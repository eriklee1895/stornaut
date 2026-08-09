import AppKit
import SwiftUI

@main
struct StornautApp: App {
    private let launchColorScheme = LaunchAppearanceOverride.colorScheme

    init() {
        LaunchAppearanceOverride.apply()
    }

    var body: some Scene {
        Window("app.name", id: "main") {
            RootView()
                .preferredColorScheme(launchColorScheme)
        }
        .defaultSize(width: 1_180, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            StornautSettingsView()
                .preferredColorScheme(launchColorScheme)
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}

private enum LaunchAppearanceOverride {
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

    @MainActor
    static func apply() {
#if DEBUG
        switch value {
        case "light":
            NSApplication.shared.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        default:
            break
        }
#endif
    }

    private static var value: Substring? {
        let prefix = "--stornaut-ui-test-appearance="
        return CommandLine.arguments
            .first { $0.hasPrefix(prefix) }?
            .dropFirst(prefix.count)
    }
}
