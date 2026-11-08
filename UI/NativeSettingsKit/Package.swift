// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NativeSettingsKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "NativeSettingsKit", targets: ["NativeSettingsKit"]),
        // Preview/demo only. Never link this product into a shipping app.
        .library(name: "NativeSettingsKitExamples", targets: ["NativeSettingsKitExamples"])
    ],
    targets: [
        .target(name: "NativeSettingsKit"),
        .target(name: "NativeSettingsKitExamples", dependencies: ["NativeSettingsKit"], path: "Examples"),
        .testTarget(name: "NativeSettingsKitTests", dependencies: ["NativeSettingsKit"])
    ]
)
