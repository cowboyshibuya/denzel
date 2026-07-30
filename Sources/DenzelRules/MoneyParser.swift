// SPDX-License-Identifier: MPL-2.0
import Foundation

public enum MoneyParseError: Error {
    case empty
    case invalidDigits(String)
}

/// Parses a money string into integer minor units (cents) without trusting
/// locale detection. Heuristic: the LAST separator (`,` or `.`) is the
/// decimal separator only if followed by exactly 1 or 2 trailing digits
/// (real currencies use 0-2 decimal places). A trailing 3-digit group is
/// thousands grouping, not a 3-decimal currency — that's the classic bug
/// where naive `Double(string)` parsing on "1.234" silently gives 1234 cents
/// instead of the correct 123400.
public func parseMoneyMinorUnits(_ raw: String) throws -> Int {
    var cleaned = raw
        .replacingOccurrences(of: "\u{00A0}", with: "")  // NBSP thousands separator
        .replacingOccurrences(of: " ", with: "")
        .trimmingCharacters(in: .whitespaces)
    cleaned = cleaned.filter { $0.isNumber || $0 == "," || $0 == "." || $0 == "-" }

    guard !cleaned.isEmpty else { throw MoneyParseError.empty }

    let isNegative = cleaned.hasPrefix("-")
    if isNegative { cleaned.removeFirst() }

    guard let lastSeparatorIndex = cleaned.lastIndex(where: { $0 == "," || $0 == "." }) else {
        // No separator at all: a plain integer of major units.
        guard let major = Int(cleaned) else { throw MoneyParseError.invalidDigits(raw) }
        return applySign(major * 100, isNegative)
    }

    let trailingDigits = cleaned[cleaned.index(after: lastSeparatorIndex)...]
    guard trailingDigits.allSatisfy(\.isNumber) else { throw MoneyParseError.invalidDigits(raw) }

    let isDecimal = trailingDigits.count == 1 || trailingDigits.count == 2

    let digitsOnly = cleaned.filter(\.isNumber)
    guard !digitsOnly.isEmpty else { throw MoneyParseError.invalidDigits(raw) }

    if isDecimal {
        let minorDigits = trailingDigits.count == 1 ? trailingDigits + "0" : String(trailingDigits)
        let majorDigits = String(digitsOnly.dropLast(trailingDigits.count))
        let major = majorDigits.isEmpty ? 0 : (Int(majorDigits) ?? 0)
        let minor = Int(minorDigits) ?? 0
        return applySign(major * 100 + minor, isNegative)
    } else {
        // Trailing group isn't 1-2 digits (i.e. it's a 3-digit thousands
        // group, or the string only has grouping separators) — the whole
        // thing is major units with grouping stripped.
        guard let major = Int(digitsOnly) else { throw MoneyParseError.invalidDigits(raw) }
        return applySign(major * 100, isNegative)
    }
}

private func applySign(_ value: Int, _ isNegative: Bool) -> Int {
    isNegative ? -value : value
}
