// swift-tools-version: 6.0

import PackageDescription
import Foundation

let nativeRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let megaHeaders = nativeRoot.appendingPathComponent("Vendor/MEGADependencies/Headers").path
let megaLibraries = nativeRoot.appendingPathComponent("Vendor/MEGADependencies").path
let sdkSources = nativeRoot.appendingPathComponent("Vendor/MEGASDK").path
// The MEGA native library is iOS-only; Linux core tests don't compile it.
let coreOnly = ProcessInfo.processInfo.environment["CALC84_CORE_ONLY"] == "1"

let package = Package(
    name: "Arithvale",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // An xtool project should contain exactly one library product,
        // representing the main app.
        .library(
            name: "Arithvale",
            targets: ["Calc84"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", exact: "4.3.1")
    ],
    targets: [
        .target(
            name: "Calc84", dependencies: coreOnly ? ["CalcCore"] : ["CalcCore", .target(name: "CalcMega", condition: .when(platforms: [.iOS]))],
            exclude: ["Info.plist"], resources: [.copy("Resources"), .copy("PrivacyInfo.xcprivacy")],
            // The Linux Swift Build linker otherwise records the deployment target
            // as the SDK version. Match the installed iOS 27.1 SDK while retaining iOS 17 support.
            linkerSettings: [.unsafeFlags([
                "-Xlinker", "-platform_version", "-Xlinker", "ios",
                "-Xlinker", "17.0", "-Xlinker", "27.1"
            ], .when(platforms: [.iOS]))]
        ),
        .target(name: "MEGACore", path: "Vendor/MEGASDK", exclude: [
            "bindings", "cmake", "contrib", "examples", "tests", "tools",
            "src/android", "src/common/client_adapter_with_sync.cpp", "src/common/platform/windows",
            "src/fuse/supported", "src/win32", "src/file_service/documentation", "third_party/utf8proc/utf8proc_data.c"
        ], sources: ["src", "third_party/utf8proc/utf8proc.cpp", "third_party/ccronexpr/ccronexpr.cpp"], publicHeadersPath: "include",
        cSettings: [.unsafeFlags(["-I" + megaHeaders])],
        cxxSettings: [.headerSearchPath("bindings/ios"), .headerSearchPath("include/mega/osx"),
            .headerSearchPath("include/mega/posix"), .headerSearchPath("src/common/platform/posix"),
            .headerSearchPath("src/file_service"), .headerSearchPath("src/fuse/unsupported"),
            .headerSearchPath("third_party"), .define("HAVE_LIBUV"), .define("ENABLE_CHAT"), .define("NDEBUG", .when(configuration: .release)),
            .unsafeFlags(["-I" + megaHeaders])],
        linkerSettings: [.unsafeFlags(["-L" + megaLibraries, "-lmega"]), .linkedLibrary("c++"),
            .linkedLibrary("z"), .linkedLibrary("sqlite3"), .linkedLibrary("resolv"), .linkedLibrary("icucore"),
            .linkedFramework("QuickLookThumbnailing"), .linkedFramework("AVFoundation"),
            .linkedFramework("CFNetwork"), .linkedFramework("Security"), .linkedFramework("CoreGraphics"),
            .linkedFramework("ImageIO"), .linkedFramework("UIKit"), .linkedFramework("UniformTypeIdentifiers")]),
        .target(name: "CalcMega", dependencies: ["MEGACore"], publicHeadersPath: "include",
            cxxSettings: [.unsafeFlags(["-I" + sdkSources + "/include", "-I" + sdkSources + "/bindings/ios", "-I" + megaHeaders])]),
        .target(name: "CalcCore", dependencies: [
            .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
            .product(name: "CryptoExtras", package: "swift-crypto", condition: .when(platforms: [.linux]))
        ]),
        .testTarget(name: "CalcCoreTests", dependencies: ["CalcCore"])
    ].filter { !coreOnly || !["MEGACore", "CalcMega"].contains($0.name) },
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx17
)
