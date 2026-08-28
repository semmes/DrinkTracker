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
    .macOS(.v15)
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
