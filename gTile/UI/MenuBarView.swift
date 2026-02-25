import SwiftUI

struct MenuBarView: View {
    var body: some View {
        Button("Toggle Overlay") {
            // TODO: Wire to AppCoordinator
        }
        .keyboardShortcut("g", modifiers: [.command, .option])

        Divider()

        SettingsLink {
            Text("Settings...")
        }

        Divider()

        Button("Quit gTile") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
