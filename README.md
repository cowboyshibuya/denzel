# Denzel

An open-source, local-first invoice library for macOS. Denzel identifies, organizes, renames, and retrieves invoices — everything lives as plain files in a folder you choose; nothing leaves your Mac.

## Status

Early scaffold (M0): repo, SPM workspace, CI, and a 3-page app shell with a library-folder picker that persists across restarts.

## Requirements

- macOS 15+
- Swift 6.1+ (Xcode 16+ recommended for the app target)
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

## License

MPL-2.0. See [LICENSE](LICENSE). Every source file carries an SPDX header (`// SPDX-License-Identifier: MPL-2.0`), enforced in CI.
