// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MacClickStudio",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MacClickStudio",
            targets: ["MacClickStudio"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MacClickStudio"
        )
    ]
)
