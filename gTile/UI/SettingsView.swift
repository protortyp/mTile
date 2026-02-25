import SwiftUI

struct SettingsView: View {
    @State private var preferences = UserPreferences()

    var body: some View {
        TabView {
            GeneralSettingsTab(preferences: preferences)
                .tabItem { Label("General", systemImage: "gear") }

            InsetSettingsTab(preferences: preferences)
                .tabItem { Label("Insets", systemImage: "arrow.up.left.and.arrow.down.right") }

            PresetSettingsTab(preferences: preferences)
                .tabItem { Label("Presets", systemImage: "grid") }

            AutotileSettingsTab(preferences: preferences)
                .tabItem { Label("Autotile", systemImage: "rectangle.split.3x3") }

            ShortcutsSettingsTab()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 520, height: 400)
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @Bindable var preferences: UserPreferences

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Auto-close overlay after placing window", isOn: $preferences.autoClose)
                Toggle("Auto-maximize when selection fills grid", isOn: $preferences.autoMaximize)
                Toggle("Follow cursor (place overlay at cursor)", isOn: $preferences.followCursor)
                Toggle("Show grid lines preview", isOn: $preferences.showGridLines)
                Toggle("Target presets to monitor of mouse", isOn: $preferences.targetPresetsToMonitorOfMouse)
            }

            Section("Window Spacing") {
                HStack {
                    Text("Spacing between windows:")
                    TextField("", value: $preferences.windowSpacing, format: .number)
                        .frame(width: 60)
                    Text("px")
                }
            }

            Section("Grid Sizes") {
                HStack {
                    Text("Sizes (e.g. 8x6, 6x4, 4x4):")
                    TextField("", text: $preferences.gridSizes)
                        .frame(minWidth: 200)
                }
            }

            Section("Global Shortcuts") {
                Toggle("Enable autotile shortcuts globally", isOn: $preferences.globalAutoTiling)
                Toggle("Enable preset shortcuts globally", isOn: $preferences.globalPresets)
                Toggle("Enable move/resize shortcuts globally", isOn: $preferences.moveResizeEnabled)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Insets Tab

struct InsetSettingsTab: View {
    @Bindable var preferences: UserPreferences

    var body: some View {
        Form {
            Section("Primary Monitor Insets") {
                insetFields(
                    top: $preferences.insetsPrimaryTop,
                    right: $preferences.insetsPrimaryRight,
                    bottom: $preferences.insetsPrimaryBottom,
                    left: $preferences.insetsPrimaryLeft
                )
            }

            Section("Secondary Monitor Insets") {
                insetFields(
                    top: $preferences.insetsSecondaryTop,
                    right: $preferences.insetsSecondaryRight,
                    bottom: $preferences.insetsSecondaryBottom,
                    left: $preferences.insetsSecondaryLeft
                )
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func insetFields(
        top: Binding<Int>,
        right: Binding<Int>,
        bottom: Binding<Int>,
        left: Binding<Int>
    ) -> some View {
        Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text("Top:")
                TextField("", value: top, format: .number)
                    .frame(width: 60)
                Text("px")
            }
            GridRow {
                Text("Right:")
                TextField("", value: right, format: .number)
                    .frame(width: 60)
                Text("px")
            }
            GridRow {
                Text("Bottom:")
                TextField("", value: bottom, format: .number)
                    .frame(width: 60)
                Text("px")
            }
            GridRow {
                Text("Left:")
                TextField("", value: left, format: .number)
                    .frame(width: 60)
                Text("px")
            }
        }
    }
}

// MARK: - Presets Tab

struct PresetSettingsTab: View {
    @Bindable var preferences: UserPreferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Resize Presets")
                    .font(.headline)

                Text("Format: GridSize Selection [, Selection | GridSize Selection ...]")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Example: 4x4 1:3 2:4, 1:2 3:4, 1:1 4:4")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(1...30, id: \.self) { index in
                    HStack {
                        Text("Preset \(index):")
                            .frame(width: 70, alignment: .trailing)
                            .font(.system(.body, design: .monospaced))

                        TextField("e.g. 4x4 1:1 2:2", text: Binding(
                            get: { preferences.resizePreset(index) },
                            set: { preferences.setResizePreset(index, value: $0) }
                        ))
                        .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Autotile Tab

struct AutotileSettingsTab: View {
    @Bindable var preferences: UserPreferences

    var body: some View {
        Form {
            Section("Main Window Ratios") {
                HStack {
                    Text("Ratios (comma-separated):")
                    TextField("", text: $preferences.autotileMainWindowRatios)
                        .frame(minWidth: 200)
                }
                Text("e.g. 0.5,0.6,0.65,0.7 — cycles through main/side ratios")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("GridSpec Presets") {
                Text("DSL format: cols(weight, weight:rows(w,wd,w), ...)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(1...10, id: \.self) { index in
                    HStack {
                        Text("Layout \(index):")
                            .frame(width: 80, alignment: .trailing)

                        TextField("e.g. cols(1, 1)", text: Binding(
                            get: { preferences.autotileGridSpec(index) },
                            set: { preferences.setAutotileGridSpec(index, value: $0) }
                        ))
                        .font(.system(.body, design: .monospaced))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Shortcuts Tab

struct ShortcutsSettingsTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Keyboard Shortcuts")
                .font(.headline)

            Text("Shortcut recording will be available via the KeyboardShortcuts package.")
                .foregroundStyle(.secondary)

            Text("Default: ⌘⌥G to toggle overlay")
                .font(.callout)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
