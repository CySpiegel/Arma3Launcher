import Foundation

public enum GameMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case standard
    case native

    public var id: String { rawValue }
    public var title: String { self == .native ? "Apple silicon" : "Standard (Rosetta)" }
    public var bundleName: String { self == .native ? "ArmA3 AS Native.app" : "ArmA3.app" }
}

public enum Availability: String, Codable, Sendable {
    case ready
    case updating
    case error
    case unknown
    case missing
    case unsupported

    public var allowsSelection: Bool { self == .ready }
}

public struct GameBundle: Codable, Hashable, Sendable, Identifiable {
    public let mode: GameMode
    public let url: URL
    public var id: URL { url }

    public init(mode: GameMode, url: URL) {
        self.mode = mode
        self.url = url
    }
}

public struct GameCandidate: Codable, Hashable, Sendable, Identifiable {
    public let directory: URL
    public let libraryRoot: URL
    public let manifestURL: URL?
    public let readiness: Availability
    public let status: String
    public let bundles: [GameBundle]
    public var id: URL { directory }

    public init(
        directory: URL,
        libraryRoot: URL,
        manifestURL: URL?,
        readiness: Availability,
        status: String,
        bundles: [GameBundle]
    ) {
        self.directory = directory
        self.libraryRoot = libraryRoot
        self.manifestURL = manifestURL
        self.readiness = readiness
        self.status = status
        self.bundles = bundles
    }
}

public struct SteamInstallation: Codable, Sendable {
    public let libraryRoots: [URL]
    public let candidates: [GameCandidate]
    public let selectedGame: GameCandidate?
    public let requiresExplicitChoice: Bool

    public init(
        libraryRoots: [URL], candidates: [GameCandidate], selectedGame: GameCandidate?,
        requiresExplicitChoice: Bool
    ) {
        self.libraryRoots = libraryRoots
        self.candidates = candidates
        self.selectedGame = selectedGame
        self.requiresExplicitChoice = requiresExplicitChoice
    }
}

public enum ContentSource: String, Codable, Sendable {
    case workshop
    case optionalDLC
    case platformDLC
}

public enum ArtworkSource: Codable, Hashable, Sendable {
    case modDirectory(URL)
    case steamApplication(appID: UInt32, cacheRoot: URL)
}

public struct ContentCopy: Codable, Hashable, Sendable {
    public let url: URL
    public let libraryRoot: URL
    public let availability: Availability
    public let status: String

    public init(url: URL, libraryRoot: URL, availability: Availability, status: String) {
        self.url = url
        self.libraryRoot = libraryRoot
        self.availability = availability
        self.status = status
    }
}

public struct ContentItem: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let source: ContentSource
    public let resolvedURL: URL?
    public let availability: Availability
    public let status: String
    public let copies: [ContentCopy]
    public let artworkSource: ArtworkSource?

    public init(
        id: String, displayName: String, source: ContentSource, resolvedURL: URL?,
        availability: Availability, status: String, copies: [ContentCopy] = [],
        artworkSource: ArtworkSource? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.source = source
        self.resolvedURL = resolvedURL
        self.availability = availability
        self.status = status
        self.copies = copies
        self.artworkSource = artworkSource
    }
}

public struct DiscoverySnapshot: Codable, Sendable {
    public let generation: Int
    public let installation: SteamInstallation
    public let content: [ContentItem]
    public let warnings: [String]
    public let errors: [String]

    public init(
        generation: Int, installation: SteamInstallation, content: [ContentItem],
        warnings: [String], errors: [String]
    ) {
        self.generation = generation
        self.installation = installation
        self.content = content
        self.warnings = warnings
        self.errors = errors
    }
}

public struct LaunchOptions: Codable, Equatable, Sendable {
    public var skipIntro = true
    public var noSplash = true
    public var windowed = false

    public init(skipIntro: Bool = true, noSplash: Bool = true, windowed: Bool = false) {
        self.skipIntro = skipIntro
        self.noSplash = noSplash
        self.windowed = windowed
    }
}

public struct LaunchConfiguration: Codable, Equatable, Sendable {
    public var mode: GameMode
    public var selectedContentIDs: [String]
    public var options: LaunchOptions
    public var advancedArguments: String

    public init(
        mode: GameMode = .native, selectedContentIDs: [String] = [],
        options: LaunchOptions = .init(), advancedArguments: String = ""
    ) {
        self.mode = mode
        self.selectedContentIDs = selectedContentIDs
        self.options = options
        self.advancedArguments = advancedArguments
    }
}

public struct LaunchPlan: Equatable, Sendable {
    public let applicationURL: URL
    public let arguments: [String]
    public let selectedContentIDs: [String]
    public let summary: String
}

public struct Preset: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var configuration: LaunchConfiguration

    public init(id: UUID = UUID(), name: String, configuration: LaunchConfiguration) {
        self.id = id
        self.name = name
        self.configuration = configuration
    }
}
