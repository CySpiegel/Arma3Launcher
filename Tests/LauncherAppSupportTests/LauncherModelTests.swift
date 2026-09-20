import AppKit
import Foundation
import LauncherCore
import Testing

@testable import LauncherAppSupport

@Suite(.serialized) @MainActor struct LauncherModelTests {
    @Test func reorderedScansPublishOnlyNewestGeneration() async throws {
        let scans = ScanHarness()
        let model = testModel(scans: scans)
        model.refresh()
        model.refresh()
        await scans.waitForCount(2)
        await scans.finish(generation: 2, snapshot: snapshot(generation: 2))
        await eventually { model.snapshot?.generation == 2 }
        await scans.finish(generation: 1, snapshot: snapshot(generation: 1))
        await Task.yield()
        #expect(model.snapshot?.generation == 2)
    }

    @Test func refreshWaitsUntilExternalHandoffCompletes() async throws {
        let scans = ScanHarness()
        let launches = LaunchHarness()
        let model = testModel(scans: scans, launch: { try await launches.launch($0) })
        model.refresh()
        await scans.waitForCount(1)
        await scans.finish(generation: 1, snapshot: snapshot(generation: 1, readyGame: true))
        await eventually { model.snapshot?.generation == 1 }
        model.play()
        await scans.waitForCount(2)
        await scans.finish(generation: 2, snapshot: snapshot(generation: 2, readyGame: true))
        await launches.waitUntilStarted()
        #expect(model.handoffState == .handingOff)
        model.refresh()
        #expect(await scans.count == 2)
        await launches.finish("handed off")
        await scans.waitForCount(3)
        #expect(model.handoffState == .handedOff("handed off"))
    }

