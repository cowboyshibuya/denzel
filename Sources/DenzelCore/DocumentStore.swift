// SPDX-License-Identifier: MPL-2.0
import Foundation

/// A fully rebuildable index over filed documents. GRDB/SQLite is today's
/// implementation; callers only ever see this protocol.
public protocol DocumentStore {
    func insert(_ record: DocumentRecord) throws
    func update(_ record: DocumentRecord) throws
    func delete(id: UUID) throws
    func find(id: UUID) throws -> DocumentRecord?
    func find(contentHash: String) throws -> DocumentRecord?
    func find(vendor: String, invoiceNumber: String) throws -> DocumentRecord?
    func fetchAll() throws -> [DocumentRecord]
    func fetchNeedingReview() throws -> [DocumentRecord]

    /// Wipes and repopulates the entire index from the given records — the
    /// operation `LibraryScanner` drives to prove the index is rebuildable.
    func rebuild(with records: [DocumentRecord]) throws

    /// (Re)indexes a document's searchable text. `fullText` may be empty —
    /// vendor/invoiceNumber alone still make a manually-filed document with
    /// no extracted body text findable.
    func indexText(documentID: UUID, vendor: String, invoiceNumber: String?, fullText: String) throws
    func removeIndex(documentID: UUID) throws
    func search(_ query: String) throws -> [DocumentRecord]
}
