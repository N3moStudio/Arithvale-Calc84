import Foundation

public enum CalculationError: Error, LocalizedError {
    case invalidExpression, nonFinite
    public var errorDescription: String? {
        switch self {
        case .invalidExpression: return "Check the expression."
        case .nonFinite: return "Result is undefined."
        }
    }
}

/// A bounded recursive-descent parser. Never evaluates scripts or arbitrary code.
public struct Calculator {
    /// Toggle the last operand without changing the preceding calculation.
    public static func toggleSign(_ expression: String) -> String {
        let characters = Array(expression)
        guard !characters.isEmpty else { return expression }
        var depth = 0
        var start = 0
        for index in characters.indices.reversed() {
            let character = characters[index]
            if character == ")" { depth += 1; continue }
            if character == "(" {
                if depth > 0 { depth -= 1; continue }
                start = index + 1; break
            }
            guard depth == 0, "+−-×÷*/^".contains(character) else { continue }
            // Signs following an operator or an opening parenthesis are unary;
            // signs immediately after a numeric exponent belong to the number.
            if character == "+" || character == "-" || character == "−" {
                if index == 0 || "+−-×÷*/^(".contains(characters[index - 1]) { continue }
                if (characters[index - 1] == "e" || characters[index - 1] == "E"),
                   index >= 2, characters[index - 2].isNumber || characters[index - 2] == "." { continue }
            }
            start = index + 1; break
        }
        let prefix = String(characters[..<start])
        let operand = String(characters[start...])
        guard !operand.isEmpty else { return expression }
        if operand.hasPrefix("-("), operand.hasSuffix(")") {
            return prefix + String(operand.dropFirst(2).dropLast())
        }
        return prefix + "-(" + operand + ")"
    }

    public static func clearEntry(_ expression: String) -> String {
        guard let boundary = expression.lastIndex(where: { "+−×÷*/^".contains($0) }) else { return "" }
        return String(expression[...boundary])
    }

    public static func evaluate(_ expression: String, degrees: Bool = true) throws -> Double {
        guard expression.count <= 256 else { throw CalculationError.invalidExpression }
        var parser = Parser(text: expression, degrees: degrees)
        let value = try parser.sum()
        guard parser.index == parser.characters.count else { throw CalculationError.invalidExpression }
        guard value.isFinite else { throw CalculationError.nonFinite }
        return value == 0 ? 0 : value
    }

    public static func display(_ value: Double) -> String {
        String(format: "%.12g", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private struct Parser {
        var characters: [Character]
        var index = 0
        let degrees: Bool
        init(text: String, degrees: Bool) {
            characters = Array(text.replacingOccurrences(of: "×", with: "*")
                .replacingOccurrences(of: "÷", with: "/")
                .replacingOccurrences(of: "−", with: "-")
                .filter { !$0.isWhitespace })
            self.degrees = degrees
        }
        mutating func take(_ c: Character) -> Bool {
            guard index < characters.count, characters[index] == c else { return false }
            index += 1
            return true
        }
        mutating func sum() throws -> Double {
            var value = try product()
            while index < characters.count {
                if take("+") { value += try product() }
                else if take("-") { value -= try product() }
                else { break }
            }
            return value
        }
        mutating func product() throws -> Double {
            var value = try unary()
            while index < characters.count {
                if take("*") { value *= try unary() }
                else if take("/") { value /= try unary() }
                else { break }
            }
            return value
        }
        mutating func unary() throws -> Double {
            if take("+") { return try unary() }
            if take("-") { return -(try unary()) }
            return try power()
        }
        mutating func power() throws -> Double {
            var value = try primary()
            while take("%") { value /= 100 }
            if take("^") { value = pow(value, try unary()) }
            return value
        }
        mutating func primary() throws -> Double {
            if take("(") {
                let value = try sum()
                guard take(")") else { throw CalculationError.invalidExpression }
                return value
            }
            if take("π") { return .pi }
            guard index < characters.count else { throw CalculationError.invalidExpression }
            if characters[index].isLetter {
                let start = index
                while index < characters.count, characters[index].isLetter { index += 1 }
                let name = String(characters[start..<index])
                if name == "e" { return M_E }
                guard take("(") else { throw CalculationError.invalidExpression }
                let value = try sum()
                guard take(")") else { throw CalculationError.invalidExpression }
                let angle = degrees ? value * .pi / 180 : value
                switch name {
                case "sin": return sin(angle)
                case "cos": return cos(angle)
                case "tan": return abs(cos(angle)) < 1e-14 ? .nan : tan(angle)
                case "sqrt": return sqrt(value)
                case "ln": return log(value)
                case "log": return log10(value)
                case "abs": return abs(value)
                default: throw CalculationError.invalidExpression
                }
            }
            let start = index
            while index < characters.count, characters[index].isNumber || characters[index] == "." { index += 1 }
            if index < characters.count, characters[index] == "e" || characters[index] == "E" {
                index += 1
                if index < characters.count, characters[index] == "+" || characters[index] == "-" { index += 1 }
                while index < characters.count, characters[index].isNumber { index += 1 }
            }
            guard index > start, let number = Double(String(characters[start..<index])) else {
                throw CalculationError.invalidExpression
            }
            return number
        }
    }
}
