import SwiftUI

/// Main overlay view combining title bar, grid, preset bar, and action bar.
struct OverlayView: View {
    let title: String
    let presets: [GridSize]
    @Binding var gridSize: GridSize
    @Binding var selection: GridSelection?
    @ObservedObject var interactionState: GridInteractionState

    let onSelectionComplete: ((GridSelection) -> Void)?
    var onHoverChanged: ((GridOffset?) -> Void)?
    let onAutotile: ((AutoTileLayout) -> Void)?
    let onClose: (() -> Void)?
    let onToggleAutoClose: (() -> Void)?
    let onToggleFollowCursor: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            // Title Bar
            titleBar

            // Grid
            GridView(
                gridSize: gridSize,
                selection: $selection,
                onHoverChanged: onHoverChanged,
                onSelectionComplete: onSelectionComplete,
                interactionState: interactionState
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

            Button {
                onClose?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
        }
    }

    private var presetBar: some View {
        HStack(spacing: 4) {
            ForEach(Array(presets.enumerated()), id: \.offset) { index, preset in
                Button {
                    gridSize = preset
                    selection = nil
                    interactionState.anchor = nil
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
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help("Auto Close after placement")
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
