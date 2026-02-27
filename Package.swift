// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NetSwitcher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NetSwitcher", targets: ["NetSwitcher"])
    ],
    targets: [
        .executableTarget(
            name: "NetSwitcher"
        )
    ]
)