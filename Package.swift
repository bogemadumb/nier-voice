// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NierVoice",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "NierVoice",
            path: "Sources/NierVoice",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
