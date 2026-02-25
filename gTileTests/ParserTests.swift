import XCTest
@testable import gTile

final class ScannerTests: XCTestCase {

    func testScansEmptyInput() throws {
        let scanner = Scanner(input: "")
        let token = try scanner.scan()
        XCTAssertEqual(token.kind, .eof)
    }

    func testScansTokenStream() throws {
        let scanner = Scanner(input: "(multiply (add 12390 2) (add 3 2))")
        let expected: [(Literal, String?)] = [
            (.lParen, nil),
            (.keyword, "multiply"),
            (.lParen, nil),
            (.keyword, "add"),
            (.number, "12390"),
            (.number, "2"),
            (.rParen, nil),
            (.lParen, nil),
            (.keyword, "add"),
            (.number, "3"),
            (.number, "2"),
            (.rParen, nil),
            (.rParen, nil),
            (.eof, nil),
        ]

        for (kind, raw) in expected {
            let token = try scanner.scan()
            XCTAssertEqual(token.kind, kind)
            if let raw = raw {
                XCTAssertEqual(token.raw, raw)
            }
        }
    }

    func testScansPresetFormat() throws {
        let scanner = Scanner(input: "3x3 1:1 1:1")
        let expected: [(Literal, String?)] = [
            (.number, "3"),
            (.keyword, "x"),
            (.number, "3"),
            (.number, "1"),
            (.colon, nil),
            (.number, "1"),
            (.number, "1"),
            (.colon, nil),
            (.number, "1"),
            (.eof, nil),
        ]

        for (kind, raw) in expected {
            let token = try scanner.scan()
            XCTAssertEqual(token.kind, kind)
            if let raw = raw {
                XCTAssertEqual(token.raw, raw)
            }
        }
    }

    func testThrowsOnInvalidCharacter() {
        let scanner = Scanner(input: "3x3 1:1 1:A")
        XCTAssertThrowsError(try {
            while true {
                let token = try scanner.scan()
                if token.kind == .eof { break }
            }
        }())
    }
}

final class GridSizeListParserTests: XCTestCase {

    func testParsesEmptyInput() {
        XCTAssertEqual(GridSizeListParser(input: "").parse(), [])
        XCTAssertEqual(GridSizeListParser(input: " ").parse(), [])
    }

    func testParsesSingleGridSize() {
        let result = GridSizeListParser(input: "3x1").parse()
        XCTAssertEqual(result, [GridSize(cols: 3, rows: 1)])
    }

    func testParsesMultipleGridSizes() {
        let result = GridSizeListParser(input: "2x1, 4x12").parse()
        XCTAssertEqual(result, [
            GridSize(cols: 2, rows: 1),
            GridSize(cols: 4, rows: 12),
        ])
    }

    func testParsesWithWhitespace() {
        let result = GridSizeListParser(input: " 2 x8  , 3x 4 ,10  x2 ").parse()
        XCTAssertEqual(result, [
            GridSize(cols: 2, rows: 8),
            GridSize(cols: 3, rows: 4),
            GridSize(cols: 10, rows: 2),
        ])
    }

    func testClampsValues() {
        let result = GridSizeListParser(input: "600x800").parse()
        XCTAssertEqual(result, [GridSize(cols: 64, rows: 64)])
    }
}

final class ResizePresetListParserTests: XCTestCase {

    func testParsesEmptyInput() {
        XCTAssertEqual(ResizePresetListParser(input: "").parse(), [])
        XCTAssertEqual(ResizePresetListParser(input: " ").parse(), [])
    }

    func testParsesShortNotation() {
        // Short notation reuses the grid size from the previous preset
        let a = ResizePresetListParser(input: "3x3 1:1 2:2, 2x2 1:1 1:1     2:2 2:2").parse()
        let b = ResizePresetListParser(input: "3x3 1:1 2:2, 2x2 1:1 1:1 2x2 2:2 2:2").parse()
        XCTAssertNotNil(a)
        XCTAssertNotNil(b)
        XCTAssertEqual(a, b)
    }

    func testParsesShortNotation2() {
        let a = ResizePresetListParser(input: "3x3 1:1 2:2,     1:1 1:1, 4x4 1:1 1:1,     1:3 4:4").parse()
        let b = ResizePresetListParser(input: "3x3 1:1 2:2, 3x3 1:1 1:1, 4x4 1:1 1:1, 4x4 1:3 4:4").parse()
        XCTAssertNotNil(a)
        XCTAssertNotNil(b)
        XCTAssertEqual(a, b)
    }

