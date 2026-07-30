// SPDX-License-Identifier: MPL-2.0
import Foundation

/// UserDefaults today; swap the backing store later without touching callers.
///
/// Explicitly targets the `com.denzel.app` suite rather than `.standard`:
/// `.standard` resolves to a domain keyed by the *current process's* bundle
/// identifier, which is `com.denzel.app` for the GUI app but falls back to
/// the executable name (e.g. `swift-frontend`) for a bare `swift run`
/// process — meaning the CLI would silently read/write a different,
/// unrelated domain and could never see the library the app configured.
public struct LibraryLocationStore {
    private static let sharedDomain = UserDefaults(suiteName: "com.denzel.app") ?? .standard

    private let defaults: UserDefaults
    private let key = "com.denzel.libraryBookmark"

    public init(defaults: UserDefaults? = nil) { self.defaults = defaults ?? Self.sharedDomain }

    public func load() -> LibraryLocation? {
        defaults.data(forKey: key).map(LibraryLocation.init)
    }

    public func save(_ location: LibraryLocation) { defaults.set(location.bookmarkData, forKey: key) }
    public func clear() { defaults.removeObject(forKey: key) }
}
