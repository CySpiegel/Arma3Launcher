import Foundation

public enum LaunchPlanError: Error, Equatable, LocalizedError {
    case installationNotReady(String)
    case modeUnavailable(GameMode)
    case missingContent(String)
    case unavailableContent(String)
    case unsafePath(String)
    case conflictingArgument(String)
    case invalidArgument(String)

    public var errorDescription: String? {
        switch self {
        case .installationNotReady(let message): message
        case .modeUnavailable(let mode): "The \(mode.title) game bundle is unavailable."
        case .missingContent(let id): "Selected content \(id) is missing."
        case .unavailableContent(let name): "\(name) is not ready to load."
        case .unsafePath(let path): "A selected path cannot be represented safely: \(path)"
        case .conflictingArgument(let argument):
            "Advanced argument conflicts with a managed option: \(argument)"
        case .invalidArgument(let argument): "Advanced argument is invalid: \(argument)"
        }
    }
}

public enum LaunchPlanner {
    private static let reserved = [
        "-mod", "-servermod", "-p", "-no-remote", "-par", "-skipintro", "-nosplash", "-window",
    ]

    public static func makePlan(
        snapshot: DiscoverySnapshot, configuration: LaunchConfiguration
    ) throws -> LaunchPlan {
        guard !snapshot.installation.requiresExplicitChoice,
            let game = snapshot.installation.selectedGame
        else { throw LaunchPlanError.installationNotReady("Choose a detected Arma 3 installation.") }
        guard game.readiness == .ready else { throw LaunchPlanError.installationNotReady(game.status) }
        guard let bundle = game.bundles.first(where: { $0.mode == configuration.mode }) else {
            throw LaunchPlanError.modeUnavailable(configuration.mode)
        }

        var seen = Set<String>()
        let ids = configuration.selectedContentIDs.filter { seen.insert($0).inserted }
        let byID = Dictionary(uniqueKeysWithValues: snapshot.content.map { ($0.id, $0) })
        let items = try ids.map { id -> ContentItem in
            guard let item = byID[id] else { throw LaunchPlanError.missingContent(id) }
            guard item.availability == .ready, item.resolvedURL != nil else {
                throw LaunchPlanError.unavailableContent(item.displayName)
            }
            return item
        }
        let paths = try items.compactMap(\.resolvedURL).map { url in
            let path = url.path(percentEncoded: false)
            guard !path.contains(";"), !path.contains("\n"), !path.contains("\r"),
                !path.contains("\0"), !path.contains("\"")
            else { throw LaunchPlanError.unsafePath(path) }
            return "C:\(path)"
        }

        var arguments = ["-p", "default", "-no-remote"]
        if !paths.isEmpty { arguments.append("-mod=\(paths.joined(separator: ";"))") }
        if configuration.options.skipIntro { arguments.append("-skipIntro") }
        if configuration.options.noSplash { arguments.append("-noSplash") }
        if configuration.options.windowed { arguments.append("-window") }
        arguments += try advancedArguments(configuration.advancedArguments)
        let summary =
            "\(configuration.mode.title) · \(items.count) selected item\(items.count == 1 ? "" : "s")"
        return LaunchPlan(
            applicationURL: bundle.url, arguments: arguments, selectedContentIDs: ids, summary: summary)
    }

    public static func advancedArguments(_ text: String) throws -> [String] {
        try text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).compactMap { line in
            let value = line.trimmingCharacters(in: .whitespaces)
            if value.isEmpty { return nil }
            guard !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
            else {
                throw LaunchPlanError.invalidArgument(value)
            }
            let name = String(value.prefix { $0 != "=" }).lowercased()
            guard !reserved.contains(name) else { throw LaunchPlanError.conflictingArgument(value) }
            return value
        }
    }
}
