// SPDX-License-Identifier: MPL-2.0
import Foundation

/// The single entry point for everything touching the library folder.
/// M1 hangs journal.jsonl, xattr sidecar helpers, and the SQLite index off
/// this type — nothing above it (app, CLI) needs to change shape.
public struct DenzelLibrary {
    public let location: LibraryLocation
    private let resolver: LibraryLocationResolver

    public init(location: LibraryLocation, resolver: LibraryLocationResolver = LibraryLocationResolver()) {
        self.location = location
        self.resolver = resolver
    }

    public func withRootAccess<T>(_ body: (URL) throws -> T) throws -> T {
        try resolver.withAccess(location, body)
    }
}
