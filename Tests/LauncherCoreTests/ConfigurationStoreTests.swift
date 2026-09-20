import Foundation
import Testing

@testable import LauncherCore

@Suite struct ConfigurationStoreTests {
    @Test func roundTripsVersionedPresets() throws {
        try withTemporaryDirectory { directory in
            let store = ConfigurationStore(url: directory.appending(path: "settings.json"))
            let preset = Preset(name: "Co-op", configuration: .init(selectedContentIDs: ["workshop:1"]))
            let value = StoredConfiguration(presets: [preset], selectedPresetID: preset.id)
            try store.save(value)
            #expect(try store.load() == value)
        }
    }

    @Test func malformedFileIsPreserved() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appending(path: "settings.json")
            let original = Data("not json".utf8)
            try original.write(to: url)
            #expect(throws: (any Error).self) { try ConfigurationStore(url: url).load() }
            #expect(try Data(contentsOf: url) == original)
        }
    }

    @Test func futureVersionIsPreserved() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appending(path: "settings.json")
            let original = Data(#"{"version":99,"presets":[],"explicitSteamRoots":[]}"#.utf8)
            try original.write(to: url)
            #expect(throws: ConfigurationStoreError.self) { try ConfigurationStore(url: url).load() }
            #expect(try Data(contentsOf: url) == original)
        }
    }

    @Test func currentConfigurationRoundTripsWithoutPresetAndLegacyFileStillLoads() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appending(path: "settings.json")
            let configuration = LaunchConfiguration(
                mode: .standard, selectedContentIDs: ["workshop:1"],
                options: .init(skipIntro: false, noSplash: true, windowed: true),
                advancedArguments: "-hugePages")
            let store = ConfigurationStore(url: url)
            try store.save(StoredConfiguration(currentConfiguration: configuration))
            #expect(try store.load().currentConfiguration == configuration)
            try Data(#"{"version":1,"presets":[],"explicitSteamRoots":[]}"#.utf8).write(to: url)
            #expect(try store.load().currentConfiguration == .init())
        }
    }

    @Test func oversizedSettingsArePreservedAndWriteErrorsSurface() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appending(path: "settings.json")
            let oversized = Data(repeating: 65, count: 1_024 * 1_024 + 1)
            try oversized.write(to: url)
            #expect(throws: ConfigurationStoreError.self) { try ConfigurationStore(url: url).load() }
            #expect(try Data(contentsOf: url) == oversized)
            let original = Data("preserve me".utf8)
            try original.write(to: url)
            let huge = StoredConfiguration(
                currentConfiguration: .init(advancedArguments: String(repeating: "x", count: 1_024 * 1_024)))
            #expect(throws: ConfigurationStoreError.self) { try ConfigurationStore(url: url).save(huge) }
            #expect(try Data(contentsOf: url) == original)
            #expect(throws: ConfigurationStoreError.self) {
                try ConfigurationStore(url: directory).save(.init())
            }
        }
    }
}

func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(directory)
}
