import Foundation

public struct StoredConfiguration: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public var version: Int
    public var presets: [Preset]
    public var selectedPresetID: UUID?
    public var explicitSteamRoots: [URL]
    public var explicitGameDirectory: URL?
    public var currentConfiguration: LaunchConfiguration

    public init(
        version: Int = currentVersion, presets: [Preset] = [], selectedPresetID: UUID? = nil,
        explicitSteamRoots: [URL] = [], explicitGameDirectory: URL? = nil,
        currentConfiguration: LaunchConfiguration = .init()
    ) {
        self.version = version
        self.presets = presets
        self.selectedPresetID = selectedPresetID
        self.explicitSteamRoots = explicitSteamRoots
        self.explicitGameDirectory = explicitGameDirectory
        self.currentConfiguration = currentConfiguration
    }

    private enum CodingKeys: String, CodingKey {
        case version, presets, selectedPresetID, explicitSteamRoots, explicitGameDirectory
        case currentConfiguration
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        presets = try values.decodeIfPresent([Preset].self, forKey: .presets) ?? []
        selectedPresetID = try values.decodeIfPresent(UUID.self, forKey: .selectedPresetID)
        explicitSteamRoots = try values.decodeIfPresent([URL].self, forKey: .explicitSteamRoots) ?? []
        explicitGameDirectory = try values.decodeIfPresent(URL.self, forKey: .explicitGameDirectory)
        currentConfiguration =
            try values.decodeIfPresent(LaunchConfiguration.self, forKey: .currentConfiguration) ?? .init()
    }
}

public enum ConfigurationStoreError: Error, LocalizedError {
    case unsupportedVersion(Int)
    case malformed(Error)
    case read(Error)
    case write(Error)

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            "Settings version \(version) is not supported. The original file was preserved."
        case .malformed(let error):
            "Settings could not be decoded and were preserved: \(error.localizedDescription)"
        case .read(let error): "Settings could not be read: \(error.localizedDescription)"
        case .write(let error): "Settings could not be saved: \(error.localizedDescription)"
        }
    }
}

public struct ConfigurationStore: Sendable {
    private static let maximumBytes = 1_024 * 1_024
    public let url: URL
    public init(url: URL) { self.url = url }

    public func load() throws -> StoredConfiguration {
        let values: URLResourceValues
        do { values = try url.resourceValues(forKeys: [.fileSizeKey]) } catch {
            throw ConfigurationStoreError.read(error)
        }
        guard let size = values.fileSize, size <= Self.maximumBytes else {
            throw ConfigurationStoreError.read(StoreLimitError.oversized)
        }
        let data: Data
        do { data = try Data(contentsOf: url) } catch { throw ConfigurationStoreError.read(error) }
        let value: StoredConfiguration
        do { value = try JSONDecoder().decode(StoredConfiguration.self, from: data) } catch {
            throw ConfigurationStoreError.malformed(error)
        }
        guard value.version == StoredConfiguration.currentVersion else {
            throw ConfigurationStoreError.unsupportedVersion(value.version)
        }
        return value
    }

    public func save(_ value: StoredConfiguration) throws {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder.pretty.encode(value)
            guard data.count <= Self.maximumBytes else { throw StoreLimitError.oversized }
            try data.write(to: url, options: .atomic)
        } catch { throw ConfigurationStoreError.write(error) }
    }
}

private enum StoreLimitError: Error, LocalizedError {
    case oversized
    var errorDescription: String? { "Settings exceed the 1 MiB safety limit." }
}

extension JSONEncoder {
    fileprivate static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
