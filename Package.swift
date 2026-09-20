// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Arma3Launcher",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LauncherCore", targets: ["LauncherCore"]),
        .executable(name: "LauncherDiagnostics", targets: ["LauncherDiagnostics"]),
    ],
    targets: [
        .target(name: "LauncherCore"),
        .target(
            name: "LauncherAppSupport", dependencies: ["LauncherCore"], path: "App",
            exclude: ["Arma3LauncherApp.swift", "MainWindow.swift"], sources: ["LauncherModel.swift"]),
        .executableTarget(name: "LauncherDiagnostics", dependencies: ["LauncherCore"]),
        .testTarget(name: "LauncherCoreTests", dependencies: ["LauncherCore"]),
        .testTarget(
            name: "LauncherAppSupportTests", dependencies: ["LauncherAppSupport", "LauncherCore"]),
    ]
)
