// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftfulDataManagersFirebase",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftfulDataManagersFirebase",
            targets: ["SwiftfulDataManagersFirebase"]),
    ],
    dependencies: [
        .package(url: "https://github.com/andrewcoyle1/SwiftfulDataManagers.git", "1.0.0"..<"2.0.0"),
        .package(url: "https://github.com/SwiftfulThinking/SwiftfulFirestore.git", "11.0.6"..<"12.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftfulDataManagersFirebase",
            dependencies: [
                .product(name: "SwiftfulDataManagers", package: "SwiftfulDataManagers"),
                .product(name: "SwiftfulFirestore", package: "SwiftfulFirestore"),
            ]
        ),
        .testTarget(
            name: "SwiftfulDataManagersFirebaseTests",
            dependencies: ["SwiftfulDataManagersFirebase"]
        ),
    ]
)
