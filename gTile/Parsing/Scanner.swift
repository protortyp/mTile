import Foundation

/// Error thrown when the scanner encounters an unsupported character.
struct LexicalError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

/// Describes the type of a scanned lexeme.
enum Literal: Int, Equatable {
    /// A number literal with one or more digits. Never starts with "0".
    case number = 1
    /// A string consisting of only lower case letters.
    case keyword
    /// The literal ",".
    case separator
    /// The literal ":".
    case colon
    /// The literal "(".
    case lParen
    /// The literal ")".
    case rParen
    /// Represents the end of the input string.
    case eof
}

/// Datastructure that describes a scanned lexeme.
struct Token: Equatable {
    let kind: Literal
    let position: Int
    let raw: String
}

/// A simple scanner able to tokenize the lexemes of this lexical grammar:
///
/// ```
/// Token     := ( Number | Keyword | Separator | Colon | LParen | RParen | $ ) .
/// Number    := 1 … 9 { ( "0" | Number ) } .
/// Keyword   := a … z { Keyword } .
/// Separator := "," .
/// Colon     := ":" .
/// LParen    := "(" .
/// RParen    := ")" .
/// EOS       := $ .
/// ```
final class Scanner {
    let input: String
    private var position: String.Index
    private var positionInt: Int
    private var buffer: String

    init(input: String) {
        self.input = input
        self.position = input.startIndex
        self.positionInt = 0
        self.buffer = ""
    }

    /// Scans the next token from the input.
    ///
    /// - Throws: `LexicalError` when a non-supported character was encountered.
    func scan() throws -> Token {
        // skip whitespace
        while position < input.endIndex && input[position] == " " {
            advance()
        }

        let pos = positionInt
        let kind = try scanToken()
        let token = Token(kind: kind, position: pos, raw: buffer)
        buffer = ""

        return token
    }

    private func advance() {
        position = input.index(after: position)
        positionInt += 1
    }

    private func take() {
        buffer.append(input[position])
        advance()
    }

    private var currentChar: Character? {
        position < input.endIndex ? input[position] : nil
    }

    private func isDigit(_ c: Character) -> Bool {
        c >= "0" && c <= "9"
    }

    private func isNonZeroDigit(_ c: Character) -> Bool {
        c >= "1" && c <= "9"
    }

    private func isLowerAlpha(_ c: Character) -> Bool {
        c >= "a" && c <= "z"
    }

    private func scanToken() throws -> Literal {
        guard let char = currentChar else {
            return .eof
        }

        switch char {
        case "1", "2", "3", "4", "5", "6", "7", "8", "9":
            repeat {
                take()
            } while currentChar.map(isDigit) ?? false
            return .number

        case "a", "b", "c", "d", "e", "f", "g",
             "h", "i", "j", "k", "l", "m", "n",
             "o", "p", "q", "r", "s", "t", "u",
             "v", "w", "x", "y", "z":
            repeat {
                take()
            } while currentChar.map(isLowerAlpha) ?? false
            return .keyword

        case ",":
            take()
            return .separator

        case ":":
            take()
            return .colon

        case "(":
            take()
            return .lParen

        case ")":
            take()
            return .rParen

        default:
            throw LexicalError(
                message: "Unexpected character \"\(char)\" at position \(positionInt).")
        }
    }
}
