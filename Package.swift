// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RunbookMac",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/msjurset/swift-vim-engine.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "RunbookMac",
            dependencies: [
                "Yams",
                .product(name: "VimEngine", package: "swift-vim-engine"),
            ],
            path: "Sources/RunbookMac"
        ),
        .testTarget(
            name: "RunbookMacTests",
            dependencies: [
                "RunbookMac",
                "Yams",
                .product(name: "VimEngine", package: "swift-vim-engine"),
            ],
            path: "Tests/RunbookMacTests"
        ),
    ]
)
