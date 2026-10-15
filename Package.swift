// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Echo",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        // An xtool project should contain exactly one library product,
        // representing the main app.
        .library(
            name: "Echo",
            targets: ["Echo"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/alexeichhorn/YouTubeKit", .upToNextMinor(from: "0.4.9")),
    ],
    targets: [
        .target(
            name: "Echo",
            dependencies: ["YouTubeKit"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
