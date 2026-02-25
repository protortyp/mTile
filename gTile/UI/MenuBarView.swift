import SwiftUI

struct MenuBarView: View {
    var body: some View {
        Button("Toggle Overlay") {
            AppCoordinator.shared?.onAction(.toggle)
        }
        .keyboardShortcut("g", modifiers: [.command, .option])

        Divider()

        Button("Snap to Neighbors") {
            AppCoordinator.shared?.onAction(.grow)
        }

        Menu("Autotile") {
            Button("Main Layout") {
                AppCoordinator.shared?.onAction(.autotile(.main))
            }
            Button("Main Inverted") {
                AppCoordinator.shared?.onAction(.autotile(.mainInverted))
            }
        }

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
