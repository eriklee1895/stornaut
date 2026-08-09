import SwiftUI

struct StornautSettingsView: View {
    var body: some View {
        Form {
            LabeledContent("settings.language") {
                Text("settings.systemDefault")
                    .foregroundStyle(.secondary)
            }

            LabeledContent("settings.appearance") {
                Text("settings.systemDefault")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 260)
        .navigationTitle("settings.title")
        .accessibilityIdentifier("settings.content")
    }
}
