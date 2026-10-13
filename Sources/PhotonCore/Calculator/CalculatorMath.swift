import Foundation

enum MathExpression {
  static func evaluate(_ input: String) -> CalculatorResult? {
    let tokens = tokenize(input)
    guard !tokens.isEmpty, containsOperator(tokens) else {
      return nil
    }
    var parser = Parser(tokens: tokens)
    guard let value = parser.parseExpression(), parser.isAtEnd else {
      return nil
    }
    guard value.isFinite else {
      return nil
    }
    let formatted = formatCalculatorNumber(value)
    let label = parser.lastOperationLabel ?? "Calculate"
    let words = NumberWords.spokenForm(for: value)
    return CalculatorResult(
      expression: input,
      value: formatted,
      operationLabel: label,
      wordForm: words
    )
  }

  private static func containsOperator(_ tokens: [Token]) -> Bool {
    tokens.contains { token in
      switch token {
      case .op, .percent: true
      default: false
      }
    }
  }

  private enum Token: Equatable {
    case number(Double)
    case op(Character)
    /// Postfix percent ("10%"). `%` followed by an operand is `.op("%")`, modulo.
    case percent
    case lparen
    case rparen
  }

  private static func tokenize(_ input: String) -> [Token] {
    var tokens: [Token] = []
    var index = input.startIndex

    while index < input.endIndex {
      let char = input[index]
      if char.isWhitespace {
        index = input.index(after: index)
        continue
      }
      if char.isNumber || char == "." {
        guard let (value, next) = readNumber(in: input, from: index) else {
          return []
        }
        tokens.append(.number(value))
        index = next
        continue
      }
      if char == "(" {
        tokens.append(.lparen)
        index = input.index(after: index)
        continue
      }
      if char == ")" {
        tokens.append(.rparen)
        index = input.index(after: index)
        continue
      }
      if char == "%" {
        tokens.append(startsOperand(in: input, after: index) ? .op("%") : .percent)
        index = input.index(after: index)
        continue
      }
      if "+-*/^".contains(char) {
        tokens.append(.op(char))
        index = input.index(after: index)
        continue
      }
      if char.isLetter {
        // "20% of 50" reads "of" as multiplication. Any other word is not math.
        let end = input[index...].firstIndex { !$0.isLetter } ?? input.endIndex
        guard input[index ..< end].lowercased() == "of" else {
          return []
        }
        tokens.append(.op("*"))
        index = end
        continue
      }
      return []
    }
    return tokens
  }

  /// True when the next non-space character after `index` starts a number or group, so "10 % 3" stays modulo.
  private static func startsOperand(in input: String, after index: String.Index) -> Bool {
    guard let next = input[input.index(after: index)...].first(where: { !$0.isWhitespace }) else {
      return false
    }
    return next.isNumber || next == "." || next == "("
  }

  private static func readNumber(in input: String, from start: String.Index) -> (Double, String.Index)? {
    var index = start
    var sawDot = input[index] == "."
    index = input.index(after: index)
    while index < input.endIndex {
      let next = input[index]
      if next.isNumber {
        index = input.index(after: index)
      } else if next == ".", !sawDot {
        sawDot = true
        index = input.index(after: index)
      } else {
        break
      }
    }
    guard let value = Double(input[start ..< index]) else {
      return nil
    }
    return (value, index)
  }

  private struct Parser {
    let tokens: [Token]
    var position = 0
    private(set) var lastOperationLabel: String?

    init(tokens: [Token]) {
      self.tokens = tokens
    }

    var isAtEnd: Bool {
      position >= tokens.count
    }

    mutating func parseExpression() -> Double? {
      parseAddition()
    }

    private mutating func parseAddition() -> Double? {
      guard var value = parseMultiplication() else {
        return nil
      }
      while match(.op("+")) || match(.op("-")) {
        let add = previousOp == "+"
        lastOperationLabel = add ? "Add" : "Subtract"
        let start = position
        guard let rhs = parseMultiplication() else {
          return nil
        }
        // "50 + 10%" adds ten percent of 50, as on a desk calculator.
        let scale = isPercentLiteral(start ..< position) ? value : 1
        value = add ? value + rhs * scale : value - rhs * scale
      }
      return value
    }

    /// True when `range` is a bare "N%" term.
    private func isPercentLiteral(_ range: Range<Int>) -> Bool {
      guard range.count == 2, case .number = tokens[range.lowerBound] else {
        return false
      }
      return tokens[range.upperBound - 1] == .percent
    }

    private mutating func parseMultiplication() -> Double? {
      guard var value = parseUnary() else {
        return nil
      }
      while match(.op("*")) || match(.op("/")) || match(.op("%")) {
        let op = previousOp!
        lastOperationLabel = op == "*" ? "Multiply" : op == "/" ? "Divide" : "Modulo"
        guard let rhs = parseUnary() else {
          return nil
        }
        switch op {
        case "*": value *= rhs
        case "/":
          guard rhs != 0 else {
            return nil
          }
          value /= rhs
        case "%":
          guard rhs != 0 else {
            return nil
          }
          value = value.truncatingRemainder(dividingBy: rhs)
        default: break
        }
      }
      return value
    }

    /// Sign binds looser than power, so "-3^2" is -9 and "2*-3" is -6.
    private mutating func parseUnary() -> Double? {
      if match(.op("-")) {
        guard let value = parseUnary() else {
          return nil
        }
        return -value
      }
      if match(.op("+")) {
        return parseUnary()
      }
      return parsePower()
    }

    /// Right-associative ("2^3^2" is 2^9), and the exponent may carry a sign ("2^-1").
    /// Postfix percent applies to the base: "10%" is 0.1.
    private mutating func parsePower() -> Double? {
      guard var base = parsePrimary() else {
        return nil
      }
      while match(.percent) {
        base /= 100
      }
      guard match(.op("^")) else {
        return base
      }
      lastOperationLabel = "Power"
      guard let exponent = parseUnary() else {
        return nil
      }
      return pow(base, exponent)
    }

    private mutating func parsePrimary() -> Double? {
      if let value = consumeNumber() {
        return value
      }
      if match(.lparen) {
        guard let value = parseExpression(), match(.rparen) else {
          return nil
        }
        return value
      }
      return nil
    }

    private var previousOp: Character?

    private mutating func consumeNumber() -> Double? {
      guard position < tokens.count, case let .number(value) = tokens[position] else {
        return nil
      }
      position += 1
      return value
    }

    private mutating func match(_ token: Token) -> Bool {
      guard position < tokens.count else {
        return false
      }
      switch (token, tokens[position]) {
      case (.lparen, .lparen), (.rparen, .rparen), (.percent, .percent):
        position += 1
        return true
      case let (.op(expected), .op(actual)) where expected == actual:
        previousOp = actual
        position += 1
        return true
      default:
        return false
      }
    }
  }
}
