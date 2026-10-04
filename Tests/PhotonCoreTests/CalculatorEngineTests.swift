import PhotonCore
import XCTest

final class CalculatorEngineTests: XCTestCase {
  private let enUS = Locale(identifier: "en_US")

  func testDivisionShowsDivideLabel() {
    let result = CalculatorEngine.evaluate("30/5")
    XCTAssertEqual(result?.value, "6")
    XCTAssertEqual(result?.operationLabel, "Divide")
    XCTAssertEqual(result?.wordForm, "Six")
    XCTAssertEqual(result?.rowTitle, "30/5 → 6")
  }

  func testParenthesesAndPower() {
    XCTAssertEqual(CalculatorEngine.evaluate("(2+3)*4")?.value, "20")
    XCTAssertEqual(CalculatorEngine.evaluate("2^10")?.value, "1024")
    XCTAssertEqual(CalculatorEngine.evaluate("2^10")?.operationLabel, "Power")
  }

  func testDecimalsAndModulo() {
    XCTAssertEqual(CalculatorEngine.evaluate("3.5 * 2", locale: enUS)?.value, "7")
    XCTAssertEqual(CalculatorEngine.evaluate("10 % 3")?.value, "1")
  }

  func testLargeResultsStayScientificInsteadOfTrapping() {
    XCTAssertEqual(CalculatorEngine.evaluate("2^64")?.value, "1.844674407e+19")
    XCTAssertEqual(CalculatorEngine.evaluate("-(10^19)")?.value, "-1e+19")
  }

  func testExactIntegersUpTo2Pow53PrintInFull() {
    XCTAssertEqual(CalculatorEngine.evaluate("10^15+1")?.value, "1000000000000001")
    XCTAssertEqual(CalculatorEngine.evaluate("2^53")?.value, "9007199254740992")
  }

  func testNegativeOperandsAndRightAssociativePower() {
    let cases = ["2*-3": "-6", "3 - -2": "5", "2^-1": "0.5", "10 / -2": "-5", "2^3^2": "512", "-3^2": "-9"]
    for (query, value) in cases {
      XCTAssertEqual(CalculatorEngine.evaluate(query)?.value, value, query)
    }
  }

  func testPercent() {
    let cases = ["20% of 50": "10", "50 + 10%": "55", "50 - 10%": "45", "10%": "0.1", "10% - 5": "-4.9"]
    for (query, value) in cases {
      XCTAssertEqual(CalculatorEngine.evaluate(query)?.value, value, query)
    }
  }

  func testLocaleSeparatorsAndTypographicOperators() {
    let grouped = CalculatorEngine.evaluate("1,000 + 1", locale: enUS)
    XCTAssertEqual(grouped?.value, "1001")
    XCTAssertEqual(grouped?.expression, "1,000 + 1")
    XCTAssertEqual(CalculatorEngine.evaluate("3 × 4", locale: enUS)?.value, "12")
    XCTAssertEqual(CalculatorEngine.evaluate("8 ÷ 2", locale: enUS)?.value, "4")
    XCTAssertEqual(CalculatorEngine.evaluate("5 \u{2212} 2", locale: enUS)?.value, "3")
    XCTAssertEqual(CalculatorEngine.evaluate("1.000,5 + 1", locale: Locale(identifier: "de_DE"))?.value, "1001.5")
    XCTAssertEqual(CalculatorEngine.evaluate("0.1 + 0.2", locale: Locale(identifier: "de_DE"))?.value, "0.3")
    XCTAssertEqual(CalculatorEngine.evaluate("0.125 * 8", locale: Locale(identifier: "de_DE"))?.value, "1")
    XCTAssertEqual(CalculatorEngine.evaluate("10.125 * 8", locale: Locale(identifier: "de_DE"))?.value, "81000")
  }

  func testDisplayValueGroupsForTheLocaleAndCopyStaysRaw() throws {
    let product = try XCTUnwrap(CalculatorEngine.evaluate("1234*5678"))
    XCTAssertEqual(product.displayValue(locale: enUS), "7,006,652")
    XCTAssertEqual(product.copyValue, "7006652")
    let decimal = try XCTUnwrap(CalculatorEngine.evaluate("1234.5 * 1", locale: enUS))
    XCTAssertEqual(decimal.displayValue(locale: Locale(identifier: "de_DE")), "1.234,5")
    XCTAssertEqual(CalculatorEngine.evaluate("2 km to m")?.displayValue(locale: enUS), "2,000 m")
  }

  func testLengthConversion() throws {
    let result = try XCTUnwrap(CalculatorEngine.evaluate("10 km to mi"))
    XCTAssertEqual(result.operationLabel, "Convert")
    XCTAssertTrue(result.rowTitle.contains("→"))
    XCTAssertEqual(CalculatorEngine.evaluate("2 kilometres to metres")?.value, "2000 m")
    XCTAssertEqual(CalculatorEngine.evaluate("150 centimeters to millimeters")?.wordForm, "Millimeters")
  }

  func testTemperatureConversion() {
    let freezing = CalculatorEngine.evaluate("32 f to c")
    XCTAssertEqual(freezing?.value, "0 °C")
    XCTAssertEqual(freezing?.wordForm, "Celsius")
    let boiling = CalculatorEngine.evaluate("212 f to c")
    XCTAssertEqual(boiling?.value, "100 °C")
  }

  func testConversionSplitsOnTheLastSeparatorWord() {
    XCTAssertEqual(CalculatorEngine.evaluate("1 in to cm")?.value, "2.54 cm")
    XCTAssertEqual(CalculatorEngine.evaluate("5 km to in")?.wordForm, "Inches")
    XCTAssertNil(CalculatorEngine.evaluate("İİİİİİİİ in"))
    XCTAssertNil(CalculatorEngine.evaluate("İ to"))
  }

  func testDataConversion() {
    let result = CalculatorEngine.evaluate("1024 mb to gb")
    XCTAssertNotNil(result)
    XCTAssertEqual(CalculatorEngine.evaluate("1024 B to KiB")?.value, "1 KiB")
  }

  func testNonExpressionReturnsNil() {
    XCTAssertNil(CalculatorEngine.evaluate("safari"))
    XCTAssertNil(CalculatorEngine.evaluate(""))
    XCTAssertNil(CalculatorEngine.evaluate("1/0"))
  }
}
