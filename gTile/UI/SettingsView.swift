import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Text("General settings will go here.")
                .tabItem { Label("General", systemImage: "gear") }
                .frame(width: 450, height: 300)

            Text("Grid size presets will go here.")
                .tabItem { Label("Presets", systemImage: "grid") }

            Text("Inset settings will go here.")
                .tabItem { Label("Insets", systemImage: "arrow.up.left.and.arrow.down.right") }

            Text("Shortcut configuration will go here.")
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 450, height: 300)
    }
}
