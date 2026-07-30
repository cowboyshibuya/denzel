// SPDX-License-Identifier: MPL-2.0
import Testing
import Foundation
@testable import DenzelRules
import DenzelCore

struct Fixture {
    let vendorID: String
    let lines: [String]
    let expectedVendor: String
    let expectedInvoiceNumber: String
    let expectedIssueDate: String
    let expectedTotalMinorUnits: Int
}

let fixtures: [Fixture] = [
    Fixture(
        vendorID: "cloudflare",
        lines: [
            "Cloudflare, Inc.", "cloudflare.com", "INVOICE",
            "Invoice date: March 1, 2026", "Invoice #: INV-4821",
            "Description: Pro Plan Subscription", "Total: $20.00",
        ],
        expectedVendor: "Cloudflare", expectedInvoiceNumber: "INV-4821",
        expectedIssueDate: "2026-03-01", expectedTotalMinorUnits: 2000
    ),
    Fixture(
        vendorID: "github",
        lines: [
            "GitHub, Inc.", "github.com", "INVOICE",
            "Invoice date: April 5, 2026", "Invoice number: GH-1002",
            "Amount due: $9.00",
        ],
        expectedVendor: "GitHub", expectedInvoiceNumber: "GH-1002",
        expectedIssueDate: "2026-04-05", expectedTotalMinorUnits: 900
    ),
    Fixture(
        vendorID: "stripe",
        lines: [
            "Stripe, Inc.", "stripe.com", "INVOICE",
            "Date of issue: May 10, 2026", "Invoice number 8F2C1D-0001",
            "Amount paid $49.99",
        ],
        expectedVendor: "Stripe", expectedInvoiceNumber: "8F2C1D-0001",
        expectedIssueDate: "2026-05-10", expectedTotalMinorUnits: 4999
    ),
    Fixture(
        vendorID: "vercel",
        lines: [
            "Vercel Inc.", "vercel.com", "INVOICE",
            "Invoice date: June 2, 2026", "Invoice # V-3301",
            "Total $12.50",
        ],
        expectedVendor: "Vercel", expectedInvoiceNumber: "V-3301",
        expectedIssueDate: "2026-06-02", expectedTotalMinorUnits: 1250
    ),
    Fixture(
        vendorID: "digitalocean",
        lines: [
            "DigitalOcean, LLC", "digitalocean.com", "INVOICE",
            "Invoice date: July 15, 2026", "Invoice No.: DO-77021",
            "Total Due: $100.00",
        ],
        expectedVendor: "DigitalOcean", expectedInvoiceNumber: "DO-77021",
        expectedIssueDate: "2026-07-15", expectedTotalMinorUnits: 10000
    ),
    Fixture(
        vendorID: "aws",
        lines: [
            "Amazon Web Services, Inc.", "aws.amazon.com", "INVOICE",
            "Invoice date: August 1, 2026", "Invoice Number: AWS-88213",
            "Total: $215.40",
        ],
        expectedVendor: "Amazon Web Services", expectedInvoiceNumber: "AWS-88213",
        expectedIssueDate: "2026-08-01", expectedTotalMinorUnits: 21540
    ),
    Fixture(
        vendorID: "anthropic",
        lines: [
            "Anthropic, PBC", "anthropic.com", "INVOICE",
            "Invoice date: September 3, 2026", "Invoice #: ANT-5521",
            "Total: $50.00",
        ],
        expectedVendor: "Anthropic", expectedInvoiceNumber: "ANT-5521",
        expectedIssueDate: "2026-09-03", expectedTotalMinorUnits: 5000
    ),
    Fixture(
        vendorID: "openai",
        lines: [
            "OpenAI, LLC", "openai.com", "INVOICE",
            "Invoice date: October 4, 2026", "Invoice number: OAI-3391",
            "Amount due: $100.00",
        ],
        expectedVendor: "OpenAI", expectedInvoiceNumber: "OAI-3391",
        expectedIssueDate: "2026-10-04", expectedTotalMinorUnits: 10000
    ),
    Fixture(
        vendorID: "linear",
        lines: [
            "Linear Orbit, Inc.", "linear.app", "INVOICE",
            "Invoice date: November 6, 2026", "Invoice # LIN-771",
            "Total $8.00",
        ],
        expectedVendor: "Linear", expectedInvoiceNumber: "LIN-771",
        expectedIssueDate: "2026-11-06", expectedTotalMinorUnits: 800
    ),
    Fixture(
        vendorID: "notion",
        lines: [
            "Notion Labs, Inc.", "notion.so", "INVOICE",
            "Invoice date: December 9, 2026", "Invoice No.: NOT-4021",
            "Total Due: $10.00",
        ],
        expectedVendor: "Notion", expectedInvoiceNumber: "NOT-4021",
        expectedIssueDate: "2026-12-09", expectedTotalMinorUnits: 1000
    ),
]

private func makeTempLibrary() throws -> DenzelLibrary {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let bookmark = try dir.bookmarkData(includingResourceValuesForKeys: nil, relativeTo: nil)
    return DenzelLibrary(location: LibraryLocation(bookmarkData: bookmark))
}

/// This is the M2 done-when: every one of the 10 synthetic vendor fixtures
/// must auto-file correctly through the real pipeline (>= 90% is the
/// brief's bar; with all-clean digital fixtures the target is 10/10).
struct VendorRuleFixtureTests {
    @Test(arguments: fixtures)
    func autoFilesCorrectly(fixture: Fixture) throws {
        let library = try makeTempLibrary()
        let root = try library.rootURL()
        defer { try? FileManager.default.removeItem(at: root) }

        let pdfURL = root.appendingPathComponent("\(fixture.vendorID).pdf")
        try FixtureGenerator.makePDF(lines: fixture.lines, at: pdfURL)

        let rules = try VendorRuleLoader.loadBundledRules()
        let record = try ExtractionPipeline.process(fileURL: pdfURL, library: library, rules: rules)

        #expect(!record.needsReview, "expected auto-file, got review reason: \(record.reviewReason ?? "none")")
        #expect(record.vendor == fixture.expectedVendor)
        #expect(record.invoiceNumber == fixture.expectedInvoiceNumber)
        #expect(record.issueDate == fixture.expectedIssueDate)
        #expect(record.totalMinorUnits == fixture.expectedTotalMinorUnits)
    }

    @Test func unrecognizedVendorGoesToReview() throws {
        let library = try makeTempLibrary()
        let root = try library.rootURL()
        defer { try? FileManager.default.removeItem(at: root) }

        let pdfURL = root.appendingPathComponent("unknown.pdf")
        try FixtureGenerator.makePDF(lines: [
            "Some Company That Sells Things", "randomvendor.example", "INVOICE",
            "This is a plain invoice from a vendor with no matching rule in the rulebook.",
            "Invoice date: January 1, 2026", "Reference: XYZ-0001", "Total: $5.00",
        ], at: pdfURL)

        let rules = try VendorRuleLoader.loadBundledRules()
        let record = try ExtractionPipeline.process(fileURL: pdfURL, library: library, rules: rules)

        #expect(record.needsReview)
        #expect(record.reviewReason == "vendor not confidently identified")
    }
}
