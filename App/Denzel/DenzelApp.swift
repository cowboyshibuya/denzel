// SPDX-License-Identifier: MPL-2.0
import SwiftUI
import Sparkle

@main
struct DenzelApp: App {
    @State private var appState = AppState()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        WindowGroup {
            ContentRouter(appState: appState)
                .task { appState.loadOnLaunch() }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
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
