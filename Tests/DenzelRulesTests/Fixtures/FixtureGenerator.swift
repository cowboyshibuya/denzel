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
}
