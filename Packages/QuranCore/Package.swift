// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuranCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        // Pure model / navigation / text-loading logic. No UI, no Apple-only
        // frameworks, so it is testable anywhere Swift runs.
        .library(name: "QuranCore", targets: ["QuranCore"]),
        // Device-to-device plumbing: Watch <-> iPhone, and iPhone <-> iPad.
        .library(name: "QuranLink", targets: ["QuranLink"])
    ],
    targets: [
        .target(name: "QuranCore"),
        .target(name: "QuranLink", dependencies: ["QuranCore"]),
        .testTarget(name: "QuranCoreTests", dependencies: ["QuranCore"])
    ]
)
