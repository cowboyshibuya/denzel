// SPDX-License-Identifier: MPL-2.0
import Testing
import Foundation
@testable import DenzelCore

private actor DetectedURLs {
    private(set) var urls: [URL] = []
    func add(_ url: URL) { urls.append(url) }
}

struct InboxWatcherTests {
    @Test func detectsNewFileAppearing() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }

        let detected = DetectedURLs()
        let watcher = InboxWatcher(directory: dir) { url in
            Task { await detected.add(url) }
        }
        try watcher.start()
        defer { watcher.stop() }

        try "hello".data(using: .utf8)!.write(to: dir.appendingPathComponent("new.pdf"))

        var names: [String] = []
        for _ in 0..<40 {
            names = await detected.urls.map(\.lastPathComponent)
            if !names.isEmpty { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(names == ["new.pdf"])
    }

    @Test func ignoresFilesPresentBeforeStart() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "pre-existing".data(using: .utf8)!.write(to: dir.appendingPathComponent("old.pdf"))

        let detected = DetectedURLs()
        let watcher = InboxWatcher(directory: dir) { url in
            Task { await detected.add(url) }
        }
        try watcher.start()
        defer { watcher.stop() }

        try await Task.sleep(for: .milliseconds(200))
        let names = await detected.urls.map(\.lastPathComponent)
        #expect(names.isEmpty)
    }
}
