// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "safari-mcp",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "safari-mcp", path: "Sources/safari-mcp")
    ]
)
