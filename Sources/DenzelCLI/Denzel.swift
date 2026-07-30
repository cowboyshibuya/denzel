// SPDX-License-Identifier: MPL-2.0
import ArgumentParser

@main
struct Denzel: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "denzel",
        abstract: "Denzel invoice library CLI.",
        version: "0.1.0",
        subcommands: [ScanCommand.self, FileCommand.self, LsCommand.self, UndoCommand.self, ExportCommand.self]
    )
}
