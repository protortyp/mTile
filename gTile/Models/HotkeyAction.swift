import Foundation

/// Cardinal direction for movement and resize operations.
enum CardinalDirection: String, CaseIterable {
    case north, east, south, west
}

/// Resize/adjust mode.
enum AdjustMode: String {
    case extend, shrink
}

/// Autotile layout type.
enum AutoTileLayout: Equatable {
    case main
    case mainInverted
    case cols(Int)
}

/// A data structure that comprises a discriminative action and associated meta information.
/// Replaces the TypeScript discriminated union HotkeyAction.
enum HotkeyAction {
    /// Toggle gTile overlay.
    case toggle

    /// Close the gTile overlay and abort the current operation, if any.
    case cancel

    /// Apply the previewed window placement.
    case confirm

    /// Changes the current grid size by cycling through the available presets.
    case loopGridSize

    /// Move currently previewed grid selection in the desired direction by a single tile.
    case pan(CardinalDirection)

    /// Extend or shrink the current grid selection preview by one tile in the desired direction.
    case adjust(mode: AdjustMode, dir: CardinalDirection)

    /// Moves a window by at most one tile in the desired direction.
    case move(CardinalDirection)

    /// Expand or contract the specified edge of a window by at most one tile.
    case resize(mode: AdjustMode, dir: CardinalDirection)

    /// Move and resize a window to fill remaining space in all four cardinal directions.
    case grow

    /// Move and resize a window by looping through a list of user-defined preset specifications.
    case loopPreset(Int)

    /// Move the window to the neighbouring screen.
    case relocate

    /// Autotile all windows on a screen according to the desired layout.
    case autotile(AutoTileLayout)
}
