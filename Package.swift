// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "AirPortUtility",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "AirPort Utility", targets: ["AirPortUtilityApp"])
  ],
  targets: [
    .target(
      name: "AirPortUtilityCore",
      path: "Sources/AirPortUtilityCore",
      resources: [
        .process("Resources")
      ]
    ),
    .executableTarget(
      name: "AirPortUtilityApp",
      dependencies: ["AirPortUtilityCore"],
      path: "Sources/AirPortUtilityApp",
      exclude: ["Resources"]
    ),
    .testTarget(
      name: "AirPortUtilityAppTests",
      dependencies: ["AirPortUtilityCore"],
      path: "Tests/AirPortUtilityAppTests"
    ),
  ]
)
