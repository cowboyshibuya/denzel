// SPDX-License-Identifier: MPL-2.0
import ArgumentParser
import Foundation

struct ExportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "export", abstract: "Export filed documents as CSV.")

    @Option(name: .long, help: "Filter to a quarter, e.g. 2026-Q1.")
    var quarter: String?

    func run() throws {
        let library = try resolveLibrary()
        var records = try library.documentStore().fetchAll().filter { !$0.needsReview }

        if let quarter {
            guard let bounds = Self.quarterBounds(quarter) else {
                throw ValidationError("Invalid quarter '\(quarter)', expected format YYYY-Q[1-4].")
            }
            records = records.filter { record in
                guard let issueDate = record.issueDate else { return false }
                return issueDate >= bounds.start && issueDate < bounds.endExclusive
            }
        }

        print("vendor,invoice_number,issue_date,total,currency,file_path")
        for record in records.sorted(by: { ($0.issueDate ?? "") < ($1.issueDate ?? "") }) {
            let total = record.totalMinorUnits.map { String(format: "%.2f", Double($0) / 100) } ?? ""
            let fields = [record.vendor, record.invoiceNumber ?? "", record.issueDate ?? "", total, record.currency ?? "", record.filePath]
            print(fields.map(Self.csvEscape).joined(separator: ","))
        }
    }

    static func csvEscape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    /// "YYYY-Qn" -> [start, endExclusive) as "YYYY-MM-DD" strings — issueDate
    /// is stored ISO8601, so lexicographic comparison against these bounds
    /// is correct without parsing back into `Date`.
    static func quarterBounds(_ quarter: String) -> (start: String, endExclusive: String)? {
        let parts = quarter.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              parts[1].hasPrefix("Q"),
              let q = Int(parts[1].dropFirst()),
              (1...4).contains(q)
        else { return nil }

        let startMonth = (q - 1) * 3 + 1
        let start = String(format: "%04d-%02d-01", year, startMonth)
        let endMonthRaw = startMonth + 3
        let endYear = endMonthRaw > 12 ? year + 1 : year
        let endMonth = endMonthRaw > 12 ? endMonthRaw - 12 : endMonthRaw
        let endExclusive = String(format: "%04d-%02d-01", endYear, endMonth)
        return (start, endExclusive)
    }
}
