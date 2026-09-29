// swift-tools-version: 6.0
import PackageDescription

// Defines the independently maintainable preview modules shared by both entry points.
let package = Package(
    name: "SpaceLookPreview",
    platforms: [.macOS(.v13)],
    products: [.library(name: "PreviewModules", targets: ["PreviewModules"])],
    dependencies: [
        .package(url: "https://github.com/smittytone/HighlighterSwift.git", exact: "3.1.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", exact: "2.4.1"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20")
    ],
    targets: [
        .target(name: "PreviewCore"),
        .target(name: "DirectoryPreview", dependencies: ["PreviewCore"]),
        .target(name: "ModelPreview", dependencies: ["PreviewCore"], resources: [.copy("Resources")]),
        .target(
            name: "PreviewUI",
            dependencies: [.product(name: "Highlighter", package: "HighlighterSwift")]
        ),
        .target(
            name: "MarkdownPreview",
            dependencies: [
                "PreviewCore",
                "PreviewUI",
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ]
        ),
        .target(name: "StructuredTextPreview", dependencies: ["PreviewCore", "PreviewUI"]),
        .target(
            name: "ZipPreview",
            dependencies: ["PreviewCore", .product(name: "ZIPFoundation", package: "ZIPFoundation")]
        ),
        .target(
            name: "PreviewModules",
            dependencies: ["PreviewCore", "DirectoryPreview", "MarkdownPreview", "StructuredTextPreview", "ZipPreview", "ModelPreview"]
        )
    ]
)
