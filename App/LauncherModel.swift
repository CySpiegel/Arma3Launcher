import AppKit
import Foundation
import ImageIO
import LauncherCore
import Observation
import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case all = "All content"
    case workshop = "Workshop addons"
    case dlc = "DLC & expansions"
    case settings = "Settings"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .all: "square.stack.3d.up"
        case .workshop: "puzzlepiece.extension"
        case .dlc: "shippingbox"
        case .settings: "gearshape"
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    var id: String { rawValue }
}

enum HandoffState: Equatable {
    case idle
    case validating
    case handingOff
    case handedOff(String)
    case failed(String)
}

typealias ScanOperation = @Sendable (DiscoveryRequest) async throws -> DiscoverySnapshot
typealias LaunchOperation = @MainActor @Sendable (LaunchPlan) async throws -> String
typealias ThumbnailOperation = @Sendable (ArtworkSource) async throws -> DecodedThumbnail?
typealias SaveOperation = @Sendable (StoredConfiguration) throws -> Void

enum ArtworkCanvas: Sendable { case light, dark }

struct DecodedThumbnail: @unchecked Sendable {
    let image: CGImage
    let canvas: ArtworkCanvas
}

struct PresentedArtwork {
    let image: NSImage
    let canvas: ArtworkCanvas
}

@MainActor @Observable
final class LauncherModel {
    var snapshot: DiscoverySnapshot?
    var configuration = LaunchConfiguration()
    var selectedSection: SidebarSection = .all
    var selectedItemID: String?
    var search = ""
    var isScanning = false
    var handoffState: HandoffState = .idle
    var presets: [Preset] = []
    var selectedPresetID: UUID?
    var explicitSteamRoots: [URL] = []
    var explicitGameDirectory: URL?
    var persistenceError: String?
    var artwork: [String: PresentedArtwork] = [:]
    var appearance: AppAppearance = .system {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appearance") }
    }

    private var generation = 0
    private var scanTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var storeLocked = false
    private var refreshPending = false
    private var lastSavedConfiguration: StoredConfiguration?
    private let store: ConfigurationStore
    private let saveOperation: SaveOperation
    private let scanOperation: ScanOperation
    private let launchOperation: LaunchOperation
    private let thumbnailOperation: ThumbnailOperation

