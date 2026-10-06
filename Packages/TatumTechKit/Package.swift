// swift-tools-version: 6.0
import PackageDescription

// Platform-neutral core of the Tatum Tech app: configuration, networking, API models,
// domain models, session and account logic. No UIKit/SwiftUI, so it also builds and
// tests with the Swift toolchain on Linux and Windows.
let package = Package(
    name: "TatumTechKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TatumTechKit", targets: ["TatumTechKit"])
    ],
    targets: [
        .target(name: "TatumTechKit"),
        .testTarget(name: "TatumTechKitTests", dependencies: ["TatumTechKit"])
    ]
)
