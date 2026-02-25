import Foundation

/// Error thrown when parsing fails.
struct ParseError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

/// Base class for LL(1) parsers that operate on the Scanner's token stream.
class Parser {
    let scanner: Scanner
    var token: Token

    init(input: String) {
        self.scanner = Scanner(input: input)
        // Placeholder token; subclasses call scanner.scan() to initialize
        self.token = Token(kind: .eof, position: 0, raw: "")
    }

    /// Scans the next token, accepting & discarding the current token.
    ///
    /// - Parameters:
    ///   - kind: Optional. The expected kind of the current token.
    ///   - raw: Optional. The expected raw value of the current token.
    /// - Returns: The literal representation of the accepted token.
    /// - Throws: `ParseError` if the current token doesn't match the expected shape.
    @discardableResult
    func accept(kind: Literal? = nil, raw: String? = nil) throws -> String {
        if let kind = kind, kind != token.kind {
            throw ParseError(message:
                "Unexpected token \(token.kind). Want \(kind)")
        }
        if let raw = raw, raw != token.raw {
            throw ParseError(message:
                "Unexpected constant literal \(token.raw). Want \(raw)")
        }

        let rawValue = token.raw
        token = try scanner.scan()
        return rawValue
    }

    /// Conditionally scans the next token.
    ///
    /// - Parameter kind: The scan only proceeds if the current token matches this.
    /// - Returns: Whether the current token was accepted.
    @discardableResult
    func acceptIf(_ kind: Literal) throws -> Bool {
        if token.kind == kind {
            token = try scanner.scan()
            return true
        }
        return false
    }
}
