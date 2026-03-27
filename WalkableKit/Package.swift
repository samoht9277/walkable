// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WalkableKit",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11)
    ],
    products: [
        .library(name: "WalkableKit", targets: ["WalkableKit"])
    ],
    targets: [
        .target(
            name: "WalkableKit",
            path: "Sources/WalkableKit"
        )
    ]
)
