import Foundation

/// Outcome of parsing and evaluating a launcher calculator query.
public struct CalculatorResult: Equatable, Sendable {
  public internal(set) var expression: String
  public let value: String
  public let operationLabel: String
  public let wordForm: String?

  public init(expression: String, value: String, operationLabel: String, wordForm: String? = nil) {
    self.expression = expression
    self.value = value
    self.operationLabel = operationLabel
    self.wordForm = wordForm
  }

  /// Row title: expression, arrow, formatted result (Raycast-style, one line).
  public var rowTitle: String {
    "\(expression) → \(displayValue())"
  }

  /// Text copied when the user presses Enter: the raw answer without grouping. Conversions keep their unit.
  public var copyValue: String {
    value
  }

  /// `value` for display, with the number grouped and its decimal separator set by `locale`.
  /// Scientific answers ("1.8e+19") stay as they are.
  public func displayValue(locale: Locale = .current) -> String {
    let parts = value.split(separator: " ", maxSplits: 1)
    guard let number = parts.first, !number.contains("e"), let decimal = Decimal(string: String(number)) else {
      return value
    }
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = locale
    formatter.maximumFractionDigits = number.split(separator: ".").dropFirst().first?.count ?? 0
    guard let grouped = formatter.string(from: decimal as NSDecimalNumber) else {
      return value
    }
    return ([Substring(grouped)] + parts.dropFirst()).joined(separator: " ")
  }
}
