import SwiftUI

@main
struct GTileApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("gTile", systemImage: "grid") {
            MenuBarView()
        }

        Settings {
            SettingsView()
        }
    }
}
