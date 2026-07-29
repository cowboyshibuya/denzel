// SPDX-License-Identifier: MPL-2.0
import ArgumentParser

@main
struct Denzel: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "denzel",
        abstract: "Denzel invoice library CLI (stub — real commands land in M1+).",
        version: "0.1.0"
    )
}
