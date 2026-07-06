// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Paper",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Paper",
            path: "Sources/Paper",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
