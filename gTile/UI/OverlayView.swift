import SwiftUI

/// Main overlay view combining title bar, grid, preset bar, and action bar.
///
/// This is the SwiftUI equivalent of gTile's Overlay container, composed of
/// TitleBar + Grid + PresetBar + ActionBar.
struct OverlayView: View {
    let title: String
    let presets: [GridSize]
    @Binding var gridSize: GridSize
    @Binding var selection: GridSelection?
    @Binding var hoverTile: GridOffset?

    let onSelectionComplete: ((GridSelection) -> Void)?
    let onAutotile: ((AutoTileLayout) -> Void)?
    let onToggleAutoClose: (() -> Void)?
    let onToggleFollowCursor: (() -> Void)?

    @State private var presetIndex: Int = 0

    var body: some View {
        VStack(spacing: 8) {
            // Title Bar
            titleBar

            // Grid
            GridView(
                gridSize: gridSize,
                selection: $selection,
                hoverTile: $hoverTile,
                onSelectionComplete: onSelectionComplete
            )
            .frame(height: 150)

            // Preset Bar
            presetBar

            // Action Bar
            actionBar
        }
        .padding(12)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        )
        .frame(width: 280)
    }

    private var titleBar: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text("\(gridSize.cols)x\(gridSize.rows)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    private var presetBar: some View {
        HStack(spacing: 4) {
            ForEach(Array(presets.enumerated()), id: \.offset) { index, preset in
                Button {
                    gridSize = preset
                    presetIndex = index
                    selection = nil
                } label: {
                    Text("\(preset.cols)x\(preset.rows)")
                        .font(.system(size: 10, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.bordered)
                .tint(gridSize == preset ? .accentColor : nil)
            }

            Spacer()
        }
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            // Autotile buttons
            Button {
                onAutotile?(.main)
            } label: {
                Image(systemName: "rectangle.split.2x1")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help("Autotile: Main + List")

            Button {
                onAutotile?(.mainInverted)
            } label: {
                Image(systemName: "rectangle.split.2x1")
                    .font(.system(size: 12))
                    .scaleEffect(x: -1)
            }
            .buttonStyle(.borderless)
            .help("Autotile: List + Main")

            Spacer()

            // Toggle buttons
            Button {
                onToggleFollowCursor?()
            } label: {
                Image(systemName: "cursorarrow.motionlines")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help("Follow Cursor")

            Button {
                onToggleAutoClose?()
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help("Auto Close")
        }
    }
}

/// NSVisualEffectView wrapper for SwiftUI.
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
