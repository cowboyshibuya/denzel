// swift-tools-version:5.10
// SPDX-License-Identifier: MPL-2.0
import PackageDescription

let package = Package(
    name: "Denzel",
    // Package-level floor; the app target's own deployment target (project.yml) is
    // what actually enforces macOS 15+ for end users. .v15 needs tools-version 6.0,
    // which would force Swift 6 strict concurrency — not worth it for this package.
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DenzelCore", targets: ["DenzelCore"]),
        .library(name: "DenzelRules", targets: ["DenzelRules"]),
        .executable(name: "denzel", targets: ["DenzelCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.0.0"),
    ],
    targets: [
        .target(name: "DenzelCore", dependencies: [.product(name: "GRDB", package: "GRDB.swift")]),
        .target(
            name: "DenzelRules",
            dependencies: ["DenzelCore", .product(name: "Yams", package: "Yams")],
            resources: [.copy("VendorRules")]
        ),
        .executableTarget(
            name: "DenzelCLI",
            dependencies: [
                "DenzelCore",
                "DenzelRules",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "DenzelCoreTests", dependencies: ["DenzelCore"]),
        .testTarget(name: "DenzelRulesTests", dependencies: ["DenzelRules"]),
    ]
)
