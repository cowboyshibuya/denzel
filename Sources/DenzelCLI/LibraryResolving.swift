// SPDX-License-Identifier: MPL-2.0
import Foundation
import DenzelCore

enum CLIError: Error, CustomStringConvertible {
    case noLibraryConfigured

    var description: String {
        switch self {
        case .noLibraryConfigured:
            "No Denzel library configured. Open the Denzel app first and choose a library folder."
        }
    }
}

/// The CLI resolves the same bookmark the app stores in `UserDefaults.standard`
/// — this works cross-process because the bookmark is per-user, not scoped to
/// an app sandbox container, consistent with Denzel shipping non-sandboxed.
func resolveLibrary() throws -> DenzelLibrary {
    guard let location = LibraryLocationStore().load() else { throw CLIError.noLibraryConfigured }
    return DenzelLibrary(location: location)
}
