// SPDX-License-Identifier: MPL-2.0
import Foundation

/// Resolves a stored bookmark into a live URL.
///
/// Deliberately uses a *plain* bookmark, not `.withSecurityScope`: Denzel
/// ships non-sandboxed, and on this non-sandboxed / non-entitled build,
/// `.withSecurityScope` bookmark *creation* silently degrades to a
/// non-security-scoped bookmark (confirmed empirically — resolving the
/// same stored bookmark with `.withSecurityScope` fails with "not in the
/// correct format" while resolving it with no options succeeds). Requesting
/// `.withSecurityScope` on resolution then fails outright, and gating
/// filesystem access on `startAccessingSecurityScopedResource()` always
/// returns false for such a URL — which previously meant every relaunch
/// silently failed to reopen the last-chosen library. A non-sandboxed
/// process already has direct POSIX access to any path the user picked, so
/// there's nothing a working security scope would add today; revisit if
/// Denzel ever ships sandboxed (that would need its own entitlements setup
/// first, at which point security-scoped bookmarks could be reintroduced
/// correctly).
public final class LibraryLocationResolver {
    public init() {}

    public func resolve(_ location: LibraryLocation) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: location.bookmarkData,
                options: [],
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
        return try body(url)
    }
}
