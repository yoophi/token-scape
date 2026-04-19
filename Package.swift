// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TokenScope",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TokenScope", targets: ["TokenScope"]),
        .library(name: "TokenScopeCore", targets: ["TokenScopeCore"])
    ],
    targets: [
        .target(name: "TokenScopeCore"),
        .executableTarget(
            name: "TokenScope",
            dependencies: ["TokenScopeCore"]
        ),
        .executableTarget(
            name: "UsageTests",
            dependencies: ["TokenScopeCore"],
            path: "Tests/UsageTests"
        )
    ]
)
