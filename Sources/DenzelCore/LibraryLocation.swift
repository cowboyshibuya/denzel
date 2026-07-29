// SPDX-License-Identifier: MPL-2.0
import Foundation

public struct LibraryLocation: Codable, Equatable {
    public let bookmarkData: Data
    public init(bookmarkData: Data) { self.bookmarkData = bookmarkData }
}

public enum LibraryLocationError: Error {
    case bookmarkResolutionFailed(Error)
    case accessDenied
}
