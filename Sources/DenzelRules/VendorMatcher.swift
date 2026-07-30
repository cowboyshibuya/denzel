// SPDX-License-Identifier: MPL-2.0
import Foundation

public struct VendorMatch {
    public let rule: VendorRule
    public let confidence: Double
}

/// For clean digital text (M2's scope), vendor confidence is effectively
/// binary: an exact `text_contains`/`vat_id` match or not. Fuzzy/Levenshtein
/// alias matching only starts earning its keep once OCR (M3) introduces
/// noisy text — not built here.
public enum VendorMatcher {
    public static func bestMatch(in text: String, rules: [VendorRule]) -> VendorMatch? {
        for rule in rules {
            for condition in rule.match.any {
                if let textContains = condition.textContains, text.localizedCaseInsensitiveContains(textContains) {
                    return VendorMatch(rule: rule, confidence: 1.0)
                }
                if let vatID = condition.vatID, text.contains(vatID) {
                    return VendorMatch(rule: rule, confidence: 1.0)
                }
            }
        }
        return nil
    }
}
