// SPDX-License-Identifier: MPL-2.0
import Foundation
#if canImport(Darwin)
import Darwin
#endif

public enum AtomicPlaceError: Error {
    case destinationExists
    case posix(errno: Int32)
}

/// `FileManager.moveItem` across volumes is copy-then-delete — interruptible,
/// not atomic. This copies into a temp dir guaranteed to be on the
/// *destination* volume, then does a same-volume, race-free atomic rename.
public enum AtomicPlacer {
    public static func place(source: URL, at destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        let tempDir = try fm.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: destination,
            create: true
        )
        defer { try? fm.removeItem(at: tempDir) }

        let tempURL = tempDir.appendingPathComponent(destination.lastPathComponent)
        try fm.copyItem(at: source, to: tempURL)

        // RENAME_EXCL (Darwin 10.12+): fails atomically if destination already
        // exists instead of silently clobbering it — no check-then-rename race.
        let rc = tempURL.path.withCString { tempPath in
            destination.path.withCString { destPath in
                renamex_np(tempPath, destPath, UInt32(RENAME_EXCL))
            }
        }
        guard rc == 0 else {
            throw errno == EEXIST ? AtomicPlaceError.destinationExists : AtomicPlaceError.posix(errno: errno)
        }

        // This is a move, not a copy: the source must not survive at its old
        // location, or the library ends up with two copies of one document.
        // Best-effort — the destination is already safely and atomically in
        // place, so a failure here is an orphan, never data loss.
        try? fm.removeItem(at: source)
    }
}
