import Foundation

public struct DiscoveryRequest: Sendable {
    public var defaultSteamRoot: URL
    public var explicitLibraryRoots: [URL]
    public var explicitGameDirectory: URL?
    public var generation: Int

    public init(
        defaultSteamRoot: URL, explicitLibraryRoots: [URL] = [], explicitGameDirectory: URL? = nil,
        generation: Int = 1
    ) {
        self.defaultSteamRoot = defaultSteamRoot
        self.explicitLibraryRoots = explicitLibraryRoots
        self.explicitGameDirectory = explicitGameDirectory
        self.generation = generation
    }

    public static func standard(generation: Int = 1) -> DiscoveryRequest {
        DiscoveryRequest(
            defaultSteamRoot: FileManager.default.homeDirectoryForCurrentUser
                .appending(path: "Library/Application Support/Steam"),
            generation: generation)
    }
}

public enum SteamDiscovery {
    private static let maxMetadataBytes = 8 * 1_024 * 1_024

    public static func scan(_ request: DiscoveryRequest) -> DiscoverySnapshot {
        (try? scanCancellable(request))
            ?? emptySnapshot(request.generation, message: "Discovery was canceled.")
    }

    public static func scanCancellable(_ request: DiscoveryRequest) throws -> DiscoverySnapshot {
        try Task.checkCancellation()
        var warnings: [String] = []
        var errors: [String] = []
        let roots = libraryRoots(request: request, warnings: &warnings)
        var candidates: [GameCandidate] = []
        for root in roots {
            try Task.checkCancellation()
            if let candidate = gameCandidate(libraryRoot: root, warnings: &warnings) {
                candidates.append(candidate)
            }
        }
        candidates = deduplicatedCandidates(candidates)

        let explicitCandidate: GameCandidate?
        if let selected = request.explicitGameDirectory?.standardizedFileURL {
            explicitCandidate =
                candidates.first { $0.directory.standardizedFileURL == selected }
                ?? manualCandidate(directory: selected, roots: roots)
        } else {
            explicitCandidate = nil
        }
        let requiresChoice = request.explicitGameDirectory == nil && candidates.count > 1
        let selectedGame = explicitCandidate ?? (candidates.count == 1 ? candidates[0] : nil)
        if candidates.isEmpty { errors.append("No validated Arma 3 installation was found.") }
        if requiresChoice {
            warnings.append("Multiple Arma 3 installations were found. Choose one before Play.")
        }

        var content = try workshopItems(roots: roots, selectedGame: selectedGame, warnings: &warnings)
        if let game = selectedGame {
            content += dlcItems(
                game: game, cacheRoot: request.defaultSteamRoot.appending(path: "appcache/librarycache"))
        }
        content.sort {
            if $0.source != $1.source { return $0.source.rawValue < $1.source.rawValue }
            return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
        return DiscoverySnapshot(
            generation: request.generation,
            installation: SteamInstallation(
                libraryRoots: roots, candidates: candidates, selectedGame: selectedGame,
                requiresExplicitChoice: requiresChoice),
            content: content, warnings: warnings, errors: errors)
    }

    private static func emptySnapshot(_ generation: Int, message: String) -> DiscoverySnapshot {
        DiscoverySnapshot(
            generation: generation,
            installation: SteamInstallation(
                libraryRoots: [], candidates: [], selectedGame: nil, requiresExplicitChoice: false),
            content: [], warnings: [], errors: [message])
    }

    private static func libraryRoots(request: DiscoveryRequest, warnings: inout [String]) -> [URL] {
        let explicit = request.explicitLibraryRoots.map(\.standardizedFileURL)
        let defaultRoot = request.defaultSteamRoot.standardizedFileURL
        var discovered: [URL] = []
        let vdfURL = defaultRoot.appending(path: "steamapps/libraryfolders.vdf")
        if let root = try? readVDF(vdfURL), let libraries = root.first("libraryfolders") {
            for (key, value) in libraries.entries {
                if let path = value.string, Int(key) != nil {
                    discovered.append(URL(filePath: path).standardizedFileURL)
                }
                if let path = value.first("path")?.string {
                    discovered.append(URL(filePath: path).standardizedFileURL)
                }
            }
        } else if FileManager.default.fileExists(atPath: vdfURL.path) {
            warnings.append("Steam's library list could not be read; direct library inspection continues.")
        }
        var seen = Set<String>()
        let fixed = (explicit + [defaultRoot]).filter {
            seen.insert($0.resolvingSymlinksInPath().standardizedFileURL.path).inserted
        }
        let remaining = discovered.map { $0.resolvingSymlinksInPath().standardizedFileURL }
            .sorted { $0.path < $1.path }
            .filter { seen.insert($0.path).inserted }
        return fixed + remaining
    }

    private static func gameCandidate(libraryRoot: URL, warnings: inout [String]) -> GameCandidate? {
        let manifestURL = libraryRoot.appending(path: "steamapps/appmanifest_107410.acf")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return nil }
        do {
            let root = try readVDF(manifestURL)
            guard let state = root.first("AppState"), state.first("appid")?.string == "107410",
                let installDir = state.first("installdir")?.string, isSafeDirectoryName(installDir)
            else { return nil }
            let directory = libraryRoot.appending(path: "steamapps/common/\(installDir)").standardizedFileURL
            guard FileManager.default.fileExists(atPath: directory.path) else { return nil }
            let readiness = gameReadiness(state)
            let bundles = GameMode.allCases.compactMap { validatedBundle(mode: $0, in: directory) }
            return GameCandidate(
                directory: directory, libraryRoot: libraryRoot, manifestURL: manifestURL,
                readiness: readiness.0, status: readiness.1, bundles: bundles)
        } catch {
            warnings.append("A game manifest in \(libraryRoot.lastPathComponent) is malformed.")
            return nil
        }
    }

