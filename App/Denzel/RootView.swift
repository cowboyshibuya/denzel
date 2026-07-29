// SPDX-License-Identifier: MPL-2.0
import SwiftUI
import DenzelCore

enum Page: String, CaseIterable, Identifiable {
    case inbox = "Inbox"
    case review = "Review"
    case library = "Library"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .inbox: "tray"
        case .review: "checkmark.circle"
        case .library: "books.vertical"
        }
    }
}

struct RootView: View {
    let appState: AppState
    @State private var selection: Page? = .inbox
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationSplitView {
            List(Page.allCases, selection: $selection) { page in
                Label(page.rawValue, systemImage: page.systemImage)
            }
            .navigationTitle("Denzel")
        } detail: {
            Group {
                switch selection {
                case .inbox: InboxView()
                case .review: ReviewView()
                case .library: LibraryView()
                case .none: ContentUnavailableView("Select a page", systemImage: "sidebar.left")
                }
            }
            .animation(Motion.page(reduceMotion: reduceMotion), value: selection)
        }
    }
}
