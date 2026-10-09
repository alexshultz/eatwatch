// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "EatWatchCore",
    platforms: [
        .iOS(.v27),
        .macOS(.v27),
        .watchOS(.v27)
    ],
    products: [
        .library(name: "EatWatchCore", targets: ["EatWatchCore"])
    ],
    targets: [
        .target(
            name: "EatWatchCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "EatWatchCoreTests",
            dependencies: ["EatWatchCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
