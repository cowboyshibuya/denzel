// SPDX-License-Identifier: MPL-2.0
import Foundation
import Observation
import DenzelCore

@MainActor
@Observable
final class AppState {
    var library: DenzelLibrary?
    var needsLibraryPicker = false
    var stagedDocuments: [DocumentRecord] = []
    var filedDocuments: [DocumentRecord] = []
    var lastErrorMessage: String?

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
                refreshDocuments()
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
        refreshDocuments()
    }

    func refreshDocuments() {
        guard let library else { return }
        do {
            let all = try library.documentStore().fetchAll()
            stagedDocuments = all.filter(\.needsReview).sorted { $0.filedAt > $1.filedAt }
            filedDocuments = all.filter { !$0.needsReview }.sorted { $0.filedAt > $1.filedAt }
        } catch {
            lastErrorMessage = String(describing: error)
        }
    }

    func stageDropped(urls: [URL]) {
        guard let library else { return }
        do {
            let filer = try library.filer()
            for url in urls { _ = try filer.stage(source: url) }
            refreshDocuments()
        } catch {
            lastErrorMessage = String(describing: error)
        }
    }

    func fileManually(recordID: UUID, fields: FiledFields) {
        guard let library else { return }
        do {
            _ = try library.filer().finalize(recordID: recordID, fields: fields)
            refreshDocuments()
        } catch {
            lastErrorMessage = String(describing: error)
        }
    }

    func undoLast() {
        guard let library else { return }
        do {
            _ = try library.undoService().undoLast()
            refreshDocuments()
        } catch {
            lastErrorMessage = String(describing: error)
        }
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
        refreshDocuments()
    }
}
