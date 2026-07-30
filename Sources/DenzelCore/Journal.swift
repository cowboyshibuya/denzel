// SPDX-License-Identifier: MPL-2.0
import Foundation

public enum JournalOperation: String, Codable {
    case file
    case move
    case undo
}

public struct JournalEntry: Codable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let operation: JournalOperation
    public let documentID: UUID
    public let fromPath: String?   // relative to library root; nil for a fresh "file" of a new document
    public let toPath: String
    public let contentHash: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        operation: JournalOperation,
        documentID: UUID,
        fromPath: String?,
        toPath: String,
        contentHash: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operation = operation
        self.documentID = documentID
        self.fromPath = fromPath
        self.toPath = toPath
        self.contentHash = contentHash
    }
}

/// Append-only `journal.jsonl` — one JSON object per line. The durable "belt"
/// to the xattr sidecar's "suspenders": xattrs can get stripped by some sync
/// tools/transports, the journal never does.
public final class Journal {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func append(_ entry: JournalEntry) throws {
        let line = try encoder.encode(entry)
        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path) {
            fm.createFile(atPath: fileURL.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        handle.seekToEndOfFile()
        handle.write(line)
        handle.write("\n".data(using: .utf8)!)
    }

    public func readAll() throws -> [JournalEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        return try contents
            .split(separator: "\n")
            .map { try decoder.decode(JournalEntry.self, from: Data($0.utf8)) }
    }

    public func lastUndoable() throws -> JournalEntry? {
        try readAll().last { $0.operation != .undo }
    }
}
