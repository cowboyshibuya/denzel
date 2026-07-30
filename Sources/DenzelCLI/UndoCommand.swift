// SPDX-License-Identifier: MPL-2.0
import ArgumentParser

struct UndoCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "undo", abstract: "Undo the last file/move operation.")

    func run() throws {
        let library = try resolveLibrary()
        let entry = try library.undoService().undoLast()
        print("Undid \(entry.operation.rawValue): \(entry.toPath) -> \(entry.fromPath ?? "(removed)")")
    }
}
