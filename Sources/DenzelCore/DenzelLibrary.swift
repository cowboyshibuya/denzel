// SPDX-License-Identifier: MPL-2.0
import Foundation

/// The single entry point for everything touching the library folder.
/// Journal, xattr sidecars, and the SQLite index all hang off this type via
/// the methods below — nothing above it (app, CLI) ever sees a raw `URL`.
public struct DenzelLibrary {
    public let location: LibraryLocation
    private let resolver: LibraryLocationResolver
    private let handles: Handles

    public init(location: LibraryLocation, resolver: LibraryLocationResolver = LibraryLocationResolver()) {
        self.location = location
        self.resolver = resolver
        self.handles = Handles(location: location, resolver: resolver)
    }

    /// One-shot access for a single operation on an arbitrary, not-yet-open
    /// path — the M0 convention, unchanged.
    public func withRootAccess<T>(_ body: (URL) throws -> T) throws -> T {
        try resolver.withAccess(location, body)
    }

    /// Long-lived handles (an open SQLite connection, a journal file) are
    /// resolved and cached once for the life of this `DenzelLibrary`. No
    /// security scope to keep open here — see `LibraryLocationResolver`.
    public func documentStore() throws -> DocumentStore { try handles.documentStore() }
    public func journal() throws -> Journal { try handles.journal() }
    public func filer() throws -> LibraryFiler { try handles.filer() }
    public func undoService() throws -> UndoService { try handles.undoService() }

    public func rebuildIndex() throws {
        let root = try handles.rootURL()
        try LibraryScanner.rebuild(root: root, into: try documentStore())
    }

    /// Exposed for library-internal processing (the extraction pipeline
    /// needs an absolute URL to open a staged file) — the app/CLI layers
    /// still never construct library paths themselves.
    public func rootURL() throws -> URL { try handles.rootURL() }

}

/// Reference-type cache shared across copies of `DenzelLibrary` (a struct).
private final class Handles {
    private let location: LibraryLocation
    private let resolver: LibraryLocationResolver
    private var cachedRoot: URL?
    private var cachedStore: DocumentStore?
    private var cachedJournal: Journal?

    init(location: LibraryLocation, resolver: LibraryLocationResolver) {
        self.location = location
        self.resolver = resolver
    }

    // ponytail: no locking — DenzelLibrary is only ever touched from
    // AppState's @MainActor or a single-threaded CLI invocation, never
    // concurrently. Add locking if a background-queue caller shows up.
    func rootURL() throws -> URL {
        if let cachedRoot { return cachedRoot }
        let (url, _) = try resolver.resolve(location)
        cachedRoot = url
        return url
    }

    func documentStore() throws -> DocumentStore {
        if let cachedStore { return cachedStore }
        let root = try rootURL()
        let store = try GRDBDocumentStore(path: root.appendingPathComponent("index.sqlite").path)
        cachedStore = store
        return store
    }

    func journal() throws -> Journal {
        if let cachedJournal { return cachedJournal }
        let root = try rootURL()
        let journal = Journal(fileURL: root.appendingPathComponent("journal.jsonl"))
        cachedJournal = journal
        return journal
    }

    func filer() throws -> LibraryFiler {
        LibraryFiler(root: try rootURL(), store: try documentStore(), journal: try journal())
    }

    func undoService() throws -> UndoService {
        UndoService(root: try rootURL(), store: try documentStore(), journal: try journal())
    }
}
