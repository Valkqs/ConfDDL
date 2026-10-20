// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ConfDDL",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ConfDDL", targets: ["ConfDDL"])],
    dependencies: [.package(path: "Vendor/Yams")],
    targets: [
        .target(name: "DeadlineCore", dependencies: [.product(name: "Yams", package: "Yams")]),
        .executableTarget(name: "ConfDDL", dependencies: ["DeadlineCore"]),
        .executableTarget(name: "DeadlineCoreChecks", dependencies: ["DeadlineCore"], path: "Tests/DeadlineCoreTests")
    ]
)
