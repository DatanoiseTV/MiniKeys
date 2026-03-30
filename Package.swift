// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MiniKeys",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MiniKeys",
            path: "Sources/MiniKeys"
        )
    ]
)
