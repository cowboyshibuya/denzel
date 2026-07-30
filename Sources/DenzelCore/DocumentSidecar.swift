// SPDX-License-Identifier: MPL-2.0
import Foundation

/// The payload written into every filed document's `com.denzel.meta` xattr.
/// Deliberately excludes its own file path — the path is whatever
/// `LibraryScanner` found the file at; a self-referential path would go
/// stale the instant someone drags the file around in Finder.
public struct DocumentSidecar: Codable, Equatable {
    public static let currentSchemaVersion = 1

    public let id: UUID
    public var vendor: String
    public var invoiceNumber: String?
    public var issueDate: String?          // ISO8601 "YYYY-MM-DD"
    public var totalMinorUnits: Int?
    public var currency: String?
    public var confidenceOverall: Double
    public var confidenceFields: [String: Double]
    public var contentHash: String
    public var filedAt: Date
    public var needsReview: Bool
    public var reviewReason: String?
    public var schemaVersion: Int

    public init(
        id: UUID = UUID(),
        vendor: String,
        invoiceNumber: String? = nil,
        issueDate: String? = nil,
        totalMinorUnits: Int? = nil,
        currency: String? = nil,
        confidenceOverall: Double = 0,
        confidenceFields: [String: Double] = [:],
        contentHash: String,
        filedAt: Date = Date(),
        needsReview: Bool = false,
        reviewReason: String? = nil,
        schemaVersion: Int = DocumentSidecar.currentSchemaVersion
    ) {
        self.id = id
        self.vendor = vendor
        self.invoiceNumber = invoiceNumber
        self.issueDate = issueDate
        self.totalMinorUnits = totalMinorUnits
        self.currency = currency
        self.confidenceOverall = confidenceOverall
        self.confidenceFields = confidenceFields
        self.contentHash = contentHash
        self.filedAt = filedAt
        self.needsReview = needsReview
        self.reviewReason = reviewReason
        self.schemaVersion = schemaVersion
    }
}
