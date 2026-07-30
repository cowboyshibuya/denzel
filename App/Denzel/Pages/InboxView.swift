// SPDX-License-Identifier: MPL-2.0
import SwiftUI
import DenzelCore

struct InboxView: View {
    let appState: AppState
    @State private var isDropTargeted = false
    @State private var recordToFile: DocumentRecord?

    var body: some View {
        Group {
            if appState.stagedDocuments.isEmpty {
                ContentUnavailableView(
                    "Inbox",
                    systemImage: "tray",
                    description: Text("Drop an invoice PDF here to get started.")
                )
            } else {
                List(appState.stagedDocuments) { record in
                    HStack {
                        VStack(alignment: .leading) {
                            Text((record.filePath as NSString).lastPathComponent)
                            if let reason = record.reviewReason {
                                Text(reason).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("File…") { recordToFile = record }
                    }
                }
            }
        }
        .background(isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        .dropDestination(for: URL.self) { urls, _ in
            appState.stageDropped(urls: urls)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .sheet(item: $recordToFile) { record in
            FileDocumentSheet(appState: appState, record: record)
        }
    }
}
