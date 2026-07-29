// SPDX-License-Identifier: MPL-2.0
import Observation
import DenzelCore

@MainActor
@Observable
final class AppState {
    var library: DenzelLibrary?
    var needsLibraryPicker = false

    private let store = LibraryLocationStore()
    private let resolver = LibraryLocationResolver()

    func loadOnLaunch() {
        guard let location = store.load() else {
            needsLibraryPicker = true
            return
        }
        do {
            let (url, isStale) = try resolver.resolve(location)
            if isStale {
                refreshBookmark(for: url)
            } else {
                library = DenzelLibrary(location: location, resolver: resolver)
            }
        } catch {
            // Folder moved/deleted/inaccessible — ask again rather than crash.
            needsLibraryPicker = true
        }
    }

    func choose(_ location: LibraryLocation) {
        store.save(location)
        library = DenzelLibrary(location: location, resolver: resolver)
        needsLibraryPicker = false
    }

    private func refreshBookmark(for url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            needsLibraryPicker = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let fresh = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            needsLibraryPicker = true
            return
        }
        let location = LibraryLocation(bookmarkData: fresh)
        store.save(location)
        library = DenzelLibrary(location: location, resolver: resolver)
    }
}
