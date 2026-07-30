# Denzel

An open-source, local-first invoice library for macOS. Denzel identifies, organizes, renames, and retrieves invoices — everything lives as plain files in a folder you choose; nothing leaves your Mac.

The filesystem is the source of truth. A per-file extended attribute (`com.denzel.meta`) and an append-only `journal.jsonl` carry every document's metadata and history; the SQLite index (`index.sqlite`, including full-text search) is a fully rebuildable cache — delete it and relaunch, and it comes back identical.

## Status

All core milestones (M1–M7) are implemented: filesystem-first library with journal + undo, text-layer extraction with a Vision OCR fallback for scanned documents, a 10-vendor rulebook with a confidence gate and review queue, a watched Inbox folder, a CLI, FTS5 search, and a signed Release build pipeline.

## Requirements

- macOS 15+
- Xcode 16+ (for the app target; the SPM packages build with just the Swift toolchain)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project: `brew install xcodegen`

## Building

The SPM packages (`DenzelCore`, `DenzelRules`, `DenzelCLI`) build without Xcode:

```
swift build
swift test
```

The macOS app target is generated from `App/project.yml`:

```
cd App
xcodegen generate
open Denzel.xcodeproj
```

## Using the app

1. Launch Denzel and choose a library folder. It's remembered across restarts.
2. **Inbox** — drop an invoice PDF onto the window, or drop one into the library's `Inbox/` folder in Finder while the app is running (watched automatically). It's matched against the vendor rulebook and either filed straight into `vendors/<vendor>/<year>/` or sent to Review.
3. **Review** — anything the rulebook couldn't confidently match (unknown vendor, missing/low-confidence fields, no text layer) waits here. Click a document to see what was extracted, correct it, and confirm.
4. **Library** — everything that's been filed, searchable by vendor or any word from the document's body text (⌘F focuses the search field). ⌘Z undoes the last file/move, even across restarts.

## CLI

The `denzel` command shares the same library the app is pointed at (both read/write the same `com.denzel.app` preferences suite), so it works whether or not the app is running:

```
swift run denzel scan                    # rebuild the index from disk
swift run denzel file path/to/invoice.pdf  # file a document through the pipeline
swift run denzel ls [--needs-review]     # list documents
swift run denzel undo                    # undo the last file/move
swift run denzel export [--quarter 2026-Q1]  # CSV export to stdout
```

## Adding a vendor

Vendor rules are data, not code — drop a YAML file into `Sources/DenzelRules/VendorRules/` (see the existing files for the schema) and it's picked up automatically, no Swift changes needed. Add a fixture in `Tests/DenzelRulesTests/VendorRuleFixtureTests.swift` to regression-test it.

## Releasing

`scripts/release.sh <version>` bumps the version, archives, Developer-ID-signs, and packages a `.zip` — safe to run any time, touches nothing external. Pass `--publish` to also notarize and create a public GitHub Release (needs `AC_API_KEY_PATH` set to the App Store Connect `.p8` key). See the script for details.

## License

MPL-2.0. See [LICENSE](LICENSE). Every source file carries an SPDX header (`// SPDX-License-Identifier: MPL-2.0`), enforced in CI.
