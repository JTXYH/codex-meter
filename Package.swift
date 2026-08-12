// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexMeter",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "CodexMeter", targets: ["CodexMeter"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.2"),
    ],
    targets: [
        .executableTarget(
            name: "CodexMeter",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/CodexMeter",
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks",
                ]),
            ]
        ),
        .testTarget(
            name: "CodexMeterTests",
            dependencies: ["CodexMeter"],
            path: "Tests/CodexMeterTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
