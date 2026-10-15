// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Probe",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/alexeichhorn/YouTubeKit", .upToNextMinor(from: "0.4.9")),
    ],
    targets: [
        .executableTarget(name: "Probe", dependencies: ["YouTubeKit"]),
    ]
)
