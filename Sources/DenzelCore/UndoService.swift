// SPDX-License-Identifier: MPL-2.0
import Foundation

public enum UndoError: Error {
    case nothingToUndo
    case recordNotFound(UUID)
    case originalFileMissing(String)
}

/// Reverses the last journal-recorded move/file operation, even across app
/// restarts — the journal is read fresh each time, not cached in memory.
public final class UndoService {
    private let root: URL
    private let store: DocumentStore
    private let journal: Journal

    public init(root: URL, store: DocumentStore, journal: Journal) {
        self.root = root
        self.store = store
        self.journal = journal
    }

    @discardableResult
    public func undoLast() throws -> JournalEntry {
        guard let last = try journal.lastUndoable() else { throw UndoError.nothingToUndo }
        guard var record = try store.find(id: last.documentID) else {
            throw UndoError.recordNotFound(last.documentID)
        }

        let currentURL = root.appendingPathComponent(last.toPath)

        if let fromPath = last.fromPath {
            // A move: put it back where it came from.
            let originalURL = root.appendingPathComponent(fromPath)
            guard FileManager.default.fileExists(atPath: currentURL.path) else {
                throw UndoError.originalFileMissing(last.toPath)
            }
            try AtomicPlacer.place(source: currentURL, at: originalURL)
            record.filePath = fromPath
            try store.update(record)
        } else {
            // A fresh file: undoing it removes the document entirely.
            try? FileManager.default.removeItem(at: currentURL)
            try store.delete(id: record.id)
        }

        try journal.append(JournalEntry(
            operation: .undo,
            documentID: last.documentID,
            fromPath: last.toPath,
            toPath: last.fromPath ?? last.toPath,
            contentHash: last.contentHash
        ))
        return last
    }
}
