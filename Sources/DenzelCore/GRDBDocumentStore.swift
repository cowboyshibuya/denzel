// SPDX-License-Identifier: MPL-2.0
import Foundation
import GRDB

public final class GRDBDocumentStore: DocumentStore {
    private let dbQueue: DatabaseQueue

    public init(path: String) throws {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }
        dbQueue = try DatabaseQueue(path: path, configuration: configuration)
        try Self.migrator.migrate(dbQueue)
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_documents") { db in
            try db.create(table: "document") { t in
                t.column("id", .text).primaryKey()
                t.column("vendor", .text).notNull()
                t.column("invoiceNumber", .text)
                t.column("issueDate", .text)
                t.column("totalMinorUnits", .integer)
                t.column("currency", .text)
                t.column("confidenceOverall", .double).notNull().defaults(to: 0)
                t.column("confidenceFields", .text).notNull().defaults(to: "{}")
                t.column("filePath", .text).notNull().unique()
                t.column("contentHash", .text).notNull().unique()
                t.column("filedAt", .datetime).notNull()
                t.column("schemaVersion", .integer).notNull().defaults(to: 1)
                t.column("needsReview", .boolean).notNull().defaults(to: false)
                t.column("reviewReason", .text)
            }
            try db.create(
                index: "document_vendor_invoice_idx",
                on: "document",
                columns: ["vendor", "invoiceNumber"],
                unique: true,
                condition: Column("invoiceNumber") != nil
            )
            try db.create(index: "document_needs_review_idx", on: "document", columns: ["needsReview"])
        }
        migrator.registerMigration("v2_fts5_search") { db in
            try db.create(virtualTable: "document_fts", using: FTS5()) { table in
                table.column("documentID").notIndexed()
                table.column("vendor")
                table.column("invoiceNumber")
                table.column("fullText")
            }
        }
        return migrator
    }

    public func insert(_ record: DocumentRecord) throws {
        try dbQueue.write { db in try record.insert(db) }
    }

    public func update(_ record: DocumentRecord) throws {
        try dbQueue.write { db in try record.update(db) }
    }

    public func delete(id: UUID) throws {
        _ = try dbQueue.write { db in try DocumentRecord.deleteOne(db, key: id) }
    }

    public func find(id: UUID) throws -> DocumentRecord? {
        try dbQueue.read { db in try DocumentRecord.fetchOne(db, key: id) }
    }

    public func find(contentHash: String) throws -> DocumentRecord? {
        try dbQueue.read { db in
            try DocumentRecord.filter(Column("contentHash") == contentHash).fetchOne(db)
        }
    }

    public func find(vendor: String, invoiceNumber: String) throws -> DocumentRecord? {
        try dbQueue.read { db in
            try DocumentRecord
                .filter(Column("vendor") == vendor && Column("invoiceNumber") == invoiceNumber)
                .fetchOne(db)
        }
    }

    public func fetchAll() throws -> [DocumentRecord] {
        try dbQueue.read { db in try DocumentRecord.fetchAll(db) }
    }

    public func fetchNeedingReview() throws -> [DocumentRecord] {
        try dbQueue.read { db in
            try DocumentRecord.filter(Column("needsReview") == true).fetchAll(db)
        }
    }

    public func rebuild(with records: [DocumentRecord]) throws {
        try dbQueue.write { db in
            try DocumentRecord.deleteAll(db)
            try db.execute(sql: "DELETE FROM document_fts")
            for record in records { try record.insert(db) }
        }
    }

    public func indexText(documentID: UUID, vendor: String, invoiceNumber: String?, fullText: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM document_fts WHERE documentID = ?", arguments: [documentID.uuidString])
            try db.execute(
                sql: "INSERT INTO document_fts (documentID, vendor, invoiceNumber, fullText) VALUES (?, ?, ?, ?)",
                arguments: [documentID.uuidString, vendor, invoiceNumber ?? "", fullText]
            )
        }
    }

    public func removeIndex(documentID: UUID) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM document_fts WHERE documentID = ?", arguments: [documentID.uuidString])
        }
    }

    public func search(_ query: String) throws -> [DocumentRecord] {
        try dbQueue.read { db in
            let ids = try String.fetchAll(
                db,
                sql: "SELECT documentID FROM document_fts WHERE document_fts MATCH ? ORDER BY bm25(document_fts)",
                arguments: [Self.ftsMatchExpression(for: query)]
            )
            // FTS gives us rank order; look each document up and preserve it.
            return try ids.compactMap { UUID(uuidString: $0) }.compactMap { id in
                try DocumentRecord.fetchOne(db, key: id)
            }
        }
    }

    /// Turns free-text user input into a safe FTS5 MATCH expression: each
    /// whitespace-separated term becomes a quoted, prefix-matched literal
    /// ANDed together — quoting avoids FTS5 syntax errors on special
    /// characters in arbitrary search input.
    private static func ftsMatchExpression(for query: String) -> String {
        let terms = query.split(separator: " ").map { term -> String in
            let escaped = term.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\"*"
        }
        return terms.isEmpty ? "\"\"" : terms.joined(separator: " AND ")
    }
}
