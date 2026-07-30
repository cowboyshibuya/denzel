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
]

private func makeTempLibrary() throws -> DenzelLibrary {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let bookmark = try dir.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    return DenzelLibrary(location: LibraryLocation(bookmarkData: bookmark))
}

/// This is the M2 done-when: every one of the 5 synthetic vendor fixtures
/// must auto-file correctly through the real pipeline (>= 90% is the
/// brief's bar; with only 5 clean digital fixtures the target is 5/5).
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
