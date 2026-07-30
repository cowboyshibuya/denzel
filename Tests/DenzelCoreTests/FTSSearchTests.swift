// SPDX-License-Identifier: MPL-2.0
import Testing
import Foundation
@testable import DenzelCore

struct FTSSearchTests {
    @Test func searchFindsByVendorAndBodyText() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try GRDBDocumentStore(path: root.appendingPathComponent("index.sqlite").path)
        let journal = Journal(fileURL: root.appendingPathComponent("journal.jsonl"))
        let filer = LibraryFiler(root: root, store: store, journal: journal)

        let cloudflareSource = root.appendingPathComponent("a.pdf")
        try "fixture-a".data(using: .utf8)!.write(to: cloudflareSource)
        try filer.file(
            source: cloudflareSource,
            fields: FiledFields(vendor: "Cloudflare", invoiceNumber: "INV-1", extractedText: "Cloudflare Pro Plan subscription for March 2026")
        )

        let stripeSource = root.appendingPathComponent("b.pdf")
        try "fixture-b".data(using: .utf8)!.write(to: stripeSource)
        try filer.file(
            source: stripeSource,
            fields: FiledFields(vendor: "Stripe", invoiceNumber: "INV-2", extractedText: "Stripe payment processing fees")
        )

        let byVendor = try store.search("cloudflare")
        #expect(byVendor.map(\.vendor) == ["Cloudflare"])

        let byBodyText = try store.search("processing")
        #expect(byBodyText.map(\.vendor) == ["Stripe"])

        let noMatch = try store.search("nonexistentterm")
        #expect(noMatch.isEmpty)
    }

    @Test func rebuildRepopulatesSearchIndexFromDiskText() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let dbPath = root.appendingPathComponent("index.sqlite").path
        let journal = Journal(fileURL: root.appendingPathComponent("journal.jsonl"))
        let filer = LibraryFiler(root: root, store: try GRDBDocumentStore(path: dbPath), journal: journal)

        let source = root.appendingPathComponent("a.pdf")
        try "fixture".data(using: .utf8)!.write(to: source)
        try filer.file(source: source, fields: FiledFields(vendor: "Vercel", invoiceNumber: "V-1"))

        try FileManager.default.removeItem(atPath: dbPath)
        try? FileManager.default.removeItem(atPath: dbPath + "-wal")
        try? FileManager.default.removeItem(atPath: dbPath + "-shm")
        let rebuiltStore = try GRDBDocumentStore(path: dbPath)
        try LibraryScanner.rebuild(root: root, into: rebuiltStore)

        // The filed file isn't a real PDF, so re-extraction yields no body
        // text — but vendor/invoiceNumber alone must still be searchable.
        let results = try rebuiltStore.search("vercel")
        #expect(results.map(\.vendor) == ["Vercel"])
    }
}
