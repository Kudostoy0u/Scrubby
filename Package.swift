// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Scrubby",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Scrubby",
            path: "Sources/Scrubby",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
