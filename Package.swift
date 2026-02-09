// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "PortDeck",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PortDeck", targets: ["PortDeck"])
    ],
    targets: [
        .executableTarget(
            name: "PortDeck"
        )
    ]
)
