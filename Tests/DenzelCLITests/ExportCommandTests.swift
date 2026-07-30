// SPDX-License-Identifier: MPL-2.0
import Testing
@testable import DenzelCLI

struct ExportCommandTests {
    @Test(arguments: [
        ("2026-Q1", "2026-01-01", "2026-04-01"),
        ("2026-Q2", "2026-04-01", "2026-07-01"),
        ("2026-Q4", "2026-10-01", "2027-01-01"),   // rolls into the next year
    ])
    func computesQuarterBounds(input: String, start: String, endExclusive: String) {
        let bounds = ExportCommand.quarterBounds(input)
        #expect(bounds?.start == start)
        #expect(bounds?.endExclusive == endExclusive)
    }

    @Test(arguments: ["2026-Q5", "not-a-quarter", "2026-01"])
    func rejectsInvalidQuarters(input: String) {
        #expect(ExportCommand.quarterBounds(input) == nil)
    }

    @Test func escapesFieldsContainingCommasOrQuotes() {
        #expect(ExportCommand.csvEscape("Cloudflare") == "Cloudflare")
        #expect(ExportCommand.csvEscape("Cloudflare, Inc.") == "\"Cloudflare, Inc.\"")
        #expect(ExportCommand.csvEscape("Say \"hi\"") == "\"Say \"\"hi\"\"\"")
    }
}
