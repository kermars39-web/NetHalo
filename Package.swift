// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GlanceBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GlanceBar", targets: ["GlanceBar"])
    ],
    targets: [
        .executableTarget(
            name: "GlanceBar",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
