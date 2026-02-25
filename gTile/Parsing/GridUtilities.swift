import Foundation

/// Default grid sizes used when no user configuration is provided.
let DefaultGridSizes: [GridSize] = [
    GridSize(cols: 8, rows: 6),
    GridSize(cols: 6, rows: 4),
    GridSize(cols: 4, rows: 4),
]

/// Moves a selection towards a direction within the specified boundary.
///
/// - Parameters:
///   - selection: The selection to be panned.
///   - bounds: The grid boundaries within which the selection can be panned.
///   - dir: The cardinal direction in which to move the selection.
/// - Returns: The new selection after performing the pan operation.
func pan(
    _ selection: GridSelection,
    bounds: GridSize,
    dir: CardinalDirection
) -> GridSelection {
    let colOffset = dir == .east ? 1 : dir == .west ? -1 : 0
    let rowOffset = dir == .south ? 1 : dir == .north ? -1 : 0
    let maxCol = bounds.cols - 1
    let maxRow = bounds.rows - 1

    let anchorCol = clamp(selection.anchor.col + colOffset, min: 0, max: maxCol)
    let anchorRow = clamp(selection.anchor.row + rowOffset, min: 0, max: maxRow)
    let targetCol = clamp(selection.target.col + colOffset, min: 0, max: maxCol)
    let targetRow = clamp(selection.target.row + rowOffset, min: 0, max: maxRow)

    return GridSelection(
        anchor: GridOffset(col: anchorCol, row: anchorRow),
        target: GridOffset(col: targetCol, row: targetRow)
    )
}

/// Adjusts a selection by shrinking or extending it by one tile towards a
/// direction and within the specified boundaries.
///
/// - Parameters:
///   - selection: The selection to be adjusted.
///   - bounds: The grid boundaries that the selection must not exceed.
///   - dir: The edge of the selection that shall be shrunk or extended.
///   - mode: Whether to shrink or extend the selection.
/// - Returns: The adjusted selection with a NW anchor and SE target.
func adjust(
    _ selection: GridSelection,
    bounds: GridSize,
    dir: CardinalDirection,
    mode: AdjustMode
) -> GridSelection {
    var anchor = GridOffset(
        col: min(selection.anchor.col, selection.target.col),
        row: min(selection.anchor.row, selection.target.row)
    )
    var target = GridOffset(
        col: max(selection.anchor.col, selection.target.col),
        row: max(selection.anchor.row, selection.target.row)
    )

    let rel: Int = {
        switch (dir, mode) {
        case (.north, .shrink), (.east, .extend), (.south, .extend), (.west, .shrink):
            return 1
        default:
            return -1
        }
    }()

    switch dir {
    case .north:
        anchor.row = clamp(anchor.row + rel, min: 0, max: target.row)
    case .east:
        target.col = clamp(target.col + rel, min: anchor.col, max: bounds.cols - 1)
    case .south:
        target.row = clamp(target.row + rel, min: anchor.row, max: bounds.rows - 1)
    case .west:
        anchor.col = clamp(anchor.col + rel, min: 0, max: target.col)
    }

    return GridSelection(anchor: anchor, target: target)
}

/// Clamps a value to the given range [min, max].
func clamp(_ value: Int, min minVal: Int, max maxVal: Int) -> Int {
    max(minVal, min(maxVal, value))
}

/// Clamps a Double value to the given range [min, max].
func clamp(_ value: Double, min minVal: Double, max maxVal: Double) -> Double {
    max(minVal, min(maxVal, value))
}
