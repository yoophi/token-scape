// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TokenScope",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TokenScope", targets: ["TokenScope"]),
        .library(name: "CodexUsageCore", targets: ["CodexUsageCore"])
    ],
    targets: [
        .target(name: "CodexUsageCore"),
        .executableTarget(
            name: "TokenScope",
            dependencies: ["CodexUsageCore"]
        ),
        .executableTarget(
            name: "UsageTests",
            dependencies: ["CodexUsageCore"],
            path: "Tests/UsageTests"
        )
    ]
)
