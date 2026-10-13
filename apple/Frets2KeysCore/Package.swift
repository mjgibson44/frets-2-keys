// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Frets2KeysCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Frets2KeysCore", targets: ["Frets2KeysCore"]),
    ],
    targets: [
        .target(name: "Frets2KeysCore"),
        .testTarget(name: "Frets2KeysCoreTests", dependencies: ["Frets2KeysCore"]),
    ]
)
