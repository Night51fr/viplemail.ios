// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VipleMail",
    defaultLocalization: "fr",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "VipleMail",
            targets: ["VipleMail"]
        )
    ],
    targets: [
        .target(
            name: "VipleMail",
            path: "Sources",
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
