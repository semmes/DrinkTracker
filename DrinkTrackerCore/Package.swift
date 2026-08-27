// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "DrinkTrackerCore",
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
