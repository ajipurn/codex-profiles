// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexProfiles",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "CodexProfiles", targets: ["CodexProfiles"]),
        .library(name: "CodexProfilesCore", targets: ["CodexProfilesCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6"),
    ],
    targets: [
        .target(
            name: "CodexProfilesCore",
            path: "CodexProfilesCore"
        ),
        .executableTarget(
            name: "CodexProfiles",
            dependencies: ["CodexProfilesCore", .product(name: "Sparkle", package: "Sparkle")],
            path: "CodexProfiles",
            exclude: [
                "Info.plist",
                "CodexProfiles.entitlements",
            ],
            resources: [
                .process("Assets.xcassets"),
                .process("Resources"),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
        .executableTarget(
            name: "CodexProfilesCheck",
            dependencies: ["CodexProfilesCore"],
            path: "CodexProfilesTests"
        ),
    ]
)
