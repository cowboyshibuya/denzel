// SPDX-License-Identifier: MPL-2.0
import Testing
import Foundation
@testable import DenzelCore

struct LibraryLocationTests {
    @Test func bookmarkRoundTripsToSameURL() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let bookmark = try dir.bookmarkData(includingResourceValuesForKeys: nil, relativeTo: nil)
        let (resolved, isStale) = try LibraryLocationResolver().resolve(LibraryLocation(bookmarkData: bookmark))

        #expect(resolved.standardizedFileURL.path == dir.standardizedFileURL.path)
        #expect(isStale == false)
    }

    @Test func storeRoundTrips() {
        let suiteName = "com.denzel.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = LibraryLocationStore(defaults: defaults)
        #expect(store.load() == nil)
        let location = LibraryLocation(bookmarkData: Data([1, 2, 3]))
        store.save(location)
        #expect(store.load() == location)
    }
}