    private static func manualCandidate(directory: URL, roots: [URL]) -> GameCandidate {
        let matchingRoot = roots.first {
            directory.path.hasPrefix($0.appending(path: "steamapps/common").path + "/")
        }
        let manifestURL = matchingRoot?.appending(path: "steamapps/appmanifest_107410.acf")
        let bundles = GameMode.allCases.compactMap { validatedBundle(mode: $0, in: directory) }
        return GameCandidate(
            directory: directory, libraryRoot: matchingRoot ?? directory.deletingLastPathComponent(),
            manifestURL: manifestURL, readiness: .unknown,
            status:
                "The selected folder is not backed by a matching readable Steam manifest. Select its Steam library.",
            bundles: bundles)
    }

    private static func gameReadiness(_ state: ValveValue) -> (Availability, String) {
        guard let flagText = state.first("StateFlags")?.string, let flags = Int(flagText) else {
            return (.unknown, "The game manifest has no valid installation state.")
        }
        if let update = state.first("UpdateResult")?.string, update != "0" {
            return (.error, "Steam reports a game update error (\(update)).")
        }
        for pair in [("BytesToDownload", "BytesDownloaded"), ("BytesToStage", "BytesStaged")] {
            let total = state.first(pair.0)?.string
            let complete = state.first(pair.1)?.string
            if (total == nil) != (complete == nil) {
                return (.unknown, "Steam progress metadata is incomplete.")
            }
            if let total, let complete {
                guard let totalValue = Int64(total), let completeValue = Int64(complete), totalValue >= 0,
                    completeValue >= 0
                else {
                    return (.unknown, "Steam progress metadata is malformed.")
                }
                if totalValue != completeValue { return (.updating, "Steam is still updating the game.") }
            }
        }
        guard flags == 4 else {
            return (.updating, "Steam reports StateFlags \(flags), not fully installed (4).")
        }
        return (.ready, "Steam reports the game fully installed.")
    }

    private static func validatedBundle(mode: GameMode, in directory: URL) -> GameBundle? {
        let bundleURL = directory.appending(path: mode.bundleName)
        let infoURL = bundleURL.appending(path: "Contents/Info.plist")
        guard let data = try? boundedData(infoURL, maximumBytes: 1_024 * 1_024),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let info = plist as? [String: Any], info["CFBundleIdentifier"] as? String == "com.vpltd.Arma3",
            let executableName = info["CFBundleExecutable"] as? String,
            !executableName.contains("/"), !executableName.contains("\\")
        else { return nil }
        let executable = bundleURL.appending(path: "Contents/MacOS/\(executableName)")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { return nil }
        return GameBundle(mode: mode, url: bundleURL)
    }

