// SPDX-License-Identifier: MPL-2.0
import Testing
@testable import DenzelRules

struct RulesPlaceholderTests {
    // ponytail: nothing to test until the rulebook loader lands in M2 — this
    // just keeps the test target non-empty so `swift test` covers the module.
    @Test func moduleLoads() {
        #expect(Bool(true))
    }
}
