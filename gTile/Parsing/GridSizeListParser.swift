import Foundation

/// A simple parser for parsing a list of user-specified grid sizes.
///
/// Attention: The parsed grid size is clamped to the interval [1, 64].
///
/// Grammar (using lexemes defined by `Literal`):
/// ```
/// List     := [ GridSize { "," GridSize } ] .
/// GridSize := Number "x" Number .
/// ```
///
/// Examples:
/// - ""
/// - " "
/// - "3x1"
/// - "2x1, 4x12"
/// - " 2 x8  , 3x 4 ,10  x2 "
final class GridSizeListParser: Parser {
    /// Parses the input provided during instance creation.
    ///
    /// - Returns: The parsed grid list or `nil` when a parser error occurred.
    func parse() -> [GridSize]? {
        do {
            token = try scanner.scan()
            return try parseList()
        } catch {
            print("Failed to parse grid-size list. Input: \"\(scanner.input)\". Error: \(error)")
            return nil
        }
    }

    private func parseList() throws -> [GridSize] {
        var gridSizes: [GridSize] = []

        switch token.kind {
        case .eof:
            return gridSizes
        case .number:
            repeat {
                gridSizes.append(try parseGridSize())
            } while try acceptIf(.separator)
            return gridSizes
        default:
            throw ParseError(message:
                "Unexpected token \"\(token.raw)\" (type: \(token.kind)) at pos \(token.position).")
        }
    }

    private func parseGridSize() throws -> GridSize {
        let cols = min(max(try parseNumber(), 1), 64)
        try accept(kind: .keyword, raw: "x")
        let rows = min(max(try parseNumber(), 1), 64)
        return GridSize(cols: cols, rows: rows)
    }

    private func parseNumber() throws -> Int {
        let raw = try accept(kind: .number)
        return Int(raw)!
    }
}
