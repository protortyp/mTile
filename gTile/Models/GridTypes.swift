import Foundation

/// Represents a margin with a specified thickness in pixels.
struct Inset: Equatable, Codable {
    var top: Int
    var right: Int
    var bottom: Int
    var left: Int

    static let zero = Inset(top: 0, right: 0, bottom: 0, left: 0)
}

/// Data structure that represents an area on a 2D plane.
///
/// The `x` and `y` coordinates identify the north-west corner of the
/// rectangle, assuming that the origin of the plane is also in the north-west
/// corner and has coordinates (0, 0).
struct Rectangle: Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var area: Double { width * height }

    /// Returns true if this rectangle fully contains the other rectangle.
    func contains(_ other: Rectangle) -> Bool {
        other.x >= x &&
        other.y >= y &&
        other.x + other.width <= x + width &&
        other.y + other.height <= y + height
    }

    /// Returns the intersection of this rectangle with another, or nil if they don't intersect.
    func intersection(_ other: Rectangle) -> Rectangle? {
        let ix = max(x, other.x)
        let iy = max(y, other.y)
        let iw = min(x + width, other.x + other.width) - ix
        let ih = min(y + height, other.y + other.height) - iy

        guard iw > 0 && ih > 0 else { return nil }
        return Rectangle(x: ix, y: iy, width: iw, height: ih)
    }

    /// Returns true if this rectangle intersects with the other rectangle.
    func intersects(_ other: Rectangle) -> Bool {
        intersection(other) != nil
    }
}

/// The dimensions of a grid in terms of columns and rows.
struct GridSize: Equatable, Hashable, Codable {
    var cols: Int
    var rows: Int
}

/// Represents a location inside a grid. The north-west corner of the grid is
/// considered the origin of the grid with an offset of (0, 0).
struct GridOffset: Equatable, Codable {
    var col: Int
    var row: Int
}

/// Represents a rectangular selection inside a grid.
///
/// `anchor` represents the origin of a selection and `target` represents the
/// ending point of a selection.
///
/// Unless explicitly stated otherwise, selections are not normalized and can be
/// ambiguous. For instance, the following selections are all semantically
/// equivalent:
///
///   - `GridSelection(anchor: (2, 1), target: (3, 2))`
///   - `GridSelection(anchor: (3, 1), target: (2, 2))`
///   - `GridSelection(anchor: (2, 2), target: (3, 1))`
///   - `GridSelection(anchor: (3, 2), target: (2, 1))`
struct GridSelection: Equatable {
    var anchor: GridOffset
    var target: GridOffset
}
