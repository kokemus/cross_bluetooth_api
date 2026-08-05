// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "cross_bluetooth_api",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "cross-bluetooth-api", targets: ["cross_bluetooth_api"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "cross_bluetooth_api",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
