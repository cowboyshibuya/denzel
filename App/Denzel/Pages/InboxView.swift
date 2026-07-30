// SPDX-License-Identifier: MPL-2.0
import SwiftUI
import DenzelCore

struct InboxView: View {
    let appState: AppState
    @State private var isDropTargeted = false

    var body: some View {
        ContentUnavailableView(
            "Inbox",
            systemImage: "tray",
            description: Text("Drop an invoice PDF here. It's matched against the rulebook and either filed automatically or sent to Review.")
        )
        .background(isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        .dropDestination(for: URL.self) { urls, _ in
            appState.ingest(urls: urls)
            return true
        } isTargeted: { isDropTargeted = $0 }
    }
}
