import XCTest
@testable import CalcCore

final class CalculatorTests: XCTestCase {
    func testToggleSignChangesOnlyCurrentOperand() throws {
        for (expression, expected) in [("5+3", 2.0), ("5−3", 8.0), ("5×3", -15.0),
                                       ("5+sqrt(9)", 2.0), ("5+(2+3)", 0.0),
                                       ("5+1e-3", 4.999), ("5+2^3", 5.125)] {
            let toggled = Calculator.toggleSign(expression)
            XCTAssertEqual(try Calculator.evaluate(toggled), expected, accuracy: 1e-12, expression)
            XCTAssertEqual(Calculator.toggleSign(toggled), expression)
        }
        XCTAssertEqual(Calculator.toggleSign("sqrt(9"), "sqrt(-(9)")
        XCTAssertEqual(Calculator.toggleSign("5+"), "5+")
        XCTAssertEqual(Calculator.toggleSign(""), "")
    }

    func testToggleSignOfDisplayedResult() throws {
        let result = Calculator.display(try Calculator.evaluate("5+3"))
        XCTAssertEqual(try Calculator.evaluate(Calculator.toggleSign(result)), -8)
        XCTAssertEqual(try Calculator.evaluate(Calculator.toggleSign("-8")), 8)
        XCTAssertEqual(try Calculator.evaluate(Calculator.toggleSign("1e+12")), -1e12)
    }

    func testPrecedenceAndParentheses() throws {
        XCTAssertEqual(try Calculator.evaluate("2+3×4"), 14)
        XCTAssertEqual(try Calculator.evaluate("(2+3)×4"), 20)
        XCTAssertEqual(try Calculator.evaluate("2^3^2"), 512)
        XCTAssertEqual(try Calculator.evaluate("-2^2"), -4)
        XCTAssertEqual(try Calculator.evaluate("2^-2"), 0.25)
    }
    func testScientificFunctionsAndAngleModes() throws {
        XCTAssertEqual(try Calculator.evaluate("sin(30)"), 0.5, accuracy: 1e-12)
        XCTAssertEqual(try Calculator.evaluate("cos(π)", degrees: false), -1, accuracy: 1e-12)
        XCTAssertEqual(try Calculator.evaluate("sqrt(81)+log(100)+ln(e)"), 12, accuracy: 1e-12)
        XCTAssertEqual(try Calculator.evaluate("100×15%"), 15)
        XCTAssertEqual(try Calculator.evaluate("1e-3+2"), 2.001, accuracy: 1e-12)
    }
    func testRejectsInvalidOrUndefinedExpressions() {
        for input in ["", "2+", "1/0", "sqrt(-1)", "2(3)", "tan(90)", "foo(2)", "2..3", "(3+1", "2;4"] {
            XCTAssertThrowsError(try Calculator.evaluate(input), input)
        }
        XCTAssertThrowsError(try Calculator.evaluate(String(repeating: "(", count: 300)))
    }
}
