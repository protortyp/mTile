import Foundation

/// Represents a selection bound to a particular grid.
struct Preset: Equatable {
    let gridSize: GridSize
    let selection: GridSelection
}

/// A simple parser for parsing a list of user-specified resize presets.
///
/// ATTENTION: The parsed offset is revised by -1.
/// Currently, the user specifies the tile offset as 1-based index while this
/// codebase uses 0-based indexes for all calculations. The parser does revise
/// the offset for convenience.
///
/// Grammar (using lexemes defined by `Literal`):
/// ```
/// S         := [ Preset { "," ( Preset | Selection ) } ] .
/// Preset    := GridSize Selection .
/// Selection := Offset Offset .
/// GridSize  := Number "x" Number .
/// Offset    := Number ":" Number .
/// ```
///
/// Implementation detail:
/// The grammar above requires LL(2). The implementation uses a refactored
/// grammar that is LL(1):
/// ```
/// S                 := [ GridSize Selection { "," PresetOrSelection } ] .
/// PresetOrSelection := Number ( "x" Number Selection | ":" Number Offset ) .
/// Selection         := Offset Offset .
/// GridSize          := Number "x" Number .
/// Offset            := Number ":" Number .
/// ```
final class ResizePresetListParser: Parser {
    /// Parses the input provided during instance creation.
    ///
    /// Automatically revises the parsed 1-based offsets to 0-based offsets.
    ///
    /// - Returns: The parsed presets or `nil` when a parser error occurred.
    func parse() -> [Preset]? {
        do {
            token = try scanner.scan()
            return try parseList()
        } catch {
            print("Failed to parse preset list. Input: \"\(scanner.input)\". Error: \(error)")
            return nil
        }
    }

    private func parseList() throws -> [Preset] {
        var presets: [Preset] = []

        switch token.kind {
        case .eof:
            return presets
        case .number:
            let gridSize = try parseGridSize()
            let selection = try parseSelection()
            presets.append(Preset(gridSize: gridSize, selection: selection))

            while try acceptIf(.separator) {
                let result = try parsePresetOrSelection()
                switch result {
                case .preset(let preset):
                    presets.append(preset)
                case .selection(let selection):
                    let lastGridSize = presets[presets.count - 1].gridSize
                    presets.append(Preset(gridSize: lastGridSize, selection: selection))
                }
            }

            return presets
        default:
            throw ParseError(message:
                "Unexpected token \"\(token.raw)\" (type: \(token.kind)) at pos \(token.position).")
        }
    }

    private enum PresetOrSelection {
        case preset(Preset)
        case selection(GridSelection)
    }

    private func parsePresetOrSelection() throws -> PresetOrSelection {
        let num = try parseNumber()

        switch token.kind {
        case .keyword:
            try accept(kind: .keyword, raw: "x")
            let rows = try parseNumber()
            let selection = try parseSelection()
            return .preset(Preset(
                gridSize: GridSize(cols: num, rows: rows),
                selection: selection
            ))
        case .colon:
            try accept()
            let row = try parseNumber()
            let target = try parseOffset()
            return .selection(GridSelection(
                // Revise by -1 due to 0-based index used throughout the code.
                anchor: GridOffset(col: num - 1, row: row - 1),
                target: target
            ))
        default:
            throw ParseError(message:
                "Unexpected token \"\(token.raw)\" (type: \(token.kind)) at pos \(token.position).")
        }
    }

    private func parseSelection() throws -> GridSelection {
        let anchor = try parseOffset()
        let target = try parseOffset()
        return GridSelection(anchor: anchor, target: target)
    }

    private func parseGridSize() throws -> GridSize {
        let cols = try parseNumber()
        try accept(kind: .keyword, raw: "x")
        let rows = try parseNumber()
        return GridSize(cols: cols, rows: rows)
    }

    private func parseOffset() throws -> GridOffset {
        // Revise by -1 due to 0-based index used throughout the code.
        // Note that a number is defined as being >=1 in the lexer grammar.
        let col = try parseNumber() - 1
        try accept(kind: .colon)
        let row = try parseNumber() - 1
        return GridOffset(col: col, row: row)
    }

    private func parseNumber() throws -> Int {
        let raw = try accept(kind: .number)
        return Int(raw)!
    }
}
