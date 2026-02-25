import XCTest
@testable import gTile

final class GridUtilitiesTests: XCTestCase {

    // MARK: - Pan Tests

    func testPanEast() {
        let selection = GridSelection(
            anchor: GridOffset(col: 1, row: 1),
            target: GridOffset(col: 2, row: 2)
        )
        let bounds = GridSize(cols: 4, rows: 4)
        let result = pan(selection, bounds: bounds, dir: .east)

        XCTAssertEqual(result.anchor.col, 2)
        XCTAssertEqual(result.anchor.row, 1)
        XCTAssertEqual(result.target.col, 3)
        XCTAssertEqual(result.target.row, 2)
    }

    func testPanWest() {
        let selection = GridSelection(
            anchor: GridOffset(col: 1, row: 1),
            target: GridOffset(col: 2, row: 2)
        )
        let bounds = GridSize(cols: 4, rows: 4)
        let result = pan(selection, bounds: bounds, dir: .west)

        XCTAssertEqual(result.anchor.col, 0)
        XCTAssertEqual(result.anchor.row, 1)
        XCTAssertEqual(result.target.col, 1)
        XCTAssertEqual(result.target.row, 2)
    }

    func testPanClampsAtBoundary() {
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 1, row: 1)
        )
        let bounds = GridSize(cols: 4, rows: 4)
        let result = pan(selection, bounds: bounds, dir: .west)

        XCTAssertEqual(result.anchor.col, 0)
        XCTAssertEqual(result.target.col, 1)
    }

    func testPanSouth() {
        let selection = GridSelection(
            anchor: GridOffset(col: 1, row: 1),
            target: GridOffset(col: 2, row: 2)
        )
        let bounds = GridSize(cols: 4, rows: 4)
        let result = pan(selection, bounds: bounds, dir: .south)

        XCTAssertEqual(result.anchor.row, 2)
        XCTAssertEqual(result.target.row, 3)
    }

    func testPanNorth() {
        let selection = GridSelection(
            anchor: GridOffset(col: 1, row: 1),
            target: GridOffset(col: 2, row: 2)
        )
        let bounds = GridSize(cols: 4, rows: 4)
        let result = pan(selection, bounds: bounds, dir: .north)

        XCTAssertEqual(result.anchor.row, 0)
        XCTAssertEqual(result.target.row, 1)
    }

    // MARK: - Adjust Tests

    func testAdjustExtendEast() {
        let selection = GridSelection(
            anchor: GridOffset(col: 1, row: 1),
            target: GridOffset(col: 2, row: 2)
        )
        let bounds = GridSize(cols: 4, rows: 4)
        let result = adjust(selection, bounds: bounds, dir: .east, mode: .extend)

        XCTAssertEqual(result.anchor.col, 1)
        XCTAssertEqual(result.target.col, 3)
    }

    func testAdjustShrinkEast() {
        let selection = GridSelection(
            anchor: GridOffset(col: 1, row: 1),
            target: GridOffset(col: 3, row: 2)
        )
        let bounds = GridSize(cols: 4, rows: 4)
        let result = adjust(selection, bounds: bounds, dir: .east, mode: .shrink)

        XCTAssertEqual(result.anchor.col, 1)
        XCTAssertEqual(result.target.col, 2)
    }

    func testAdjustExtendSouth() {
        let selection = GridSelection(
            anchor: GridOffset(col: 1, row: 1),
            target: GridOffset(col: 2, row: 2)
        )
        let bounds = GridSize(cols: 4, rows: 4)
        let result = adjust(selection, bounds: bounds, dir: .south, mode: .extend)

        XCTAssertEqual(result.anchor.row, 1)
        XCTAssertEqual(result.target.row, 3)
    }

    func testAdjustShrinkNorth() {
        let selection = GridSelection(
            anchor: GridOffset(col: 1, row: 0),
            target: GridOffset(col: 2, row: 2)
        )
        let bounds = GridSize(cols: 4, rows: 4)
        let result = adjust(selection, bounds: bounds, dir: .north, mode: .shrink)

        XCTAssertEqual(result.anchor.row, 1)
        XCTAssertEqual(result.target.row, 2)
    }

    func testAdjustExtendWest() {
        let selection = GridSelection(
            anchor: GridOffset(col: 2, row: 1),
            target: GridOffset(col: 3, row: 2)
        )
        let bounds = GridSize(cols: 4, rows: 4)
        let result = adjust(selection, bounds: bounds, dir: .west, mode: .extend)

        XCTAssertEqual(result.anchor.col, 1)
        XCTAssertEqual(result.target.col, 3)
    }

    func testAdjustClampsAtBoundary() {
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 3, row: 3)
        )
        let bounds = GridSize(cols: 4, rows: 4)

        // Extend east at max boundary
        let result = adjust(selection, bounds: bounds, dir: .east, mode: .extend)
        XCTAssertEqual(result.target.col, 3) // Already at max

        // Extend west at min boundary
        let result2 = adjust(selection, bounds: bounds, dir: .west, mode: .extend)
        XCTAssertEqual(result2.anchor.col, 0) // Already at min
    }

    func testAdjustNormalizesSelection() {
        // Selection with target NW of anchor (not normalized)
        let selection = GridSelection(
            anchor: GridOffset(col: 3, row: 3),
            target: GridOffset(col: 1, row: 1)
        )
        let bounds = GridSize(cols: 4, rows: 4)
        let result = adjust(selection, bounds: bounds, dir: .east, mode: .extend)

        // Should normalize: anchor becomes NW, target becomes SE
        XCTAssertEqual(result.anchor.col, 1)
        XCTAssertEqual(result.anchor.row, 1)
        XCTAssertEqual(result.target.col, 3)
        XCTAssertEqual(result.target.row, 3)
    }
}