    init(
        store: ConfigurationStore? = nil,
        scanOperation: @escaping ScanOperation = { try SteamDiscovery.scanCancellable($0) },
        launchOperation: @escaping LaunchOperation = NativeLauncher.launch,
        thumbnailOperation: @escaping ThumbnailOperation = {
            try ArtworkReadService.shared.loadThumbnail(from: $0)
        }, saveOperation: SaveOperation? = nil
    ) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Arma3Launcher/settings.json")
        let resolvedStore = store ?? ConfigurationStore(url: support)
        self.store = resolvedStore
        self.saveOperation = saveOperation ?? { try resolvedStore.save($0) }
        self.scanOperation = scanOperation
        self.launchOperation = launchOperation
        self.thumbnailOperation = thumbnailOperation
        appearance =
            AppAppearance(rawValue: UserDefaults.standard.string(forKey: "appearance") ?? "") ?? .system
    }

    func start() {
        loadSettings()
        refresh()
    }

    func refresh() {
        guard !handoffBusy else {
            refreshPending = true
            return
        }
        beginScan(launchConfiguration: nil)
    }

    func refreshIfIdle() {
        guard !isScanning else { return }
        refresh()
    }

    private func beginScan(launchConfiguration: LaunchConfiguration?) {
        generation += 1
        let requestedGeneration = generation
        scanTask?.cancel()
        artworkTask?.cancel()
        artwork = [:]
        isScanning = true
        let request = DiscoveryRequest.standard(generation: requestedGeneration)
        let configured = DiscoveryRequest(
            defaultSteamRoot: request.defaultSteamRoot, explicitLibraryRoots: explicitSteamRoots,
            explicitGameDirectory: explicitGameDirectory, generation: requestedGeneration)
        let scanOperation = scanOperation
        let child = Task.detached { try await scanOperation(configured) }
        scanTask = Task { [weak self] in
            do {
                let result = try await withTaskCancellationHandler {
                    try await child.value
                } onCancel: {
                    child.cancel()
                }
                guard let self, !Task.isCancelled, requestedGeneration == self.generation else { return }
                self.snapshot = result
                self.isScanning = false
                self.loadArtwork(for: result, generation: requestedGeneration)
                if let launchConfiguration {
                    let plan = try LaunchPlanner.makePlan(
                        snapshot: result, configuration: launchConfiguration)
                    guard requestedGeneration == self.generation, !Task.isCancelled else { return }
                    self.handoffState = .handingOff
                    let message = try await self.launchOperation(plan)
                    guard requestedGeneration == self.generation, !Task.isCancelled else { return }
                    self.handoffState = .handedOff(message)
                    self.runPendingRefresh()
                }
            } catch is CancellationError {
                guard let self, requestedGeneration == self.generation else { return }
                self.isScanning = false
                if launchConfiguration != nil {
                    self.handoffState = .idle
                    self.runPendingRefresh()
                }
            } catch {
                guard let self, requestedGeneration == self.generation else { return }
                self.isScanning = false
                if launchConfiguration != nil {
                    self.handoffState = .failed(error.localizedDescription)
                    self.runPendingRefresh()
                }
            }
        }
    }

    func toggle(_ item: ContentItem) {
        guard item.availability.allowsSelection else { return }
        if let index = configuration.selectedContentIDs.firstIndex(of: item.id) {
            configuration.selectedContentIDs.remove(at: index)
        } else {
            configuration.selectedContentIDs.append(item.id)
        }
        saveCurrentConfiguration()
    }

    func createPreset() {
        let preset = Preset(name: "New preset", configuration: configuration)
        presets.append(preset)
        selectedPresetID = preset.id
        persist()
    }

    func selectPreset(_ id: UUID) {
        guard let preset = presets.first(where: { $0.id == id }) else { return }
        selectedPresetID = id
        configuration = preset.configuration
        persist()
    }

    func renameSelectedPreset(_ name: String) {
        guard let id = selectedPresetID, let index = presets.firstIndex(where: { $0.id == id }) else {
            return
        }
        presets[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Preset" : name
        persist()
    }

    func deleteSelectedPreset() {
        guard let id = selectedPresetID else { return }
        presets.removeAll { $0.id == id }
        selectedPresetID = nil
        persist()
    }

    func chooseGameFolder() {
        guard let url = chooseDirectory(message: "Choose the folder containing the Arma 3 app bundles") else {
            return
        }
        explicitGameDirectory = url
        persist()
        refresh()
    }

    func addSteamLibrary() {
        guard let url = chooseDirectory(message: "Choose a Steam library root") else { return }
        if !explicitSteamRoots.contains(url) { explicitSteamRoots.append(url) }
        persist()
        refresh()
    }

    func resetUnreadableSettings() {
        storeLocked = false
        persistenceError = nil
        presets = []
        selectedPresetID = nil
        explicitSteamRoots = []
        explicitGameDirectory = nil
        persist()
        refresh()
    }

    func play() {
        guard handoffState == .idle || failureOrSuccess else { return }
        handoffState = .validating
        beginScan(launchConfiguration: configuration)
    }

    func openSteam() {
        NSWorkspace.shared.openApplication(
            at: URL(filePath: "/Applications/Steam.app"), configuration: .init())
    }
    func clearHandoff() { handoffState = .idle }

    var filteredContent: [ContentItem] {
        guard let content = snapshot?.content else { return [] }
        return content.filter { item in
            let sectionMatch =
                selectedSection == .all
                || (selectedSection == .workshop && item.source == .workshop)
                || (selectedSection == .dlc && item.source != .workshop)
            return sectionMatch
                && (search.isEmpty || item.displayName.localizedCaseInsensitiveContains(search))
        }
    }

    var selectedPresetName: String {
        presets.first(where: { $0.id == selectedPresetID })?.name ?? "Current configuration"
    }

    var planPreview: String {
        guard let snapshot else {
            return "Discovery has not completed."
        }
        do {
            return try LaunchPlanner.makePlan(snapshot: snapshot, configuration: configuration).arguments
                .joined(separator: "\n")
        } catch { return error.localizedDescription }
    }

    var steamRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.valvesoftware.steam" }
    }

    private var failureOrSuccess: Bool {
        if case .failed = handoffState { return true }
        if case .handedOff = handoffState { return true }
        return false
    }

    var handoffBusy: Bool {
        handoffState == .validating || handoffState == .handingOff
    }

    private func runPendingRefresh() {
        guard refreshPending else { return }
        refreshPending = false
        beginScan(launchConfiguration: nil)
    }

    private func loadSettings() {
        guard FileManager.default.fileExists(atPath: store.url.path) else { return }
        do {
            let value = try store.load()
            lastSavedConfiguration = value
            presets = value.presets
            selectedPresetID = value.selectedPresetID
            explicitSteamRoots = value.explicitSteamRoots
            explicitGameDirectory = value.explicitGameDirectory
            if let selectedPresetID, let preset = presets.first(where: { $0.id == selectedPresetID }) {
                configuration = preset.configuration
            } else {
                configuration = value.currentConfiguration
            }
        } catch {
            storeLocked = true
            persistenceError = error.localizedDescription
        }
    }

    private func saveCurrentConfiguration() {
        if let id = selectedPresetID, let index = presets.firstIndex(where: { $0.id == id }) {
            presets[index].configuration = configuration
        }
        persist()
    }

    func persist() {
        guard !storeLocked else { return }
        if let id = selectedPresetID, let index = presets.firstIndex(where: { $0.id == id }) {
            presets[index].configuration = configuration
        }
        let value = StoredConfiguration(
            presets: presets, selectedPresetID: selectedPresetID,
            explicitSteamRoots: explicitSteamRoots, explicitGameDirectory: explicitGameDirectory,
            currentConfiguration: configuration)
        guard value != lastSavedConfiguration else { return }
        do {
            try saveOperation(value)
            lastSavedConfiguration = value
            persistenceError = nil
        } catch { persistenceError = error.localizedDescription }
    }

    private func chooseDirectory(message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.message = message
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url?.standardizedFileURL : nil
    }

    private func loadArtwork(for snapshot: DiscoverySnapshot, generation requestedGeneration: Int) {
        let items = Array(
            snapshot.content.filter { $0.artworkSource != nil }.prefix(128))
        let thumbnailOperation = thumbnailOperation
        artworkTask = Task { [weak self] in
            for item in items {
                guard !Task.isCancelled, let source = item.artworkSource else { return }
                let thumbnail = try? await thumbnailOperation(source)
                guard let self, !Task.isCancelled, requestedGeneration == self.generation,
                    self.snapshot?.content.first(where: { $0.id == item.id })?.artworkSource == source,
                    let thumbnail
                else { continue }
                self.artwork[item.id] = PresentedArtwork(
                    image: NSImage(
                        cgImage: thumbnail.image,
                        size: NSSize(width: thumbnail.image.width, height: thumbnail.image.height)),
                    canvas: thumbnail.canvas)
            }
        }
    }
}

