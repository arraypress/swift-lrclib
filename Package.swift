// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LRCLib",
    platforms: [
        .macOS(.v14), .iOS(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1),
    ],
    products: [
        .library(name: "LRCLib", targets: ["LRCLib"]),
    ],
    dependencies: [
        // SRT and WebVTT: the cue model and writers the caption tools already share.
        .package(url: "https://github.com/arraypress/swift-subtitle-kit.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "LRCLib",
            dependencies: [.product(name: "SubtitleKit", package: "swift-subtitle-kit")],
            swiftSettings: [
                // Async functions run on the caller's executor rather than hopping
                // to the global pool — Swift 6.2's "nonisolated nonsending" default.
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]),
        .testTarget(name: "LRCLibTests", dependencies: ["LRCLib"]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
