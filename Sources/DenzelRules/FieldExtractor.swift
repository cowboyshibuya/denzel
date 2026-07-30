// SPDX-License-Identifier: MPL-2.0
import Foundation

public struct ExtractedField {
    public let value: String
    public let confidence: Double
}

public enum FieldExtractor {
    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    public static func extract(fields: [String: VendorRule.FieldRule], from text: String) -> [String: ExtractedField] {
        var results: [String: ExtractedField] = [:]
        for (name, rule) in fields {
            if let pattern = rule.regex, let capture = firstCapture(pattern: pattern, in: text) {
                if rule.money == true, let minorUnits = try? parseMoneyMinorUnits(capture) {
                    results[name] = ExtractedField(value: String(minorUnits), confidence: 0.9)
                } else {
                    results[name] = ExtractedField(value: capture, confidence: 0.9)
                }
            } else if let near = rule.near {
                let keywords = [DateKeyword(language: "custom", phrases: near)]
                if let match = extractInvoiceDate(from: text, keywords: keywords) {
                    results[name] = ExtractedField(value: isoDateFormatter.string(from: match.date), confidence: match.confidence)
                }
            }
        }
        return results
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
              match.numberOfRanges > 1 else { return nil }
        return nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
    }
}
