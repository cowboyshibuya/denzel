// SPDX-License-Identifier: MPL-2.0
import Foundation

/// UserDefaults today; swap the backing store later without touching callers.
public struct LibraryLocationStore {
    private let defaults: UserDefaults
    private let key = "com.denzel.libraryBookmark"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> LibraryLocation? {
        defaults.data(forKey: key).map(LibraryLocation.init)
    }

    public func save(_ location: LibraryLocation) { defaults.set(location.bookmarkData, forKey: key) }
    public func clear() { defaults.removeObject(forKey: key) }
}
