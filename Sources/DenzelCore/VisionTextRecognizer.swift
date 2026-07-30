// SPDX-License-Identifier: MPL-2.0
import Foundation
import PDFKit
import Vision
import CoreGraphics

public enum VisionTextRecognizerError: Error {
    case unreadable
    case renderFailed
}

/// The OCR fallback for `PDFTextExtractor.likelyScanned` documents: renders
/// each page at 300 DPI (not `PDFPage.thumbnail`, which is tuned for small
/// previews, not glyph fidelity a recognizer needs) and runs Vision's
/// on-device text recognizer. OCR text feeds the exact same vendor/field
/// confidence gates as a real text layer — never treated as more trustworthy
/// just because it took more work to get.
public enum VisionTextRecognizer {
    public static func recognizeText(from url: URL, dpi: CGFloat = 300) throws -> String {
        guard let document = PDFDocument(url: url) else { throw VisionTextRecognizerError.unreadable }
        var pages: [String] = []
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            guard let image = try render(page, dpi: dpi) else { continue }
            pages.append(try recognize(in: image))
        }
        return pages.joined(separator: "\n")
    }

    private static func render(_ page: PDFPage, dpi: CGFloat) throws -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let scale = dpi / 72.0
        let width = Int(bounds.width * scale)
        let height = Int(bounds.height * scale)
        guard width > 0, height > 0 else { return nil }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw VisionTextRecognizerError.renderFailed }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)
        page.draw(with: .mediaBox, to: context)
        return context.makeImage()
    }

    private static func recognize(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}
