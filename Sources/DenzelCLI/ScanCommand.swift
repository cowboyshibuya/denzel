// SPDX-License-Identifier: MPL-2.0
import ArgumentParser

struct ScanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "scan", abstract: "Rebuild the index from the filesystem + xattr sidecars.")

    func run() throws {
        let library = try resolveLibrary()
        try library.rebuildIndex()
        let count = try library.documentStore().fetchAll().count
        print("Rebuilt index: \(count) document(s).")
    }
}
