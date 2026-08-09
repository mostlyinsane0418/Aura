// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AuraKit",
    products: [
        .library(name: "AuraKit", targets: ["AuraKit"])
    ],
    targets: [
        .target(name: "AuraKit"),
        // A command-line way to run the real clustering over a real library's
        // metadata, without a phone. See Tools/probe_library.py.
        .executableTarget(name: "aura-probe", dependencies: ["AuraKit"]),
        .testTarget(name: "AuraKitTests", dependencies: ["AuraKit"])
    ]
)
