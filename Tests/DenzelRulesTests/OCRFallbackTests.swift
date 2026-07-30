// SPDX-License-Identifier: MPL-2.0
import Testing
import Foundation
@testable import DenzelRules
import DenzelCore

private func makeTempLibrary() throws -> DenzelLibrary {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let bookmark = try dir.bookmarkData(includingResourceValuesForKeys: nil, relativeTo: nil)
    return DenzelLibrary(location: LibraryLocation(bookmarkData: bookmark))
}

/// A scanned (image-only) PDF must still auto-file: the OCR fallback reads
/// it back to text, which then runs through the exact same vendor/field
/// confidence gates as a real text layer.
struct OCRFallbackTests {
    @Test func scannedInvoiceIsRecognizedAndAutoFiled() throws {
        let library = try makeTempLibrary()
        let root = try library.rootURL()
        defer { try? FileManager.default.removeItem(at: root) }

        let pdfURL = root.appendingPathComponent("scanned-cloudflare.pdf")
        try FixtureGenerator.makeScannedPDF(lines: [
            "Cloudflare, Inc.", "cloudflare.com", "INVOICE",
            "Invoice date: March 1, 2026", "Invoice #: INV-9999",
            "Total: $30.00",
        ], at: pdfURL)

        let extraction = try PDFTextExtractor.extract(from: pdfURL)
        #expect(extraction.likelyScanned, "fixture must have no real text layer to exercise the OCR path")

        let rules = try VendorRuleLoader.loadBundledRules()
        let record = try ExtractionPipeline.process(fileURL: pdfURL, library: library, rules: rules)

        #expect(!record.needsReview, "expected OCR text to clear the same gates as digital text, got: \(record.reviewReason ?? "none")")
        #expect(record.vendor == "Cloudflare")
        #expect(record.invoiceNumber == "INV-9999")
        #expect(record.totalMinorUnits == 3000)
    }

    @Test func blankScannedPageStillGoesToReview() throws {
        let library = try makeTempLibrary()
        let root = try library.rootURL()
        defer { try? FileManager.default.removeItem(at: root) }

        let pdfURL = root.appendingPathComponent("blank.pdf")
        try FixtureGenerator.makeScannedPDF(lines: [], at: pdfURL)

        let rules = try VendorRuleLoader.loadBundledRules()
        let record = try ExtractionPipeline.process(fileURL: pdfURL, library: library, rules: rules)

        #expect(record.needsReview)
    }
}
