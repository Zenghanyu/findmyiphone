// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "EasyFindCore",
  platforms: [.iOS(.v17), .macOS(.v13)],
  products: [.library(name: "EasyFindCore", targets: ["EasyFindCore"])],
  targets: [
    .target(name: "EasyFindCore"),
    .testTarget(name: "EasyFindCoreTests", dependencies: ["EasyFindCore"]),
  ]
)
