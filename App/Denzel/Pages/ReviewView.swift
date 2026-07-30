// SPDX-License-Identifier: MPL-2.0
import SwiftUI
import DenzelCore

struct ReviewView: View {
    let appState: AppState
    @State private var recordToReview: DocumentRecord?

    var body: some View {
        Group {
            if appState.needsReviewDocuments.isEmpty {
                ContentUnavailableView(
                    "Review",
                    systemImage: "checkmark.circle",
                    description: Text("Low-confidence extractions will wait here for a quick confirm.")
                )
            } else {
                List(appState.needsReviewDocuments) { record in
                    Button {
                        recordToReview = record
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text((record.filePath as NSString).lastPathComponent)
                            if let reason = record.reviewReason {
                                Text(reason).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $recordToReview) { record in
            FileDocumentSheet(appState: appState, record: record)
        }
    }
}
