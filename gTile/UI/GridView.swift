import SwiftUI

/// Observable state for the grid, shared between GridView and OverlayController.
/// Using a class avoids @State being reset when the view is recreated.
final class GridInteractionState: ObservableObject {
    @Published var anchor: GridOffset?
    @Published var hoverTile: GridOffset?
}

/// SwiftUI view that renders an interactive 2D tile grid.
///
/// Selection modes:
/// 1. Click a tile to set anchor, click another tile to complete selection
/// 2. Click and drag from one tile to another
struct GridView: View {
    let gridSize: GridSize
    @Binding var selection: GridSelection?
    /// Called when hover changes, so the parent can update the preview window.
    var onHoverChanged: ((GridOffset?) -> Void)?
    let onSelectionComplete: ((GridSelection) -> Void)?
    @ObservedObject var interactionState: GridInteractionState

    private let tileSpacing: CGFloat = 2
    private let tileCornerRadius: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            let tileWidth = (geometry.size.width - tileSpacing * CGFloat(gridSize.cols - 1)) / CGFloat(gridSize.cols)
            let tileHeight = (geometry.size.height - tileSpacing * CGFloat(gridSize.rows - 1)) / CGFloat(gridSize.rows)

            VStack(spacing: tileSpacing) {
                ForEach(0..<gridSize.rows, id: \.self) { row in
                    HStack(spacing: tileSpacing) {
                        ForEach(0..<gridSize.cols, id: \.self) { col in
                            let offset = GridOffset(col: col, row: row)
                            let state = tileState(offset)

                            RoundedRectangle(cornerRadius: tileCornerRadius)
                                .fill(colorForState(state))
                                .frame(width: tileWidth, height: tileHeight)
                                .onHover { hovering in
                                    if hovering {
                                        interactionState.hoverTile = offset
                                        onHoverChanged?(offset)
                                    } else if interactionState.hoverTile == offset {
                                        interactionState.hoverTile = nil
                                        onHoverChanged?(nil)
                                    }
                                }
                                .onTapGesture {
                                    handleTap(offset)
                                }
                        }
                    }
                }
            }
        }
    }

    private enum TileState {
        case selected     // Part of confirmed selection
        case previewed    // Hover preview (anchor to cursor)
        case hovered      // Single tile hover (no anchor set)
        case normal       // Unselected
    }

    private func tileState(_ offset: GridOffset) -> TileState {
        // Check confirmed selection first
        if let selection = selection, isInRange(offset, from: selection.anchor, to: selection.target) {
            return .selected
        }
        // Check hover preview (anchor set, mouse hovering)
        if let anchor = interactionState.anchor, let hover = interactionState.hoverTile {
            if isInRange(offset, from: anchor, to: hover) {
                return .previewed
            }
        }
        // Single tile hover when no anchor
        if interactionState.anchor == nil && interactionState.hoverTile == offset {
            return .hovered
        }
        return .normal
    }

    private func isInRange(_ offset: GridOffset, from a: GridOffset, to b: GridOffset) -> Bool {
        let minCol = min(a.col, b.col)
        let maxCol = max(a.col, b.col)
        let minRow = min(a.row, b.row)
        let maxRow = max(a.row, b.row)
        return offset.col >= minCol && offset.col <= maxCol &&
               offset.row >= minRow && offset.row <= maxRow
    }

    private func colorForState(_ state: TileState) -> Color {
        switch state {
        case .selected:  return Color.accentColor.opacity(0.8)
        case .previewed: return Color.accentColor.opacity(0.45)
        case .hovered:   return Color.accentColor.opacity(0.3)
        case .normal:    return Color.white.opacity(0.08)
        }
    }

    private func handleTap(_ offset: GridOffset) {
        if let currentAnchor = interactionState.anchor {
            // Second click: complete the selection
            let newSelection = GridSelection(anchor: currentAnchor, target: offset)
            selection = newSelection
            interactionState.anchor = nil
            onSelectionComplete?(newSelection)
        } else {
            // First click: set anchor, show it highlighted
            interactionState.anchor = offset
            selection = GridSelection(anchor: offset, target: offset)
        }
    }
}
