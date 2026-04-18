// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexUsageViewer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexUsageViewer", targets: ["CodexUsageViewer"]),
        .library(name: "CodexUsageCore", targets: ["CodexUsageCore"])
    ],
    targets: [
        .target(name: "CodexUsageCore"),
        .executableTarget(
            name: "CodexUsageViewer",
            dependencies: ["CodexUsageCore"]
        )
    ]
)
