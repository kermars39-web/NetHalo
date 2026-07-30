// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NetHalo",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NetHalo", targets: ["NetHalo"])
    ],
    targets: [
        .executableTarget(
            name: "NetHalo",
            path: "Sources/NetHalo",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
