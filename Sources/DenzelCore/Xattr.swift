// SPDX-License-Identifier: MPL-2.0
import Foundation
#if canImport(Darwin)
import Darwin
#endif

public enum XattrError: Error {
    case posix(errno: Int32, function: String)
}

/// Reads/writes the `com.denzel.meta` sidecar extended attribute directly via
/// the Darwin xattr syscalls — Foundation has no public wrapper for custom xattrs.
public enum Xattr {
    public static let sidecarName = "com.denzel.meta"

    public static func set(_ data: Data, at url: URL) throws {
        let rc = data.withUnsafeBytes { buffer in
            setxattr(url.path, sidecarName, buffer.baseAddress, buffer.count, 0, 0)
        }
        guard rc == 0 else { throw XattrError.posix(errno: errno, function: "setxattr") }
    }

    public static func get(at url: URL) throws -> Data? {
        let size = getxattr(url.path, sidecarName, nil, 0, 0, 0)
        guard size >= 0 else {
            if errno == ENOATTR { return nil }
            throw XattrError.posix(errno: errno, function: "getxattr")
        }
        guard size > 0 else { return Data() }
        var buffer = [UInt8](repeating: 0, count: size)
        let rc = buffer.withUnsafeMutableBytes { getxattr(url.path, sidecarName, $0.baseAddress, size, 0, 0) }
        guard rc >= 0 else { throw XattrError.posix(errno: errno, function: "getxattr") }
        return Data(buffer.prefix(rc))
    }

    public static func remove(at url: URL) throws {
        guard removexattr(url.path, sidecarName, 0) == 0 || errno == ENOATTR else {
            throw XattrError.posix(errno: errno, function: "removexattr")
        }
    }
}