    @Test func playHandsOffCompleteQuotedStandardPlanAfterFreshDiscovery() async throws {
        let scans = ScanHarness()
        let launches = LaunchHarness()
        let model = testModel(scans: scans, launch: { try await launches.launch($0) })
        let ace = URL(
            filePath:
                "/Users/player/Library/Application Support/Steam/steamapps/workshop/content/107410/463939057/"
        )
        let cba = URL(
            filePath:
                "/Users/player/Library/Application Support/Steam/steamapps/workshop/content/107410/450814997/"
        )
        model.configuration = LaunchConfiguration(
            mode: .standard, selectedContentIDs: ["workshop:ace", "workshop:cba"],
            options: .init(skipIntro: true, noSplash: true, windowed: false))
        model.play()
        await scans.waitForCount(1)
        await scans.finish(
            generation: 1,
            snapshot: snapshot(
                generation: 1, readyGame: true,
                items: [item("ace", ace), item("cba", cba)]))
        await launches.waitUntilStarted()
        let plan = try #require(await launches.plan)
        #expect(plan.applicationURL == URL(filePath: "/tmp/game/standard.app"))
        #expect(plan.selectedContentIDs == ["workshop:ace", "workshop:cba"])
        #expect(
            plan.arguments == [
                "-p", "default", "-no-remote",
                "-mod=\"C:/Users/player/Library/Application Support/Steam/steamapps/workshop/content/107410/463939057/;C:/Users/player/Library/Application Support/Steam/steamapps/workshop/content/107410/450814997/\"",
                "-skipIntro", "-noSplash",
            ])
        await launches.finish("handed off")
        await eventually { model.handoffState == .handedOff("handed off") }
    }

    @Test func presetAndCurrentConfigurationPersistAcrossModelRelaunch() async throws {
        try await withTemporaryDirectoryAsync { directory in
            let store = ConfigurationStore(url: directory.appending(path: "settings.json"))
            let scans = ScanHarness()
            let first = testModel(store: store, scans: scans)
            first.configuration = .init(
                mode: .standard, selectedContentIDs: ["workshop:missing"],
                options: .init(skipIntro: false, noSplash: false, windowed: true),
                advancedArguments: "-world=empty")
            first.persist()
            first.createPreset()
            first.configuration.advancedArguments = "-world=Stratis"
            first.persist()

            let secondScans = ScanHarness()
            let second = testModel(store: store, scans: secondScans)
            second.start()
            await secondScans.waitForCount(1)
            await secondScans.finish(generation: 1, snapshot: snapshot(generation: 1, readyGame: true))
            await eventually { second.snapshot != nil }
            #expect(second.presets.count == 1)
            #expect(second.configuration.advancedArguments == "-world=Stratis")
            #expect(second.configuration.selectedContentIDs == ["workshop:missing"])
            #expect(second.planPreview.contains("workshop:missing"))
        }
    }

    @Test func persistenceWriteFailureSurfacesOnActualModel() throws {
        try withTemporaryDirectory { directory in
            let model = LauncherModel(
                store: ConfigurationStore(url: directory),
                scanOperation: { snapshot(generation: $0.generation) },
                launchOperation: { _ in "unused" }, thumbnailOperation: { _ in nil })
            model.persist()
            #expect(model.persistenceError != nil)
        }
    }

    @Test func staleSameIDArtworkCannotPublishAndCacheStopsAt128() async throws {
        let scans = ScanHarness()
        let artwork = ArtworkHarness()
        let model = testModel(scans: scans, thumbnail: { try await artwork.load($0) })
        let old = URL(filePath: "/tmp/old")
        let new = URL(filePath: "/tmp/new")
        model.refresh()
        await scans.waitForCount(1)
        await scans.finish(generation: 1, snapshot: snapshot(generation: 1, items: [item("same", old)]))
        await artwork.waitForPath(old)
        model.refresh()
        await scans.waitForCount(2)
        let many = (0..<140).map { item("id\($0)", URL(filePath: "/tmp/item\($0)")) }
        await scans.finish(
            generation: 2, snapshot: snapshot(generation: 2, items: [item("same", new)] + many))
        await artwork.finish(path: old, thumbnail: thumbnail(red: 255))
        await artwork.waitForPath(new)
        await artwork.finish(path: new, thumbnail: thumbnail(red: 0))
        await artwork.enableImmediate(thumbnail(red: 128))
        await eventually { model.artwork.count == 128 }
        #expect(model.artwork["workshop:same"] != nil)
        #expect(model.artwork.count == 128)
    }

    @Test func artworkReaderIsGloballySerialAcrossConcurrentRequests() async throws {
        let meter = ConcurrencyMeter()
        let payload = ArtworkPayload.rgba(
            width: 1, height: 1, pixels: Data([UInt8(255), UInt8(255), UInt8(255), UInt8(255)]))
        let reader = ArtworkReadService { _ in
            meter.enter()
            Thread.sleep(forTimeInterval: 0.02)
            meter.leave()
            return payload
        }
        async let first = reader.loadThumbnail(from: .modDirectory(URL(filePath: "/tmp/one")))
        async let second = reader.loadThumbnail(from: .modDirectory(URL(filePath: "/tmp/two")))
        _ = try await (first, second)
        #expect(meter.maximum == 1)
    }

    @Test func sameIDChangedArtworkDescriptorCannotPublishStaleThumbnail() async throws {
        let scans = ScanHarness()
        let artwork = ArtworkHarness()
        let model = testModel(scans: scans, thumbnail: { try await artwork.load($0) })
        let cache = URL(filePath: "/tmp/cache")
        let old = ArtworkSource.steamApplication(appID: 1, cacheRoot: cache)
        let new = ArtworkSource.steamApplication(appID: 2, cacheRoot: cache)
        model.refresh()
        await scans.waitForCount(1)
        await scans.finish(
            generation: 1, snapshot: snapshot(generation: 1, items: [artItem("same", old)]))
        await artwork.wait(for: old)
        model.refresh()
        await scans.waitForCount(2)
        await scans.finish(
            generation: 2, snapshot: snapshot(generation: 2, items: [artItem("same", new)]))
        await artwork.finish(source: old, thumbnail: thumbnail(red: 255))
        await artwork.wait(for: new)
        #expect(model.artwork["workshop:same"] == nil)
        await artwork.finish(source: new, thumbnail: thumbnail(red: 0))
        await eventually { model.artwork["workshop:same"] != nil }
    }

    @Test func corruptEncodedArtworkFallsBackQuietly() async throws {
        let reader = ArtworkReadService { _ in .encoded(Data("not an image".utf8)) }
        let result = try await reader.loadThumbnail(
            from: .steamApplication(appID: 1, cacheRoot: URL(filePath: "/tmp/cache")))
        #expect(result == nil)
    }

    @Test func sharedReaderDecodesBothArtworkDescriptorKinds() async throws {
        let payload = ArtworkPayload.rgba(
            width: 1, height: 1, pixels: Data([UInt8(1), 2, 3, 255]))
        let reader = ArtworkReadService { _ in payload }
        #expect(
            try await reader.loadThumbnail(from: .modDirectory(URL(filePath: "/tmp/mod"))) != nil)
        #expect(
            try await reader.loadThumbnail(
                from: .steamApplication(appID: 1, cacheRoot: URL(filePath: "/tmp/cache"))) != nil)
    }

    @Test func duplicateSuccessfulPersistenceIsSuppressedAndToggleIsImmediate() throws {
        let saves = SaveMeter()
        let scans = ScanHarness()
        let model = LauncherModel(
            store: ConfigurationStore(url: URL(filePath: "/tmp/unused-settings")),
            scanOperation: { try await scans.scan($0) }, launchOperation: { _ in "unused" },
            thumbnailOperation: { _ in nil }, saveOperation: saves.save)
        let selectable = ContentItem(
            id: "workshop:test", displayName: "Test", source: .workshop,
            resolvedURL: URL(filePath: "/tmp/test"), availability: .ready, status: "ready")
        let clock = ContinuousClock()
        let elapsed = clock.measure { model.toggle(selectable) }
        model.persist()
        model.persist()
        #expect(saves.count == 1)
        #expect(model.configuration.selectedContentIDs == ["workshop:test"])
        #expect(elapsed < .seconds(1))
    }

    @Test func failedIdenticalPersistenceRetriesUntilSuccess() {
        let saves = SaveMeter(failures: 1)
        let scans = ScanHarness()
        let model = LauncherModel(
            store: ConfigurationStore(url: URL(filePath: "/tmp/unused-settings")),
            scanOperation: { try await scans.scan($0) }, launchOperation: { _ in "unused" },
            thumbnailOperation: { _ in nil }, saveOperation: saves.save)
        model.persist()
        #expect(model.persistenceError != nil)
        model.persist()
        #expect(model.persistenceError == nil)
        model.persist()
        #expect(saves.count == 2)
    }

    @Test func thumbnailDecoderAcceptsPNGAndJPEGAndRejectsOversizedDimensions() throws {
        let png = try #require(encodedImage(width: 2, height: 1, format: .png))
        let jpeg = try #require(encodedImage(width: 2, height: 1, format: .jpeg))
        let pngThumbnail = try #require(ImageThumbnailDecoder.thumbnail(from: .encoded(png)))
        let jpegThumbnail = try #require(ImageThumbnailDecoder.thumbnail(from: .encoded(jpeg)))
        #expect(pngThumbnail.image.width == 2 && pngThumbnail.image.height == 1)
        #expect(jpegThumbnail.image.width == 2 && jpegThumbnail.image.height == 1)

        let oversized = try #require(
            encodedImage(width: OrdinaryImageBounds.maximumDimension + 1, height: 1, format: .png))
        #expect(ImageThumbnailDecoder.thumbnail(from: .encoded(oversized)) == nil)
        #expect(
            ImageThumbnailDecoder.thumbnail(
                from: .encoded(Data(repeating: 0, count: ArtworkLoader.maximumSourceBytes + 1))) == nil)
    }

    @Test func rgbaThumbnailRetainsStraightAlphaBytes() throws {
        let source = Data([UInt8(200), 100, 50, 128])
        let thumbnail = try #require(
            ImageThumbnailDecoder.thumbnail(from: .rgba(width: 1, height: 1, pixels: source)))
        #expect(thumbnail.image.alphaInfo == .last)
        let provider = try #require(thumbnail.image.dataProvider?.data)
        #expect((provider as Data).prefix(4) == source)
    }
}

