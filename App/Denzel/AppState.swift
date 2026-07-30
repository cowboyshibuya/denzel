// SPDX-License-Identifier: MPL-2.0
import Foundation
import Observation
import DenzelCore
import DenzelRules

@MainActor
@Observable
final class AppState {
    var library: DenzelLibrary?
    var needsLibraryPicker = false
    var needsReviewDocuments: [DocumentRecord] = []
    var filedDocuments: [DocumentRecord] = []
    var lastErrorMessage: String?
    var lastWatcherActivity: String?

    private let store = LibraryLocationStore()
    private let resolver = LibraryLocationResolver()
    private var vendorRules: [VendorRule] = []
    private var inboxWatcher: InboxWatcher?

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
                startWatchingInbox()
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
        startWatchingInbox()
    }

    func refreshDocuments() {
        guard let library else { return }
        do {
            let all = try library.documentStore().fetchAll()
            needsReviewDocuments = all.filter(\.needsReview).sorted { $0.filedAt > $1.filedAt }
            filedDocuments = all.filter { !$0.needsReview }.sorted { $0.filedAt > $1.filedAt }
        } catch {
            lastErrorMessage = String(describing: error)
        }
    }

    /// Runs every dropped file through the real pipeline (stage -> extract
    /// -> match -> gate) — the same path the watched Inbox folder uses.
    func ingest(urls: [URL]) {
        guard let library else { return }
        loadVendorRulesIfNeeded()
        for url in urls {
            do {
                _ = try ExtractionPipeline.process(fileURL: url, library: library, rules: vendorRules)
            } catch {
                lastErrorMessage = String(describing: error)
            }
        }
        refreshDocuments()
    }

    /// Watches `<library>/Inbox/` — a physical, user-visible drop folder,
    /// distinct from `LibraryFiler`'s internal `_staging/` — for files
    /// dropped in from Finder while the app is running.
    func startWatchingInbox() {
        guard let library, inboxWatcher == nil else { return }
        loadVendorRulesIfNeeded()
        do {
            let watchDirectory = try library.rootURL().appendingPathComponent("Inbox")
            let watcher = InboxWatcher(directory: watchDirectory) { [weak self] url in
                Task { @MainActor in self?.processWatchedFile(url) }
            }
            try watcher.start()
            inboxWatcher = watcher
        } catch {
            lastErrorMessage = String(describing: error)
        }
    }

    func stopWatchingInbox() {
        inboxWatcher?.stop()
        inboxWatcher = nil
    }

    private func processWatchedFile(_ url: URL) {
        guard let library else { return }
        do {
            let record = try ExtractionPipeline.process(fileURL: url, library: library, rules: vendorRules)
            lastWatcherActivity = record.needsReview
                ? "Needs review: \(url.lastPathComponent)"
                : "Filed: \(url.lastPathComponent)"
        } catch {
            lastErrorMessage = String(describing: error)
        }
        refreshDocuments()
    }

    private func loadVendorRulesIfNeeded() {
        guard vendorRules.isEmpty else { return }
        vendorRules = (try? VendorRuleLoader.loadBundledRules()) ?? []
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
        startWatchingInbox()
    }
}
