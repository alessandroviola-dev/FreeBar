// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FreeBar",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "FreeBar", targets: ["FreeBar"])],
    targets: [
        .executableTarget(name: "FreeBar"),
        .testTarget(name: "FreeBarTests", dependencies: ["FreeBar"])
    ]
)
