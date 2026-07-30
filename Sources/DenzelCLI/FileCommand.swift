// SPDX-License-Identifier: MPL-2.0
import ArgumentParser
import Foundation
import DenzelRules

struct FileCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "file", abstract: "File a document through the extraction pipeline.")

    @Argument(help: "Path to the PDF to file.")
    var path: String

    func run() throws {
        let library = try resolveLibrary()
        let rules = try VendorRuleLoader.loadBundledRules()
        let url = URL(fileURLWithPath: path)
        let record = try ExtractionPipeline.process(fileURL: url, library: library, rules: rules)
        if record.needsReview {
            print("Needs review (\(record.reviewReason ?? "unknown reason")): \(record.filePath)")
        } else {
            print("Filed: \(record.filePath)")
        }
    }
}
