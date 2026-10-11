// swift-tools-version: 6.0
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
        .target(name: "LRCLib", dependencies: [.product(name: "SubtitleKit", package: "swift-subtitle-kit")]),
        .testTarget(name: "LRCLibTests", dependencies: ["LRCLib"]),
    ]
)
