// SPDX-License-Identifier: MPL-2.0
import Foundation

/// Walks the library tree, reads each file's `com.denzel.meta` xattr sidecar,
/// and rebuilds the index from scratch. Files with no sidecar aren't
/// Denzel-filed documents (stray Finder droppings, `journal.jsonl`,
/// `index.sqlite`, `.DS_Store`) and are skipped.
///
/// This is the concrete mechanism behind M1's done-when: delete index.sqlite,
/// rescan, get back the identical index.
public enum LibraryScanner {
    private static let ignoredNames: Set<String> = ["journal.jsonl", "index.sqlite", "index.sqlite-wal", "index.sqlite-shm", ".DS_Store"]

    public static func scan(root: URL) throws -> [DocumentRecord] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var records: [DocumentRecord] = []
        for case let url as URL in enumerator {
            guard !ignoredNames.contains(url.lastPathComponent) else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            guard let data = try Xattr.get(at: url) else { continue }
            let sidecar = try JSONDecoder.denzel.decode(DocumentSidecar.self, from: data)
            let relativePath = String(url.path.dropFirst(root.path.count + 1))
            records.append(DocumentRecord(sidecar: sidecar, filePath: relativePath))
        }
        return records
    }

    public static func rebuild(root: URL, into store: DocumentStore) throws {
        let records = try scan(root: root)
        try store.rebuild(with: records)
    }
}

extension JSONDecoder {
    static let denzel: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension JSONEncoder {
    static let denzel: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
