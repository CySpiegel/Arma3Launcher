import Foundation
import Testing

@testable import LauncherCore

@Suite struct SteamDiscoveryTests {
    @Test func findsGameWhenLibraryAppsHintOmitsIt() throws {
        try withTemporaryDirectory { root in
            try createGame(root: root, flags: "4")
            let snapshot = SteamDiscovery.scan(.init(defaultSteamRoot: root))
            #expect(snapshot.installation.candidates.count == 1)
            #expect(snapshot.installation.selectedGame?.readiness == .ready)
        }
    }

    @Test func blocksUpdatingUnknownAndErrorStates() throws {
        try withTemporaryDirectory { root in
            try createGame(root: root, flags: "6")
            #expect(
                SteamDiscovery.scan(.init(defaultSteamRoot: root)).installation.selectedGame?.readiness
                    == .updating)
        }
        try withTemporaryDirectory { root in
            try createGame(root: root, flags: nil)
            #expect(
                SteamDiscovery.scan(.init(defaultSteamRoot: root)).installation.selectedGame?.readiness
                    == .unknown)
        }
        try withTemporaryDirectory { root in
            try createGame(root: root, flags: "4", update: "2")
            #expect(
                SteamDiscovery.scan(.init(defaultSteamRoot: root)).installation.selectedGame?.readiness
                    == .error)
        }
    }

    @Test func rejectsUnsafeInstallDirectory() throws {
        try withTemporaryDirectory { root in
            try createGame(root: root, flags: "4", installDir: "../elsewhere")
            #expect(SteamDiscovery.scan(.init(defaultSteamRoot: root)).installation.candidates.isEmpty)
        }
    }

    @Test func multipleGamesRequireExplicitChoice() throws {
        try withTemporaryDirectory { root in
            let other = root.appending(path: "other")
            try createGame(root: root, flags: "4")
            try createGame(root: other, flags: "4")
            let libraryVDF = "\"libraryfolders\" { \"1\" { \"path\" \"\(other.path)\" } }"
            try write(libraryVDF, root.appending(path: "steamapps/libraryfolders.vdf"))
            let snapshot = SteamDiscovery.scan(.init(defaultSteamRoot: root))
            #expect(snapshot.installation.candidates.count == 2)
            #expect(snapshot.installation.requiresExplicitChoice)
            #expect(snapshot.installation.selectedGame == nil)
        }
    }

    @Test func rootsPreserveExplicitAndDefaultThenSortCanonicalAliases() throws {
        try withTemporaryDirectory { container in
            let root = container.appending(path: "default")
            let explicit = container.appending(path: "explicit")
            let alpha = container.appending(path: "alpha")
            let zulu = container.appending(path: "zulu")
            for directory in [root, explicit, alpha, zulu] {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let alias = container.appending(path: "alias-alpha")
            try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: alpha)
            let libraries =
                "\"libraryfolders\" { \"3\" { \"path\" \"\(zulu.path)\" } \"2\" { \"path\" \"\(alias.path)\" } \"1\" { \"path\" \"\(alpha.path)\" } }"
            try write(libraries, root.appending(path: "steamapps/libraryfolders.vdf"))
            let roots = SteamDiscovery.scan(
                .init(defaultSteamRoot: root, explicitLibraryRoots: [explicit, alias])
            ).installation.libraryRoots
            #expect(roots[0] == explicit.standardizedFileURL)
            #expect(roots[1] == alias.standardizedFileURL)
            #expect(roots[2] == root.standardizedFileURL)
            #expect(roots[3].path == zulu.standardizedFileURL.path)
            #expect(roots.count == 4)
        }
    }

    @Test func readsLegacyIndexedStringLibraryRoot() throws {
        try withTemporaryDirectory { root in
            let legacy = root.appending(path: "legacy")
            try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
            try write(
                "\"libraryfolders\" { \"1\" \"\(legacy.path)\" }",
                root.appending(path: "steamapps/libraryfolders.vdf"))
            let roots = SteamDiscovery.scan(.init(defaultSteamRoot: root)).installation.libraryRoots
            #expect(roots.map(\.path).contains(legacy.path))
        }
    }

    @Test func downloadAndStagingProgressMustBePairedCompleteAndValid() throws {
        try withTemporaryDirectory { root in
            let manifestURL = root.appending(path: "steamapps/appmanifest_107410.acf")
            let prefix =
                "\"AppState\" { \"appid\" \"107410\" \"installdir\" \"Arma 3\" \"StateFlags\" \"4\" "
            try FileManager.default.createDirectory(
                at: root.appending(path: "steamapps/common/Arma 3"), withIntermediateDirectories: true)
            for (fields, expected) in [
                ("\"BytesToDownload\" \"10\"", Availability.unknown),
                ("\"BytesToDownload\" \"10\" \"BytesDownloaded\" \"9\"", .updating),
                ("\"BytesToStage\" \"x\" \"BytesStaged\" \"x\"", .unknown),
                ("\"BytesToStage\" \"3\" \"BytesStaged\" \"3\"", .ready),
            ] {
                try write(prefix + fields + " }", manifestURL)
                #expect(
                    SteamDiscovery.scan(.init(defaultSteamRoot: root)).installation.selectedGame?.readiness
                        == expected)
            }
        }
    }

    @Test func vanishedExplicitGameDoesNotFallBack() throws {
        try withTemporaryDirectory { root in
            try createGame(root: root, flags: "4")
            let missing = root.appending(path: "missing")
            let snapshot = SteamDiscovery.scan(.init(defaultSteamRoot: root, explicitGameDirectory: missing))
            #expect(snapshot.installation.selectedGame?.directory == missing)
            #expect(snapshot.installation.selectedGame?.readiness == .unknown)
        }
    }

    @Test func explicitManifestBackedGameFolderUsesValidatedCandidate() throws {
        try withTemporaryDirectory { root in
            try createGame(root: root, flags: "4")
            let directory = root.appending(path: "steamapps/common/Arma 3")
            let game = try #require(
                SteamDiscovery.scan(
                    .init(defaultSteamRoot: root, explicitGameDirectory: directory)
                ).installation.selectedGame)
            #expect(game.directory == directory.standardizedFileURL)
            #expect(game.readiness == .ready)
            #expect(game.manifestURL == root.appending(path: "steamapps/appmanifest_107410.acf"))
        }
    }

    @Test func duplicateCopiesPreferReadyFallbackWithoutSelectedGame() throws {
        try withTemporaryDirectory { root in
            let other = root.appending(path: "other")
            try createAddon(root: root, id: "123", manifest: nil)
            try createAddon(root: other, id: "123", manifest: "9")
            let item = try #require(
                SteamDiscovery.scan(
                    .init(defaultSteamRoot: root, explicitLibraryRoots: [root, other])
                ).content.first { $0.id == "workshop:123" })
            #expect(item.availability == .ready)
            #expect(
                item.resolvedURL?.resolvingSymlinksInPath().path
                    == other.appending(path: "steamapps/workshop/content/107410/123")
                    .resolvingSymlinksInPath().path)
        }
    }

    @Test func selectedGameLibraryWinsWhenDuplicateMetadataConflicts() throws {
        try withTemporaryDirectory { root in
            let other = root.appending(path: "other")
            try createGame(root: root, flags: "4")
            try createAddon(root: root, id: "123", manifest: nil)
            try write(
                "name = \"Selected updating copy\";",
                root.appending(path: "steamapps/workshop/content/107410/123/mod.cpp"))
            try write(
                workshopManifest(id: "123", installed: "8", detail: "9"),
                root.appending(path: "steamapps/workshop/appworkshop_107410.acf"))
            try createAddon(root: other, id: "123", manifest: "9")
            try write(
                "name = \"Other ready copy\";",
                other.appending(path: "steamapps/workshop/content/107410/123/mod.cpp"))
            let item = try #require(
                SteamDiscovery.scan(
                    .init(defaultSteamRoot: root, explicitLibraryRoots: [root, other])
                ).content.first { $0.id == "workshop:123" })
            #expect(item.availability == .updating)
            #expect(item.displayName == "Selected updating copy")
            #expect(
                item.resolvedURL?.resolvingSymlinksInPath().path
                    == root.appending(path: "steamapps/workshop/content/107410/123")
                    .resolvingSymlinksInPath().path)
        }
    }

    @Test func missingMalformedAndIncompleteWorkshopMetadataRemainUnknown() throws {
        try withTemporaryDirectory { root in
            try createAddon(root: root, id: "123", manifest: nil)
            let manifestURL = root.appending(path: "steamapps/workshop/appworkshop_107410.acf")
            #expect(
                SteamDiscovery.scan(.init(defaultSteamRoot: root)).content.first {
                    $0.id == "workshop:123"
                }?.availability == .unknown)
            for manifest in [
                "{",
                "\"AppWorkshop\" { \"WorkshopItemDetails\" { \"123\" { \"manifest\" \"9\" } } }",
                "\"AppWorkshop\" { \"WorkshopItemsInstalled\" { \"123\" { \"manifest\" \"9\" } } }",
                "\"AppWorkshop\" { \"WorkshopItemsInstalled\" { \"123\" { } } \"WorkshopItemDetails\" { \"123\" { \"manifest\" \"9\" } } }",
            ] {
                try write(manifest, manifestURL)
                #expect(
                    SteamDiscovery.scan(.init(defaultSteamRoot: root)).content.first {
                        $0.id == "workshop:123"
                    }?.availability == .unknown)
            }
        }
    }

    @Test func duplicateWorkshopUsesSelectedGameLibraryEvenWhenUnknown() throws {
        try withTemporaryDirectory { root in
            let other = root.appending(path: "other")
            try createGame(root: root, flags: "4")
            try createAddon(root: root, id: "123", manifest: nil)
            try createAddon(root: other, id: "123", manifest: "9")
            let libraries = "\"libraryfolders\" { \"1\" { \"path\" \"\(other.path)\" } }"
            try write(libraries, root.appending(path: "steamapps/libraryfolders.vdf"))
            let snapshot = SteamDiscovery.scan(.init(defaultSteamRoot: root))
            let item = try #require(snapshot.content.first { $0.id == "workshop:123" })
            #expect(
                item.resolvedURL?.standardizedFileURL
                    == root.appending(path: "steamapps/workshop/content/107410/123").standardizedFileURL)
            #expect(item.availability == .unknown)
            #expect(item.copies.count == 2)
        }
    }

    @Test func duplicateWorkshopManifestRecordsBecomeUnknownWithoutTrap() throws {
        try withTemporaryDirectory { root in
            try createGame(root: root, flags: "4")
            try createAddon(root: root, id: "123", manifest: "9")
            let duplicate =
                "\"AppWorkshop\" { \"NeedsUpdate\" \"0\" \"NeedsDownload\" \"0\" \"WorkshopItemsInstalled\" { \"123\" { \"manifest\" \"9\" } \"123\" { \"manifest\" \"9\" } } \"WorkshopItemDetails\" { \"123\" { \"manifest\" \"9\" } } }"
            try write(duplicate, root.appending(path: "steamapps/workshop/appworkshop_107410.acf"))
            let item = try #require(
                SteamDiscovery.scan(.init(defaultSteamRoot: root)).content.first { $0.id == "workshop:123" })
            #expect(item.availability == .unknown)
        }
    }

    @Test func globalPendingUsesMatchingItemEvidenceBeforeFallback() throws {
        try withTemporaryDirectory { root in
            try createGame(root: root, flags: "4")
            try createAddon(root: root, id: "123", manifest: nil)
            try createAddon(root: root, id: "456", manifest: nil)
            let manifest =
                "\"AppWorkshop\" { \"NeedsUpdate\" \"1\" \"WorkshopItemsInstalled\" { \"123\" { \"manifest\" \"9\" } \"456\" { \"manifest\" \"8\" } } \"WorkshopItemDetails\" { \"123\" { \"manifest\" \"9\" } \"456\" { \"manifest\" \"7\" } } }"
            try write(manifest, root.appending(path: "steamapps/workshop/appworkshop_107410.acf"))
            let content = SteamDiscovery.scan(.init(defaultSteamRoot: root)).content
            #expect(content.first { $0.id == "workshop:123" }?.availability == .ready)
            #expect(content.first { $0.id == "workshop:456" }?.availability == .updating)
        }
    }

    @Test func optionalDLCRequiresRegularNonemptyPackageAndInheritsGameState() throws {
        try withTemporaryDirectory { root in
            try createGame(root: root, flags: "4")
            let contact = root.appending(path: "steamapps/common/Arma 3/Contact/addons")
            try FileManager.default.createDirectory(
                at: contact.appending(path: "fake.pbo"), withIntermediateDirectories: true)
            try Data().write(to: contact.appending(path: "empty.ebo"))
            var item = try #require(
                SteamDiscovery.scan(.init(defaultSteamRoot: root)).content.first { $0.id == "dlc:contact" })
            #expect(item.availability == .unsupported)
            try Data("package".utf8).write(to: contact.appending(path: "real.pbo"))
            item = try #require(
                SteamDiscovery.scan(.init(defaultSteamRoot: root)).content.first { $0.id == "dlc:contact" })
            #expect(item.availability == .ready)
            try createGame(root: root, flags: "6")
            item = try #require(
                SteamDiscovery.scan(.init(defaultSteamRoot: root)).content.first { $0.id == "dlc:contact" })
            #expect(item.availability == .updating)
        }
    }

    @Test func catalogUsesOfficialSteamArtworkApplicationIDs() throws {
        try withTemporaryDirectory { root in
            try createGame(root: root, flags: "4")
            let content = SteamDiscovery.scan(.init(defaultSteamRoot: root)).content
            let expected: [String: UInt32] = [
                "dlc:contact": 1_021_790, "dlc:gm": 1_042_220, "dlc:vn": 1_227_700,
                "dlc:csla": 1_294_440, "dlc:ws": 1_681_170, "dlc:spe": 1_175_380,
                "dlc:rf": 2_647_760, "dlc:ef": 2_647_830, "platform:karts": 288_520,
                "platform:helicopters": 304_380, "platform:marksmen": 332_350,
                "platform:apex": 395_180, "platform:jets": 601_670,
                "platform:laws-of-war": 571_710, "platform:tac-ops": 744_950,
                "platform:tanks": 798_390,
            ]
            #expect(expected.count == 16)
            for (id, appID) in expected {
                let item = try #require(content.first { $0.id == id })
                #expect(
                    item.artworkSource
                        == .steamApplication(
                            appID: appID,
                            cacheRoot: root.appending(path: "appcache/librarycache")))
            }
        }
    }

    @Test func immediateCancellationThrowsInsteadOfPublishingSnapshot() async throws {
        try await withTemporaryDirectoryAsync { root in
            let task = Task {
                try Task.checkCancellation()
                return try SteamDiscovery.scanCancellable(.init(defaultSteamRoot: root))
            }
            task.cancel()
            await #expect(throws: CancellationError.self) { try await task.value }
        }
    }

    @Test func cancellationInterruptsActiveWorkshopEnumeration() async throws {
        try await withTemporaryDirectoryAsync { root in
            try createGame(root: root, flags: "4")
            let workshop = root.appending(path: "steamapps/workshop/content/107410")
            for index in 0..<500 {
                try write("package", workshop.appending(path: "\(index)/addons/item.pbo"))
            }
            let task = Task { try SteamDiscovery.scanCancellable(.init(defaultSteamRoot: root)) }
            try await Task.sleep(for: .milliseconds(1))
            task.cancel()
            await #expect(throws: CancellationError.self) { try await task.value }
        }
    }

    @Test func oversizedBundleInfoIsNotAcceptedAsLaunchEvidence() throws {
        try withTemporaryDirectory { root in
            try createGame(root: root, flags: "4")
            let bundle = root.appending(path: "steamapps/common/Arma 3/Arma 3.app/Contents")
            try FileManager.default.createDirectory(
                at: bundle.appending(path: "MacOS"), withIntermediateDirectories: true)
            try Data(repeating: 65, count: 1_024 * 1_024 + 1).write(
                to: bundle.appending(path: "Info.plist"))
            try Data([1]).write(to: bundle.appending(path: "MacOS/game"))
            let game = try #require(
                SteamDiscovery.scan(.init(defaultSteamRoot: root)).installation.selectedGame)
            #expect(game.bundles.isEmpty)
        }
    }
}

