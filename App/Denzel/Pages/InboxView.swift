// SPDX-License-Identifier: MPL-2.0
import SwiftUI
import DenzelCore

struct InboxView: View {
    let appState: AppState
    @State private var isDropTargeted = false
    @State private var toast: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ContentUnavailableView(
            "Inbox",
            systemImage: "tray",
            description: Text("Drop an invoice PDF here, or drop one into the library's Inbox folder in Finder. It's matched against the rulebook and either filed automatically or sent to Review.")
        )
        .background(isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        .dropDestination(for: URL.self) { urls, _ in
            appState.ingest(urls: urls)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Motion.page(reduceMotion: reduceMotion), value: toast)
        .onChange(of: appState.lastWatcherActivity) { _, newValue in
            guard let newValue else { return }
            toast = newValue
            Task {
                try? await Task.sleep(for: .seconds(3))
                if toast == newValue { toast = nil }
            }
        }
    }
}
