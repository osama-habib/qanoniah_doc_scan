// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "qanoniah_doc_scan",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "qanoniah-doc-scan", targets: ["qanoniah_doc_scan"])
    ],
    dependencies: [],
    targets: [
        // Tesseract 5 + Leptonica, built from source by tool/build_ios_tesseract.sh.
        .binaryTarget(name: "CTesseract", path: "Frameworks/CTesseract.xcframework"),
        .target(
            name: "qanoniah_doc_scan",
            dependencies: ["CTesseract"],
            resources: [
                // If your plugin requires a privacy manifest, for example if it uses any required
                // reason APIs, update the PrivacyInfo.xcprivacy file to describe your plugin's
                // privacy impact, and then uncomment these lines. For more information, see
                // https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
                // .process("PrivacyInfo.xcprivacy"),

                // If you have other resources that need to be bundled with your plugin, refer to
                // the following instructions to add them:
                // https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package
            ],
            linkerSettings: [.linkedLibrary("c++")]
        )
    ]
)
