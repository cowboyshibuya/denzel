// SPDX-License-Identifier: MPL-2.0
import Foundation

/// Resolves a stored bookmark into a live URL. Callers must bracket filesystem
/// work with start/stop access — never hold the scope open for the app's lifetime.
public final class LibraryLocationResolver {
    public init() {}

    public func resolve(_ location: LibraryLocation) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: location.bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return (url, isStale)
        } catch {
            throw LibraryLocationError.bookmarkResolutionFailed(error)
        }
    }

    public func withAccess<T>(_ location: LibraryLocation, _ body: (URL) throws -> T) throws -> T {
        let (url, _) = try resolve(location)
        guard url.startAccessingSecurityScopedResource() else { throw LibraryLocationError.accessDenied }
        defer { url.stopAccessingSecurityScopedResource() }
        return try body(url)
    }
}
