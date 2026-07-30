// SPDX-License-Identifier: MPL-2.0
import Foundation
#if canImport(Darwin)
import Darwin
#endif

public enum InboxWatcherError: Error {
    case cannotOpenDirectory
}

/// Watches one directory (non-recursive) for new files and calls `handler`
/// for each — the mechanism behind "drop a file into the watched folder
/// from Finder, it's processed with zero user action" (M4).
///
/// Uses a `DispatchSourceFileSystemObject` on the directory's own file
/// descriptor rather than the full `FSEventStream` API: that's built for
/// recursive multi-directory trees, which this app never needs — it only
/// ever watches a single flat `Inbox/` folder.
public final class InboxWatcher {
    public typealias Handler = (URL) -> Void

    private let directory: URL
    private let handler: Handler
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private var knownNames: Set<String> = []

    public init(directory: URL, handler: @escaping Handler) {
        self.directory = directory
        self.handler = handler
    }

    public func start() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        knownNames = currentNames()

        fileDescriptor = open(directory.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { throw InboxWatcherError.cannotOpenDirectory }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue(label: "com.denzel.inboxwatcher")
        )
        source.setEventHandler { [weak self] in self?.scanForNewFiles() }
        source.setCancelHandler { [fileDescriptor] in close(fileDescriptor) }
        source.resume()
        self.source = source
    }

    public func stop() {
        source?.cancel()
        source = nil
    }

    private func scanForNewFiles() {
        let current = currentNames()
        let newNames = current.subtracting(knownNames)
        knownNames = current
        for name in newNames.sorted() {
            handler(directory.appendingPathComponent(name))
        }
    }

    private func currentNames() -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
    }
}
