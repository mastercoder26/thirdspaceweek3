// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TabDNA",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TabDNA", targets: ["TabDNA"])
    ],
    targets: [
        .executableTarget(
            name: "TabDNA",
            path: "Sources/TabDNA",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "TabDNATests",
            dependencies: ["TabDNA"],
            path: "Tests/TabDNATests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
