// SPDX-License-Identifier: MPL-2.0
import Testing
import Foundation
@testable import DenzelCore

struct UndoServiceTests {
    @Test func undoRemovesFreshlyFiledDocument() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try GRDBDocumentStore(path: root.appendingPathComponent("index.sqlite").path)
        let journal = Journal(fileURL: root.appendingPathComponent("journal.jsonl"))
        let filer = LibraryFiler(root: root, store: store, journal: journal)
        let undo = UndoService(root: root, store: store, journal: journal)

        let source = root.appendingPathComponent("incoming.pdf")
        try "bytes".data(using: .utf8)!.write(to: source)
        let record = try filer.file(source: source, fields: FiledFields(vendor: "Linear", invoiceNumber: "L-1"))
        let filedURL = root.appendingPathComponent(record.filePath)
        #expect(FileManager.default.fileExists(atPath: filedURL.path))

        try undo.undoLast()

        #expect(!FileManager.default.fileExists(atPath: filedURL.path))
        #expect(try store.find(id: record.id) == nil)
    }

    @Test func undoRevertsAMoveBackToItsOrigin() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try GRDBDocumentStore(path: root.appendingPathComponent("index.sqlite").path)
        let journal = Journal(fileURL: root.appendingPathComponent("journal.jsonl"))
        let filer = LibraryFiler(root: root, store: store, journal: journal)
        let undo = UndoService(root: root, store: store, journal: journal)

        let source = root.appendingPathComponent("incoming.pdf")
        try "bytes".data(using: .utf8)!.write(to: source)
        let staged = try filer.stage(source: source)
        let finalized = try filer.finalize(recordID: staged.id, fields: FiledFields(vendor: "Notion", invoiceNumber: "N-1", needsReview: false))

        try undo.undoLast()

        let reverted = try store.find(id: staged.id)
        #expect(reverted?.filePath == staged.filePath)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(staged.filePath).path))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(finalized.filePath).path))
    }
}