actor ArtworkReadService {
    static let shared = ArtworkReadService()
    private let loader: @Sendable (ArtworkSource) throws -> ArtworkPayload?

    init(loader: @escaping @Sendable (ArtworkSource) throws -> ArtworkPayload? = ArtworkLoader.load) {
        self.loader = loader
    }

    func loadThumbnail(from source: ArtworkSource) throws -> DecodedThumbnail? {
        try Task.checkCancellation()
        guard let payload = try loader(source) else { return nil }
        try Task.checkCancellation()
        return ImageThumbnailDecoder.thumbnail(from: payload)
    }
}

enum ImageThumbnailDecoder {
    nonisolated static func thumbnail(from payload: ArtworkPayload) -> DecodedThumbnail? {
        let image: CGImage?
        switch payload {
        case .encoded(let data): image = ordinary(data)
        case .rgba(let width, let height, let pixels):
            image =
                if pixels.count == width * height * 4,
                    let provider = CGDataProvider(data: pixels as CFData),
                    let image = CGImage(
                        width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                        provider: provider,
                        decode: nil, shouldInterpolate: true, intent: .defaultIntent)
                { image } else { nil }
        }
        guard let image, let pixels = rgbaPixels(from: image) else { return nil }
        let canvas = ArtworkContrast.canvas(width: image.width, height: image.height, pixels: pixels)
        return DecodedThumbnail(image: image, canvas: canvas == .light ? .light : .dark)
    }

    nonisolated private static func ordinary(_ data: Data) -> CGImage? {
        guard data.count <= ArtworkLoader.maximumSourceBytes,
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            OrdinaryImageBounds.accepts(width: width, height: height)
        else { return nil }
        let options =
            [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 128,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    nonisolated private static func rgbaPixels(from image: CGImage) -> Data? {
        var pixels = Data(count: image.width * image.height * 4)
        let rendered = pixels.withUnsafeMutableBytes { bytes in
            guard let address = bytes.baseAddress,
                let context = CGContext(
                    data: address, width: image.width, height: image.height, bitsPerComponent: 8,
                    bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        return rendered ? pixels : nil
    }
}

enum NativeLauncher {
    @MainActor static func launch(_ plan: LaunchPlan) async throws -> String {
        guard
            NSWorkspace.shared.runningApplications.contains(where: {
                $0.bundleIdentifier == "com.valvesoftware.steam"
            })
        else {
            throw LauncherNativeError.steamNotRunning
        }
        let games = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == "com.vpltd.Arma3" || $0.bundleURL == plan.applicationURL
        }
        guard games.isEmpty else { throw LauncherNativeError.gameAlreadyRunning }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = plan.arguments
        configuration.allowsRunningApplicationSubstitution = false
        configuration.createsNewApplicationInstance = false
        let application = try await NSWorkspace.shared.openApplication(
            at: plan.applicationURL, configuration: configuration)
        guard application.bundleURL?.standardizedFileURL == plan.applicationURL.standardizedFileURL else {
            throw LauncherNativeError.bundleMismatch
        }
        return
            "LaunchServices handed the configuration to \(plan.applicationURL.lastPathComponent). Game content loading is not yet verified."
    }
}

enum LauncherNativeError: Error, LocalizedError {
    case steamNotRunning
    case gameAlreadyRunning
    case bundleMismatch
    var errorDescription: String? {
        switch self {
        case .steamNotRunning: "Steam is not running. Open Steam, sign in, then try again."
        case .gameAlreadyRunning: "Arma 3 is already running. Close it before applying a new configuration."
        case .bundleMismatch: "LaunchServices returned a different game bundle. No launch success is claimed."
        }
    }
}
