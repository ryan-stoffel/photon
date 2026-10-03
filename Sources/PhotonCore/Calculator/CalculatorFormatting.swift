import Foundation

func formatCalculatorNumber(_ value: Double) -> String {
  if value.isNaN || !value.isFinite {
    return "∞"
  }
  // Int(_:) traps past Int.max and value * 1e12 overflows near 1e296, so large answers stay scientific.
  if abs(value) >= 1e15 {
    return String(format: "%.10g", value)
  }
  let rounded = (value * 1e12).rounded() / 1e12
  if abs(rounded - rounded.rounded()) < 1e-9 {
    return String(Int(rounded))
  }
  var text = String(rounded)
  if text.contains("e") || text.contains("E") {
    text = String(format: "%.10g", rounded)
  }
  while text.contains("."), text.last == "0" {
    text.removeLast()
  }
  if text.last == "." {
    text.removeLast()
  }
  return text
}
