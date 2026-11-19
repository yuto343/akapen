// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AkapenKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    products: ["AkapenCore", "AkapenPlatform", "AkapenUI", "AkapenApp", "AkapenAXID"].map {
        .library(name: $0, targets: [$0])
    },
    // 外部のライブラリは Sparkle（アプリ内の更新）だけ。AGENTS.md の例外。
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1"),
    ],
    targets: [
        .target(name: "AkapenCore"),
        .target(name: "AkapenAXID"),
        .target(
            name: "AkapenPlatform",
            dependencies: [
                "AkapenCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        .target(
            name: "AkapenUI",
            dependencies: ["AkapenCore", "AkapenAXID"],
            resources: [.process("Resources")]
        ),
        .target(name: "AkapenApp", dependencies: ["AkapenCore", "AkapenUI", "AkapenPlatform"]),
        .testTarget(name: "AkapenCoreTests", dependencies: ["AkapenCore"]),
        .testTarget(name: "AkapenPlatformTests", dependencies: ["AkapenPlatform"]),
        .testTarget(name: "AkapenUITests", dependencies: ["AkapenUI"]),
        .testTarget(name: "AkapenAppTests", dependencies: ["AkapenApp"]),
    ],
    swiftLanguageModes: [.v6]
)
