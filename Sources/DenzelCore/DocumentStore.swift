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
}
