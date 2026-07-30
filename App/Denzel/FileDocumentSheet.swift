// SPDX-License-Identifier: MPL-2.0
import SwiftUI
import DenzelCore

/// Manual "file this document" flow — vendor + fields entered by hand, with a
/// live preview of the name the document will be renamed to.
struct FileDocumentSheet: View {
    let appState: AppState
    let record: DocumentRecord

    @Environment(\.dismiss) private var dismiss
    @State private var vendor = ""
    @State private var invoiceNumber = ""
    @State private var issueDate = Date()
    @State private var amount = ""
    @State private var currency = "USD"

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    var body: some View {
        Form {
            Section("Document") {
                TextField("Vendor", text: $vendor)
                TextField("Invoice number", text: $invoiceNumber)
                DatePicker("Issue date", selection: $issueDate, displayedComponents: .date)
                TextField("Amount", text: $amount)
                TextField("Currency", text: $currency)
            }
            Section("Will be filed as") {
                Text(previewPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 380, minHeight: 340)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("File") {
                    appState.fileManually(recordID: record.id, fields: fields)
                    dismiss()
                }
                .disabled(vendor.isEmpty)
            }
        }
    }

    private var fields: FiledFields {
        FiledFields(
            vendor: vendor,
            invoiceNumber: invoiceNumber.isEmpty ? nil : invoiceNumber,
            issueDate: Self.dateFormatter.string(from: issueDate),
            totalMinorUnits: Int((Double(amount) ?? 0) * 100),
            currency: currency.isEmpty ? nil : currency,
            confidenceOverall: 1,
            needsReview: false
        )
    }

    private var previewPath: String {
        guard !vendor.isEmpty else { return "—" }
        let vendorSlug = NameTemplate.sanitize(vendor.lowercased().replacingOccurrences(of: " ", with: "-"))
        let dateString = Self.dateFormatter.string(from: issueDate)
        let year = String(dateString.prefix(4))
        let amountString = String(format: "%.2f", Double(amount) ?? 0)
        let name = (try? NameTemplate(
            pattern: "{date}_{vendor}_{invoiceNumber}_{amount}{currency}",
            fileExtension: "pdf"
        ).render(fields: [
            "date": dateString,
            "vendor": vendorSlug,
            "invoiceNumber": invoiceNumber.isEmpty ? "unknown" : invoiceNumber,
            "amount": amountString,
            "currency": currency,
        ])) ?? "—"
        return "vendors/\(vendorSlug)/\(year)/\(name)"
    }
}
