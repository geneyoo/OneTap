// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "onetap",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "tap", targets: ["onetap"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "onetap",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/onetap"
        ),
        .testTarget(
            name: "onetapTests",
            dependencies: ["onetap"],
            path: "Tests/onetapTests"
        )
    ]
)
