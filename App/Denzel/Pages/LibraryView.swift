// SPDX-License-Identifier: MPL-2.0
import SwiftUI
import DenzelCore

struct LibraryView: View {
    let appState: AppState
    @State private var searchQuery = ""

    private var displayedDocuments: [DocumentRecord] {
        appState.search(searchQuery)
    }

    var body: some View {
        Group {
            if appState.filedDocuments.isEmpty {
                ContentUnavailableView(
                    "Library",
                    systemImage: "books.vertical",
                    description: Text("Your filed invoices will show up here.")
                )
            } else if displayedDocuments.isEmpty {
                ContentUnavailableView.search(text: searchQuery)
            } else {
                List(displayedDocuments) { record in
                    VStack(alignment: .leading) {
                        Text(record.vendor)
                        Text(record.filePath).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .searchable(text: $searchQuery, prompt: "Search invoices")
        .toolbar {
            ToolbarItem {
                Button("Undo", systemImage: "arrow.uturn.backward") { appState.undoLast() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(appState.filedDocuments.isEmpty && appState.needsReviewDocuments.isEmpty)
            }
        }
    }
}
