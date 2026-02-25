import SwiftUI

/// SwiftUI view that renders an interactive 2D tile grid.
///
/// Supports click-anchor-then-click-target interaction for selecting
/// a rectangular region of tiles, with hover preview.
struct GridView: View {
    let gridSize: GridSize
    @Binding var selection: GridSelection?
    @Binding var hoverTile: GridOffset?
    let onSelectionComplete: ((GridSelection) -> Void)?

    @State private var anchor: GridOffset?

    private let tileSpacing: CGFloat = 2
    private let tileCornerRadius: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            let tileWidth = (geometry.size.width - tileSpacing * CGFloat(gridSize.cols - 1)) / CGFloat(gridSize.cols)
            let tileHeight = (geometry.size.height - tileSpacing * CGFloat(gridSize.rows - 1)) / CGFloat(gridSize.rows)

            ZStack(alignment: .topLeading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.2))

                // Grid tiles
                ForEach(0..<gridSize.rows, id: \.self) { row in
                    ForEach(0..<gridSize.cols, id: \.self) { col in
                        let offset = GridOffset(col: col, row: row)
                        let isSelected = isTileSelected(offset)
                        let isHovered = isTileHovered(offset)

                        RoundedRectangle(cornerRadius: tileCornerRadius)
                            .fill(tileColor(selected: isSelected, hovered: isHovered))
                            .frame(width: tileWidth, height: tileHeight)
                            .offset(
                                x: CGFloat(col) * (tileWidth + tileSpacing),
                                y: CGFloat(row) * (tileHeight + tileSpacing)
                            )
                            .onHover { hovering in
                                if hovering {
                                    hoverTile = offset
                                } else if hoverTile == offset {
                                    hoverTile = nil
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

    private func tileColor(selected: Bool, hovered: Bool) -> Color {
        if selected {
            return Color.accentColor.opacity(0.7)
        } else if hovered {
            return Color.accentColor.opacity(0.3)
        } else {
            return Color.gray.opacity(0.3)
        }
    }

    private func isTileSelected(_ offset: GridOffset) -> Bool {
        guard let selection = selection else { return false }
        let minCol = min(selection.anchor.col, selection.target.col)
        let maxCol = max(selection.anchor.col, selection.target.col)
        let minRow = min(selection.anchor.row, selection.target.row)
        let maxRow = max(selection.anchor.row, selection.target.row)

        return offset.col >= minCol && offset.col <= maxCol &&
               offset.row >= minRow && offset.row <= maxRow
    }

    private func isTileHovered(_ offset: GridOffset) -> Bool {
        guard let anchor = anchor, let hover = hoverTile else {
            return hoverTile == offset
        }

        // When we have an anchor, show preview of the selection
        let minCol = min(anchor.col, hover.col)
        let maxCol = max(anchor.col, hover.col)
        let minRow = min(anchor.row, hover.row)
        let maxRow = max(anchor.row, hover.row)

        return offset.col >= minCol && offset.col <= maxCol &&
               offset.row >= minRow && offset.row <= maxRow
    }

    private func handleTap(_ offset: GridOffset) {
        if let currentAnchor = anchor {
            // Second click: complete the selection
            let newSelection = GridSelection(anchor: currentAnchor, target: offset)
            selection = newSelection
            anchor = nil
            onSelectionComplete?(newSelection)
        } else {
            // First click: set anchor
            anchor = offset
            selection = GridSelection(anchor: offset, target: offset)
        }
    }
}
