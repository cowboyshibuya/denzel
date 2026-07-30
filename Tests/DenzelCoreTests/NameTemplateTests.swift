// SPDX-License-Identifier: MPL-2.0
import Testing
import Foundation
@testable import DenzelCore

struct NameTemplateTests {
    @Test func rendersAllTokens() throws {
        let template = NameTemplate(pattern: "{date}_{vendor}_{invoiceNumber}_{amount}{currency}", fileExtension: "pdf")
        let name = try template.render(fields: [
            "date": "2026-03-01", "vendor": "openai", "invoiceNumber": "INV-4821", "amount": "20.00", "currency": "EUR",
        ])
        #expect(name == "2026-03-01_openai_INV-4821_20.00EUR.pdf")
    }

    @Test func sanitizesIllegalCharacters() {
        #expect(NameTemplate.sanitize("Cloudflare, Inc./Ltd") == "Cloudflare--Inc.-Ltd")
        #expect(NameTemplate.sanitize(".hidden") == "hidden")
        #expect(NameTemplate.sanitize("trailing. ") == "trailing")
    }

    @Test func throwsOnMissingField() {
        let template = NameTemplate(pattern: "{date}_{vendor}", fileExtension: "pdf")
        #expect(throws: NameTemplateError.self) {
            try template.render(fields: ["date": "2026-03-01"])
        }
    }

    @Test func truncatesToByteLimitNotCharacterLimit() {
        let longVendor = String(repeating: "日", count: 200)   // 3 bytes/char in UTF-8
        let result = NameTemplate.truncatingToByteLimit(longVendor, extension: "pdf")
        #expect(result.utf8.count <= 255)
        // Must not have chopped a multi-byte character in half.
        #expect(String(data: Data(result.utf8), encoding: .utf8) != nil)
    }
}