    private static func workshopItems(
        roots: [URL], selectedGame: GameCandidate?, warnings: inout [String]
    ) throws -> [ContentItem] {
        var copiesByID: [String: [ContentCopy]] = [:]
        for root in roots {
            try Task.checkCancellation()
            let workshopRoot = root.appending(path: "steamapps/workshop/content/107410")
            let manifestURL = root.appending(path: "steamapps/workshop/appworkshop_107410.acf")
            let manifest = try? readVDF(manifestURL)
            let workshopState = workshopRecords(manifest)
            guard
                let folders = try? FileManager.default.contentsOfDirectory(
                    at: workshopRoot, includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles])
            else { continue }
            for folder in folders where Int(folder.lastPathComponent) != nil {
                try Task.checkCancellation()
                let id = folder.lastPathComponent
                let classification = addonClassification(folder)
                let installedRecord = workshopState.installed[id]
                let detailRecord = workshopState.details[id]
                let availability: Availability
                let status: String
                if !classification.0 {
                    availability = .unsupported
                    status = "No supported top-level addon packages were found."
                } else if manifest == nil || installedRecord == nil || detailRecord == nil {
                    availability = .unknown
                    status =
                        workshopState.hasGlobalPending
                        ? "Steam reports pending Workshop activity without item-specific completion evidence."
                        : "Workshop install metadata is missing or unreadable."
                } else if installedRecord?.first("manifest")?.string == nil
                    || detailRecord?.first("manifest")?.string == nil
                {
                    availability = .unknown
                    status =
                        workshopState.hasGlobalPending
                        ? "Steam reports pending Workshop activity without item-specific completion evidence."
                        : "Workshop item metadata is incomplete."
                } else if installedRecord?.first("manifest")?.string
                    != detailRecord?.first("manifest")?.string
                {
                    availability = .updating
                    status = "Steam's installed and current Workshop manifests do not match."
                } else {
                    availability = .ready
                    status = "Installed in Steam Workshop; \(classification.1) package(s)."
                }
                copiesByID[id, default: []].append(
                    ContentCopy(url: folder, libraryRoot: root, availability: availability, status: status))
            }
        }
        return copiesByID.keys.sorted().map { id in
            let ordered = copiesByID[id]!.sorted {
                copyRank($0, selectedGame: selectedGame, roots: roots)
                    < copyRank($1, selectedGame: selectedGame, roots: roots)
            }
            let selected = ordered[0]
            let duplicate =
                ordered.count > 1
                ? " \(ordered.count) copies found; selected deterministic library precedence." : ""
            return ContentItem(
                id: "workshop:\(id)", displayName: displayName(folder: selected.url, fallback: id),
                source: .workshop,
                resolvedURL: selected.url, availability: selected.availability,
                status: selected.status + duplicate, copies: ordered,
                artworkSource: .modDirectory(selected.url))
        }
    }

    private static func workshopRecords(_ root: ValveValue?) -> (
        installed: [String: ValveValue], details: [String: ValveValue], hasGlobalPending: Bool
    ) {
        guard let root, let appWorkshop = root.first("AppWorkshop") else { return ([:], [:], false) }
        func records(_ section: String) -> [String: ValveValue] {
            var result: [String: ValveValue] = [:]
            var ambiguous = Set<String>()
            for (key, value) in appWorkshop.first(section)?.entries ?? [] where Int(key) != nil {
                if result[key] != nil { ambiguous.insert(key) } else { result[key] = value }
            }
            for key in ambiguous { result.removeValue(forKey: key) }
            return result
        }
        let needsUpdate = appWorkshop.first("NeedsUpdate")?.string
        let needsDownload = appWorkshop.first("NeedsDownload")?.string
        let pending =
            (needsUpdate != nil && needsUpdate != "0") || (needsDownload != nil && needsDownload != "0")
        return (records("WorkshopItemsInstalled"), records("WorkshopItemDetails"), pending)
    }

    private static func copyRank(_ copy: ContentCopy, selectedGame: GameCandidate?, roots: [URL]) -> String {
        if copy.libraryRoot.standardizedFileURL == selectedGame?.libraryRoot.standardizedFileURL {
            return "0"
        }
        let ready = copy.availability == .ready ? "1" : "2"
        let rootIndex = roots.firstIndex(of: copy.libraryRoot) ?? roots.count
        return "\(ready)-\(String(format: "%05d", rootIndex))-\(copy.libraryRoot.path)"
    }

    private static func addonClassification(_ folder: URL) -> (Bool, Int) {
        guard
            let children = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.isDirectoryKey])
        else { return (false, 0) }
        guard
            let addons = children.first(where: {
                $0.lastPathComponent.caseInsensitiveCompare("addons") == .orderedSame
            })
        else { return (false, 0) }
        let packages =
            (try? FileManager.default.contentsOfDirectory(
                at: addons, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey])) ?? []
        let count = packages.filter {
            guard ["pbo", "ebo"].contains($0.pathExtension.lowercased()),
                let values = try? $0.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            else { return false }
            return values.isRegularFile == true && (values.fileSize ?? 0) > 0
        }.count
        return (count > 0, count)
    }

    private static func displayName(folder: URL, fallback: String) -> String {
        for file in ["mod.cpp", "meta.cpp"] {
            let url = folder.appending(path: file)
            guard let data = try? boundedData(url, maximumBytes: 1_024 * 1_024),
                let value = ConfigLiteralParser.fields(in: data)["name"]
            else { continue }
            let clean = value.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
            if !clean.isEmpty { return String(String.UnicodeScalarView(clean)) }
        }
        return fallback
    }

    private static func dlcItems(game: GameCandidate, cacheRoot: URL) -> [ContentItem] {
        let catalog = [
            ("contact", "Contact", "Contact", UInt32(1_021_790)),
            ("gm", "Global Mobilization", "GM", 1_042_220),
            ("vn", "S.O.G. Prairie Fire", "vn", 1_227_700),
            ("csla", "CSLA Iron Curtain", "csla", 1_294_440),
            ("ws", "Western Sahara", "WS", 1_681_170),
            ("spe", "Spearhead 1944", "SPE", 1_175_380),
            ("rf", "Reaction Forces", "RF", 2_647_760),
            ("ef", "Expeditionary Forces", "EF", 2_647_830),
        ]
        let children =
            (try? FileManager.default.contentsOfDirectory(
                at: game.directory, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        let optional = catalog.map { id, name, folderName, appID in
            let folder = children.first {
                $0.lastPathComponent.caseInsensitiveCompare(folderName) == .orderedSame
            }
            let packages = folder.map(addonClassification) ?? (false, 0)
            let ready = game.readiness == .ready && packages.0
            let availability: Availability
            if folder == nil {
                availability = .missing
            } else if game.readiness != .ready {
                availability = game.readiness
            } else {
                availability = packages.0 ? .ready : .unsupported
            }
            return ContentItem(
                id: "dlc:\(id)", displayName: name, source: .optionalDLC, resolvedURL: folder,
                availability: ready ? .ready : availability,
                status: folder == nil
                    ? "Not installed."
                    : packages.0
                        ? "Installed; ownership is not verified. \(packages.1) package(s)."
                        : "Folder found, but no nonempty package files were found; loading is unavailable.",
                artworkSource: .steamApplication(appID: appID, cacheRoot: cacheRoot))
        }
        let platformCatalog: [(String, UInt32)] = [
            ("Karts", 288_520), ("Helicopters", 304_380), ("Marksmen", 332_350),
            ("Apex", 395_180), ("Jets", 601_670), ("Laws of War", 571_710),
            ("Tac-Ops", 744_950), ("Tanks", 798_390),
        ]
        let platform = platformCatalog.map { name, appID in
            ContentItem(
                id: "platform:\(name.lowercased().replacingOccurrences(of: " ", with: "-"))",
                displayName: name, source: .platformDLC, resolvedURL: nil, availability: .unknown,
                status: "Platform content is managed by Steam and the game. Ownership is not verified here.",
                artworkSource: .steamApplication(appID: appID, cacheRoot: cacheRoot))
        }
        return optional + platform
    }

    private static func deduplicatedCandidates(_ candidates: [GameCandidate]) -> [GameCandidate] {
        var seen = Set<String>()
        return candidates.sorted { $0.directory.path < $1.directory.path }.filter {
            seen.insert($0.directory.resolvingSymlinksInPath().path).inserted
        }
    }

    private static func isSafeDirectoryName(_ value: String) -> Bool {
        !value.isEmpty && value != "." && value != ".." && !value.contains("/") && !value.contains("\\")
            && !(value as NSString).isAbsolutePath
    }

    private static func readVDF(_ url: URL) throws -> ValveValue {
        try ValveKeyValues.parse(boundedData(url, maximumBytes: maxMetadataBytes))
    }

    private static func boundedData(_ url: URL, maximumBytes: Int) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values.fileSize, size <= maximumBytes else { throw ValveKeyValuesError.invalidUTF8 }
        return try Data(contentsOf: url, options: [.mappedIfSafe])
    }
}
