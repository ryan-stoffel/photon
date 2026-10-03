import PhotonCore
import XCTest

final class CalculatorDisplayModelTests: XCTestCase {
  func testMathResultMapsToHeroModel() throws {
    let result = try XCTUnwrap(CalculatorEngine.evaluate("2 + 2"))
    let model = CalculatorDisplayModel(result: result, commandID: "calculator:test")
    XCTAssertEqual(model.expression, "2 + 2")
    XCTAssertEqual(model.value, "4")
    XCTAssertEqual(model.expressionCaption, "Question")
    XCTAssertEqual(model.valueCaption, "Four")
  }

  func testConversionMapsExpressionAndValue() throws {
    let result = try XCTUnwrap(CalculatorEngine.evaluate("10 km to mi"))
    let model = CalculatorDisplayModel(result: result, commandID: "calculator:convert")
    XCTAssertEqual(model.expressionCaption, "Question")
    XCTAssertFalse(model.expression.isEmpty)
    XCTAssertTrue(model.value.hasSuffix(" mi"))
    XCTAssertEqual(model.valueCaption, "Miles")
  }

  func testSectionTitle() {
    XCTAssertEqual(CalculatorDisplayModel.sectionTitle, "Calculator")
  }
}
