import Foundation

/// Local calculator and unit conversion for the launcher. No network, no AI.
public enum CalculatorEngine: Sendable {
  /// Returns a result when `query` is a math expression or supported conversion.
  /// `locale` sets which grouping and decimal separators the query may use. The result keeps the typed expression.
  public static func evaluate(_ rawQuery: String, locale: Locale = .current) -> CalculatorResult? {
    let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
      return nil
    }
    let normalized = normalize(query, locale: locale)
    guard var result = UnitConversion.evaluate(normalized) ?? MathExpression.evaluate(normalized) else {
      return nil
    }
    result.expression = query.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    return result
  }

  /// Maps × ÷ − to ASCII operators, drops the locale's grouping separator when exactly three digits follow it,
  /// and turns its decimal separator into ".". The three-digit rule keeps "0.1" a decimal in "." grouping locales.
  private static func normalize(_ query: String, locale: Locale) -> String {
    var text = query
      .replacingOccurrences(of: "×", with: "*")
      .replacingOccurrences(of: "÷", with: "/")
      .replacingOccurrences(of: "\u{2212}", with: "-")
    if let grouping = locale.groupingSeparator, !grouping.isEmpty {
      let pattern = "(?<=\\d)" + NSRegularExpression.escapedPattern(for: grouping) + "(?=\\d{3}(?!\\d))"
      text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
    if let decimal = locale.decimalSeparator, decimal != "." {
      text = text.replacingOccurrences(of: decimal, with: ".")
    }
    return text
  }
}
