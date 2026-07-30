// SPDX-License-Identifier: MPL-2.0
import ArgumentParser

struct LsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "ls", abstract: "List documents in the library.")

    @Flag(name: .long, help: "Only show documents needing review.")
    var needsReview = false

    func run() throws {
        let library = try resolveLibrary()
        let store = try library.documentStore()
        let records = needsReview ? try store.fetchNeedingReview() : try store.fetchAll()

        guard !records.isEmpty else {
            print(needsReview ? "Nothing needs review." : "Library is empty.")
            return
        }
        for record in records.sorted(by: { $0.filePath < $1.filePath }) {
            let flag = record.needsReview ? " [review: \(record.reviewReason ?? "unknown reason")]" : ""
            print("\(record.filePath)\(flag)")
        }
    }
}
