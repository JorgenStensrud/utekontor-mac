// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Utekontor",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "Utekontor", targets: ["Utekontor"]),
    ],
    targets: [
        .executableTarget(
            name: "Utekontor",
            path: "Sources/Utekontor"
        ),
    ]
)
