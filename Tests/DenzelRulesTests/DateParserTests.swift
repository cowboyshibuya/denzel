// SPDX-License-Identifier: MPL-2.0
import Testing
import Foundation
@testable import DenzelRules

struct DateParserTests {
    @Test func anchorsOnInvoiceDateNotPeriodDates() {
        let text = """
        Service period: Jan 1, 2026 - Jan 31, 2026
        Due date: February 15, 2026
        Invoice date: March 1, 2026
        Total: $20.00
        """
        let result = extractInvoiceDate(from: text)
        #expect(result != nil)
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: result!.date)
        #expect(components.month == 3)
        #expect(components.day == 1)
    }

    @Test func returnsNilWhenNoDateNearKeyword() {
        let text = "Some unrelated text with a date March 1, 2026 but no keyword nearby at all, padded out further and further so the distance exceeds the proximity window entirely."
        let result = extractInvoiceDate(from: text, proximityWindow: 10)
        #expect(result == nil)
    }

    @Test func handlesGermanKeyword() {
        let text = "Rechnungsdatum: 03.01.2026\nGesamtbetrag: 42,00 EUR"
        let result = extractInvoiceDate(from: text)
        #expect(result != nil)
    }
}
