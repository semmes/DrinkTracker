// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "DrinkTrackerCore",
  // Required before the package can carry localized resources. English is the
  // source language, and every lookup falls back to it — which is what keeps
  // the domain tests running unchanged on macOS CI (ADR-0020).
  defaultLocalization: "en",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
    // The watch app and its complication link this package (watch Phase 1).
    // The string form on purpose: `.v26` needs a newer tools-version than 6.0
    // and fails to compile, while this resolves to the same `watchos 26.0`.
    .watchOS("26.0")
  ],
  products: [
    .library(name: "DrinkTrackerCore", targets: ["DrinkTrackerCore"])
  ],
  targets: [
    .target(
      name: "DrinkTrackerCore",
      resources: [.process("Resources")]
    ),
    .testTarget(
      name: "DrinkTrackerCoreTests",
      dependencies: ["DrinkTrackerCore"]
    )
  ]
)
