import XCTest
@testable import CalcCore

final class CalculatorTests: XCTestCase {
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
