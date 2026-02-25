import Foundation

/// Describes a set of adjacent rows or columns of a grid.
struct GridSpec: Equatable {
    let mode: GridSpecMode
    let cells: [GridCellSpec]

    enum GridSpecMode: String, Equatable {
        case cols, rows
    }
}

/// Ultimately describes a cell inside a grid.
///
/// The weight of a cell is used to calculate how much space it claims in
/// relation to its siblings. The sum of weights amongst siblings is used as
/// normalization factor.
///
/// A cell can be declared as dynamic which means it can be the target for
/// multiple windows that are to be placed in the cell. Each window then claims
/// the same fraction of the available cell space.
///
/// A cell can alternatively act as a container for a sub-grid.
/// In that case it cannot be dynamic.
struct GridCellSpec: Equatable {
    let weight: Int
    let dynamic: Bool
    let child: GridSpec?
}

/// A parser for GridSpecs. A grid spec is a very simple DSL that allows
/// defining a grid in terms of a hierarchy of child rows and columns.
///
/// Grammar:
/// ```
/// gridspec := [ ( colspec | rowspec ) ] .
/// colspec  := "cols" "(" cellspec { "," cellspec } ")" .
/// rowspec  := "rows" "(" cellspec { "," cellspec } ")" .
/// cellspec := <number> [ ( "d" | ":" ( colspec | rowspec ) ) ] .
/// ```
///
/// Examples:
/// - ""            - describes a single-cell grid with 100% width and height
/// - "rows(3, 1)"  - describes a grid with 2 rows that take 75% and 25% height.
/// - "cols(2, 2d)" - describes a grid with 2 cells (one dynamic) each 50% width.
/// - "cols(2:rows(1,2d,1), 2:rows(1,2:rows(1,1),1))"
final class GridSpecParser: Parser {
    /// Parses the input provided during instance creation.
    ///
    /// - Returns: The parsed GridSpec or `nil` when a parser error occurred.
    func parse() -> GridSpec? {
        do {
            token = try scanner.scan()
            return try parseGridSpec()
        } catch {
            print("Failed to parse GridSpec. Input: \"\(scanner.input)\". Error: \(error)")
            return nil
        }
    }

    private func parseGridSpec() throws -> GridSpec {
        switch token.kind {
        case .eof:
            return GridSpec(mode: .cols, cells: [])
        case .keyword:
            return try parseColRowSpec()
        default:
            throw ParseError(message:
                "Unexpected token \"\(token.raw)\" (type: \(token.kind)) at pos \(token.position).")
        }
    }

    private func parseColRowSpec() throws -> GridSpec {
        guard token.kind == .keyword else {
            throw ParseError(message:
                "Unexpected token \"\(token.raw)\" (type: \(token.kind)) at pos \(token.position).")
        }

        let modeStr = token.raw
        guard modeStr == "cols" || modeStr == "rows" else {
            throw ParseError(message:
                "Unexpected token \"\(token.raw)\" (type: \(token.kind)) at pos \(token.position).")
        }

        let mode: GridSpec.GridSpecMode = modeStr == "cols" ? .cols : .rows
        try accept()
        try accept(kind: .lParen)

        var cells: [GridCellSpec] = []
        repeat {
            cells.append(try parseCellSpec())
        } while try acceptIf(.separator)

        try accept(kind: .rParen)

        return GridSpec(mode: mode, cells: cells)
    }

    private func parseCellSpec() throws -> GridCellSpec {
        let weight = try parseNumber()
        var dynamic = false
        var child: GridSpec? = nil

        if token.kind == .keyword && token.raw == "d" {
            try accept()
            dynamic = true
        } else if try acceptIf(.colon) {
            child = try parseColRowSpec()
        }

        return GridCellSpec(weight: weight, dynamic: dynamic, child: child)
    }

    private func parseNumber() throws -> Int {
        let raw = try accept(kind: .number)
        return Int(raw)!
    }
}