private func encodedImage(
    width: Int, height: Int, format: NSBitmapImageRep.FileType
) -> Data? {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4, bitsPerPixel: 32)
    else { return nil }
    return bitmap.representation(using: format, properties: [:])
}

private actor ScanHarness {
    private var continuations: [Int: CheckedContinuation<DiscoverySnapshot, Error>] = [:]
    private(set) var count = 0

    func scan(_ request: DiscoveryRequest) async throws -> DiscoverySnapshot {
        count += 1
        return try await withCheckedThrowingContinuation { continuations[request.generation] = $0 }
    }

    func finish(generation: Int, snapshot: DiscoverySnapshot) {
        continuations.removeValue(forKey: generation)?.resume(returning: snapshot)
    }

    func waitForCount(_ expected: Int) async {
        while count < expected { await Task.yield() }
    }
}

private actor LaunchHarness {
    private var continuation: CheckedContinuation<String, Error>?
    private var started = false
    private(set) var plan: LaunchPlan?
    func launch(_ plan: LaunchPlan) async throws -> String {
        self.plan = plan
        started = true
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func waitUntilStarted() async { while !started { await Task.yield() } }
    func finish(_ value: String) { continuation?.resume(returning: value) }
}

private actor ArtworkHarness {
    private var continuations: [ArtworkSource: CheckedContinuation<DecodedThumbnail?, Error>] = [:]
    private var immediate: DecodedThumbnail?
    func load(_ source: ArtworkSource) async throws -> DecodedThumbnail? {
        if let immediate { return immediate }
        return try await withCheckedThrowingContinuation { continuations[source] = $0 }
    }
    func waitForPath(_ path: URL) async {
        while continuations[.modDirectory(path)] == nil { await Task.yield() }
    }
    func finish(path: URL, thumbnail: DecodedThumbnail?) {
        continuations.removeValue(forKey: .modDirectory(path))?.resume(returning: thumbnail)
    }
    func wait(for source: ArtworkSource) async {
        while continuations[source] == nil { await Task.yield() }
    }
    func finish(source: ArtworkSource, thumbnail: DecodedThumbnail?) {
        continuations.removeValue(forKey: source)?.resume(returning: thumbnail)
    }
    func enableImmediate(_ value: DecodedThumbnail) {
        immediate = value
        for continuation in continuations.values { continuation.resume(returning: value) }
        continuations.removeAll()
    }
}

private final class ConcurrencyMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var current = 0
    private(set) var maximum = 0
    func enter() {
        lock.withLock {
            current += 1
            maximum = max(maximum, current)
        }
    }
    func leave() { lock.withLock { current -= 1 } }
}

