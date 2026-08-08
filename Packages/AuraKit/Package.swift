// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AuraKit",
    products: [
        .library(name: "AuraKit", targets: ["AuraKit"])
    ],
    targets: [
        .target(name: "AuraKit"),
        .testTarget(name: "AuraKitTests", dependencies: ["AuraKit"])
    ]
)
