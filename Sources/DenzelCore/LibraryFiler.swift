// SPDX-License-Identifier: MPL-2.0
import Foundation

/// Everything known about a document at the point it's filed — whether that
/// knowledge came from a human (manual filing) or the extraction pipeline
/// (M2's auto-file path). Both go through the same `LibraryFiler` methods.
public struct FiledFields {
    public var vendor: String
    public var invoiceNumber: String?
    public var issueDate: String?          // ISO8601 "YYYY-MM-DD"
    public var totalMinorUnits: Int?
    public var currency: String?
    public var confidenceOverall: Double
    public var confidenceFields: [String: Double]
    public var needsReview: Bool
    public var reviewReason: String?

    public init(
        vendor: String,
        invoiceNumber: String? = nil,
        issueDate: String? = nil,
        totalMinorUnits: Int? = nil,
        currency: String? = nil,
        confidenceOverall: Double = 1,
        confidenceFields: [String: Double] = [:],
        needsReview: Bool = false,
        reviewReason: String? = nil
    ) {
        self.vendor = vendor
        self.invoiceNumber = invoiceNumber
        self.issueDate = issueDate
        self.totalMinorUnits = totalMinorUnits
        self.currency = currency
        self.confidenceOverall = confidenceOverall
        self.confidenceFields = confidenceFields
        self.needsReview = needsReview
        self.reviewReason = reviewReason
    }
}

/// The one "file a document" verb: dedupe check -> name template -> atomic
/// placement -> xattr write -> journal append -> store insert/update. Used
/// by manual filing (M1) and the auto-file pipeline (M2) alike — one code
/// path, not two.
public final class LibraryFiler {
    public enum FilerError: Error {
        case duplicateContent(existingID: UUID)
        case duplicateInvoice(existingID: UUID)
        case recordNotFound(UUID)
    }

    private let root: URL
    private let store: DocumentStore
    private let journal: Journal
    private let nameTemplate: NameTemplate

    public init(
        root: URL,
        store: DocumentStore,
        journal: Journal,
        nameTemplate: NameTemplate = NameTemplate(pattern: "{date}_{vendor}_{invoiceNumber}_{amount}{currency}", fileExtension: "pdf")
    ) {
        self.root = root
        self.store = store
        self.journal = journal
        self.nameTemplate = nameTemplate
    }

    /// Files `source` directly into its final vendor/year location. Used for
    /// manual filing and for the pipeline's confident auto-file success path.
    @discardableResult
    public func file(source: URL, fields: FiledFields, id: UUID = UUID()) throws -> DocumentRecord {
        let hash = try ContentHash.sha256(of: source)
        try checkForDuplicates(hash: hash, vendor: fields.vendor, invoiceNumber: fields.invoiceNumber)

        let relativePath = try finalPath(for: fields, contentHash: hash, extension: source.pathExtension.isEmpty ? "pdf" : source.pathExtension)
        let destination = root.appendingPathComponent(relativePath)
        try AtomicPlacer.place(source: source, at: destination)

        let sidecar = DocumentSidecar(
            id: id,
            vendor: fields.vendor,
            invoiceNumber: fields.invoiceNumber,
            issueDate: fields.issueDate,
            totalMinorUnits: fields.totalMinorUnits,
            currency: fields.currency,
            confidenceOverall: fields.confidenceOverall,
            confidenceFields: fields.confidenceFields,
            contentHash: hash,
            needsReview: fields.needsReview,
            reviewReason: fields.reviewReason
        )
        try Xattr.set(try JSONEncoder.denzel.encode(sidecar), at: destination)
        try journal.append(JournalEntry(operation: .file, documentID: id, fromPath: nil, toPath: relativePath, contentHash: hash))

        let record = DocumentRecord(sidecar: sidecar, filePath: relativePath)
        try store.insert(record)
        return record
    }

