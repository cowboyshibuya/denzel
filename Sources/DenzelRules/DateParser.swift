// SPDX-License-Identifier: MPL-2.0
import Foundation

public struct DateKeyword {
    public let language: String
    public let phrases: [String]

    public init(language: String, phrases: [String]) {
        self.language = language
        self.phrases = phrases
    }
}

// Deliberately no bare "Date" fallback: it matches "Due date", "Period date",
// even the word "date" inside prose, and anchors on the wrong nearby date —
// exactly the bug this proximity approach exists to avoid. Every keyword
// here is specific enough to (almost always) mean the invoice's own date.
public let defaultInvoiceDateKeywords: [DateKeyword] = [
    DateKeyword(language: "en", phrases: ["Invoice date", "Date of issue"]),
    DateKeyword(language: "fr", phrases: ["Date de facture", "Date d'émission"]),
    DateKeyword(language: "nl", phrases: ["Factuurdatum"]),
    DateKeyword(language: "de", phrases: ["Rechnungsdatum"]),
]

/// Finds the invoice date by anchoring on proximity to a keyword phrase —
/// never "the first date on the page" (often a period-start or due-date,
/// not the invoice date itself). Uses `NSDataDetector` for native,
/// locale-aware date-shape recognition instead of a hand-rolled format table.
public func extractInvoiceDate(
    from text: String,
    keywords: [DateKeyword] = defaultInvoiceDateKeywords,
    proximityWindow: Int = 60
) -> (date: Date, confidence: Double)? {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
        return nil
    }

    let nsText = text as NSString
    let dateMatches = detector.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        .compactMap { match -> (range: NSRange, date: Date)? in
            guard let date = match.date else { return nil }
            return (match.range, date)
        }
    guard !dateMatches.isEmpty else { return nil }

    let keywordRanges: [NSRange] = keywords.flatMap { keyword in
        keyword.phrases.compactMap { phrase -> NSRange? in
            let range = nsText.range(of: phrase, options: .caseInsensitive)
            return range.location == NSNotFound ? nil : range
        }
    }
    guard !keywordRanges.isEmpty else { return nil }

    var best: (date: Date, distance: Int)?
    for dateMatch in dateMatches {
        for keywordRange in keywordRanges {
            let distance = abs(dateMatch.range.location - (keywordRange.location + keywordRange.length))
            guard distance <= proximityWindow else { continue }
            if best == nil || distance < best!.distance {
                best = (dateMatch.date, distance)
            }
        }
    }

    guard let best else { return nil }
    let confidence = 1.0 - (Double(best.distance) / Double(proximityWindow)) * 0.5
    return (best.date, max(0.5, confidence))
}
