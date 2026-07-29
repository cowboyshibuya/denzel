// SPDX-License-Identifier: MPL-2.0
import SwiftUI

@main
struct DenzelApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentRouter(appState: appState)
                .task { appState.loadOnLaunch() }
        }
    }
}

private struct ContentRouter: View {
    let appState: AppState

    var body: some View {
        if appState.needsLibraryPicker {
            LibraryPickerPromptView(appState: appState)
        } else if appState.library != nil {
            RootView(appState: appState)
        } else {
            ProgressView("Loading Denzel…")
                .frame(minWidth: 480, minHeight: 320)
        }
    }
}
