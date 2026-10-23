// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Harbor",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .target(
            name: "HarborCore",
            path: "Sources/HarborCore"
        ),
        .executableTarget(
            name: "Harbor",
            dependencies: ["HarborCore"],
            path: "Sources/Harbor"
        ),
        .executableTarget(
            name: "HarborFixtureServer",
            dependencies: ["HarborCore"],
            path: "Sources/HarborFixtureServer"
        ),
        .target(
            name: "HarborTestSupport",
            dependencies: ["HarborCore"],
            path: "Tests/HarborTestSupport"
        ),
        .testTarget(
            name: "HarborCoreTests",
            dependencies: ["HarborCore", "HarborTestSupport"],
            path: "Tests/HarborCoreTests"
        ),
        .testTarget(
            name: "HarborIntegrationTests",
            dependencies: ["HarborCore", "HarborTestSupport"],
            path: "Tests/HarborIntegrationTests"
        ),
        .testTarget(
            name: "HarborFunctionalTests",
            dependencies: ["HarborCore", "HarborTestSupport"],
            path: "Tests/HarborFunctionalTests"
        ),
        .testTarget(
            name: "HarborTests",
            dependencies: ["Harbor", "HarborCore", "HarborTestSupport"],
            path: "Tests/HarborTests"
        ),
    ]
)
