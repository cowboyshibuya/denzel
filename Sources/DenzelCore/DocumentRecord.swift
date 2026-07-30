// SPDX-License-Identifier: MPL-2.0
import Foundation
import GRDB

public struct DocumentRecord: Codable, Equatable, Identifiable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "document"

    public var id: UUID
    public var vendor: String
    public var invoiceNumber: String?
    public var issueDate: String?
    public var totalMinorUnits: Int?
    public var currency: String?
    public var confidenceOverall: Double
    public var confidenceFields: String   // JSON-encoded [String: Double]
    public var filePath: String           // relative to library root
    public var contentHash: String
    public var filedAt: Date
    public var schemaVersion: Int
    public var needsReview: Bool
    public var reviewReason: String?

    public init(
        id: UUID,
        vendor: String,
        invoiceNumber: String?,
        issueDate: String?,
        totalMinorUnits: Int?,
        currency: String?,
        confidenceOverall: Double,
        confidenceFields: String,
        filePath: String,
        contentHash: String,
        filedAt: Date,
        schemaVersion: Int,
        needsReview: Bool,
        reviewReason: String?
    ) {
        self.id = id
        self.vendor = vendor
        self.invoiceNumber = invoiceNumber
        self.issueDate = issueDate
        self.totalMinorUnits = totalMinorUnits
        self.currency = currency
        self.confidenceOverall = confidenceOverall
        self.confidenceFields = confidenceFields
        self.filePath = filePath
        self.contentHash = contentHash
        self.filedAt = filedAt
        self.schemaVersion = schemaVersion
        self.needsReview = needsReview
        self.reviewReason = reviewReason
    }

    public init(sidecar: DocumentSidecar, filePath: String) {
        let confidenceJSON = (try? JSONEncoder().encode(sidecar.confidenceFields))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        self.init(
            id: sidecar.id,
            vendor: sidecar.vendor,
            invoiceNumber: sidecar.invoiceNumber,
            issueDate: sidecar.issueDate,
            totalMinorUnits: sidecar.totalMinorUnits,
            currency: sidecar.currency,
            confidenceOverall: sidecar.confidenceOverall,
            confidenceFields: confidenceJSON,
            filePath: filePath,
            contentHash: sidecar.contentHash,
            filedAt: sidecar.filedAt,
            schemaVersion: sidecar.schemaVersion,
            needsReview: sidecar.needsReview,
            reviewReason: sidecar.reviewReason
        )
    }
}
