// SPDX-License-Identifier: MPL-2.0
import Foundation
import CoreGraphics
import CoreText

enum FixtureGeneratorError: Error {
    case contextCreationFailed
}

/// Generates a minimal single-page text PDF via CoreGraphics/CoreText —
/// no AppKit needed, so it runs headless in CI. Regenerated at test time
/// rather than committed as a binary fixture: these tests only assert on
/// extracted text/fields, not visual fidelity, so there's nothing a
/// checked-in binary would buy over generating it fresh every run.
enum FixtureGenerator {
    static func makePDF(lines: [String], at url: URL) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            throw FixtureGeneratorError.contextCreationFailed
        }

        context.beginPDFPage(nil)
        let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
        var y: CGFloat = 740
        for line in lines {
            let attributed = NSAttributedString(string: line, attributes: [
                .font: font,
                .foregroundColor: CGColor(gray: 0, alpha: 1),
            ])
            let ctLine = CTLineCreateWithAttributedString(attributed)
            context.textPosition = CGPoint(x: 50, y: y)
            CTLineDraw(ctLine, context)
            y -= 20
        }
        context.endPDFPage()
        context.closePDF()
    }

    /// Generates a PDF with NO real text layer — the lines are rendered to a
    /// raster image first, then that image is embedded as the entire page
    /// content. `PDFPage.string` returns empty for this, exactly like a real
    /// scanned document, exercising the Vision OCR fallback path.
    static func makeScannedPDF(lines: [String], at url: URL) throws {
        let pageWidth = 612.0
        let pageHeight = 792.0
        let scale = 2.0

        guard let imageContext = CGContext(
            data: nil,
            width: Int(pageWidth * scale),
            height: Int(pageHeight * scale),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw FixtureGeneratorError.contextCreationFailed }

        imageContext.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        imageContext.fill(CGRect(x: 0, y: 0, width: pageWidth * scale, height: pageHeight * scale))
        imageContext.scaleBy(x: scale, y: scale)

        let font = CTFontCreateWithName("Helvetica" as CFString, 16, nil)
        var y = pageHeight - 80
        for line in lines {
            let attributed = NSAttributedString(string: line, attributes: [
                .font: font,
                .foregroundColor: CGColor(gray: 0, alpha: 1),
            ])
            let ctLine = CTLineCreateWithAttributedString(attributed)
            imageContext.textPosition = CGPoint(x: 50, y: y)
            CTLineDraw(ctLine, imageContext)
            y -= 28
        }
        guard let rasterImage = imageContext.makeImage() else { throw FixtureGeneratorError.contextCreationFailed }

        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { throw FixtureGeneratorError.contextCreationFailed }

        pdfContext.beginPDFPage(nil)
        pdfContext.draw(rasterImage, in: mediaBox)
        pdfContext.endPDFPage()
        pdfContext.closePDF()
    }
}
