// SPDX-License-Identifier: MPL-2.0
import AppKit
import UniformTypeIdentifiers

/// Handles both plain file drops (Finder, most apps) and file promises
/// (Mail, Safari — dragging an attachment straight out of Mail hands you a
/// promise, not a resolved URL yet; SwiftUI's `.dropDestination(for:
/// URL.self)` only sees plain file URLs and silently no-ops on a promise).
///
/// Two-tier, in order:
/// 1. `loadItem(forTypeIdentifier:)` — what `Transferable`'s `URL` support
///    uses under the hood too; verified locally to hand back the exact
///    original file URL for a plain provider. This is the path that must
///    not regress, so it's tried first and used whenever it resolves to a
///    file that actually exists.
/// 2. `loadFileRepresentation(forTypeIdentifier:)` — the promise
///    materialization path, only reached when (1) didn't resolve. This is
///    the older `NSFilePromiseReceiver`/`NSDraggingInfo` API's modern
///    `NSItemProvider` replacement (`NSFilePromiseReceiver` itself conforms
///    to `NSPasteboardReading`, not `NSItemProviderReading`, so it isn't
///    reachable from an `NSItemProvider` at all — this is the correct fix).
@MainActor
enum InboxDropHandler {
    static let acceptedTypeIdentifiers: [String] = [UTType.fileURL.identifier]

    static func handle(providers: [NSItemProvider], onURLs: @escaping ([URL]) -> Void) {
        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { continue }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let url = resolvedURL(from: item), FileManager.default.fileExists(atPath: url.path) {
                    DispatchQueue.main.async { onURLs([url]) }
                } else {
                    receivePromisedFile(from: provider, onURLs: onURLs)
                }
            }
        }
    }

    private static func resolvedURL(from item: NSSecureCoding?) -> URL? {
        if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
        return item as? URL
    }

    private static func receivePromisedFile(from provider: NSItemProvider, onURLs: @escaping ([URL]) -> Void) {
        _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { url, _ in
            guard let url, let staged = stage(url) else { return }
            DispatchQueue.main.async { onURLs([staged]) }
        }
    }

    /// The URL handed to the completion block is only valid for the
    /// duration of the call, so copy it out immediately. Also guards
    /// against a failure mode confirmed locally: a non-promise provider
    /// asked for a file representation can hand back a tiny text file whose
    /// *contents* are just the serialized `file://…` URL string, not real
    /// file bytes — reject anything that looks like that rather than filing
    /// it as if it were a real invoice.
    private static func stage(_ url: URL) -> URL? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        if data.count < 512, let text = String(data: data, encoding: .utf8), text.hasPrefix("file://") {
            return nil
        }
        let ext = url.pathExtension.isEmpty ? "pdf" : url.pathExtension
        let staged = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        guard (try? data.write(to: staged)) != nil else { return nil }
        return staged
    }
}