    /// Stages an incoming file into `Inbox/` with a placeholder sidecar so
    /// it's tracked immediately; the extraction pipeline or a reviewer fills
    /// in real fields and calls `finalize`.
    @discardableResult
    public func stage(source: URL, id: UUID = UUID()) throws -> DocumentRecord {
        let hash = try ContentHash.sha256(of: source)
        if let existing = try store.find(contentHash: hash) {
            throw FilerError.duplicateContent(existingID: existing.id)
        }

        let ext = source.pathExtension.isEmpty ? "pdf" : source.pathExtension
        let relativePath = "Inbox/\(id.uuidString).\(ext)"
        let destination = root.appendingPathComponent(relativePath)
        try AtomicPlacer.place(source: source, at: destination)

        let sidecar = DocumentSidecar(
            id: id,
            vendor: "Unknown",
            contentHash: hash,
            needsReview: true,
            reviewReason: "awaiting processing"
        )
        try Xattr.set(try JSONEncoder.denzel.encode(sidecar), at: destination)
        try journal.append(JournalEntry(operation: .file, documentID: id, fromPath: nil, toPath: relativePath, contentHash: hash))

        let record = DocumentRecord(sidecar: sidecar, filePath: relativePath)
        try store.insert(record)
        return record
    }

    /// Moves an already-staged document to its final vendor location once
    /// fields are known — the pipeline's confident path and a reviewer's
    /// "confirm" both call this with the same shape of input.
    @discardableResult
    public func finalize(recordID: UUID, fields: FiledFields) throws -> DocumentRecord {
        guard var record = try store.find(id: recordID) else {
            throw FilerError.recordNotFound(recordID)
        }
        if fields.needsReview == false {
            try checkForDuplicates(hash: record.contentHash, vendor: fields.vendor, invoiceNumber: fields.invoiceNumber, excluding: recordID)
        }

        let currentURL = root.appendingPathComponent(record.filePath)
        let ext = (currentURL.pathExtension.isEmpty ? "pdf" : currentURL.pathExtension)
        let relativePath = try finalPath(for: fields, contentHash: record.contentHash, extension: ext)
        let destination = root.appendingPathComponent(relativePath)

        if relativePath != record.filePath {
            try AtomicPlacer.place(source: currentURL, at: destination)
        }

        let sidecar = DocumentSidecar(
            id: recordID,
            vendor: fields.vendor,
            invoiceNumber: fields.invoiceNumber,
            issueDate: fields.issueDate,
            totalMinorUnits: fields.totalMinorUnits,
            currency: fields.currency,
            confidenceOverall: fields.confidenceOverall,
            confidenceFields: fields.confidenceFields,
            contentHash: record.contentHash,
            needsReview: fields.needsReview,
            reviewReason: fields.reviewReason
        )
        try Xattr.set(try JSONEncoder.denzel.encode(sidecar), at: destination)
        try journal.append(JournalEntry(
            operation: .move,
            documentID: recordID,
            fromPath: record.filePath,
            toPath: relativePath,
            contentHash: record.contentHash
        ))

        record = DocumentRecord(sidecar: sidecar, filePath: relativePath)
        try store.update(record)
        return record
    }

    private func checkForDuplicates(hash: String, vendor: String, invoiceNumber: String?, excluding: UUID? = nil) throws {
        if let existing = try store.find(contentHash: hash), existing.id != excluding {
            throw FilerError.duplicateContent(existingID: existing.id)
        }
        if let invoiceNumber, let existing = try store.find(vendor: vendor, invoiceNumber: invoiceNumber), existing.id != excluding {
            throw FilerError.duplicateInvoice(existingID: existing.id)
        }
    }

    private func finalPath(for fields: FiledFields, contentHash: String, extension ext: String) throws -> String {
        let vendorSlug = NameTemplate.sanitize(fields.vendor.lowercased().replacingOccurrences(of: " ", with: "-"))
        let year = fields.issueDate.flatMap { String($0.prefix(4)) } ?? String(Calendar.current.component(.year, from: Date()))
        let filename = try NameTemplate(pattern: nameTemplate.pattern, fileExtension: ext).render(fields: [
            "date": fields.issueDate ?? "unknown-date",
            "vendor": vendorSlug,
            "invoiceNumber": fields.invoiceNumber ?? String(contentHash.prefix(8)),
            "amount": fields.totalMinorUnits.map { String(format: "%.2f", Double($0) / 100) } ?? "0.00",
            "currency": fields.currency ?? "",
        ])
        return "vendors/\(vendorSlug)/\(year)/\(filename)"
    }
}