private final class SaveMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var remainingFailures: Int
    private var storage = 0
    var count: Int { lock.withLock { storage } }
    init(failures: Int = 0) { remainingFailures = failures }
    func save(_: StoredConfiguration) throws {
        try lock.withLock {
            storage += 1
            if remainingFailures > 0 {
                remainingFailures -= 1
                throw SaveFailure.expected
            }
        }
    }
    private enum SaveFailure: Error { case expected }
}

@MainActor private func testModel(
    store: ConfigurationStore = ConfigurationStore(
        url: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)),
    scans: ScanHarness, launch: @escaping LaunchOperation = { _ in "unused" },
    thumbnail: @escaping ThumbnailOperation = { _ in nil }
) -> LauncherModel {
    LauncherModel(
        store: store, scanOperation: { try await scans.scan($0) }, launchOperation: launch,
        thumbnailOperation: thumbnail)
}

private func snapshot(
    generation: Int, readyGame: Bool = false, items: [ContentItem] = []
) -> DiscoverySnapshot {
    let root = URL(filePath: "/tmp/game")
    let game = GameCandidate(
        directory: root, libraryRoot: root, manifestURL: root.appending(path: "manifest"),
        readiness: readyGame ? .ready : .unknown, status: readyGame ? "ready" : "unknown",
        bundles: readyGame
            ? [
                GameBundle(mode: .native, url: root.appending(path: "native.app")),
                GameBundle(mode: .standard, url: root.appending(path: "standard.app")),
            ] : [])
    return DiscoverySnapshot(
        generation: generation,
        installation: .init(
            libraryRoots: [root], candidates: [game], selectedGame: game, requiresExplicitChoice: false),
        content: items, warnings: [], errors: [])
}

private func item(_ id: String, _ path: URL) -> ContentItem {
    ContentItem(
        id: "workshop:\(id)", displayName: id, source: .workshop, resolvedURL: path,
        availability: .ready, status: "ready", artworkSource: .modDirectory(path))
}

private func artItem(_ id: String, _ source: ArtworkSource) -> ContentItem {
    ContentItem(
        id: "workshop:\(id)", displayName: id, source: .platformDLC, resolvedURL: nil,
        availability: .unknown, status: "managed", artworkSource: source)
}

private func thumbnail(red: UInt8) -> DecodedThumbnail {
    let data = Data([red, UInt8(0), UInt8(0), UInt8(255)])
    let provider = CGDataProvider(data: data as CFData)!
    let image = CGImage(
        width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
        decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    return DecodedThumbnail(image: image, canvas: .light)
}

@MainActor private func eventually(_ predicate: @escaping @MainActor () -> Bool) async {
    for _ in 0..<10_000 {
        if predicate() { return }
        await Task.yield()
    }
    Issue.record("Timed out waiting for model state")
}

@MainActor private func withTemporaryDirectoryAsync(
    _ body: @MainActor (URL) async throws -> Void
) async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try await body(root)
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
}
