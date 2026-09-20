import Foundation
import Testing

@testable import LauncherCore

@Suite struct LaunchPlannerTests {
    @Test func producesExactOrderedArgumentsAndDeduplicates() throws {
        let snapshot = readySnapshot(content: [
            item("workshop:a", "/Steam Folder/a"), item("dlc:b", "/Steam Folder/b"),
        ])
        let config = LaunchConfiguration(
            mode: .native, selectedContentIDs: ["workshop:a", "dlc:b", "workshop:a"],
            options: .init(skipIntro: true, noSplash: false, windowed: true),
            advancedArguments: "  -hugePages  \n-name=Player")
        let plan = try LaunchPlanner.makePlan(snapshot: snapshot, configuration: config)
        #expect(
            plan.arguments == [
                "-p", "default", "-no-remote", "-mod=C:/Steam Folder/a;C:/Steam Folder/b",
                "-skipIntro", "-window", "-hugePages", "-name=Player",
            ])
        #expect(plan.selectedContentIDs == ["workshop:a", "dlc:b"])
    }

    @Test(arguments: ["-MOD=thing", "-ServerMod=x", "-P=other", "-NO-REMOTE", "-SkipIntro=false", "-WINDOW"])
    func rejectsManagedArgumentsCaseInsensitively(argument: String) {
        #expect(throws: LaunchPlanError.conflictingArgument(argument)) {
            try LaunchPlanner.advancedArguments(argument)
        }
    }

    @Test func rejectsUnsafeSeparatorInPath() {
        let snapshot = readySnapshot(content: [item("workshop:a", "/mods/bad;path")])
        #expect(throws: LaunchPlanError.unsafePath("/mods/bad;path")) {
            try LaunchPlanner.makePlan(
                snapshot: snapshot,
                configuration: LaunchConfiguration(selectedContentIDs: ["workshop:a"]))
        }
    }

    @Test(arguments: ["bad\npath", "bad\rpath", "bad\"path"])
    func rejectsEveryUnsafePathCharacter(path: String) {
        let fullPath = "/mods/\(path)"
        #expect(throws: (any Error).self) {
            try LaunchPlanner.makePlan(
                snapshot: readySnapshot(content: [item("workshop:a", fullPath)]),
                configuration: LaunchConfiguration(selectedContentIDs: ["workshop:a"]))
        }
    }

    @Test func rejectsNULInSelectedPath() throws {
        let url = try #require(URL(string: "file:///mods/bad%00path"))
        let unsafe = ContentItem(
            id: "workshop:a", displayName: "a", source: .workshop, resolvedURL: url,
            availability: .ready, status: "ready")
        #expect(throws: LaunchPlanError.unsafePath("/mods/bad\0path")) {
            try LaunchPlanner.makePlan(
                snapshot: readySnapshot(content: [unsafe]),
                configuration: LaunchConfiguration(selectedContentIDs: ["workshop:a"]))
        }
    }

    @Test func reportsMissingPersistedSelection() {
        #expect(throws: LaunchPlanError.missingContent("workshop:gone")) {
            try LaunchPlanner.makePlan(
                snapshot: readySnapshot(),
                configuration: LaunchConfiguration(selectedContentIDs: ["workshop:gone"]))
        }
    }

    @Test func blocksUnknownGameReadiness() {
        var snapshot = readySnapshot()
        let game = snapshot.installation.selectedGame!
        let blocked = GameCandidate(
            directory: game.directory, libraryRoot: game.libraryRoot, manifestURL: game.manifestURL,
            readiness: .unknown, status: "unknown", bundles: game.bundles)
        snapshot = DiscoverySnapshot(
            generation: 1,
            installation: SteamInstallation(
                libraryRoots: [game.libraryRoot], candidates: [blocked], selectedGame: blocked,
                requiresExplicitChoice: false),
            content: [], warnings: [], errors: [])
        #expect(throws: LaunchPlanError.installationNotReady("unknown")) {
            try LaunchPlanner.makePlan(snapshot: snapshot, configuration: .init())
        }
    }
}

private func item(_ id: String, _ path: String) -> ContentItem {
    ContentItem(
        id: id, displayName: id, source: id.hasPrefix("dlc:") ? .optionalDLC : .workshop,
        resolvedURL: URL(filePath: path), availability: .ready, status: "ready")
}

private func readySnapshot(content: [ContentItem] = []) -> DiscoverySnapshot {
    let root = URL(filePath: "/Steam")
    let directory = root.appending(path: "steamapps/common/Arma 3")
    let game = GameCandidate(
        directory: directory, libraryRoot: root,
        manifestURL: root.appending(path: "steamapps/appmanifest_107410.acf"), readiness: .ready,
        status: "ready",
        bundles: [.init(mode: .native, url: directory.appending(path: "ArmA3 AS Native.app"))])
    return DiscoverySnapshot(
        generation: 1,
        installation: SteamInstallation(
            libraryRoots: [root], candidates: [game], selectedGame: game, requiresExplicitChoice: false),
        content: content, warnings: [], errors: [])
}
