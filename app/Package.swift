// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Herdr",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "Herdr",
            dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")]
        ),
    ]
)
