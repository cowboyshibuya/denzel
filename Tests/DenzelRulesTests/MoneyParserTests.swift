// SPDX-License-Identifier: MPL-2.0
import Testing
@testable import DenzelRules

struct MoneyParserTests {
    @Test(arguments: [
        ("1.234,56", 123456),     // EU-style: both separators present
        ("1,234.56", 123456),     // US-style
        ("1.234", 123400),        // 3-digit trailing group = thousands, NOT 1234 cents
        ("1,234", 123400),
        ("1.234.567,89", 123456789),  // multiple thousands groups
        ("42.5", 4250),           // single trailing digit = implied decimal, not grouping
        ("€ 1.234,56", 123456),   // currency symbol stripped
        ("1 234,56", 123456),     // regular space thousands separator
        ("1\u{00A0}234,56", 123456),  // NBSP thousands separator
        ("42", 4200),             // plain integer, no separator
        ("0.99", 99),
        ("-42.50", -4250),        // negative (credit note)
    ])
    func parsesKnownCases(input: String, expected: Int) throws {
        #expect(try parseMoneyMinorUnits(input) == expected)
    }

    @Test func throwsOnEmpty() {
        #expect(throws: MoneyParseError.self) { try parseMoneyMinorUnits("") }
    }

    @Test func throwsOnGarbage() {
        #expect(throws: MoneyParseError.self) { try parseMoneyMinorUnits("not a number") }
    }
}
