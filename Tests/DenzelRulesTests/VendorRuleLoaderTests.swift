// SPDX-License-Identifier: MPL-2.0
import Testing
@testable import DenzelRules

struct VendorRuleLoaderTests {
    @Test func loadsAllBundledVendorRules() throws {
        let rules = try VendorRuleLoader.loadBundledRules()
        let ids = Set(rules.map(\.id))
        #expect(ids == ["cloudflare", "github", "stripe", "vercel", "digitalocean", "aws", "anthropic", "openai", "linear", "notion"])
        for rule in rules {
            #expect(!rule.match.any.isEmpty)
            #expect(rule.fields["invoice_number"] != nil)
            #expect(rule.fields["total"] != nil)
            #expect(rule.fields["issue_date"] != nil)
        }
    }
}
