// SPDX-License-Identifier: MPL-2.0
import Foundation

public enum NameTemplateError: Error {
    case missingField(String)
}

/// Renders a filename from a `{token}` pattern, e.g.
/// `"{date}_{vendor}_{invoiceNumber}_{amount}{currency}"`.
public struct NameTemplate {
    public let pattern: String
    public let fileExtension: String

    public init(pattern: String, fileExtension: String) {
        self.pattern = pattern
        self.fileExtension = fileExtension
    }

    public func render(fields: [String: String]) throws -> String {
        var stem = pattern
        for (key, value) in fields {
            stem = stem.replacingOccurrences(of: "{\(key)}", with: Self.sanitize(value))
        }
        if let range = stem.range(of: "{"), stem[range.upperBound...].contains("}") {
            let token = String(stem[range.lowerBound...]).prefix(while: { $0 != "}" }) + "}"
            throw NameTemplateError.missingField(String(token))
        }
        return Self.truncatingToByteLimit(stem, extension: fileExtension)
    }

    /// Whitelist-based: keep alphanumerics, `-`, `_`, `.`; replace everything
    /// else (including `/`, control chars, NUL) with `-`. Trims leading dots
    /// and trailing whitespace/dots from the *raw* input first — trimming
    /// after substitution would miss them, since illegal trailing chars have
    /// already been turned into `-` by then.
    public static func sanitize(_ raw: String) -> String {
        var trimmed = Substring(raw)
        while trimmed.hasPrefix(".") { trimmed.removeFirst() }
        while let last = trimmed.last, last == " " || last == "." { trimmed.removeLast() }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return String(trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
    }

    /// Truncates the stem to fit within a 255-*byte* (not character) filename
    /// limit alongside its extension. Cuts on whole `Character` boundaries —
    /// never mid-codepoint — by accumulating UTF-8 byte counts per character
    /// rather than slicing the raw byte buffer (which can leave a dangling
    /// lead byte that decodes as a differently-sized U+FFFD replacement).
    public static func truncatingToByteLimit(_ stem: String, extension ext: String) -> String {
        let suffix = ".\(ext)"
        let budget = 255 - suffix.utf8.count
        guard stem.utf8.count > budget else { return stem + suffix }

        var result = ""
        var byteCount = 0
        for character in stem {
            let characterByteCount = String(character).utf8.count
            guard byteCount + characterByteCount <= budget else { break }
            result.append(character)
            byteCount += characterByteCount
        }
        return result + suffix
    }
}
