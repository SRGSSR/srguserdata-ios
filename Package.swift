// swift-tools-version:5.3

import PackageDescription

struct ProjectSettings {
    static let marketingVersion: String = "3.0.0"
}

let package = Package(
    name: "SRGUserData",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v9),
        .tvOS(.v12)
    ],
    products: [
        .library(
            name: "SRGUserData",
            targets: ["SRGUserData"]
        )
    ],
    dependencies: [
        .package(name: "SRGIdentity", url: "https://github.com/SRGSSR/srgidentity-apple.git", .branch("develop"))
    ],
    targets: [
        .target(
            name: "SRGUserData",
            dependencies: ["SRGIdentity"],
            resources: [
                .process("Data"),
                .process("Resources"),
            ],
            cSettings: [
                .define("MARKETING_VERSION", to: "\"\(ProjectSettings.marketingVersion)\"")
            ]
        )
    ]
)