    func testParsesCorrectly() {
        let result = ResizePresetListParser(input: "11x17 4:6 8:10").parse()
        XCTAssertEqual(result, [
            Preset(
                gridSize: GridSize(cols: 11, rows: 17),
                selection: GridSelection(
                    anchor: GridOffset(col: 3, row: 5),
                    target: GridOffset(col: 7, row: 9)
                )
            )
        ])
    }

    func testParsesComplexInput() {
        let result = ResizePresetListParser(input: "8x8 3:3 6:6, 2:2 7:7,1:1 8:8,16x16 6:6 10:10").parse()
        XCTAssertEqual(result, [
            Preset(
                gridSize: GridSize(cols: 8, rows: 8),
                selection: GridSelection(
                    anchor: GridOffset(col: 2, row: 2),
                    target: GridOffset(col: 5, row: 5)
                )
            ),
            Preset(
                gridSize: GridSize(cols: 8, rows: 8),
                selection: GridSelection(
                    anchor: GridOffset(col: 1, row: 1),
                    target: GridOffset(col: 6, row: 6)
                )
            ),
            Preset(
                gridSize: GridSize(cols: 8, rows: 8),
                selection: GridSelection(
                    anchor: GridOffset(col: 0, row: 0),
                    target: GridOffset(col: 7, row: 7)
                )
            ),
            Preset(
                gridSize: GridSize(cols: 16, rows: 16),
                selection: GridSelection(
                    anchor: GridOffset(col: 5, row: 5),
                    target: GridOffset(col: 9, row: 9)
                )
            ),
        ])
    }

    func testHandlesInvalidSpecs() {
        let invalidInputs = [
            "0x0 3:3 3:3",
            "0x1 3:3 3:3",
            "1x0 3:3 3:3",
            "3:3 0:0",
            "3:3 0:1",
            "3:3 1:0",
            "3:b 1:1",
            "3x3 1:b 1:1",
            "3xa 1:1 1:1",
            "3x3 1:a 1:1",
            "3x3 1:1 1:a",
            "xx3 1:1 1:1",
            "3x3 x:1 1:1",
            "3x3 1:1 x:1",
            "bx3 1:1 1:1",
            "3x3 b:1 1:1",
            "3x3 1:1 b:1",
        ]

        for input in invalidInputs {
            XCTAssertNil(
                ResizePresetListParser(input: input).parse(),
                "Expected nil for input: \"\(input)\""
            )
        }
    }
}

final class GridSpecParserTests: XCTestCase {

    func testParsesEmptyInput() {
        let result = GridSpecParser(input: "").parse()
        XCTAssertEqual(result, GridSpec(mode: .cols, cells: []))
    }

    func testParsesSimpleRows() {
        let result = GridSpecParser(input: "rows(3, 1)").parse()
        XCTAssertEqual(result, GridSpec(mode: .rows, cells: [
            GridCellSpec(weight: 3, dynamic: false, child: nil),
            GridCellSpec(weight: 1, dynamic: false, child: nil),
        ]))
    }

    func testParsesDynamicCells() {
        let result = GridSpecParser(input: "cols(2, 2d)").parse()
        XCTAssertEqual(result, GridSpec(mode: .cols, cells: [
            GridCellSpec(weight: 2, dynamic: false, child: nil),
            GridCellSpec(weight: 2, dynamic: true, child: nil),
        ]))
    }

    func testParsesNestedSpec() {
        let result = GridSpecParser(input: "cols(2:rows(1,2d,1), 2:rows(1,2:rows(1,1),1))").parse()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.mode, .cols)
        XCTAssertEqual(result?.cells.count, 2)

        // First cell: cols weight 2 with rows(1, 2d, 1)
        let first = result?.cells[0]
        XCTAssertEqual(first?.weight, 2)
        XCTAssertEqual(first?.child?.mode, .rows)
        XCTAssertEqual(first?.child?.cells.count, 3)
        XCTAssertEqual(first?.child?.cells[1].dynamic, true)

        // Second cell: cols weight 2 with rows(1, 2:rows(1,1), 1)
        let second = result?.cells[1]
        XCTAssertEqual(second?.weight, 2)
        XCTAssertEqual(second?.child?.mode, .rows)
        XCTAssertEqual(second?.child?.cells[1].child?.mode, .rows)
    }

    func testHandlesInvalidInput() {
        XCTAssertNil(GridSpecParser(input: "invalid(1, 2)").parse())
        XCTAssertNil(GridSpecParser(input: "cols(").parse())
    }
}
