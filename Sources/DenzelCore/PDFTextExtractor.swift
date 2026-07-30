// SPDX-License-Identifier: MPL-2.0
import Foundation
import PDFKit

public struct TextExtractionResult {
    public let fullText: String
    public let perPageCharCounts: [Int]

    /// Triggers the Vision OCR fallback (`VisionTextRecognizer`): below
    /// ~50 chars/page means the page almost certainly has no real text layer.
    public var likelyScanned: Bool {
        !perPageCharCounts.isEmpty && perPageCharCounts.allSatisfy { $0 < 50 }
    }

    public init(fullText: String, perPageCharCounts: [Int]) {
        self.fullText = fullText
        self.perPageCharCounts = perPageCharCounts
    }
}

public enum PDFTextExtractionError: Error {
    case unreadable
}

public enum PDFTextExtractor {
    public static func extract(from url: URL) throws -> TextExtractionResult {
        guard let document = PDFDocument(url: url) else { throw PDFTextExtractionError.unreadable }
        var fullText = ""
        var perPageCharCounts: [Int] = []
        for pageIndex in 0..<document.pageCount {
            let pageText = document.page(at: pageIndex)?.string ?? ""
            perPageCharCounts.append(pageText.count)
            fullText += pageText + "\n"
        }
        return TextExtractionResult(fullText: fullText, perPageCharCounts: perPageCharCounts)
    }
}
