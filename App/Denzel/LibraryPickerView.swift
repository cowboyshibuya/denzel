// SPDX-License-Identifier: MPL-2.0
import AppKit
import SwiftUI
import DenzelCore

@MainActor
func pickLibraryFolder() -> LibraryLocation? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.message = "Choose a folder to store your Denzel library"
    guard panel.runModal() == .OK, let url = panel.url,
          let bookmark = try? url.bookmarkData(
              options: .withSecurityScope,
              includingResourceValuesForKeys: nil,
              relativeTo: nil
          )
    else { return nil }
    return LibraryLocation(bookmarkData: bookmark)
}

struct LibraryPickerPromptView: View {
    let appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Choose a library folder")
                .font(.title2)
            Text("Denzel stores invoices as plain files in a folder you choose. Nothing leaves your Mac.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button("Choose Folder…") {
                if let location = pickLibraryFolder() {
                    appState.choose(location)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(minWidth: 480, minHeight: 320)
    }
}
