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
            for record in records { try record.insert(db) }
        }
    }
}