private func withTemporaryDirectoryAsync(_ body: (URL) async throws -> Void) async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try await body(root)
}

private func createGame(
    root: URL, flags: String?, update: String = "0", installDir: String = "Arma 3"
) throws {
    let stateFlags = flags.map { "\"StateFlags\" \"\($0)\"" } ?? ""
    let manifest =
        "\"AppState\" { \"appid\" \"107410\" \"installdir\" \"\(installDir)\" \(stateFlags) \"UpdateResult\" \"\(update)\" \"BytesToDownload\" \"10\" \"BytesDownloaded\" \"10\" }"
    try write(manifest, root.appending(path: "steamapps/appmanifest_107410.acf"))
    try FileManager.default.createDirectory(
        at: root.appending(path: "steamapps/common/\(installDir)"), withIntermediateDirectories: true)
}

private func write(_ string: String, _ url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(string.utf8).write(to: url)
}

private func createAddon(root: URL, id: String, manifest: String?) throws {
    let addon = root.appending(path: "steamapps/workshop/content/107410/\(id)")
    try write("package", addon.appending(path: "addons/example.pbo"))
    guard let manifest else { return }
    let data = workshopManifest(id: id, installed: manifest, detail: manifest)
    try write(data, root.appending(path: "steamapps/workshop/appworkshop_107410.acf"))
}

private func workshopManifest(id: String, installed: String, detail: String) -> String {
    "\"AppWorkshop\" { \"NeedsUpdate\" \"0\" \"NeedsDownload\" \"0\" \"WorkshopItemsInstalled\" { \"\(id)\" { \"manifest\" \"\(installed)\" } } \"WorkshopItemDetails\" { \"\(id)\" { \"manifest\" \"\(detail)\" } } }"
}
