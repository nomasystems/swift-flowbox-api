// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "swift-flowbox-api",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "FlowboxAPI", targets: ["FlowboxAPI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-runtime", .upToNextMinor(from: "1.12.2")),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", .upToNextMinor(from: "1.3.2")),
        .package(url: "https://github.com/apple/swift-http-types", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "FlowboxAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                .product(name: "HTTPTypes", package: "swift-http-types")
            ]
        )
    ]
)
