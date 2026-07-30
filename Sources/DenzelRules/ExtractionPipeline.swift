// SPDX-License-Identifier: MPL-2.0
import Foundation
import DenzelCore

/// Orchestrates: extract -> likelyScanned check -> vendor gate -> field gate
/// -> file or flag for review. Every document, whether dropped by hand or
/// picked up automatically, goes through the same `LibraryFiler.stage()` +
/// this pipeline — there's one ingestion code path, not two.
public enum ExtractionPipeline {
    private static let requiredFields = ["invoice_number", "total", "issue_date"]

    @discardableResult
    public static func process(fileURL: URL, library: DenzelLibrary, rules: [VendorRule]) throws -> DocumentRecord {
        let staged = try library.filer().stage(source: fileURL)
        return try processStaged(staged, library: library, rules: rules)
    }

    @discardableResult
    public static func processStaged(_ staged: DocumentRecord, library: DenzelLibrary, rules: [VendorRule]) throws -> DocumentRecord {
        let root = try library.rootURL()
        let stagedURL = root.appendingPathComponent(staged.filePath)
        let extraction = try PDFTextExtractor.extract(from: stagedURL)

        var text = extraction.fullText
        if extraction.likelyScanned {
            // OCR is a quality fallback, not a trust upgrade: whatever text
            // comes back — digital or recognized — runs through the exact
            // same vendor/field confidence gates below.
            let ocrText = (try? VisionTextRecognizer.recognizeText(from: stagedURL)) ?? ""
            guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return try library.filer().finalize(
                    recordID: staged.id,
                    fields: FiledFields(vendor: "Unknown", needsReview: true, reviewReason: "no text layer and OCR found no text")
                )
            }
            text = ocrText
        }

        guard let vendorMatch = VendorMatcher.bestMatch(in: text, rules: rules),
              vendorMatch.confidence >= ConfidenceThresholds.vendorMatch
        else {
            return try library.filer().finalize(
                recordID: staged.id,
                fields: FiledFields(vendor: "Unknown", needsReview: true, reviewReason: "vendor not confidently identified", extractedText: text)
            )
        }

        let extracted = FieldExtractor.extract(fields: vendorMatch.rule.fields, from: text)
        let missing = requiredFields.filter { (extracted[$0]?.confidence ?? 0) < ConfidenceThresholds.fieldMinimum }

        var confidenceFields: [String: Double] = [:]
        for (key, field) in extracted { confidenceFields[key] = field.confidence }
        let overallConfidence = min(vendorMatch.confidence, extracted.values.map(\.confidence).min() ?? 0)

        let fields = FiledFields(
            vendor: vendorMatch.rule.name,
            invoiceNumber: extracted["invoice_number"]?.value,
            issueDate: extracted["issue_date"]?.value,
            totalMinorUnits: (extracted["total"]?.value).flatMap { Int($0) },
            currency: detectCurrency(in: text),
            confidenceOverall: overallConfidence,
            confidenceFields: confidenceFields,
            needsReview: !missing.isEmpty,
            reviewReason: missing.isEmpty ? nil : "missing or low-confidence: \(missing.joined(separator: ", "))",
            extractedText: text
        )
        return try library.filer().finalize(recordID: staged.id, fields: fields)
    }

    private static func detectCurrency(in text: String) -> String {
        if text.contains("€") { return "EUR" }
        if text.contains("£") { return "GBP" }
        return "USD"
    }
}
