// SPDX-License-Identifier: MPL-2.0
import Testing
import Foundation
@testable import DenzelCore

private func makeTempLibrary() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func makeFixturePDF(in dir: URL, name: String = "test.pdf", contents: String = "fixture") throws -> URL {
    let url = dir.appendingPathComponent(name)
    try contents.data(using: .utf8)!.write(to: url)
    return url
}

struct LibraryFilerTests {
    @Test func filesDirectlyAndWritesSidecar() throws {
        let root = try makeTempLibrary()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try makeFixturePDF(in: root, name: "incoming.pdf")

        let store = try GRDBDocumentStore(path: root.appendingPathComponent("index.sqlite").path)
        let journal = Journal(fileURL: root.appendingPathComponent("journal.jsonl"))
        let filer = LibraryFiler(root: root, store: store, journal: journal)

        let record = try filer.file(
            source: source,
            fields: FiledFields(vendor: "Cloudflare", invoiceNumber: "INV-1", issueDate: "2026-03-01", totalMinorUnits: 2000, currency: "EUR")
        )

        #expect(record.filePath == "vendors/cloudflare/2026/2026-03-01_cloudflare_INV-1_20.00EUR.pdf")
        let filedURL = root.appendingPathComponent(record.filePath)
        #expect(FileManager.default.fileExists(atPath: filedURL.path))
        #expect(try Xattr.get(at: filedURL) != nil)
        #expect(try journal.readAll().count == 1)
    }

    @Test func rejectsExactByteDuplicate() throws {
        let root = try makeTempLibrary()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try GRDBDocumentStore(path: root.appendingPathComponent("index.sqlite").path)
        let journal = Journal(fileURL: root.appendingPathComponent("journal.jsonl"))
        let filer = LibraryFiler(root: root, store: store, journal: journal)

        let source1 = try makeFixturePDF(in: root, name: "a.pdf", contents: "same-bytes")
        _ = try filer.file(source: source1, fields: FiledFields(vendor: "GitHub", invoiceNumber: "A"))

        let source2 = try makeFixturePDF(in: root, name: "b.pdf", contents: "same-bytes")
        #expect(throws: LibraryFiler.FilerError.self) {
            try filer.file(source: source2, fields: FiledFields(vendor: "GitHub", invoiceNumber: "B"))
        }
    }

    @Test func rejectsSameVendorInvoiceWithDifferentBytes() throws {
        let root = try makeTempLibrary()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try GRDBDocumentStore(path: root.appendingPathComponent("index.sqlite").path)
        let journal = Journal(fileURL: root.appendingPathComponent("journal.jsonl"))
        let filer = LibraryFiler(root: root, store: store, journal: journal)

        let source1 = try makeFixturePDF(in: root, name: "a.pdf", contents: "version-1-bytes")
        _ = try filer.file(source: source1, fields: FiledFields(vendor: "Stripe", invoiceNumber: "INV-99"))

        let source2 = try makeFixturePDF(in: root, name: "b.pdf", contents: "version-2-bytes-regenerated")
        #expect(throws: LibraryFiler.FilerError.self) {
            try filer.file(source: source2, fields: FiledFields(vendor: "Stripe", invoiceNumber: "INV-99"))
        }
    }

    @Test func stageThenFinalizeMovesFromInboxToVendorPath() throws {
        let root = try makeTempLibrary()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try GRDBDocumentStore(path: root.appendingPathComponent("index.sqlite").path)
        let journal = Journal(fileURL: root.appendingPathComponent("journal.jsonl"))
        let filer = LibraryFiler(root: root, store: store, journal: journal)

        let source = try makeFixturePDF(in: root, name: "dropped.pdf")
        let staged = try filer.stage(source: source)
        #expect(staged.filePath.hasPrefix("_staging/"))
        #expect(staged.needsReview)

        let finalized = try filer.finalize(
            recordID: staged.id,
            fields: FiledFields(vendor: "Vercel", invoiceNumber: "V-1", issueDate: "2026-01-15", totalMinorUnits: 999, currency: "USD", needsReview: false)
        )
        #expect(finalized.filePath == "vendors/vercel/2026/2026-01-15_vercel_V-1_9.99USD.pdf")
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(staged.filePath).path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(finalized.filePath).path))
        #expect(try journal.readAll().count == 2)   // stage (.file) + finalize (.move)
    }
}
