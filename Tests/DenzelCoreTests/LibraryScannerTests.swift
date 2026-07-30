// SPDX-License-Identifier: MPL-2.0
import Testing
import Foundation
@testable import DenzelCore

/// This is the concrete M1 done-when: delete index.sqlite, rescan, get the
/// identical index back — the filesystem + xattr sidecars are the truth.
struct LibraryScannerTests {
    @Test func rebuildsIdenticalIndexAfterDeletingSQLite() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let dbPath = root.appendingPathComponent("index.sqlite").path
        let journal = Journal(fileURL: root.appendingPathComponent("journal.jsonl"))
        let filer = LibraryFiler(root: root, store: try GRDBDocumentStore(path: dbPath), journal: journal)

        for i in 0..<3 {
            let source = root.appendingPathComponent("incoming-\(i).pdf")
            try "fixture-\(i)".data(using: .utf8)!.write(to: source)
            _ = try filer.file(
                source: source,
                fields: FiledFields(vendor: "Vendor\(i)", invoiceNumber: "INV-\(i)", issueDate: "2026-0\(i + 1)-01", totalMinorUnits: 1000 * (i + 1), currency: "USD")
            )
        }

        let before = try LibraryScanner.scan(root: root).sorted { $0.filePath < $1.filePath }
        #expect(before.count == 3)

        try FileManager.default.removeItem(atPath: dbPath)
        try? FileManager.default.removeItem(atPath: dbPath + "-wal")
        try? FileManager.default.removeItem(atPath: dbPath + "-shm")

        let rebuiltStore = try GRDBDocumentStore(path: dbPath)
        try LibraryScanner.rebuild(root: root, into: rebuiltStore)
        let after = try rebuiltStore.fetchAll().sorted { $0.filePath < $1.filePath }

        #expect(after.count == before.count)
        for (b, a) in zip(before, after) {
            #expect(b.id == a.id)
            #expect(b.vendor == a.vendor)
            #expect(b.invoiceNumber == a.invoiceNumber)
            #expect(b.filePath == a.filePath)
            #expect(b.contentHash == a.contentHash)
        }
    }

    @Test func skipsFilesWithoutSidecar() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "not tracked".data(using: .utf8)!.write(to: root.appendingPathComponent("stray.pdf"))
        try "".data(using: .utf8)!.write(to: root.appendingPathComponent("journal.jsonl"))

        let records = try LibraryScanner.scan(root: root)
        #expect(records.isEmpty)
    }
}
