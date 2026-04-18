// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ListenCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "ListenCore", targets: ["ListenCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "ListenCore",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit")
            ]
        ),
        .testTarget(
            name: "ListenCoreTests",
            dependencies: ["ListenCore"]
        ),
    ]
)
